ALTER TABLE "WeddingTask"
ADD COLUMN "responsibleName" TEXT,
ADD COLUMN "responsiblePhone" TEXT,
ADD COLUMN "responsibleSource" TEXT;

ALTER TABLE "WeddingTask"
ADD CONSTRAINT "WeddingTask_responsibility_mode_check"
CHECK (
  "assigneeUserId" IS NULL
  OR (
    "responsibleName" IS NULL
    AND "responsiblePhone" IS NULL
    AND "responsibleSource" IS NULL
  )
);
