-- RA-BE-180: the plain ids that name an account become references, so none
-- can point at an account that is gone. Each is SET NULL: the row is the
-- other party's record (a booking's history, a receipt, a listing's review
-- trail) and stays when the account goes, with nobody named. A reference to
-- an account that is already gone is cleared first (it named nobody); no row
-- is deleted. BookingChange.requestedByUserId may now be empty for that
-- reason (as Booking.requestedByUserId, 20261125120000); the server only
-- writes it. Each key has its partial index, so erasing an account does not
-- read these tables row by row.

ALTER TABLE "BookingChange" ALTER COLUMN "requestedByUserId" DROP NOT NULL;

-- BookingChange.requestedByUserId: who asked for the change (a member may leave; the change, part of the booking's history, stays).
UPDATE "BookingChange"
SET "requestedByUserId" = NULL
WHERE "requestedByUserId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "BookingChange"."requestedByUserId");

ALTER TABLE "BookingChange"
  ADD CONSTRAINT "BookingChange_requestedByUserId_fkey"
  FOREIGN KEY ("requestedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "BookingChange_requestedByUserId_idx"
  ON "BookingChange"("requestedByUserId") WHERE "requestedByUserId" IS NOT NULL;

-- CostReceipt.uploadedByUserId: who uploaded it (RA-BE-178: a receipt on another person's cost stays, from «عضو سابق»).
UPDATE "CostReceipt"
SET "uploadedByUserId" = NULL
WHERE "uploadedByUserId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "CostReceipt"."uploadedByUserId");

ALTER TABLE "CostReceipt"
  ADD CONSTRAINT "CostReceipt_uploadedByUserId_fkey"
  FOREIGN KEY ("uploadedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ProviderReviewEvent.actorId: the account that acted (an admin, or the provider).
UPDATE "ProviderReviewEvent"
SET "actorId" = NULL
WHERE "actorId" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "ProviderReviewEvent"."actorId");

ALTER TABLE "ProviderReviewEvent"
  ADD CONSTRAINT "ProviderReviewEvent_actorId_fkey"
  FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProviderReviewEvent_actorId_idx"
  ON "ProviderReviewEvent"("actorId") WHERE "actorId" IS NOT NULL;

-- Provider.verifiedById: the admin who checked the documents.
UPDATE "Provider"
SET "verifiedById" = NULL
WHERE "verifiedById" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "Provider"."verifiedById");

ALTER TABLE "Provider"
  ADD CONSTRAINT "Provider_verifiedById_fkey"
  FOREIGN KEY ("verifiedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Provider_verifiedById_idx"
  ON "Provider"("verifiedById") WHERE "verifiedById" IS NOT NULL;

-- ProviderClaimRequest.decidedById: the admin who decided.
UPDATE "ProviderClaimRequest"
SET "decidedById" = NULL
WHERE "decidedById" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "ProviderClaimRequest"."decidedById");

ALTER TABLE "ProviderClaimRequest"
  ADD CONSTRAINT "ProviderClaimRequest_decidedById_fkey"
  FOREIGN KEY ("decidedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProviderClaimRequest_decidedById_idx"
  ON "ProviderClaimRequest"("decidedById") WHERE "decidedById" IS NOT NULL;

-- ProviderFeaturedPeriod.endedById: the admin who ended it.
UPDATE "ProviderFeaturedPeriod"
SET "endedById" = NULL
WHERE "endedById" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "ProviderFeaturedPeriod"."endedById");

ALTER TABLE "ProviderFeaturedPeriod"
  ADD CONSTRAINT "ProviderFeaturedPeriod_endedById_fkey"
  FOREIGN KEY ("endedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProviderFeaturedPeriod_endedById_idx"
  ON "ProviderFeaturedPeriod"("endedById") WHERE "endedById" IS NOT NULL;

-- PortfolioItem.reviewedById: the admin who reviewed it.
UPDATE "PortfolioItem"
SET "reviewedById" = NULL
WHERE "reviewedById" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "PortfolioItem"."reviewedById");

ALTER TABLE "PortfolioItem"
  ADD CONSTRAINT "PortfolioItem_reviewedById_fkey"
  FOREIGN KEY ("reviewedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "PortfolioItem_reviewedById_idx"
  ON "PortfolioItem"("reviewedById") WHERE "reviewedById" IS NOT NULL;

-- ProviderProfileChange.decidedById: the admin who decided.
UPDATE "ProviderProfileChange"
SET "decidedById" = NULL
WHERE "decidedById" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "User" WHERE "id" = "ProviderProfileChange"."decidedById");

ALTER TABLE "ProviderProfileChange"
  ADD CONSTRAINT "ProviderProfileChange_decidedById_fkey"
  FOREIGN KEY ("decidedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "ProviderProfileChange_decidedById_idx"
  ON "ProviderProfileChange"("decidedById") WHERE "decidedById" IS NOT NULL;
