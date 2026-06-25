CREATE TYPE "NotificationPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'QUOTE_REQUEST_SUBMITTED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'DEBT_DUE_SOON';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SHARING_INVITE_DECLINED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'QUOTE_ACCEPTED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'QUOTE_REJECTED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'PLAN_UPDATED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'SYNC_REQUIRED';

ALTER TABLE "Notification"
ADD COLUMN "priority" "NotificationPriority" NOT NULL DEFAULT 'NORMAL',
ADD COLUMN "entityType" TEXT,
ADD COLUMN "entityId" TEXT,
ADD COLUMN "routeTarget" TEXT,
ADD COLUMN "archivedAt" TIMESTAMP(3);

DROP INDEX IF EXISTS "Notification_userId_readAt_createdAt_idx";
CREATE INDEX "Notification_userId_archivedAt_readAt_createdAt_idx"
ON "Notification"("userId", "archivedAt", "readAt", "createdAt");

CREATE INDEX "Notification_entityType_entityId_idx"
ON "Notification"("entityType", "entityId");
