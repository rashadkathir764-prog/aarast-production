-- Preserve quota accounting after object cleanup and bind consumption to one
-- durable domain target. Account deletion keeps ticket rows as deletion jobs
-- instead of cascading away the only ownership ledger before S3 cleanup.
ALTER TYPE "MediaUploadStatus" ADD VALUE 'DELETED';

ALTER TABLE "MediaUploadTicket"
  ADD COLUMN "consumedByType" TEXT,
  ADD COLUMN "consumedById" TEXT,
  ADD COLUMN "deletedAt" TIMESTAMP(3),
  ALTER COLUMN "userId" DROP NOT NULL;

ALTER TABLE "MediaUploadTicket"
  DROP CONSTRAINT "MediaUploadTicket_userId_fkey";

ALTER TABLE "MediaUploadTicket"
  ADD CONSTRAINT "MediaUploadTicket_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "MediaUploadTicket_consumedByType_consumedById_idx"
ON "MediaUploadTicket"("consumedByType", "consumedById");

CREATE INDEX "MediaUploadTicket_status_createdAt_idx"
ON "MediaUploadTicket"("status", "createdAt");
