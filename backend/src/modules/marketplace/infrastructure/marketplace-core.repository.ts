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
import {
  orderProviders,
  profileCompleteness,
  type ProviderSort,
} from "../../../marketplace/provider-ranking";
import { activeFeaturedPeriodInclude } from "../public/featured-placement";
import { likePatternContaining } from "../../../shared-kernel/text/arabic-search";

type Client = Prisma.TransactionClient;


/**
 * RA-BE-09, RA-BE-181: the providers whose name, owner, description or
 * address, or an active service's title or description, holds the search
 * folded as the phone folds it (shared-kernel/text/arabic-search). The text
 * is matched with LIKE against the folded text that three trigram indexes
 * hold (migration 20261125130000_search_and_invite_indexes: the
 * `aarast_*_search_text` functions are the folding in SQL, equal to
 * arabicSearchKey), so the table is no longer read row by row; a key of one
 * or two letters has no trigram and is still answered, by a scan. The
 * listing rules still apply on top (the caller's where).
 */
export async function findProviderIdsMatchingSearch(client: Client, key: string): Promise<string[]> {
  const pattern = likePatternContaining(key);
  const rows = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT p."id" FROM "Provider" p
    WHERE "aarast_provider_search_text"(p."businessName", p."ownerName", p."description", p."address") LIKE ${pattern}
    UNION
    SELECT s."providerId" AS "id" FROM "ProviderService" s
    WHERE s."isActive" = true
      AND "aarast_service_search_text"(s."title", s."description") LIKE ${pattern}`);
  return rows.map((row) => row.id);
}

/**
 * RA-BE-09, RA-BE-181: the services whose title or description, or provider's
 * name, holds the folded search; each on its own trigram index.
 */
export async function findServiceIdsMatchingSearch(client: Client, key: string): Promise<string[]> {
  const pattern = likePatternContaining(key);
  const rows = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT s."id" FROM "ProviderService" s
    WHERE "aarast_service_search_text"(s."title", s."description") LIKE ${pattern}
    UNION
    SELECT s."id" FROM "ProviderService" s
    JOIN "Provider" p ON p."id" = s."providerId"
    WHERE "aarast_search_fold"(p."businessName") LIKE ${pattern}`);
  return rows.map((row) => row.id);
}

/**
 * The customers' list in the order they picked (D131,
 * docs/project/PROVIDER_RANKING.md). «الأنسب»: verified providers before
 * unverified ones (Q-73); inside each band those featured at `now` (B-43),
 * then claimed listings, then unclaimed ones; inside each group the score
 * (RA-BE-151: smoothed rating, profile, response, a lift for new ones);
 * ties by age and id, a total order, so a page never skips or repeats a
 * provider inside one snapshot. «الأعلى تقييمًا» and «الأقل سعرًا» order by
 * what they say, ties in «الأنسب»'s order (`orderProviders`). "Featured" is read from the
 * periods at request time by the placement rule (`where` is already the
 * listed providers); a row of the other group is never «مميز», even with a
 * period running (an unclaimed listing).
 *
 * The score reads the response history, which no column holds, so the
 * listed providers' few signals are read whole, ranked here, and only the
 * page's rows are read in full.
 */
export async function searchActiveProviders(
  client: Client,
  where: ProviderSearchWhere,
  pagination: MarketplacePagination,
  now: Date,
  sort: ProviderSort = "best",
) {
  const candidates = await client.provider.findMany({
    where,
    select: {
      id: true,
      userId: true,
      verifiedAt: true,
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
      // D131: «الأقل سعرًا» compares his rial prices.
      services: {
        where: { isActive: true, basePrice: { not: null }, currency: "YER" },
        select: { basePrice: true },
      },
    },
  });
  const samples = await providerResponseSamples(
    client,
    candidates.map((row) => row.id),
    responsivenessWindow(now),
  );
  const ranked = orderProviders(
    candidates.map((row) => ({
      id: row.id,
      claimed: row.userId !== null,
      verified: row.verifiedAt != null,
      featuredNow: row.userId !== null && row.featuredPeriods.length > 0,
      createdAt: row.createdAt,
      ratingAverage: Number(row.ratingAverage),
      ratingCount: row.ratingCount,
      profile: profileCompleteness(row),
      response: summarizeResponsiveness(
        samples.get(row.id) ?? { requests: 0, answered: 0, medianMinutes: null },
      ),
      lowestPriceYer: lowestPrice(row.services),
    })),
    sort,
    now,
  );
  // RA-BE-181: every listed provider is a candidate, so the total of the
  // filter is how many there are; a second count of it was a second pass.
  const total = ranked.length;
  const pageIds = ranked.slice(pagination.skip, pagination.skip + pagination.limit);
  if (pageIds.length === 0) return { total, rows: [] };
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
  const pageRows = pageIds.flatMap(({ id }) => {
    const row = byId.get(id);
    if (!row) return [];
    return [featuredIds.has(id) ? row : { ...row, featuredPeriods: [] }];
  });
  return { total, rows: pageRows };
}

/** D131: the ids of the providers [where] lists, for the busy to be left out of them. */
export async function listListedProviderIds(client: Client, where: ProviderSearchWhere): Promise<string[]> {
  const rows = await client.provider.findMany({ where, select: { id: true } });
  return rows.map((row) => row.id);
}

/**
 * D131 (F8): each listed provider's categories, his main one and every
 * active service's, for the category chips' counts.
 */
export async function listListedProviderCategories(
  client: Client,
  where: ProviderSearchWhere,
): Promise<string[][]> {
  const rows = await client.provider.findMany({
    where,
    select: {
      primaryCategoryId: true,
      services: { where: { isActive: true }, select: { categoryId: true } },
    },
  });
  return rows.map((row) => [
    ...new Set([
      ...(row.primaryCategoryId ? [row.primaryCategoryId] : []),
      ...row.services.flatMap((service) => (service.categoryId ? [service.categoryId] : [])),
    ]),
  ]);
}

/** His lowest priced active rial service, or null (a fake client may send no services). */
function lowestPrice(
  services: ReadonlyArray<{ basePrice: Prisma.Decimal | null }> | undefined,
): number | null {
  let lowest: number | null = null;
  for (const service of services ?? []) {
    if (service.basePrice === null) continue;
    const price = Number(service.basePrice);
    if (lowest === null || price < lowest) lowest = price;
  }
  return lowest;
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
