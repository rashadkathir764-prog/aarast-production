import type { Prisma } from '@prisma/client';
import type { FinancePort } from '../modules/finance/public/finance.port';
import type { ProviderReadPort } from '../modules/marketplace/public/provider-read.port';

/**
 * D60, one definition of «محجوز»: a service of the plan is booked when the
 * provider CONFIRMED a booking for it, or when its cost is recorded with a
 * party outside اعّرست. An accepted offer without a booking is «اخترت X ·
 * اطلب الحجز», never booked.
 *
 * A service is the money item its booked offer was filed under; a booked
 * offer with no item (a request outside the plan's money) is its own. The
 * home's «محجوز» tile and the providers board (f01) both read this result,
 * so the two numbers are one number.
 */
export interface PlanBookedServices {
  count: number;
  /** The plan's money items that are booked. */
  budgetCategoryIds: string[];
  /** Booked requests whose offer has no money item. */
  quoteRequestIds: string[];
}

export async function readPlanBookedServices(
  tx: Prisma.TransactionClient,
  owners: {
    providers: Pick<ProviderReadPort, 'listPlanConfirmedBookings'>;
    finance: Pick<FinancePort, 'listCostsForOffers' | 'listOutsidePartyItemIds'>;
  },
  weddingPlanId: string,
  scope: {
    /** A contributor's requests; null: the plan's. */
    quoteRequestIds: readonly string[] | null;
    /** The reader's costs (never another account's private ones); null: the plan's. */
    costIds: readonly string[] | null;
  },
): Promise<PlanBookedServices> {
  const bookings = await owners.providers.listPlanConfirmedBookings(
    tx,
    weddingPlanId,
    scope.quoteRequestIds,
  );
  const offerIds = bookings.flatMap((booking) =>
    booking.quoteOfferId ? [booking.quoteOfferId] : [],
  );
  const [costs, outsideItemIds] = await Promise.all([
    owners.finance.listCostsForOffers(tx, offerIds),
    owners.finance.listOutsidePartyItemIds(tx, weddingPlanId, scope.costIds),
  ]);
  const itemByOffer = new Map(
    costs
      .filter((cost) => scope.costIds === null || scope.costIds.includes(cost.id))
      .map((cost) => [cost.quoteOfferId, cost.budgetCategoryId]),
  );
  const items = new Set(outsideItemIds);
  const quotes = new Set<string>();
  for (const booking of bookings) {
    const item = booking.quoteOfferId ? itemByOffer.get(booking.quoteOfferId) : undefined;
    if (item) items.add(item);
    else quotes.add(booking.quoteRequestId);
  }
  const budgetCategoryIds = [...items].sort();
  const quoteRequestIds = [...quotes].sort();
  return {
    count: budgetCategoryIds.length + quoteRequestIds.length,
    budgetCategoryIds,
    quoteRequestIds,
  };
}
