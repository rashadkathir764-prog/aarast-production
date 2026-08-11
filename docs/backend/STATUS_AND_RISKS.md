# Backend Status And Risks

Snapshot date: 2026-08-11

Snapshot source: the checked-out canonical `main` content after the 2026-08-11
production deployment and documentation closure. Resolve its immutable
revision with `git rev-parse HEAD`.

## Implemented Areas

- Health, 15-minute access JWTs, and rotating 30-day refresh sessions.
- Verified-phone registration, atomic OTP consumption, production Meta
  WhatsApp OTP delivery, profile, settings, user lookup, and avatar handling.
- WeddingPlan, onboarding, dashboard summary, money, tasks, timeline, guests,
  sharing, permissions, and notifications.
- The money contract is consolidated before launch around one optional
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
  rotating server sessions, every access JWT has an explicit signed
  application/admin scope, product and Chat routes reject admin scope, refresh
  material is HttpOnly, and logout revokes active admin access immediately.
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
- Versioned reference catalogs with immutable revisions, explicit publish,
  historical rollback, audience targeting, and soft-disable. Public bootstrap
  returns one stable version and omits duplicate payload for a matching client
  version.
- Typed Yemen geography with Governorate, District, and district-bound
  AdministrativeLocality levels for area, isolation, neighborhood, and zone.
  Parentage is same-district and cycle-safe; disable preserves historical text.
- Contributor history, membership-bound plan leaving, recoverable anonymous
  account-deletion receipts, and device-scoped Firebase push installations are
  present in the current schema and guarded source/tests.
- Notification settings report Push truthfully: `push.supported` follows the
  runtime-enabled `FirebasePushClient`, while `push.enabled` follows the
  account's registered enabled device installation. Expected `GET /ready`
  `503` probe failures are excluded from error logging and Sentry.

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
Production revision `900897a90e8b030c7c3ddfdc55cc2669b64f2e87` now runs the
matching schema and configuration. The signed physical-device reconnect/logout,
OTP, and Push acceptance passes remain open against that deployed environment.

The Backend was rebuilt locally for this snapshot: `/live=200` and
`/ready=200`, with database, Redis, and media all `up`. This is local runtime
evidence. Separately, the deployed Backend passed external `/live` and `/ready`,
all 76 migrations, the exact-image backup/restore rehearsal, and the live
contributor-history relational postconditions. Those production facts do not
replace physical-device or external-channel acceptance.

## Production Receipt

- Application revision:
  `900897a90e8b030c7c3ddfdc55cc2669b64f2e87`.
- Backend image:
  `sha256:313e77263d5ed61f1a67f78381e2389a92f61ff1b45eeb33df3822b2ec9dfc1e`.
- Container health: healthy, zero restarts, no OOM termination at acceptance.
- Database: all 76 migrations applied; 15 live plans and 15 linked history
  scopes; zero missing scopes, lifecycle mismatches, missing active tenures, or
  unfinished migrations.
- Fresh backup SHA-256:
  `b86d11263262f6e4a709d3638c250fa59ac88e7dbce4aff0841d0a91122dbc4b`;
  checksum, catalog, isolated restore, second migration pass, schema, and
  relational postconditions PASS against the exact image.

The verified registration slice also requires the current OTP migration and
`smoke:auth-verification` against the matching backend image. Live WhatsApp
delivery cannot be claimed until the Meta business account and authentication
template are approved and a real device receives a code.

## Current Risks

- Rebuild/restart the exact Docker image and rerun all smoke groups after any
  backend, migration, or media-policy change before claiming runtime readiness.
- Production currently selects the temporary OpenWA OTP channel, but real-device
  delivery/verification, privacy-history, rotation, recovery, and stability
  acceptance is not recorded as passed. Freeze wider OTP/admin-login rollout
  until that gate closes or switch to an approved disabled/Meta channel.
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
- Rebuild and repeat `/live` and `/ready` after any backend, dependency, or
  media-policy change. The current local ready result does not replace
  the recorded production receipt, and neither result replaces device or
  external-service acceptance evidence.

## Verification

For backend code changes:

```powershell
cd D:\projects\aarast\backend
npm run check
npm run build
npm test
npm run smoke:all
npm run smoke:reference-catalog
```

Smoke checks require the matching local runtime and environment. Report them as
BLOCKED rather than PASS when dependencies are unavailable.

Latest local source evidence on 2026-08-11: `npm run check`, guarded unit tests,
build, Prisma validation, Phase 0 source guard, managed reference-catalog smoke,
and managed Admin runtime smoke PASS. Both managed smokes applied all 76
migrations to disposable databases and cleaned their owned resources. The
current local rebuilt Backend reports `/live=200` and `/ready=200`, with
database, Redis, and media `up`. The independent production receipt above
records the actual publish and recovery evidence. The Backend production
dependency audit reports zero vulnerabilities.
