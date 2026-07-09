-- Bridge the old Debt / Installment storage into the FinancialCommitment
-- backbone without deleting legacy rows. Old API routes can keep returning
-- their legacy response shapes while the money product reads one financial
-- source of truth.

ALTER TABLE "FinancialPaymentRecord"
  ADD COLUMN "legacyDebtId" TEXT,
  ADD COLUMN "legacyInstallmentId" TEXT;

ALTER TABLE "FinancialInstallment"
  ADD COLUMN "legacyInstallmentId" TEXT;

CREATE UNIQUE INDEX "FinancialPaymentRecord_legacyDebtId_key"
  ON "FinancialPaymentRecord"("legacyDebtId");

CREATE UNIQUE INDEX "FinancialPaymentRecord_legacyInstallmentId_key"
  ON "FinancialPaymentRecord"("legacyInstallmentId");

CREATE UNIQUE INDEX "FinancialInstallment_legacyInstallmentId_key"
  ON "FinancialInstallment"("legacyInstallmentId");

INSERT INTO "BudgetCategory" (
  "id",
  "weddingPlanId",
  "name",
  "createdAt",
  "updatedAt"
)
SELECT
  'legacy-debt-category-' || plan."id",
  plan."id",
  'مستحقات قديمة',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "WeddingPlan" plan
WHERE EXISTS (
  SELECT 1
  FROM "Debt" debt
  WHERE debt."weddingPlanId" = plan."id"
)
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "FinancialCommitment" (
  "id",
  "weddingPlanId",
  "budgetCategoryId",
  "sourceType",
  "title",
  "partyName",
  "partyPhone",
  "totalAmount",
  "paidAmount",
  "dueDate",
  "agreementDate",
  "status",
  "note",
  "legacyDebtId",
  "createdAt",
  "updatedAt"
)
SELECT
  'legacy-financial-commitment-' || debt."id",
  debt."weddingPlanId",
  'legacy-debt-category-' || debt."weddingPlanId",
  'MANUAL_DEBT',
  debt."title",
  debt."creditorName",
  debt."creditorPhone",
  debt."totalAmount",
  debt."paidAmount",
  debt."dueDate",
  debt."createdAt",
  CASE
    WHEN debt."status" = 'CANCELLED' THEN 'CANCELLED'::"FinancialCommitmentStatus"
    WHEN debt."totalAmount" <= 0 OR debt."paidAmount" <= 0 THEN 'OPEN'::"FinancialCommitmentStatus"
    WHEN debt."paidAmount" >= debt."totalAmount" THEN 'PAID'::"FinancialCommitmentStatus"
    ELSE 'PARTIALLY_PAID'::"FinancialCommitmentStatus"
  END,
  debt."note",
  debt."id",
  debt."createdAt",
  debt."updatedAt"
FROM "Debt" debt
WHERE NOT EXISTS (
  SELECT 1
  FROM "FinancialCommitment" existing
  WHERE existing."legacyDebtId" = debt."id"
)
ON CONFLICT ("legacyDebtId") DO NOTHING;

WITH paid_installments AS (
  SELECT
    installment."debtId",
    COALESCE(SUM(installment."amount"), 0) AS "paidTotal"
  FROM "Installment" installment
  WHERE installment."status" = 'PAID'
  GROUP BY installment."debtId"
),
direct_debt_payments AS (
  SELECT
    debt."id" AS "debtId",
    debt."weddingPlanId",
    commitment."id" AS "financialCommitmentId",
    commitment."budgetCategoryId",
    debt."title",
    debt."note",
    debt."createdAt",
    debt."updatedAt",
    GREATEST(debt."paidAmount" - COALESCE(paid_installments."paidTotal", 0), 0) AS "directPaid"
  FROM "Debt" debt
  JOIN "FinancialCommitment" commitment
    ON commitment."legacyDebtId" = debt."id"
  LEFT JOIN paid_installments
    ON paid_installments."debtId" = debt."id"
  WHERE debt."status" <> 'CANCELLED'
)
INSERT INTO "FinancialPaymentRecord" (
  "id",
  "weddingPlanId",
  "financialCommitmentId",
  "budgetCategoryId",
  "title",
  "amount",
  "paidAt",
  "note",
  "legacyDebtId",
  "createdAt",
  "updatedAt"
)
SELECT
  'legacy-debt-payment-' || direct_debt_payments."debtId",
  direct_debt_payments."weddingPlanId",
  direct_debt_payments."financialCommitmentId",
  direct_debt_payments."budgetCategoryId",
  'دفعة مسجلة: ' || direct_debt_payments."title",
  direct_debt_payments."directPaid",
  direct_debt_payments."updatedAt",
  direct_debt_payments."note",
  direct_debt_payments."debtId",
  direct_debt_payments."createdAt",
  direct_debt_payments."updatedAt"
FROM direct_debt_payments
WHERE direct_debt_payments."directPaid" > 0
ON CONFLICT ("legacyDebtId") DO NOTHING;

INSERT INTO "FinancialInstallment" (
  "id",
  "weddingPlanId",
  "financialCommitmentId",
  "budgetCategoryId",
  "amount",
  "dueDate",
  "paidAt",
  "status",
  "note",
  "legacyInstallmentId",
  "createdAt",
  "updatedAt"
)
SELECT
  'legacy-financial-installment-' || installment."id",
  debt."weddingPlanId",
  commitment."id",
  commitment."budgetCategoryId",
  installment."amount",
  installment."dueDate",
  installment."paidAt",
  installment."status",
  installment."note",
  installment."id",
  installment."createdAt",
  installment."updatedAt"
FROM "Installment" installment
JOIN "Debt" debt
  ON debt."id" = installment."debtId"
JOIN "FinancialCommitment" commitment
  ON commitment."legacyDebtId" = debt."id"
WHERE NOT EXISTS (
  SELECT 1
  FROM "FinancialInstallment" existing
  WHERE existing."legacyInstallmentId" = installment."id"
)
ON CONFLICT ("legacyInstallmentId") DO NOTHING;

INSERT INTO "FinancialPaymentRecord" (
  "id",
  "weddingPlanId",
  "financialCommitmentId",
  "budgetCategoryId",
  "title",
  "amount",
  "paidAt",
  "note",
  "legacyInstallmentId",
  "createdAt",
  "updatedAt"
)
SELECT
  'legacy-installment-payment-' || installment."id",
  debt."weddingPlanId",
  commitment."id",
  commitment."budgetCategoryId",
  'قسط: ' || debt."title",
  installment."amount",
  COALESCE(installment."paidAt", installment."updatedAt", installment."createdAt"),
  installment."note",
  installment."id",
  installment."createdAt",
  installment."updatedAt"
FROM "Installment" installment
JOIN "Debt" debt
  ON debt."id" = installment."debtId"
JOIN "FinancialCommitment" commitment
  ON commitment."legacyDebtId" = debt."id"
WHERE installment."status" = 'PAID'
  AND installment."amount" > 0
ON CONFLICT ("legacyInstallmentId") DO NOTHING;
