UPDATE "NotificationPreference"
SET
  "pushEnabled" = false,
  "smsEnabled" = false,
  "whatsappEnabled" = false,
  "emailEnabled" = false
WHERE
  "pushEnabled" = true
  OR "smsEnabled" = true
  OR "whatsappEnabled" = true
  OR "emailEnabled" = true;

ALTER TABLE "NotificationPreference"
  ALTER COLUMN "pushEnabled" SET DEFAULT false;
