-- AlterEnum
ALTER TYPE "WeddingTaskPriority" ADD VALUE 'URGENT';

-- AlterTable
ALTER TABLE "WeddingTask" ADD COLUMN     "assigneeUserId" TEXT;

-- CreateTable
CREATE TABLE "WeddingTaskChecklistItem" (
    "id" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "isDone" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WeddingTaskChecklistItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "WeddingTaskChecklistItem_taskId_sortOrder_idx" ON "WeddingTaskChecklistItem"("taskId", "sortOrder");

-- CreateIndex
CREATE INDEX "WeddingTask_weddingPlanId_status_idx" ON "WeddingTask"("weddingPlanId", "status");

-- CreateIndex
CREATE INDEX "WeddingTask_assigneeUserId_idx" ON "WeddingTask"("assigneeUserId");

-- AddForeignKey
ALTER TABLE "WeddingTask" ADD CONSTRAINT "WeddingTask_assigneeUserId_fkey" FOREIGN KEY ("assigneeUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WeddingTaskChecklistItem" ADD CONSTRAINT "WeddingTaskChecklistItem_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "WeddingTask"("id") ON DELETE CASCADE ON UPDATE CASCADE;
