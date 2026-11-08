-- RA-BE-25: a reminder cancelled because its agreement was paid in full is
-- marked, so a reversed payment or a raised total that leaves money owed
-- brings it back (a reminder cancelled by hand stays cancelled).
ALTER TABLE "PaymentSchedule" ADD COLUMN "cancelledByPaidInFullAt" TIMESTAMP(3);
