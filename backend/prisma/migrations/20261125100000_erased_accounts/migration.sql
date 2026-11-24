-- RA-OP-32: a backup restored after an erasure brought the erased account
-- back, and nothing said to erase it again. The erasure now writes the
-- account's id here; the restore script puts this list back into the
-- restored database and marks those accounts due, and the hourly purge
-- erases them again. Ids only, kept 120 days (past the oldest backup).
CREATE TABLE "ErasedAccount" (
    "userId" TEXT NOT NULL,
    "erasedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ErasedAccount_pkey" PRIMARY KEY ("userId")
);

CREATE INDEX "ErasedAccount_erasedAt_idx" ON "ErasedAccount"("erasedAt");
