-- Preserve only the latest unconsumed OTP for each phone/purpose pair before
-- enforcing the invariant. Older rows are invalidated, never deleted.
WITH "ranked_otps" AS (
  SELECT
    "id",
    ROW_NUMBER() OVER (
      PARTITION BY "phone", "purpose"
      ORDER BY "createdAt" DESC, "id" DESC
    ) AS "row_number"
  FROM "OtpCode"
  WHERE "consumedAt" IS NULL
)
UPDATE "OtpCode" AS "otp"
SET "consumedAt" = NOW(), "updatedAt" = NOW()
FROM "ranked_otps" AS "ranked"
WHERE "otp"."id" = "ranked"."id"
  AND "ranked"."row_number" > 1;

-- A partial unique index makes concurrent OTP requests converge on exactly
-- one active code. The request transaction invalidates the prior row first.
CREATE UNIQUE INDEX "OtpCode_one_active_per_phone_purpose"
ON "OtpCode" ("phone", "purpose")
WHERE "consumedAt" IS NULL;
