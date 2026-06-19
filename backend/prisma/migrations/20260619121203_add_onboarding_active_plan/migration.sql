-- CreateEnum
CREATE TYPE "OnboardingPath" AS ENUM ('USER', 'PROVIDER');

-- CreateEnum
CREATE TYPE "WeddingPersona" AS ENUM ('GROOM', 'BRIDE', 'HELPER');

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "activeWeddingPlanId" TEXT,
ADD COLUMN     "onboardingCompletedAt" TIMESTAMP(3),
ADD COLUMN     "onboardingPath" "OnboardingPath",
ADD COLUMN     "persona" "WeddingPersona";

-- AlterTable
ALTER TABLE "WeddingPlan" ADD COLUMN     "location" JSONB,
ADD COLUMN     "onboardingCompletedAt" TIMESTAMP(3),
ADD COLUMN     "onboardingPath" "OnboardingPath",
ADD COLUMN     "persona" "WeddingPersona",
ADD COLUMN     "priorities" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateIndex
CREATE INDEX "WeddingPlan_ownerUserId_status_idx" ON "WeddingPlan"("ownerUserId", "status");

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_activeWeddingPlanId_fkey" FOREIGN KEY ("activeWeddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;
