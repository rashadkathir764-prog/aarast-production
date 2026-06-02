# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Auth Foundation merged into `main` and verified
- Current HEAD: `800058fedc68cf8e32c17bd8e10c50ae67f84a6e`
- Auth endpoints available: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- Dependencies added: `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcryptjs`, `class-validator`, `class-transformer`, plus dev types
- `backend/.env` created locally (untracked, gitignored, not committed); `JWT_SECRET` not committed
- No new Prisma migrations needed; existing User model is sufficient

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3117`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3117`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3117`: PASS (15/15 checks)
- `passwordHash` not exposed in any response: PASS (3 explicit checks)
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: Ownership Context, not WeddingPlan yet.
- Auth Foundation worktree may be removed after verification.
- Approved next implementation order:
  1. ✅ Prisma + PostgreSQL foundation
  2. ✅ User model
  3. ✅ User migration
  4. ✅ Auth foundation
  5. Ownership context
  6. WeddingPlan module
- WeddingPlan implementation is blocked until ownership context readiness is handled.
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
