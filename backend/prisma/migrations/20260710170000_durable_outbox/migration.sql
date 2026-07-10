CREATE TABLE "OutboxEvent" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "aggregateType" TEXT,
    "aggregateId" TEXT,
    "payload" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "attemptCount" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lockedAt" TIMESTAMP(3),
    "lockedBy" TEXT,
    "processedAt" TIMESTAMP(3),
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OutboxEvent_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "OutboxEvent_status_check"
      CHECK ("status" IN ('PENDING', 'PROCESSING', 'PROCESSED', 'FAILED')),
    CONSTRAINT "OutboxEvent_attempt_count_check" CHECK ("attemptCount" >= 0)
);

CREATE INDEX "OutboxEvent_status_nextAttemptAt_createdAt_idx"
  ON "OutboxEvent"("status", "nextAttemptAt", "createdAt");

CREATE INDEX "OutboxEvent_aggregateType_aggregateId_createdAt_idx"
  ON "OutboxEvent"("aggregateType", "aggregateId", "createdAt");
