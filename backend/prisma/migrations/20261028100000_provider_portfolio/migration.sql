-- B-16 (D62): «معرض الشغل». Every new photo waits for the moderation team;
-- customers see only APPROVED photos, the women's album «حفلات النساء» only
-- brides, and only photos the provider confirmed show no faces. A refused
-- photo keeps its reason for the provider; its stored image is deleted by
-- the media cleanup. The provider's TikTok, Instagram and Facebook links.

-- B-16: the provider is told a photo was approved or refused (opens p37).
ALTER TYPE "NotificationType" ADD VALUE 'PORTFOLIO_REVIEWED';

-- CreateEnum
CREATE TYPE "PortfolioItemStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterTable
ALTER TABLE "Provider" ADD COLUMN "socialLinks" JSONB;

-- CreateTable
CREATE TABLE "PortfolioItem" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "mediaKey" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "album" TEXT,
    "forWomen" BOOLEAN NOT NULL DEFAULT false,
    "noFaces" BOOLEAN NOT NULL DEFAULT false,
    "status" "PortfolioItemStatus" NOT NULL DEFAULT 'PENDING',
    "rejectionReason" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "reviewedById" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PortfolioItem_pkey" PRIMARY KEY ("id"),
    -- The album is a short label; the women's album is the one named «حفلات النساء».
    CONSTRAINT "PortfolioItem_album_check" CHECK (
        "album" IS NULL OR char_length("album") BETWEEN 1 AND 30
    ),
    CONSTRAINT "PortfolioItem_for_women_check" CHECK (
        "forWomen" = ("album" IS NOT DISTINCT FROM 'حفلات النساء')
    ),
    -- A women's photo is published only with the provider's «بدون وجوه».
    CONSTRAINT "PortfolioItem_women_no_faces_check" CHECK (
        NOT "forWomen" OR "noFaces"
    ),
    -- PENDING has no decision; a decision has its time; only a refusal has a reason.
    CONSTRAINT "PortfolioItem_decision_check" CHECK (
        ("status" = 'PENDING' AND "reviewedAt" IS NULL AND "rejectionReason" IS NULL)
        OR ("status" = 'APPROVED' AND "reviewedAt" IS NOT NULL AND "rejectionReason" IS NULL)
        OR ("status" = 'REJECTED' AND "reviewedAt" IS NOT NULL AND "rejectionReason" IS NOT NULL)
    )
);

-- CreateIndex
CREATE UNIQUE INDEX "PortfolioItem_mediaKey_key" ON "PortfolioItem"("mediaKey");

-- CreateIndex
CREATE INDEX "PortfolioItem_providerId_sortOrder_idx" ON "PortfolioItem"("providerId", "sortOrder");

-- CreateIndex
CREATE INDEX "PortfolioItem_status_createdAt_idx" ON "PortfolioItem"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "PortfolioItem" ADD CONSTRAINT "PortfolioItem_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;
