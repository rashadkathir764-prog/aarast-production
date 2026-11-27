import { Prisma } from "@prisma/client";
import * as core from "../modules/marketplace/infrastructure/marketplace-core.repository";
import type { PrismaService } from "../platform/database/prisma.service";
import type { ListProviderReviewsQueryDto } from "./dto/list-provider-reviews-query.dto";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import { MarketplacePresenter, MarketplaceQuery } from "./marketplace.presenter";

// A provider's reviews a page at a time, with what they add up to (2026-11-26
// review): a provider with years of reviews sent them all on every open of
// his page, and the page could not say how they spread over the stars.

export const REVIEWS_PAGE_DEFAULT = 10;
export const REVIEWS_PAGE_MAX = 50;

const STARS = [1, 2, 3, 4, 5] as const;

export interface ProviderReviewSummary {
  /** The average of the published reviews to two decimals; null with none. */
  average: number | null;
  count: number;
  /** How many published reviews gave each number of stars, 1 to 5. */
  distribution: Record<(typeof STARS)[number], number>;
}

/** The summary of every published review, from their count at each number of stars. */
export function reviewSummary(
  groups: ReadonlyArray<{ rating: number; count: number }>,
): ProviderReviewSummary {
  const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  let count = 0;
  let total = 0;
  for (const group of groups) {
    // A rating is 1 to 5 (CreateProviderReviewDto); another is not counted.
    if (!STARS.includes(group.rating as (typeof STARS)[number])) continue;
    distribution[group.rating as (typeof STARS)[number]] += group.count;
    count += group.count;
    total += group.rating * group.count;
  }
  return {
    average: count === 0 ? null : Math.round((total / count) * 100) / 100,
    count,
    distribution,
  };
}

/** `GET /providers/:id/reviews?page=&limit=`: one snapshot for the page, the total and the summary. */
export async function readProviderReviewPage(
  prisma: PrismaService,
  relations: MarketplaceRelationsService,
  providerId: string,
  query: ListProviderReviewsQueryDto,
) {
  const asked = MarketplaceQuery.parsePagination(
    query.page,
    query.limit ?? String(REVIEWS_PAGE_DEFAULT),
  );
  const limit = Math.min(asked.limit, REVIEWS_PAGE_MAX);
  const pagination = { page: asked.page, limit, skip: (asked.page - 1) * limit };
  const { rows, summary } = await prisma.$transaction(
    async (tx) => ({
      rows: await relations.attachReviewUsers(
        tx,
        await core.listPublishedProviderReviewsPage(tx, providerId, pagination),
      ),
      summary: reviewSummary(await core.countPublishedProviderReviewsByRating(tx, providerId)),
    }),
    { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
  );
  return {
    ...MarketplaceQuery.paginate(
      rows.map((review) => MarketplacePresenter.toReviewResponse(review)),
      summary.count,
      pagination,
    ),
    summary,
  };
}
