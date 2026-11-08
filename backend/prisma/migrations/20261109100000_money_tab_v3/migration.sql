-- D105 to D109 (the money tab, approved 2026-11-09). Every column is
-- new and optional or defaulted to today's meaning, so old apps read and write
-- as before (D93).

-- D109: what the owner expects an item to cost, apart from its allocation (a
-- share of the budget that never exceeds it). The estimate is free: it may be
-- set before a budget and may pass it, and that is the early warning. Zero is
-- an answer («ما بيكلف شي»), not a missing estimate.
ALTER TABLE "BudgetCategory" ADD COLUMN "estimatedAmount" DECIMAL(14,2);
ALTER TABLE "BudgetCategory" ADD CONSTRAINT "BudgetCategory_estimated_amount_non_negative"
  CHECK ("estimatedAmount" IS NULL OR "estimatedAmount" >= 0);

-- D107: an expense is an agreement paid in full the day it was recorded.
CREATE TYPE "CostEntryKind" AS ENUM ('AGREEMENT', 'EXPENSE');
ALTER TABLE "WeddingCost" ADD COLUMN "entryKind" "CostEntryKind" NOT NULL DEFAULT 'AGREEMENT';

-- D105: what part of its item's estimate an agreement settles. WHOLE (every
-- agreement so far) drops the rest of the estimate; PART settles
-- "estimatePart" of it and leaves the rest expected.
CREATE TYPE "EstimateCover" AS ENUM ('WHOLE', 'PART');
ALTER TABLE "WeddingCost" ADD COLUMN "estimateCover" "EstimateCover" NOT NULL DEFAULT 'WHOLE';
ALTER TABLE "WeddingCost" ADD COLUMN "estimatePart" DECIMAL(14,2);
ALTER TABLE "WeddingCost" ADD CONSTRAINT "WeddingCost_estimate_part_check" CHECK (
  ("estimateCover" = 'WHOLE' AND "estimatePart" IS NULL)
  OR ("estimateCover" = 'PART' AND "estimatePart" IS NOT NULL AND "estimatePart" > 0)
);

-- D106: a reminder day of its own, and the first due day of a rescheduled date.
ALTER TABLE "PaymentSchedule" ADD COLUMN "remindAt" TIMESTAMP(3);
ALTER TABLE "PaymentSchedule" ADD COLUMN "rescheduledFrom" TIMESTAMP(3);

-- D106: a partial payment is a free payment that lowered a pending date by its
-- amount; the link lets its reversal give the amount back. Same agreement
-- only, and a date with such a payment is not deleted.
ALTER TABLE "CostPayment" ADD COLUMN "lowersScheduleId" TEXT;
ALTER TABLE "CostPayment" ADD CONSTRAINT "CostPayment_lowers_schedule_same_cost_fkey"
  FOREIGN KEY ("lowersScheduleId", "weddingCostId") REFERENCES "PaymentSchedule"("id", "weddingCostId")
  ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "CostPayment_lowersScheduleId_idx" ON "CostPayment"("lowersScheduleId");

-- D108: who gave or promised the money, matched with the agreements' payer names.
ALTER TABLE "FundingSource" ADD COLUMN "contributorName" TEXT;

-- RA-BE-109: a pending date that asks for less than its amount (a straight
-- payment came after it, RA-BE-53) could not be edited at all: moving its
-- day, its note or its reminder re-checked the old amount against what is
-- left and was refused. The rule is about claiming money: a date is checked
-- when it is written new, when it comes back pending, or when its amount
-- goes up; changing anything else, or lowering it, claims nothing new.
CREATE OR REPLACE FUNCTION "aarast_validate_payment_schedule_amount_at_write"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  remaining_amount DECIMAL(14,2);
BEGIN
  IF NEW."status" <> 'PENDING' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD."status" = 'PENDING'
     AND NEW."amount" <= OLD."amount" THEN
    RETURN NEW;
  END IF;

  SELECT cost."totalAmount" - cost."paidAmount"
  INTO remaining_amount
  FROM "WeddingCost" cost
  WHERE cost."id" = NEW."weddingCostId"
  FOR SHARE;

  IF FOUND AND NEW."amount" > remaining_amount THEN
    RAISE EXCEPTION 'payment schedule amount exceeds the remaining cost %', NEW."weddingCostId";
  END IF;
  RETURN NEW;
END $$;
