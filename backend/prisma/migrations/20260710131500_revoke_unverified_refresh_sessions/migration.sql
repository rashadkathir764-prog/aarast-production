-- Legacy accounts created before verified registration may still have active
-- refresh rows. JWT validation already rejects them; revoking the persisted
-- sessions makes the policy explicit and prevents later code from reviving
-- an unverified session accidentally.
UPDATE "RefreshToken" AS "refresh"
SET "revokedAt" = NOW()
WHERE "refresh"."revokedAt" IS NULL
  AND EXISTS (
    SELECT 1
    FROM "User" AS "user"
    WHERE "user"."id" = "refresh"."userId"
      AND "user"."phoneVerifiedAt" IS NULL
  );
