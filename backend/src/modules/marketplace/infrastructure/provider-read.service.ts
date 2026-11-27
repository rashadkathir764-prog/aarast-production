import { Injectable } from '@nestjs/common';
import {
  BookingStatus,
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
import { featuredNowProviderWhere } from '../public/featured-placement';
import { listPricedServices } from './market-prices.repository';
import { bookingToday } from '../../../marketplace/booking-policy';
import {
  arabicSearchKey,
  likePatternContaining,
} from '../../../shared-kernel/text/arabic-search';

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
    const key = arabicSearchKey(search);
    if (providerIds.length === 0 || key.length === 0) return [];
    // RA-BE-09: the name is matched folded, as the phone matches it
    // (RA-BE-181: with LIKE, as every search).
    const pattern = likePatternContaining(key);
    const providers = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      SELECT p."id" FROM "Provider" p
      WHERE p."id" IN (${Prisma.join([...providerIds])})
        AND "aarast_search_fold"(p."businessName") LIKE ${pattern}`);
    return providers.map((provider) => provider.id);
  }

  async countFeaturedActiveProviders(
    client: Prisma.TransactionClient,
    now: Date,
  ): Promise<number> {
    // B-43: by the placement rule, as the customers' list ranks them.
    return client.provider.count({ where: featuredNowProviderWhere(now) });
  }

  async countUserFavorites(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<number> {
    return client.favoriteProvider.count({ where: { userId } });
  }

  async listPlanConfirmedBookings(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
  ): Promise<Array<{ quoteRequestId: string; quoteOfferId: string | null }>> {
    return client.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        quoteRequest: { weddingPlanId },
        ...(quoteRequestIds ? { quoteRequestId: { in: [...quoteRequestIds] } } : {}),
      },
      orderBy: { quoteRequestId: 'asc' },
      select: { quoteRequestId: true, quoteOfferId: true },
    });
  }

  async listPlanUnconfirmedBookings(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    quoteRequestIds: readonly string[] | null,
    now: Date,
    take: number,
  ): Promise<
    Array<{ quoteRequestId: string; providerName: string; eventDate: Date }>
  > {
    if (quoteRequestIds?.length === 0) return [];
    const bookings = await client.booking.findMany({
      where: {
        status: BookingStatus.REQUESTED,
        eventDate: { gte: bookingToday(now) },
        quoteRequest: { weddingPlanId },
        ...(quoteRequestIds ? { quoteRequestId: { in: [...quoteRequestIds] } } : {}),
      },
      orderBy: [{ eventDate: 'asc' }, { quoteRequestId: 'asc' }],
      take,
      select: {
        quoteRequestId: true,
        eventDate: true,
        provider: { select: { businessName: true } },
      },
    });
    return bookings.map((booking) => ({
      quoteRequestId: booking.quoteRequestId,
      providerName: booking.provider.businessName,
      eventDate: booking.eventDate,
    }));
  }

  async countPlanProvidersToRate(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    now: Date,
  ): Promise<number> {
    const served = await client.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        eventDate: { lt: bookingToday(now) },
        // B-22, RA-BE-46: as `hasCompletedBookingWith` reads it.
        OR: [{ notHappenedAt: null }, { notHappenedReason: 'WE_DID_NOT_ATTEND' }],
        quoteRequest: { weddingPlanId, userId },
      },
      distinct: ['providerId'],
      orderBy: { providerId: 'asc' },
      select: { providerId: true },
    });
    if (served.length === 0) return 0;
    const rated = await client.providerReview.findMany({
      where: {
        userId,
        providerId: { in: served.map((booking) => booking.providerId) },
      },
      distinct: ['providerId'],
      orderBy: { providerId: 'asc' },
      select: { providerId: true },
    });
    return served.length - rated.length;
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
              orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
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
