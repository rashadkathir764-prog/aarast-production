BEGIN;

-- Fail safely instead of waiting forever behind a long-lived production query.
-- No data or index changes occur unless this lock is acquired.
SET LOCAL lock_timeout = '15s';
LOCK TABLE "Guest" IN ACCESS EXCLUSIVE MODE;

-- Build the same canonical representation used by PhoneNormalizer:
--   * Arabic/Persian digits become ASCII.
--   * spaces, hyphens and parentheses are removed.
--   * accepted Yemeni variants become +967 plus 8 or 9 local digits.
--   * other accepted international forms keep a leading +.
--   * accepted bare 7-15 digit forms remain bare.
CREATE TEMPORARY TABLE "_GuestPhoneCanonicalization" ON COMMIT DROP AS
WITH compacted AS (
  SELECT
    "id",
    regexp_replace(
      translate(
        "phone",
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
      ),
      '[[:space:]()-]',
      '',
      'g'
    ) AS "compactPhone"
  FROM "Guest"
),
digits AS (
  SELECT
    "id",
    "compactPhone",
    CASE
      WHEN "compactPhone" LIKE '+%' THEN substring("compactPhone" FROM 2)
      WHEN "compactPhone" LIKE '00%' THEN substring("compactPhone" FROM 3)
      ELSE "compactPhone"
    END AS "digits"
  FROM compacted
),
parsed AS (
  SELECT
    "id",
    "compactPhone",
    "digits",
    CASE
      WHEN "compactPhone" LIKE '+967%'
        OR "compactPhone" LIKE '00967%'
        OR "digits" LIKE '967%'
        THEN substring("digits" FROM 4)
      WHEN length("digits") = 10 AND "digits" LIKE '0%'
        THEN substring("digits" FROM 2)
      WHEN length("digits") = 9
        THEN "digits"
      ELSE NULL
    END AS "yemeniLocal"
  FROM digits
)
SELECT
  "id",
  "compactPhone",
  CASE
    WHEN "compactPhone" IS NULL OR "compactPhone" = '' THEN NULL
    WHEN "compactPhone" !~ '^([+]|00)?[0-9]+$' THEN NULL
    WHEN "yemeniLocal" IS NOT NULL
      AND length("yemeniLocal") IN (8, 9)
      THEN '+967' || "yemeniLocal"
    WHEN "compactPhone" LIKE '+967%'
      OR "compactPhone" LIKE '00967%'
      OR "digits" LIKE '967%'
      THEN NULL
    WHEN length("digits") < 7 OR length("digits") > 15 THEN NULL
    WHEN "compactPhone" LIKE '+%' OR "compactPhone" LIKE '00%'
      THEN '+' || "digits"
    ELSE "digits"
  END AS "canonicalPhone"
FROM parsed;

-- Do not discard an orphaned normalized phone, accept an unparseable phone, or
-- merge duplicate people automatically. All failures are deliberately generic
-- so deployment logs never contain the phone value.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "Guest" AS guest
    JOIN "_GuestPhoneCanonicalization" AS canonical
      ON canonical."id" = guest."id"
    WHERE
      (
        guest."phone" IS NULL
        AND guest."normalizedPhone" IS NOT NULL
      )
      OR (
        guest."phone" IS NOT NULL
        AND canonical."canonicalPhone" IS NULL
      )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cannot canonicalize guest phones: manual reconciliation required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "Guest" AS guest
    JOIN "_GuestPhoneCanonicalization" AS canonical
      ON canonical."id" = guest."id"
    WHERE canonical."canonicalPhone" IS NOT NULL
    GROUP BY guest."weddingPlanId", canonical."canonicalPhone"
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Cannot enforce unique guest phone: manual reconciliation required';
  END IF;
END $$;

UPDATE "Guest" AS guest
SET
  "phone" = canonical."canonicalPhone",
  "normalizedPhone" = canonical."canonicalPhone"
FROM "_GuestPhoneCanonicalization" AS canonical
WHERE canonical."id" = guest."id"
  AND (
    guest."phone" IS DISTINCT FROM canonical."canonicalPhone"
    OR guest."normalizedPhone" IS DISTINCT FROM canonical."canonicalPhone"
  );

-- Rebuild both known index topologies while Guest is locked. Dropping the new
-- name too makes a retry safe after a manually repaired/partially applied run.
ALTER TABLE "Guest"
  DROP CONSTRAINT IF EXISTS "Guest_phone_normalizedPhone_match_check";
DROP INDEX IF EXISTS "Guest_weddingPlanId_normalizedName_normalizedPhone_key";
DROP INDEX IF EXISTS "Guest_weddingPlanId_normalizedPhone_key";
CREATE UNIQUE INDEX "Guest_weddingPlanId_normalizedPhone_key"
  ON "Guest"("weddingPlanId", "normalizedPhone");

-- Only rows with no phone may retain NULL. Live writes already store both
-- fields from PhoneNormalizer; the database now rejects a partial pair too.
ALTER TABLE "Guest"
  ADD CONSTRAINT "Guest_phone_normalizedPhone_match_check"
  CHECK ("phone" IS NOT DISTINCT FROM "normalizedPhone");

COMMIT;
