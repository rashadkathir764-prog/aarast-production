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
