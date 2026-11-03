-- D83: the plan's invitation card and the guests' events beyond the wedding.
-- Every guest is invited to the wedding (their reply stays on "Guest"); a
-- GuestEventInvite row is one guest's invitation to one more event of the
-- plan (the lunch, the aqd...) with their reply to it.

CREATE TABLE "GuestInvitationCard" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "hostLine" TEXT,
    "freeText" TEXT,
    "photoUrl" TEXT,
    "mapUrl" TEXT,
    "address" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GuestInvitationCard_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "GuestInvitationCard_weddingPlanId_key" ON "GuestInvitationCard"("weddingPlanId");

ALTER TABLE "GuestInvitationCard" ADD CONSTRAINT "GuestInvitationCard_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "GuestEventInvite" (
    "id" TEXT NOT NULL,
    "guestId" TEXT NOT NULL,
    "planEventId" TEXT NOT NULL,
    "attendanceStatus" "GuestAttendanceStatus" NOT NULL DEFAULT 'PENDING',
    "companionsCount" INTEGER NOT NULL DEFAULT 0,
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GuestEventInvite_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "GuestEventInvite_guestId_planEventId_key" ON "GuestEventInvite"("guestId", "planEventId");

CREATE INDEX "GuestEventInvite_planEventId_idx" ON "GuestEventInvite"("planEventId");

ALTER TABLE "GuestEventInvite" ADD CONSTRAINT "GuestEventInvite_guestId_fkey" FOREIGN KEY ("guestId") REFERENCES "Guest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "GuestEventInvite" ADD CONSTRAINT "GuestEventInvite_planEventId_fkey" FOREIGN KEY ("planEventId") REFERENCES "PlanEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;
