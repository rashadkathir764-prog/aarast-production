-- CreateEnum
CREATE TYPE "QuoteOfferStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "PlanProviderLinkStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

-- CreateTable
CREATE TABLE "QuoteOffer" (
    "id" TEXT NOT NULL,
    "quoteRequestId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "title" TEXT,
    "message" TEXT,
    "amount" DECIMAL(14,2),
    "currency" TEXT NOT NULL DEFAULT 'YER',
    "validUntil" TIMESTAMP(3),
    "status" "QuoteOfferStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QuoteOffer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlanProviderLink" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "quoteRequestId" TEXT,
    "quoteOfferId" TEXT,
    "status" "PlanProviderLinkStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlanProviderLink_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "QuoteOffer_quoteRequestId_status_idx" ON "QuoteOffer"("quoteRequestId", "status");

-- CreateIndex
CREATE INDEX "QuoteOffer_providerId_status_idx" ON "QuoteOffer"("providerId", "status");

-- CreateIndex
CREATE INDEX "PlanProviderLink_providerId_status_idx" ON "PlanProviderLink"("providerId", "status");

-- CreateIndex
CREATE INDEX "PlanProviderLink_quoteRequestId_idx" ON "PlanProviderLink"("quoteRequestId");

-- CreateIndex
CREATE INDEX "PlanProviderLink_quoteOfferId_idx" ON "PlanProviderLink"("quoteOfferId");

-- CreateIndex
CREATE UNIQUE INDEX "PlanProviderLink_weddingPlanId_providerId_key" ON "PlanProviderLink"("weddingPlanId", "providerId");

-- AddForeignKey
ALTER TABLE "QuoteOffer" ADD CONSTRAINT "QuoteOffer_quoteRequestId_fkey" FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteOffer" ADD CONSTRAINT "QuoteOffer_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanProviderLink" ADD CONSTRAINT "PlanProviderLink_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanProviderLink" ADD CONSTRAINT "PlanProviderLink_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanProviderLink" ADD CONSTRAINT "PlanProviderLink_quoteRequestId_fkey" FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanProviderLink" ADD CONSTRAINT "PlanProviderLink_quoteOfferId_fkey" FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id") ON DELETE SET NULL ON UPDATE CASCADE;
