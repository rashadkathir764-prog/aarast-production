import type {
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  Prisma,
} from '@prisma/client';
import { conflict, type FinanceViolation, invalid } from './finance-violation';

type Amount = Prisma.Decimal;

// Funding sources are tracking only: Aarast records where the wedding money
// comes from and when a loan is paid back; it never holds or moves money.

/** Repayment schedules belong to loans only. */
export function repaymentKindViolation(kind: FundingSourceKind): FinanceViolation | null {
  return kind === 'LOAN' ? null : invalid('Repayments can only be added to a loan');
}

/** The planned and paid repayments of a loan never exceed what was borrowed. */
export function repaymentTotalViolation(
  scheduledTotal: Amount,
  loanAmount: Amount,
): FinanceViolation | null {
  return scheduledTotal.gt(loanAmount)
    ? invalid('Repayments cannot exceed the loan amount')
    : null;
}

/**
 * G16: a source whose loan was partly paid back keeps its history. Deleting
 * it would erase the paid repayments with it; they are marked unpaid first.
 */
export function fundingSourceDeletionViolation(
  repayments: ReadonlyArray<{ status: LoanRepaymentStatus }>,
): FinanceViolation | null {
  return repayments.some((repayment) => repayment.status === 'PAID')
    ? conflict('A funding source with paid repayments cannot be deleted')
    : null;
}

/**
 * D112 (Q-2): money that has not arrived is not paid back. A repayment of a
 * promised loan may be planned, never marked paid.
 */
export function repaymentOnPromisedLoanViolation(
  loanStatus: FundingSourceStatus,
  nextRepaymentStatus: LoanRepaymentStatus | undefined,
): FinanceViolation | null {
  return loanStatus === 'PLEDGED' && nextRepaymentStatus === 'PAID'
    ? conflict('A loan that has not arrived cannot be repaid')
    : null;
}

/**
 * D112 (Q-2), the other door to the same state: a loan that arrived and was
 * paid back in part does not go back to promised.
 */
export function loanBackToPromisedViolation(
  currentStatus: FundingSourceStatus,
  nextStatus: FundingSourceStatus,
  repayments: ReadonlyArray<{ status: LoanRepaymentStatus }>,
): FinanceViolation | null {
  return currentStatus === 'RECEIVED' &&
    nextStatus === 'PLEDGED' &&
    repayments.some((repayment) => repayment.status === 'PAID')
    ? conflict('A loan with paid repayments cannot go back to promised')
    : null;
}

/**
 * A loan with repayments stays a loan, and its amount cannot drop below what
 * is already scheduled to be paid back.
 */
export function fundingSourceChangeViolation(input: {
  currentKind: FundingSourceKind;
  nextKind: FundingSourceKind;
  nextAmount: Amount;
  scheduledRepayments: Amount;
  repaymentCount: number;
}): FinanceViolation | null {
  if (input.repaymentCount > 0 && input.currentKind === 'LOAN' && input.nextKind !== 'LOAN') {
    return conflict('A loan with repayments cannot change its kind');
  }
  return input.nextAmount.lt(input.scheduledRepayments)
    ? invalid('amount cannot be less than the scheduled repayments')
    : null;
}

/**
 * D59: when promised money's day calls for a reminder (a06 «ونذكرك بموعد
 * استلامه»): the day before and on the day, once each. `expectedAt` is the
 * stored day and `today` the start of today in Sana'a; any other day asks
 * for none (a past day is read as «متأخر», not reminded again).
 */
export type ExpectedFundingReminder = 'DAY_BEFORE' | 'ON_THE_DAY';

export function expectedFundingReminder(
  expectedAt: Date,
  today: Date,
): ExpectedFundingReminder | null {
  const days = Math.floor(
    (expectedAt.getTime() - today.getTime()) / (24 * 60 * 60 * 1000),
  );
  if (days === 1) return 'DAY_BEFORE';
  if (days === 0) return 'ON_THE_DAY';
  return null;
}

/** A paid repayment is only reopened, never edited or cancelled directly. */
/**
 * RA-BE-27: a paid repayment is deleted as it is edited or cancelled: marked
 * unpaid first, so a paid record never leaves with no trace.
 */
export function repaymentDeletionViolation(
  status: LoanRepaymentStatus,
): FinanceViolation | null {
  return status === 'PAID'
    ? conflict('A paid repayment cannot be deleted; mark it unpaid first')
    : null;
}

export function repaymentEditViolation(
  status: LoanRepaymentStatus,
  change: { amountOrDueDate: boolean; nextStatus?: LoanRepaymentStatus },
): FinanceViolation | null {
  if (status === 'PAID' && change.amountOrDueDate) {
    return conflict('A paid repayment cannot be edited; mark it unpaid first');
  }
  if (status === 'PAID' && change.nextStatus === 'CANCELLED') {
    return conflict('A paid repayment cannot be cancelled; mark it unpaid first');
  }
  if (status === 'CANCELLED' && change.nextStatus === 'PAID') {
    return conflict('A cancelled repayment cannot be paid');
  }
  return null;
}
