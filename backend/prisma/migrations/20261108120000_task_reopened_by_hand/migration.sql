-- RA-BE-68 (D71): a task its owner reopened by hand after a booking or a
-- payment closed it stays open; the next booking of its item closes it only
-- once that one has fallen through.
ALTER TABLE "WeddingTask" ADD COLUMN "reopenedByHandAt" TIMESTAMP(3);
