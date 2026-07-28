import { ConflictException, NotFoundException } from "@nestjs/common";
import {
  ConversationEventType,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
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
  notifications: NotificationsService,
  input: RejectQuoteOfferInput,
) {
  const { id, currentUser } = input;

  return runSerializableTransaction(prisma, async (tx) => {
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
      await permissions.assertProviderManageableInTransaction(
        tx,
        seed.quoteRequest.weddingPlanId,
        currentUser,
      );
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
