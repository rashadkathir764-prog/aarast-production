# Backend Status And Risks

Snapshot date: 2026-07-14

## Implemented Areas

- Health, 15-minute access JWTs, and rotating 30-day refresh sessions.
- Verified-phone registration, atomic OTP consumption, production Meta
  WhatsApp OTP delivery, profile, settings, user lookup, and avatar handling.
- WeddingPlan, onboarding, dashboard summary, money, tasks, timeline, guests,
  sharing, permissions, and notifications.
- The money contract is being consolidated before launch to one optional
  general budget, `BudgetCategory`, `WeddingCost`, append-only `CostPayment`,
  and dated `PaymentSchedule`. There are no compatibility endpoints for the
  removed finance models.
- Sharing invitations use hashed tokens, verified phone identity, atomic
  accept/decline claims, and a permission ceiling for delegated inviters.
- Provider catalog, city/category references, favorites, reviews, quote
  requests/offers, and provider dashboard operations.
- Admin dashboard, provider approvals, catalog, users, services, reviews,
  notifications, and operational reports.
- Admin list APIs return bounded page metadata, and all seven corresponding web
  surfaces now navigate beyond the first page instead of truncating results.
- PostgreSQL-backed idempotency for authenticated mutations, bound to method,
  concrete target, and canonical body. Concurrent identical retries execute
  once; mismatched key reuse is rejected, responses expire, and one replica
  performs hourly cleanup under an advisory lock.
- Admin browser sessions require password + phone OTP; admin JWTs are bound to
  rotating server sessions, refresh material is HttpOnly, and logout revokes
  active access immediately.
- One conversation per plan/provider or account/provider context, Socket.IO
  delivery/recovery, quote/offer system events, message attachments,
  reporting/side-level blocking/personal mute/read state, and signed media
  uploads.
- Media verification fully decodes and sanitizes JPEG/PNG/WebP objects before
  conditional replacement; signed creation cannot overwrite an existing key.
- Every presign has a durable account-owned upload ticket, rolling daily
  count/byte quota, explicit verification/consumption state, and bounded
  advisory-lock cleanup for abandoned objects. Account deletion takes the same
  account lock and atomically marks every owned ticket `DELETE_PENDING`; the
  deletion commits only when this durable scheduling succeeds. Tickets survive
  the User row and the media worker deletes objects with retries before marking
  them `DELETED`.
- Password login throttling uses a pepper-keyed HMAC identifier in PostgreSQL,
  fails closed without the production pepper, and cleans expired/inactive rows
  hourly under one transaction-level advisory lock.
- Transactional outbox workers retain exhausted `FAILED` dead letters. A
  separate cross-replica cleanup deletes only `PROCESSED` receipts older than
  seven days every six hours, while account deletion removes its related
  notification/conversation events atomically.
- Admin conversation-report list and status moderation without message-body
  exposure.

## Integrated Runtime Contract

The finance runtime is acceptable only when both fresh and upgraded databases
contain the canonical cost tables and no live legacy finance tables, routes, or
queue entity types. A cost must belong to a category and may reference either a
provider or an external party. Payments and schedules inherit that context from
the cost. Schedule dates are required; schedules do not affect totals until a
payment is recorded.

Conversation/media, refresh sessions, and admin report moderation are wired
through the active schema, modules, routes, clients, and source tests. The local
Compose runtime includes PostgreSQL, Redis, and MinIO-compatible storage so
real upload/verify/private-chat and Socket.IO paths are covered by HTTP smoke.
Production still requires the matching migrations and configuration plus a
signed physical-device reconnect/logout pass against the deployed environment.

The verified registration slice also requires the current OTP migration and
`smoke:auth-verification` against the matching backend image. Live WhatsApp
delivery cannot be claimed until the Meta business account and authentication
template are approved and a real device receives a code.

## Current Risks

- Rebuild/restart the exact Docker image and rerun all smoke groups after any
  backend, migration, or media-policy change before claiming runtime readiness.
- Production admin login remains unavailable until the Meta WhatsApp OTP
  channel is approved and configured; development echo codes are forbidden in
  production.
- Tighten provider quote permissions before broad shared-plan quote decisions.
- Keep JWT and storage secrets environment-only.
- Recheck guest read privacy decisions before broad release.
- Keep server-side phone normalization aligned with mobile behavior.
- Cascade restrictions protect financial children; future plan deletion must
  preserve that integrity.
- The prelaunch finance cleanup is destructive by design. Do not deploy a
  partially mixed schema or restore removed finance controllers from build
  output. Verify old endpoints return `404`, not `401`, and inspect the live
  database for absent old tables before accepting the image.
- Cost/payment mutations require concurrency and idempotency smoke. The release
  gate must prove that concurrent payment, schedule-payment, and reversal
  requests cannot overpay a cost or duplicate ledger rows.

## Verification

For backend code changes:

```powershell
cd D:\projects\aarast\backend
npm run check
npm run build
npm test
npm run smoke:all
```

Smoke checks require the matching local runtime and environment. Report them as
BLOCKED rather than PASS when dependencies are unavailable.
