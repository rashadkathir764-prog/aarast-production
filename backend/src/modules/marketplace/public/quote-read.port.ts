import type {
  Prisma,
  ProviderService,
  QuoteOffer,
  QuoteRequest,
} from '@prisma/client';

export const QUOTE_READ_PORT = Symbol('QUOTE_READ_PORT');

export type QuoteOfferWithRequest = QuoteOffer & { quoteRequest: QuoteRequest };

export interface QuoteOfferProviderRow {
  id: string;
  providerId: string;
}

/** A quote request as a conversation shows it: with the service it names and its offers, newest first. */
export type ConversationQuoteRequest = QuoteRequest & {
  service: Pick<ProviderService, 'id' | 'title'> | null;
  offers: QuoteOffer[];
};

export interface ConversationQuoteCount {
  conversationId: string;
  count: number;
}

export interface PlanQuoteCounters {
  total: number;
  pending: number;
  received: number;
  accepted: number;
  closed: number;
}

/** A quote offer made to the plan, as the planning assistant compares it (V1 checklist 4.12). */
export interface PlanQuoteOffer {
  offerId: string;
  quoteRequestId: string;
  providerId: string;
  serviceTitle: string | null;
  serviceCategoryId: string | null;
  title: string | null;
  amount: Prisma.Decimal | null;
  currency: string;
  status: QuoteOffer['status'];
  validUntil: Date | null;
}

export type ExpiredPendingOffer = Pick<
  QuoteOffer,
  'id' | 'quoteRequestId' | 'validUntil'
>;

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
  // Messaging shows the quote requests a conversation carries: the latest
  // one per conversation on the list, all of them on the detail, their
  // count, and the pending offers whose validity lapsed (a virtual timeline
  // event). The rows are marketplace's; the requester is attached by
  // messaging through identity.
  getQuoteRequestConversationId(
    client: Prisma.TransactionClient,
    quoteRequestId: string,
  ): Promise<string | null>;
  listConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationId: string,
  ): Promise<ConversationQuoteRequest[]>;
  getLatestConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<ConversationQuoteRequest[]>;
  countConversationQuoteRequests(
    client: Prisma.TransactionClient,
    conversationIds: readonly string[],
  ): Promise<ConversationQuoteCount[]>;
  /** The user's quote requests (the home dashboard counter). */
  countUserQuoteRequests(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<number>;
  /** The plan dashboard's quote counters; `quoteIds` narrows to a contributor's quotes. */
  getPlanQuoteCounters(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteIds?: readonly string[] | null,
  ): Promise<PlanQuoteCounters>;
  /** The newest offers made to the plan's quote requests, at most `take`. */
  listPlanQuoteOffers(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    take: number,
  ): Promise<PlanQuoteOffer[]>;
  /** Pending offers of the conversation whose validity lapsed at or before `before`, latest expiry first. */
  listExpiredPendingOffersForConversation(
    client: Prisma.TransactionClient,
    conversationId: string,
    before: Date,
    take: number,
  ): Promise<ExpiredPendingOffer[]>;
}
