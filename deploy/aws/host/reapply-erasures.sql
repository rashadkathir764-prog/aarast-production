-- RA-OP-32, run by restore.sh on the restored database once it is at the
-- live release: the re-deletion list of the database it replaced (loaded
-- into "ErasedAccountIncoming") joins its own, and every account on the
-- list that the backup brought back is due for erasure now. The hourly purge
-- erases it again through the one erasure saga; the server refuses to take
-- such an account back. One transaction: all of it, or nothing.
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
COMMIT;
