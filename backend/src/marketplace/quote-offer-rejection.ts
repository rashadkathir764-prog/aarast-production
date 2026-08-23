import { ConflictException, NotFoundException } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  ConversationEventType,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import type { CollaborationHistoryPort as ContributionHistoryService } from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import type { NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import type { CollaborationPermissionPort as PermissionService } from "../modules/collaboration/public/collaboration-permission.port";
import {
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
} from "./quote-lifecycle";
import { requesterRejectedOfferNotification } from "./quote-notifications";
import { isQuoteOfferExpired } from "./quote-offer-expiry";
import {
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
  lockMarketplaceProvider,
} from "./marketplace-write-locks";

interface RejectQuoteOfferInput {
  id: string;
  currentUser: AuthenticatedUser;
}

export async function rejectQuoteOfferInTransaction(
  prisma: PrismaService,
  permissions: PermissionService,
  notifications: NotificationsPort,
  input: RejectQuoteOfferInput,
  history?: ContributionHistoryService,
) {
  const { id, currentUser } = input;

  return runSerializableTransaction(prisma, async (tx) => {
    let planContext: Awaited<
      ReturnType<PermissionService["assertProviderManageableInTransaction"]>
    > | null = null;
    const seed = await tx.quoteOffer.findUnique({
      where: { id },
      select: {
        providerId: true,
        provider: { select: { userId: true } },
        quoteRequest: {
          select: {
            userId: true,
            weddingPlanId: true,
            weddingPlan: { select: { ownerUserId: true } },
          },
        },
      },
    });
    if (!seed) {
      throw new NotFoundException("Quote offer not found");
    }
    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      currentUser.id,
      [
        seed.quoteRequest.userId,
        seed.quoteRequest.weddingPlan?.ownerUserId,
        seed.provider.userId,
      ],
    );
    if (seed.quoteRequest.weddingPlanId) {
      planContext = await permissions.assertProviderManageableInTransaction(
        tx,
        seed.quoteRequest.weddingPlanId,
        currentUser,
      );
      if (!planContext.isOwner && seed.quoteRequest.userId !== currentUser.id) {
        throw new NotFoundException("Quote offer not found");
      }
    } else if (seed.quoteRequest.userId !== currentUser.id) {
      throw new NotFoundException("Quote offer not found");
    }
    const provider = await lockMarketplaceProvider(tx, seed.providerId);
    assertProviderAccountUnchanged(
      provider,
      seed.provider.userId,
      lockedUserIds,
    );

    const locked = await lockQuoteOfferTransitionRows(tx, id);
    if (!locked) {
      throw new NotFoundException("Quote offer not found");
    }

    const current = await tx.quoteOffer.findUnique({
      where: { id },
      include: { quoteRequest: true },
    });
    if (!current) {
      throw new NotFoundException("Quote offer not found");
    }
    if (
      current.providerId !== seed.providerId ||
      current.quoteRequest.userId !== seed.quoteRequest.userId ||
      current.quoteRequest.weddingPlanId !==
        seed.quoteRequest.weddingPlanId
    ) {
      throw new ConflictException(
        "Quote offer context changed concurrently; retry the request",
      );
    }
    if (isQuoteOfferExpired(current)) {
      throw new ConflictException({
        code: "QUOTE_OFFER_EXPIRED",
        message: "انتهت صلاحية عرض السعر.",
      });
    }
    if (current.status !== QuoteOfferStatus.PENDING) {
      throw new ConflictException("Quote offer is not pending");
    }

    assertQuoteRequestTransition(
      current.quoteRequest.status,
      QuoteRequestStatus.REJECTED,
      "requester",
    );

    const rejectedAt = new Date();
    const offerTransition = await tx.quoteOffer.updateMany({
      where: { id, status: QuoteOfferStatus.PENDING },
      data: { status: QuoteOfferStatus.REJECTED },
    });
    if (offerTransition.count !== 1) {
      throw new ConflictException("Quote offer is not pending");
    }

    const requestTransition = await tx.quoteRequest.updateMany({
      where: {
        id: current.quoteRequestId,
        status: current.quoteRequest.status,
      },
      data: {
        status: QuoteRequestStatus.REJECTED,
        rejectedAt,
      },
    });
    if (requestTransition.count !== 1) {
      throw new ConflictException("Quote request cannot be rejected");
    }

    await recordConversationEvent(tx, {
      conversationId: current.quoteRequest.conversationId,
      quoteRequestId: current.quoteRequestId,
      quoteOfferId: current.id,
      actorUserId: currentUser.id,
      type: ConversationEventType.QUOTE_OFFER_REJECTED,
      occurredAt: rejectedAt,
      dedupeKey: `quote-offer:${current.id}:rejected`,
      data: { status: QuoteOfferStatus.REJECTED },
    });
    await recordConversationEvent(tx, {
      conversationId: current.quoteRequest.conversationId,
      quoteRequestId: current.quoteRequestId,
      actorUserId: currentUser.id,
      type: ConversationEventType.QUOTE_REQUEST_REJECTED,
      occurredAt: rejectedAt,
      dedupeKey: `quote-request:${current.quoteRequestId}:rejected`,
      data: { status: QuoteRequestStatus.REJECTED },
    });
    if (planContext && history) {
      await history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.QUOTE_REQUEST,
        entityId: current.quoteRequestId,
        action: ContributionAction.STATUS_CHANGED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.QUOTE_REQUEST,
          {
            requestStatus: QuoteRequestStatus.REJECTED,
            status: QuoteRequestStatus.REJECTED,
          },
        ),
        dedupeKey: `provider:quote-request:${current.quoteRequestId}:rejected`,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt: rejectedAt,
      });
    }

    const providerAccount = await tx.provider.findUnique({
      where: { id: current.providerId },
      select: { userId: true },
    });
    if (providerAccount?.userId && providerAccount.userId !== currentUser.id) {
      await notifications.createNotificationInTransaction(
        tx,
        requesterRejectedOfferNotification({
          providerUserId: providerAccount.userId,
          quoteRequestId: current.quoteRequestId,
          quoteOfferId: current.id,
          providerId: current.providerId,
        }),
      );
    }

    return tx.quoteOffer.findUniqueOrThrow({ where: { id } });
  });
}
