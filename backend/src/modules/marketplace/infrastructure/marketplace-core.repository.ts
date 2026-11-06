import { Prisma, ProviderStatus, ReviewStatus } from "@prisma/client";
import type {
  MarketplacePagination,
  MyQuoteAccessWhere,
  ProviderSearchWhere,
  ServiceSearchWhere,
} from "../../../marketplace/marketplace.contracts";
import { MARKETPLACE_QUOTE_INCLUDE } from "../../../marketplace/marketplace.contracts";
import type { ProviderResponseSample } from "../../../marketplace/provider-responsiveness";
import { ARABIC_FOLD_FROM, ARABIC_FOLD_TO } from "../../../shared-kernel/text/arabic-search";
import {
  activeFeaturedPeriodInclude,
  featuredNowConditions,
  notFeaturedNowCondition,
} from "../public/featured-placement";

type Client = Prisma.TransactionClient;

/**
 * RA-BE-09: the providers whose name, owner, description or address, or an
 * active service's title or description, holds the search folded as the
 * phone folds it (shared-kernel/text/arabic-search). The listing rules still
 * apply on top (the caller's where).
 */
export async function findProviderIdsMatchingSearch(client: Client, key: string): Promise<string[]> {
  const rows = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT p."id" FROM "Provider" p
    WHERE strpos(translate(lower(concat_ws(chr(1), p."businessName", p."ownerName", p."description", p."address")),
            ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0
       OR EXISTS (
         SELECT 1 FROM "ProviderService" s
         WHERE s."providerId" = p."id" AND s."isActive" = true
           AND strpos(translate(lower(concat_ws(chr(1), s."title", s."description")),
                 ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0
       )`);
  return rows.map((row) => row.id);
}

/** RA-BE-09: the services whose title or description, or provider's name, holds the folded search. */
export async function findServiceIdsMatchingSearch(client: Client, key: string): Promise<string[]> {
  const rows = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT s."id" FROM "ProviderService" s
    JOIN "Provider" p ON p."id" = s."providerId"
    WHERE strpos(translate(lower(concat_ws(chr(1), s."title", s."description", p."businessName")),
            ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0`);
  return rows.map((row) => row.id);
}

export function countActiveProviders(client: Client, where: ProviderSearchWhere) {
  return client.provider.count({ where });
}

function searchProviderPage(client: Client, where: ProviderSearchWhere, now: Date, skip: number, take: number) {
  return client.provider.findMany({
    where,
    include: {
      services: {
        where: { isActive: true }, orderBy: [{ createdAt: "desc" }, { id: "asc" }],
        select: { title: true, basePrice: true, currency: true, priceUpdatedAt: true, categoryId: true },
      },
      featuredPeriods: activeFeaturedPeriodInclude(now),
    },
    orderBy: [
      { ratingAverage: "desc" },
      { createdAt: "desc" },
      { id: "asc" },
    ],
    skip,
    take,
  });
}

/**
 * The customers' list: providers featured at `now` first (B-43), then the
 * rest, each group by rating, age and id (a total order, so a page never
 * skips or repeats a provider inside one snapshot). "Featured" is read from
 * the periods at request time by the placement rule (`where` is already the
 * listed providers), so the page is cut across the two groups here: the
 * featured rows fill the page first and the others continue after them. A
 * row of the other group is never «مميز», even with a period running (an
 * unclaimed listing).
 */
export async function searchActiveProviders(client: Client, where: ProviderSearchWhere, pagination: MarketplacePagination, now: Date) {
  const featuredWhere: ProviderSearchWhere = { AND: [...where.AND, ...featuredNowConditions(now)] };
  const regularWhere: ProviderSearchWhere = { AND: [...where.AND, notFeaturedNowCondition(now)] };
  const featuredCount = await client.provider.count({ where: featuredWhere });
  const featured = pagination.skip < featuredCount
    ? await searchProviderPage(client, featuredWhere, now, pagination.skip, pagination.limit)
    : [];
  const room = pagination.limit - featured.length;
  if (room <= 0) return featured;
  const regular = await searchProviderPage(
    client,
    regularWhere,
    now,
    Math.max(0, pagination.skip - featuredCount),
    room,
  );
  return [...featured, ...regular.map((row) => ({ ...row, featuredPeriods: [] }))];
}

export function findActiveProviderWithServices(client: Client, id: string, now: Date) {
  return client.provider.findFirst({
    where: { id, status: ProviderStatus.ACTIVE },
    include: {
      services: {
        where: { isActive: true },
        include: { images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] } },
        orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      },
      featuredPeriods: activeFeaturedPeriodInclude(now),
    },
  });
}

/**
 * The provider's quote requests since `since` that count toward its response
 * time: answered ones, and unanswered ones that were neither cancelled nor
 * made after `settledBefore` (still inside the grace period). An offer the
 * provider withdrew (B-03) is no answer: the request is answered by the
 * first offer that still stands.
 */
export async function providerResponseSample(
  client: Client,
  providerId: string,
  window: { since: Date; settledBefore: Date },
): Promise<ProviderResponseSample> {
  const rows = await client.$queryRaw<
    Array<{ requests: bigint; answered: bigint; medianMinutes: number | null }>
  >(Prisma.sql`
    SELECT
      COUNT(*) AS "requests",
      COUNT(o."firstOfferAt") AS "answered",
      percentile_cont(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (o."firstOfferAt" - q."createdAt")) / 60
      ) AS "medianMinutes"
    FROM "QuoteRequest" q
    LEFT JOIN (
      SELECT "quoteRequestId", MIN("createdAt") AS "firstOfferAt"
      FROM "QuoteOffer"
      WHERE "status" <> 'WITHDRAWN'
      GROUP BY "quoteRequestId"
    ) o ON o."quoteRequestId" = q."id"
    WHERE q."providerId" = ${providerId}
      AND q."createdAt" >= ${window.since}
      AND (
        o."firstOfferAt" IS NOT NULL
        OR (q."status" <> 'CANCELLED' AND q."createdAt" < ${window.settledBefore})
      )
  `);
  const row = rows[0];
  return {
    requests: Number(row?.requests ?? 0),
    answered: Number(row?.answered ?? 0),
    medianMinutes: row?.medianMinutes ?? null,
  };
}

export function listActiveProviderServices(client: Client, providerId: string) {
  return client.providerService.findMany({
    where: { providerId, isActive: true },
    include: {
      provider: true,
      images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
    },
    orderBy: [{ createdAt: "desc" }, { id: "asc" }],
  });
}

export function countActiveServices(client: Client, where: ServiceSearchWhere) {
  return client.providerService.count({ where });
}

export function searchActiveServices(client: Client, where: ServiceSearchWhere, pagination: MarketplacePagination) {
  return client.providerService.findMany({
      where,
      include: {
        provider: true,
        images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
      },
      // Cheapest first, then newest; the id makes the order total, so a page
      // never skips or repeats a service.
      orderBy: [
        { basePrice: "asc" },
        { createdAt: "desc" },
        { id: "asc" },
      ],
      skip: pagination.skip,
      take: pagination.limit,
  });
}

export function findActiveService(client: Client, id: string) {
  return client.providerService.findFirst({
    where: { id, isActive: true, provider: { status: ProviderStatus.ACTIVE } },
    include: {
      provider: true,
      images: { orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }] },
    },
  });
}

export function listActiveProviderPackages(client: Client, providerId: string) {
  return client.providerPackage.findMany({
    where: { providerId, isActive: true },
    include: { service: true },
    orderBy: { createdAt: "desc" },
  });
}

export function listPublishedProviderReviews(client: Client, providerId: string) {
  return client.providerReview.findMany({
    where: { providerId, status: ReviewStatus.PUBLISHED },
    orderBy: { createdAt: "desc" },
  });
}

export function findProviderAccountForFavorite(client: Client, providerId: string) {
  return client.provider.findUnique({ where: { id: providerId }, select: { userId: true } });
}

export function saveFavoriteProvider(client: Client, userId: string, providerId: string, now: Date) {
  return client.favoriteProvider.upsert({
    where: { userId_providerId: { userId, providerId } },
    create: { userId, providerId },
    update: {},
    include: { provider: { include: { featuredPeriods: activeFeaturedPeriodInclude(now) } } },
  });
}

export function deleteFavoriteProvider(client: Client, userId: string, providerId: string) {
  return client.favoriteProvider.deleteMany({ where: { userId, providerId } });
}

export function listMyActiveFavoriteProviders(client: Client, userId: string, now: Date) {
  return client.favoriteProvider.findMany({
    where: { userId, provider: { status: ProviderStatus.ACTIVE } },
    include: { provider: { include: { featuredPeriods: activeFeaturedPeriodInclude(now) } } },
    orderBy: { createdAt: "desc" },
  });
}

export function listPlanQuoteRequests(
  client: Client,
  weddingPlanId: string,
  quoteIds: readonly string[] | null,
  liveFilter: { id?: { in: string[] } },
) {
  return client.quoteRequest.findMany({
    where: {
      weddingPlanId,
      ...(quoteIds ? { id: { in: [...quoteIds] } } : {}),
      ...liveFilter,
    },
    include: MARKETPLACE_QUOTE_INCLUDE,
    orderBy: { createdAt: "desc" },
  });
}

export function listMyQuoteRequests(client: Client, where: MyQuoteAccessWhere) {
  return client.quoteRequest.findMany({
    where,
    include: MARKETPLACE_QUOTE_INCLUDE,
    orderBy: { createdAt: "desc" },
  });
}

export function findMyQuoteRequest(client: Client, where: MyQuoteAccessWhere) {
  return client.quoteRequest.findFirst({ where, include: MARKETPLACE_QUOTE_INCLUDE });
}

export function findReviewForUser(client: Client, id: string, userId: string) {
  return client.providerReview.findFirst({ where: { id, userId } });
}

export function findProviderForReview(client: Client, providerId: string) {
  return client.provider.findUnique({ where: { id: providerId } });
}

export function findExistingProviderReview(client: Client, userId: string, providerId: string) {
  return client.providerReview.findUnique({ where: { userId_providerId: { userId, providerId } } });
}

export function createProviderReview(client: Client, userId: string, providerId: string, rating: number, comment: string | null) {
  return client.providerReview.create({ data: { userId, providerId, rating, comment } });
}

export function updateProviderReview(client: Client, id: string, changes: { rating?: number; comment?: string | null }) {
  return client.providerReview.update({ where: { id }, data: changes });
}

export function deleteProviderReview(client: Client, id: string) {
  return client.providerReview.delete({ where: { id } });
}

export function findActiveProvider(client: Client, id: string) {
  return client.provider.findFirst({ where: { id, status: ProviderStatus.ACTIVE } });
}

export function findActiveServiceForProvider(client: Client, id: string, providerId: string) {
  return client.providerService.findFirst({
    where: { id, providerId, isActive: true, provider: { status: ProviderStatus.ACTIVE } },
  });
}

export function findQuoteRequestSeed(client: Client, id: string) {
  return client.quoteRequest.findUnique({ where: { id }, select: { id: true, weddingPlanId: true } });
}

export function findPersonalQuoteRequest(client: Client, id: string, userId: string) {
  return client.quoteRequest.findFirst({
    where: { id, userId, weddingPlanId: null },
    include: MARKETPLACE_QUOTE_INCLUDE,
  });
}

export function findQuoteOfferWithRequest(client: Client, id: string) {
  return client.quoteOffer.findUnique({ where: { id }, include: { quoteRequest: true } });
}

/**
 * Counts one view of a listed provider's page on `day` (V1 checklist 4.19):
 * one statement, so concurrent first views of a day cannot collide. Returns
 * 0 when the provider is not active (nothing is counted).
 */
export function recordProviderProfileView(client: Client, providerId: string, day: string) {
  return client.$executeRaw`
    INSERT INTO "ProviderProfileViewDay" ("providerId", "day", "views")
    SELECT "id", ${day}::date, 1 FROM "Provider"
    WHERE "id" = ${providerId} AND "status" = 'ACTIVE'
    ON CONFLICT ("providerId", "day")
    DO UPDATE SET "views" = "ProviderProfileViewDay"."views" + 1`;
}
