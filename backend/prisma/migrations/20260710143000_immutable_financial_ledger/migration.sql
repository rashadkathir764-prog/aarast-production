-- Every payment is an append-only ledger entry. Reversals are separate rows;
-- the original payment is retained for audit and reconciliation.
CREATE TYPE "FinancialPaymentRecordType" AS ENUM ('PAYMENT', 'REVERSAL');

ALTER TABLE "FinancialPaymentRecord"
  ADD COLUMN "entryType" "FinancialPaymentRecordType" NOT NULL DEFAULT 'PAYMENT',
  ADD COLUMN "financialInstallmentId" TEXT,
  ADD COLUMN "reversalOfId" TEXT;

-- Backfill the one-to-one link for paid installments mirrored before this
-- migration. Primary (non-legacy) installment payments will set it at write.
UPDATE "FinancialPaymentRecord" payment
SET "financialInstallmentId" = installment."id"
FROM "FinancialInstallment" installment
WHERE payment."legacyInstallmentId" IS NOT NULL
  AND installment."legacyInstallmentId" = payment."legacyInstallmentId";

DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyDebtId_key";
DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyInstallmentId_key";

CREATE INDEX "FinancialPaymentRecord_legacyDebtId_idx"
  ON "FinancialPaymentRecord"("legacyDebtId");
CREATE INDEX "FinancialPaymentRecord_legacyInstallmentId_idx"
  ON "FinancialPaymentRecord"("legacyInstallmentId");
CREATE UNIQUE INDEX "FinancialPaymentRecord_financialInstallmentId_key"
  ON "FinancialPaymentRecord"("financialInstallmentId");
CREATE UNIQUE INDEX "FinancialPaymentRecord_reversalOfId_key"
  ON "FinancialPaymentRecord"("reversalOfId");

ALTER TABLE "FinancialPaymentRecord"
  ADD CONSTRAINT "FinancialPaymentRecord_financialInstallmentId_fkey"
  FOREIGN KEY ("financialInstallmentId") REFERENCES "FinancialInstallment"("id")
  ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "FinancialPaymentRecord_reversalOfId_fkey"
  FOREIGN KEY ("reversalOfId") REFERENCES "FinancialPaymentRecord"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "FinancialPaymentRecord_reversal_type"
  CHECK ("reversalOfId" IS NULL OR "entryType" = 'REVERSAL');
