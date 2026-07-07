-- Financial invariants enforced at the database layer as a last line of
-- defense. Application code already validates these; the constraints
-- guarantee that no future code path, manual SQL, or import script can
-- persist corrupted money data.

-- Amounts can never be negative.
ALTER TABLE "Expense"
  ADD CONSTRAINT "Expense_amount_non_negative" CHECK ("amount" >= 0);

ALTER TABLE "Debt"
  ADD CONSTRAINT "Debt_amounts_non_negative"
  CHECK ("totalAmount" >= 0 AND "paidAmount" >= 0);

ALTER TABLE "Installment"
  ADD CONSTRAINT "Installment_amount_non_negative" CHECK ("amount" >= 0);

ALTER TABLE "FinancialCommitment"
  ADD CONSTRAINT "FinancialCommitment_amounts_non_negative"
  CHECK ("totalAmount" >= 0 AND "paidAmount" >= 0);

ALTER TABLE "FinancialInstallment"
  ADD CONSTRAINT "FinancialInstallment_amount_non_negative"
  CHECK ("amount" >= 0);

-- A recorded payment of zero or less is meaningless and would silently
-- skew paid totals; every creation path requires a positive amount.
ALTER TABLE "FinancialPaymentRecord"
  ADD CONSTRAINT "FinancialPaymentRecord_amount_positive" CHECK ("amount" > 0);

-- Paid can never exceed the agreed total.
ALTER TABLE "Debt"
  ADD CONSTRAINT "Debt_paid_within_total"
  CHECK ("paidAmount" <= "totalAmount");

ALTER TABLE "FinancialCommitment"
  ADD CONSTRAINT "FinancialCommitment_paid_within_total"
  CHECK ("paidAmount" <= "totalAmount");
