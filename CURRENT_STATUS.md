# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: WeddingPlan Prisma model and migration merged into `main` and verified
- Current HEAD after merge: `040dabcd7ef0dde3f89ca8849f3923b14b10422c`
- Migration created and applied: `20260602200934_add_wedding_plan_model`
- Migration path: `backend/prisma/migrations/20260602200934_add_wedding_plan_model/migration.sql`
- Prisma additions: `WeddingPlanStatus` enum, `WeddingPlan` model, `User.weddingPlans` relation, and `WeddingPlan.owner` relation
- WeddingPlan API/controller/service/module are not implemented yet
- Budget, Expenses, Debts, Installments, Tasks, and Sharing are not implemented yet
- `backend/.env` remains local, ignored, and untracked; secrets were not committed

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS after providing `DATABASE_URL` through process environment
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3123`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3123`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3123`: PASS (21/21 checks)
- Migration SQL scope check: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: WeddingPlan API slice.
- WeddingPlan model worktree may be removed after cleanup approval.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Complete: WeddingPlan Prisma model and migration
  7. Next: WeddingPlan API planning/implementation
- Do not start Budget, Expenses, Debts, Installments, Tasks, or Sharing before the WeddingPlan module.
- Do not create product modules until implementation is explicitly approved.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the User and WeddingPlan migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create WeddingPlan controller, service, module, or API endpoints until explicitly approved.
- Do not create Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile screens or folders.
- Do not create Dockerfiles, docker-compose files, Dokploy config, or deployment scripts.
- Do not run `prisma db push`.
- Do not add payment, deposit, loan, credit, financing, AI, or internal chat logic.
- Do not reset or drop the `aarast` database.

## Known Issues

- `aarast` database has pre-existing full schema from prior migrations not tracked in this repo; it must not be reset.
- `backend/.env` must be configured locally each time (gitignored); the `DATABASE_URL` must point to `aarast_dev` on port `5433`.
- Production migration and Docker/Dokploy work are outside the current task scope.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
