ALTER TYPE "SharedMemberRole" ADD VALUE IF NOT EXISTS 'GROOM';
ALTER TYPE "SharedMemberRole" ADD VALUE IF NOT EXISTS 'BRIDE';
ALTER TYPE "SharedMemberRole" ADD VALUE IF NOT EXISTS 'FAMILY';

ALTER TABLE "SharedMember"
ADD COLUMN "canEditPlan" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canManageGuests" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canManageProviders" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canInviteMembers" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "receiveNotifications" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "PlanInvite"
ADD COLUMN "name" TEXT,
ADD COLUMN "normalizedPhone" TEXT,
ADD COLUMN "email" TEXT,
ADD COLUMN "canEditPlan" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canManageGuests" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canManageProviders" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canInviteMembers" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "receiveNotifications" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "declinedAt" TIMESTAMP(3);

UPDATE "PlanInvite"
SET "normalizedPhone" = "phone"
WHERE "phone" IS NOT NULL AND "normalizedPhone" IS NULL;

CREATE INDEX "PlanInvite_weddingPlanId_normalizedPhone_idx"
ON "PlanInvite"("weddingPlanId", "normalizedPhone");

CREATE INDEX "PlanInvite_weddingPlanId_email_idx"
ON "PlanInvite"("weddingPlanId", "email");
