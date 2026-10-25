-- The provider's review steps are ordered by a sequence instead of their
-- time alone: two steps written in the same millisecond (or after the clock
-- stepped back) had no defined order, so "the latest decision" could name an
-- older one. Every step is written under the provider's row lock, so the
-- sequence grows in the order the steps happened. The steps already written
-- take their numbers from their time, then their id.

-- AlterTable
ALTER TABLE "ProviderReviewEvent" ADD COLUMN "sequence" SERIAL NOT NULL;

UPDATE "ProviderReviewEvent" AS event
SET "sequence" = ordered."position"
FROM (
  SELECT "id", row_number() OVER (ORDER BY "createdAt" ASC, "id" ASC) AS "position"
  FROM "ProviderReviewEvent"
) AS ordered
WHERE event."id" = ordered."id";

SELECT setval(
  pg_get_serial_sequence('"ProviderReviewEvent"', 'sequence'),
  COALESCE((SELECT MAX("sequence") FROM "ProviderReviewEvent"), 0) + 1,
  false
);

-- DropIndex
DROP INDEX "ProviderReviewEvent_providerId_createdAt_idx";

-- CreateIndex
CREATE UNIQUE INDEX "ProviderReviewEvent_sequence_key" ON "ProviderReviewEvent"("sequence");

-- CreateIndex
CREATE INDEX "ProviderReviewEvent_providerId_sequence_idx" ON "ProviderReviewEvent"("providerId", "sequence");
