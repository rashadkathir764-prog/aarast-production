-- RA-OP-32, run by restore.sh on the restored database once it is at the
-- live release: the re-deletion lists of the database it replaced (loaded
-- into "ErasedAccountIncoming" and "ErasedPlanIncoming") join its own, and
-- every account and plan on them that the backup brought back is due for
-- erasure now. The hourly purges erase them again through the one erasure
-- saga; the server refuses to take such an account or plan back. One
-- transaction: all of it, or nothing.
BEGIN;
INSERT INTO "ErasedAccount" ("userId", "erasedAt")
  SELECT "userId", "erasedAt" FROM "ErasedAccountIncoming"
  ON CONFLICT ("userId") DO NOTHING;
UPDATE "User"
SET "deletionRequestedAt" = (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '1 minute',
    "deletionScheduledFor" = CURRENT_TIMESTAMP AT TIME ZONE 'UTC',
    "deletionPurgeFailedAt" = NULL,
    "deletionPurgeFailure" = NULL,
    "deletionPurgeAttempts" = 0
WHERE "id" IN (SELECT "userId" FROM "ErasedAccount");
DROP TABLE "ErasedAccountIncoming";
INSERT INTO "ErasedPlan" ("weddingPlanId", "erasedAt")
  SELECT "weddingPlanId", "erasedAt" FROM "ErasedPlanIncoming"
  ON CONFLICT ("weddingPlanId") DO NOTHING;
-- Due now, as a plan whose 30 days ended: closed to its members and erased by
-- the next hourly purge, never told as a deletion the owner asked for.
UPDATE "WeddingPlan"
SET "deletionRequestedAt" = (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '1 minute',
    "deletionScheduledFor" = CURRENT_TIMESTAMP AT TIME ZONE 'UTC'
WHERE "id" IN (SELECT "weddingPlanId" FROM "ErasedPlan");
DROP TABLE "ErasedPlanIncoming";
COMMIT;
