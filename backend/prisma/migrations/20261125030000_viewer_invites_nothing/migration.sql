-- RA-BE-157 (Q-38, D52): «يشوف بس» edits nothing in the plan, and inviting
-- someone into it is a write. The server no longer stores the right on a
-- viewer; this clears it from the viewers and the pending viewer invites
-- that were given it before. Data only; no column changes.

UPDATE "SharedMember"
SET "canInviteMembers" = false
WHERE "role" = 'VIEWER' AND "canInviteMembers" = true;

UPDATE "PlanInvite"
SET "canInviteMembers" = false
WHERE "role" = 'VIEWER' AND "canInviteMembers" = true
  AND "acceptedAt" IS NULL AND "declinedAt" IS NULL AND "revokedAt" IS NULL;
