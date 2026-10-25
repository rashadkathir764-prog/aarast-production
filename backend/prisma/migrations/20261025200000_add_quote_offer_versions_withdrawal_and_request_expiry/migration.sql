-- B-03 withdraw an offer, B-04 a request ends after seven days without an
-- answer, B-06 every edit before acceptance is a new version, B-08 the
-- customer chooses to share the budget and the phone.

ALTER TYPE "QuoteRequestStatus" ADD VALUE 'EXPIRED';
ALTER TYPE "ConversationEventType" ADD VALUE 'QUOTE_OFFER_WITHDRAWN';
ALTER TYPE "ConversationEventType" ADD VALUE 'QUOTE_OFFER_REVISED';
ALTER TYPE "ConversationEventType" ADD VALUE 'QUOTE_REQUEST_EXPIRED';
ALTER TYPE "NotificationType" ADD VALUE 'QUOTE_REQUEST_EXPIRING';

-- Existing requests share nothing (B-08) and answer by seven days after
-- their creation (B-04). The hourly job ends the overdue ones itself, so its
-- events and notices are written once, by one path.
ALTER TABLE "QuoteRequest"
ADD COLUMN "shareBudget" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "shareContact" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "expiresAt" TIMESTAMP(3),
ADD COLUMN "expiryWarnedAt" TIMESTAMP(3),
ADD COLUMN "expiredAt" TIMESTAMP(3);

UPDATE "QuoteRequest" SET "expiresAt" = "createdAt" + INTERVAL '7 days';

ALTER TABLE "QuoteRequest"
ALTER COLUMN "expiresAt" SET DEFAULT (CURRENT_TIMESTAMP + '7 days'::interval),
ALTER COLUMN "expiresAt" SET NOT NULL;

CREATE INDEX "QuoteRequest_status_expiresAt_idx" ON "QuoteRequest"("status", "expiresAt");

ALTER TABLE "QuoteOffer"
ADD COLUMN "currentVersionNo" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "versionChanges" JSONB,
ADD COLUMN "revisedAt" TIMESTAMP(3),
ADD COLUMN "withdrawnAt" TIMESTAMP(3),
ADD COLUMN "withdrawnReason" TEXT;

CREATE TABLE "QuoteOfferVersion" (
    "id" TEXT NOT NULL,
    "quoteOfferId" TEXT NOT NULL,
    "versionNo" INTEGER NOT NULL,
    "title" TEXT,
    "message" TEXT,
    "amount" DECIMAL(14,2),
    "currency" TEXT NOT NULL,
    "validUntil" TIMESTAMP(3),
    "changes" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QuoteOfferVersion_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "QuoteOfferVersion_quoteOfferId_versionNo_key" ON "QuoteOfferVersion"("quoteOfferId", "versionNo");

ALTER TABLE "QuoteOfferVersion" ADD CONSTRAINT "QuoteOfferVersion_quoteOfferId_fkey" FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Every existing offer is its own version 1, as the customer read it.
INSERT INTO "QuoteOfferVersion" (
    "id", "quoteOfferId", "versionNo", "title", "message", "amount",
    "currency", "validUntil", "changes", "createdAt"
)
SELECT
    gen_random_uuid()::text, "id", 1, "title", "message", "amount",
    "currency", "validUntil", NULL, "createdAt"
FROM "QuoteOffer";
