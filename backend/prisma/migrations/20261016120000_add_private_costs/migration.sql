-- AlterTable
ALTER TABLE "WeddingCost" ADD COLUMN "privateToUserId" TEXT;

-- CreateIndex
CREATE INDEX "WeddingCost_weddingPlanId_privateToUserId_idx" ON "WeddingCost"("weddingPlanId", "privateToUserId");
