-- RA-BE-152 (Q-39 (أ), D124): an approved provider's new name, logo,
-- cover, city or category went live with no review. Each now waits here as
-- one request per provider; the listing keeps its live values and images
-- until the team approves, and a refused request's images are deleted by
-- the media cleanup. The provider is told either way.

-- CreateEnum
CREATE TYPE "ProviderProfileChangeStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN');

-- RA-BE-152: the provider is told his change was approved or refused.
-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_PROFILE_CHANGE_REVIEWED';

-- CreateTable
CREATE TABLE "ProviderProfileChange" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "status" "ProviderProfileChangeStatus" NOT NULL DEFAULT 'PENDING',
    "businessName" TEXT,
    "cityId" TEXT,
    "primaryCategoryId" TEXT,
    "logoUrl" TEXT,
    "coverUrl" TEXT,
    "rejectionReason" TEXT,
    "decidedAt" TIMESTAMP(3),
    "decidedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderProfileChange_pkey" PRIMARY KEY ("id"),
    -- A waiting request asks for something and has no decision; only a
    -- refusal has a reason, and every other state has its time.
    CONSTRAINT "ProviderProfileChange_decision_check" CHECK (
        ("status" = 'PENDING' AND "decidedAt" IS NULL AND "rejectionReason" IS NULL
            AND num_nonnulls("businessName", "cityId", "primaryCategoryId", "logoUrl", "coverUrl") > 0)
        OR ("status" IN ('APPROVED', 'WITHDRAWN') AND "decidedAt" IS NOT NULL AND "rejectionReason" IS NULL)
        OR ("status" = 'REJECTED' AND "decidedAt" IS NOT NULL AND "rejectionReason" IS NOT NULL)
    )
);

-- CreateIndex
CREATE INDEX "ProviderProfileChange_providerId_status_idx" ON "ProviderProfileChange"("providerId", "status");

-- CreateIndex
CREATE INDEX "ProviderProfileChange_status_createdAt_idx" ON "ProviderProfileChange"("status", "createdAt");

-- One waiting request per provider; a later edit updates it.
CREATE UNIQUE INDEX "ProviderProfileChange_one_pending" ON "ProviderProfileChange"("providerId") WHERE "status" = 'PENDING';

-- AddForeignKey
ALTER TABLE "ProviderProfileChange" ADD CONSTRAINT "ProviderProfileChange_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;
