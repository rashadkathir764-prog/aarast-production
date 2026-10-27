import * as quoteRepository from "../modules/marketplace/infrastructure/marketplace-quote-mutation.repository";
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
import type { ConversationLifecyclePort } from "../modules/messaging/public/conversation-lifecycle.port";
import type { NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import { type CollaborationPermissionPort as PermissionService, seesWholePlan } from "../modules/collaboration/public/collaboration-permission.port";
import type { MarketplaceRelationsService } from "./marketplace-relations";
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
  /** B-11: why, as the provider reads it; never a budget figure. */
  reason?: string | null;
  message?: string | null;
}

export async function rejectQuoteOfferInTransaction(
  prisma: PrismaService,
  lifecycle: ConversationLifecyclePort,
  permissions: PermissionService,
  notifications: NotificationsPort,
  relations: MarketplaceRelationsService,
  input: RejectQuoteOfferInput,
  history?: ContributionHistoryService,
) {
  const { id, currentUser } = input;

  return runSerializableTransaction(prisma, async (tx) => {
    let planContext: Awaited<
      ReturnType<PermissionService["assertProviderManageableInTransaction"]>
    > | null = null;
    const seed = await quoteRepository.findOfferSeed(tx, id);
    if (!seed) {
      throw new NotFoundException("Quote offer not found");
    }
    // The plan owner is planning's row, read through its port for the
    // user lock set.
    const planSeed = seed.quoteRequest.weddingPlanId
      ? await relations.plans.getPlan(tx, seed.quoteRequest.weddingPlanId)
      : null;
    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      currentUser.id,
      [
        seed.quoteRequest.userId,
        planSeed?.ownerUserId,
        seed.provider.userId,
      ],
    );
    if (seed.quoteRequest.weddingPlanId) {
      planContext = await permissions.assertProviderManageableInTransaction(
        tx,
        seed.quoteRequest.weddingPlanId,
        currentUser,
      );
      if (!seesWholePlan(planContext) && seed.quoteRequest.userId !== currentUser.id) {
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

    const locked = await lockQuoteOfferTransitionRows(tx, lifecycle, id);
    if (!locked) {
      throw new NotFoundException("Quote offer not found");
    }

    const current = await quoteRepository.findOfferForRejection(tx, id);
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
    const offerTransition = await quoteRepository.rejectPendingOffer(tx, id, {
      reason: input.reason ?? null,
      message: input.message ?? null,
    });
    if (offerTransition.count !== 1) {
      throw new ConflictException("Quote offer is not pending");
    }

    const requestTransition = await quoteRepository.rejectQuoteRequest(tx, current.quoteRequestId, current.quoteRequest.status, rejectedAt);
    if (requestTransition.count !== 1) {
      throw new ConflictException("Quote request cannot be rejected");
    }

    await lifecycle.recordConversationEvent(tx, {
      conversationId: current.quoteRequest.conversationId,
      quoteRequestId: current.quoteRequestId,
      quoteOfferId: current.id,
      actorUserId: currentUser.id,
      type: ConversationEventType.QUOTE_OFFER_REJECTED,
      occurredAt: rejectedAt,
      dedupeKey: `quote-offer:${current.id}:rejected`,
      data: { status: QuoteOfferStatus.REJECTED },
    });
    await lifecycle.recordConversationEvent(tx, {
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

    const providerAccount = await quoteRepository.findProviderAccountForOffer(tx, current.providerId);
    if (providerAccount?.userId && providerAccount.userId !== currentUser.id) {
      await notifications.createNotificationInTransaction(
        tx,
        requesterRejectedOfferNotification({
          providerUserId: providerAccount.userId,
          quoteRequestId: current.quoteRequestId,
          quoteOfferId: current.id,
          providerId: current.providerId,
          reason: input.reason ?? null,
        }),
      );
    }

    return quoteRepository.requireOfferAfterRejection(tx, id);
  });
}
