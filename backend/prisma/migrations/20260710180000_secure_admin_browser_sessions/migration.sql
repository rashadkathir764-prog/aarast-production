CREATE TABLE "AdminLoginChallenge" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "tokenHash" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "consumedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "AdminLoginChallenge_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AdminLoginChallenge_tokenHash_key"
ON "AdminLoginChallenge"("tokenHash");

CREATE INDEX "AdminLoginChallenge_userId_consumedAt_idx"
ON "AdminLoginChallenge"("userId", "consumedAt");

CREATE INDEX "AdminLoginChallenge_expiresAt_idx"
ON "AdminLoginChallenge"("expiresAt");

ALTER TABLE "AdminLoginChallenge"
ADD CONSTRAINT "AdminLoginChallenge_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

-- Legacy admin refresh sessions were issued without MFA assurance. Revoke
-- them so only the new password + OTP browser flow can mint admin sessions.
UPDATE "RefreshToken"
SET "revokedAt" = CURRENT_TIMESTAMP
WHERE "revokedAt" IS NULL
  AND "userId" IN (SELECT "id" FROM "User" WHERE "role" = 'ADMIN');
