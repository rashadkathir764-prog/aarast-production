-- RA-BE-176 (D124): the contribution history kept guests' and members'
-- names for ever, after the guest, the member, the plan or the account was
-- deleted. New snapshots carry no person's name (the event's entity type
-- and id are its label; the history reads the name live from the guest or
-- member, «محذوف» once it is gone). This removes the names the history
-- already holds: `displayName` from every guest, member and invitation
-- snapshot. A group's name is not a person's and stays.
--
-- ContributionEvent is append-only (its trigger rejects every UPDATE and
-- DELETE). The trigger is disabled inside this migration's own transaction
-- only, around this one statement, and enabled again before it commits; a
-- failure rolls the whole transaction back with the trigger in place.
-- Nothing at runtime can change an event.
--
-- The hashes follow the snapshot: `snapshotHash` and `eventFingerprint` are
-- recomputed exactly as the runtime computes them (SHA-256 of the canonical
-- JSON: compact, keys sorted by code point), so a redacted event is the
-- event the runtime would write now.
BEGIN;

CREATE FUNCTION "redaction_canonical_json"(input JSONB)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
DECLARE
  input_type TEXT := jsonb_typeof(input);
  output TEXT;
BEGIN
  IF input_type = 'object' THEN
    SELECT '{' || string_agg(
      to_json(entry.key)::text || ':' || "redaction_canonical_json"(entry.value),
      ',' ORDER BY entry.key COLLATE "C"
    ) || '}'
    INTO output
    FROM jsonb_each(input) AS entry;
    RETURN COALESCE(output, '{}');
  ELSIF input_type = 'array' THEN
    SELECT '[' || string_agg(
      "redaction_canonical_json"(item.value),
      ',' ORDER BY item.ordinality
    ) || ']'
    INTO output
    FROM jsonb_array_elements(input) WITH ORDINALITY AS item(value, ordinality);
    RETURN COALESCE(output, '[]');
  END IF;
  RETURN input::text;
END;
$$;

CREATE FUNCTION "redaction_sha256"(input JSONB)
RETURNS CHAR(64)
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
  SELECT encode(sha256(convert_to("redaction_canonical_json"(input), 'UTF8')), 'hex')
$$;

ALTER TABLE "ContributionEvent" DISABLE TRIGGER "ContributionEvent_append_only";

WITH redacted AS (
  SELECT
    event."id",
    event."snapshot" - 'displayName' AS "snapshot",
    "redaction_sha256"(event."snapshot" - 'displayName') AS "snapshotHash"
  FROM "ContributionEvent" AS event
  WHERE event."entityType" IN (
      'GUEST'::"ContributionEntityType",
      'MEMBER_ITEM'::"ContributionEntityType",
      'PLAN_INVITE'::"ContributionEntityType"
    )
    AND event."snapshot" ? 'displayName'
)
UPDATE "ContributionEvent" AS event
SET
  "snapshot" = redacted."snapshot",
  "snapshotHash" = redacted."snapshotHash",
  "eventFingerprint" = "redaction_sha256"(jsonb_build_object(
    'contributorReference', tenure."actorReference",
    'contributorTenureId', event."contributorTenureId",
    'section', event."section"::text,
    'entityType', event."entityType"::text,
    'entityId', event."entityId",
    'action', event."action"::text,
    'snapshotHash', redacted."snapshotHash",
    'provenance', event."provenance"::text,
    'requiredPermission', event."requiredPermission"::text,
    'permissionPolicyVersion', event."permissionPolicyVersion",
    'authorityVersion', event."authorityVersion",
    'occurredAt', to_char(event."occurredAt", 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  ))
FROM redacted, "ContributorTenure" AS tenure
WHERE event."id" = redacted."id"
  AND tenure."id" = event."contributorTenureId";

ALTER TABLE "ContributionEvent" ENABLE TRIGGER "ContributionEvent_append_only";

DROP FUNCTION "redaction_sha256"(JSONB);
DROP FUNCTION "redaction_canonical_json"(JSONB);

COMMIT;
