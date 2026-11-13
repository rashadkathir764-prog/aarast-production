import type { Prisma } from '@prisma/client';
import type { CreateNotificationInput } from '../../notifications/public/notifications.port';

export const MARKETPLACE_ERASURE_PORT = Symbol('MARKETPLACE_ERASURE_PORT');

export interface OwnedQuoteRequestScope {
  userId: string;
  weddingPlanIds: readonly string[];
  providerIds: readonly string[];
  conversationIds: readonly string[];
}

/** D112 (Q-22): the owner a plan's requests pass to, and his contact. */
export interface QuoteRequestHeir {
  quoteRequestIds: readonly string[];
  ownerUserId: string;
  contactName: string | null;
  contactPhone: string | null;
}

// The marketplace steps of account erasure, each run by marketplace on the
// saga's transaction at the point the saga reaches it.
export interface MarketplaceErasurePort {
  /**
   * B-33: the confirmed bookings of these providers from today on (the
   * day in Sana'a at `now`), under their row locks (`FOR UPDATE`,
   * ascending), so none is confirmed between this read and the erasure.
   * Any id refuses the deletion.
   */
  lockUpcomingConfirmedBookingIdsInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    now: Date,
  ): Promise<string[]>;
  /**
   * B-33: «المزود أغلق حسابه» for every customer whose open request (not
   * refused, cancelled, expired, or a wedding already done) goes with these
   * providers. Built before the requests are purged; written after.
   */
  closedProviderNoticesInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    closedAt: Date,
  ): Promise<CreateNotificationInput[]>;
  /**
   * D63 (w05): «[العميل] حذف حسابه» for the provider of every open request
   * of the account (its own, or in the plans it owns): not refused,
   * cancelled, expired, or a wedding already done. Built before the
   * requests are purged; written after.
   */
  closedCustomerNoticesInTransaction(
    tx: Prisma.TransactionClient,
    scope: { userId: string; weddingPlanIds: readonly string[] },
    customerName: string | null,
    closedAt: Date,
  ): Promise<CreateNotificationInput[]>;
  /** D63 (w05): the confirmed bookings of these plans from today on (the day in Sana'a at `now`). */
  countUpcomingPlanBookings(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    now: Date,
  ): Promise<number>;
  listOwnedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]>;
  /**
   * RA-BE-26 (D63): the owner of these listings asked for the account's
   * deletion (`at`) or took it back (null). A leaving listing is out of the
   * directory and takes no new request; what is open stays.
   */
  markOwnerLeavingInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    at: Date | null,
  ): Promise<void>;
  /** Distinct provider ids the user reviewed, ascending. */
  listReviewedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]>;
  deleteUserReviewsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /**
   * D112 (Q-22), RA-BE-131: the requests the account sent from inside plans
   * it does not own, locked (`FOR UPDATE`, ascending), by plan. They are the
   * plan's (a helper who booked the hall for the groom), so they are not
   * erased with the account: they used to be, and their offers and
   * bookings, confirmed ones too, went with them by cascade while the
   * plan's owner was told nothing. Called right after the owned requests
   * are locked, with the same scope, so the two sets never overlap.
   */
  lockMemberPlanQuoteRequestsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedQuoteRequestScope,
  ): Promise<Array<{ weddingPlanId: string; quoteRequestIds: string[] }>>;
  /**
   * D112 (Q-22): hands those requests to each plan's owner: the request,
   * its booking and its booking changes are his from now on, and the
   * contact the provider calls is his (the erased account's name and number
   * leave the request).
   */
  handOverQuoteRequestsInTransaction(
    tx: Prisma.TransactionClient,
    erasedUserId: string,
    heirs: readonly QuoteRequestHeir[],
  ): Promise<void>;
  /**
   * Locks (`FOR UPDATE`, ascending) and returns the quote requests in the
   * account's contexts: its own outside any plan or in a plan it owns, and
   * every request of its plans, its listings and its conversations.
   */
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
