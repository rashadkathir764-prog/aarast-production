-- Guest RSVP links (V1 checklist 4.7): a personal link per guest, stored as
-- a SHA-256 hash only, and the time the guest last answered through it.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'GUEST_RESPONDED';

-- AlterTable
ALTER TABLE "Guest" ADD COLUMN     "respondedAt" TIMESTAMP(3),
ADD COLUMN     "rsvpTokenHash" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Guest_rsvpTokenHash_key" ON "Guest"("rsvpTokenHash");
