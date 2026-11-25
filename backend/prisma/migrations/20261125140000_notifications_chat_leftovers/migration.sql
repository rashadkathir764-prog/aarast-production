-- RA-BE-170 (Q-42 أ): a conversation stays open to writing after a request is
-- declined, cancelled or expired or a booking ends, but its messages make no
-- notice or phone alert from this instant (30 days after the ending); any new
-- activity in a request clears it. Null for every conversation until then.
ALTER TABLE "Conversation" ADD COLUMN "pushStopsAt" TIMESTAMP(3);

-- RA-BE-190: the booking reminders are the «الحجوزات» switch; on for everyone
-- until a person turns it off.
ALTER TABLE "NotificationPreference" ADD COLUMN "bookingRemindersEnabled" BOOLEAN NOT NULL DEFAULT true;

-- RA-OP-32: the plans erased in the last 120 days, by id only, so a restored
-- backup erases them again (the same list the accounts have).
CREATE TABLE "ErasedPlan" (
    "weddingPlanId" TEXT NOT NULL,
    "erasedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ErasedPlan_pkey" PRIMARY KEY ("weddingPlanId")
);

CREATE INDEX "ErasedPlan_erasedAt_idx" ON "ErasedPlan"("erasedAt");
