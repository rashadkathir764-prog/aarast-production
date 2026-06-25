-- Add a mobile journey role without changing the existing authorization role.
CREATE TYPE "AppRole" AS ENUM ('WEDDING_USER', 'PROVIDER');

ALTER TABLE "User"
ADD COLUMN "appRole" "AppRole" NOT NULL DEFAULT 'WEDDING_USER';

-- Keep the existing creditor phone for display/backward compatibility and add
-- a nullable canonical value for comparison and future contact integrations.
ALTER TABLE "Debt"
ADD COLUMN "creditorNormalizedPhone" TEXT;

WITH normalized_debt_phones AS (
  SELECT
    "id",
    regexp_replace(
      translate(
        btrim("creditorPhone"),
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
      ),
      '[\s\-\(\)]',
      '',
      'g'
    ) AS compact_phone
  FROM "Debt"
  WHERE "creditorPhone" IS NOT NULL
    AND btrim("creditorPhone") <> ''
)
UPDATE "Debt" AS debt
SET "creditorNormalizedPhone" = CASE
  WHEN source.compact_phone ~ '^\+9677[0-9]{8}$'
    THEN source.compact_phone
  WHEN source.compact_phone ~ '^009677[0-9]{8}$'
    THEN '+' || substring(source.compact_phone FROM 3)
  WHEN source.compact_phone ~ '^9677[0-9]{8}$'
    THEN '+' || source.compact_phone
  WHEN source.compact_phone ~ '^07[0-9]{8}$'
    THEN '+967' || substring(source.compact_phone FROM 2)
  WHEN source.compact_phone ~ '^7[0-9]{8}$'
    THEN '+967' || source.compact_phone
  WHEN source.compact_phone ~ '^\+[0-9]{7,15}$'
    THEN source.compact_phone
  WHEN source.compact_phone ~ '^00[0-9]{7,15}$'
    THEN '+' || substring(source.compact_phone FROM 3)
  WHEN source.compact_phone ~ '^[0-9]{7,15}$'
    THEN source.compact_phone
  ELSE NULL
END
FROM normalized_debt_phones AS source
WHERE debt."id" = source."id";
