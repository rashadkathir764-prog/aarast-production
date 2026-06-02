# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Ownership Context foundation merged into `main` and verified
- Current HEAD after merge: `f5fba4aefd1dd0c68ebef0f7c24dea378ac557b2`
- Auth endpoints available: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- Ownership utilities available: `AuthenticatedUser`, `OwnershipContextService`, `isOwner()`, and `assertOwner()`
- Ownership rule: future private resources should compare authenticated user id to resource `ownerUserId`
- `backend/.env` remains local, ignored, and untracked; secrets were not committed
- No new Prisma models or migrations were created for Ownership Context

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3120`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3120`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3120`: PASS (21/21 checks)
- `/auth/me` returns the authenticated user's id and role consistently: PASS
- `passwordHash` not exposed in any response: PASS (3 explicit checks)
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: WeddingPlan backend planning/implementation.
- Ownership Context worktree may be removed after cleanup approval.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Next: WeddingPlan module
- Do not start Budget, Expenses, Debts, Installments, Tasks, or Sharing before the WeddingPlan module.
- Do not use a mock-auth shortcut for WeddingPlan ownership.
- Do not create product modules until implementation is explicitly approved.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: fresh, created for the User model migration, contains only the User model migration
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile screens or folders.
- Do not create Dockerfiles, docker-compose files, Dokploy config, or deployment scripts.
- Do not add payment, deposit, loan, credit, financing, AI, or internal chat logic.
- Do not reset or drop the `aarast` database.

## Known Issues

- `aarast` database has pre-existing full schema from prior migrations not tracked in this repo; it must not be reset.
- `backend/.env` must be configured locally each time (gitignored); the `DATABASE_URL` must point to `aarast_dev` on port `5433`.
- Production migration and Docker/Dokploy work are outside the current task scope.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
