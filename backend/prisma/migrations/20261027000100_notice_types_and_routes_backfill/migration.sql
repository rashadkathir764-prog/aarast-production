-- B-19: the notices already written move to their own type and open the
-- exact screen they are about, the same routes the server writes from now
-- on (src/shared-kernel/routes/notification-routes.ts). Their words stay as
-- they were written: a notice is a record of what was said.

-- The provider's account notices were GENERAL.
UPDATE "Notification"
SET "type" = CASE "data"->>'providerStatus'
    WHEN 'ACTIVE' THEN 'PROVIDER_APPROVED'::"NotificationType"
    WHEN 'NEEDS_CHANGES' THEN 'PROVIDER_NEEDS_CHANGES'::"NotificationType"
    WHEN 'REJECTED' THEN 'PROVIDER_REJECTED'::"NotificationType"
    WHEN 'SUSPENDED' THEN 'PROVIDER_SUSPENDED'::"NotificationType"
    WHEN 'PENDING' THEN 'PROVIDER_IN_REVIEW'::"NotificationType"
  END,
  "routeTarget" = '/provider/dashboard'
WHERE "type" = 'GENERAL'
  AND "entityType" = 'Provider'
  AND "data"->>'providerStatus' IN ('ACTIVE', 'NEEDS_CHANGES', 'REJECTED', 'SUSPENDED', 'PENDING');

UPDATE "Notification"
SET "type" = 'PROVIDER_CLAIM_DECIDED'
WHERE "type" = 'GENERAL'
  AND "entityType" IN ('Provider', 'ProviderClaimRequest')
  AND "data"->>'claimStatus' IN ('APPROVED', 'REJECTED');

UPDATE "Notification"
SET "type" = 'LISTING_PLAN_CHANGED',
  "routeTarget" = '/provider/dashboard?tab=profile'
WHERE "type" = 'GENERAL'
  AND "entityType" = 'ProviderFeaturedPeriod';

-- A booking request told the provider as BOOKING_UPDATED; its key names it.
UPDATE "Notification"
SET "type" = 'BOOKING_REQUESTED'
WHERE "type" = 'BOOKING_UPDATED'
  AND "data"->>'recipientAudience' = 'PROVIDER'
  AND "dedupeKey" LIKE '%:REQUESTED:%';

-- Each booking step names itself in its data (the phone told a request
-- from a cancellation by the title).
UPDATE "Notification"
SET "data" = jsonb_set("data", '{bookingEvent}', to_jsonb(substring("dedupeKey" from ':booking:[^:]+:([A-Z]+):')))
WHERE "type" IN ('BOOKING_UPDATED', 'BOOKING_REQUESTED')
  AND "entityType" = 'booking'
  AND jsonb_typeof("data") = 'object'
  AND substring("dedupeKey" from ':booking:[^:]+:([A-Z]+):') IN ('REQUESTED', 'CONFIRMED', 'DECLINED', 'CANCELLED');

-- The provider's request and booking notices pointed at the portal's home.
UPDATE "Notification"
SET "routeTarget" = '/provider/requests/' || ("data"->>'quoteRequestId')
WHERE "data"->>'recipientAudience' = 'PROVIDER'
  AND "routeTarget" = '/provider/dashboard'
  AND "entityType" IN ('quote_request', 'booking')
  AND COALESCE("data"->>'quoteRequestId', '') <> '';

-- The customer's request notices opened the providers' list first.
UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/providers/requests?quote=' || ("data"->>'quoteRequestId')
WHERE "routeTarget" LIKE '/providers?quoteId=%'
  AND "weddingPlanId" IS NOT NULL
  AND COALESCE("data"->>'quoteRequestId', '') <> '';

-- A task notice opens its task, a payment notice its agreement, an
-- over-budget notice its item, a guest's answer the guest, and joining a
-- plan the plan's home.
UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/tasks/' || "entityId"
WHERE "entityType" = 'task'
  AND "weddingPlanId" IS NOT NULL
  AND "entityId" IS NOT NULL;

UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/money/costs/' || ("data"->>'weddingCostId')
WHERE "entityType" = 'payment_schedule'
  AND "weddingPlanId" IS NOT NULL
  AND COALESCE("data"->>'weddingCostId', '') <> '';

UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/money/categories/' || "entityId"
WHERE "entityType" = 'budget_category'
  AND "weddingPlanId" IS NOT NULL
  AND "entityId" IS NOT NULL;

UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/guests/view/' || "entityId"
WHERE "entityType" = 'guest'
  AND "weddingPlanId" IS NOT NULL
  AND "entityId" IS NOT NULL;

UPDATE "Notification"
SET "routeTarget" = '/wedding-plans/' || "weddingPlanId" || '/dashboard'
WHERE "type" = 'SHARING_INVITATION'
  AND "entityType" = 'shared_member'
  AND "weddingPlanId" IS NOT NULL;
