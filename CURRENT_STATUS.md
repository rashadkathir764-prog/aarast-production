# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: User model Prisma migration merged into `main` and verified
- Current HEAD: `f4500f33ab609ec2e72ef48ba3d178de30232d43`
- Branch merged: `phase/3-local-db-user-migration` → `main` (fast-forward)
- Migration name: `20260602181910_init_user_model`
- Migration path: `backend/prisma/migrations/20260602181910_init_user_model/migration.sql`
- Migration scope: `UserRole` enum, `UserStatus` enum, `User` table only
- Local development database: `aarast_dev` on `localhost:5433` (Docker container `aarast-db`)
- Prisma version: `6.19.3` (local install, not global)
- DATABASE_URL: configured locally in untracked `backend/.env` (not committed)

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `prisma format`: PASS
- `prisma validate`: PASS, schema is valid
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `prisma migrate dev --name init_user_model`: PASS (applied on `aarast_dev` in worktree)
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3115`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3115`: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: Auth foundation.
- Do not create Auth, Users API/module, or WeddingPlan before explicit approval.
- Auth foundation work must begin in a dedicated worktree on a new branch.
- Planned MVP User shape: `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`.
- Initial roles: `USER`, `ADMIN`, `PROVIDER`; `PROVIDER` is reserved for later provider flows and must not implement provider logic now.
- Initial statuses: `ACTIVE`, `DISABLED`.
- Approved next implementation order:
  1. ✅ Prisma + PostgreSQL foundation
  2. ✅ User model
  3. ✅ User migration
  4. Auth foundation
  5. Ownership context
  6. WeddingPlan module
- WeddingPlan implementation is blocked until Auth and ownership context readiness are handled.
- Do not use a mock-auth shortcut for WeddingPlan ownership.
- Do not create product modules until implementation is explicitly approved.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) — do not reset or modify
- `aarast_dev` database: fresh, created for this migration, contains only the User model migration
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Auth, Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
