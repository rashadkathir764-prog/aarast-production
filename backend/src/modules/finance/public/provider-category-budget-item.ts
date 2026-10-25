import {
  findLogicalBudgetCategory,
  normalizeBudgetCategoryName,
  providerCategoryIdsByBudgetItem,
  type BudgetCategoryCandidate,
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

/** A directory category as G40 reads it: its name and who sees it. */
export interface SearchableProviderCategory {
  id: string;
  nameAr: string;
  showForGroom: boolean;
  showForBride: boolean;
}

/**
 * G40: the directory categories «ابحث» on each of a plan's wedding items
 * searches, keyed by item id. A category counts for the item its accepted
 * offer is filed under (`budgetItemForProviderCategory`, acceptance's rule)
 * and only when the plan's persona sees it in the directory (a groom's plan
 * does not search «فنانة», a bride's does not search «مبرع»), so an item
 * lists exactly the providers its owner can ask and whose offers land in it.
 * `items` are the plan's wedding items in acceptance's order.
 */
export function budgetItemSearchCategories(
  items: readonly BudgetCategoryCandidate[],
  providerCategories: readonly SearchableProviderCategory[],
  persona: string | null | undefined,
): Map<string, string[]> {
  return providerCategoryIdsByBudgetItem(
    items,
    providerCategories.filter((category) =>
      providerCategoryShownTo(category, persona),
    ),
  );
}

/** The catalog's audience: GROOM and BRIDE see theirs, any other plan both. */
export function providerCategoryShownTo(
  category: Pick<SearchableProviderCategory, 'showForGroom' | 'showForBride'>,
  persona: string | null | undefined,
): boolean {
  switch (persona) {
    case 'GROOM':
      return category.showForGroom;
    case 'BRIDE':
      return category.showForBride;
    default:
      return category.showForGroom || category.showForBride;
  }
}
