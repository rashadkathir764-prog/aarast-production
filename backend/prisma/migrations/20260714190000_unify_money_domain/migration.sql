-- PRELAUNCH DESTRUCTIVE RESET
-- Aarast has no real users yet. The four experimental finance systems are
-- intentionally discarded instead of guessing how incompatible records map.
-- WeddingPlan budget/currency and normalized BudgetCategory rows are retained.

BEGIN;

CREATE TYPE "WeddingCostStatus" AS ENUM ('OPEN', 'PARTIALLY_PAID', 'PAID', 'CANCELLED');
CREATE TYPE "CostPaymentType" AS ENUM ('PAYMENT', 'REVERSAL');
CREATE TYPE "PaymentScheduleStatus" AS ENUM ('PENDING', 'PAID', 'CANCELLED');

ALTER TABLE "BudgetCategory"
  ADD COLUMN "normalizedName" TEXT,
  ADD COLUMN "allocatedAmount" DECIMAL(14,2);

-- Old experimental clients could persist a whitespace-only display name.
-- Repair it before deriving the canonical key so the retained category never
-- appears as a blank row in the product.
UPDATE "BudgetCategory"
SET "name" = 'غير مصنف'
WHERE trim("name") = '';

UPDATE "BudgetCategory"
SET
  "normalizedName" = COALESCE(
    NULLIF(lower(regexp_replace(trim("name"), '\s+', ' ', 'g')), ''),
    'غير مصنف'
  ),
  "allocatedAmount" = CASE
    WHEN "targetAmount" > 0 THEN "targetAmount"
    ELSE NULL
  END;

-- Remove the old domains before merging duplicate categories so their foreign
-- keys cannot preserve duplicate category rows. No old financial row is copied.
DROP TABLE "FinancialPaymentRecord";
DROP TABLE "FinancialInstallment";
DROP TABLE "FinancialCommitment";
DROP TABLE "Expense";

DROP TYPE "FinancialPaymentRecordType";
DROP TYPE "FinancialCommitmentStatus";
DROP TYPE "FinancialCommitmentSourceType";
DROP TYPE "ExpenseStatus";
DROP TYPE "InstallmentStatus";

-- The general budget is either intentionally unset or a positive amount, and
-- currency is one normalized ISO code everywhere in the money domain.
UPDATE "WeddingPlan"
SET "estimatedBudget" = NULL
WHERE "estimatedBudget" IS NOT NULL AND "estimatedBudget" <= 0;

UPDATE "WeddingPlan"
SET "currency" = upper(trim("currency"));

UPDATE "WeddingPlan"
SET "currency" = 'YER'
WHERE "currency" !~ '^[A-Z]{3}$';

ALTER TABLE "WeddingPlan"
  ADD CONSTRAINT "WeddingPlan_estimated_budget_positive"
    CHECK ("estimatedBudget" IS NULL OR "estimatedBudget" > 0),
  ADD CONSTRAINT "WeddingPlan_currency_iso_code"
    CHECK ("currency" ~ '^[A-Z]{3}$');

-- Categories created only as a bridge for the removed debt domain must not
-- survive as unexplained empty rows in the new product.
DELETE FROM "BudgetCategory"
WHERE "id" LIKE 'legacy-debt-category-%';

-- Reassert the current ownership lifecycle explicitly. A plan cannot be
-- removed while category records still exist; account deletion orders the
-- children intentionally.
ALTER TABLE "BudgetCategory"
  DROP CONSTRAINT "BudgetCategory_weddingPlanId_fkey";
ALTER TABLE "BudgetCategory"
  ADD CONSTRAINT "BudgetCategory_weddingPlanId_fkey"
  FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Keep the oldest category for each normalized name. MAX avoids inflating an
-- allocation by summing duplicate hints from the experimental UI.
WITH grouped AS (
  SELECT
    first_value("id") OVER (
      PARTITION BY "weddingPlanId", "normalizedName"
      ORDER BY "createdAt", "id"
    ) AS canonical_id,
    max("allocatedAmount") OVER (
      PARTITION BY "weddingPlanId", "normalizedName"
    ) AS canonical_allocation
  FROM "BudgetCategory"
)
UPDATE "BudgetCategory" category
SET "allocatedAmount" = grouped.canonical_allocation
FROM grouped
WHERE category."id" = grouped.canonical_id;

WITH ranked AS (
  SELECT
    "id",
    first_value("id") OVER (
      PARTITION BY "weddingPlanId", "normalizedName"
      ORDER BY "createdAt", "id"
    ) AS canonical_id
  FROM "BudgetCategory"
)
DELETE FROM "BudgetCategory" category
USING ranked
WHERE category."id" = ranked."id"
  AND ranked."id" <> ranked.canonical_id;

-- Allocations are meaningful only under a general budget. If historic hints
-- form an impossible total, clear the whole plan rather than inventing values.
UPDATE "BudgetCategory" category
SET "allocatedAmount" = NULL
FROM "WeddingPlan" plan
WHERE category."weddingPlanId" = plan."id"
  AND plan."estimatedBudget" IS NULL;

WITH invalid_plans AS (
  SELECT category."weddingPlanId"
  FROM "BudgetCategory" category
  JOIN "WeddingPlan" plan ON plan."id" = category."weddingPlanId"
  WHERE plan."estimatedBudget" IS NOT NULL
  GROUP BY category."weddingPlanId", plan."estimatedBudget"
  HAVING COALESCE(SUM(category."allocatedAmount"), 0) > plan."estimatedBudget"
)
UPDATE "BudgetCategory" category
SET "allocatedAmount" = NULL
FROM invalid_plans
WHERE category."weddingPlanId" = invalid_plans."weddingPlanId";

ALTER TABLE "BudgetCategory"
  ALTER COLUMN "normalizedName" SET NOT NULL,
  DROP COLUMN "targetAmount";

ALTER TABLE "BudgetCategory"
  ADD CONSTRAINT "BudgetCategory_allocation_non_negative"
    CHECK ("allocatedAmount" IS NULL OR "allocatedAmount" >= 0);

CREATE UNIQUE INDEX "BudgetCategory_weddingPlanId_normalizedName_key"
  ON "BudgetCategory"("weddingPlanId", "normalizedName");
CREATE UNIQUE INDEX "BudgetCategory_id_weddingPlanId_key"
  ON "BudgetCategory"("id", "weddingPlanId");

CREATE TABLE "WeddingCost" (
  "id" TEXT NOT NULL,
  "weddingPlanId" TEXT NOT NULL,
  "budgetCategoryId" TEXT NOT NULL,
  "providerId" TEXT,
  "quoteOfferId" TEXT,
  "title" TEXT NOT NULL,
  "partyName" TEXT,
  "partyPhone" TEXT,
  "totalAmount" DECIMAL(14,2) NOT NULL,
  "paidAmount" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "agreementDate" TIMESTAMP(3),
  "status" "WeddingCostStatus" NOT NULL DEFAULT 'OPEN',
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "WeddingCost_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "WeddingCost_total_positive" CHECK ("totalAmount" > 0),
  CONSTRAINT "WeddingCost_paid_non_negative" CHECK ("paidAmount" >= 0),
  CONSTRAINT "WeddingCost_paid_within_total" CHECK ("paidAmount" <= "totalAmount"),
  CONSTRAINT "WeddingCost_external_party_exclusive" CHECK (
    "providerId" IS NULL OR ("partyName" IS NULL AND "partyPhone" IS NULL)
  ),
  CONSTRAINT "WeddingCost_status_matches_balance" CHECK (
    ("status" = 'CANCELLED' AND "paidAmount" = 0) OR
    ("status" = 'OPEN' AND "paidAmount" = 0) OR
    ("status" = 'PARTIALLY_PAID' AND "paidAmount" > 0 AND "paidAmount" < "totalAmount") OR
    ("status" = 'PAID' AND "paidAmount" = "totalAmount")
  )
);

CREATE TABLE "PaymentSchedule" (
  "id" TEXT NOT NULL,
  "weddingCostId" TEXT NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "dueDate" TIMESTAMP(3) NOT NULL,
  "paidAt" TIMESTAMP(3),
  "status" "PaymentScheduleStatus" NOT NULL DEFAULT 'PENDING',
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PaymentSchedule_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "PaymentSchedule_amount_positive" CHECK ("amount" > 0),
  CONSTRAINT "PaymentSchedule_status_matches_paid_at" CHECK (
    ("status" = 'PAID' AND "paidAt" IS NOT NULL) OR
    ("status" <> 'PAID' AND "paidAt" IS NULL)
  )
);

CREATE TABLE "CostPayment" (
  "id" TEXT NOT NULL,
  "weddingCostId" TEXT NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "entryType" "CostPaymentType" NOT NULL DEFAULT 'PAYMENT',
  "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "method" TEXT,
  "note" TEXT,
  "paymentScheduleId" TEXT,
  "reversalOfId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CostPayment_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "CostPayment_amount_positive" CHECK ("amount" > 0),
  CONSTRAINT "CostPayment_reversal_type" CHECK (
    ("entryType" = 'PAYMENT' AND "reversalOfId" IS NULL) OR
    ("entryType" = 'REVERSAL' AND "reversalOfId" IS NOT NULL)
  ),
  CONSTRAINT "CostPayment_reversal_has_no_schedule" CHECK (
    "entryType" <> 'REVERSAL' OR "paymentScheduleId" IS NULL
  )
);

CREATE UNIQUE INDEX "WeddingCost_quoteOfferId_key" ON "WeddingCost"("quoteOfferId");
CREATE INDEX "WeddingCost_weddingPlanId_status_idx" ON "WeddingCost"("weddingPlanId", "status");
CREATE INDEX "WeddingCost_budgetCategoryId_idx" ON "WeddingCost"("budgetCategoryId");
CREATE INDEX "WeddingCost_providerId_idx" ON "WeddingCost"("providerId");
CREATE INDEX "PaymentSchedule_weddingCostId_status_dueDate_idx" ON "PaymentSchedule"("weddingCostId", "status", "dueDate");
CREATE INDEX "PaymentSchedule_status_dueDate_idx" ON "PaymentSchedule"("status", "dueDate");
CREATE INDEX "CostPayment_paymentScheduleId_idx" ON "CostPayment"("paymentScheduleId");
CREATE UNIQUE INDEX "CostPayment_reversalOfId_key" ON "CostPayment"("reversalOfId");
CREATE UNIQUE INDEX "CostPayment_reversalOfId_weddingCostId_key" ON "CostPayment"("reversalOfId", "weddingCostId");
CREATE INDEX "CostPayment_weddingCostId_paidAt_idx" ON "CostPayment"("weddingCostId", "paidAt");
CREATE UNIQUE INDEX "CostPayment_id_weddingCostId_key" ON "CostPayment"("id", "weddingCostId");
CREATE UNIQUE INDEX "PaymentSchedule_id_weddingCostId_key" ON "PaymentSchedule"("id", "weddingCostId");

ALTER TABLE "WeddingCost"
  ADD CONSTRAINT "WeddingCost_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "WeddingCost_category_same_plan_fkey" FOREIGN KEY ("budgetCategoryId", "weddingPlanId") REFERENCES "BudgetCategory"("id", "weddingPlanId") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "WeddingCost_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "WeddingCost_quoteOfferId_fkey" FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PaymentSchedule"
  ADD CONSTRAINT "PaymentSchedule_weddingCostId_fkey" FOREIGN KEY ("weddingCostId") REFERENCES "WeddingCost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CostPayment"
  ADD CONSTRAINT "CostPayment_weddingCostId_fkey" FOREIGN KEY ("weddingCostId") REFERENCES "WeddingCost"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "CostPayment_schedule_same_cost_fkey" FOREIGN KEY ("paymentScheduleId", "weddingCostId") REFERENCES "PaymentSchedule"("id", "weddingCostId") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "CostPayment_reversal_same_cost_fkey" FOREIGN KEY ("reversalOfId", "weddingCostId") REFERENCES "CostPayment"("id", "weddingCostId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Cross-row ledger rules are deferred so a service transaction may write the
-- immutable entry and update its denormalized cost/schedule state in either
-- order. Invalid final states are rejected at COMMIT even for direct SQL.
CREATE FUNCTION "aarast_validate_cost_payment_entry"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  current_payment "CostPayment"%ROWTYPE;
  target_payment "CostPayment"%ROWTYPE;
  linked_schedule "PaymentSchedule"%ROWTYPE;
  linked_schedule_id TEXT;
  active_schedule_payments INTEGER;
  active_schedule_amount DECIMAL(14,2);
  active_schedule_paid_at TIMESTAMP(3);
BEGIN
  IF TG_OP = 'DELETE' THEN
    linked_schedule_id := OLD."paymentScheduleId";
    IF OLD."entryType" = 'REVERSAL' THEN
      SELECT "paymentScheduleId" INTO linked_schedule_id
      FROM "CostPayment"
      WHERE "id" = OLD."reversalOfId";
    END IF;
  ELSE
    SELECT * INTO current_payment FROM "CostPayment" WHERE "id" = NEW."id";
    IF NOT FOUND THEN
      RETURN NEW;
    END IF;
  END IF;

  IF TG_OP <> 'DELETE' AND current_payment."entryType" = 'REVERSAL' THEN
    SELECT * INTO target_payment
    FROM "CostPayment"
    WHERE "id" = current_payment."reversalOfId";
    IF NOT FOUND
       OR target_payment."entryType" <> 'PAYMENT'
       OR target_payment."weddingCostId" <> current_payment."weddingCostId"
       OR target_payment."amount" <> current_payment."amount" THEN
      RAISE EXCEPTION 'invalid cost payment reversal %', current_payment."id";
    END IF;
    linked_schedule_id := target_payment."paymentScheduleId";
  END IF;

  IF TG_OP <> 'DELETE' AND current_payment."paymentScheduleId" IS NOT NULL THEN
    linked_schedule_id := current_payment."paymentScheduleId";
    SELECT * INTO linked_schedule
    FROM "PaymentSchedule"
    WHERE "id" = current_payment."paymentScheduleId";
    IF NOT FOUND
       OR current_payment."entryType" <> 'PAYMENT'
       OR linked_schedule."weddingCostId" <> current_payment."weddingCostId"
       OR linked_schedule."amount" <> current_payment."amount" THEN
      RAISE EXCEPTION 'invalid payment schedule link for payment %', current_payment."id";
    END IF;

    SELECT COUNT(*) INTO active_schedule_payments
    FROM "CostPayment" payment
    WHERE payment."paymentScheduleId" = current_payment."paymentScheduleId"
      AND payment."entryType" = 'PAYMENT'
      AND NOT EXISTS (
        SELECT 1 FROM "CostPayment" reversal
        WHERE reversal."reversalOfId" = payment."id"
          AND reversal."entryType" = 'REVERSAL'
      );
    IF active_schedule_payments > 1 THEN
      RAISE EXCEPTION 'payment schedule % has multiple active payments', current_payment."paymentScheduleId";
    END IF;
  END IF;

  IF linked_schedule_id IS NOT NULL THEN
    SELECT * INTO linked_schedule
    FROM "PaymentSchedule"
    WHERE "id" = linked_schedule_id;
    SELECT COUNT(*), MAX(payment."amount"), MAX(payment."paidAt")
    INTO active_schedule_payments, active_schedule_amount, active_schedule_paid_at
    FROM "CostPayment" payment
    WHERE payment."paymentScheduleId" = linked_schedule_id
      AND payment."entryType" = 'PAYMENT'
      AND NOT EXISTS (
        SELECT 1 FROM "CostPayment" reversal
        WHERE reversal."reversalOfId" = payment."id"
          AND reversal."entryType" = 'REVERSAL'
      );
    IF (linked_schedule."status" = 'PAID' AND active_schedule_payments <> 1)
       OR (linked_schedule."status" <> 'PAID' AND active_schedule_payments <> 0)
       OR (
         active_schedule_payments = 1
         AND (
           active_schedule_amount <> linked_schedule."amount"
           OR active_schedule_paid_at IS DISTINCT FROM linked_schedule."paidAt"
         )
       ) THEN
      RAISE EXCEPTION 'payment schedule % does not match its active ledger entry', linked_schedule_id;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER "CostPayment_entry_integrity"
AFTER INSERT OR UPDATE OR DELETE ON "CostPayment"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_cost_payment_entry"();

CREATE FUNCTION "aarast_validate_payment_schedule_state"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  current_schedule "PaymentSchedule"%ROWTYPE;
  active_payments INTEGER;
  active_amount DECIMAL(14,2);
  active_paid_at TIMESTAMP(3);
BEGIN
  SELECT * INTO current_schedule FROM "PaymentSchedule" WHERE "id" = NEW."id";
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT COUNT(*), MAX(payment."amount"), MAX(payment."paidAt")
  INTO active_payments, active_amount, active_paid_at
  FROM "CostPayment" payment
  WHERE payment."paymentScheduleId" = current_schedule."id"
    AND payment."entryType" = 'PAYMENT'
    AND NOT EXISTS (
      SELECT 1 FROM "CostPayment" reversal
      WHERE reversal."reversalOfId" = payment."id"
        AND reversal."entryType" = 'REVERSAL'
    );

  IF (current_schedule."status" = 'PAID' AND active_payments <> 1)
     OR (current_schedule."status" <> 'PAID' AND active_payments <> 0)
     OR (
       active_payments = 1
       AND (
         active_amount <> current_schedule."amount"
         OR active_paid_at IS DISTINCT FROM current_schedule."paidAt"
       )
     ) THEN
    RAISE EXCEPTION 'payment schedule % does not match its active ledger entry', current_schedule."id";
  END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER "PaymentSchedule_ledger_integrity"
AFTER INSERT OR UPDATE ON "PaymentSchedule"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_payment_schedule_state"();

CREATE FUNCTION "aarast_protect_cost_payment_ledger"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'CostPayment is append-only';
  END IF;
  IF TG_OP = 'DELETE'
     AND COALESCE(current_setting('aarast.allow_ledger_purge', true), 'off') <> 'on' THEN
    RAISE EXCEPTION 'CostPayment is append-only';
  END IF;
  RETURN OLD;
END $$;

CREATE TRIGGER "CostPayment_append_only"
BEFORE UPDATE OR DELETE ON "CostPayment"
FOR EACH ROW EXECUTE FUNCTION "aarast_protect_cost_payment_ledger"();

CREATE FUNCTION "aarast_validate_wedding_cost_ledger"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  cost_id TEXT;
  affected_cost_ids TEXT[];
  cost_row "WeddingCost"%ROWTYPE;
  ledger_total DECIMAL(14,2);
BEGIN
  IF TG_TABLE_NAME = 'WeddingCost' THEN
    affected_cost_ids := ARRAY[NEW."id"]::TEXT[];
  ELSIF TG_OP = 'INSERT' THEN
    affected_cost_ids := ARRAY[NEW."weddingCostId"]::TEXT[];
  ELSIF TG_OP = 'DELETE' THEN
    affected_cost_ids := ARRAY[OLD."weddingCostId"]::TEXT[];
  ELSE
    affected_cost_ids := ARRAY[OLD."weddingCostId", NEW."weddingCostId"]::TEXT[];
  END IF;

  FOR cost_id IN
    SELECT DISTINCT value FROM unnest(affected_cost_ids) AS value
  LOOP
    SELECT * INTO cost_row FROM "WeddingCost" WHERE "id" = cost_id;
    IF FOUND THEN
      SELECT COALESCE(SUM(
        CASE WHEN "entryType" = 'REVERSAL' THEN -"amount" ELSE "amount" END
      ), 0)
      INTO ledger_total
      FROM "CostPayment"
      WHERE "weddingCostId" = cost_id;

      IF ledger_total <> cost_row."paidAmount"
         OR ledger_total < 0
         OR ledger_total > cost_row."totalAmount"
         OR (cost_row."status" = 'CANCELLED' AND ledger_total <> 0)
         OR (cost_row."status" = 'OPEN' AND ledger_total <> 0)
         OR (
           cost_row."status" = 'PARTIALLY_PAID'
           AND NOT (ledger_total > 0 AND ledger_total < cost_row."totalAmount")
         )
         OR (cost_row."status" = 'PAID' AND ledger_total <> cost_row."totalAmount") THEN
        RAISE EXCEPTION 'wedding cost % does not match its payment ledger', cost_id;
      END IF;
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER "WeddingCost_ledger_integrity"
AFTER INSERT OR UPDATE ON "WeddingCost"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_wedding_cost_ledger"();

CREATE CONSTRAINT TRIGGER "CostPayment_ledger_integrity"
AFTER INSERT OR UPDATE OR DELETE ON "CostPayment"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_wedding_cost_ledger"();

-- Category allocations and the plan budget form one atomic invariant. The
-- deferred triggers allow the API to replace both sides in one transaction,
-- while direct SQL and future code paths still fail closed at COMMIT.
CREATE FUNCTION "aarast_validate_money_budget"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  plan_id TEXT;
  affected_plan_ids TEXT[];
  plan_budget DECIMAL(14,2);
  allocated_total DECIMAL(14,2);
BEGIN
  IF TG_TABLE_NAME = 'WeddingPlan' THEN
    affected_plan_ids := ARRAY[NEW."id"]::TEXT[];
  ELSIF TG_OP = 'INSERT' THEN
    affected_plan_ids := ARRAY[NEW."weddingPlanId"]::TEXT[];
  ELSIF TG_OP = 'DELETE' THEN
    affected_plan_ids := ARRAY[OLD."weddingPlanId"]::TEXT[];
  ELSE
    affected_plan_ids := ARRAY[OLD."weddingPlanId", NEW."weddingPlanId"]::TEXT[];
  END IF;

  FOR plan_id IN
    SELECT DISTINCT value FROM unnest(affected_plan_ids) AS value
  LOOP
    SELECT "estimatedBudget" INTO plan_budget
    FROM "WeddingPlan"
    WHERE "id" = plan_id;

    IF FOUND THEN
      SELECT COALESCE(SUM("allocatedAmount"), 0)
      INTO allocated_total
      FROM "BudgetCategory"
      WHERE "weddingPlanId" = plan_id;

      IF (plan_budget IS NULL AND allocated_total > 0)
         OR (plan_budget IS NOT NULL AND allocated_total > plan_budget) THEN
        RAISE EXCEPTION 'category allocations exceed the wedding plan budget %', plan_id;
      END IF;
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER "BudgetCategory_money_budget_integrity"
AFTER INSERT OR UPDATE OR DELETE ON "BudgetCategory"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_money_budget"();

CREATE CONSTRAINT TRIGGER "WeddingPlan_money_budget_integrity"
AFTER UPDATE ON "WeddingPlan"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_money_budget"();

-- Validate one reminder against the balance visible at that reminder write.
-- This trigger intentionally never sums reminders and never runs when a later
-- payment reduces the balance. The shared lock serializes this check with cost
-- balance updates while service transactions keep a consistent cost-first
-- lock order.
CREATE FUNCTION "aarast_validate_payment_schedule_amount_at_write"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  remaining_amount DECIMAL(14,2);
BEGIN
  IF NEW."status" <> 'PENDING' THEN
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

CREATE TRIGGER "PaymentSchedule_amount_at_write_integrity"
BEFORE INSERT OR UPDATE ON "PaymentSchedule"
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_payment_schedule_amount_at_write"();

-- A payment schedule is a non-reserving reminder: multiple reminders may each
-- reference the full outstanding balance. The final state must still be
-- coherent, so a paid or cancelled cost cannot retain a pending reminder.
-- This is deferred to let service transactions update the cost and reminders
-- in either order, including an atomic payment reversal.
CREATE FUNCTION "aarast_validate_payment_schedule_cost_status"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  cost_id TEXT;
  affected_cost_ids TEXT[];
BEGIN
  IF TG_TABLE_NAME = 'WeddingCost' THEN
    affected_cost_ids := ARRAY[NEW."id"]::TEXT[];
  ELSIF TG_OP = 'INSERT' THEN
    affected_cost_ids := ARRAY[NEW."weddingCostId"]::TEXT[];
  ELSE
    affected_cost_ids := ARRAY[OLD."weddingCostId", NEW."weddingCostId"]::TEXT[];
  END IF;

  FOR cost_id IN
    SELECT DISTINCT value FROM unnest(affected_cost_ids) AS value
  LOOP
    IF EXISTS (
      SELECT 1
      FROM "WeddingCost" cost
      JOIN "PaymentSchedule" schedule
        ON schedule."weddingCostId" = cost."id"
      WHERE cost."id" = cost_id
        AND cost."status" IN ('PAID', 'CANCELLED')
        AND schedule."status" = 'PENDING'
    ) THEN
      RAISE EXCEPTION 'paid or cancelled wedding cost % cannot retain pending payment schedules', cost_id;
    END IF;
  END LOOP;

  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER "PaymentSchedule_cost_status_integrity"
AFTER INSERT OR UPDATE ON "PaymentSchedule"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_payment_schedule_cost_status"();

CREATE CONSTRAINT TRIGGER "WeddingCost_pending_schedule_integrity"
AFTER INSERT OR UPDATE ON "WeddingCost"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "aarast_validate_payment_schedule_cost_status"();

ALTER TABLE "SharedMember"
  ADD COLUMN "canViewMoney" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "canManageMoney" BOOLEAN NOT NULL DEFAULT false;
UPDATE "SharedMember"
SET
  "canViewMoney" = "canViewFinancialRecords" OR "canManageFinancialRecords",
  "canManageMoney" = "canManageFinancialRecords";
ALTER TABLE "SharedMember"
  DROP COLUMN "canViewBudget",
  DROP COLUMN "canViewExpenses",
  DROP COLUMN "canViewFinancialRecords",
  DROP COLUMN "canManageFinancialRecords",
  ADD CONSTRAINT "SharedMember_manage_money_requires_view"
    CHECK (NOT "canManageMoney" OR "canViewMoney");

ALTER TABLE "PlanInvite"
  ADD COLUMN "canViewMoney" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "canManageMoney" BOOLEAN NOT NULL DEFAULT false;
UPDATE "PlanInvite"
SET
  "canViewMoney" = "canViewFinancialRecords" OR "canManageFinancialRecords",
  "canManageMoney" = "canManageFinancialRecords";
ALTER TABLE "PlanInvite"
  DROP COLUMN "canViewBudget",
  DROP COLUMN "canViewExpenses",
  DROP COLUMN "canViewFinancialRecords",
  DROP COLUMN "canManageFinancialRecords",
  ADD CONSTRAINT "PlanInvite_manage_money_requires_view"
    CHECK (NOT "canManageMoney" OR "canViewMoney");

-- Old reminders point at records intentionally discarded above. Delete them;
-- never rewrite their IDs to a new route that cannot resolve them.
CREATE TEMP TABLE "aarast_removed_finance_notification" ON COMMIT DROP AS
SELECT "id"
FROM "Notification"
WHERE "type"::text IN ('INSTALLMENT_DUE_SOON', 'INSTALLMENT_OVERDUE', 'DEBT_DUE_SOON')
   OR "entityType" IN (
     'financial_installment', 'financial_commitment', 'expense', 'debt', 'installment'
   )
   OR "routeTarget" LIKE '%/financial-commitments/%'
   OR "routeTarget" LIKE '%/financial-installments/%'
   OR "routeTarget" LIKE '%/finance/%'
   OR "routeTarget" LIKE '%/debts/%'
   OR "routeTarget" LIKE '%/expenses/%';

DELETE FROM "OutboxEvent"
WHERE "aggregateType" = 'notification'
  AND "aggregateId" IN (
    SELECT "id" FROM "aarast_removed_finance_notification"
  );

DELETE FROM "Notification"
WHERE "id" IN (
  SELECT "id" FROM "aarast_removed_finance_notification"
);

ALTER TYPE "NotificationType" RENAME TO "NotificationType_old";
CREATE TYPE "NotificationType" AS ENUM (
  'QUOTE_REQUEST_SUBMITTED', 'TASK_DUE_SOON', 'TASK_OVERDUE',
  'PAYMENT_SCHEDULE_DUE_SOON', 'PAYMENT_SCHEDULE_OVERDUE',
  'SHARING_INVITATION', 'SHARING_UPDATED', 'SHARING_INVITE_ACCEPTED',
  'SHARING_INVITE_DECLINED', 'QUOTE_OFFER_RECEIVED', 'QUOTE_ACCEPTED',
  'QUOTE_REJECTED', 'PLAN_UPDATED', 'SYNC_REQUIRED', 'CHAT_MESSAGE_RECEIVED', 'GENERAL'
);
ALTER TABLE "Notification"
  ALTER COLUMN "type" TYPE "NotificationType"
  USING ("type"::text::"NotificationType");
DROP TYPE "NotificationType_old";

-- Transactional postconditions: abort the whole migration on any partial or
-- impossible state.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "WeddingCost" LIMIT 1)
     OR EXISTS (SELECT 1 FROM "CostPayment" LIMIT 1)
     OR EXISTS (SELECT 1 FROM "PaymentSchedule" LIMIT 1) THEN
    RAISE EXCEPTION 'prelaunch finance reset must create empty money tables';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "BudgetCategory" category
    JOIN "WeddingPlan" plan ON plan."id" = category."weddingPlanId"
    GROUP BY category."weddingPlanId", plan."estimatedBudget"
    HAVING
      (plan."estimatedBudget" IS NULL AND COUNT(category."allocatedAmount") > 0)
      OR (
        plan."estimatedBudget" IS NOT NULL
        AND COALESCE(SUM(category."allocatedAmount"), 0) > plan."estimatedBudget"
      )
  ) THEN
    RAISE EXCEPTION 'invalid category allocations after finance reset';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "WeddingPlan"
    WHERE ("estimatedBudget" IS NOT NULL AND "estimatedBudget" <= 0)
       OR "currency" !~ '^[A-Z]{3}$'
  ) THEN
    RAISE EXCEPTION 'invalid plan budget or currency after finance reset';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'PaymentSchedule_amount_at_write_integrity'
      AND tgrelid = '"PaymentSchedule"'::regclass
      AND NOT tgdeferrable
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'PaymentSchedule_cost_status_integrity'
      AND tgrelid = '"PaymentSchedule"'::regclass
      AND tgdeferrable
      AND tginitdeferred
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'WeddingCost_pending_schedule_integrity'
      AND tgrelid = '"WeddingCost"'::regclass
      AND tgdeferrable
      AND tginitdeferred
  ) THEN
    RAISE EXCEPTION 'payment schedule database integrity triggers are missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "BudgetCategory"
    WHERE trim("name") = ''
       OR trim("normalizedName") = ''
       OR "allocatedAmount" < 0
  ) OR EXISTS (
    SELECT 1
    FROM "BudgetCategory"
    GROUP BY "weddingPlanId", "normalizedName"
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'invalid normalized budget categories after finance reset';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "SharedMember" WHERE "canManageMoney" AND NOT "canViewMoney"
  ) OR EXISTS (
    SELECT 1 FROM "PlanInvite" WHERE "canManageMoney" AND NOT "canViewMoney"
  ) THEN
    RAISE EXCEPTION 'money management must imply money visibility';
  END IF;

  IF EXISTS (
    SELECT 1 FROM "Notification"
    WHERE "entityType" IN (
      'financial_installment', 'financial_commitment', 'expense', 'debt', 'installment'
    )
       OR "routeTarget" LIKE '%/financial-commitments/%'
       OR "routeTarget" LIKE '%/financial-installments/%'
       OR "routeTarget" LIKE '%/finance/%'
       OR "routeTarget" LIKE '%/debts/%'
       OR "routeTarget" LIKE '%/expenses/%'
  ) THEN
    RAISE EXCEPTION 'old finance notifications remain after reset';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "OutboxEvent"
    WHERE "aggregateType" = 'notification'
      AND "aggregateId" IN (
        SELECT "id" FROM "aarast_removed_finance_notification"
      )
  ) THEN
    RAISE EXCEPTION 'old finance notification outbox events remain after reset';
  END IF;

  IF to_regclass('"Expense"') IS NOT NULL
     OR to_regclass('"FinancialCommitment"') IS NOT NULL
     OR to_regclass('"FinancialPaymentRecord"') IS NOT NULL
     OR to_regclass('"FinancialInstallment"') IS NOT NULL
     OR EXISTS (
       SELECT 1 FROM pg_type
       WHERE typname IN (
         'ExpenseStatus', 'InstallmentStatus', 'FinancialCommitmentStatus',
         'FinancialCommitmentSourceType', 'FinancialPaymentRecordType'
       )
     ) THEN
    RAISE EXCEPTION 'old finance tables or enum types remain after reset';
  END IF;
END $$;

COMMIT;
