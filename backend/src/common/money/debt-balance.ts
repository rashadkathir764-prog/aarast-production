import { DebtStatus, Prisma } from '@prisma/client';

export interface DebtBalanceState {
  paidAmount: Prisma.Decimal;
  status: DebtStatus;
}

/**
 * Pure derivation of a debt's paidAmount + status after applying a payment
 * delta (positive = payment, negative = compensation for un-pay/delete).
 *
 * Invariants enforced:
 * - 0 <= paidAmount <= totalAmount (clamped, never negative, never over).
 * - status is always derived from the balance, never set independently.
 * - All arithmetic stays in Decimal — no float drift in a money path.
 */
export function applyDebtPaymentDelta(
  totalAmount: Prisma.Decimal,
  currentPaidAmount: Prisma.Decimal,
  delta: Prisma.Decimal,
): DebtBalanceState {
  const zero = new Prisma.Decimal(0);

  let next = currentPaidAmount.add(delta);
  if (next.lessThan(zero)) next = zero;
  if (next.greaterThan(totalAmount)) next = totalAmount;

  const status =
    totalAmount.greaterThan(zero) && next.greaterThanOrEqualTo(totalAmount)
      ? DebtStatus.PAID
      : next.greaterThan(zero)
        ? DebtStatus.PARTIALLY_PAID
        : DebtStatus.OPEN;

  return { paidAmount: next, status };
}
