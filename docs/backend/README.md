# Backend

Snapshot date: 2026-08-11

The backend is a NestJS + Prisma + PostgreSQL API. It is the source of truth for
account-backed wedding plans, financial records, permissions, provider
references, quote leads, provider dashboard behavior, admin operations, and
notifications, rotating refresh sessions, unified provider conversations,
Socket.IO delivery, fully decoded/sanitized signed provider/chat media,
pepper-keyed durable login throttling, and report moderation.
It also owns versioned published reference catalogs and the typed Yemen
governorate → district → locality hierarchy consumed by Admin and Mobile.

## Active Backend Docs

- `docs/backend/API_CONTRACT.md` - route-level API contract.
- `docs/backend/DATABASE.md` - data-model intent and privacy rules.
- `docs/backend/STATUS_AND_RISKS.md` - current backend status and known risks.

## Commands

From `backend/`:

```powershell
npm run check
npm run build
npm test
npm run smoke:all
npx prisma validate
```

Database-writing smoke and load commands are managed by
`scripts/smoke/run-isolated-smoke.js`. The runner uses the active local Docker
Compose PostgreSQL, Redis, and MinIO services, but creates a per-run database,
MinIO bucket, Redis namespace, and backend port. It applies committed migrations
with `prisma migrate deploy` and removes only those exact run-owned resources in
`finally`, including after a failed check. The supported `npm run smoke:*` and
`npm run load:test` commands must be used instead of invoking fixture scripts
directly; they refuse the permanent `aarast` and `aarast_dev` databases.

## Boundaries

Backend provider and quote flows are planning/reference and lead workflows only.
Quote conversations are limited to the requester and provider account on a real
quote request. They must not create payments, deposits, confirmed bookings,
loans, credit, financing, AI, open messaging, or marketplace checkout behavior.
