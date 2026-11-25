-- Q-50 (أ), D124 (RA-AD-22): a conversation report was closed with no word
-- and its reporter never heard of it. Closing it now takes a reason, kept
-- here with its time, and the reporter is told it. A report closed before
-- keeps no reason (both stay null); an open one has neither.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'CONVERSATION_REPORT_CLOSED';

-- AlterTable
ALTER TABLE "ConversationReport"
  ADD COLUMN "closingNote" TEXT,
  ADD COLUMN "closedAt" TIMESTAMP(3);

ALTER TABLE "ConversationReport"
  ADD CONSTRAINT "ConversationReport_open_has_no_closing_check" CHECK (
    "status" <> 'OPEN' OR ("closingNote" IS NULL AND "closedAt" IS NULL)
  );
