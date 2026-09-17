import type { Prisma, Provider } from '@prisma/client';

export const PROVIDER_READ_PORT = Symbol('PROVIDER_READ_PORT');

export interface LockedProviderRow {
  id: string;
}

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
  /** Locks the user's provider row (if any) for share and returns it. */
  lockOwnedProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null>;
}
