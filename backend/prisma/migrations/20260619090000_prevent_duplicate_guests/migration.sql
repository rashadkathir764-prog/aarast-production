-- Add canonical guest fields for duplicate protection inside one wedding plan.
ALTER TABLE "Guest" ADD COLUMN "normalizedName" TEXT;
ALTER TABLE "Guest" ADD COLUMN "normalizedPhone" TEXT;

UPDATE "Guest"
SET
  "normalizedName" = regexp_replace(btrim("name"), '\s+', ' ', 'g'),
  "normalizedPhone" = CASE
    WHEN "phone" IS NULL OR btrim("phone") = '' THEN NULL
    WHEN length(regexp_replace("phone", '[^0-9]', '', 'g')) = 14
      AND regexp_replace("phone", '[^0-9]', '', 'g') LIKE '00967%'
      THEN '+967' || substring(regexp_replace("phone", '[^0-9]', '', 'g') from 6)
    WHEN length(regexp_replace("phone", '[^0-9]', '', 'g')) = 12
      AND regexp_replace("phone", '[^0-9]', '', 'g') LIKE '967%'
      THEN '+967' || substring(regexp_replace("phone", '[^0-9]', '', 'g') from 4)
    WHEN length(regexp_replace("phone", '[^0-9]', '', 'g')) = 10
      AND regexp_replace("phone", '[^0-9]', '', 'g') LIKE '0%'
      THEN '+967' || substring(regexp_replace("phone", '[^0-9]', '', 'g') from 2)
    WHEN length(regexp_replace("phone", '[^0-9]', '', 'g')) = 9
      THEN '+967' || regexp_replace("phone", '[^0-9]', '', 'g')
    ELSE NULL
  END;

UPDATE "Guest"
SET "normalizedName" = "id"
WHERE "normalizedName" IS NULL OR "normalizedName" = '';

ALTER TABLE "Guest" ALTER COLUMN "normalizedName" SET NOT NULL;

CREATE INDEX "Guest_weddingPlanId_normalizedName_idx" ON "Guest"("weddingPlanId", "normalizedName");
CREATE UNIQUE INDEX "Guest_weddingPlanId_normalizedName_normalizedPhone_key"
  ON "Guest"("weddingPlanId", "normalizedName", "normalizedPhone");
