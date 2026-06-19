-- CreateEnum
CREATE TYPE "GuestInvitationStatus" AS ENUM ('NOT_SENT', 'SENT', 'DELIVERED');

-- CreateEnum
CREATE TYPE "GuestAttendanceStatus" AS ENUM ('PENDING', 'CONFIRMED', 'DECLINED');

-- AlterTable
ALTER TABLE "Guest" ADD COLUMN     "attendanceStatus" "GuestAttendanceStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "companionsCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "groupId" TEXT,
ADD COLUMN     "invitationStatus" "GuestInvitationStatus" NOT NULL DEFAULT 'NOT_SENT';

-- CreateTable
CREATE TABLE "GuestGroup" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "notes" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GuestGroup_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "GuestGroup_weddingPlanId_sortOrder_idx" ON "GuestGroup"("weddingPlanId", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "GuestGroup_weddingPlanId_name_key" ON "GuestGroup"("weddingPlanId", "name");

-- CreateIndex
CREATE INDEX "Guest_weddingPlanId_invitationStatus_idx" ON "Guest"("weddingPlanId", "invitationStatus");

-- CreateIndex
CREATE INDEX "Guest_weddingPlanId_attendanceStatus_idx" ON "Guest"("weddingPlanId", "attendanceStatus");

-- CreateIndex
CREATE INDEX "Guest_weddingPlanId_groupId_idx" ON "Guest"("weddingPlanId", "groupId");

-- AddForeignKey
ALTER TABLE "Guest" ADD CONSTRAINT "Guest_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "GuestGroup"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GuestGroup" ADD CONSTRAINT "GuestGroup_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;
