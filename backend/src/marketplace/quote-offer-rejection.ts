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
    if (isQuoteOfferExpired(current)) {
      throw new ConflictException({
        code: "QUOTE_OFFER_EXPIRED",
        message: "انتهت صلاحية عرض السعر.",
      });
    }
    if (current.status !== QuoteOfferStatus.PENDING) {
      throw new ConflictException("Quote offer is not pending");
    }

    if (current.quoteRequest.weddingPlanId) {
      await permissions.assertProviderManageableInTransaction(
        tx,
        current.quoteRequest.weddingPlanId,
        currentUser,
      );
    } else if (current.quoteRequest.userId !== currentUser.id) {
      throw new NotFoundException("Quote offer not found");
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
