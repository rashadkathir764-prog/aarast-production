-- B-05, B-07, B-11 (owner-vision audit 2026-10-27, G24): why a provider
-- declined a request, what an offer covers and its delivery days, and why
-- the customer turned an offer down. All optional; old rows read as before.
ALTER TABLE "QuoteRequest"
    ADD COLUMN "declineReason" TEXT,
    ADD COLUMN "declineMessage" TEXT;

ALTER TABLE "QuoteOffer"
    ADD COLUMN "lines" JSONB,
    ADD COLUMN "deliveryDays" INTEGER,
    ADD COLUMN "rejectReason" TEXT,
    ADD COLUMN "rejectMessage" TEXT;

ALTER TABLE "QuoteOfferVersion"
    ADD COLUMN "lines" JSONB,
    ADD COLUMN "deliveryDays" INTEGER;

ALTER TABLE "QuoteRequest"
    ADD CONSTRAINT "QuoteRequest_declineReason_check"
    CHECK ("declineReason" IS NULL OR "declineReason" IN ('BUSY_THAT_DAY', 'OUT_OF_AREA', 'NOT_MY_SERVICE', 'OTHER'));

ALTER TABLE "QuoteOffer"
    ADD CONSTRAINT "QuoteOffer_rejectReason_check"
    CHECK ("rejectReason" IS NULL OR "rejectReason" IN ('PRICE', 'CHOSE_OTHER', 'DATE', 'NONE')),
    ADD CONSTRAINT "QuoteOffer_deliveryDays_check"
    CHECK ("deliveryDays" IS NULL OR ("deliveryDays" >= 0 AND "deliveryDays" <= 365));

ALTER TABLE "QuoteOfferVersion"
    ADD CONSTRAINT "QuoteOfferVersion_deliveryDays_check"
    CHECK ("deliveryDays" IS NULL OR ("deliveryDays" >= 0 AND "deliveryDays" <= 365));
