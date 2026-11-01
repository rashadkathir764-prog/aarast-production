/**
 * The home suggests the plan's own open items (the venue, the
 * photographer...). The owner answers one of them with «ما أحتاجها» or
 * «بعدين»; with no answer it is suggested.
 *
 * NOT_NEEDED hides it from this plan until the owner takes it back. LATER
 * hides it for LATER_DAYS, then it is suggested again. Pure: no Nest, no
 * persistence (L06).
 */
export type BudgetItemSuggestionChoice = 'NOT_NEEDED' | 'LATER';

export const LATER_DAYS = 7;

const DAY_MS = 24 * 60 * 60 * 1000;

/** What to store for [choice] answered at [now]; null clears the answer. */
export function budgetItemSuggestionAnswer(
  choice: BudgetItemSuggestionChoice | null,
  now: Date,
): { suggestion: BudgetItemSuggestionChoice | null; suggestionUntil: Date | null } {
  if (choice === 'LATER') {
    return {
      suggestion: 'LATER',
      suggestionUntil: new Date(now.getTime() + LATER_DAYS * DAY_MS),
    };
  }
  return { suggestion: choice, suggestionUntil: null };
}

/** Whether an item answered so is kept off the home at [now]. */
export function isBudgetItemSuggestionHidden(
  item: {
    suggestion: BudgetItemSuggestionChoice | null;
    suggestionUntil: Date | null;
  },
  now: Date,
): boolean {
  if (item.suggestion === 'NOT_NEEDED') return true;
  if (item.suggestion === 'LATER') {
    return item.suggestionUntil !== null && item.suggestionUntil > now;
  }
  return false;
}
