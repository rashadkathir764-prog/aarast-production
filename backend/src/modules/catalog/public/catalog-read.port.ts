import type {
  City,
  District,
  Governorate,
  Prisma,
  ProviderCategory,
} from '@prisma/client';

export const CATALOG_READ_PORT = Symbol('CATALOG_READ_PORT');

export type ActiveGovernorate = Governorate & {
  _count: { districts: number };
};

// Catalog owns City, ProviderCategory, Governorate and District. Other
// contexts read them through this port on the client they pass (their
// transaction or the shared Prisma service); marketplace attaches the rows to
// its providers, services and quotes after reading its own tables.
export interface CatalogReadPort {
  listActiveCities(client: Prisma.TransactionClient): Promise<City[]>;
  listActiveCategories(
    client: Prisma.TransactionClient,
  ): Promise<ProviderCategory[]>;
  /** Active governorates with the count of their active districts. */
  listActiveGovernorates(
    client: Prisma.TransactionClient,
  ): Promise<ActiveGovernorate[]>;
  findActiveGovernorate(
    client: Prisma.TransactionClient,
    governorateId: string,
  ): Promise<Pick<Governorate, 'id'> | null>;
  listActiveDistricts(
    client: Prisma.TransactionClient,
    governorateId: string,
  ): Promise<District[]>;
  getCities(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<City[]>;
  getCategories(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<ProviderCategory[]>;
  findActiveCity(
    client: Prisma.TransactionClient,
    cityId: string,
  ): Promise<City | null>;
  findActiveCategory(
    client: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<ProviderCategory | null>;
  /** How many of the given categories exist and are active. */
  countActiveCategories(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<number>;
  /** Locks the city row for share and returns it while it is active. */
  lockActiveCityForShareInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<City | null>;
  /** Locks the category rows for share; true only when every one exists and is active. */
  lockActiveCategoriesForShareInTransaction(
    tx: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<boolean>;
}
