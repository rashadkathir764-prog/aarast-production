import type {
  PlanProviderLink,
  Prisma,
  Provider,
  ProviderService,
  ProviderServiceImage,
} from '@prisma/client';
import type { PriceGroup } from './market-prices';

export const PROVIDER_READ_PORT = Symbol('PROVIDER_READ_PORT');

export interface LockedProviderRow {
  id: string;
}

/** An active plan-provider link with the provider it names, its first active service and that service's first image (the dashboard preview). */
export type PlanProviderLinkPreview = PlanProviderLink & {
  provider: Provider & {
    services: Array<
      Pick<ProviderService, 'id' | 'title'> & {
        images: Array<Pick<ProviderServiceImage, 'imageUrl'>>;
      }
    >;
  };
};

// Marketplace owns `Provider`. Other contexts read provider rows and take
// the provider row lock through this port; every method runs on the client
// the caller passes (its transaction or the shared Prisma service), so the
// read stays in the caller's snapshot and the lock order is the caller's.
export interface ProviderReadPort {
  getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<Provider | null>;
  getProviders(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<Provider[]>;
  getProviderByUserId(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null>;
  /** The provider only when the user owns it. */
  findOwnedProvider(
    client: Prisma.TransactionClient,
    providerId: string,
    userId: string,
  ): Promise<Provider | null>;
  /** The subset of `providerIds` whose business name contains `search` (case-insensitive). */
  filterProviderIdsByBusinessName(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    search: string,
  ): Promise<string[]>;
  lockProviderRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<LockedProviderRow[]>;
  /** Active providers featured at `now` (the home dashboard counter, B-43). */
  countFeaturedActiveProviders(client: Prisma.TransactionClient, now: Date): Promise<number>;
  /** The user's favorite providers (the home dashboard counter). */
  countUserFavorites(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<number>;
  /**
   * D60 «محجوز»: the plan's CONFIRMED bookings (a day already past
   * included), each with the request and the accepted offer it follows;
   * `quoteRequestIds` narrows to a contributor's quotes.
   */
  listPlanConfirmedBookings(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
  ): Promise<Array<{ quoteRequestId: string; quoteOfferId: string | null }>>;
  /**
   * REFINEMENT_SPEC 2.1: the plan's bookings asked for and not yet confirmed
   * by their provider (REQUESTED) whose day has not passed in Yemen at
   * `now` (one whose day passed is over, RA-MO-263), the nearest day first,
   * at most `take`; `quoteRequestIds` narrows to a contributor's quotes.
   */
  listPlanUnconfirmedBookings(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
    now: Date,
    take: number,
  ): Promise<
    Array<{ quoteRequestId: string; providerName: string; eventDate: Date }>
  >;
  /**
   * The providers of the plan this reader may rate now and has not rated:
   * a CONFIRMED booking whose day has passed in Yemen at `now`, on a request
   * the reader sent, that the provider did not report «ما صار» (his own
   * absence aside), and no review of his by the reader. The same rule
   * `createReview` enforces (F10), so the home asks for a rating only where
   * one can be written, and stops asking once it is.
   */
  countPlanProvidersToRate(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    now: Date,
  ): Promise<number>;
  /** The plan's active links to active providers; `quoteRequestIds` narrows to a contributor's quotes. */
  countActivePlanProviderLinks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds?: readonly string[] | null,
  ): Promise<number>;
  /** The newest active links (at most `take`) with their provider preview; `quoteRequestIds` narrows as above. */
  listActivePlanProviderLinks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
    take: number,
  ): Promise<PlanProviderLinkPreview[]>;
  /** Locks the user's provider row (if any) for share and returns it. */
  lockOwnedProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null>;
  /**
   * The market price ranges by city, category and currency (V1 checklist
   * 4.12), only for groups several providers price in, so no single
   * provider's price is readable.
   */
  listMarketPriceGroups(client: Prisma.TransactionClient): Promise<PriceGroup[]>;
}
