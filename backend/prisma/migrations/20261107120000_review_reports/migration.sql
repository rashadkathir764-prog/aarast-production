-- RA-ST-05: a report that a published review is offensive or false, from a
-- reader or from the provider it reviews. One per reporter and review; open
-- until the moderation team hides or keeps the review (resolvedAt). Reports
-- go with their review, and a reporter's reports with their account.

CREATE TABLE "ReviewReport" (
    "id" TEXT NOT NULL,
    "reviewId" TEXT NOT NULL,
    "reporterUserId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReviewReport_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ReviewReport_reviewId_reporterUserId_key" ON "ReviewReport"("reviewId", "reporterUserId");

CREATE INDEX "ReviewReport_resolvedAt_createdAt_idx" ON "ReviewReport"("resolvedAt", "createdAt");

ALTER TABLE "ReviewReport" ADD CONSTRAINT "ReviewReport_reviewId_fkey" FOREIGN KEY ("reviewId") REFERENCES "ProviderReview"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ReviewReport" ADD CONSTRAINT "ReviewReport_reporterUserId_fkey" FOREIGN KEY ("reporterUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
