-- D114: the groom chooses, while writing his budget, whether the mahr counts
-- inside it. Every plan so far was budgeted under «بدون المهر», so it stays
-- false and nothing is taken out of an existing budget.
ALTER TABLE "WeddingPlan" ADD COLUMN "budgetIncludesMahr" BOOLEAN NOT NULL DEFAULT false;
