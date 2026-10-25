-- B5: the mahr (C1). The groom's mahr is an agreement with the bride's
-- family: a MAHR budget item outside the wedding budget, with his payments
-- and the rest's due date. The bride's mahr is money coming in: MAHR funding
-- sources, the received part and the pledged rest with its expected day.

-- CreateEnum
CREATE TYPE "BudgetCategoryKind" AS ENUM ('WEDDING', 'MAHR');

-- AlterEnum
ALTER TYPE "FundingSourceKind" ADD VALUE 'MAHR';

-- AlterTable
ALTER TABLE "BudgetCategory" ADD COLUMN "kind" "BudgetCategoryKind" NOT NULL DEFAULT 'WEDDING';

-- AlterTable
ALTER TABLE "FundingSource" ADD COLUMN "expectedAt" TIMESTAMP(3);

-- One mahr item per plan.
CREATE UNIQUE INDEX "BudgetCategory_one_mahr_per_plan" ON "BudgetCategory"("weddingPlanId") WHERE "kind" = 'MAHR';

-- The mahr is outside the budget (C1), so it never holds an allocation; the
-- plan's allocation invariant keeps summing every item.
ALTER TABLE "BudgetCategory" ADD CONSTRAINT "BudgetCategory_mahr_has_no_allocation" CHECK ("kind" <> 'MAHR' OR "allocatedAmount" IS NULL);

-- G12: honeymoon (all three plans) and the bride's home are recommended
-- starter items (R2). New databases get them from the seeded defaults; here
-- an item still on the system's first revision (never edited by an admin) is
-- published again as recommended. Admin edits are left as they are.
WITH "untouched" AS (
  SELECT
    "revision"."itemId", "revision"."groupKey", "revision"."groupNameAr",
    "revision"."groupSubtitleAr", "revision"."nameAr", "revision"."nameEn",
    "revision"."icon", "revision"."sortOrder", "revision"."showForGroom",
    "revision"."showForBride", "revision"."showForCustomer",
    "revision"."showForProvider", "revision"."isActive", "revision"."metadata"
  FROM "ReferenceCatalogItem" AS "item"
  JOIN "ReferenceCatalog" AS "catalog" ON "catalog"."id" = "item"."catalogId"
  JOIN "ReferenceCatalogItemRevision" AS "revision"
    ON "revision"."itemId" = "item"."id" AND "revision"."revision" = 1
  WHERE "catalog"."key" = 'money.starter.categories'
    AND "item"."key" IN ('groom-honeymoon', 'bride-honeymoon', 'neutral-honeymoon', 'bride-home')
    AND "item"."currentRevision" = 1
    AND "item"."publishedRevision" = 1
    AND "revision"."isRecommended" = false
),
"published" AS (
  INSERT INTO "ReferenceCatalogItemRevision" (
    "id", "itemId", "revision", "groupKey", "groupNameAr", "groupSubtitleAr",
    "nameAr", "nameEn", "icon", "sortOrder", "showForGroom", "showForBride",
    "showForCustomer", "showForProvider", "isRecommended", "isActive", "metadata"
  )
  SELECT
    gen_random_uuid()::text, "itemId", 2, "groupKey", "groupNameAr", "groupSubtitleAr",
    "nameAr", "nameEn", "icon", "sortOrder", "showForGroom", "showForBride",
    "showForCustomer", "showForProvider", true, "isActive", "metadata"
  FROM "untouched"
  RETURNING "itemId"
)
UPDATE "ReferenceCatalogItem"
SET "currentRevision" = 2, "publishedRevision" = 2, "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" IN (SELECT "itemId" FROM "published");
