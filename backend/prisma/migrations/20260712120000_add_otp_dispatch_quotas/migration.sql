CREATE TABLE "OtpDispatchQuota" (
    "scope" VARCHAR(32) NOT NULL,
    "subjectHash" CHAR(64) NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "windowStartedAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OtpDispatchQuota_pkey" PRIMARY KEY ("scope", "subjectHash")
);

CREATE INDEX "OtpDispatchQuota_updatedAt_idx"
ON "OtpDispatchQuota"("updatedAt");
