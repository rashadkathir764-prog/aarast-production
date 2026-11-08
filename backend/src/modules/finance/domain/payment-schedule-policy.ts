import type { Prisma, WeddingCostStatus } from '@prisma/client';
import { type FinanceViolation, invalid } from './finance-violation';

type Amount = Prisma.Decimal;

// Payment schedules are reminders, not reservations: each schedule is capped
// independently by the cost's outstanding amount (read under the cost's row
// lock), other pending schedules reserve nothing, and a full payment cancels
// the pending schedules.

/** A schedule's amount, when it is created or edited. */
export function scheduleAmountViolation(
  amount: Amount,
  totalAmount: Amount,
  paidAmount: Amount,
): FinanceViolation | null {
  return amount.gt(totalAmount.minus(paidAmount))
    ? invalid('Payment schedule amount cannot exceed the remaining cost')
    : null;
}

/**
 * RA-BE-53: what a pending schedule asks for now. The cap above holds when a
 * schedule is written; a payment made straight on the cost afterwards lowers
 * what is left, and the schedule kept asking for its whole amount: «the next
 * payment» read more than the cost still owed, and paying it was refused as
 * above the remaining. A schedule asks for the lesser of its amount and what
 * the cost still owes; while pending its own amount, as the person wrote it,
 * is kept, and once paid it records what was paid (the ledger holds a paid
 * schedule equal to its payment).
 */
export function scheduleAmountDue(
  amount: Amount,
  totalAmount: Amount,
  paidAmount: Amount,
): Amount {
  const remaining = totalAmount.minus(paidAmount);
  if (remaining.lte(0)) return remaining.mul(0);
  return amount.lt(remaining) ? amount : remaining;
}

/** A schedule's amount, when it is paid. */
export function scheduledPaymentViolation(
  amount: Amount,
  totalAmount: Amount,
  paidAmount: Amount,
): FinanceViolation | null {
  return amount.gt(totalAmount.minus(paidAmount))
    ? invalid('Scheduled payment exceeds the remaining cost')
    : null;
}

/** Whether a cost reaching `status` cancels its pending schedules. */
export function schedulesToCancelOnStatus(status: WeddingCostStatus): boolean {
  return status === 'PAID';
}

/**
 * D106: a reminder day of its own is between today and the due day (days in
 * Riyadh, D11). It moves the reminder only; the due day stays.
 */
export function remindDayViolation(
  remindDay: string,
  today: string,
  dueDay: string,
): FinanceViolation | null {
  return remindDay < today || remindDay > dueDay
    ? invalid('The reminder day must be between today and the due day')
    : null;
}
