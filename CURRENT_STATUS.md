# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Sharing / Permissions backend slice merged into main and verified
- Current HEAD after merge: `22617cd47b7241de098528c3c61906dd13069670`
- Prisma additions: `SharedMemberRole`, `SharedMember`, `WeddingPlan.sharedMembers`, and `User.sharedWeddingPlans`
- Migration created and applied: `20260603212938_add_shared_members_permissions`
- Sharing endpoints available: `POST /wedding-plans/:weddingPlanId/shared-members`, `GET /wedding-plans/:weddingPlanId/shared-members`, `PATCH /shared-members/:id`, `DELETE /shared-members/:id`, and `GET /shared/wedding-plans`
- Shared members can read basic shared plan info and list tasks; task creation/update/delete requires `canManageTasks` or `MANAGER`.
- Timeline access is permission-aware: shared members can see tasks, while due debts/installments remain hidden unless debt permissions allow them.
- Financial endpoints remain owner-only in this slice; financial privacy remains protected by default.
- `smoke:sharing` passed from main.
- Flutter/mobile work has not started.
- `backend/.env` is untracked and gitignored; runtime verification used process environment variables only.

## Checks Passed From Main After Sharing / Permissions Merge

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3147`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (27/27 checks)
- `npm run smoke:budget-expense` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (48/48 checks)
- `npm run smoke:debt-installment` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (56/56 checks)
- `npm run smoke:task-timeline` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (43/43 checks)
- `npm run smoke:sharing` with `SMOKE_BASE_URL=http://127.0.0.1:3147`: PASS (57/57 checks)
- Migration SQL scope check: PASS
- passwordHash not exposed in auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, or Sharing smoke responses: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: cleanup of the completed Sharing / Permissions worktree, then Backend Regression + API Contract Freeze.
- Sharing / Permissions worktree still exists and may be removed after approval.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Complete: WeddingPlan Prisma model and migration
  7. Complete: WeddingPlan API slice
  8. Complete: Budget + Expense backend slice
  9. Complete: Debt + Installment backend slice
  10. Complete: Task + Timeline backend slice
  11. Complete: Sharing / Permissions backend slice
  12. Next: Backend Regression + API Contract Freeze
- Do not start Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile files until the active phase explicitly asks for Flutter work.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the current migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
