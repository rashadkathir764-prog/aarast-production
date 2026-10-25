import { Injectable } from '@nestjs/common';
import {
  PlanProviderLinkStatus,
  Prisma,
  type Provider,
  ProviderStatus,
} from '@prisma/client';
import type {
  PlanProviderLinkPreview,
  LockedProviderRow,
  ProviderReadPort,
} from '../public/provider-read.port';
import { groupPrices, type PriceGroup } from '../public/market-prices';
import { activeFeaturedPeriodWhere } from '../public/featured-placement';
import { listPricedServices } from './market-prices.repository';

@Injectable()
export class ProviderReadService implements ProviderReadPort {
  async getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<Provider | null> {
    return client.provider.findUnique({ where: { id: providerId } });
  }

  async getProviders(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<Provider[]> {
    if (providerIds.length === 0) return [];
    return client.provider.findMany({
      where: { id: { in: [...providerIds] } },
    });
  }

  async getProviderByUserId(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null> {
    return client.provider.findUnique({ where: { userId } });
  }

  async findOwnedProvider(
    client: Prisma.TransactionClient,
    providerId: string,
    userId: string,
  ): Promise<Provider | null> {
    return client.provider.findFirst({ where: { id: providerId, userId } });
  }

  async filterProviderIdsByBusinessName(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    search: string,
  ): Promise<string[]> {
    if (providerIds.length === 0) return [];
    const providers = await client.provider.findMany({
      where: {
        id: { in: [...providerIds] },
        businessName: { contains: search, mode: 'insensitive' },
      },
      select: { id: true },
    });
    return providers.map((provider) => provider.id);
  }

  async countFeaturedActiveProviders(
    client: Prisma.TransactionClient,
    now: Date,
  ): Promise<number> {
    return client.provider.count({
      where: {
        status: ProviderStatus.ACTIVE,
        featuredPeriods: { some: activeFeaturedPeriodWhere(now) },
      },
    });
  }

  async countUserFavorites(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<number> {
    return client.favoriteProvider.count({ where: { userId } });
  }

  async countActivePlanProviderLinks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds?: readonly string[] | null,
  ): Promise<number> {
    return client.planProviderLink.count({
      where: activePlanLinksWhere(weddingPlanId, quoteRequestIds),
    });
  }

  async listActivePlanProviderLinks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
    take: number,
  ): Promise<PlanProviderLinkPreview[]> {
    return client.planProviderLink.findMany({
      where: activePlanLinksWhere(weddingPlanId, quoteRequestIds),
      include: {
        provider: {
          include: {
            services: {
              where: { isActive: true },
              orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
              take: 1,
              select: {
                id: true,
                title: true,
                images: {
                  orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
                  take: 1,
                  select: { imageUrl: true },
                },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async lockOwnedProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<Provider | null> {
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "userId" = ${userId}
        FOR SHARE
      `,
    );
    return this.getProviderByUserId(tx, userId);
  }

  async lockProviderRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<LockedProviderRow[]> {
    const sortedProviderIds = [...new Set(providerIds)].sort();
    if (sortedProviderIds.length === 0) return [];
    return tx.$queryRaw<LockedProviderRow[]>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" IN (${Prisma.join(sortedProviderIds)})
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }

  async listMarketPriceGroups(
    client: Prisma.TransactionClient,
  ): Promise<PriceGroup[]> {
    return groupPrices(await listPricedServices(client));
  }
}

function activePlanLinksWhere(
  weddingPlanId: string,
  quoteRequestIds?: readonly string[] | null,
) {
  return {
    weddingPlanId,
    ...(quoteRequestIds ? { quoteRequestId: { in: [...quoteRequestIds] } } : {}),
    status: PlanProviderLinkStatus.ACTIVE,
    provider: { status: ProviderStatus.ACTIVE },
  };
}
