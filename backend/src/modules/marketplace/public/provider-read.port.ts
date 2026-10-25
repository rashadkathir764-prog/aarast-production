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
