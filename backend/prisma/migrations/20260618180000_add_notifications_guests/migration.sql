-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('TASK_DUE_SOON', 'TASK_OVERDUE', 'INSTALLMENT_DUE_SOON', 'INSTALLMENT_OVERDUE', 'SHARING_INVITATION', 'SHARING_UPDATED', 'GENERAL');

-- CreateEnum
CREATE TYPE "GuestSide" AS ENUM ('GROOM', 'BRIDE', 'FAMILY', 'FRIEND', 'OTHER');

-- CreateEnum
CREATE TYPE "GuestStatus" AS ENUM ('INVITED', 'CONFIRMED', 'DECLINED', 'PENDING');

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "weddingPlanId" TEXT,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "dedupeKey" TEXT,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Guest" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT,
    "side" "GuestSide" NOT NULL DEFAULT 'OTHER',
    "status" "GuestStatus" NOT NULL DEFAULT 'INVITED',
    "seatsCount" INTEGER NOT NULL DEFAULT 1,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Guest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Notification_dedupeKey_key" ON "Notification"("dedupeKey");

-- CreateIndex
CREATE INDEX "Notification_userId_readAt_createdAt_idx" ON "Notification"("userId", "readAt", "createdAt");

-- CreateIndex
CREATE INDEX "Notification_weddingPlanId_createdAt_idx" ON "Notification"("weddingPlanId", "createdAt");

-- CreateIndex
CREATE INDEX "Guest_weddingPlanId_status_idx" ON "Guest"("weddingPlanId", "status");

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Guest" ADD CONSTRAINT "Guest_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;
