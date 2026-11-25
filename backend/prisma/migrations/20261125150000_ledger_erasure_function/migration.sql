-- RA-BE-180: the payment ledger (`CostPayment`) is append-only, and until now
-- any session could switch that off for its transaction by setting
-- `aarast.allow_ledger_purge` (the account erasure did, and so could any
-- statement that reached the database). The setting is gone. A ledger row is
-- deleted only inside `aarast_erase_cost_ledger`, which takes one cost and
-- deletes its payments only when that cost is being erased: its plan was
-- deleted and its 30 days are over (Q-45), or the plan's owner, or the
-- account the cost is private to, asked for the account's deletion and its
-- day has come (D63). For any other cost it refuses, and nothing is deleted.
-- The days are stored as UTC without a zone (Prisma), so they are compared
-- with the UTC time, whatever the server's TimeZone.
--
-- The function is SECURITY DEFINER, owned by the role that runs this
-- migration (the migrator in production), with a fixed search_path. The
-- trigger accepts a DELETE only when it runs as that owner (inside a
-- SECURITY DEFINER call; the runtime role is never the migrator, nor a member
-- of it) and the statement is the function's own (its frame in the PL/pgSQL
-- call stack, `PG_CONTEXT`). So no session setting, and no statement of the
-- runtime role, opens the ledger; where one role is both (a developer's
-- database) the call stack alone still keeps every other DELETE out. The
-- runtime role is given EXECUTE on it by
-- deploy/dokploy/postgres/least-privilege.sql.
--
-- No row is changed by this migration.

CREATE FUNCTION "aarast_erase_cost_ledger"(erased_cost_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  removed INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM "WeddingCost" cost
    JOIN "WeddingPlan" plan ON plan."id" = cost."weddingPlanId"
    LEFT JOIN "User" owner ON owner."id" = plan."ownerUserId"
    LEFT JOIN "User" holder ON holder."id" = cost."privateToUserId"
    WHERE cost."id" = erased_cost_id
      AND (
        (plan."deletionRequestedAt" IS NOT NULL AND plan."deletionScheduledFor" <= (now() AT TIME ZONE 'UTC'))
        OR (owner."deletionRequestedAt" IS NOT NULL AND owner."deletionScheduledFor" <= (now() AT TIME ZONE 'UTC'))
        OR (holder."deletionRequestedAt" IS NOT NULL AND holder."deletionScheduledFor" <= (now() AT TIME ZONE 'UTC'))
      )
  ) THEN
    RAISE EXCEPTION 'CostPayment is append-only: cost % is not being erased', erased_cost_id;
  END IF;
  DELETE FROM "CostPayment" WHERE "weddingCostId" = erased_cost_id;
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;

REVOKE ALL ON FUNCTION "aarast_erase_cost_ledger"(TEXT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION "aarast_protect_cost_payment_ledger"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  call_stack TEXT;
  eraser_owner NAME;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'CostPayment is append-only';
  END IF;
  SELECT pg_get_userbyid(routine.proowner) INTO eraser_owner
  FROM pg_proc routine
  WHERE routine.oid = 'public.aarast_erase_cost_ledger(text)'::regprocedure;
  GET DIAGNOSTICS call_stack = PG_CONTEXT;
  IF current_user <> eraser_owner
     OR call_stack !~ E'(^|\n)PL/pgSQL function aarast_erase_cost_ledger\\(text\\) line [0-9]+ at SQL statement(\n|$)' THEN
    RAISE EXCEPTION 'CostPayment is append-only';
  END IF;
  RETURN OLD;
END $$;
