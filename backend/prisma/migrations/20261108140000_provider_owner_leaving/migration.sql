-- RA-BE-26 (D63): while a provider's owner waits out the account's deletion,
-- the listing leaves the directory and takes no new request. Marketplace
-- keeps its own mark (it does not read identity's rows); identity sets it at
-- the request and clears it at «تراجعت». Accounts already waiting are marked
-- once here.
ALTER TABLE "Provider" ADD COLUMN "ownerLeavingAt" TIMESTAMP(3);

UPDATE "Provider" AS p
SET "ownerLeavingAt" = u."deletionRequestedAt"
FROM "User" AS u
WHERE p."userId" = u."id"
  AND u."deletionScheduledFor" IS NOT NULL;
