-- D65: the wedding's events (b12, b13), from which the wedding week (b04)
-- and the wedding day (b05) are built. WEDDING is the main event: its day is
-- the plan's wedding date, so it keeps no date of its own.
CREATE TYPE "PlanEventType" AS ENUM ('WEDDING', 'SAMRA', 'MAQEEL', 'HAFLA', 'NASHMA', 'AQD', 'LUNCH', 'DINNER', 'CUSTOM');

CREATE TYPE "PlanEventTimeSlot" AS ENUM ('DUHA', 'DHUHR', 'AFTER_DHUHR', 'AFTER_ASR', 'AFTER_MAGHRIB', 'AFTER_ISHA', 'EXACT');

CREATE TABLE "PlanEvent" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "type" "PlanEventType" NOT NULL,
    "title" TEXT,
    "date" DATE,
    "timeSlot" "PlanEventTimeSlot",
    "exactTime" TEXT,
    "placeLabel" TEXT,
    "responsibleName" TEXT,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "PlanEvent_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "PlanEvent_weddingPlanId_date_idx" ON "PlanEvent"("weddingPlanId", "date");

-- Every kind but CUSTOM is once per plan; WEDDING is the main event.
CREATE UNIQUE INDEX "PlanEvent_one_per_type" ON "PlanEvent"("weddingPlanId", "type") WHERE "type" <> 'CUSTOM';

ALTER TABLE "PlanEvent"
    ADD CONSTRAINT "PlanEvent_custom_title_check"
    CHECK ("type" <> 'CUSTOM' OR ("title" IS NOT NULL AND length(btrim("title")) > 0)),
    ADD CONSTRAINT "PlanEvent_wedding_date_check"
    CHECK ("type" <> 'WEDDING' OR "date" IS NULL),
    ADD CONSTRAINT "PlanEvent_exact_time_check"
    CHECK (COALESCE("timeSlot" = 'EXACT', false) = ("exactTime" IS NOT NULL)
        AND ("exactTime" IS NULL OR "exactTime" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'));

ALTER TABLE "PlanEvent" ADD CONSTRAINT "PlanEvent_weddingPlanId_fkey"
    FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
