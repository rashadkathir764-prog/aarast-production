import type {
  City,
  District,
  Governorate,
  Prisma,
  ProviderCategory,
} from '@prisma/client';

export const CATALOG_READ_PORT = Symbol('CATALOG_READ_PORT');

/** C24: the provider category of wedding venues (قاعات ومخادر). */
export const VENUE_PROVIDER_CATEGORY_SLUG = 'wedding-halls';

/** Whose new plan a money catalog item is offered to. */
export type MoneyCatalogPersona = 'GROOM' | 'BRIDE' | 'NEUTRAL';

/**
 * A published, active item of the money catalog (`money.starter.categories`):
 * the name a new plan's budget item is created with, and the provider
 * categories (by slug, stable across environments) the owner linked it to
 * from the back office. D73: an empty list is no explicit link.
 */
export interface MoneyCatalogItem {
  nameAr: string;
  /** `metadata.persona`, the back office's reading; null when unnamed. */
  persona: MoneyCatalogPersona | null;
  /** Who a new plan offers it to, as the app reads it. */
  showForGroom: boolean;
  showForBride: boolean;
  providerCategorySlugs: string[];
}

export type ActiveGovernorate = Governorate & {
  _count: { districts: number };
};

// Catalog owns City, ProviderCategory, Governorate and District. Other
// contexts read them through this port on the client they pass (their
// transaction or the shared Prisma service); marketplace attaches the rows to
// its providers, services and quotes after reading its own tables.
export interface CatalogReadPort {
  listActiveCities(client: Prisma.TransactionClient): Promise<City[]>;
  /** D73: the published, active money catalog items, in the catalog's order. */
  listMoneyCatalogItems(
    client: Prisma.TransactionClient,
  ): Promise<MoneyCatalogItem[]>;
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
