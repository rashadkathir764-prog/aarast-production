# Backend

Snapshot date: 2026-08-31

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
  and dependency direction.
- `docs/backend/API_CONTRACT.md` - route-level API contract.
- `docs/backend/DATABASE.md` - data-model intent and privacy rules.

## Modular Monolith Boundary

R1 implements the Backend platform/shared-kernel target layout locally.
Infrastructure is under `src/platform/`; Money, phone, privacy/application
identity, and time helpers are under `src/shared-kernel/`; the pure Admin
permission matrix is under `src/modules/backoffice/domain/`; and the former
`src/common`, `src/prisma`, `src/outbox`, and root health paths are absent.
Cross-context Backend code consumes only the owner's public contract, except
for the exact reviewed pre-port Admin permission contract used only by legacy
`auth/` and `catalogs/`. The Nest class/import graph remains acyclic, and no new
`forwardRef()` or `@Global()` use is allowed.

R3 closed all six frozen platform-to-business dependencies and all retired
provider edges. R6 later removed Collaboration's concrete OTP transport
dependency, and R8 removed the final two project-owned globals.

Physical ownership covers Prisma root delegates, relation traversal, nested
writes, and raw-SQL tables. `WeddingPlan` is owned by planning. R4 retired
Finance's former direct `WeddingPlan.estimatedBudget` write: Finance now calls
the singleton Planning public write port with its exact caller-owned transaction,
and only Planning performs the delegate update. The removed debt is not an
exception.

R5 moved all 44 Identity source files one-to-one from `auth`, `users`, `me`,
and `contexts` into `src/modules/identity`; the four old roots are absent and
there is no compatibility facade. Public/internal/api ownership, route and Nest
provider identity, auth/OTP/session/context behavior, and all error contracts
are preserved. The dependency baseline is exactly 31 records after retiring
the 58 authorized relocation debts, while ownership remains 385 records / 781
occurrences. Prisma remains 6.19.3 with the separately verified exact
`deepmerge-ts` 8.0.1 security override.

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

`npm run architecture` is the strict modular-monolith gate: it rejects any
dependency violation and any foreign Prisma access (root delegates, relation
traversal, nested writes, raw-SQL tables, and argument shapes it cannot
prove), plus ports/global/Nest-graph violations. Since the 2026-09-24 closure
no dependency or ownership baseline exists; the closed phase gates fail if
one reappears. R1 keeps 52 models and 76 migrations and changes
no API route or database contract.

R7 physically owns Collaboration under `src/modules/collaboration`: all 18
approved API/DTO/internal/public files are at their final paths, while the old
`sharing` and `contribution-history` roots are absent. Cross-context consumers
use the Collaboration boundary; strict reports zero legacy sources, 18 final
targets, 22 known dependency records, and unchanged ownership at 385/781. The
public contribution-snapshot builder keeps exactly four runtime exports.

R8 removed `@Global()` from `PrismaModule` and
`ConversationRealtimeModule`. Strict closure is now project globals 0, Prisma
21/21 with missing 0, and Realtime 2. `ApplicationOutboxRuntimeModule` imports
`PrismaModule` explicitly; singleton provider identity and the Realtime
`useExisting` aliases remain exact. The only global runtime behavior is
dependency-owned and frozen to `@nestjs/schedule@6.1.3` and
`@nestjs/throttler@6.5.0` through their existing root factories. Dependency
evidence remains 22 and ownership remains 385/781.

R10 reorganized Admin Web only. Its Task 9 cumulative proof reran Backend
architecture/check/build, 1,351 passing tests with zero failures and one
intentional skip, both zero-finding audits, the Prisma security gate,
52-model/41-enum/76-migration equivalence, 12 focused smokes, and the aggregate
smoke suite. No Backend product source, schema, migration, seed, dependency, or
lockfile changed. The 22 dependency records and 385 records / 781 occurrences
of physical-ownership debt remain explicit future work; R10 does not convert
them into exemptions or claim the Backend target complete.

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

## R10 Local Wave Stop Boundary

The Backend state remains behavior-identical through the locally completed R10
Admin phase from immutable R9 closeout
`e560e5784278907dd6bf565327c3abfa0c9b8cab`. No commit, push, merge,
deployment, production mutation, or remote CI is claimed. Removing the
remaining 22 and 385/781 debt requires a separately approved future phase.
