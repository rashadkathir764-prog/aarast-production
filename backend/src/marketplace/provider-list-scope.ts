import type { Prisma } from "@prisma/client";

// What one row of the customers' list says inside the asked categories
// (2026-11-26 review, docs/project/PROVIDER_RANKING.md): a hall that also
// photographs is, under «تصوير», a photographer at his photography price,
// not a hall at his hall price. Pure: the repository reads the rows, these
// read them the same way for the order, the card and the chips' counts.

/** One active service of a listed provider, as the list reads it. */
export interface ListedService {
  categoryId: string;
  basePrice: Prisma.Decimal | null;
  currency: string;
  priceUpdatedAt?: Date | null;
}

/** One active priced package, filed under its service's category (or his main one when it names none). */
export interface ListedPackage {
  price: Prisma.Decimal | null;
  currency: string;
  service: { categoryId: string } | null;
}

export interface ListedOffers {
  primaryCategoryId: string | null;
  /** Active services only, newest first. */
  services: readonly ListedService[];
  /** Active packages only. */
  packages: readonly ListedPackage[];
}

/** A price the card and «الأقل سعرًا» may read. */
export interface PricedOffer {
  price: Prisma.Decimal;
  currency: string;
  /** A service's price stamp; a package keeps none. */
  priceUpdatedAt: Date | null;
}

/**
 * The categories a listed provider is found under: his main one and every
 * active service's. The list's category filter (provider-category-filter.ts)
 * and the chips' counts (`countProvidersByCategory`) file him by this rule.
 */
export function providerCategoryIdsOf(
  row: Pick<ListedOffers, "primaryCategoryId"> & {
    services: ReadonlyArray<{ categoryId: string }>;
  },
): string[] {
  return [
    ...new Set([
      ...(row.primaryCategoryId ? [row.primaryCategoryId] : []),
      ...row.services.map((service) => service.categoryId),
    ]),
  ];
}

/**
 * The asked category he was found under: his main one when it is asked,
 * else his newest active service's that is; null when nothing is asked.
 */
export function matchedCategoryId(
  row: Pick<ListedOffers, "primaryCategoryId"> & {
    services: ReadonlyArray<{ categoryId: string }>;
  },
  scope: readonly string[] | null,
): string | null {
  if (!scope) return null;
  if (row.primaryCategoryId && scope.includes(row.primaryCategoryId)) {
    return row.primaryCategoryId;
  }
  return row.services.find((service) => scope.includes(service.categoryId))?.categoryId ?? null;
}

/**
 * His priced active services and packages in the asked categories (every
 * one when none is asked). A package goes under its service's category, or
 * his main one when it names no service.
 */
export function pricedOffersInScope(
  row: ListedOffers,
  scope: readonly string[] | null,
): PricedOffer[] {
  const inScope = (categoryId: string | null) =>
    scope === null || (categoryId !== null && scope.includes(categoryId));
  const offers: PricedOffer[] = [];
  for (const service of row.services) {
    if (service.basePrice === null || !inScope(service.categoryId)) continue;
    offers.push({
      price: service.basePrice,
      currency: service.currency,
      priceUpdatedAt: service.priceUpdatedAt ?? null,
    });
  }
  for (const pack of row.packages) {
    if (pack.price === null) continue;
    if (!inScope(pack.service?.categoryId ?? row.primaryCategoryId)) continue;
    offers.push({ price: pack.price, currency: pack.currency, priceUpdatedAt: null });
  }
  return offers;
}

/** The lowest of [offers] in Yemeni rials; null when none is in rials. */
export function lowestRialPrice(offers: readonly PricedOffer[]): number | null {
  let lowest: number | null = null;
  for (const offer of offers) {
    if (offer.currency !== "YER") continue;
    const price = Number(offer.price);
    if (lowest === null || price < lowest) lowest = price;
  }
  return lowest;
}

/** Whether he published any price at all (`profileCompleteness`). */
export function hasPublishedPrice(row: ListedOffers): boolean {
  return pricedOffersInScope(row, null).length > 0;
}

/**
 * The card's photo (2026-11-26 review): his first approved work photo
 * outside the women's album (the repository reads only those), else his
 * cover's 480px copy, else the cover itself; null with neither. A work photo
 * has no smaller copies (only a logo and a cover get them, RA-MO-364).
 */
export function cardPhotoUrl(row: {
  portfolioItems: ReadonlyArray<{ imageUrl: string }>;
  coverThumbUrl: string | null;
  coverUrl: string | null;
}): string | null {
  return row.portfolioItems[0]?.imageUrl ?? row.coverThumbUrl ?? row.coverUrl ?? null;
}
