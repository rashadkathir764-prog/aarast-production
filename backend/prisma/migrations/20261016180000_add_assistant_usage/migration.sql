-- CreateTable
CREATE TABLE "AssistantUsageDay" (
    "userId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "requests" INTEGER NOT NULL DEFAULT 0,
    "inputTokens" INTEGER NOT NULL DEFAULT 0,
    "outputTokens" INTEGER NOT NULL DEFAULT 0,
    "costMicroUsd" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AssistantUsageDay_pkey" PRIMARY KEY ("userId","day")
);

-- CreateIndex
CREATE INDEX "AssistantUsageDay_day_idx" ON "AssistantUsageDay"("day");

-- AddForeignKey
ALTER TABLE "AssistantUsageDay" ADD CONSTRAINT "AssistantUsageDay_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
