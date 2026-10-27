// The back office's success indicators (V1 checklist 4.21). Pure rules
// only: the counts come from each owner's port. The market price ranges are
// marketplace's (`modules/marketplace/public/market-prices`).

export const ACTIVE_USERS_WINDOW_DAYS = 7;
export const CONVERSION_WINDOW_DAYS = 30;

export function daysAgo(now: Date, days: number): Date {
  return new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
}

/** Whole percent, or null when nothing was counted. */
export function percent(part: number, whole: number): number | null {
  return whole > 0 ? Math.round((part / whole) * 100) : null;
}

/** One decimal place, or null when nothing was counted. */
export function average(total: number, count: number): number | null {
  return count > 0 ? Math.round((total / count) * 10) / 10 : null;
}

/**
 * G41: a group is shown only when at least this many plans are in it, so
 * no single wedding's spending can be read back from the report.
 */
export const SPENDING_MIN_PLANS = 5;

export interface SpendingRow {
  weddingPlanId: string;
  itemName: string;
  city: string | null;
  currency: string;
  /** Decimal text. */
  total: string;
}

export interface SpendingGroup {
  city: string;
  itemName: string;
  currency: string;
  plans: number;
  min: string;
  median: string;
  max: string;
}

/** «صنعاء» and «صنعاء » and «صنعا» read as one city (أ/ا، ة/ه، ى/ي). */
function cityKey(city: string): string {
  return city
    .trim()
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\s+/g, ' ');
}

/**
 * G41: what plans really agreed per wedding item, by city and currency,
 * never across currencies. Each plan counts once per group; groups under
 * [SPENDING_MIN_PLANS] plans are left out.
 */
export function groupSpending(rows: readonly SpendingRow[]): SpendingGroup[] {
  const groups = new Map<string, { city: string; itemName: string; currency: string; byPlan: Map<string, number> }>();
  for (const row of rows) {
    const city = row.city?.trim();
    if (!city) continue;
    const key = `${cityKey(city)}|${row.itemName}|${row.currency}`;
    const group =
      groups.get(key) ??
      { city, itemName: row.itemName, currency: row.currency, byPlan: new Map<string, number>() };
    group.byPlan.set(
      row.weddingPlanId,
      (group.byPlan.get(row.weddingPlanId) ?? 0) + Number(row.total),
    );
    groups.set(key, group);
  }
  const result: SpendingGroup[] = [];
  for (const group of groups.values()) {
    const totals = [...group.byPlan.values()].sort((a, b) => a - b);
    if (totals.length < SPENDING_MIN_PLANS) continue;
    const middle = Math.floor(totals.length / 2);
    const median =
      totals.length % 2 === 1 ? totals[middle] : (totals[middle - 1] + totals[middle]) / 2;
    result.push({
      city: group.city,
      itemName: group.itemName,
      currency: group.currency,
      plans: totals.length,
      min: totals[0].toFixed(2),
      median: median.toFixed(2),
      max: totals[totals.length - 1].toFixed(2),
    });
  }
  return result.sort(
    (a, b) => a.city.localeCompare(b.city, 'ar') || b.plans - a.plans,
  );
}
