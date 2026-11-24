-- RA-BE-166: a reported assistant answer names the server's own answer id,
-- whose signature proved the reported text is the assistant's, so a report
-- can no longer carry text the phone made up; one report per answer. Reports
-- kept before have no id (their text was the phone's word) and keep null.
ALTER TABLE "AssistantAnswerReport" ADD COLUMN "answerId" TEXT;

CREATE UNIQUE INDEX "AssistantAnswerReport_answerId_key" ON "AssistantAnswerReport"("answerId");
