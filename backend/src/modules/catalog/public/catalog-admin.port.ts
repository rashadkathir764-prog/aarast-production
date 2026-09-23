import type { City, Prisma, ProviderCategory } from '@prisma/client';

export const CATALOG_ADMIN_PORT = Symbol('CATALOG_ADMIN_PORT');

export interface CategoryFields {
  nameAr: string;
  nameEn: string | null;
  slug: string;
  icon: string | null;
  showForGroom: boolean;
  showForBride: boolean;
  isActive: boolean;
  sortOrder: number;
}

export interface CityFields {
  nameAr: string;
  nameEn: string | null;
  countryCode: string;
  isActive: boolean;
  sortOrder: number;
}

// Catalog owns City and ProviderCategory. The back office maintains them
// through this port inside its authorized serializable transaction; a row
// being changed is locked FOR UPDATE first, a row a marketplace service is
// about to reference is locked FOR SHARE whatever its active state (the
// administrator may still file a service under an inactive entry).
export interface CatalogAdminPort {
  /** Every category, by sort order then Arabic name. */
  listCategories(client: Prisma.TransactionClient): Promise<ProviderCategory[]>;
  /** Every city, by sort order then Arabic name. */
  listCities(client: Prisma.TransactionClient): Promise<City[]>;
  countCategories(client: Prisma.TransactionClient): Promise<number>;
  countCities(
    client: Prisma.TransactionClient,
    filter?: { isActive?: boolean },
  ): Promise<number>;
  createCategoryInTransaction(
    tx: Prisma.TransactionClient,
    fields: CategoryFields,
  ): Promise<ProviderCategory>;
  /** Locks the category FOR UPDATE and returns it; null when it does not exist. */
  lockCategoryForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<ProviderCategory | null>;
  updateCategoryInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
    changes: Partial<CategoryFields>,
  ): Promise<ProviderCategory>;
  /** Locks the category FOR SHARE; false when it does not exist. */
  lockCategoryForShareInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<boolean>;
  createCityInTransaction(
    tx: Prisma.TransactionClient,
    fields: CityFields,
  ): Promise<City>;
  /** Locks the city FOR UPDATE; false when it does not exist. */
  lockCityForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<boolean>;
  updateCityInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
    changes: Partial<CityFields>,
  ): Promise<City>;
  /** Locks the city FOR SHARE; false when it does not exist. */
  lockCityForShareInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<boolean>;
}
