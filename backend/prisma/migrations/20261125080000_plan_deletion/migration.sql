-- Q-45 (D124), RA-BE-179: a plan could only be archived, and an archived
-- plan kept its guests' numbers, invitations and everything else for ever.
-- Its owner may now ask to delete it: it closes to its members, stays
-- read-only to him for 30 days (when he can take it back), and is then
-- erased by the hourly purge.
ALTER TABLE "WeddingPlan" ADD COLUMN "deletionRequestedAt" TIMESTAMP(3),
ADD COLUMN "deletionScheduledFor" TIMESTAMP(3);

-- Both are set together and cleared together, the day after the request.
ALTER TABLE "WeddingPlan" ADD CONSTRAINT "WeddingPlan_deletion_check" CHECK (
  ("deletionRequestedAt" IS NULL AND "deletionScheduledFor" IS NULL)
  OR ("deletionRequestedAt" IS NOT NULL AND "deletionScheduledFor" > "deletionRequestedAt")
);

CREATE INDEX "WeddingPlan_deletionScheduledFor_idx" ON "WeddingPlan"("deletionScheduledFor");
