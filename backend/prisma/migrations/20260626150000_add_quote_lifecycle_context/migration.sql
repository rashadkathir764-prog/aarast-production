ALTER TABLE "QuoteRequest"
ADD COLUMN "location" JSONB,
ADD COLUMN "contactName" TEXT,
ADD COLUMN "contactPhone" TEXT,
ADD COLUMN "contactNormalizedPhone" TEXT,
ADD COLUMN "acceptedAt" TIMESTAMP(3),
ADD COLUMN "rejectedAt" TIMESTAMP(3),
ADD COLUMN "cancelledAt" TIMESTAMP(3);

CREATE INDEX "QuoteRequest_contactNormalizedPhone_idx"
ON "QuoteRequest"("contactNormalizedPhone");
