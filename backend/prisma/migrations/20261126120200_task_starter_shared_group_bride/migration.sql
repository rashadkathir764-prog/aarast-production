-- The default task list changed on 2026-11-25 (reference-catalog.defaults):
-- a bride's plan is not offered the shared «حجز المصور» beside her own
-- «حجز المصورة النسائية» (the same task twice), and the shared group's
-- subtitle is in the app's dialect, «الأساسيات اللي يتفقون عليها.». The
-- seed creates a catalog item once and never updates it, so a live
-- database kept the old rows. This publishes the change there as an admin
-- publishes one: a new revision (2) of every shared task still on the
-- system's first revision and never edited (currentRevision and
-- publishedRevision both 1, the old subtitle), made current and published,
-- and the catalog's version raised once so phones read the catalog again.
-- An item an admin edited, or holds a draft of, is left as it is. A fresh
-- database has no catalog rows yet (the API seeds the new defaults), so
-- nothing happens there.
WITH "untouched" AS (
  SELECT
    "revision"."itemId", "revision"."groupKey", "revision"."groupNameAr",
    "revision"."nameAr", "revision"."nameEn", "revision"."icon",
    "revision"."sortOrder", "revision"."showForGroom",
    CASE WHEN "item"."key" = 'task-shared-photo' THEN false ELSE "revision"."showForBride" END AS "showForBride",
    "revision"."showForCustomer", "revision"."showForProvider",
    "revision"."isRecommended", "revision"."isActive", "revision"."metadata"
  FROM "ReferenceCatalogItem" AS "item"
  JOIN "ReferenceCatalog" AS "catalog" ON "catalog"."id" = "item"."catalogId"
  JOIN "ReferenceCatalogItemRevision" AS "revision"
    ON "revision"."itemId" = "item"."id" AND "revision"."revision" = 1
  WHERE "catalog"."key" = 'tasks.starter'
    AND "item"."key" IN (
      'task-shared-date', 'task-shared-budget', 'task-shared-photo',
      'task-shared-home', 'task-shared-guests', 'task-shared-contract',
      'task-shared-honeymoon', 'task-shared-invites'
    )
    AND "item"."currentRevision" = 1
    AND "item"."publishedRevision" = 1
    AND "revision"."groupSubtitleAr" = 'الأساسيات التي يتفق عليها الطرفان.'
),
"published" AS (
  INSERT INTO "ReferenceCatalogItemRevision" (
    "id", "itemId", "revision", "groupKey", "groupNameAr", "groupSubtitleAr",
    "nameAr", "nameEn", "icon", "sortOrder", "showForGroom", "showForBride",
    "showForCustomer", "showForProvider", "isRecommended", "isActive", "metadata"
  )
  SELECT
    gen_random_uuid()::text, "itemId", 2, "groupKey", "groupNameAr", 'الأساسيات اللي يتفقون عليها.',
    "nameAr", "nameEn", "icon", "sortOrder", "showForGroom", "showForBride",
    "showForCustomer", "showForProvider", "isRecommended", "isActive", "metadata"
  FROM "untouched"
  RETURNING "itemId"
),
"items" AS (
  UPDATE "ReferenceCatalogItem"
  SET "currentRevision" = 2, "publishedRevision" = 2, "updatedAt" = CURRENT_TIMESTAMP
  WHERE "id" IN (SELECT "itemId" FROM "published")
  RETURNING "id"
)
UPDATE "ReferenceCatalog"
SET "version" = "version" + 1, "updatedAt" = CURRENT_TIMESTAMP
WHERE "key" = 'tasks.starter'
  AND EXISTS (SELECT 1 FROM "published");
