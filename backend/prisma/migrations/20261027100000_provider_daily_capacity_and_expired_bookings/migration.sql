-- B-20: how many weddings a provider takes on one day. One number per
-- provider, 1 to 20, one by default (the old rule). Only a confirmed booking
-- takes a seat; the provider's row lock (marketplace-write-locks.ts) guards
-- the count at request and at confirm.
ALTER TABLE "Provider"
  ADD COLUMN "dailyBookingCapacity" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "Provider"
  ADD CONSTRAINT "Provider_dailyBookingCapacity_range"
  CHECK ("dailyBookingCapacity" BETWEEN 1 AND 20);

-- The partial unique index allowed one confirmed booking per provider per
-- day. A provider with a capacity above one holds more, so it goes; the
-- count under the provider's row lock is the invariant now.
DROP INDEX IF EXISTS "Booking_provider_confirmed_date_key";

-- B-42: a suspended provider's open requests end; the customer is told.
ALTER TYPE "BookingStatus" ADD VALUE IF NOT EXISTS 'EXPIRED';

ALTER TABLE "Booking" ADD COLUMN "expiredAt" TIMESTAMP(3);
