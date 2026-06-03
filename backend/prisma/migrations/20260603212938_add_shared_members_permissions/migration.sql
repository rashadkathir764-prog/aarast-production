-- CreateEnum
CREATE TYPE "SharedMemberRole" AS ENUM ('VIEWER', 'CONTRIBUTOR', 'MANAGER');

-- CreateTable
CREATE TABLE "SharedMember" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "SharedMemberRole" NOT NULL DEFAULT 'VIEWER',
    "canViewBudget" BOOLEAN NOT NULL DEFAULT false,
    "canViewExpenses" BOOLEAN NOT NULL DEFAULT false,
    "canViewDebts" BOOLEAN NOT NULL DEFAULT false,
    "canManageTasks" BOOLEAN NOT NULL DEFAULT false,
    "canManageFinancialRecords" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SharedMember_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SharedMember_weddingPlanId_userId_key" ON "SharedMember"("weddingPlanId", "userId");

-- AddForeignKey
ALTER TABLE "SharedMember" ADD CONSTRAINT "SharedMember_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SharedMember" ADD CONSTRAINT "SharedMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
