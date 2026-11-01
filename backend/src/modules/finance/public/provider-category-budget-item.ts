import {
  findLogicalBudgetCategory,
  normalizeBudgetCategoryName,
  providerCategoryIdsByBudgetItem,
  type BudgetCategoryCandidate,
  type ExplicitProviderCategoryLink,
  type MoneyCatalogLinks,
} from '../domain/cost-category-matching';

export type {
  BudgetItemProviderLink,
  ExplicitProviderCategoryLink,
  MoneyCatalogLinks,
} from '../domain/cost-category-matching';

/**
 * G38 for the back office: the budget item an accepted offer of a provider
 * category lands in, among a new plan's starter items, chosen by the same
 * matcher acceptance uses (`findLogicalBudgetCategory`). Null is «أخرى»:
 * no item fits, so the cost would be filed there. D73: `explicit` carries
 * the category's slug and the starter items' links.
 */
export function providerCategoryBudgetItem(
  starterItemNames: readonly string[],
  providerCategoryName: string,
  explicit?: ExplicitProviderCategoryLink,
): string | null {
  const items = starterItemNames.map((name, index) => ({
    id: String(index),
    name,
    normalizedName: normalizeBudgetCategoryName(name),
  }));
  return (
    findLogicalBudgetCategory(items, providerCategoryName, explicit)?.name ??
    null
  );
}

/** A directory category as G40 reads it: its name, slug and who sees it. */
export interface SearchableProviderCategory {
  id: string;
  nameAr: string;
  /** D73: what a money catalog item links to; absent, only words match. */
  slug?: string | null;
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
 * `items` are the plan's wedding items in acceptance's order; `catalogItems`
 * the money catalog's items with their explicit links (D73), read for the
 * plan's persona as acceptance reads them.
 */
export function budgetItemSearchCategories(
  items: readonly BudgetCategoryCandidate[],
  providerCategories: readonly SearchableProviderCategory[],
  persona: string | null | undefined,
  catalogItems: MoneyCatalogLinks['items'] = [],
): Map<string, string[]> {
  return providerCategoryIdsByBudgetItem(
    items,
    providerCategories.filter((category) =>
      providerCategoryShownTo(category, persona),
    ),
    { planPersona: persona, items: catalogItems },
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
