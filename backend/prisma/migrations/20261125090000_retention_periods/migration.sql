-- RA-BE-179 (Q-45, D124): the back office's audit log had no end. It is now
-- kept two years: its append-only trigger still refuses every UPDATE and
-- the DELETE of any row younger than two years, and lets only the older
-- rows go (the daily retention job, AdminAuditRetentionScheduler). The rule
-- is the database's own; no session flag or bypass exists.
CREATE OR REPLACE FUNCTION prevent_admin_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE'
     AND OLD."createdAt" < (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') - INTERVAL '2 years' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'AdminAuditLog is append-only';
END;
$$ LANGUAGE plpgsql;
