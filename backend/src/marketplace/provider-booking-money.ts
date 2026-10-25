import { Prisma } from "@prisma/client";
import type { FinancePort } from "../modules/finance/public/finance.port";

// B-18 (D41): the provider reads what the customer agreed, paid and still
// owes on the money item his accepted offer created. Read only, three
// totals: never a payment, who paid, from where, a receipt or a note. The
// customer records every payment, as before; nothing here moves money.

export interface ProviderBookingMoney {
  agreed: string;
  paid: string;
  left: string;
  /** The accepted offer's currency, which is the plan's (G19). */
  currency: string;
  lastPaidAt: Date | null;
}

const money = (value: Prisma.Decimal) => value.toFixed(2);

/**
 * The money of each accepted offer, by offer id; an offer whose customer
 * keeps no agreement for it (a request without a plan, or a removed cost)
 * has none.
 */
export async function readProviderBookingMoney(
  finance: Pick<FinancePort, "listCostsForOffers">,
  client: Prisma.TransactionClient,
  offers: ReadonlyArray<{ id: string; currency: string }>,
): Promise<Map<string, ProviderBookingMoney>> {
  const currencies = new Map(offers.map((offer) => [offer.id, offer.currency]));
  const costs = await finance.listCostsForOffers(client, [...currencies.keys()]);
  const result = new Map<string, ProviderBookingMoney>();
  for (const cost of costs) {
    const left = cost.totalAmount.minus(cost.paidAmount);
    result.set(cost.quoteOfferId, {
      agreed: money(cost.totalAmount),
      paid: money(cost.paidAmount),
      left: money(left.isNegative() ? new Prisma.Decimal(0) : left),
      currency: currencies.get(cost.quoteOfferId)!,
      lastPaidAt: cost.lastPaidAt,
    });
  }
  return result;
}

export interface ProviderLedgerTotals {
  currency: string;
  agreed: string;
  paid: string;
  left: string;
  bookings: number;
}

/** p47: one month's totals, each currency on its own (never added together). */
export function providerLedgerTotals(
  rows: ReadonlyArray<ProviderBookingMoney>,
): ProviderLedgerTotals[] {
  const byCurrency = new Map<
    string,
    { agreed: Prisma.Decimal; paid: Prisma.Decimal; left: Prisma.Decimal; bookings: number }
  >();
  for (const row of rows) {
    const sum = byCurrency.get(row.currency) ?? {
      agreed: new Prisma.Decimal(0),
      paid: new Prisma.Decimal(0),
      left: new Prisma.Decimal(0),
      bookings: 0,
    };
    sum.agreed = sum.agreed.plus(row.agreed);
    sum.paid = sum.paid.plus(row.paid);
    sum.left = sum.left.plus(row.left);
    sum.bookings += 1;
    byCurrency.set(row.currency, sum);
  }
  return [...byCurrency.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([currency, sum]) => ({
      currency,
      agreed: money(sum.agreed),
      paid: money(sum.paid),
      left: money(sum.left),
      bookings: sum.bookings,
    }));
}

/** `YYYY-MM` to the month's first day and the next month's (`@db.Date` midnights). */
export function ledgerMonthRange(month: string): { from: Date; until: Date } | null {
  const match = /^(\d{4})-(\d{2})$/.exec(month.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const index = Number(match[2]) - 1;
  if (index < 0 || index > 11) return null;
  return {
    from: new Date(Date.UTC(year, index, 1)),
    until: new Date(Date.UTC(year, index + 1, 1)),
  };
}
