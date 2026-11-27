import { BadRequestException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import * as core from "../modules/marketplace/infrastructure/marketplace-core.repository";
import { listProvidersDayStatus } from "../modules/marketplace/infrastructure/marketplace-booking.repository";
import type { PrismaService } from "../platform/database/prisma.service";
import type { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import type { ProviderSearchWhere } from "./marketplace.contracts";
import { MarketplacePresenter, MarketplaceQuery } from "./marketplace.presenter";
import { providerCategoryIds } from "./provider-category-filter";
import { cardPhotoUrl, matchedCategoryId, pricedOffersInScope } from "./provider-list-scope";
import { PROVIDER_SORTS, type ProviderSort } from "./provider-ranking";

// The customers' provider directory (D131, docs/project/PROVIDER_RANKING.md):
// the ranked page in the order they picked, what is known of their wedding
// day, the busy left out when asked, and how many each category holds.

/**
 * D131: the order the customer picked (`sort`, default `best`) and whether
 * to leave out the busy (`hideBusy`, which needs `eventDate`), as they are
 * applied. Each is answered back (`sort`, `hideBusyApplied`), so the phone
 * says only what was done:
 * - «الأقل سعرًا» compares prices inside the asked categories only (2026-11-26
 *   review): with none asked a hall's price would stand beside a singer's,
 *   so `price` without a category is answered in `best`'s order. An app
 *   already out may send it, so it is not refused (RA-BE-01: a deploy adds,
 *   it never breaks).
 * - a day already past asks nothing of the calendar (no `availabilityDay`),
 *   so it hides nobody.
 */
export function providerDirectoryOptions(
  query: Pick<ListProvidersQueryDto, "sort" | "hideBusy" | "eventDate" | "categoryId" | "categoryIds">,
  availabilityDay: Date | null,
): { sort: ProviderSort; hideBusy: boolean } {
  const asked = (query.sort?.trim() || "best") as ProviderSort;
  if (!PROVIDER_SORTS.includes(asked)) {
    throw new BadRequestException(`sort must be one of: ${PROVIDER_SORTS.join(", ")}`);
  }
  const hideBusy = MarketplaceQuery.optionalBoolean(query.hideBusy, "hideBusy") === true;
  if (hideBusy && !query.eventDate?.trim()) {
    throw new BadRequestException("hideBusy needs eventDate");
  }
  const sort = asked === "price" && providerCategoryIds(query) === null ? "best" : asked;
  return { sort, hideBusy: hideBusy && availabilityDay !== null };
}

/**
 * D131: «أخفِ المشغولين يوم عرسي» leaves out the listed providers known to
 * take nothing on [day] (he closed it, or Aarast's bookings filled it).
 */
async function leaveOutBusy(
  tx: Prisma.TransactionClient,
  where: ProviderSearchWhere,
  day: Date,
): Promise<void> {
  const listed = await core.listListedProviderIds(tx, where);
  const busy = await listProvidersDayStatus(tx, listed, day);
  if (busy.size > 0) where.AND.push({ id: { notIn: [...busy.keys()] } });
}

/**
 * The page of the directory. One snapshot for the search and the ranked
 * page (B-43, RA-BE-151). RA-BE-09: the text is matched folded, as on the
 * phone. RA-BE-181: the total is the ranked candidates' count; there is no
 * second count query.
 */
export async function readProviderDirectoryPage(
  prisma: PrismaService,
  query: ListProvidersQueryDto,
  now: Date,
) {
  const { pagination, where, searchKey, availabilityDay } =
    MarketplaceQuery.providerSearch(query, now);
  const { sort, hideBusy } = providerDirectoryOptions(query, availabilityDay);
  const scope = providerCategoryIds(query);
  const [total, rows, dayStatus] = await prisma.$transaction(
    async (tx) => {
      if (searchKey) where.AND.push({ id: { in: await core.findProviderIdsMatchingSearch(tx, searchKey) } });
      // D131: the busy are left out before the ranking and the page, so
      // the total and every page agree.
      if (hideBusy && availabilityDay) await leaveOutBusy(tx, where, availabilityDay);
      const page = await core.searchActiveProviders(tx, where, pagination, now, sort, scope);
      // RA-BE-150 (Q-36), D131: what is known of the asked day, for the
      // rows of this page.
      const status = availabilityDay
        ? await listProvidersDayStatus(tx, page.rows.map((row) => row.id), availabilityDay)
        : null;
      return [page.total, page.rows, status] as const;
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
  );
  return { total, rows, dayStatus, pagination, sort, hideBusy, scope };
}

/**
 * `GET /api/v1/providers`: the page with each row's catalog, what it says
 * inside the asked categories (provider-list-scope.ts) and the day's status,
 * and the order and the hiding as applied.
 */
export async function readProviderDirectory(
  prisma: PrismaService,
  relations: MarketplaceRelationsService,
  query: ListProvidersQueryDto,
  now: Date,
) {
  const { total, rows, dayStatus, pagination, sort, hideBusy, scope } =
    await readProviderDirectoryPage(prisma, query, now);
  const listings = new Map(
    rows.map((row) => [
      row.id,
      {
        priceOffers: pricedOffersInScope(row, scope),
        matchedCategoryId: matchedCategoryId(row, scope),
        cardPhotoUrl: cardPhotoUrl(row),
      },
    ]),
  );
  // Catalog's city and category rows are attached after the own-table read.
  const providers = await relations.attachProviderListCatalog(
    prisma,
    rows.map(({ packages: _packages, portfolioItems: _photos, ...row }) => row),
  );
  return {
    ...MarketplaceQuery.paginate(
      providers.map((provider) => ({
        ...MarketplacePresenter.toProviderListResponse(provider, listings.get(provider.id)!),
        // D131: what is known of the asked day: CLOSED (he closed it) or
        // FULL (Aarast's bookings filled it); null with no day asked or
        // nothing known. Nothing here says he is free.
        dayStatus: dayStatus?.get(provider.id) ?? null,
        // RA-BE-150, kept for phones before D131: false when he is known to
        // be busy, null otherwise, so no phone says «فاضي» without proof.
        availableOnEventDate: dayStatus?.has(provider.id) ? false : null,
      })),
      total,
      pagination,
    ),
    // The order and the hiding as applied, so the phone names only those.
    sort,
    hideBusyApplied: hideBusy,
  };
}

/**
 * D131 (F8): how many providers each category holds under the same filter
 * as the list (city, search, featured, the day's busy left out), the
 * category itself apart, so the chips say what each one opens. A provider
 * counts in each category the list's filter finds him under
 * (`providerCategoryIdsOf`): `GET /providers?categoryId=` lists exactly
 * those counted here.
 */
export async function countProvidersByCategory(
  prisma: PrismaService,
  query: ListProvidersQueryDto,
  now: Date,
) {
  const { where, searchKey, availabilityDay } = MarketplaceQuery.providerSearch(
    { ...query, categoryId: undefined, categoryIds: undefined, page: undefined, limit: undefined },
    now,
  );
  // The order is no filter: a count reads none.
  const { hideBusy } = providerDirectoryOptions({ ...query, sort: undefined }, availabilityDay);
  return prisma.$transaction(
    async (tx) => {
      if (searchKey) where.AND.push({ id: { in: await core.findProviderIdsMatchingSearch(tx, searchKey) } });
      if (hideBusy && availabilityDay) await leaveOutBusy(tx, where, availabilityDay);
      const rows = await core.listListedProviderCategories(tx, where);
      const counts = new Map<string, number>();
      for (const categories of rows) {
        for (const id of categories) counts.set(id, (counts.get(id) ?? 0) + 1);
      }
      return {
        total: rows.length,
        categories: [...counts.entries()]
          .map(([categoryId, count]) => ({ categoryId, count }))
          .sort((a, b) => (a.categoryId < b.categoryId ? -1 : 1)),
      };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
  );
}
