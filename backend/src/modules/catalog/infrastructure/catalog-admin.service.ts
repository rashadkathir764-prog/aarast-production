import { Injectable } from '@nestjs/common';
import { type City, Prisma, type ProviderCategory } from '@prisma/client';
import type {
  CatalogAdminPort,
  CategoryFields,
  CityFields,
  StarterBudgetItem,
} from '../public/catalog-admin.port';
import { listPublishedMoneyCatalogItems } from './money-catalog.repository';

const CATALOG_ORDER = [{ sortOrder: 'asc' }, { nameAr: 'asc' }] as const;

@Injectable()
export class CatalogAdminService implements CatalogAdminPort {
  async listCategories(
    client: Prisma.TransactionClient,
  ): Promise<ProviderCategory[]> {
    return client.providerCategory.findMany({ orderBy: [...CATALOG_ORDER] });
  }

  async listStarterBudgetItems(
    client: Prisma.TransactionClient,
  ): Promise<StarterBudgetItem[]> {
    return (await listPublishedMoneyCatalogItems(client)).flatMap(
      ({ persona, ...item }) => (persona ? [{ persona, ...item }] : []),
    );
  }

  async listCities(client: Prisma.TransactionClient): Promise<City[]> {
    return client.city.findMany({ orderBy: [...CATALOG_ORDER] });
  }

  async countCategories(client: Prisma.TransactionClient): Promise<number> {
    return client.providerCategory.count();
  }

  async countCities(
    client: Prisma.TransactionClient,
    filter: { isActive?: boolean } = {},
  ): Promise<number> {
    return filter.isActive === undefined
      ? client.city.count()
      : client.city.count({ where: { isActive: filter.isActive } });
  }

  async createCategoryInTransaction(
    tx: Prisma.TransactionClient,
    fields: CategoryFields,
  ): Promise<ProviderCategory> {
    return tx.providerCategory.create({ data: fields });
  }

  async lockCategoryForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<ProviderCategory | null> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderCategory"
        WHERE "id" = ${categoryId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) return null;
    return tx.providerCategory.findUnique({ where: { id: categoryId } });
  }

  async updateCategoryInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
    changes: Partial<CategoryFields>,
  ): Promise<ProviderCategory> {
    return tx.providerCategory.update({
      where: { id: categoryId },
      data: changes,
    });
  }

  async lockCategoryForShareInTransaction(
    tx: Prisma.TransactionClient,
    categoryId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderCategory"
        WHERE "id" = ${categoryId}
        FOR SHARE
      `,
    );
    return rows.length === 1;
  }

  async createCityInTransaction(
    tx: Prisma.TransactionClient,
    fields: CityFields,
  ): Promise<City> {
    return tx.city.create({ data: fields });
  }

  async lockCityForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "City"
        WHERE "id" = ${cityId}
        FOR UPDATE
      `,
    );
    return rows.length === 1;
  }

  async updateCityInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
    changes: Partial<CityFields>,
  ): Promise<City> {
    return tx.city.update({ where: { id: cityId }, data: changes });
  }

  async lockCityForShareInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "City"
        WHERE "id" = ${cityId}
        FOR SHARE
      `,
    );
    return rows.length === 1;
  }
}
