-- Durable signed-upload lifecycle and quota accounting.
CREATE TYPE "MediaUploadStatus" AS ENUM (
  'PENDING',
  'VERIFYING',
  'VERIFIED',
  'DELETE_PENDING'
);

CREATE TABLE "MediaUploadTicket" (
  "key" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "contentType" TEXT NOT NULL,
  "declaredByteSize" INTEGER NOT NULL,
  "verifiedByteSize" INTEGER,
  "status" "MediaUploadStatus" NOT NULL DEFAULT 'PENDING',
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "verifiedAt" TIMESTAMP(3),
  "consumedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "MediaUploadTicket_pkey" PRIMARY KEY ("key")
);

ALTER TABLE "MediaUploadTicket"
ADD CONSTRAINT "MediaUploadTicket_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "MediaUploadTicket_userId_createdAt_idx"
ON "MediaUploadTicket"("userId", "createdAt");

CREATE INDEX "MediaUploadTicket_status_expiresAt_idx"
ON "MediaUploadTicket"("status", "expiresAt");

CREATE INDEX "MediaUploadTicket_status_updatedAt_idx"
ON "MediaUploadTicket"("status", "updatedAt");

CREATE INDEX "MediaUploadTicket_status_verifiedAt_idx"
ON "MediaUploadTicket"("status", "verifiedAt");
