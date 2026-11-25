import { BadRequestException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import * as core from "../modules/marketplace/infrastructure/marketplace-core.repository";
import { listProvidersDayStatus } from "../modules/marketplace/infrastructure/marketplace-booking.repository";
import type { PrismaService } from "../platform/database/prisma.service";
import type { ListProvidersQueryDto } from "./dto/list-providers-query.dto";
import type { ProviderSearchWhere } from "./marketplace.contracts";
import { MarketplaceQuery } from "./marketplace.presenter";
import { PROVIDER_SORTS, type ProviderSort } from "./provider-ranking";

// The customers' provider directory (D131, docs/project/PROVIDER_RANKING.md):
// the ranked page in the order they picked, what is known of their wedding
// day, the busy left out when asked, and how many each category holds. The
// marketplace service attaches the catalog rows and shapes the response.

/**
 * D131: the order the customer picked (`sort`, default `best`) and whether
 * to leave out the busy (`hideBusy`, which needs `eventDate`). A day already
 * past asks nothing of the calendar (no `availabilityDay`), so hides nobody.
 */
export function providerDirectoryOptions(
  query: Pick<ListProvidersQueryDto, "sort" | "hideBusy" | "eventDate">,
  availabilityDay: Date | null,
): { sort: ProviderSort; hideBusy: boolean } {
  const sort = (query.sort?.trim() || "best") as ProviderSort;
  if (!PROVIDER_SORTS.includes(sort)) {
    throw new BadRequestException(`sort must be one of: ${PROVIDER_SORTS.join(", ")}`);
  }
  const hideBusy = MarketplaceQuery.optionalBoolean(query.hideBusy, "hideBusy") === true;
  if (hideBusy && !query.eventDate?.trim()) {
    throw new BadRequestException("hideBusy needs eventDate");
  }
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
  const [total, rows, dayStatus] = await prisma.$transaction(
    async (tx) => {
      if (searchKey) where.AND.push({ id: { in: await core.findProviderIdsMatchingSearch(tx, searchKey) } });
      // D131: the busy are left out before the ranking and the page, so
      // the total and every page agree.
      if (hideBusy && availabilityDay) await leaveOutBusy(tx, where, availabilityDay);
      const page = await core.searchActiveProviders(tx, where, pagination, now, sort);
      // RA-BE-150 (Q-36), D131: what is known of the asked day, for the
      // rows of this page.
      const status = availabilityDay
        ? await listProvidersDayStatus(tx, page.rows.map((row) => row.id), availabilityDay)
        : null;
      return [page.total, page.rows, status] as const;
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
  );
  return { total, rows, dayStatus, pagination };
}

/**
 * D131 (F8): how many providers each category holds under the same filter
 * as the list (city, search, featured, the day's busy left out), the
 * category itself apart, so the chips say what each one opens. A provider
 * counts in his main category and in every category of an active service.
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
  const { hideBusy } = providerDirectoryOptions(query, availabilityDay);
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
