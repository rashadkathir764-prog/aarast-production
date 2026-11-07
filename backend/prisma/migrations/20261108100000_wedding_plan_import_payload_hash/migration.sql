-- RA-BE-65: what a local plan's import held, so a retry with other content is
-- told apart from a replay of the same save. Null on plans imported before it.
-- AlterTable
ALTER TABLE "WeddingPlan" ADD COLUMN "importPayloadHash" TEXT;
