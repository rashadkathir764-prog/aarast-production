import { createHash } from 'node:crypto';

/**
 * D112 (Q-4), the owner's word: a budget saved from an older read is
 * refused. The budget is saved whole, so a save made from what a phone read
 * a while ago brought back names and amounts changed on another phone and
 * deleted the items added there.
 *
 * The version is the budget's content: its total, its currency and its
 * items (id, name, allocation, the owner's estimate). It changes exactly
 * when the budget does, whichever write changed it, so no column has to be
 * kept in step. The money summary carries it to the plan's owner and the
 * budget save sends back the one it read (`expectedBudgetVersion`).
 */
export interface BudgetVersionInput {
  totalBudget: string | null;
  currency: string;
  categories: readonly {
    id: string;
    name: string;
    allocatedAmount: string | null;
    estimatedAmount: string | null;
  }[];
}

export const BUDGET_CHANGED_ELSEWHERE = 'BUDGET_CHANGED_ELSEWHERE';

export function budgetVersionOf(input: BudgetVersionInput): string {
  const items = [...input.categories]
    .sort((first, second) =>
      first.id < second.id ? -1 : first.id > second.id ? 1 : 0,
    )
    .map((item) => [
      item.id,
      item.name,
      item.allocatedAmount,
      item.estimatedAmount,
    ]);
  return createHash('sha256')
    .update(
      JSON.stringify([input.totalBudget, input.currency.toUpperCase(), items]),
    )
    .digest('hex')
    .slice(0, 24);
}
