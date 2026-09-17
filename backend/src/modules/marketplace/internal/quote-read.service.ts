import { Injectable } from '@nestjs/common';
import { Prisma, QuoteOfferStatus } from '@prisma/client';
import type {
  ConversationQuoteCount,
  ConversationQuoteRequest,
  ExpiredPendingOffer,
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
