# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Persistence/Auth readiness planning merged into `main`
- Current HEAD: `e4cc6bea81186b455069269b67da49525a7e72fb`
- Merge result: fast-forward from `phase/3-persistence-auth-readiness`
- Readiness planning status: complete

## Checks Passed From Main

- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3107`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3107`: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Phase 3 Persistence/Auth readiness worktree still exists at `D:\projects\aarast-worktrees\phase-3-persistence-auth-readiness`.
- Next pending step is removing the readiness worktree after approval.
- After cleanup, create a new worktree for Prisma/PostgreSQL foundation.
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

- Readiness worktree still exists and may be removed after approval.
- Phase 3 WeddingPlan implementation depends on persistence and authenticated user ownership readiness.
- Production migration and Docker/Dokploy work are outside the current readiness planning task.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
