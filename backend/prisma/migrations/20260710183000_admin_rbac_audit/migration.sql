CREATE TYPE "AdminRole" AS ENUM (
  'SUPER_ADMIN',
  'OPERATIONS',
  'MODERATOR',
  'SUPPORT'
);

CREATE TYPE "AdminAuditPhase" AS ENUM (
  'ATTEMPT',
  'SUCCEEDED',
  'FAILED'
);

ALTER TABLE "User" ADD COLUMN "adminRole" "AdminRole";

UPDATE "User"
SET "adminRole" = 'SUPER_ADMIN'
WHERE "role" = 'ADMIN';

ALTER TABLE "User"
ADD CONSTRAINT "User_adminRole_consistency_check"
CHECK (
  ("role" = 'ADMIN' AND "adminRole" IS NOT NULL)
  OR
  ("role" <> 'ADMIN' AND "adminRole" IS NULL)
);

CREATE TABLE "AdminAuditLog" (
  "id" TEXT NOT NULL,
  "eventId" TEXT NOT NULL,
  "actorUserId" TEXT NOT NULL,
  "actorAdminRole" "AdminRole" NOT NULL,
  "action" TEXT NOT NULL,
  "method" TEXT NOT NULL,
  "route" TEXT NOT NULL,
  "targetId" TEXT,
  "phase" "AdminAuditPhase" NOT NULL,
  "statusCode" INTEGER,
  "errorType" TEXT,
  "requestId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "AdminAuditLog_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AdminAuditLog_eventId_phase_key"
ON "AdminAuditLog"("eventId", "phase");

CREATE INDEX "AdminAuditLog_actorUserId_createdAt_idx"
ON "AdminAuditLog"("actorUserId", "createdAt");

CREATE INDEX "AdminAuditLog_action_createdAt_idx"
ON "AdminAuditLog"("action", "createdAt");

CREATE INDEX "AdminAuditLog_createdAt_idx"
ON "AdminAuditLog"("createdAt");

CREATE FUNCTION prevent_admin_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'AdminAuditLog is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "AdminAuditLog_append_only"
BEFORE UPDATE OR DELETE ON "AdminAuditLog"
FOR EACH ROW EXECUTE FUNCTION prevent_admin_audit_log_mutation();
