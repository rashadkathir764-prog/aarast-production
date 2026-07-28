ALTER TABLE "OtpCode"
ADD CONSTRAINT "OtpCode_invite_access_context_check"
CHECK (
  (
    "purpose" = 'INVITE_ACCESS'
    AND "planInviteId" IS NOT NULL
  )
  OR
  (
    "purpose" <> 'INVITE_ACCESS'
    AND "planInviteId" IS NULL
  )
);
