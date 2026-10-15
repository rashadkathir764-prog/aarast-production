import { Prisma } from '@prisma/client';
import type { AdminPricedService } from '../modules/marketplace/public/marketplace-admin.port';

// The back office's success indicators and market price report (V1
// checklist 4.21). Pure rules only: the counts come from each owner's port.

export const ACTIVE_USERS_WINDOW_DAYS = 7;
export const CONVERSION_WINDOW_DAYS = 30;

/**
 * A price group is shown only when at least this many different providers
 * price in it, so no single provider's price can be read off the report.
 */
export const PRICE_GROUP_MIN_PROVIDERS = 3;

export type PricedServiceRow = AdminPricedService;

export interface PriceGroup {
  cityId: string;
  categoryId: string;
  currency: string;
  providers: number;
  services: number;
  min: string;
  median: string;
  max: string;
}

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

function median(sorted: Prisma.Decimal[]): Prisma.Decimal {
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? sorted[middle]
    : sorted[middle - 1].plus(sorted[middle]).dividedBy(2);
}

/**
 * Prices by city, category and currency (amounts in different currencies
 * are never mixed), keeping only groups priced by enough providers.
 */
export function groupPrices(rows: readonly PricedServiceRow[]): PriceGroup[] {
  const groups = new Map<string, { row: PricedServiceRow; prices: Prisma.Decimal[]; providers: Set<string> }>();
  for (const row of rows) {
    const key = `${row.cityId}|${row.categoryId}|${row.currency}`;
    const group = groups.get(key) ?? { row, prices: [], providers: new Set<string>() };
    group.prices.push(row.basePrice);
    group.providers.add(row.providerId);
    groups.set(key, group);
  }
  return [...groups.values()]
    .filter((group) => group.providers.size >= PRICE_GROUP_MIN_PROVIDERS)
    .map(({ row, prices, providers }) => {
      const sorted = [...prices].sort((left, right) => left.comparedTo(right));
      return {
        cityId: row.cityId,
        categoryId: row.categoryId,
        currency: row.currency,
        providers: providers.size,
        services: sorted.length,
        min: sorted[0].toFixed(2),
        median: median(sorted).toFixed(2),
        max: sorted[sorted.length - 1].toFixed(2),
      };
    })
    .sort((left, right) => right.providers - left.providers);
}
