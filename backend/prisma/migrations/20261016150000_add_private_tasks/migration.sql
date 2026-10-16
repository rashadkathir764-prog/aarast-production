-- AlterTable
ALTER TABLE "WeddingTask" ADD COLUMN "privateToUserId" TEXT;

-- CreateIndex
CREATE INDEX "WeddingTask_weddingPlanId_privateToUserId_idx" ON "WeddingTask"("weddingPlanId", "privateToUserId");
