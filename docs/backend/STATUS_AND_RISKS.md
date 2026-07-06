# Backend Status And Risks

Snapshot date: 2026-07-06

## Implemented Areas

- Health, 15-minute access JWTs, and rotating 30-day refresh sessions.
- Profile, OTP helpers, settings, user lookup, and avatar handling.
- WeddingPlan, onboarding, dashboard summary, money, tasks, timeline, guests,
  sharing, permissions, and notifications.
- Provider catalog, city/category references, favorites, reviews, quote
  requests/offers, and provider dashboard operations.
- Admin dashboard, provider approvals, catalog, users, services, reviews,
  notifications, and operational reports.
- Idempotency handling for supported mutating endpoints.
- Quote-scoped conversations, Socket.IO delivery, message attachments,
  reporting/blocking/muting/read state, and signed media uploads.
- Admin conversation-report list and status moderation without message-body
  exposure.

## Integrated, Pending Runtime Smoke

Conversation/media, refresh sessions, and admin report moderation are wired
through the active schema, modules, routes, clients, and source tests. They are
not production-ready until migrations, PostgreSQL, S3-compatible storage,
Socket.IO, and reconnect/logout behavior pass environment-backed smoke.

## Current Risks

- Rebuild/restart local Docker runtime and rerun smoke before claiming runtime
  readiness.
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
