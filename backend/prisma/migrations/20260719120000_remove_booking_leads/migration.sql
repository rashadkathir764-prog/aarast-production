-- The BookingLead model was a marketplace-foundation relic. The product
-- settled on the QuoteRequest -> QuoteOffer -> Conversation path and nothing
-- ever read or wrote BookingLead, so the table, its enum, and its foreign keys
-- are removed.

-- DropForeignKey
ALTER TABLE "BookingLead" DROP CONSTRAINT "BookingLead_userId_fkey";

-- DropForeignKey
ALTER TABLE "BookingLead" DROP CONSTRAINT "BookingLead_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "BookingLead" DROP CONSTRAINT "BookingLead_providerId_fkey";

-- DropForeignKey
ALTER TABLE "BookingLead" DROP CONSTRAINT "BookingLead_quoteRequestId_fkey";

-- DropTable
DROP TABLE "BookingLead";

-- DropEnum
DROP TYPE "BookingLeadStatus";
