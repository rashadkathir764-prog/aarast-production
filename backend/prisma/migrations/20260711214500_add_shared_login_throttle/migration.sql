CREATE TABLE "LoginThrottle" (
    "subjectHash" CHAR(64) NOT NULL,
    "failedCount" INTEGER NOT NULL DEFAULT 0,
    "windowStartedAt" TIMESTAMP(3) NOT NULL,
    "lockedUntil" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LoginThrottle_pkey" PRIMARY KEY ("subjectHash")
);

CREATE INDEX "LoginThrottle_lockedUntil_idx" ON "LoginThrottle"("lockedUntil");
