import type { Prisma } from '@prisma/client';
import { type FinanceViolation, invalid } from './finance-violation';

type Amount = Prisma.Decimal;

// Category allocations never substitute the general budget.

/** Allocations never exceed the general budget when one is set. */
export function allocationWithinBudgetViolation(
  totalBudget: Amount | null,
  allocated: Amount,
): FinanceViolation | null {
  return totalBudget !== null && allocated.gt(totalBudget)
    ? invalid('Category allocations cannot exceed the general budget')
    : null;
}

/**
 * A whole budget (general budget plus its category allocations): allocating
 * needs a general budget, and the allocations never exceed it.
 */
export function budgetAllocationViolation(
  totalBudget: Amount | null,
  allocated: Amount,
): FinanceViolation | null {
  if (totalBudget === null && allocated.gt(0)) {
    return invalid('Set the general budget before allocating money to categories');
  }
  return allocationWithinBudgetViolation(totalBudget, allocated);
}
