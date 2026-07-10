-- Idempotency rows created before route-template storage could contain a
-- concrete invite bearer token or a query string. They are replay metadata,
-- not an audit log, so retain only a non-sensitive route label.
UPDATE "IdempotencyKey"
SET "path" = CASE
  WHEN "path" ILIKE '%/invites/%' THEN 'redacted-invite-route'
  ELSE split_part("path", '?', 1)
END
WHERE "path" ILIKE '%/invites/%'
   OR position('?' in "path") > 0;
