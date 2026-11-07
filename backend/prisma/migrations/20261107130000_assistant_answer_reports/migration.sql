-- RA-ST-04 (D95): an answer of the planning assistant that its reader
-- reported to the moderation team. The assistant stores no question or
-- answer; the report keeps the one its reader sent with it. Open until the
-- team marks it reviewed (resolvedAt); a reporter's reports go with their
-- account.

CREATE TABLE "AssistantAnswerReport" (
    "id" TEXT NOT NULL,
    "reporterUserId" TEXT NOT NULL,
    "kind" VARCHAR(32) NOT NULL,
    "question" TEXT,
    "answer" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AssistantAnswerReport_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "AssistantAnswerReport_resolvedAt_createdAt_idx" ON "AssistantAnswerReport"("resolvedAt", "createdAt");

CREATE INDEX "AssistantAnswerReport_reporterUserId_idx" ON "AssistantAnswerReport"("reporterUserId");

ALTER TABLE "AssistantAnswerReport" ADD CONSTRAINT "AssistantAnswerReport_reporterUserId_fkey" FOREIGN KEY ("reporterUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
