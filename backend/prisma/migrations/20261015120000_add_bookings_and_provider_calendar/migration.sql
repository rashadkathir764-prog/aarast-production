-- Bookings without payment and the provider's calendar (V1 checklist 4.6).

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'BOOKING_UPDATED';

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('REQUESTED', 'CONFIRMED', 'DECLINED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "BookingParty" AS ENUM ('CUSTOMER', 'PROVIDER');

-- CreateTable
CREATE TABLE "Booking" (
    "id" TEXT NOT NULL,
    "quoteRequestId" TEXT NOT NULL,
    "quoteOfferId" TEXT,
    "providerId" TEXT NOT NULL,
    "eventDate" DATE NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'REQUESTED',
    "requestedByUserId" TEXT NOT NULL,
    "cancelledBy" "BookingParty",
    "note" TEXT,
    "confirmedAt" TIMESTAMP(3),
    "declinedAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Booking_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderBlockedDate" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderBlockedDate_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Booking_quoteRequestId_key" ON "Booking"("quoteRequestId");

-- CreateIndex
CREATE INDEX "Booking_providerId_eventDate_status_idx" ON "Booking"("providerId", "eventDate", "status");

-- CreateIndex
CREATE INDEX "Booking_quoteOfferId_idx" ON "Booking"("quoteOfferId");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderBlockedDate_providerId_date_key" ON "ProviderBlockedDate"("providerId", "date");

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_quoteRequestId_fkey" FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_quoteOfferId_fkey" FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderBlockedDate" ADD CONSTRAINT "ProviderBlockedDate_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- The application checks availability before confirming; this partial unique
-- index is the final invariant: a provider holds at most one confirmed
-- booking per date, so two confirmations racing for the same day cannot both
-- succeed.
CREATE UNIQUE INDEX "Booking_provider_confirmed_date_key"
ON "Booking"("providerId", "eventDate")
WHERE "status" = 'CONFIRMED';
