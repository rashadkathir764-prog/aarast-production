-- R4: a task can be about one money item or one payment, and closes with it.
-- Plain ids: the money is another context, so no foreign key crosses into it.
ALTER TABLE "WeddingTask"
  ADD COLUMN "linkedBudgetCategoryId" TEXT,
  ADD COLUMN "linkedCostId" TEXT,
  ADD COLUMN "linkedScheduleId" TEXT,
  ADD COLUMN "autoClosedAt" TIMESTAMP(3);

CREATE INDEX "WeddingTask_weddingPlanId_linkedBudgetCategoryId_idx"
  ON "WeddingTask"("weddingPlanId", "linkedBudgetCategoryId");

CREATE INDEX "WeddingTask_weddingPlanId_linkedScheduleId_idx"
  ON "WeddingTask"("weddingPlanId", "linkedScheduleId");
