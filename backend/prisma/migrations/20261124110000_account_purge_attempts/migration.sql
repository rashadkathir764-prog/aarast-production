-- RA-BE-177: the hourly purge took its 25 accounts by due date alone, and a
-- failure changed nothing, so 25 accounts that always fail took every run.
-- The request now counts its failed purges; the purge takes the fewest
-- first, then the oldest due.
ALTER TABLE "User" ADD COLUMN "deletionPurgeAttempts" INTEGER NOT NULL DEFAULT 0;

-- A request that already carries a failure failed at least once; how many
-- times before is not known.
UPDATE "User" SET "deletionPurgeAttempts" = 1 WHERE "deletionPurgeFailedAt" IS NOT NULL;
