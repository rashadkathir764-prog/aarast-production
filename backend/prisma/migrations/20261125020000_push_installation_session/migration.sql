-- RA-MO-358: a push registration remembers the application session it was
-- made under, so ending that session lets the registration go with it. A
-- plain id (identity owns the session row); additive, the registrations
-- before this keep it empty and are released with the account's sessions
-- as before.

-- AlterTable
ALTER TABLE "PushInstallation" ADD COLUMN     "sessionId" TEXT;

-- CreateIndex
CREATE INDEX "PushInstallation_sessionId_idx" ON "PushInstallation"("sessionId");
