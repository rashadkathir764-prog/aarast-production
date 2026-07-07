# Current Status

Snapshot date: 2026-07-08

This is the compact project status source. Current code, schema, module imports,
and runtime checks override historical completion reports.

## Repository

- Root: `D:\projects\aarast`.
- The 2026-07 documentation consolidation is active.
- The current working tree contains ongoing mobile, backend, migration, and
  documentation work. Do not treat uncommitted files as release-ready solely
  because they exist.

## Current Stack

- Backend: NestJS 11, Prisma 6, PostgreSQL, 15-minute access JWTs, and
  rotating 30-day refresh sessions.
- Scale/observability: optional Redis (shared throttling + Socket.IO
  adapter, fail-open when Redis drops), request-id correlation,
  token-guarded Prometheus `/metrics` with business counters, JSON
  production logs, optional Sentry via `SENTRY_DSN`, graceful shutdown
  draining, nightly pg_dump sidecar in the Dokploy compose, and a
  deployable Prometheus/Grafana/Alertmanager stack under
  `deploy/monitoring/`.
- Financial integrity: database CHECK constraints (non-negative amounts,
  paid ≤ total, positive payment records) enforce money invariants below
  the application layer.
- Quality gates in CI: backend unit + e2e smoke, admin-web Vitest,
  mobile analyze + tests, gitleaks secret scan, and `npm audit` gate.
- Mobile: Flutter, Provider, go_router, dio, sqflite, and secure token storage.
- Admin web: React 18, Vite, and TypeScript strict mode.
- Local runtime: Docker Compose backend/database.
- Production path: Dokploy Compose under `deploy/dokploy/`.

## Active Implemented Scope

- Authentication, OTP helpers, profile, and settings.
- Wedding plans, onboarding, dashboard summaries, money, financial
  commitments, payment records, tasks, guests, sharing, permissions,
  notifications, and offline/cache support.
- Provider catalog, favorites, reviews, quote requests/offers, provider
  dashboard operations, and admin catalog/provider operations.
- Quote-scoped conversations, authenticated Socket.IO delivery, unread/read,
  mute, block, report, signed media uploads, and admin report moderation.
- Rotating refresh sessions with single-session logout, logout-all, secure
  mobile storage, and one guarded retry after `401`.
- Mobile and admin surfaces listed by the generated route references.

## Approved Work In Flight

The five-tab provider portal, conversation screens, media integration, and
refresh lifecycle are integrated in source. Release readiness still requires
environment-backed smoke coverage for PostgreSQL, object storage, Socket.IO,
and real mobile reconnect/session behavior.

## Verification Status

Historical reports recorded passing backend, mobile, and admin checks before
the current in-flight changes. Those results are not evidence for the present
working tree. Rerun the checks in `docs/qa/README.md` before any readiness or
release claim.

## Known Risks

- Refresh and conversation behavior must be smoke-tested against the same
  deployed backend build before release.
- Signed media requires valid S3-compatible configuration; credentials remain
  server-side.
- Provider quote permissions require explicit ownership checks before broader
  shared-plan decisions.
- Financial data remains private by default, including financial commitments,
  payment records, expenses, debts, and installments.
- Existing unrelated working-tree changes must be preserved.

## Documentation State

- Active Markdown files: 28, listed in `docs/README.md`.
- Historical archive files: 103 under
  `docs/archive/2026-07-docs-consolidation/`.
- `scripts/docs-sync.mjs` generates route, model, and package-script tables.
- `scripts/docs-verify.mjs` checks active documentation against source.
