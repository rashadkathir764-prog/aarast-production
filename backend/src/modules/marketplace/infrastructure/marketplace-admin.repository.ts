import {
  Prisma,
  type Provider,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';
import type {
  AdminListedProviderFields,
  AdminListing,
  AdminMarketplaceCounters,
  AdminMarketplaceReport,
  AdminPage,
  AdminProviderDetailRow,
  AdminProviderFilter,
  AdminProviderRow,
  AdminReviewFilter,
  AdminReviewRow,
  AdminServiceChanges,
  AdminServiceFields,
  AdminServiceFilter,
  AdminServiceRow,
  CatalogUsage,
  MarketplaceAdminPort,
  ProviderReviewDecision,
  ProviderVerification,
} from '../public/marketplace-admin.port';
import {
  priceStampForNewService,
  priceStampForServiceUpdate,
} from './service-price-stamp';

interface TextMatch {
  contains: string;
  mode: 'insensitive';
}

interface AccountMatch {
  userId: { in: string[] };
}

type ProviderAdminCondition =
  | { status: { in: ProviderStatus[] } }
  | { cityId: string }
  | {
      OR: Array<
        | { primaryCategoryId: string }
        | { services: { some: { categoryId: string } } }
      >;
    }
  | {
      OR: Array<
        | { businessName: TextMatch }
        | { ownerName: TextMatch }
        | { phone: TextMatch }
        | { email: TextMatch }
        | AccountMatch
      >;
    };

type ServiceAdminCondition =
  | { isActive: boolean }
  | { isFeatured: boolean }
  | { providerId: string }
  | { categoryId: string }
  | {
      OR: Array<
        { cityId: string } | { cityId: null; provider: { cityId: string } }
      >;
    }
  | {
      OR: Array<
        | { title: TextMatch }
        | { description: TextMatch }
        | { provider: { businessName: TextMatch } }
        | { provider: { phone: TextMatch } }
      >;
    };

type ReviewAdminCondition =
  | { status: ReviewStatus }
  | { providerId: string }
  | {
      OR: Array<
        | { comment: TextMatch }
        | AccountMatch
        | { provider: { businessName: TextMatch } }
      >;
    };

const providerCounts = {
  _count: {
    select: {
      services: true,
      packages: true,
      quoteRequests: true,
      reviews: true,
    },
  },
} satisfies Prisma.ProviderInclude;

const imageOrder = [
  { sortOrder: 'asc' },
  { createdAt: 'asc' },
] satisfies Prisma.ProviderServiceImageOrderByWithRelationInput[];

const providerDetailInclude = {
  ...providerCounts,
  services: {
    include: { images: { orderBy: imageOrder } },
    orderBy: { createdAt: 'desc' },
  },
  packages: {
    include: { service: true },
    orderBy: { createdAt: 'desc' },
  },
} satisfies Prisma.ProviderInclude;

const serviceInclude = {
  provider: true,
  images: { orderBy: imageOrder },
} satisfies Prisma.ProviderServiceInclude;

export class MarketplaceAdminRepository implements MarketplaceAdminPort {
  async getCounters(
    client: Prisma.TransactionClient,
  ): Promise<AdminMarketplaceCounters> {
    const [
      totalProviders,
      pendingProviders,
      approvedProviders,
      rejectedProviders,
      needsChangesProviders,
      suspendedProviders,
      totalQuoteRequests,
    ] = await Promise.all([
      client.provider.count(),
      client.provider.count({ where: { status: ProviderStatus.PENDING } }),
      client.provider.count({ where: { status: ProviderStatus.ACTIVE } }),
      client.provider.count({ where: { status: ProviderStatus.REJECTED } }),
      client.provider.count({
        where: { status: ProviderStatus.NEEDS_CHANGES },
      }),
      client.provider.count({ where: { status: ProviderStatus.SUSPENDED } }),
      client.quoteRequest.count(),
    ]);
    return {
      totalProviders,
      pendingProviders,
      approvedProviders,
      rejectedProviders,
      needsChangesProviders,
      suspendedProviders,
      totalQuoteRequests,
    };
  }

  async getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport> {
    const [providers, services, reviews, quotes] = await Promise.all([
      this.providerReport(client, createdAt),
      this.serviceReport(client, createdAt),
      this.reviewReport(client, createdAt),
      Promise.all(
        Object.values(QuoteRequestStatus).map(async (status) => ({
          status,
          count: await client.quoteRequest.count({
            where: { createdAt, status },
          }),
        })),
      ),
    ]);
    return { providers, services, reviews, quotes };
  }

  async listProviders(
    client: Prisma.TransactionClient,
    filter: AdminProviderFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminProviderRow>> {
    const and: ProviderAdminCondition[] = [
      { status: { in: [...filter.statuses] } },
    ];
    if (filter.cityId) and.push({ cityId: filter.cityId });
    if (filter.categoryId) {
      and.push({
        OR: [
          { primaryCategoryId: filter.categoryId },
          { services: { some: { categoryId: filter.categoryId } } },
        ],
      });
    }
    if (filter.search) {
      const text = textMatch(filter.search.text);
      and.push({
        OR: [
          { businessName: text },
          { ownerName: text },
          { phone: text },
          { email: text },
          { userId: { in: [...filter.search.userIds] } },
        ],
      });
    }
    const where = { AND: and };
    const total = await client.provider.count({ where });
    const items = await client.provider.findMany({
      where,
      include: providerCounts,
      orderBy: [{ createdAt: 'desc' }],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async getProvider(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderDetailRow | null> {
    return client.provider.findUnique({
      where: { id: providerId },
      include: providerDetailInclude,
    });
  }

  async getAccountProviders(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<Provider[]> {
    if (userIds.length === 0) return [];
    return client.provider.findMany({
      where: { userId: { in: [...userIds] } },
    });
  }

  async findProviderAccount(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null } | null> {
    return client.provider.findUnique({
      where: { id: providerId },
      select: { userId: true },
    });
  }

  async lockProviderForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<{ userId: string | null; status: ProviderStatus } | null> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" = ${providerId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) return null;
    return tx.provider.findUnique({
      where: { id: providerId },
      select: { userId: true, status: true },
    });
  }

  async recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow> {
    return tx.provider.update({
      where: { id: providerId },
      data: {
        status: decision.status,
        reviewNote: decision.reviewNote,
        reviewedAt: decision.reviewedAt,
        reviewedById: decision.reviewedById,
      },
      include: providerDetailInclude,
    });
  }

  async recordProviderVerificationInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    verification: ProviderVerification,
  ): Promise<AdminProviderDetailRow> {
    return tx.provider.update({
      where: { id: providerId },
      data: {
        verifiedAt: verification.verifiedAt,
        verifiedById: verification.verifiedById,
      },
      include: providerDetailInclude,
    });
  }

  async hasProviderWithPhone(
    client: Prisma.TransactionClient,
    phones: readonly string[],
  ): Promise<boolean> {
    if (phones.length === 0) return false;
    const found = await client.provider.findFirst({
      where: { phone: { in: [...phones] } },
      select: { id: true },
    });
    return found !== null;
  }

  async createListedProviderInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminListedProviderFields,
  ): Promise<AdminProviderDetailRow> {
    return tx.provider.create({
      data: {
        userId: null,
        status: ProviderStatus.ACTIVE,
        businessName: fields.businessName,
        phone: fields.phone,
        whatsapp: fields.whatsapp,
        cityId: fields.cityId,
        primaryCategoryId: fields.primaryCategoryId,
        description: fields.description,
        address: fields.address,
        reviewedAt: fields.reviewedAt,
        reviewedById: fields.reviewedById,
      },
      include: providerDetailInclude,
    });
  }

  async lockProviderForShareInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" = ${providerId}
        FOR SHARE
      `,
    );
    return rows.length === 1;
  }

  async listServices(
    client: Prisma.TransactionClient,
    filter: AdminServiceFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminServiceRow>> {
    const and: ServiceAdminCondition[] = [];
    if (filter.isActive !== undefined) and.push({ isActive: filter.isActive });
    if (filter.isFeatured !== undefined) {
      and.push({ isFeatured: filter.isFeatured });
    }
    if (filter.providerId) and.push({ providerId: filter.providerId });
    if (filter.categoryId) and.push({ categoryId: filter.categoryId });
    if (filter.cityId) {
      and.push({
        OR: [
          { cityId: filter.cityId },
          { cityId: null, provider: { cityId: filter.cityId } },
        ],
      });
    }
    if (filter.search) {
      const text = textMatch(filter.search);
      and.push({
        OR: [
          { title: text },
          { description: text },
          { provider: { businessName: text } },
          { provider: { phone: text } },
        ],
      });
    }
    const where = { AND: and };
    const total = await client.providerService.count({ where });
    const items = await client.providerService.findMany({
      where,
      include: serviceInclude,
      orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async findServiceProviderId(
    client: Prisma.TransactionClient,
    serviceId: string,
  ): Promise<string | null> {
    const service = await client.providerService.findUnique({
      where: { id: serviceId },
      select: { providerId: true },
    });
    return service?.providerId ?? null;
  }

  async lockServiceForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    providerId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderService"
        WHERE "id" = ${serviceId}
          AND "providerId" = ${providerId}
        FOR UPDATE
      `,
    );
    return rows.length === 1;
  }

  async createServiceInTransaction(
    tx: Prisma.TransactionClient,
    fields: AdminServiceFields,
  ): Promise<AdminServiceRow> {
    return tx.providerService.create({
      data: {
        ...fields,
        priceUpdatedAt: priceStampForNewService(fields.basePrice),
      },
      include: serviceInclude,
    });
  }

  async updateServiceInTransaction(
    tx: Prisma.TransactionClient,
    serviceId: string,
    changes: AdminServiceChanges,
  ): Promise<AdminServiceRow> {
    const priceStamp = await priceStampForServiceUpdate(tx, serviceId, changes);
    return tx.providerService.update({
      where: { id: serviceId },
      data: { ...changes, ...priceStamp },
      include: serviceInclude,
    });
  }

  async listReviews(
    client: Prisma.TransactionClient,
    filter: AdminReviewFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminReviewRow>> {
    const and: ReviewAdminCondition[] = [];
    if (filter.status) and.push({ status: filter.status });
    if (filter.providerId) and.push({ providerId: filter.providerId });
    if (filter.search) {
      const text = textMatch(filter.search.text);
      and.push({
        OR: [
          { comment: text },
          { userId: { in: [...filter.search.userIds] } },
          { provider: { businessName: text } },
        ],
      });
    }
    const where = { AND: and };
    const total = await client.providerReview.count({ where });
    const items = await client.providerReview.findMany({
      where,
      include: { provider: true },
      orderBy: { createdAt: 'desc' },
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async findReviewProviderId(
    client: Prisma.TransactionClient,
    reviewId: string,
  ): Promise<string | null> {
    const review = await client.providerReview.findUnique({
      where: { id: reviewId },
      select: { providerId: true },
    });
    return review?.providerId ?? null;
  }

  async lockReviewForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    providerId: string,
  ): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderReview"
        WHERE "id" = ${reviewId}
          AND "providerId" = ${providerId}
        FOR UPDATE
      `,
    );
    return rows.length === 1;
  }

  async setReviewStatusInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    status: ReviewStatus,
  ): Promise<AdminReviewRow> {
    return tx.providerReview.update({
      where: { id: reviewId },
      data: { status },
      include: { provider: true },
    });
  }

  async countCategoryUsage(
    client: Prisma.TransactionClient,
    categoryIds: readonly string[],
  ): Promise<CatalogUsage[]> {
    if (categoryIds.length === 0) return [];
    const ids = [...categoryIds];
    const [providers, services] = await Promise.all([
      client.provider.groupBy({
        by: ['primaryCategoryId'],
        where: { primaryCategoryId: { in: ids } },
        _count: { _all: true },
      }),
      client.providerService.groupBy({
        by: ['categoryId'],
        where: { categoryId: { in: ids } },
        _count: { _all: true },
      }),
    ]);
    return usage(
      ids,
      providers.map((group) => [group.primaryCategoryId, group._count._all]),
      services.map((group) => [group.categoryId, group._count._all]),
    );
  }

  async countCityUsage(
    client: Prisma.TransactionClient,
    cityIds: readonly string[],
  ): Promise<CatalogUsage[]> {
    if (cityIds.length === 0) return [];
    const ids = [...cityIds];
    const [providers, services] = await Promise.all([
      client.provider.groupBy({
        by: ['cityId'],
        where: { cityId: { in: ids } },
        _count: { _all: true },
      }),
      client.providerService.groupBy({
        by: ['cityId'],
        where: { cityId: { in: ids } },
        _count: { _all: true },
      }),
    ]);
    return usage(
      ids,
      providers.map((group) => [group.cityId, group._count._all]),
      services.map((group) => [group.cityId, group._count._all]),
    );
  }

  private async providerReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport['providers']> {
    const [total, pending, active, needsChanges, suspended, rejected, featured] =
      await Promise.all([
        client.provider.count({ where: { createdAt } }),
        client.provider.count({
          where: { createdAt, status: ProviderStatus.PENDING },
        }),
        client.provider.count({
          where: { createdAt, status: ProviderStatus.ACTIVE },
        }),
        client.provider.count({
          where: { createdAt, status: ProviderStatus.NEEDS_CHANGES },
        }),
        client.provider.count({
          where: { createdAt, status: ProviderStatus.SUSPENDED },
        }),
        client.provider.count({
          where: { createdAt, status: ProviderStatus.REJECTED },
        }),
        client.provider.count({ where: { createdAt, isFeatured: true } }),
      ]);
    return { total, pending, active, needsChanges, suspended, rejected, featured };
  }

  private async serviceReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport['services']> {
    const [total, active, disabled, featured] = await Promise.all([
      client.providerService.count({ where: { createdAt } }),
      client.providerService.count({ where: { createdAt, isActive: true } }),
      client.providerService.count({ where: { createdAt, isActive: false } }),
      client.providerService.count({ where: { createdAt, isFeatured: true } }),
    ]);
    return { total, active, disabled, featured };
  }

  private async reviewReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport['reviews']> {
    const [total, published, hidden, pending, average] = await Promise.all([
      client.providerReview.count({ where: { createdAt } }),
      client.providerReview.count({
        where: { createdAt, status: ReviewStatus.PUBLISHED },
      }),
      client.providerReview.count({
        where: { createdAt, status: ReviewStatus.HIDDEN },
      }),
      client.providerReview.count({
        where: { createdAt, status: ReviewStatus.PENDING },
      }),
      client.providerReview.aggregate({
        where: { createdAt },
        _avg: { rating: true },
      }),
    ]);
    return {
      total,
      published,
      hidden,
      pending,
      averageRating: average._avg.rating,
    };
  }
}

function textMatch(search: string): TextMatch {
  return { contains: search, mode: 'insensitive' };
}

function usage(
  ids: readonly string[],
  providers: Array<[string | null, number]>,
  services: Array<[string | null, number]>,
): CatalogUsage[] {
  const providerCounts = new Map(providers);
  const serviceCounts = new Map(services);
  return ids.map((id) => ({
    id,
    providers: providerCounts.get(id) ?? 0,
    services: serviceCounts.get(id) ?? 0,
  }));
}
