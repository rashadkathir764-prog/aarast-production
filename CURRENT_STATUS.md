# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast-worktrees\phase-3-task-timeline-backend`
- Current branch: `phase/3-task-timeline-backend`

## Last Completed Task

- Task: Task + Timeline backend slice implemented and verified in worktree
- Base main HEAD: `6072ddb6f0c795448d9f9c3cced4166fe38e548f`
- Prisma additions: `WeddingTaskStatus`, `WeddingTaskPriority`, `WeddingTask`, and WeddingPlan relation for tasks
- Migration created and applied: `20260603205638_add_task_timeline_model`
- Task endpoints available: `POST /wedding-plans/:weddingPlanId/tasks`, `GET /wedding-plans/:weddingPlanId/tasks`, `PATCH /tasks/:id`, `DELETE /tasks/:id`
- Timeline endpoint available: `GET /wedding-plans/:weddingPlanId/timeline`
- All Task and Timeline endpoints require JWT authentication and owner access to the parent WeddingPlan.
- `smoke:task-timeline` passed from the worktree.
- Sharing is not implemented yet.
- Flutter/mobile work has not started.
- `backend/.env` is untracked and gitignored; runtime verification used process environment variables only.

## Checks Passed From Task + Timeline Worktree

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS
- `npx prisma migrate dev --name add_task_timeline_model`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3140`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS (27/27 checks)
- `npm run smoke:budget-expense` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS (48/48 checks)
- `npm run smoke:debt-installment` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS (56/56 checks)
- `npm run smoke:task-timeline` with `SMOKE_BASE_URL=http://127.0.0.1:3140`: PASS (43/43 checks)
- Migration SQL scope check: PASS
- passwordHash not exposed in auth, WeddingPlan, Budget + Expense, Debt + Installment, or Task + Timeline smoke responses: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step after merge: Sharing / Permissions backend slice.
- Task + Timeline worktree must remain in place until review/merge/cleanup approval.
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
  10. Current: Task + Timeline backend slice
  11. Next after merge approval: Sharing / Permissions backend slice
- Do not start Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile files until the active phase explicitly asks for Flutter work.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the current migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
