-- B-01, B-02, B-12 (provider lifecycle): the review history with one note
-- per field replaces the single Provider."reviewNote", the provider can send
-- a profile back (resubmit) or reopen a refused one, and claiming a listing
-- the back office made waits for an administrator.

-- CreateEnum
CREATE TYPE "ProviderReviewEventKind" AS ENUM ('CHANGES_REQUESTED', 'REJECTED', 'APPROVED', 'SUSPENDED', 'ACTIVATED', 'RESUBMITTED', 'REOPENED');

-- CreateEnum
CREATE TYPE "ProviderReviewField" AS ENUM ('GENERAL', 'BUSINESS_NAME', 'CATEGORY', 'CITY', 'DESCRIPTION', 'SERVICE');

-- CreateEnum
CREATE TYPE "ProviderClaimStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterTable
ALTER TABLE "Provider"
ADD COLUMN     "reopenedAt" TIMESTAMP(3),
ADD COLUMN     "resubmitCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "resubmittedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "ProviderReviewEvent" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "kind" "ProviderReviewEventKind" NOT NULL,
    "actorId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderReviewEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderReviewNote" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "field" "ProviderReviewField" NOT NULL,
    "note" TEXT NOT NULL,

    CONSTRAINT "ProviderReviewNote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderClaimRequest" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" "ProviderClaimStatus" NOT NULL DEFAULT 'PENDING',
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decidedAt" TIMESTAMP(3),
    "decidedById" TEXT,

    CONSTRAINT "ProviderClaimRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ProviderReviewEvent_providerId_createdAt_idx" ON "ProviderReviewEvent"("providerId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderReviewNote_eventId_field_key" ON "ProviderReviewNote"("eventId", "field");

-- CreateIndex
CREATE INDEX "ProviderClaimRequest_status_createdAt_idx" ON "ProviderClaimRequest"("status", "createdAt");

-- CreateIndex
CREATE INDEX "ProviderClaimRequest_userId_createdAt_idx" ON "ProviderClaimRequest"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "ProviderClaimRequest_providerId_status_idx" ON "ProviderClaimRequest"("providerId", "status");

-- One open claim per listing and one per account.
CREATE UNIQUE INDEX "ProviderClaimRequest_pending_provider_key"
ON "ProviderClaimRequest"("providerId")
WHERE "status" = 'PENDING';

CREATE UNIQUE INDEX "ProviderClaimRequest_pending_user_key"
ON "ProviderClaimRequest"("userId")
WHERE "status" = 'PENDING';

-- AddForeignKey
ALTER TABLE "ProviderReviewEvent" ADD CONSTRAINT "ProviderReviewEvent_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderReviewNote" ADD CONSTRAINT "ProviderReviewNote_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "ProviderReviewEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderClaimRequest" ADD CONSTRAINT "ProviderClaimRequest_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Every stored note moves into the history as the decision that wrote it.
-- Only these three decisions ever wrote a note (approve and activate wrote
-- null, and nothing else writes the column); any other note is a state the
-- code cannot produce, so the migration stops instead of dropping it.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "Provider"
    WHERE "reviewNote" IS NOT NULL
      AND btrim("reviewNote") <> ''
      AND "status" NOT IN ('NEEDS_CHANGES', 'REJECTED', 'SUSPENDED')
  ) THEN
    RAISE EXCEPTION 'Provider review notes exist outside NEEDS_CHANGES, REJECTED and SUSPENDED';
  END IF;
END $$;

WITH noted AS (
  SELECT
    gen_random_uuid()::text AS "eventId",
    "id" AS "providerId",
    CASE "status"
      WHEN 'NEEDS_CHANGES' THEN 'CHANGES_REQUESTED'::"ProviderReviewEventKind"
      WHEN 'REJECTED' THEN 'REJECTED'::"ProviderReviewEventKind"
      ELSE 'SUSPENDED'::"ProviderReviewEventKind"
    END AS "kind",
    "reviewedById" AS "actorId",
    COALESCE("reviewedAt", "updatedAt") AS "createdAt",
    btrim("reviewNote") AS "note"
  FROM "Provider"
  WHERE "reviewNote" IS NOT NULL
    AND btrim("reviewNote") <> ''
    AND "status" IN ('NEEDS_CHANGES', 'REJECTED', 'SUSPENDED')
),
events AS (
  INSERT INTO "ProviderReviewEvent" ("id", "providerId", "kind", "actorId", "createdAt")
  SELECT "eventId", "providerId", "kind", "actorId", "createdAt" FROM noted
  RETURNING "id"
)
INSERT INTO "ProviderReviewNote" ("id", "eventId", "field", "note")
SELECT gen_random_uuid()::text, noted."eventId", 'GENERAL'::"ProviderReviewField", noted."note"
FROM noted
JOIN events ON events."id" = noted."eventId";

-- AlterTable
ALTER TABLE "Provider" DROP COLUMN "reviewNote";
