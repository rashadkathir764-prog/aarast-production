import type { Prisma } from '@prisma/client';
import { conflict, type FinanceViolation, invalid } from './finance-violation';

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

/**
 * C1 (D59): an agreement stays on its side of the wedding budget. Moving it
 * between a wedding item and the mahr item would silently move its money
 * into or out of the budget, so it is refused; the agreement is recorded
 * again in the right item instead.
 */
export function mahrItemMoveViolation(
  fromKind: string,
  toKind: string,
): FinanceViolation | null {
  return fromKind !== toKind
    ? conflict('An agreement cannot move between the mahr and the wedding items')
    : null;
}

/**
 * The mahr as money coming in is the bride's (C1, D59): only a bride's plan
 * holds MAHR funding, and a source keeps the kind it was recorded with on
 * either side of it (the mahr's parts stay the mahr; other money never
 * becomes it).
 */
export function mahrFundingViolation(input: {
  planPersona: string | null;
  /** Null when the source is being created. */
  currentKind: string | null;
  nextKind: string;
}): FinanceViolation | null {
  const touchesMahr = input.nextKind === 'MAHR' || input.currentKind === 'MAHR';
  if (!touchesMahr) return null;
  if (input.currentKind === null) {
    return input.planPersona === 'BRIDE'
      ? null
      : invalid("The mahr is money coming in only on the bride's plan");
  }
  return input.currentKind !== input.nextKind
    ? conflict('A funding source cannot change to or from the mahr')
    : null;
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
