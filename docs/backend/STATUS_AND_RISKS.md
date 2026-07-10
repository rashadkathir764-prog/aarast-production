# Backend Status And Risks

Snapshot date: 2026-07-10

## Implemented Areas

- Health, 15-minute access JWTs, and rotating 30-day refresh sessions.
- Verified-phone registration, atomic OTP consumption, production Meta
  WhatsApp OTP delivery, profile, settings, user lookup, and avatar handling.
- WeddingPlan, onboarding, dashboard summary, money, tasks, timeline, guests,
  sharing, permissions, and notifications.
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
- Quote-scoped conversations, Socket.IO delivery, message attachments,
  reporting/blocking/muting/read state, and signed media uploads.
- Admin conversation-report list and status moderation without message-body
  exposure.

## Integrated, Pending Runtime Smoke

Conversation/media, refresh sessions, and admin report moderation are wired
through the active schema, modules, routes, clients, and source tests. They are
not production-ready until migrations, PostgreSQL, S3-compatible storage,
Socket.IO, and reconnect/logout behavior pass environment-backed smoke.

The verified registration slice also requires the current OTP migration and
`smoke:auth-verification` against the matching backend image. Live WhatsApp
delivery cannot be claimed until the Meta business account and authentication
template are approved and a real device receives a code.

## Current Risks

- Rebuild/restart local Docker runtime and rerun smoke before claiming runtime
  readiness.
- Production admin login remains unavailable until the Meta WhatsApp OTP
  channel is approved and configured; development echo codes are forbidden in
  production.
- Tighten provider quote permissions before broad shared-plan quote decisions.
- Keep JWT and storage secrets environment-only.
- Recheck guest read privacy decisions before broad release.
- Keep server-side phone normalization aligned with mobile behavior.
- Cascade restrictions protect financial children; future plan deletion must
  preserve that integrity.

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
