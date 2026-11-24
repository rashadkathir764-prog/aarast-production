-- RA-BE-138 (Q-34 (ب)): an agreement made by accepting an offer stays when
-- the provider declines or cancels its booking, and is named in «يحتاج
-- انتباهك» with «احذف البند؟». Marketplace marks it through finance's port
-- and clears it when the booking is asked for again or confirmed. Additive;
-- agreements before this keep it empty.

-- AlterTable
ALTER TABLE "WeddingCost" ADD COLUMN     "bookingFellThroughAt" TIMESTAMP(3);
