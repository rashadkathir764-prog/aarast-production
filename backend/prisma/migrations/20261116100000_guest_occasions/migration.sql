-- D116: guests, occasions and invitations as one system.
--
-- Each occasion carries its own place (a map link and an address) and a
-- version raised when its day, time or place changes. Every plan has its
-- wedding row (its day stays the plan's). A guest has one stable personal
-- link; the last random link sent before this keeps opening until the link
-- is replaced. What each guest was told, and of which occasions at which
-- version, is kept in GuestInvitationSend, and nowhere else.

ALTER TABLE "PlanEvent" ADD COLUMN "mapUrl" TEXT,
ADD COLUMN "address" TEXT,
ADD COLUMN "version" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "Guest" ADD COLUMN "rsvpLinkHash" TEXT,
ADD COLUMN "rsvpLinkVersion" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "linkOpenedAt" TIMESTAMP(3),
ADD COLUMN "weddingAnsweredVersion" INTEGER;

CREATE UNIQUE INDEX "Guest_rsvpLinkHash_key" ON "Guest"("rsvpLinkHash");

ALTER TABLE "GuestEventInvite" ADD COLUMN "answeredVersion" INTEGER;

CREATE TYPE "GuestInvitationCardPhotoKind" AS ENUM ('PHOTO', 'CARD');

ALTER TABLE "GuestInvitationCard" ADD COLUMN "photoKind" "GuestInvitationCardPhotoKind" NOT NULL DEFAULT 'PHOTO';

CREATE TYPE "GuestInvitationSendKind" AS ENUM ('INVITATION', 'ADDITION', 'CHANGE', 'REMINDER');

CREATE TYPE "GuestInvitationSendStatus" AS ENUM ('PREPARED', 'SENT', 'NOT_SENT');

CREATE TYPE "GuestInvitationSendChannel" AS ENUM ('WHATSAPP', 'SMS', 'COPY');

CREATE TABLE "GuestInvitationSend" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "guestId" TEXT NOT NULL,
    "kind" "GuestInvitationSendKind" NOT NULL,
    "planEventId" TEXT,
    "events" JSONB NOT NULL,
    "channel" "GuestInvitationSendChannel" NOT NULL DEFAULT 'WHATSAPP',
    "status" "GuestInvitationSendStatus" NOT NULL DEFAULT 'PREPARED',
    "createdByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "settledAt" TIMESTAMP(3),

    CONSTRAINT "GuestInvitationSend_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "GuestInvitationSend_weddingPlanId_status_idx" ON "GuestInvitationSend"("weddingPlanId", "status");

CREATE INDEX "GuestInvitationSend_guestId_createdAt_idx" ON "GuestInvitationSend"("guestId", "createdAt");

ALTER TABLE "GuestInvitationSend" ADD CONSTRAINT "GuestInvitationSend_guestId_fkey" FOREIGN KEY ("guestId") REFERENCES "Guest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Every plan gets its wedding row; its day stays the plan's (the row's
-- "date" stays empty, as PlanEvent_wedding_date_check requires).
INSERT INTO "PlanEvent" ("id", "weddingPlanId", "type", "createdAt", "updatedAt")
SELECT 'wedding_' || plan."id", plan."id", 'WEDDING', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "WeddingPlan" plan
WHERE NOT EXISTS (
    SELECT 1 FROM "PlanEvent" event
    WHERE event."weddingPlanId" = plan."id" AND event."type" = 'WEDDING'
);

-- The wedding's map link and address move from the card to the wedding row.
UPDATE "PlanEvent" event
SET "mapUrl" = COALESCE(event."mapUrl", card."mapUrl"),
    "address" = COALESCE(event."address", card."address")
FROM "GuestInvitationCard" card
WHERE card."weddingPlanId" = event."weddingPlanId" AND event."type" = 'WEDDING';

UPDATE "GuestInvitationCard" SET "mapUrl" = NULL, "address" = NULL
WHERE "mapUrl" IS NOT NULL OR "address" IS NOT NULL;
