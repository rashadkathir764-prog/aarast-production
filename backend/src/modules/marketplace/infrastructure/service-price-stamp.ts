import { Prisma } from '@prisma/client';

// "Last price update" means the price changed (its amount or its currency),
// not any edit of the service: a title fix or a re-save of the same price
// keeps the old date.

export function priceStampForNewService(basePrice: string | null): Date | null {
  return basePrice === null ? null : new Date();
}

/**
 * The priceUpdatedAt change for an update of the service, or nothing when the
 * update leaves the price alone. The caller holds the service row locked.
 */
export async function priceStampForServiceUpdate(
  client: Prisma.TransactionClient,
  serviceId: string,
  changes: { basePrice?: string | null; currency?: string },
): Promise<{ priceUpdatedAt?: Date | null }> {
  if (changes.basePrice === undefined && changes.currency === undefined) return {};
  const current = await client.providerService.findUnique({
    where: { id: serviceId },
    select: { basePrice: true, currency: true },
  });
  if (!current) return {};
  const nextPrice =
    changes.basePrice === undefined
      ? (current.basePrice?.toString() ?? null)
      : changes.basePrice;
  const nextCurrency = changes.currency ?? current.currency;
  if (samePrice(current.basePrice, nextPrice) && current.currency === nextCurrency) {
    return {};
  }
  return { priceUpdatedAt: priceStampForNewService(nextPrice) };
}

function samePrice(current: Prisma.Decimal | null, next: string | null): boolean {
  if (current === null || next === null) return current === next;
  return current.equals(new Prisma.Decimal(next));
}
