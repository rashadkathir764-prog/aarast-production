-- B-43 (D41, G05): featured placement is a period the back office switches
-- on by hand after the provider paid outside the app. The period is the only
-- source of "featured": the groom's list ranks and badges a provider while
-- one of its periods covers now, read at request time.
--
-- Provider."isFeatured" goes. No back-office path ever wrote it (G05); its
-- true values came only from the demo seed and the production bootstrap's
-- test listing, so no placement anyone granted is lost, and a badge nobody
-- paid for stops showing.

-- CreateTable
CREATE TABLE "ProviderFeaturedPeriod" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "note" TEXT,
    "grantedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMP(3),
    "endedById" TEXT,
    "endNote" TEXT,
    "endingNoticeAt" TIMESTAMP(3),
    "endNoticeAt" TIMESTAMP(3),

    CONSTRAINT "ProviderFeaturedPeriod_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ProviderFeaturedPeriod_period_check" CHECK ("endsAt" > "startsAt")
);

-- CreateIndex
CREATE INDEX "ProviderFeaturedPeriod_providerId_startsAt_idx" ON "ProviderFeaturedPeriod"("providerId", "startsAt");

-- CreateIndex
CREATE INDEX "ProviderFeaturedPeriod_endsAt_idx" ON "ProviderFeaturedPeriod"("endsAt");

-- AddForeignKey
ALTER TABLE "ProviderFeaturedPeriod" ADD CONSTRAINT "ProviderFeaturedPeriod_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- DropIndex
DROP INDEX "Provider_status_isFeatured_idx";

-- AlterTable
ALTER TABLE "Provider" DROP COLUMN "isFeatured";
