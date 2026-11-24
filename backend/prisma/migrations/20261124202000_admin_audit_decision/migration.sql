-- RA-AD-23: the audit log keeps the decision, not only the route: the
-- reason the admin gave, and what the action changed on its target (before
-- and after). Additive; the rows before this keep them empty.

-- AlterTable
ALTER TABLE "AdminAuditLog" ADD COLUMN     "after" JSONB,
ADD COLUMN     "before" JSONB,
ADD COLUMN     "reason" TEXT;
