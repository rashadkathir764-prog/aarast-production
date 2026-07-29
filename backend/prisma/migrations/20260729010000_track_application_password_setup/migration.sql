-- A bcrypt hash alone cannot prove that the account holder chose an
-- application password. Older invite login code generated an unreachable
-- random password for first-time contributors, so persist that distinction.
ALTER TABLE "User"
ADD COLUMN "appPasswordConfiguredAt" TIMESTAMP(3);

-- Existing administrator application credentials were explicitly enrolled.
UPDATE "User"
SET "appPasswordConfiguredAt" = COALESCE("phoneVerifiedAt", "createdAt")
WHERE "role" = 'ADMIN'
  AND "appPasswordHash" IS NOT NULL;

-- Existing ordinary credentials were user-selected except for the historical
-- invite placeholder flow. That flow used this exact generated display name
-- and created the account while a matching invitation was live.
UPDATE "User" AS "user"
SET "appPasswordConfiguredAt" = COALESCE("user"."phoneVerifiedAt", "user"."createdAt")
WHERE "user"."role" IN ('USER', 'PROVIDER')
  AND NOT (
    "user"."name" = 'مشارك أعرست'
    AND EXISTS (
      SELECT 1
      FROM "PlanInvite" AS "invite"
      WHERE "invite"."normalizedPhone" = "user"."phone"
        AND "invite"."createdAt" <= "user"."createdAt"
        AND "invite"."expiresAt" >= "user"."createdAt"
    )
  );

-- Sessions minted for an unreachable generated password must not remain a
-- permanent passwordless login path. The next verified invite recovery sets a
-- real password and issues a new rotating application session.
UPDATE "RefreshToken" AS "session"
SET "revokedAt" = COALESCE("session"."revokedAt", CURRENT_TIMESTAMP)
FROM "User" AS "user"
WHERE "session"."userId" = "user"."id"
  AND "session"."scope" = 'APPLICATION'
  AND "session"."revokedAt" IS NULL
  AND "user"."appPasswordConfiguredAt" IS NULL;
