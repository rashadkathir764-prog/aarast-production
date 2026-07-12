CREATE INDEX "Notification_userId_archivedAt_createdAt_idx"
ON "Notification"("userId", "archivedAt", "createdAt");

CREATE INDEX "Notification_userId_weddingPlanId_archivedAt_createdAt_idx"
ON "Notification"("userId", "weddingPlanId", "archivedAt", "createdAt");
