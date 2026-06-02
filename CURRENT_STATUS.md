# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: WeddingPlan API slice merged into `main` and verified
- Current HEAD after merge: `80686216cb617b1d34d5db286448d70575bfef6e`
- Endpoints available: `POST /wedding-plans`, `GET /wedding-plans/my`, `GET /wedding-plans/:id`, `PATCH /wedding-plans/:id`, `PATCH /wedding-plans/:id/archive`
- All WeddingPlan endpoints require JWT authentication.
- Ownership protection uses authenticated user context and `OwnershipContextService` before returning or mutating a plan.
- WeddingPlan responses return plan fields only and do not include owner user objects.
- Budget, Expenses, Debts, Installments, Tasks, and Sharing are not implemented yet.
- Flutter/mobile work has not started.
- `backend/.env` remains local, ignored, and untracked; secrets were not committed.

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma validate`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3126`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3126`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3126`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3126`: PASS (27/27 checks)
- `passwordHash` not exposed in auth or WeddingPlan smoke responses: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: Budget + Expense backend slice.
- WeddingPlan API worktree may be removed after cleanup approval.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Complete: WeddingPlan Prisma model and migration
  7. Complete: WeddingPlan API slice
  8. Next: Budget + Expense backend slice
- Do not start Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile files until the active phase explicitly asks for Flutter work.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the User and WeddingPlan migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
