-- CreateEnum
CREATE TYPE "WeddingPlanStatus" AS ENUM ('PLANNING', 'ARCHIVED');

-- CreateTable
CREATE TABLE "WeddingPlan" (
    "id" TEXT NOT NULL,
    "ownerUserId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "city" TEXT,
    "weddingDate" TIMESTAMP(3),
    "estimatedBudget" DECIMAL(14,2),
    "currency" TEXT NOT NULL DEFAULT 'YER',
    "status" "WeddingPlanStatus" NOT NULL DEFAULT 'PLANNING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WeddingPlan_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "WeddingPlan" ADD CONSTRAINT "WeddingPlan_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
