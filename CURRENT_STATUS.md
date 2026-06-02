# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: User migration blocked status merged into `main` and verified
- Current HEAD: `3933cb3b4a46dbf006caef5a6121faae9fbd47c2`
- Minimal User model design status: implemented in Prisma schema
- Prisma schema status: contains `UserRole`, `UserStatus`, and `User` only
- Prisma migrations status: blocked because local PostgreSQL/DATABASE_URL is not usable

## Checks Passed From Main

- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `npm install`: PASS, 0 vulnerabilities
- `npm run prisma:generate`: PASS
- `npx prisma validate`: PASS
- `npx prisma migrate dev --name init_user_model`: FAIL, blocked by unusable local PostgreSQL/DATABASE_URL
- `GET /health` on port `3115`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3115`: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step is configure local PostgreSQL/DATABASE_URL before retrying User migration.
- Auth foundation is not next until the User migration is created and verified.
- Do not create Auth, Users API/module, or WeddingPlan before the approved next phase.
- User migration worktree may be removed after verification.
- Planned MVP User shape: `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`.
- Initial roles: `USER`, `ADMIN`, `PROVIDER`; `PROVIDER` is reserved for later provider flows and must not implement provider logic now.
- Initial statuses: `ACTIVE`, `DISABLED`.
- Do not run migrations or add Prisma models until explicitly approved.
- Approved next implementation order:
  1. Prisma + PostgreSQL foundation
  2. User model
  3. Auth foundation
  4. Ownership context
  5. WeddingPlan module
- WeddingPlan implementation is blocked until persistence and authenticated ownership readiness are handled.
- Do not use a mock-auth shortcut for WeddingPlan ownership.
- Do not create product modules until implementation is explicitly approved.

## Forbidden Scope Reminders

- Do not create Auth, Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile screens or folders.
- Do not run database migrations.
- Do not create Dockerfiles, docker-compose files, Dokploy config, or deployment scripts.
- Do not add payment, deposit, loan, credit, financing, AI, or internal chat logic.

## Known Issues

- User Prisma model migration is still pending because local PostgreSQL/DATABASE_URL is not usable.
- No database migrations have been created or run.
- User Prisma model is implemented without relations, provider profile fields, refresh tokens, or WeddingPlan relation.
- Phase 3 WeddingPlan implementation still depends on User, Auth, and ownership context readiness.
- Production migration and Docker/Dokploy work are outside the current Prisma/PostgreSQL foundation task.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
