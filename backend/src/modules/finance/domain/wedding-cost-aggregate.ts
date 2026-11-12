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
  const remaining = totalAmount.minus(paidAmount);
  if (!amount.gt(remaining)) return null;
  const violation = invalid('Payment amount cannot exceed the remaining cost');
  // D112 (Q-3): what is left is said with the refusal. A payment kept on a
  // phone without a connection meets it when someone else paid meanwhile;
  // the amount is never cut to fit, its owner reads what is left and
  // records what was really paid.
  return remaining.gt(0)
    ? {
        ...violation,
        userMessage: `${violation.userMessage} الباقي عليه ${amountWords(remaining)}.`,
      }
    : violation;
}

/** «20,000», or «500.50» for an amount kept from before whole riyals. */
function amountWords(amount: Amount): string {
  const [whole, fraction] = amount.toFixed(amount.isInteger() ? 0 : 2).split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/gu, ',');
  return fraction ? `${grouped}.${fraction}` : grouped;
}

export function deriveCostStatus(totalAmount: Amount, paidAmount: Amount): WeddingCostStatus {
  if (paidAmount.gte(totalAmount)) return 'PAID';
  if (paidAmount.gt(0)) return 'PARTIALLY_PAID';
  return 'OPEN';
}

/**
 * D107: an expense is its payment. Once that payment is taken back nothing
 * of the expense stands, so it is cancelled; it is never left owed
 * (RA-BE-130). An agreement owes again what was taken back.
 */
export function statusAfterReversal(
  entryKind: 'AGREEMENT' | 'EXPENSE',
  totalAmount: Amount,
  paidAmount: Amount,
): WeddingCostStatus {
  return entryKind === 'EXPENSE' && !paidAmount.gt(0)
    ? 'CANCELLED'
    : deriveCostStatus(totalAmount, paidAmount);
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

/**
 * D107: an expense is money paid in full the day it is recorded, so its
 * first payment, when typed, is its whole amount.
 */
export function expenseInitialPaymentViolation(
  entryKind: 'AGREEMENT' | 'EXPENSE',
  totalAmount: Amount,
  initialPayment: Amount,
): FinanceViolation | null {
  return entryKind === 'EXPENSE' &&
    initialPayment.gt(0) &&
    !initialPayment.equals(totalAmount)
    ? invalid('An expense is paid in full when it is recorded')
    : null;
}

/**
 * D107: an expense's amount is its payment: while the payment stands, the
 * amount does not change (correcting it is reversing the payment).
 */
export function expenseTotalChangeViolation(
  entryKind: 'AGREEMENT' | 'EXPENSE',
  totalAmount: Amount,
  nextTotalAmount: Amount,
  paidAmount: Amount,
): FinanceViolation | null {
  return entryKind === 'EXPENSE' &&
    paidAmount.gt(0) &&
    !nextTotalAmount.equals(totalAmount)
    ? invalid('An expense is its payment: correct the payment instead')
    : null;
}
