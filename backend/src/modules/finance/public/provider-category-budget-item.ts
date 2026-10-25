import {
  findLogicalBudgetCategory,
  normalizeBudgetCategoryName,
} from '../domain/cost-category-matching';

/**
 * G38 for the back office: the budget item an accepted offer of a provider
 * category lands in, among a new plan's starter items, chosen by the same
 * matcher acceptance uses (`findLogicalBudgetCategory`). Null is «أخرى»:
 * no item fits, so the cost would be filed there.
 */
export function providerCategoryBudgetItem(
  starterItemNames: readonly string[],
  providerCategoryName: string,
): string | null {
  const items = starterItemNames.map((name, index) => ({
    id: String(index),
    name,
    normalizedName: normalizeBudgetCategoryName(name),
  }));
  return findLogicalBudgetCategory(items, providerCategoryName)?.name ?? null;
}
