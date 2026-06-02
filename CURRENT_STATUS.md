# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Phase 2 Health Smoke Baseline merged into `main`
- Last commit hash: `1721db01999f01f17cdd8e425719f3bdf93096b4`
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

- Remove the completed Phase 2 worktree after approval.
- Plan the next phase after worktree cleanup.
- Do not create product modules until the next phase is explicitly approved.

## Forbidden Scope Reminders

- Do not create Auth, Cities, Categories, Services, Bookings, Favorites, Reviews, Provider Profile, WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile screens or folders.
- Do not run database migrations.
- Do not create Dockerfiles, docker-compose files, Dokploy config, or deployment scripts.
- Do not add payment, deposit, loan, credit, financing, AI, or internal chat logic.

## Known Issues

- `phase/2-smoke-baseline` worktree still exists at `D:\projects\aarast-worktrees\phase-2-smoke-baseline` and may be removed later after approval.
- `backend/node_modules/` is generated and ignored.
- `backend/dist/` is generated and ignored.
