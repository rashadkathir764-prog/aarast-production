ALTER TYPE "OtpPurpose" ADD VALUE 'ADMIN_LOGIN';

CREATE TYPE "AuthSessionScope" AS ENUM ('APPLICATION', 'ADMIN');

ALTER TABLE "User"
ADD COLUMN "appName" TEXT,
ADD COLUMN "appEmail" TEXT,
ADD COLUMN "appAvatarUrl" TEXT;

CREATE UNIQUE INDEX "User_appEmail_key" ON "User"("appEmail");

ALTER TABLE "RefreshToken"
ADD COLUMN "scope" "AuthSessionScope" NOT NULL DEFAULT 'APPLICATION';

DROP INDEX IF EXISTS "RefreshToken_userId_revokedAt_idx";
CREATE INDEX "RefreshToken_userId_scope_revokedAt_idx"
ON "RefreshToken"("userId", "scope", "revokedAt");

-- Login and reset challenges are short-lived security state. Existing rows
-- cannot be bound retroactively to the exact OTP that created them, so expire
-- them safely during the migration and require a new challenge.
DELETE FROM "AdminLoginChallenge";
DELETE FROM "AdminPasswordResetChallenge";

ALTER TABLE "AdminLoginChallenge" ADD COLUMN "otpId" TEXT NOT NULL;
ALTER TABLE "AdminPasswordResetChallenge" ADD COLUMN "otpId" TEXT NOT NULL;

CREATE UNIQUE INDEX "AdminLoginChallenge_otpId_key"
ON "AdminLoginChallenge"("otpId");
CREATE UNIQUE INDEX "AdminPasswordResetChallenge_otpId_key"
ON "AdminPasswordResetChallenge"("otpId");

ALTER TABLE "AdminLoginChallenge"
ADD CONSTRAINT "AdminLoginChallenge_otpId_fkey"
FOREIGN KEY ("otpId") REFERENCES "OtpCode"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AdminPasswordResetChallenge"
ADD CONSTRAINT "AdminPasswordResetChallenge_otpId_fkey"
FOREIGN KEY ("otpId") REFERENCES "OtpCode"("id") ON DELETE CASCADE ON UPDATE CASCADE;
