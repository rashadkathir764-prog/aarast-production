-- Reserve-before-execute idempotency: the (userId,key) row is now inserted
-- BEFORE the mutation runs, so a NULL completedAt means "in flight" and a set
-- completedAt means "response is final and safe to replay". This closes the
-- check-then-act race where concurrent requests with the same key each
-- executed the mutation and duplicated financial records.

ALTER TABLE "IdempotencyKey" ADD COLUMN "completedAt" TIMESTAMP(3);

-- Every row written by the previous code path was inserted only AFTER the
-- work had already committed, so all existing rows are complete. Backfill
-- their completedAt from createdAt; otherwise they would look "in flight"
-- forever and stall replays of already-finished requests.
UPDATE "IdempotencyKey" SET "completedAt" = "createdAt" WHERE "completedAt" IS NULL;
