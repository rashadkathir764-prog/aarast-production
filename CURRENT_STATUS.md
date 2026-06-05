# Current Status

## Project

- Project name: Aarast / اعّرست
- Repository root: `D:\projects\aarast`
- Main branch: `main`
- Current worktree path: `D:\projects\aarast`
- Current branch: `main`

## Current Task Status

- Task: Hands-on MVP QA run passed and documented.
- Current HEAD before manual QA documentation: `d19e97649117f6ff1e8acbfb553700518d1de3a5`
- Flutter app path: `mobile/`
- Manual QA plan: `MOBILE_QA_PLAN.md`
- Manual QA report: `MANUAL_QA_REPORT.md`
- Core Flutter MVP screens are now implemented.
- Hands-on MVP QA run passed for the main MVP flows.
- Core MVP is ready for the first bug-fix polish pass.
- Backend API contract remains unchanged.
- Route audit passed for auth, WeddingPlan, dashboard, finance, debt/installment, task/timeline, and sharing routes.
- Backend contract sanity check passed against `API_CONTRACT.md`.
- No mobile code fix was needed during regression.
- Backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## Hands-On MVP QA Passed

- Auth register/login/logout: PASS
- Create WeddingPlan: PASS
- Open WeddingPlan Dashboard: PASS
- Create Budget Category: PASS
- Create Expense: PASS
- Expense summary updated: PASS
- Create Debt: PASS
- Create Installment: PASS
- Debt summary/details updated: PASS
- Create Task: PASS
- Timeline summary updated: PASS
- Add shared member: PASS
- Shared member can access shared plan: PASS
- Shared member with `canManageTasks` can create task: PASS
- Final verdict: MVP core flow PASS
- Known QA notes are recorded in `MANUAL_QA_REPORT.md`.
- No deployment has started.
- Marketplace, payments, deposits, AI/FinTech, chat, and confirmed booking features are not part of the MVP.

## Checks Passed From Flutter MVP Regression Worktree

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- Route audit: PASS
- Backend API contract sanity check: PASS
- Core Flutter MVP screens are now implemented: PASS
- Mobile code fix needed: NO
- Emulator/device requirement: not required for this verification.
- Backend code unchanged by this regression task: PASS
- Forbidden scope check: PASS

## Checks Passed From Main After Flutter MVP QA Merge

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- `MOBILE_QA_PLAN.md` exists: PASS
- Flutter MVP QA documentation exists: PASS
- Backend code unchanged by this phase: PASS
- No new mobile features were added by this phase: PASS
- Forbidden scope check: PASS

## Last Completed Task

- Task: Flutter WeddingPlan + Dashboard Foundation merged into main and verified
- Main HEAD after Flutter WeddingPlan merge: `4b5feddcf89a1a44048edacdc4dcf853f2926824`
- API contract file: `API_CONTRACT.md`
- Flutter app path: `mobile/`
- API base URL location: `mobile/lib/core/config/api_config.dart`
- Auth endpoints wired: `POST /auth/register`, `POST /auth/login`, and `GET /auth/me`
- WeddingPlan endpoints wired: `POST /wedding-plans`, `GET /wedding-plans/my`, `GET /wedding-plans/:id`, `PATCH /wedding-plans/:id`, and `PATCH /wedding-plans/:id/archive`.
- Screens implemented: Splash, Login, Register, Home placeholder, My WeddingPlans, Create WeddingPlan, and WeddingPlan Dashboard.
- WeddingPlan mobile screens available: My WeddingPlans, Create WeddingPlan, and WeddingPlan Dashboard.
- Backend API contract remains unchanged.
- Dashboard has placeholder cards for financial features only.
- Budget, expense, debt, installment, task, sharing, and timeline mobile screens are not implemented yet.
- Deployment, Docker, and Dokploy implementation are still not started.
- `backend/.env` remains untracked and gitignored.

## Checks Passed From Flutter WeddingPlan Dashboard Worktree

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- Auth flow preservation check: PASS
- WeddingPlan route/client check: PASS, Flutter client uses `/wedding-plans`, `/wedding-plans/my`, `/wedding-plans/:id`, `/wedding-plans/:id/archive`, and Bearer token authorization through the existing API client.
- Emulator/device requirement: not required for this verification.
- Backend code unchanged by this phase: PASS
- Forbidden scope check: PASS

## Checks Passed From Main After Flutter WeddingPlan Dashboard Merge

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- WeddingPlan feature exists: PASS
- My WeddingPlans screen exists: PASS
- Create WeddingPlan screen exists: PASS
- WeddingPlan Dashboard screen exists: PASS
- WeddingPlan API endpoints wired: PASS
- Home links to WeddingPlans: PASS
- Backend code unchanged by this phase: PASS
- Budget, expense, debt, installment, task, sharing, and timeline mobile screens are not implemented yet: PASS
- Forbidden scope check: PASS

## Checks Passed From Flutter Auth Worktree

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- Auth contract check: PASS, Flutter client uses `/auth/register`, `/auth/login`, `/auth/me`, and Bearer token authorization.
- Emulator/device requirement: not required for this verification.
- Forbidden scope check: PASS

## Checks Passed From Main After Flutter Auth Merge

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --debug`: PASS
- `mobile/` project exists: PASS
- API base URL config exists: PASS
- Auth endpoints wired and Bearer token support present: PASS
- Backend code unchanged by this phase: PASS
- WeddingPlan, dashboard, and financial mobile screens are not implemented yet: PASS
- Forbidden scope check: PASS

## Checks Passed From Backend Regression Worktree

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma format`: PASS
- `npx prisma validate`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3148`: PASS
- `npm run smoke:health` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS
- `npm run smoke:auth` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (21/21 checks)
- `npm run smoke:wedding-plan` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (27/27 checks)
- `npm run smoke:budget-expense` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (48/48 checks)
- `npm run smoke:debt-installment` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (56/56 checks)
- `npm run smoke:task-timeline` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (43/43 checks)
- `npm run smoke:sharing` with `SMOKE_BASE_URL=http://127.0.0.1:3148`: PASS (57/57 checks)
- `npm run smoke:all` with `SMOKE_BASE_URL=http://127.0.0.1:3150`: PASS
- Migration SQL scope check: PASS
- passwordHash not exposed in auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, or Sharing smoke responses: PASS
- Forbidden scope check: PASS

## Checks Passed From Main After Merge

- `npm install`: PASS, 0 vulnerabilities
- `npx prisma validate`: PASS
- `npm run prisma:generate`: PASS, Prisma Client v6.19.3 generated
- `npm run check`: PASS
- `npm run build`: PASS
- `npm audit`: PASS, 0 vulnerabilities
- `GET /health` on port `3152`: PASS
- `npm run smoke:all` with `SMOKE_BASE_URL=http://127.0.0.1:3152`: PASS
- `backend/.env` remains untracked and gitignored.
- Forbidden scope check: PASS

## Current Pending Step

- Next pending step: first bug-fix polish pass.
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
  12. Complete: Backend Regression + API Contract Freeze
  13. Complete: Flutter Auth Foundation
  14. Complete: Flutter WeddingPlan + Dashboard foundation
  15. Complete: Flutter Budget + Expense screens
  16. Complete: Flutter Debt + Installment screens
  17. Complete: Flutter Task + Timeline screens
  18. Complete: Flutter Sharing screens
  19. Complete: Flutter MVP Regression + Manual QA Plan
  20. Complete: hands-on QA run
  21. Next: bug-fix polish pass
- Do not start Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create additional mobile screens until the active phase explicitly asks for them.

## Database Context

- `aarast-db` Docker container: `postgres:16`, port `5433`
- `aarast` database: existing schema from prior migrations (`20260529000000_init`, `20260529010000_add_refresh_tokens`) - do not reset or modify
- `aarast_dev` database: local development database used for the current migrations
- `backend/.env` is untracked and gitignored; do not commit it

## Forbidden Scope Reminders

- Do not create Marketplace, AI, FinTech, Payments, Chat, or confirmed booking logic without explicit approval.
- Do not create additional out-of-scope Flutter/mobile screens or folders.
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
- `mobile/build/`, `mobile/.dart_tool/`, and Flutter platform ephemeral files are generated and ignored.
