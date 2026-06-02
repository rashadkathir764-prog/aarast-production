# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast-worktrees\phase-3-debt-installment-backend`
- Current branch: `phase/3-debt-installment-backend`

## Last Completed Task

- Task: Debt + Installment backend slice implemented and verified in worktree
- Base main HEAD: `82190c4e07c8c80a037aa6cb572edac763060e2b`
- Prisma additions: `DebtStatus`, `InstallmentStatus`, `Debt`, `Installment`, and WeddingPlan relation for debts
- Migration created and applied: `20260602215807_add_debt_installment_models`
- Debt endpoints available: `POST /wedding-plans/:weddingPlanId/debts`, `GET /wedding-plans/:weddingPlanId/debts`, `GET /wedding-plans/:weddingPlanId/debts/summary`, `PATCH /debts/:id`, `DELETE /debts/:id`
- Installment endpoints available: `POST /debts/:debtId/installments`, `GET /debts/:debtId/installments`, `GET /wedding-plans/:weddingPlanId/installments/due`, `PATCH /installments/:id`, `DELETE /installments/:id`
- All Debt and Installment endpoints require JWT authentication and owner access to the parent WeddingPlan.
- `smoke:debt-installment` passed from the worktree.
- Tasks and Sharing are not implemented yet.
- Flutter/mobile work has not started.
- `backend/.env` is untracked and gitignored; runtime verification used process environment variables only.

## Checks Passed From Debt + Installment Worktree

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS
- `npx prisma migrate dev --name add_debt_installment_models`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3137`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3137`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3137`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3137`: PASS (27/27 checks)
- `npm run smoke:budget-expense` with `SMOKE_BASE_URL=http://127.0.0.1:3137`: PASS (48/48 checks)
- `npm run smoke:debt-installment` with `SMOKE_BASE_URL=http://127.0.0.1:3137`: PASS (56/56 checks)
- Migration SQL scope check: PASS
- passwordHash not exposed in auth, WeddingPlan, Budget + Expense, or Debt + Installment smoke responses: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step after merge: Task + Timeline backend slice.
- Debt + Installment worktree must remain in place until review/merge/cleanup approval.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Complete: WeddingPlan Prisma model and migration
  7. Complete: WeddingPlan API slice
  8. Complete: Budget + Expense backend slice
  9. Current: Debt + Installment backend slice
  10. Next after merge approval: Task + Timeline backend slice
- Do not start Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile files until the active phase explicitly asks for Flutter work.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the current migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
