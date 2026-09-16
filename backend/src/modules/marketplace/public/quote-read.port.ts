import type { Prisma, QuoteOffer, QuoteRequest } from '@prisma/client';

export const QUOTE_READ_PORT = Symbol('QUOTE_READ_PORT');

export type QuoteOfferWithRequest = QuoteOffer & { quoteRequest: QuoteRequest };

export interface QuoteOfferProviderRow {
  id: string;
  providerId: string;
}

// Marketplace owns `QuoteRequest` and `QuoteOffer`. Finance links costs to
// accepted offers and locks the offer rows it references; those reads and
// locks run here, on the caller's client, in the caller's order.
export interface QuoteReadPort {
  getQuoteOfferWithRequest(
    client: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<QuoteOfferWithRequest | null>;
  getQuoteOfferProviders(
    client: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<QuoteOfferProviderRow[]>;
  lockQuoteOfferRowsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<QuoteOfferProviderRow[]>;
}
