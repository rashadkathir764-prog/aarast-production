import type { Prisma } from '@prisma/client';

export const MARKETPLACE_ERASURE_PORT = Symbol('MARKETPLACE_ERASURE_PORT');

export interface OwnedQuoteRequestScope {
  userId: string;
  weddingPlanIds: readonly string[];
  providerIds: readonly string[];
  conversationIds: readonly string[];
}

// The marketplace steps of account erasure, each run by marketplace on the
// saga's transaction at the point the saga reaches it.
export interface MarketplaceErasurePort {
  listOwnedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]>;
  /** Distinct provider ids the user reviewed, ascending. */
  listReviewedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]>;
  deleteUserReviewsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /** Locks (`FOR UPDATE`, ascending) and returns the quote requests in the account's contexts. */
  lockOwnedQuoteRequestIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedQuoteRequestScope,
  ): Promise<string[]>;
  deleteQuoteRequestsInTransaction(
    tx: Prisma.TransactionClient,
    quoteRequestIds: readonly string[],
  ): Promise<void>;
  deletePlanProviderLinksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  deleteProvidersInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<void>;
  deleteUserFavoritesInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /** The account's claims of listings (B-12), whatever their status. */
  deleteUserClaimRequestsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
