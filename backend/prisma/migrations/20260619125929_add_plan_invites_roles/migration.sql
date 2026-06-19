-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "SharedMemberRole" ADD VALUE 'OWNER';
ALTER TYPE "SharedMemberRole" ADD VALUE 'EDITOR';
ALTER TYPE "SharedMemberRole" ADD VALUE 'FINANCE_MANAGER';
ALTER TYPE "SharedMemberRole" ADD VALUE 'HELPER';

-- CreateTable
CREATE TABLE "PlanInvite" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "inviterUserId" TEXT NOT NULL,
    "inviteeUserId" TEXT,
    "phone" TEXT,
    "token" TEXT NOT NULL,
    "role" "SharedMemberRole" NOT NULL DEFAULT 'VIEWER',
    "canViewBudget" BOOLEAN NOT NULL DEFAULT false,
    "canViewExpenses" BOOLEAN NOT NULL DEFAULT false,
    "canViewDebts" BOOLEAN NOT NULL DEFAULT false,
    "canManageTasks" BOOLEAN NOT NULL DEFAULT false,
    "canManageFinancialRecords" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "acceptedAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlanInvite_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PlanInvite_token_key" ON "PlanInvite"("token");

-- CreateIndex
CREATE INDEX "PlanInvite_weddingPlanId_createdAt_idx" ON "PlanInvite"("weddingPlanId", "createdAt");

-- CreateIndex
CREATE INDEX "PlanInvite_inviteeUserId_acceptedAt_idx" ON "PlanInvite"("inviteeUserId", "acceptedAt");

-- CreateIndex
CREATE INDEX "PlanInvite_phone_acceptedAt_idx" ON "PlanInvite"("phone", "acceptedAt");

-- CreateIndex
CREATE INDEX "PlanInvite_expiresAt_idx" ON "PlanInvite"("expiresAt");

-- AddForeignKey
ALTER TABLE "PlanInvite" ADD CONSTRAINT "PlanInvite_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanInvite" ADD CONSTRAINT "PlanInvite_inviterUserId_fkey" FOREIGN KEY ("inviterUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanInvite" ADD CONSTRAINT "PlanInvite_inviteeUserId_fkey" FOREIGN KEY ("inviteeUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
