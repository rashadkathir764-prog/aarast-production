# Backend Phase 9 - Internal Notifications API

Date: 2026-06-19
Status: Implemented

## Scope

Phase 9 completes internal notification APIs for the mobile UX:

- `/api/v1` notification aliases
- notification get-by-id
- unread counts
- mark one notification read
- mark all notifications read
- plan-scoped notification filters
- internal notification generation for invite acceptance and quote offers

No push notifications, FCM, SMS sending, email sending, Flutter UI, admin-web code, payments, deposits, bookings, AI, maps, or production configuration was changed.

## Migration

Created:

- `backend/prisma/migrations/20260619131740_add_internal_notification_types/migration.sql`

Schema additions:

- `NotificationType.SHARING_INVITE_ACCEPTED`
- `NotificationType.QUOTE_OFFER_RECEIVED`

The existing `Notification` model is reused.

## Endpoints

New `/api/v1` compatibility endpoints:

- `GET /api/v1/notifications`
- `GET /api/v1/notifications/unread-count`
- `GET /api/v1/notifications/:id`
- `PATCH /api/v1/notifications/:id/read`
- `PATCH /api/v1/notifications/read-all`

Existing unprefixed endpoints remain available:

- `GET /notifications`
- `GET /notifications/unread-count`
- `GET /notifications/:id`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `DELETE /notifications/:id`

## Generation Rules

Internal notifications are created for:

- invite received, using existing `SHARING_INVITATION`
- invite accepted, using `SHARING_INVITE_ACCEPTED`
- quote offer received, using `QUOTE_OFFER_RECEIVED`
- task due soon and overdue, using existing due-notification generation
- installment due soon and overdue when the user can read debts

All notification payloads use safe IDs and do not include sensitive user fields or payment data.

## Privacy

- JWT is required for `/api/v1/notifications` endpoints.
- Users only read their own notifications.
- Plan-scoped filtering still requires accessible plan context through existing notification logic.
- Other users receive `404` for notification IDs they do not own.

## Smoke Coverage

Added:

- `npm run smoke:notifications-apis`

Included in:

- `npm run smoke:all`

Covered cases:

- `/api/v1` list
- unread count
- get-by-id
- mark read
- read all
- cannot read another user's notification
- unauthenticated access blocked
- invite notification created
- invite accepted notification created
- quote offer received notification created
- plan-scoped notification filtering

## Verification

Expected commands for this phase:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_internal_notification_types`
- `npm.cmd run check`
- `npm.cmd run smoke:notifications-apis`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`
