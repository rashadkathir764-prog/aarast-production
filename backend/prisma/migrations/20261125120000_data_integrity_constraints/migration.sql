-- RA-BE-180: money, budgets and ratings are held by the database, and the ids
-- that are real references are foreign keys. Before this the server was the
-- only guard: a direct write, a script or a bug could save a negative amount,
-- a rating of 9 or a task linked to an item that was never there.
--
-- Every constraint is added after the rows already there are checked, in this
-- file, so a database that holds a bad row stops the deploy with a message
-- that names the table and the rows, instead of a bare constraint error. No
-- money row is deleted or changed to make a CHECK pass: a row that breaks one
-- is for a person to read, and this migration fails until it is settled.
-- The only data written is where the right value is not in doubt: a budget
-- range saved the wrong way round is put the right way round (both figures
-- stay), and a link to something that no longer exists is cleared.

-- ---------------------------------------------------------------------------
-- 1. The rows that would break a CHECK stop the migration, named.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  rule record;
  bad bigint;
  sample text;
BEGIN
  FOR rule IN
    SELECT * FROM (VALUES
      ('FundingSource',  'a funding source is more than zero',        '"amount" <= 0'),
      ('LoanRepayment',  'a repayment is more than zero',             '"amount" <= 0'),
      ('QuoteOffer',     'an offer that states an amount states more than zero', '"amount" IS NOT NULL AND "amount" <= 0'),
      ('ProviderService','a service price is not negative',           '"basePrice" < 0'),
      ('QuoteRequest',   'a budget figure is not negative',           '"budgetMin" < 0 OR "budgetMax" < 0'),
      ('ProviderReview', 'a rating is from 1 to 5',                   '"rating" < 1 OR "rating" > 5')
    ) AS checked(tbl, must, violation)
  LOOP
    EXECUTE format('SELECT count(*) FROM %I WHERE %s', rule.tbl, rule.violation) INTO bad;
    IF bad > 0 THEN
      EXECUTE format(
        'SELECT string_agg("id"::text, '', '') FROM (SELECT "id" FROM %I WHERE %s ORDER BY "id" LIMIT 5) AS first_rows',
        rule.tbl, rule.violation
      ) INTO sample;
      RAISE EXCEPTION
        'RA-BE-180: % row(s) of "%" break the rule that %. No row is deleted or changed by this migration; correct them by hand and run it again. First ids: %',
        bad, rule.tbl, rule.must, sample;
    END IF;
  END LOOP;
END
$$;

-- A budget range saved the wrong way round (the customer typed the larger
-- figure first): the two figures swap, nothing is lost. The server already
-- refuses such a range.
UPDATE "QuoteRequest"
SET "budgetMin" = "budgetMax", "budgetMax" = "budgetMin"
WHERE "budgetMin" > "budgetMax";

-- ---------------------------------------------------------------------------
-- 2. The CHECK constraints.
-- ---------------------------------------------------------------------------
ALTER TABLE "FundingSource"
  ADD CONSTRAINT "FundingSource_amount_positive" CHECK ("amount" > 0);

ALTER TABLE "LoanRepayment"
  ADD CONSTRAINT "LoanRepayment_amount_positive" CHECK ("amount" > 0);

-- An offer may state no amount (null); one that does states more than zero.
ALTER TABLE "QuoteOffer"
  ADD CONSTRAINT "QuoteOffer_amount_positive" CHECK ("amount" > 0);

-- A service may have no price (null); a price of nothing is allowed ("free").
ALTER TABLE "ProviderService"
  ADD CONSTRAINT "ProviderService_basePrice_nonnegative" CHECK ("basePrice" >= 0);

-- Either figure may be missing; those that are there are not negative and the
-- smallest is not above the largest.
ALTER TABLE "QuoteRequest"
  ADD CONSTRAINT "QuoteRequest_budget_range_check" CHECK (
    "budgetMin" >= 0 AND "budgetMax" >= 0 AND "budgetMin" <= "budgetMax"
  );

ALTER TABLE "ProviderReview"
  ADD CONSTRAINT "ProviderReview_rating_range" CHECK ("rating" BETWEEN 1 AND 5);

-- ---------------------------------------------------------------------------
-- 3. Foreign keys. A reference to something that is gone is cleared first
--    (it pointed at nothing); the keys then keep it true.
-- ---------------------------------------------------------------------------

-- GuestInvitationSend: a send belongs to its guest's plan.
UPDATE "GuestInvitationSend" AS send
SET "weddingPlanId" = guest."weddingPlanId"
FROM "Guest" AS guest
WHERE guest."id" = send."guestId"
  AND guest."weddingPlanId" <> send."weddingPlanId";

-- A send made for an occasion that was deleted is what the cascade removes
-- from now on; the ones already left behind go the same way. (A record of
-- what a guest was told is not money.)
DELETE FROM "GuestInvitationSend" AS send
WHERE send."planEventId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "PlanEvent" WHERE "id" = send."planEventId");

-- The person who prepared it may be gone; the record stays.
UPDATE "GuestInvitationSend" AS send
SET "createdByUserId" = NULL
WHERE send."createdByUserId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = send."createdByUserId");

ALTER TABLE "GuestInvitationSend"
  ADD CONSTRAINT "GuestInvitationSend_weddingPlanId_fkey"
  FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "GuestInvitationSend"
  ADD CONSTRAINT "GuestInvitationSend_planEventId_fkey"
  FOREIGN KEY ("planEventId") REFERENCES "PlanEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "GuestInvitationSend"
  ADD CONSTRAINT "GuestInvitationSend_createdByUserId_fkey"
  FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- The keys' own lookups (an occasion or a user that is deleted finds its
-- sends by these) read only the rows that hold a reference.
CREATE INDEX "GuestInvitationSend_planEventId_idx"
  ON "GuestInvitationSend"("planEventId") WHERE "planEventId" IS NOT NULL;
CREATE INDEX "GuestInvitationSend_createdByUserId_idx"
  ON "GuestInvitationSend"("createdByUserId") WHERE "createdByUserId" IS NOT NULL;

-- WeddingTask: the budget item, the cost and the payment a task waits on.
UPDATE "WeddingTask" AS task
SET "linkedBudgetCategoryId" = NULL
WHERE task."linkedBudgetCategoryId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "BudgetCategory" WHERE "id" = task."linkedBudgetCategoryId");
UPDATE "WeddingTask" AS task
SET "linkedCostId" = NULL
WHERE task."linkedCostId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "WeddingCost" WHERE "id" = task."linkedCostId");
UPDATE "WeddingTask" AS task
SET "linkedScheduleId" = NULL
WHERE task."linkedScheduleId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "PaymentSchedule" WHERE "id" = task."linkedScheduleId");

ALTER TABLE "WeddingTask"
  ADD CONSTRAINT "WeddingTask_linkedBudgetCategoryId_fkey"
  FOREIGN KEY ("linkedBudgetCategoryId") REFERENCES "BudgetCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "WeddingTask"
  ADD CONSTRAINT "WeddingTask_linkedCostId_fkey"
  FOREIGN KEY ("linkedCostId") REFERENCES "WeddingCost"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "WeddingTask"
  ADD CONSTRAINT "WeddingTask_linkedScheduleId_fkey"
  FOREIGN KEY ("linkedScheduleId") REFERENCES "PaymentSchedule"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- The existing indexes lead with the plan; deleting a budget item, a cost or
-- a payment finds its tasks by the link alone.
CREATE INDEX "WeddingTask_linkedBudgetCategoryId_idx"
  ON "WeddingTask"("linkedBudgetCategoryId") WHERE "linkedBudgetCategoryId" IS NOT NULL;
CREATE INDEX "WeddingTask_linkedCostId_idx"
  ON "WeddingTask"("linkedCostId") WHERE "linkedCostId" IS NOT NULL;
CREATE INDEX "WeddingTask_linkedScheduleId_idx"
  ON "WeddingTask"("linkedScheduleId") WHERE "linkedScheduleId" IS NOT NULL;

-- Booking: who asked for it. A member who asked may leave (account erasure)
-- and the booking, which is the provider's calendar, stays, so the column may
-- now be empty. The server only writes it; nothing reads it as always set.
ALTER TABLE "Booking" ALTER COLUMN "requestedByUserId" DROP NOT NULL;

UPDATE "Booking"
SET "requestedByUserId" = NULL
WHERE "requestedByUserId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "Booking"."requestedByUserId");

ALTER TABLE "Booking"
  ADD CONSTRAINT "Booking_requestedByUserId_fkey"
  FOREIGN KEY ("requestedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Booking_requestedByUserId_idx"
  ON "Booking"("requestedByUserId") WHERE "requestedByUserId" IS NOT NULL;
