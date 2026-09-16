import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type {
  QuoteOfferProviderRow,
  QuoteOfferWithRequest,
  QuoteReadPort,
} from '../public/quote-read.port';

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
