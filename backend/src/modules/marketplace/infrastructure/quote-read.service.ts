import { Injectable } from '@nestjs/common';
import {
  BookingStatus,
  Prisma,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from '@prisma/client';
import type {
  ConversationQuoteCount,
  ConversationQuoteRequest,
  ExpiredPendingOffer,
  PlanQuoteCounters,
  PlanQuoteOffer,
  QuoteOfferProviderRow,
  QuoteOfferWithRequest,
  QuoteReadPort,
} from '../public/quote-read.port';

const conversationQuoteInclude = {
  service: { select: { id: true, title: true } },
  offers: { orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] },
} satisfies Prisma.QuoteRequestInclude;

@Injectable()
export class QuoteReadService implements QuoteReadPort {
  async getQuoteOfferWithRequest(
    client: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<QuoteOfferWithRequest | null> {
    return client.quoteOffer.findUnique({
      where: { id: quoteOfferId },
      include: { quoteRequest: true },
    });
  }

  async getQuoteRequestConversationId(
    client: Prisma.TransactionClient,
    quoteRequestId: string,
  ): Promise<string | null> {
    const quote = await client.quoteRequest.findUnique({
      where: { id: quoteRequestId },
      select: { conversationId: true },
    });
    return quote?.conversationId ?? null;
  }

  async listConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationId: string,
  ): Promise<ConversationQuoteRequest[]> {
    return client.quoteRequest.findMany({
      where: { conversationId },
      include: conversationQuoteInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  async getLatestConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<ConversationQuoteRequest[]> {
    if (conversationIds.length === 0) return [];
    return client.quoteRequest.findMany({
      where: { conversationId: { in: [...conversationIds] } },
      include: conversationQuoteInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      distinct: ['conversationId'],
    });
  }

  async countConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<ConversationQuoteCount[]> {
    if (conversationIds.length === 0) return [];
    const groups = await client.quoteRequest.groupBy({
      by: ['conversationId'],
      where: { conversationId: { in: [...conversationIds] } },
      _count: { _all: true },
    });
    return groups.map((group) => ({
      conversationId: group.conversationId,
      count: group._count._all,
    }));
  }

  async countUserQuoteRequests(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<number> {
    return client.quoteRequest.count({ where: { userId } });
  }

  async listConfirmedBookingCategoryIds(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteIds?: readonly string[] | null,
  ): Promise<string[]> {
    const bookings = await client.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        quoteRequest: {
          weddingPlanId,
          ...(quoteIds ? { id: { in: [...quoteIds] } } : {}),
        },
      },
      select: { provider: { select: { primaryCategoryId: true } } },
    });
    return [
      ...new Set(
        bookings.flatMap((booking) =>
          booking.provider.primaryCategoryId ? [booking.provider.primaryCategoryId] : [],
        ),
      ),
    ];
  }

  async getPlanQuoteCounters(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteIds?: readonly string[] | null,
  ): Promise<PlanQuoteCounters> {
    const base = {
      weddingPlanId,
      ...(quoteIds ? { id: { in: [...quoteIds] } } : {}),
    };
    const [total, pending, received, accepted, closed] = await Promise.all([
      client.quoteRequest.count({ where: base }),
      client.quoteRequest.count({
        where: { ...base, status: { in: [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED] } },
      }),
      client.quoteRequest.count({ where: { ...base, status: QuoteRequestStatus.RESPONDED } }),
      client.quoteRequest.count({ where: { ...base, status: QuoteRequestStatus.ACCEPTED } }),
      client.quoteRequest.count({
        where: {
          ...base,
          status: {
            in: [
              QuoteRequestStatus.REJECTED,
              QuoteRequestStatus.CANCELLED,
              QuoteRequestStatus.EXPIRED,
            ],
          },
        },
      }),
    ]);
    return { total, pending, received, accepted, closed };
  }

  async listPlanQuoteOffers(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    take: number,
  ): Promise<PlanQuoteOffer[]> {
    const offers = await client.quoteOffer.findMany({
      where: { quoteRequest: { weddingPlanId } },
      include: {
        quoteRequest: {
          select: { service: { select: { title: true, categoryId: true } } },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take,
    });
    return offers.map((offer) => ({
      offerId: offer.id,
      quoteRequestId: offer.quoteRequestId,
      providerId: offer.providerId,
      serviceTitle: offer.quoteRequest.service?.title ?? null,
      serviceCategoryId: offer.quoteRequest.service?.categoryId ?? null,
      title: offer.title,
      amount: offer.amount,
      currency: offer.currency,
      status: offer.status,
      validUntil: offer.validUntil,
    }));
  }

  async listExpiredPendingOffersForConversation(
    client: Prisma.TransactionClient,
    conversationId: string,
    before: Date,
    take: number,
  ): Promise<ExpiredPendingOffer[]> {
    return client.quoteOffer.findMany({
      where: {
        quoteRequest: { conversationId },
        status: QuoteOfferStatus.PENDING,
        validUntil: { not: null, lte: before },
      },
      select: { id: true, quoteRequestId: true, validUntil: true },
      orderBy: [{ validUntil: 'desc' }, { id: 'desc' }],
      take,
    });
  }

  async getQuoteOfferProviders(
    client: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<QuoteOfferProviderRow[]> {
    if (quoteOfferIds.length === 0) return [];
    return client.quoteOffer.findMany({
      where: { id: { in: [...quoteOfferIds] } },
      select: { id: true, providerId: true },
    });
  }

  async lockQuoteOfferRowsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<QuoteOfferProviderRow[]> {
    const sortedQuoteOfferIds = [...new Set(quoteOfferIds)].sort();
    if (sortedQuoteOfferIds.length === 0) return [];
    return tx.$queryRaw<QuoteOfferProviderRow[]>(
      Prisma.sql`
        SELECT "id", "providerId"
        FROM "QuoteOffer"
        WHERE "id" IN (${Prisma.join(sortedQuoteOfferIds)})
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }
}
