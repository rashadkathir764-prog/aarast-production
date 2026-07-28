BEGIN;

ALTER TYPE "OtpPurpose" ADD VALUE 'INVITE_ACCESS';

ALTER TABLE "OtpCode"
  ADD COLUMN "planInviteId" TEXT;

DROP INDEX "OtpCode_one_active_per_phone_purpose";

CREATE UNIQUE INDEX "OtpCode_one_active_per_phone_purpose"
  ON "OtpCode"("phone", "purpose")
  WHERE "consumedAt" IS NULL
    AND "planInviteId" IS NULL;

CREATE UNIQUE INDEX "OtpCode_one_active_per_invite"
  ON "OtpCode"("phone", "purpose", "planInviteId")
  WHERE "consumedAt" IS NULL
    AND "planInviteId" IS NOT NULL;

CREATE INDEX "OtpCode_planInviteId_purpose_consumedAt_idx"
  ON "OtpCode"("planInviteId", "purpose", "consumedAt");

ALTER TABLE "OtpCode"
  ADD CONSTRAINT "OtpCode_planInviteId_fkey"
  FOREIGN KEY ("planInviteId")
  REFERENCES "PlanInvite"("id")
  ON DELETE CASCADE
  ON UPDATE CASCADE;

COMMIT;
