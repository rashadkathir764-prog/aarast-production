import { ConflictException, NotFoundException } from "@nestjs/common";
import {
  ConversationEventType,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import {
  ensureConversationContext,
  recordConversationEvent,
} from "../conversations/conversation-lifecycle";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";
import { MARKETPLACE_QUOTE_INCLUDE } from "./marketplace.contracts";
import { isQuoteOfferExpired } from "./quote-offer-expiry";
import {
  quoteSubmittedProviderNotification,
  quoteSubmittedRequesterNotification,
} from "./quote-notifications";

interface CreateQuoteRequestTransactionInput {
  data: Omit<Prisma.QuoteRequestUncheckedCreateInput, "conversationId">;
  requesterId: string;
  contactName: string;
}

export function createQuoteRequestInTransaction(
  prisma: PrismaService,
  notifications: NotificationsService,
  input: CreateQuoteRequestTransactionInput,
) {
  const providerId = input.data.providerId;
  const weddingPlanId = input.data.weddingPlanId ?? null;
  const serviceId = input.data.serviceId ?? null;
  const eventDate = input.data.eventDate ?? null;
  const cityId = input.data.cityId ?? null;

  return runSerializableTransaction(prisma, async (tx) => {
    // Logical identity: requester + provider + plan + service (including
    // null) + event date + city. Message, budget, contact and guest details
    // describe the same active lead and cannot bypass this domain guard.
    await tx.$queryRaw(
      Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR UPDATE`,
    );
    const activeProvider = await tx.provider.findFirst({
      where: { id: providerId, status: ProviderStatus.ACTIVE },
    });
    if (!activeProvider) throw new NotFoundException("Provider not found");

    const existing = await tx.quoteRequest.findFirst({
      where: {
        userId: input.requesterId,
        providerId,
        weddingPlanId,
        serviceId,
        eventDate,
        cityId,
        status: {
          in: [
            QuoteRequestStatus.SENT,
            QuoteRequestStatus.VIEWED,
            QuoteRequestStatus.RESPONDED,
          ],
        },
      },
      orderBy: { createdAt: "desc" },
      include: {
        offers: {
          where: { status: QuoteOfferStatus.PENDING },
          orderBy: { createdAt: "desc" },
        },
      },
    });
    // Expiry is a derived terminal state for the response cycle, so the UI's
    // explicit "new request" action can start a new cycle without rewriting
    // historical persisted statuses.
    const expiredResponseCycle =
      existing?.status === QuoteRequestStatus.RESPONDED &&
      existing.offers.length > 0 &&
      existing.offers.every((offer) => isQuoteOfferExpired(offer));
    if (existing && !expiredResponseCycle) {
      throw new ConflictException({
        code: "ACTIVE_QUOTE_REQUEST_EXISTS",
        message:
          "يوجد طلب عرض سعر نشط مطابق. تابع الطلب الحالي بدل إنشاء نسخة جديدة.",
        quoteRequestId: existing.id,
      });
    }

    const conversation = await ensureConversationContext(tx, {
      requesterUserId: input.requesterId,
      providerId,
      weddingPlanId,
    });
    const quote = await tx.quoteRequest.create({
      data: { ...input.data, conversationId: conversation.id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
    await recordConversationEvent(tx, {
      conversationId: conversation.id,
      quoteRequestId: quote.id,
      actorUserId: input.requesterId,
      type: ConversationEventType.QUOTE_REQUEST_CREATED,
      occurredAt: quote.createdAt,
      dedupeKey: `quote-request:${quote.id}:created`,
      data: { status: QuoteRequestStatus.SENT },
    });
    await notifications.createNotificationInTransaction(
      tx,
      quoteSubmittedRequesterNotification({
        requesterId: input.requesterId,
        weddingPlanId: quote.weddingPlanId,
        quoteId: quote.id,
        providerId: quote.providerId,
        providerName: quote.provider.businessName,
      }),
    );
    const providerUserId = quote.provider.userId;
    if (providerUserId && providerUserId !== input.requesterId) {
      await notifications.createNotificationInTransaction(
        tx,
        quoteSubmittedProviderNotification({
          providerUserId,
          quoteId: quote.id,
          providerId: quote.providerId,
          contactName: input.contactName,
        }),
      );
    }
    return quote;
  });
}
