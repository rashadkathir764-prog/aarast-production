# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Last Completed Task

- Task: Budget + Expense backend slice merged into main and verified
- Main merge HEAD: `08dd876908a3105953b308b06d7444263ed51e7a`
- Prisma additions: `ExpenseStatus`, `BudgetCategory`, `Expense`, and WeddingPlan relations for budget categories and expenses
- Migration created and applied: `20260602211007_add_budget_expense_models`
- BudgetCategory endpoints available: `POST /wedding-plans/:weddingPlanId/budget-categories`, `GET /wedding-plans/:weddingPlanId/budget-categories`, `PATCH /budget-categories/:id`, `DELETE /budget-categories/:id`
- Expense endpoints available: `POST /wedding-plans/:weddingPlanId/expenses`, `GET /wedding-plans/:weddingPlanId/expenses`, `GET /wedding-plans/:weddingPlanId/expenses/summary`, `PATCH /expenses/:id`, `DELETE /expenses/:id`
- All BudgetCategory and Expense endpoints require JWT authentication and owner access to the parent WeddingPlan.
- `smoke:budget-expense` passed from main.
- Debts, Installments, Tasks, and Sharing are not implemented yet.
- Flutter/mobile work has not started.
- `backend/.env` is untracked and gitignored; runtime verification used process environment variables only.

## Checks Passed From Main

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3136`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3136`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3136`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3136`: PASS (27/27 checks)
- `npm run smoke:budget-expense` with `SMOKE_BASE_URL=http://127.0.0.1:3136`: PASS (48/48 checks)
- Migration SQL scope check: PASS
- passwordHash not exposed in auth, WeddingPlan, or Budget + Expense smoke responses: PASS
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: Debt + Installment backend slice.
- Approved implementation order:
  1. Complete: Prisma + PostgreSQL foundation
  2. Complete: User model
  3. Complete: User migration
  4. Complete: Auth foundation
  5. Complete: Ownership context
  6. Complete: WeddingPlan Prisma model and migration
  7. Complete: WeddingPlan API slice
  8. Complete: Budget + Expense backend slice
  9. Next: Debt + Installment backend slice
- Do not start Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create Flutter/mobile files until the active phase explicitly asks for Flutter work.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the current migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
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
