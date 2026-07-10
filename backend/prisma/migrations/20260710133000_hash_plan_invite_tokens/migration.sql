CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE "PlanInvite" RENAME COLUMN "token" TO "tokenHash";

UPDATE "PlanInvite"
SET "tokenHash" = encode(digest("tokenHash", 'sha256'), 'hex');

DROP INDEX "PlanInvite_token_key";

CREATE UNIQUE INDEX "PlanInvite_tokenHash_key"
ON "PlanInvite" ("tokenHash");

-- Historical invite notifications embedded the bearer token in JSON and in
-- routeTarget. Replace it with the authenticated invite id handle.
UPDATE "Notification"
SET
  "routeTarget" = '/invites/' || "entityId",
  "data" = CASE
    WHEN "data" IS NULL THEN NULL
    ELSE "data" - 'inviteToken'
  END,
  "updatedAt" = NOW()
WHERE "entityType" = 'plan_invite'
  AND "entityId" IS NOT NULL;
