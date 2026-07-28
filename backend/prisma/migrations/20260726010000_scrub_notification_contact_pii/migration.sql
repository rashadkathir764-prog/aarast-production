-- Historical provider alerts copied requester/sender display names into a
-- secondary notification store. Keep the protected quote/conversation as the
-- only source of those identities and make old alert text generic.
UPDATE "Notification"
SET "body" = 'وصلك طلب عرض سعر جديد. افتح بوابة المورد لمراجعته والرد بعرضك.'
WHERE "type" = 'QUOTE_REQUEST_SUBMITTED'
  AND "entityType" = 'quote_request'
  AND "routeTarget" = '/provider/dashboard';

UPDATE "Notification"
SET "body" = 'لديك رسالة جديدة في محادثة عرض سعر.'
WHERE "type" = 'CHAT_MESSAGE_RECEIVED'
  AND "entityType" = 'conversation';
