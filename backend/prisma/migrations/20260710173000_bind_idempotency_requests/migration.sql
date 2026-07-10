ALTER TABLE "IdempotencyKey"
  ADD COLUMN "requestHash" TEXT NOT NULL DEFAULT 'legacy',
  ADD COLUMN "expiresAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Historical rows predate request fingerprints, so replaying them could return
-- a response for a different body. Expire them immediately; the interceptor
-- safely reacquires the same client key on its next real request.
UPDATE "IdempotencyKey"
SET "expiresAt" = CURRENT_TIMESTAMP,
    "requestHash" = 'legacy';

ALTER TABLE "IdempotencyKey"
  ALTER COLUMN "requestHash" DROP DEFAULT,
  ALTER COLUMN "expiresAt" DROP DEFAULT;

CREATE INDEX "IdempotencyKey_expiresAt_idx" ON "IdempotencyKey"("expiresAt");
