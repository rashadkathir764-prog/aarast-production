-- D63: account deletion waits 30 days (w05, w06, n06), reviews may show the
-- first name only (w40), and the account's own data downloads once (w40).

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "deletionPurgeFailedAt" TIMESTAMP(3),
ADD COLUMN     "deletionPurgeFailure" TEXT,
ADD COLUMN     "deletionRequestedAt" TIMESTAMP(3),
ADD COLUMN     "deletionScheduledFor" TIMESTAMP(3),
ADD COLUMN     "reviewFirstNameOnly" BOOLEAN NOT NULL DEFAULT true;

-- A deletion request is whole: requested and scheduled together, the
-- schedule after the request; a purge failure only on a pending request.
ALTER TABLE "User" ADD CONSTRAINT "User_deletion_request_whole_check" CHECK (
  ("deletionRequestedAt" IS NULL AND "deletionScheduledFor" IS NULL)
  OR ("deletionRequestedAt" IS NOT NULL AND "deletionScheduledFor" IS NOT NULL
      AND "deletionScheduledFor" > "deletionRequestedAt")
);
ALTER TABLE "User" ADD CONSTRAINT "User_deletion_failure_pending_check" CHECK (
  ("deletionPurgeFailedAt" IS NULL AND "deletionPurgeFailure" IS NULL)
  OR ("deletionScheduledFor" IS NOT NULL AND "deletionPurgeFailedAt" IS NOT NULL
      AND "deletionPurgeFailure" IS NOT NULL)
);

-- CreateTable
CREATE TABLE "DataExport" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" CHAR(64) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "downloadedAt" TIMESTAMP(3),

    CONSTRAINT "DataExport_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "DataExport_expiry_check" CHECK ("expiresAt" > "createdAt")
);

-- CreateIndex
CREATE UNIQUE INDEX "DataExport_tokenHash_key" ON "DataExport"("tokenHash");

-- CreateIndex
CREATE INDEX "DataExport_userId_createdAt_idx" ON "DataExport"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "DataExport_createdAt_idx" ON "DataExport"("createdAt");

-- CreateIndex
CREATE INDEX "User_deletionScheduledFor_idx" ON "User"("deletionScheduledFor");

-- AddForeignKey
ALTER TABLE "DataExport" ADD CONSTRAINT "DataExport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
