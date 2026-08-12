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

- `ARCHITECTURE.md` - canonical modular-monolith boundaries, module ownership,
  dependency direction, and phase gates.
- `docs/backend/API_CONTRACT.md` - route-level API contract.
- `docs/backend/DATABASE.md` - data-model intent and privacy rules.
- `docs/backend/STATUS_AND_RISKS.md` - current backend status and known risks.

## Modular Monolith Boundary

R0 documents the target architecture and moves no Backend application source.
During migration, each context is the union of its legacy roots and
`src/modules/<context>`. Cross-context Backend code consumes only the owner's
public contract; it never imports another context's full or internal module.
The Nest class/import graph remains acyclic, and no new `forwardRef()` or
`@Global()` use is allowed.

Physical ownership covers Prisma root delegates, relation traversal, nested
writes, and raw-SQL tables. `WeddingPlan` is owned by planning. Finance's
current direct write to `WeddingPlan.estimatedBudget` is temporary R0 baseline
debt that R4 replaces with a planning public write port accepting the caller's
explicit transaction client; it is not a permanent exception.

## Commands

From `backend/`:

```powershell
npm run architecture
npm run check
npm run build
npm test
npm run smoke:all
npx prisma validate
```

`npm run architecture` is the incremental modular-monolith gate: it rejects a
new dependency edge/cycle, new or increased foreign Prisma ownership debt, and
new ports/global/Nest-graph violations while allowing the committed R0 debt
baselines only to shrink.

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
