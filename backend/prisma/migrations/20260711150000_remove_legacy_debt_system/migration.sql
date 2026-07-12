-- Aarast has no production users yet. FinancialCommitment and
-- FinancialInstallment are now the only supported obligation models.

ALTER TABLE "SharedMember"
  ADD COLUMN "canViewFinancialRecords" BOOLEAN NOT NULL DEFAULT false;
UPDATE "SharedMember"
SET "canViewFinancialRecords" = "canViewDebts";
ALTER TABLE "SharedMember" DROP COLUMN "canViewDebts";

ALTER TABLE "PlanInvite"
  ADD COLUMN "canViewFinancialRecords" BOOLEAN NOT NULL DEFAULT false;
UPDATE "PlanInvite"
SET "canViewFinancialRecords" = "canViewDebts";
ALTER TABLE "PlanInvite" DROP COLUMN "canViewDebts";

-- Refuse destructive cleanup if the bridge migration did not create a
-- canonical row for every legacy obligation. The current databases are empty,
-- but this executable guard prevents accidental silent loss on any copied or
-- unexpected environment.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "Debt" debt
    LEFT JOIN "FinancialCommitment" commitment
      ON commitment."legacyDebtId" = debt."id"
    WHERE commitment."id" IS NULL
  ) THEN
    RAISE EXCEPTION 'Legacy Debt rows are not fully migrated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "Installment" installment
    LEFT JOIN "FinancialInstallment" financial_installment
      ON financial_installment."legacyInstallmentId" = installment."id"
    WHERE financial_installment."id" IS NULL
  ) THEN
    RAISE EXCEPTION 'Legacy Installment rows are not fully migrated';
  END IF;
END $$;

DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyDebtId_idx";
DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyInstallmentId_idx";
ALTER TABLE "FinancialPaymentRecord"
  DROP COLUMN "legacyDebtId",
  DROP COLUMN "legacyInstallmentId";

DROP INDEX IF EXISTS "FinancialInstallment_legacyInstallmentId_key";
ALTER TABLE "FinancialInstallment" DROP COLUMN "legacyInstallmentId";

DROP INDEX IF EXISTS "FinancialCommitment_legacyDebtId_key";
ALTER TABLE "FinancialCommitment" DROP COLUMN "legacyDebtId";

DROP TABLE IF EXISTS "Installment";
DROP TABLE IF EXISTS "Debt";
DROP TYPE IF EXISTS "DebtStatus";

ALTER TYPE "FinancialCommitmentSourceType" RENAME TO "FinancialCommitmentSourceType_old";
CREATE TYPE "FinancialCommitmentSourceType" AS ENUM (
  'PROVIDER_SERVICE',
  'MANUAL_PAYABLE',
  'MANUAL_COMMITMENT',
  'OTHER'
);
ALTER TABLE "FinancialCommitment"
  ALTER COLUMN "sourceType" DROP DEFAULT,
  ALTER COLUMN "sourceType" TYPE "FinancialCommitmentSourceType"
  USING (
    CASE
      WHEN "sourceType"::text = 'MANUAL_DEBT' THEN 'MANUAL_PAYABLE'
      ELSE "sourceType"::text
    END
  )::"FinancialCommitmentSourceType",
  ALTER COLUMN "sourceType" SET DEFAULT 'MANUAL_COMMITMENT';
DROP TYPE "FinancialCommitmentSourceType_old";
