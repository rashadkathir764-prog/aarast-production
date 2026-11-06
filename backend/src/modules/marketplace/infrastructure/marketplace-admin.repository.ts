import {
  BookingStatus,
  Prisma,
  type Provider,
  ProviderClaimStatus,
  type ProviderClaimRequest,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
} from '@prisma/client';
import type { CreateNotificationInput } from '../../notifications/public/notifications.port';
import * as bookingStore from './marketplace-booking.repository';
import * as portfolioStore from './portfolio.repository';
import type { PortfolioItemStatus } from '@prisma/client';
import type { AdminPortfolioDecision } from '../public/marketplace-admin.port';
import {
  type BookingLifecycle,
  bookingLifecycle,
  bookingToday,
} from '../../../marketplace/booking-policy';
import { providerSuspendedCustomerNotification } from '../../../marketplace/booking-notifications';
import { lockMarketplaceProvider } from '../../../marketplace/marketplace-write-locks';
import type {
  AdminActiveFeaturedPeriod,
  AdminBookingFilter,
  AdminBookingRow,
  AdminClaimRequestFilter,
  AdminClaimRequestRow,
  AdminFeaturedPeriodFilter,
  AdminFeaturedPeriodRow,
  AdminFeaturedSummary,
  FeaturedPeriodEndFields,
  FeaturedPeriodGrantFields,
  AdminListedProviderFields,
  AdminListing,
  AdminProviderReviewEvent,
  ProviderClaimDecision,
  AdminMarketplaceSuccessCounts,
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
import type { PricedService } from '../public/market-prices';
import { featuredNowProviderWhere } from '../public/featured-placement';
import * as featured from './featured-period.repository';
import { listPricedServices } from './market-prices.repository';
import {
  hasJoiningService,
  latestProviderDecisionInclude,
  listProviderReviewEvents,
  recordProviderReviewEvent,
} from './provider-review.repository';
import {
  priceStampForNewService,
  priceStampForServiceUpdate,
} from './service-price-stamp';
import { findServiceIdsMatchingSearch } from './marketplace-core.repository';
import {
  ARABIC_FOLD_FROM,
  ARABIC_FOLD_TO,
  arabicSearchKey,
} from '../../../shared-kernel/text/arabic-search';

interface TextMatch {
  contains: string;
  mode: 'insensitive';
}

interface AccountMatch {
  userId: { in: string[] };
}

/** RA-BE-09: the rows whose Arabic text matched the folded search. */
interface FoldedMatch {
  id: { in: string[] };
}

type ProviderAdminCondition =
  | { status: { in: ProviderStatus[] } }
  | { resubmittedAt: { not: null } | null }
  | { cityId: string }
  | {
      OR: Array<
        | { primaryCategoryId: string }
        | { services: { some: { categoryId: string } } }
      >;
    }
  | {
      OR: Array<
        | FoldedMatch
        | { phone: TextMatch }
        | { email: TextMatch }
        | AccountMatch
      >;
    };

type ServiceAdminCondition =
  | { isActive: boolean }
  | { providerId: string }
  | { categoryId: string }
  | {
      OR: Array<
        { cityId: string } | { cityId: null; provider: { cityId: string } }
      >;
    }
  | {
      OR: Array<FoldedMatch | { provider: { phone: TextMatch } }>;
    };

type ReviewAdminCondition =
  | { status: ReviewStatus }
  | { providerId: string }
  | {
      OR: Array<FoldedMatch | AccountMatch>;
    };

/** a12 (B-40): what a booking is to the people (COMPLETED once its day passed). */
function withLifecycle<
  T extends { status: BookingStatus; eventDate: Date; notHappenedAt?: Date | null },
>(booking: T): T & { lifecycleStatus: BookingLifecycle } {
  return {
    ...booking,
    lifecycleStatus: bookingLifecycle(
      booking.status,
      booking.eventDate,
      new Date(),
      booking.notHappenedAt ?? null,
    ),
  };
}

const providerCounts = {
  _count: {
    select: {
      services: true,
      packages: true,
      quoteRequests: true,
      reviews: true,
    },
  },
  ...latestProviderDecisionInclude,
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
      resubmittedProviders,
      pendingClaims,
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
      client.provider.count({
        where: { status: ProviderStatus.PENDING, resubmittedAt: { not: null } },
      }),
      client.providerClaimRequest.count({
        where: { status: ProviderClaimStatus.PENDING },
      }),
      client.quoteRequest.count(),
    ]);
    return {
      totalProviders,
      pendingProviders,
      approvedProviders,
      rejectedProviders,
      needsChangesProviders,
      suspendedProviders,
      resubmittedProviders,
      pendingClaims,
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
    // «أُعيد إرسالها» (B-01) narrows the profiles waiting for review: the
    // ones sent back after changes, or the others.
    if (filter.resubmitted !== null) {
      and.push({ status: { in: [ProviderStatus.PENDING] } });
      and.push({
        resubmittedAt: filter.resubmitted ? { not: null } : null,
      });
    }
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
      const key = arabicSearchKey(filter.search.text);
      const named = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT p."id" FROM "Provider" p
        WHERE strpos(translate(lower(concat_ws(chr(1), p."businessName", p."ownerName")),
                ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0`);
      and.push({
        OR: [
          { id: { in: named.map((row) => row.id) } },
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
  ): Promise<{ userId: string | null; status: ProviderStatus; phone: string } | null> {
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
      select: { userId: true, status: true, phone: true },
    });
  }

  async hasJoiningService(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<boolean> {
    return hasJoiningService(client, providerId);
  }

  async recordProviderReviewInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    decision: ProviderReviewDecision,
  ): Promise<AdminProviderDetailRow> {
    await recordProviderReviewEvent(tx, {
      providerId,
      kind: decision.kind,
      actorId: decision.reviewedById,
      createdAt: decision.reviewedAt,
      notes: decision.notes,
    });
    return tx.provider.update({
      where: { id: providerId },
      data: {
        status: decision.status,
        reviewedAt: decision.reviewedAt,
        reviewedById: decision.reviewedById,
      },
      include: providerDetailInclude,
    });
  }

  async listProviderReviewEvents(
    client: Prisma.TransactionClient,
    providerId: string,
  ): Promise<AdminProviderReviewEvent[]> {
    return listProviderReviewEvents(client, providerId);
  }

  async listClaimRequests(
    client: Prisma.TransactionClient,
    filter: AdminClaimRequestFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminClaimRequestRow>> {
    const where = filter.status ? { status: filter.status } : {};
    const total = await client.providerClaimRequest.count({ where });
    const items = await client.providerClaimRequest.findMany({
      where,
      include: { provider: true },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async findClaimRequestParties(
    client: Prisma.TransactionClient,
    claimId: string,
  ): Promise<{ userId: string; providerId: string } | null> {
    return client.providerClaimRequest.findUnique({
      where: { id: claimId },
      select: { userId: true, providerId: true },
    });
  }

  async lockClaimRequestForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
  ): Promise<ProviderClaimRequest | null> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ProviderClaimRequest"
        WHERE "id" = ${claimId}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) return null;
    return tx.providerClaimRequest.findUnique({ where: { id: claimId } });
  }

  async decideClaimRequestInTransaction(
    tx: Prisma.TransactionClient,
    claimId: string,
    decision: ProviderClaimDecision,
  ): Promise<AdminClaimRequestRow> {
    return tx.providerClaimRequest.update({
      where: { id: claimId },
      data: {
        status: decision.status,
        note: decision.note,
        decidedAt: decision.decidedAt,
        decidedById: decision.decidedById,
      },
      include: { provider: true },
    });
  }

  async linkClaimedListingInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    userId: string,
  ): Promise<void> {
    await tx.provider.update({ where: { id: providerId }, data: { userId } });
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

  async getSuccessCounts(
    client: Prisma.TransactionClient,
    since: Date,
  ): Promise<AdminMarketplaceSuccessCounts> {
    const [quoteRequests, confirmedBookings, visibleProviders] = await Promise.all([
      client.quoteRequest.count({ where: { createdAt: { gte: since } } }),
      client.booking.count({
        where: { createdAt: { gte: since }, status: BookingStatus.CONFIRMED },
      }),
      client.provider.count({
        where: { status: ProviderStatus.ACTIVE, services: { some: { isActive: true } } },
      }),
    ]);
    return { quoteRequests, confirmedBookings, visibleProviders };
  }

  async listPricedServices(client: Prisma.TransactionClient): Promise<PricedService[]> {
    return listPricedServices(client);
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
      const key = arabicSearchKey(filter.search);
      and.push({
        OR: [
          { id: { in: await findServiceIdsMatchingSearch(client, key) } },
          { provider: { phone: textMatch(filter.search) } },
        ],
      });
    }
    const where = { AND: and };
    const total = await client.providerService.count({ where });
    const items = await client.providerService.findMany({
      where,
      include: serviceInclude,
      // Newest first; the id makes the order total across pages.
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
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

  async settleBookingsOnSuspensionInTransaction(
    tx: Prisma.TransactionClient,
    providerId: string,
    suspendedAt: Date,
  ): Promise<CreateNotificationInput[]> {
    // The row every booking decision locks first (marketplace-write-locks).
    const provider = await lockMarketplaceProvider(tx, providerId, 'UPDATE');
    const open = await bookingStore.listOpenBookingRequests(tx, providerId);
    await bookingStore.expireOpenBookingRequests(
      tx,
      providerId,
      open.map((booking) => booking.id),
      suspendedAt,
    );
    const kept = await bookingStore.listUpcomingConfirmedBookings(
      tx,
      providerId,
      bookingToday(suspendedAt),
    );
    return [
      ...open.map((booking) => ({ booking, confirmed: false })),
      ...kept.map((booking) => ({ booking, confirmed: true })),
    ].map(({ booking, confirmed }) =>
      providerSuspendedCustomerNotification({
        bookingId: booking.id,
        quoteRequestId: booking.quoteRequestId,
        providerId,
        eventDate: booking.eventDate,
        customerUserId: booking.quoteRequest.userId,
        weddingPlanId: booking.quoteRequest.weddingPlanId,
        providerName: provider.businessName,
        confirmed,
        at: suspendedAt,
      }),
    );
  }

  async listBookings(
    client: Prisma.TransactionClient,
    filter: AdminBookingFilter,
    page: AdminPage,
  ): Promise<AdminListing<AdminBookingRow>> {
    const eventDate =
      filter.from || filter.to
        ? {
            ...(filter.from ? { gte: filter.from } : {}),
            ...(filter.to ? { lte: filter.to } : {}),
          }
        : null;
    const total = await client.booking.count({
      where: {
        ...(filter.providerId ? { providerId: filter.providerId } : {}),
        ...(filter.status ? { status: filter.status } : {}),
        ...(eventDate ? { eventDate } : {}),
      },
    });
    const items = await client.booking.findMany({
      where: {
        ...(filter.providerId ? { providerId: filter.providerId } : {}),
        ...(filter.status ? { status: filter.status } : {}),
        ...(eventDate ? { eventDate } : {}),
      },
      include: {
        provider: { select: { id: true, businessName: true, status: true } },
        quoteRequest: {
          select: { id: true, userId: true, weddingPlanId: true, contactName: true, guestCount: true },
        },
      },
      orderBy: [{ eventDate: 'desc' }, { id: 'asc' }],
      skip: page.skip,
      take: page.take,
    });
    return { total, items: items.map(withLifecycle) };
  }

  async getBooking(client: Prisma.TransactionClient, id: string): Promise<AdminBookingRow | null> {
    const booking = await client.booking.findUnique({
      where: { id },
      include: {
        provider: { select: { id: true, businessName: true, status: true } },
        quoteRequest: {
          select: { id: true, userId: true, weddingPlanId: true, contactName: true, guestCount: true },
        },
      },
    });
    return booking ? withLifecycle(booking) : null;
  }

  // n07 (B-16): the portfolio photos and their decisions.
  async listPortfolioForReview(
    client: Prisma.TransactionClient,
    status: PortfolioItemStatus,
    page: { skip: number; take: number },
  ) {
    return portfolioStore.listPortfolioForReview(client, status, page);
  }

  async lockPortfolioItemInTransaction(tx: Prisma.TransactionClient, id: string) {
    return portfolioStore.lockPortfolioItem(tx, id);
  }

  async decidePortfolioItemInTransaction(
    tx: Prisma.TransactionClient,
    id: string,
    decision: AdminPortfolioDecision,
  ) {
    return portfolioStore.decidePortfolioItem(tx, id, decision);
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
      const key = arabicSearchKey(filter.search.text);
      const matched = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT r."id" FROM "ProviderReview" r
        JOIN "Provider" p ON p."id" = r."providerId"
        WHERE strpos(translate(lower(concat_ws(chr(1), r."comment", p."businessName")),
                ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0`);
      and.push({
        OR: [
          { id: { in: matched.map((row) => row.id) } },
          { userId: { in: [...filter.search.userIds] } },
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

  async setReviewReplyStatusInTransaction(
    tx: Prisma.TransactionClient,
    reviewId: string,
    status: ReviewStatus,
  ): Promise<AdminReviewRow | null> {
    const changed = await tx.providerReview.updateMany({
      where: { id: reviewId, replyBody: { not: null } },
      data: { replyStatus: status },
    });
    if (changed.count !== 1) return null;
    return tx.providerReview.findUniqueOrThrow({
      where: { id: reviewId },
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

  async listFeaturedPeriods(
    client: Prisma.TransactionClient,
    filter: AdminFeaturedPeriodFilter,
    page: AdminPage,
    now: Date,
  ): Promise<AdminListing<AdminFeaturedPeriodRow>> {
    return featured.listFeaturedPeriods(client, filter, page, now);
  }

  async getFeaturedSummary(
    client: Prisma.TransactionClient,
    now: Date,
    weekEnd: Date,
  ): Promise<AdminFeaturedSummary> {
    return featured.countFeaturedSummary(client, now, weekEnd);
  }

  async listFeaturedShownProviderIds(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<string[]> {
    return featured.listFeaturedShownProviderIds(client, providerIds);
  }

  async listActiveFeaturedPeriods(
    client: Prisma.TransactionClient,
    providerIds: readonly string[],
    now: Date,
  ): Promise<AdminActiveFeaturedPeriod[]> {
    return featured.listActiveFeaturedPeriods(client, providerIds, now);
  }

  async findOverlappingFeaturedPeriod(
    tx: Prisma.TransactionClient,
    providerId: string,
    startsAt: Date,
    endsAt: Date,
  ): Promise<{ id: string; startsAt: Date; endsAt: Date } | null> {
    return featured.findOverlappingFeaturedPeriod(tx, providerId, startsAt, endsAt);
  }

  async createFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    fields: FeaturedPeriodGrantFields,
  ): Promise<AdminFeaturedPeriodRow> {
    return featured.createFeaturedPeriod(tx, fields);
  }

  async lockFeaturedPeriodForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
  ): Promise<AdminFeaturedPeriodRow | null> {
    return featured.lockFeaturedPeriodForUpdate(tx, periodId);
  }

  async endFeaturedPeriodInTransaction(
    tx: Prisma.TransactionClient,
    periodId: string,
    fields: FeaturedPeriodEndFields,
  ): Promise<AdminFeaturedPeriodRow | null> {
    const ended = await featured.endFeaturedPeriod(tx, periodId, fields);
    if (ended.count !== 1) return null;
    return featured.findFeaturedPeriod(tx, periodId);
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
        // Featured now (B-43), by the placement rule.
        client.provider.count({
          where: {
            AND: [{ createdAt }, ...featuredNowProviderWhere(new Date()).AND],
          },
        }),
      ]);
    return { total, pending, active, needsChanges, suspended, rejected, featured };
  }

  private async serviceReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminMarketplaceReport['services']> {
    const [total, active, disabled] = await Promise.all([
      client.providerService.count({ where: { createdAt } }),
      client.providerService.count({ where: { createdAt, isActive: true } }),
      client.providerService.count({ where: { createdAt, isActive: false } }),
    ]);
    return { total, active, disabled };
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
