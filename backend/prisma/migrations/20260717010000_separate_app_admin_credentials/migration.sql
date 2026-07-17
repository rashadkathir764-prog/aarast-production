ALTER TYPE "OtpPurpose" ADD VALUE 'ADMIN_RESET_PASSWORD';

ALTER TABLE "User" ADD COLUMN "appPasswordHash" TEXT;

CREATE TABLE "AdminPasswordResetChallenge" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "tokenHash" TEXT NOT NULL,
    "subjectHash" CHAR(64) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 5,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminPasswordResetChallenge_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AdminPasswordResetChallenge_tokenHash_key"
ON "AdminPasswordResetChallenge"("tokenHash");

CREATE INDEX "AdminPasswordResetChallenge_userId_consumedAt_idx"
ON "AdminPasswordResetChallenge"("userId", "consumedAt");

CREATE INDEX "AdminPasswordResetChallenge_subjectHash_consumedAt_idx"
ON "AdminPasswordResetChallenge"("subjectHash", "consumedAt");

CREATE INDEX "AdminPasswordResetChallenge_expiresAt_idx"
ON "AdminPasswordResetChallenge"("expiresAt");

ALTER TABLE "AdminPasswordResetChallenge"
ADD CONSTRAINT "AdminPasswordResetChallenge_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
