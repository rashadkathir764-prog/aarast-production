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
