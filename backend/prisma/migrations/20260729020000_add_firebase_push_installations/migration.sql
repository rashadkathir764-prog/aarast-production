ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'TASK_ASSIGNED';

CREATE TYPE "PushPlatform" AS ENUM ('ANDROID', 'IOS');

CREATE TABLE "PushInstallation" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "fid" VARCHAR(200) NOT NULL,
  "platform" "PushPlatform" NOT NULL,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "PushInstallation_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "PushInstallation_fid_key"
  ON "PushInstallation"("fid");

CREATE INDEX "PushInstallation_userId_enabled_idx"
  ON "PushInstallation"("userId", "enabled");

CREATE INDEX "PushInstallation_updatedAt_idx"
  ON "PushInstallation"("updatedAt");

ALTER TABLE "PushInstallation"
  ADD CONSTRAINT "PushInstallation_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
