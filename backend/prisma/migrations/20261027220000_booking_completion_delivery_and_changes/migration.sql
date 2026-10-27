-- G25 (owner-vision audit 2026-10-27): B-22 «تم العرس؟ / ما صار», B-23 the
-- delivery promise and the delivery, B-24 the customer moving the day.
ALTER TABLE "Booking"
    ADD COLUMN "completedAt" TIMESTAMP(3),
    ADD COLUMN "notHappenedAt" TIMESTAMP(3),
    ADD COLUMN "notHappenedReason" TEXT,
    ADD COLUMN "deliveryDueAt" TIMESTAMP(3),
    ADD COLUMN "deliveredAt" TIMESTAMP(3),
    ADD COLUMN "deliveryLink" TEXT,
    ADD COLUMN "deliveryNote" TEXT,
    ADD COLUMN "deliveryConfirmedAt" TIMESTAMP(3);

ALTER TABLE "Booking"
    ADD CONSTRAINT "Booking_outcome_check"
    CHECK (NOT ("completedAt" IS NOT NULL AND "notHappenedAt" IS NOT NULL)),
    ADD CONSTRAINT "Booking_notHappenedReason_check"
    CHECK (("notHappenedAt" IS NULL) = ("notHappenedReason" IS NULL)
        AND ("notHappenedReason" IS NULL OR "notHappenedReason" IN
            ('CUSTOMER_NO_SHOW', 'WE_DID_NOT_ATTEND', 'FORCE_MAJEURE', 'OFFICIAL_DECISION')));

CREATE TYPE "BookingChangeStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED');

CREATE TABLE "BookingChange" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "fromDate" DATE NOT NULL,
    "toDate" DATE NOT NULL,
    "status" "BookingChangeStatus" NOT NULL DEFAULT 'PENDING',
    "requestedByUserId" TEXT NOT NULL,
    "note" TEXT,
    "declineReason" TEXT,
    "decidedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "BookingChange_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "BookingChange_bookingId_status_idx" ON "BookingChange"("bookingId", "status");

-- One pending change per booking.
CREATE UNIQUE INDEX "BookingChange_one_pending" ON "BookingChange"("bookingId") WHERE "status" = 'PENDING';

ALTER TABLE "BookingChange" ADD CONSTRAINT "BookingChange_bookingId_fkey"
    FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;
