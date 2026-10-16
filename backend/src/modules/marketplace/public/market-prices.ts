import { Prisma } from '@prisma/client';

// Market price ranges (V1 checklist 4.21 and 4.12): what providers ask, by
// city, category and currency, without exposing any single provider's price.
// The back office's price report and the planning assistant read the same
// ranges.

/** One priced, active service of an active provider. */
export interface PricedService {
  providerId: string;
  /** The service's own city, or the provider's. */
  cityId: string;
  categoryId: string;
  currency: string;
  basePrice: Prisma.Decimal;
}

/**
 * A price group is shown only when at least this many different providers
 * price in it, so no single provider's price can be read off the report.
 */
export const PRICE_GROUP_MIN_PROVIDERS = 3;

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
export function groupPrices(rows: readonly PricedService[]): PriceGroup[] {
  const groups = new Map<string, { row: PricedService; prices: Prisma.Decimal[]; providers: Set<string> }>();
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
