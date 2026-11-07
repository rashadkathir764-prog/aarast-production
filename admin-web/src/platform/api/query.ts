export type QueryValue = string | number | boolean | null | undefined;

export type Paginated<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

/** A thousand rows a list reads whole, a hundred at a time. */
export const EVERY_PAGE_LIMIT = 100;
const EVERY_PAGE_MAX = 10;

/**
 * RA-AD-07: the admin lists come newest first, a page at a time, while a
 * queue ranks oldest first («الأقدم أول»). A queue reads every page, up to a
 * thousand rows, so its oldest are never the ones left on a later page. The
 * total is the server's, which past that cap exceeds the rows.
 */
export async function everyPage<T>(
  read: (page: number, limit: number) => Promise<{ items: T[]; total: number }>,
): Promise<{ items: T[]; total: number }> {
  const first = await read(1, EVERY_PAGE_LIMIT);
  const items = [...first.items];
  for (let page = 2; items.length < first.total && page <= EVERY_PAGE_MAX; page++) {
    const next = await read(page, EVERY_PAGE_LIMIT);
    if (next.items.length === 0) break;
    items.push(...next.items);
  }
  return { items, total: first.total };
}

/**
 * RA-AD-12: the server answers a page past the end with no rows. When the
 * last rows of a later page are handled, the list moves back to its last page
 * instead of saying it is empty while rows still wait.
 */
export function pageToShow(page: number, totalPages: number): number {
  return page > 1 && page > totalPages ? Math.max(1, totalPages) : page;
}

export function toQuery<T extends object>(params: T): string {
  const searchParams = new URLSearchParams();
  Object.entries(params as Record<string, QueryValue>).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.set(key, String(value));
    }
  });
  const query = searchParams.toString();
  return query ? `?${query}` : '';
}
