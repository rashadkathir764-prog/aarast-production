import type { Prisma } from '@prisma/client';
import { type FinanceViolation, invalid } from './finance-violation';

type Amount = Prisma.Decimal;

/**
 * Whose side of the mahr the plan is on (C1, JOURNEY_PROFILE.md): the
 * groom's plan pays it to the bride's family, the bride's plan receives it.
 * A plan without a wedding persona (a helper's plan) has no mahr side.
 */
export type MahrSide = 'PAYS' | 'RECEIVES';

export function mahrSideOf(persona: string | null): MahrSide | null {
  if (persona === 'GROOM') return 'PAYS';
  if (persona === 'BRIDE') return 'RECEIVES';
  return null;
}

/** What a06 records: the agreed mahr, what was handed over, and when the rest is due. */
export interface MahrAgreement {
  total: Amount;
  settled: Amount;
  /** When the rest is handed over; null when nothing is left or no day is set. */
  remainingDueAt: Date | null;
}

/** The agreed mahr is above zero and what was handed over is within it. */
export function mahrAgreementViolation(agreement: {
  total: Amount;
  settled: Amount;
}): FinanceViolation | null {
  if (!agreement.total.gt(0)) {
    return invalid('The mahr must be greater than zero');
  }
  if (agreement.settled.lt(0)) {
    return invalid('The handed-over part cannot be negative');
  }
  if (agreement.settled.gt(agreement.total)) {
    return invalid('The handed-over part cannot exceed the mahr');
  }
  return null;
}

/** The rest of the mahr: nothing left has no due day. */
export function mahrRemaining(agreement: MahrAgreement): {
  amount: Amount;
  dueAt: Date | null;
} {
  const amount = agreement.total.minus(agreement.settled);
  return { amount, dueAt: amount.gt(0) ? agreement.remainingDueAt : null };
}

/** The plan's mahr as both sides read it (money-summary `mahr`). */
export interface MahrPicture {
  side: MahrSide;
  total: string;
  /** Handed over (groom) or received (bride). */
  settled: string;
  remaining: string;
  /** The earliest day the rest is due (groom) or expected (bride). */
  nextDueAt: Date | null;
  complete: boolean;
}

export function mahrPicture(
  side: MahrSide,
  total: Amount,
  settled: Amount,
  nextDueAt: Date | null,
): MahrPicture {
  const remaining = total.minus(settled);
  return {
    side,
    total: total.toString(),
    settled: settled.toString(),
    remaining: remaining.toString(),
    nextDueAt: remaining.gt(0) ? nextDueAt : null,
    complete: total.gt(0) && !remaining.gt(0),
  };
}
