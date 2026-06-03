# Changelog

## 2026-06-03 - Phase 3 Task + Timeline Backend Slice

- Added `WeddingTaskStatus`, `WeddingTaskPriority`, and `WeddingTask` Prisma schema support with a real migration `20260603205638_add_task_timeline_model`.
- Implemented protected Task endpoints under WeddingPlan ownership: create, list, update, and delete.
- Implemented protected Timeline endpoint under WeddingPlan ownership with wedding date, upcoming tasks, due debts, and due installments.
- Added `backend/scripts/smoke/task-timeline-smoke.js` and `smoke:task-timeline` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_task_timeline_model`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, `npm run smoke:debt-installment`, and `npm run smoke:task-timeline`.
- Documented that Sharing and Flutter/mobile work are not implemented yet.
- Confirmed no Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Task + Timeline slice were created.

## 2026-06-03 - Phase 3 Debt + Installment Backend Slice

- Added `DebtStatus`, `InstallmentStatus`, `Debt`, and `Installment` Prisma schema support with a real migration `20260602215807_add_debt_installment_models`.
- Implemented protected Debt endpoints under WeddingPlan ownership: create, list, summary, update, and delete.
- Implemented protected Installment endpoints under Debt/WeddingPlan ownership: create, list, due list, update, and delete.
- Added `backend/scripts/smoke/debt-installment-smoke.js` and `smoke:debt-installment` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_debt_installment_models`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, and `npm run smoke:debt-installment`.
- Documented that Tasks, Sharing, and Flutter/mobile work are not implemented yet.
- Confirmed no Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Debt + Installment slice were created.

## 2026-06-03 - Phase 3 Budget + Expense Backend Slice

- Added `ExpenseStatus`, `BudgetCategory`, and `Expense` Prisma schema support with a real migration `20260602211007_add_budget_expense_models`.
- Implemented protected BudgetCategory endpoints under WeddingPlan ownership: create, list, update, and delete.
- Implemented protected Expense endpoints under WeddingPlan ownership: create, list, summary, update, and delete.
- Added `backend/scripts/smoke/budget-expense-smoke.js` and `smoke:budget-expense` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, and `npm run smoke:budget-expense`.
- Documented that Debts, Installments, Tasks, Sharing, and Flutter/mobile work are not implemented yet.
- Confirmed no Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Budget + Expense slice were created.

## 2026-06-02 - Phase 3 WeddingPlan API Slice

- Implemented protected WeddingPlan API slice with `POST /wedding-plans`, `GET /wedding-plans/my`, `GET /wedding-plans/:id`, `PATCH /wedding-plans/:id`, and `PATCH /wedding-plans/:id/archive`.
- Added `WeddingPlansModule`, `WeddingPlansService`, `WeddingPlansController`, `CreateWeddingPlanDto`, and `UpdateWeddingPlanDto`.
- All WeddingPlan routes require JWT and use authenticated ownership context before returning or mutating plans.
- Added `backend/scripts/smoke/wedding-plan-smoke.js` and `smoke:wedding-plan` package script.
- Verified `npm install`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, and `npm run smoke:wedding-plan`.
- Confirmed `passwordHash` is not returned and no Budget, Expenses, Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, new Prisma models, new migrations, `prisma db push`, fake migrations, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside WeddingPlan API slice were created.

## 2026-06-02 - Phase 3 WeddingPlan Prisma Model

- Added `WeddingPlanStatus` enum and `WeddingPlan` Prisma model with the approved owner, title, city, wedding date, estimated budget, currency, status, and timestamp fields.
- Added `User.weddingPlans` relation and `WeddingPlan.owner` relation through `ownerUserId`.
- Created and applied real Prisma migration `20260602200934_add_wedding_plan_model`.
- Migration SQL creates only `WeddingPlanStatus`, `WeddingPlan`, and the foreign key to `User`.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, and `npm run smoke:auth`.
- Confirmed no WeddingPlan API/controller/service/module, Budget, Expenses, Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 Ownership Context Foundation

- Added a generic authenticated-user shape and ownership context service for future private modules.
- Kept ownership checks generic: compare authenticated user id to resource `ownerUserId`; no WeddingPlan or private resource API was created.
- Updated auth context typing so `CurrentUser` and JWT validation use a safe authenticated-user shape.
- Extended `smoke:auth` to verify `/auth/me` preserves the authenticated user's id and role consistently; auth smoke now has 21 checks.
- Documented the ownerUserId access pattern in API/database planning and decisions.
- Verified `npm install`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, and `npm run smoke:auth`.
- Confirmed no WeddingPlan, product modules, Prisma models, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside ownership/auth context were created.

## 2026-06-02 - Phase 3 Auth Foundation

- Implemented minimal Auth foundation: `AuthModule`, `AuthService`, `AuthController`, `JwtStrategy`, `JwtAuthGuard`, `CurrentUser` decorator, `RegisterDto`, `LoginDto`, and `SafeUser` mapper.
- Endpoints: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`.
- Registration accepts `name`, `phone`, optional `email`, and `password`; hashes password with bcryptjs; creates User with default `USER` role and `ACTIVE` status.
- Login is phone-first, validates password hash, rejects disabled users.
- `GET /auth/me` requires a valid JWT and returns safe current user.
- `passwordHash` is never returned in any API response — confirmed by 3 explicit smoke checks.
- Added `ValidationPipe` globally in `main.ts` for DTO validation.
- Updated `backend/.env.example` with `JWT_SECRET` placeholder.
- Added `scripts/smoke/auth-smoke.js` with 15 checks covering register, login, wrong-password rejection, unauthenticated /me, and authenticated /me.
- Added `smoke:auth` package script; updated `smoke` to run both `smoke:health` and `smoke:auth`.
- Dependencies added: `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcryptjs`, `class-validator`, `class-transformer`, `@types/passport-jwt`, `@types/bcryptjs`.
- `backend/.env` created locally (untracked, gitignored); `JWT_SECRET` not committed.
- No new Prisma migrations were created or needed; existing User model is sufficient.
- Verified: `npm install` PASS, `prisma:generate` PASS, `npm run check` PASS, `npm run build` PASS, `npm audit` 0 vulnerabilities, `GET /health` PASS, `npm run smoke:health` PASS, `npm run smoke:auth` 15/15 PASS.
- Confirmed no WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, refresh tokens, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic outside Auth foundation were created.

## 2026-06-02 - Phase 3 User Model Migration Created


- Created and applied real Prisma migration `20260602181910_init_user_model` for the User model.
- Migration scope: `UserRole` enum, `UserStatus` enum, `User` table only — no other tables.
- Database: `aarast_dev` (fresh database created in `aarast-db` Docker container on port `5433`).
- Prisma version: `6.19.3` (local install) — global Prisma 7.x was intentionally bypassed to preserve project versioning.
- `aarast` database preserved intact; `aarast_dev` created as a clean isolated dev database.
- `backend/.env` created locally (untracked, gitignored); not committed.
- Verified `prisma format`, `prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health` — all PASS.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Migration Attempt

- Attempted to create the real User model Prisma migration `init_user_model`.
- Confirmed no fake migration was created; `backend/prisma/migrations/` still does not exist.
- Migration is blocked because the local PostgreSQL/DATABASE_URL setup is not usable from this worktree.
- Verified `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Prisma Model

- Added `UserRole` and `UserStatus` enums and the minimal MVP `User` Prisma model.
- Kept the User model limited to approved identity fields with no relations, provider profile fields, refresh tokens, or WeddingPlan relation.
- Attempted local migration `init_user_model`; migration was blocked because `DATABASE_URL` is not configured in this worktree.
- Verified `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Model Design Alignment

- Documented the minimal MVP User model shape: `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`.
- Clarified that phone is important for Yemen-first usage and `passwordHash` must store hashed passwords only, never plaintext passwords.
- Defined initial roles as `USER`, `ADMIN`, and `PROVIDER`, with `PROVIDER` reserved for later provider flows only.
- Defined initial statuses as `ACTIVE` and `DISABLED`.
- Confirmed this task is design-only; no Prisma models, migrations, Auth, backend modules, dependencies, tests, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 Prisma/PostgreSQL Foundation

- Added Prisma/PostgreSQL foundation with an empty Prisma schema, PostgreSQL datasource, Prisma client generation, and neutral NestJS Prisma infrastructure.
- Added placeholder-only `DATABASE_URL` documentation in `backend/.env.example`.
- Verified `npm install`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Prisma models, migrations, product modules, Auth/User/WeddingPlan logic, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 Persistence/Auth Readiness Planning

- Documented the approved readiness order: Prisma + PostgreSQL foundation, User model, Auth foundation, ownership context, then WeddingPlan module.
- Clarified that WeddingPlan ownership must not use a mock-auth shortcut.
- Clarified that production migrations and Docker/Dokploy deployment work are outside this planning task.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 WeddingPlan Design Alignment

- Clarified that WeddingPlan implementation depends on backend persistence and authenticated ownership readiness.
- Kept WeddingPlan as the first Wedding Financial OS domain module after prerequisites.
- Documented the first planned WeddingPlan slice and confirmed SharedMember, Budget, Expenses, Debts, Installments, and Tasks are later slices.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 2 Health Smoke Baseline

- Added a Node-based health smoke script for `GET /health`.
- Added backend `smoke` and `smoke:health` package scripts.
- Kept Phase 2 limited to the existing health endpoint; no product modules, tests, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were added.

## 2026-06-02 - Phase 1 Backend Foundation

- Added the minimal NestJS backend foundation in `backend/` with a basic `GET /health` endpoint.
- Verified `npm install`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, and `GET /health`.
- Committed the backend foundation as `b67246438c4537af91d5445d05507dc569a07885` on `phase/1-backend-foundation`.
- Confirmed no product modules, Flutter/mobile app, migrations, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat logic, marketplace logic, or confirmed booking logic were created.

## 2026-06-01 - Docs Foundation

- Created/updated the root Markdown documentation foundation for Aarast / اعّرست, including `DEPLOYMENT_PLAN.md`.
- Documented Docker for local isolation and Dokploy for later VPS deployment; clarified these are planning-only in this phase and no Dockerfile, docker-compose, Dokploy config, or deployment scripts were created.
- Clarified the MVP is Wedding Financial OS first and marketplace second.
- Clarified early provider/service features are planning references and quote/lead flows only.
- Explicitly excluded payment processing, deposits, confirmed bookings, payment status, loans, credit, financing, FinTech, AI, and internal chat from the MVP unless later approved.
- Added private-by-default financial data rules for expenses, debts, installments, attachments, and private tasks.
- Added Attachment as a planning-level entity/API concept.
- Documented Git worktree as the intended workflow, with actual usage blocked until the correct Git repository root is confirmed.
- Strengthened `AGENTS.md` rules and approved-docs discipline.
- Confirmed no application code, tests, Git actions, dependencies, migrations, Docker files, Dokploy config, Flutter screens, backend modules, deployment scripts, or business logic were created.
