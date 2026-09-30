import { Injectable } from '@nestjs/common';
import {
  type City,
  type District,
  type Governorate,
  Prisma,
  type ProviderCategory,
} from '@prisma/client';
import type {
  ActiveGovernorate,
  CatalogReadPort,
} from '../public/catalog-read.port';

const CATALOG_ORDER = [{ sortOrder: 'asc' }, { nameAr: 'asc' }] as const;

@Injectable()
export class CatalogReadService implements CatalogReadPort {
  async listActiveCities(client: Prisma.TransactionClient): Promise<City[]> {
    return client.city.findMany({
      where: { isActive: true },
      orderBy: [...CATALOG_ORDER],
    });
  }

  async listActiveCategories(
    client: Prisma.TransactionClient,
  ): Promise<ProviderCategory[]> {
    return client.providerCategory.findMany({
      where: { isActive: true },
      orderBy: [...CATALOG_ORDER],
    });
  }

  async listActiveGovernorates(
    client: Prisma.TransactionClient,
  ): Promise<ActiveGovernorate[]> {
    return client.governorate.findMany({
      where: { isActive: true },
      orderBy: [...CATALOG_ORDER],
      include: {
        _count: {
          select: {
            districts: { where: { isActive: true } },
          },
        },
      },
    });
  }

  async findActiveGovernorate(
    client: Prisma.TransactionClient,
    governorateId: string,
  ): Promise<Pick<Governorate, 'id'> | null> {
    return client.governorate.findFirst({
      where: { id: governorateId, isActive: true },
      select: { id: true },
    });
  }

  async listActiveDistricts(
    client: Prisma.TransactionClient,
    governorateId: string,
  ): Promise<District[]> {
    return client.district.findMany({
      where: { governorateId, isActive: true },
      orderBy: [...CATALOG_ORDER],
    });
  }

  async getCities(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<City[]> {
    if (cityIds.length === 0) return [];
    return client.city.findMany({ where: { id: { in: [...cityIds] } } });
  }

  async getCategories(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<ProviderCategory[]> {
    if (categoryIds.length === 0) return [];
    return client.providerCategory.findMany({
      where: { id: { in: [...categoryIds] } },
    });
  }

  async findActiveCity(
    client: Prisma.TransactionClient,
    cityId: string,
  ): Promise<City | null> {
    return client.city.findFirst({ where: { id: cityId, isActive: true } });
  }

  private async countActiveCategories(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<number> {
    if (categoryIds.length === 0) return 0;
    return client.providerCategory.count({
      where: { id: { in: [...categoryIds] }, isActive: true },
    });
  }

  async lockActiveCityForShareInTransaction(
    tx: Prisma.TransactionClient,
    cityId: string,
  ): Promise<City | null> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "City"
        WHERE "id" = ${cityId}
        FOR SHARE
      `,
    );
    if (rows.length !== 1) return null;
    return this.findActiveCity(tx, cityId);
  }

  async lockActiveCategoriesForShareInTransaction(
    tx: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<boolean> {
    const uniqueIds = [...new Set(categoryIds)].sort();
    if (uniqueIds.length === 0) return true;
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderCategory"
        WHERE "id" = ANY(${uniqueIds}::text[])
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
    if (rows.length !== uniqueIds.length) return false;
    return (await this.countActiveCategories(tx, uniqueIds)) === uniqueIds.length;
  }
}
