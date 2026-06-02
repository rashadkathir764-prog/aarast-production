# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast-worktrees\phase-3-user-model`
- Current branch: `phase/3-user-model`

## Last Completed Task

- Task: Prisma/PostgreSQL foundation merged into `main` and verified
- Current HEAD: `a0d9b4b8b9f7682b00e014113dce7dce047c11c9`
- Prisma/PostgreSQL foundation status: merged and verified from main
- Prisma schema status: empty PostgreSQL datasource with no models
- Prisma migrations status: no migrations exist

## Checks Passed From Main

- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `npm install`: PASS, 0 vulnerabilities
- `npm run prisma:generate`: PASS
- `GET /health` on port `3110`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3110`: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Phase 3 User Model worktree exists at `D:\projects\aarast-worktrees\phase-3-user-model`.
- Current task is User model design alignment only.
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

- Prisma schema intentionally has no models yet.
- User model design is not yet implemented in Prisma.
- No database migrations have been created or run.
- Phase 3 WeddingPlan implementation still depends on User, Auth, and ownership context readiness.
- Production migration and Docker/Dokploy work are outside the current Prisma/PostgreSQL foundation task.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
