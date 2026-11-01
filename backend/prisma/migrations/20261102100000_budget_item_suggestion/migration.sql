-- The home suggests the plan's own items that are still open (the venue, the
-- photographer...). The owner may answer «ما أحتاجها» (NOT_NEEDED) or
-- «بعدين» (LATER, hidden until suggestionUntil). No answer: suggested.
CREATE TYPE "BudgetItemSuggestion" AS ENUM ('NOT_NEEDED', 'LATER');

ALTER TABLE "BudgetCategory"
  ADD COLUMN "suggestion" "BudgetItemSuggestion",
  ADD COLUMN "suggestionUntil" TIMESTAMP(3);
