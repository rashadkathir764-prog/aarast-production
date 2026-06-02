# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast-worktrees\phase-3-ownership-context`
- Current branch: `phase/3-ownership-context`

## Last Completed Task

- Task: Ownership Context foundation implemented and verified in worktree
- Base main HEAD: `a2b24fd7b76e0b772cc2764ce74b170f42cf0806`
- Auth endpoints available: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- Ownership utilities added: `AuthenticatedUser` interface and generic `OwnershipContextService`.
- Ownership rule: future private resources should compare authenticated user id to resource `ownerUserId`.
- `backend/.env` was not created in this worktree; runtime verification used process environment variables only.
- No new Prisma models or migrations were created.

## Checks Passed From Ownership Worktree

- `npm install`: PASS, 0 vulnerabilities
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3118`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3118`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3118`: PASS (21/21 checks)
- `/auth/me` returns the authenticated user's id and role consistently: PASS
- `passwordHash` not exposed in any response: PASS (3 explicit checks)
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: pre-merge review for Ownership Context foundation; do not merge until approved.
- Ownership Context worktree must remain in place until review/merge/cleanup approval.
- Approved next implementation order:
  1. ✅ Prisma + PostgreSQL foundation
  2. ✅ User model
  3. ✅ User migration
  4. ✅ Auth foundation
  5. Ownership context
  6. WeddingPlan module
- WeddingPlan implementation is still blocked until Ownership Context is merged and verified on `main`.
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
