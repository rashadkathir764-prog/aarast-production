import { Prisma, ProviderStatus, ReviewStatus } from "@prisma/client";
import type {
  MarketplacePagination,
  MyQuoteAccessWhere,
  ProviderSearchWhere,
  ServiceSearchWhere,
} from "../../../marketplace/marketplace.contracts";
import { MARKETPLACE_QUOTE_INCLUDE } from "../../../marketplace/marketplace.contracts";
import {
  responsivenessWindow,
  summarizeResponsiveness,
  type ProviderResponseSample,
} from "../../../marketplace/provider-responsiveness";
import { profileCompleteness, rankProviders } from "../../../marketplace/provider-ranking";
import { ARABIC_FOLD_FROM, ARABIC_FOLD_TO } from "../../../shared-kernel/text/arabic-search";
import { activeFeaturedPeriodInclude } from "../public/featured-placement";

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

/**
 * The customers' list: providers featured at `now` first (B-43), then the
 * rest, each group in the order the ranking gives (RA-BE-151: smoothed
 * rating, profile, response, a lift for new ones, claimed listings before
 * unclaimed ones; ties by age and id, a total order, so a page never skips
 * or repeats a provider inside one snapshot). "Featured" is read from the
 * periods at request time by the placement rule (`where` is already the
 * listed providers); a row of the other group is never «مميز», even with a
 * period running (an unclaimed listing).
 *
 * The score reads the response history, which no column holds, so the
 * listed providers' few signals are read whole, ranked here, and only the
 * page's rows are read in full.
 */
export async function searchActiveProviders(client: Client, where: ProviderSearchWhere, pagination: MarketplacePagination, now: Date) {
  const candidates = await client.provider.findMany({
    where,
    select: {
      id: true,
      userId: true,
      ratingAverage: true,
      ratingCount: true,
      createdAt: true,
      logoUrl: true,
      coverUrl: true,
      description: true,
      address: true,
      whatsapp: true,
      socialLinks: true,
      featuredPeriods: activeFeaturedPeriodInclude(now),
    },
  });
  const samples = await providerResponseSamples(
    client,
    candidates.map((row) => row.id),
    responsivenessWindow(now),
  );
  const ranked = rankProviders(
    candidates.map((row) => ({
      id: row.id,
      claimed: row.userId !== null,
      featuredNow: row.userId !== null && row.featuredPeriods.length > 0,
      createdAt: row.createdAt,
      ratingAverage: Number(row.ratingAverage),
      ratingCount: row.ratingCount,
      profile: profileCompleteness(row),
      response: summarizeResponsiveness(
        samples.get(row.id) ?? { requests: 0, answered: 0, medianMinutes: null },
      ),
    })),
    now,
  );
  const pageIds = ranked.slice(pagination.skip, pagination.skip + pagination.limit);
  if (pageIds.length === 0) return [];
  const featuredIds = new Set(
    ranked.filter((row) => row.featuredNow).map((row) => row.id),
  );
  const rows = await client.provider.findMany({
    where: { id: { in: pageIds.map((row) => row.id) } },
    include: {
      services: {
        where: { isActive: true }, orderBy: [{ createdAt: "desc" }, { id: "asc" }],
        select: { title: true, basePrice: true, currency: true, priceUpdatedAt: true, categoryId: true },
      },
      featuredPeriods: activeFeaturedPeriodInclude(now),
    },
  });
  const byId = new Map(rows.map((row) => [row.id, row]));
  return pageIds.flatMap(({ id }) => {
    const row = byId.get(id);
    if (!row) return [];
    return [featuredIds.has(id) ? row : { ...row, featuredPeriods: [] }];
  });
}

export function findActiveProviderWithServices(client: Client, id: string, now: Date) {
  return client.provider.findFirst({
    where: { id, status: ProviderStatus.ACTIVE },
    include: {
      // RA-BE-12 (D62): a service's own photos are never public.
      services: {
        where: { isActive: true },
        orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      },
      featuredPeriods: activeFeaturedPeriodInclude(now),
    },
  });
}

/**
 * The providers' quote requests since `since` that count toward their
 * response time: answered ones, and unanswered ones that were neither
 * cancelled nor made after `settledBefore` (still inside the grace period).
 * An offer the provider withdrew (B-03) is no answer: the request is
 * answered by the first offer that still stands. A provider with no such
 * request has no entry.
 */
export async function providerResponseSamples(
  client: Client,
  providerIds: readonly string[],
  window: { since: Date; settledBefore: Date },
): Promise<Map<string, ProviderResponseSample>> {
  if (providerIds.length === 0) return new Map();
  const rows = await client.$queryRaw<
    Array<{ providerId: string; requests: bigint; answered: bigint; medianMinutes: number | null }>
  >(Prisma.sql`
    SELECT
      q."providerId" AS "providerId",
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
    WHERE q."providerId" IN (${Prisma.join([...providerIds])})
      AND q."createdAt" >= ${window.since}
      AND (
        o."firstOfferAt" IS NOT NULL
        OR (q."status" <> 'CANCELLED' AND q."createdAt" < ${window.settledBefore})
      )
    GROUP BY q."providerId"
  `);
  return new Map(
    rows.map((row) => [
      row.providerId,
      {
        requests: Number(row.requests),
        answered: Number(row.answered),
        medianMinutes: row.medianMinutes,
      },
    ]),
  );
}

export async function providerResponseSample(
  client: Client,
  providerId: string,
  window: { since: Date; settledBefore: Date },
): Promise<ProviderResponseSample> {
  return (
    (await providerResponseSamples(client, [providerId], window)).get(providerId) ?? {
      requests: 0,
      answered: 0,
      medianMinutes: null,
    }
  );
}

export function listActiveProviderServices(client: Client, providerId: string) {
  return client.providerService.findMany({
    where: { providerId, isActive: true },
    include: { provider: true },
    orderBy: [{ createdAt: "desc" }, { id: "asc" }],
  });
}

export function countActiveServices(client: Client, where: ServiceSearchWhere) {
  return client.providerService.count({ where });
}

export function searchActiveServices(client: Client, where: ServiceSearchWhere, pagination: MarketplacePagination) {
  return client.providerService.findMany({
      where,
      include: { provider: true },
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
    include: { provider: true },
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

/** RA-ST-05: a published review as a report reads it: its author. */
export function findPublishedReviewForReport(client: Client, id: string) {
  return client.providerReview.findFirst({
    where: { id, status: ReviewStatus.PUBLISHED },
    select: { id: true, userId: true },
  });
}

/** RA-ST-05: one report per reporter and review; again, the reason is updated and it reopens. */
export function saveReviewReport(client: Client, reviewId: string, reporterUserId: string, reason: string) {
  return client.reviewReport.upsert({
    where: { reviewId_reporterUserId: { reviewId, reporterUserId } },
    create: { reviewId, reporterUserId, reason },
    update: { reason, resolvedAt: null },
    select: { id: true },
  });
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
