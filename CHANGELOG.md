# Changelog

## 2026-07-07 - Launch Readiness Wave 2 (Scale, Observability, Hardening)

- Backend now uses Redis (optional `REDIS_URL`) for cross-replica rate limiting and Socket.IO delivery, failing open with a logged warning when Redis is unreachable instead of returning 500s.
- Added request-id correlation (`X-Request-Id`), per-request access logs, a token-guarded Prometheus `/metrics` endpoint, JSON logs in production, and optional Sentry capture for 5xx responses (`SENTRY_DSN`).
- Dokploy compose gains Redis and a nightly `pg_dump` backup sidecar with retention; media (S3), Sentry, metrics, and backup variables documented in `.env.example`.
- Admin web now actually serves its security headers (nginx `add_header` inheritance bug) and ships a strict Content-Security-Policy with the API origin injected at container start.
- Mobile release builds sign with an upload keystore via git-ignored `android/key.properties`, with R8 minification, resource shrinking, and Flutter ProGuard rules; `flutter build apk --release` verified.
- Unbounded list endpoints (expenses, guests, tasks, debts, financial commitments, payment records) accept opt-in `take`/`skip` pagination and are bounded by a 1000-row safety cap; responses stay arrays so existing clients are unaffected.
- CI gains a `backend-e2e` job that boots the compiled backend against Postgres 16 + Redis 7 and runs all 23 smoke suites; the suite passes locally (23/23).

## 2026-07-07 - Launch Readiness Phase 0

- Removed legacy root files (`old_aarast_dashboard_widgets.dart`, `update_dashboard.py`) and untracked local tooling state (`.codex/`, `design_web_refs/` photos) with matching `.gitignore` entries.
- Added `test/password-reset-logic.test.ts` to the backend `npm test` suite (60 tests total).
- Hardened the backend Docker image: dev dependencies are pruned from the runtime layer, the Prisma client is regenerated after pruning, and the container now runs as the non-root `node` user. The `prisma` CLI moved to production dependencies because the container runs `migrate deploy` at startup.
- Added GitHub Actions CI (`.github/workflows/ci.yml`): backend typecheck + tests, backend Docker image build, admin-web build, mobile `flutter analyze` + tests, and docs verification.
- Tagged the nine golden preview test files with `@Tags(['golden'])` and added `mobile/dart_test.yaml`; CI excludes golden tests because their PNGs are Windows-rendered, while local runs still include them.
- No product behavior, API contract, database schema, or deployment topology changed.

## 2026-06-21 - Markdown Source-of-Truth Refresh

- Refreshed documentation to make `API_CONTRACT.md` the route-level API source of truth.
- Reduced risky endpoint duplication in mobile docs by pointing mobile readers to the API contract.
- Marked older backend completion/audit docs with clearer current-vs-historical context.
- Clarified current mobile QA/design source documents and preserved legacy root docs as references.
- Fixed broken Markdown references in the mobile product UX rebuild documentation.
- Confirmed this was a Markdown-only cleanup; no Flutter, backend, admin-web, Prisma, Docker/Dokploy, deployment, migration, package, Git branch, commit, or push work was included.

## 2026-06-14 - Dokploy Production Routing Sync

- Synchronized the production Dokploy Compose configuration with the live server fix.
- Published backend host port `8093` to container port `3000`.
- Published admin dashboard host port `8095` to container port `80`.
- Set production deployment defaults to `PORT=3000`, `CORS_ORIGINS=https://aarast.shadowgardn.com`, and `VITE_API_BASE_URL=https://aarast-api.shadowgardn.com`.
- Updated deployment documentation so future Dokploy redeploys do not restore the old unhealthy port mapping.
- Confirmed no backend business logic, Flutter screens, database migrations, payment/deposit flows, AI, FinTech, internal chat, or confirmed booking behavior were changed.

## 2026-06-07 - Home Dashboard Exact Blueprint Polish

- Polished the Flutter Home dashboard to more closely match the approved Arabic visual reference.
- Tightened the wide-web layout with centered max-width content, denser card hierarchy, and no oversized desktop bottom navigation.
- Reworked the Home hero, metrics, budget summary, quick actions, alerts, members, and shared plans sections using existing APIs only.
- Fixed the Home budget display rule so estimated plan budget is preferred and remaining budget is not shown as negative when budget data is missing.
- Confirmed no backend code, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, confirmed booking logic, generated files, or new packages were created.

## 2026-06-06 - Flutter WeddingPlan Dashboard Command Center Redesign

- Redesigned the Flutter `WeddingPlanDashboardScreen` into a true command center.
- Added new `DashboardSummaryProvider` to fetch and aggregate Plan, Expense Summary, Debt Summary, Due Installments, Tasks, and Shared Members concurrently.
- Replaced basic navigation items with modern summary cards (`WeddingHeroSummaryCard`, `FinancialCommandCard`, `DebtInstallmentCommandCard`, `TaskTimelineCommandCard`, `QuickActionsGrid`).
- Preserved the sharing privacy UX by displaying locked versions of financial cards to shared users without adequate permissions.
- Kept animations subtle and restricted to built-in Flutter widgets (`TweenAnimationBuilder`, `AnimatedSwitcher`, etc.).
- Confirmed no backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created.
- Confirmed no new external Flutter dependencies were introduced.

## 2026-06-05 - Bug-Fix Polish Pass 3

- Improved Sharing member display so cards show safe member name and phone instead of the technical `userId`.
- Added safe shared-user display data to Sharing responses: `id`, `name`, and `phone` only.
- Translated common Sharing errors in Flutter UI, including duplicate member and unknown phone cases.
- Confirmed `passwordHash`, refresh tokens, secrets, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not created or exposed.

## 2026-06-05 - Bug-Fix Polish Pass 2

- Allowed owners to add shared members by registered phone number from Flutter.
- Preserved existing `userId`-based Sharing API support for compatibility.
- Rejected create-share requests that provide both `userId` and `phone`.
- Added sharing smoke coverage for adding a shared member by phone.
- Confirmed no Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, confirmed booking logic, secrets, or unrelated features were created.

## 2026-06-05 - Bug-Fix Polish Pass 1

- Fixed Flutter WeddingPlan Dashboard financial navigation privacy UX for shared users.
- Shared users without financial permissions now see locked/disabled financial cards instead of direct finance or debt navigation.
- Shared users with budget, expense, debt, or financial-record permissions can access the relevant financial dashboard cards.
- Owner dashboard access remains unchanged and still shows finance, debt, task, and sharing navigation.
- Confirmed backend permissions, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-05 - Hands-On MVP QA

- Recorded `MANUAL_QA_REPORT.md` for the successful hands-on MVP QA run.
- Confirmed manual QA passed for Auth, WeddingPlan, Dashboard, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing flows.
- Documented known QA notes for sharing by technical `userId` and financial navigation visibility for shared users.
- Confirmed the next recommended step is a bug-fix polish pass, then deployment planning.
- Confirmed no backend code, Flutter feature code, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created or modified by this QA documentation update.

## 2026-06-05 - Flutter MVP Regression And Manual QA Plan

- Regression-verified the Flutter MVP with `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Audited Flutter routes for Auth, WeddingPlan, Finance, Debts, Tasks, Timeline, and Sharing screens.
- Checked mobile API clients against the frozen `API_CONTRACT.md`.
- Added `MOBILE_QA_PLAN.md` with an Arabic-first manual QA checklist for hands-on backend/mobile validation.
- Documented that the next step after merge is a hands-on QA run and bug-fix pass.
- Confirmed no new mobile features, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created.

## 2026-06-04 - Flutter Sharing Screens

- Added Flutter Sharing mobile screens under `mobile/lib/features/sharing/`.
- Wired Sharing API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/sharing`, `/wedding-plans/:id/sharing/add`, `/shared-members/:id/edit`, and `/shared/wedding-plans`.
- Replaced the WeddingPlan Dashboard sharing placeholder with a real navigation card and added a Home entry for shared plans.
- Added privacy-first permission labels for budget, expenses, debts, task management, and financial record management.
- Kept Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Task + Timeline Screens

- Added Flutter Task + Timeline mobile screens under `mobile/lib/features/tasks/`.
- Wired Task and Timeline API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/tasks`, `/wedding-plans/:id/tasks/create`, and `/wedding-plans/:id/timeline`.
- Replaced the WeddingPlan Dashboard task/timeline placeholder with a real navigation card.
- Kept Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Debt + Installment Screens

- Added Flutter Debt + Installment mobile screens under `mobile/lib/features/debts/`.
- Wired Debt and Installment API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/debts`, `/wedding-plans/:id/debts/create`, `/debts/:debtId`, and `/debts/:debtId/installments/create`.
- Replaced the WeddingPlan Dashboard debt/installment placeholder with a real navigation card.
- Kept Task, Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Budget + Expense Screens

- Added Flutter Budget + Expense mobile screens under `mobile/lib/features/finance/`.
- Wired BudgetCategory and Expense API clients to the existing backend contract without changing backend APIs.
- Added finance routes for `/wedding-plans/:id/finance`, `/wedding-plans/:id/budget-categories/create`, and `/wedding-plans/:id/expenses/create`.
- Replaced the WeddingPlan Dashboard budget/expense placeholder with a real navigation card.
- Kept Debt, Installment, Task, Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter WeddingPlan And Dashboard Foundation

- Added Flutter WeddingPlan model, API client, and Provider-based state under `mobile/lib/features/wedding_plans/`.
- Implemented My WeddingPlans, Create WeddingPlan, and WeddingPlan Dashboard screens using the frozen backend API contract.
- Added routes for `/wedding-plans`, `/wedding-plans/create`, and `/wedding-plans/:id/dashboard`.
- Updated Home to link clearly to WeddingPlan planning.
- Kept budget, expense, debt, installment, task, sharing, and timeline mobile screens as dashboard placeholders only.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, backend API contract, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Auth Foundation

- Created `mobile/` as the Flutter app foundation for Aarast / اعّرست.
- Added Arabic-first RTL app theme, routing, Dio API client, shared-preferences auth storage, and Provider-based auth state.
- Implemented Splash, Login, Register, and Home placeholder screens wired to the frozen backend Auth contract.
- Added `mobile/README.md` with run instructions, API base URL location, implemented scope, and exclusions.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, backend API contract, Prisma models, migrations, WeddingPlan/dashboard/financial screens, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Backend Regression And API Contract Freeze

- Added `API_CONTRACT.md` as the frozen MVP backend API contract for Flutter integration.
- Added `backend/scripts/smoke/all-smoke.js` and `smoke:all` to run all backend MVP smoke scripts in sequence.
- Regression-verified health, auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing / Permissions smoke coverage.
- Documented that backend MVP core API is ready for Flutter MVP integration after this phase is merged.
- Confirmed deployment/Docker/Dokploy, marketplace, payment, AI/FinTech, chat, confirmed booking, deposit, provider, vendor, and Flutter implementation are still not started in this phase.

## 2026-06-04 - Phase 3 Sharing / Permissions Backend Slice

- Added `SharedMemberRole` and `SharedMember` Prisma schema support with a real migration `20260603212938_add_shared_members_permissions`.
- Implemented protected Sharing endpoints for adding, listing, updating, removing shared members, and listing wedding plans shared with the current user.
- Added a generic permission service for plan ownership, shared plan readability, task management, and financial visibility checks.
- Integrated shared read access for WeddingPlan, task visibility and task management permissions, and permission-aware timeline financial visibility.
- Kept financial endpoints owner-only in this slice; financial privacy remains protected by default.
- Added `backend/scripts/smoke/sharing-smoke.js` and `smoke:sharing` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_shared_members_permissions`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, `npm run smoke:debt-installment`, `npm run smoke:task-timeline`, and `npm run smoke:sharing`.
- Confirmed no product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Sharing / Permissions slice were created.

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
