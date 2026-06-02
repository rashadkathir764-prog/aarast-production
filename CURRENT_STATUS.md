# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast-worktrees\phase-3-wedding-plan`
- Current branch: `phase/3-wedding-plan`

## Last Completed Task

- Task: Phase 2 Health Smoke Baseline merged into `main`
- Last main commit hash: `78d4c2ae19e35ddabb620bd9a40edee9b8d93c9a`
- Merge result: fast-forward from `phase/2-smoke-baseline`
- Health smoke baseline status: complete

## Checks Passed From Main

- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3107`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3107`: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Phase 3 WeddingPlan worktree exists at `D:\projects\aarast-worktrees\phase-3-wedding-plan`.
- Current task is Phase 3 technical design alignment only.
- Clarify persistence and authenticated ownership prerequisites before WeddingPlan implementation.
- Do not create product modules until implementation is explicitly approved.

## Forbidden Scope Reminders

- Do not create Auth, Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile screens or folders.
- Do not run database migrations.
- Do not create Dockerfiles, docker-compose files, Dokploy config, or deployment scripts.
- Do not add payment, deposit, loan, credit, financing, AI, or internal chat logic.

## Known Issues

- Main has not yet merged the Phase 3 design-alignment branch.
- Phase 3 WeddingPlan implementation depends on persistence and authenticated user ownership readiness.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
