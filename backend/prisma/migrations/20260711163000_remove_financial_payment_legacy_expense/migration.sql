-- The expense-to-payment compatibility bridge was never part of the canonical
-- financial commitment system. With no production users, remove it completely
-- so payment reversals have one source of truth and old logic cannot return.
DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyExpenseId_key";

ALTER TABLE "FinancialPaymentRecord"
  DROP COLUMN IF EXISTS "legacyExpenseId";
