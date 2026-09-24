import type { CostPaymentType, Prisma, WeddingCostStatus } from '@prisma/client';
import { conflict, type FinanceViolation, invalid } from './finance-violation';

type Amount = Prisma.Decimal;

// The wedding-cost aggregate's invariants: amounts are positive, the paid
// amount never exceeds the total, a payment is reversed at most once, and a
// cost with a payment ledger is neither deleted nor cancelled while paid.

/** Every cost, payment and schedule amount is greater than zero. */
export function positiveAmountViolation(amount: Amount, field: string): FinanceViolation | null {
  return amount.gt(0) ? null : invalid(`${field} must be greater than zero`);
}

export function initialPaymentViolation(initialPayment: Amount, totalAmount: Amount): FinanceViolation | null {
  return initialPayment.gt(totalAmount)
    ? invalid('initialPaymentAmount cannot exceed totalAmount')
    : null;
}

/** A total can shrink only down to what is already paid. */
export function totalAmountViolation(totalAmount: Amount, paidAmount: Amount): FinanceViolation | null {
  return totalAmount.lt(paidAmount)
    ? invalid('totalAmount cannot be less than paidAmount')
    : null;
}

export function paymentAmountViolation(
  amount: Amount,
  totalAmount: Amount,
  paidAmount: Amount,
): FinanceViolation | null {
  return amount.gt(totalAmount.minus(paidAmount))
    ? invalid('Payment amount cannot exceed the remaining cost')
    : null;
}

export function deriveCostStatus(totalAmount: Amount, paidAmount: Amount): WeddingCostStatus {
  if (paidAmount.gte(totalAmount)) return 'PAID';
  if (paidAmount.gt(0)) return 'PARTIALLY_PAID';
  return 'OPEN';
}

/** Only an open or partially paid cost receives a payment or a schedule. */
export function payableViolation(status: WeddingCostStatus): FinanceViolation | null {
  if (status === 'CANCELLED') return conflict('Cancelled costs cannot receive payments');
  if (status === 'PAID') return conflict('Cost is already fully paid');
  return null;
}

export interface ReversiblePayment {
  entryType: CostPaymentType;
  /** Whether a reversal entry already reverses this payment. */
  reversed: boolean;
  amount: Amount;
}

/** A payment is reversed at most once, a reversal never, and never below zero paid. */
export function reversalViolation(payment: ReversiblePayment, paidAmount: Amount): FinanceViolation | null {
  if (payment.entryType !== 'PAYMENT') return conflict('A reversal entry cannot be reversed');
  if (payment.reversed) return conflict('Payment has already been reversed');
  if (payment.amount.gt(paidAmount)) return conflict('Payment ledger is inconsistent');
  return null;
}

export function costDeletionViolation(paymentCount: number, paidAmount: Amount): FinanceViolation | null {
  return paymentCount > 0 || !paidAmount.isZero()
    ? conflict('A cost with payment history cannot be deleted')
    : null;
}

export function costCancellationViolation(paidAmount: Amount): FinanceViolation | null {
  return paidAmount.isZero()
    ? null
    : conflict('Reverse the active payments before cancelling this cost');
}
