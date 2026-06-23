# Backend + API Full Audit Report

Date: 2026-06-20
Project: Aarast / Ø£Ø¹Ø±Ø³Øª
Scope: Backend + API contract audit only. No production code, mobile code, admin-web code, migrations, Docker files, deployment files, commits, pushes, resets, or checkouts were changed.

Documentation follow-up: `API_CONTRACT.md` was refreshed on 2026-06-21 to include the current provider-reference, quote-lead, onboarding, dashboard, money, task, guest, sharing, notification, and admin route surface. Keep this audit's security/runtime findings, but do not use its older API-contract-staleness note as current after that refresh.

## 1. Executive Summary

Overall status: PASS for local backend runtime after Docker rebuild, PARTIAL for production hardening.

The backend source contains a broad NestJS + Prisma implementation for the Wedding Financial OS, provider-reference marketplace, quote leads, notifications, guests, sharing, admin operations, and Flutter-facing compatibility routes. Static TypeScript and Prisma schema validation passed. The local Docker backend was healthy.

The initial `smoke:dashboard-summary` failure was caused by a stale Docker runtime, not a confirmed source-code contract failure. After rebuilding the backend Docker container and rerunning migrate/check/validate/`smoke:all`, all 21 smoke suites passed, including `smoke:dashboard-summary` and `smoke:backend-completion`.

Biggest strengths:

- Broad backend module coverage exists: auth, onboarding, active plan, wedding plans, dashboard, budget, expenses, debts, installments, tasks, checklist items, guests, sharing, notifications, provider references, quote leads, provider dashboard, and admin provider/catalog/user APIs.
- Financial privacy is implemented in the main money paths through `PermissionService.assertFinancialReadable`, `assertFinancialManageable`, and permission-aware summaries.
- `passwordHash` is intentionally stripped through safe user response helpers and smoke checks cover this for auth.
- Flutter API usage mostly matches existing backend routes. The backend supports both legacy direct routes and newer `/api/v1` routes for many modules.
- Prisma schema has useful uniqueness/index coverage for user phone/email, shared members, guests, plan invites, notifications, favorites, reviews, and plan-provider links.

Biggest risks:

- P0: Runtime/source mismatch blocks `smoke:all` at dashboard summary.
- P1: Quote request/offer access is too broad for shared members. Several quote operations use plan-readable access only, allowing non-manager shared members to list plan quote requests, create plan quote requests, and accept/reject quote offers.
- P1: `JWT_SECRET` falls back to `changeme` in source, and local `backend/.env` does not define `JWT_SECRET`.
- P1: Admin endpoints have no smoke coverage.
- P1: Guest names/phones are readable by any shared plan member because guest reads use `assertPlanReadable`; there is no `canViewGuests` permission.
- P2: Server-side phone normalization is inconsistent. Flutter normalizes Yemeni phone numbers, but backend auth/sharing/provider paths often store or query raw trimmed input.
- P2 at audit time: API documentation was partially stale because `API_CONTRACT.md` still said marketplace/provider flows were not included while implementation and `API_PLAN.md` included them. This was addressed by the 2026-06-21 Markdown source-of-truth refresh.

Immediate blockers:

- Rebuild/restart or otherwise align the running backend with the current source, then rerun `npm.cmd run smoke:all`.
- Tighten quote request/offer permissions before treating provider quote flows as safe for shared plans.
- Require a real `JWT_SECRET` in backend runtime startup instead of falling back silently.

Recommended next fixes:

- P0: Align local runtime with source and make `smoke:dashboard-summary` pass.
- P1: Restrict quote create/list/accept/reject/cancel paths to owner or an explicit plan/provider permission.
- P1: Add admin smoke coverage for `/admin/dashboard/stats`, provider application review actions, catalog CRUD, and user list/detail.
- P1: Decide and implement guest visibility permission semantics.
- P2: Normalize phone values server-side for auth, lookup, sharing invites/members, provider profile/apply, debts, and guests.

## 2. Git / Environment

Git preflight required by task:

| Check | Result |
| --- | --- |
| `git branch --show-current` | `phase/mobile-home-dashboard-ux-v2` |
| Is branch `main`? | No |
| `git status --short` before audit | Clean |
| Last commit | `b701eaa fix(mobile): repair guest onboarding interactions` |

Last 20 commits observed:

```text
b701eaa fix(mobile): repair guest onboarding interactions
d079739 feat: implement onboarding flow, wedding dashboard, and budget management features
53be99d fix(mobile): start onboarding before login
4b1abcb feat(mobile): connect onboarding active plan dashboard
816ac0f fix(backend): repair provider profile smoke contract
9b14c89 chore(backend): add backend completion smoke coverage
b1d8132 feat(backend): add internal notifications api
f938bb7 feat(backend): add provider quote request flow
b10df3f feat(backend): add plan sharing roles permissions
ff5592d feat(backend): add guest management apis
d5cc9c9 feat(backend): complete task management apis
92a599c feat(backend): complete money management apis
173754f feat(backend): add wedding plan dashboard summary
dca0908 feat(backend): add onboarding active plan flow
3c70f0b docs(backend): add full completion audit
57f5a1f feat(mobile): add notification offline release readiness
b84f8ba feat(mobile): add provider quote readiness
320677a feat(mobile): add collaboration flow readiness
327c80c feat(mobile): add money flow readiness states
e68906b feat(mobile): add guarded dashboard summary adapter
```

Local runtime:

| Check | Result |
| --- | --- |
| `docker compose ps` | `aarast-backend` and `aarast-db` healthy |
| Backend port | `127.0.0.1:3115 -> container 3000` |
| DB port | `127.0.0.1:5433 -> container 5432` |
| `Invoke-RestMethod http://127.0.0.1:3115/health` | PASS: `{ status: ok, service: aarast-backend }` |
| Root `.env` | Not present |
| `backend/.env` | Present but only `PORT` and `DATABASE_URL` were observed after secret masking |
| `backend/.env.example` | Includes `PORT`, `DATABASE_URL`, `JWT_SECRET`, OTP settings |

## 3. API Inventory

Static route extraction from `backend/src/**/*.controller.ts` found 204 route handlers. Many are compatibility duplicates between legacy direct routes and `/api/v1` routes. Some `/api/v1` controllers, such as guests and notifications, extend base controllers and rely on inherited handler methods.

Status meanings:

- PASS: implemented and covered by smoke or direct Flutter usage.
- PARTIAL: implemented but has missing coverage, missing Flutter usage, inherited-route uncertainty, or docs mismatch.
- RISK: implemented but has a security/privacy/contract risk.
- MISSING: requested/planned behavior is not implemented.

### Auth / Me / Users

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST | `/auth/register` | `AuthController.register` / `AuthService` | Public | `RegisterDto` | `{ user, accessToken }` safe user | `User` | `smoke:auth`, `smoke:otp-profile` | Yes | PASS |
| POST | `/auth/login` | `AuthController.login` / `AuthService` | Public | `LoginDto` | `{ user, accessToken }` safe user | `User` | `smoke:auth` | Yes | PASS |
| POST | `/auth/otp/request` | `AuthController.requestOtp` / `AuthService` | Public | `RequestOtpDto` | OTP request metadata; local dev may expose code by env | `OtpCode` | `smoke:otp-profile` | Not current UI | PASS |
| POST | `/auth/otp/verify` | `AuthController.verifyOtp` / `AuthService` | Public | `VerifyOtpDto` | verified phone, optional user/token | `OtpCode`, `User` | `smoke:otp-profile` | Not current UI | PASS |
| GET | `/auth/me` | `AuthController.me` / safe user | JWT | none | safe current user | `User` | `smoke:auth`, `smoke:otp-profile` | Yes | PASS |
| GET | `/me`, `/api/v1/me` | `MeController`, `ApiV1MeController` | JWT | none | safe current user | `User` | `smoke:onboarding-active-plan` | Indirect | PASS |
| PATCH | `/users/me` | `UsersController.updateMe` | JWT | `UpdateProfileDto` | safe user/profile | `User` | `smoke:otp-profile` | Not current settings UI except profile foundation | PASS |
| GET | `/users/lookup?phone=` | `UsersController.lookupByPhone` | JWT | query `phone` | `{ id, name, phone }` | `User` | Not clearly isolated | Yes, sharing add member | PARTIAL |
| GET/PATCH | `/users/me/settings` | `UsersController` / `UsersService` | JWT | `UpdateSettingsDto` | notification settings | `NotificationPreference` | `smoke:otp-profile` | Yes | PASS |

Auth risks:

- `backend/src/auth/auth.module.ts` and `backend/src/auth/jwt.strategy.ts` use `process.env.JWT_SECRET ?? 'changeme'`.
- Backend auth stores and queries `dto.phone` directly. Flutter normalizes phone input, but raw API callers can still create/query inconsistent phone values.

### Onboarding + Active Plan

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST | `/onboarding/complete`, `/api/v1/onboarding/complete` | `OnboardingController`, `ApiV1OnboardingController` / `OnboardingService` | JWT | `CompleteOnboardingDto` | user + active wedding plan + budget categories | `User`, `WeddingPlan`, `BudgetCategory` | `smoke:onboarding-active-plan`, `smoke:backend-completion` | Yes, `/api/v1` | PASS |
| GET | `/wedding-plans/active`, `/api/v1/wedding-plans/active` | `WeddingPlansController.findActive` | JWT | none | active plan or empty body/null-style response | `User`, `WeddingPlan` | `smoke:onboarding-active-plan` | Yes, `/api/v1` | PASS |
| POST | `/wedding-plans/:id/set-active`, `/api/v1/wedding-plans/:id/set-active` | `WeddingPlansController.setActive` | JWT + readable plan | none | selected active plan | `User`, `WeddingPlan`, `SharedMember` | `smoke:onboarding-active-plan` | Not current UI | PASS |

### Wedding Plans

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST | `/wedding-plans`, `/api/v1/wedding-plans` | `WeddingPlansController.create` | JWT owner creates | `CreateWeddingPlanDto` | plan fields, decimal strings | `WeddingPlan`, optional `BudgetCategory` | `smoke:wedding-plan`, many bundle smokes | Yes, legacy and `/api/v1` | PASS |
| GET | `/wedding-plans`, `/api/v1/wedding-plans` | `findAccessible` | JWT | none | owned + shared plans | `WeddingPlan`, `SharedMember` | `smoke:onboarding-active-plan` | Not primary | PASS |
| GET | `/wedding-plans/my`, `/api/v1/wedding-plans/my` | `findMine` | JWT owner | none | owned plans array | `WeddingPlan` | `smoke:wedding-plan` | Yes | PASS |
| GET | `/wedding-plans/:id`, `/api/v1/wedding-plans/:id` | `findOne` | JWT owner/shared readable | none | plan; budget hidden when no budget permission | `WeddingPlan`, `SharedMember` | `smoke:wedding-plan` | Yes | PASS |
| PATCH | `/wedding-plans/:id`, `/api/v1/wedding-plans/:id` | `update` | owner/manager/editor style via `PermissionService.canManagePlan` | `UpdateWeddingPlanDto` | updated plan | `WeddingPlan`, `SharedMember` | `smoke:wedding-plan`, `smoke:sharing-roles` | Yes | PASS |
| PATCH | `/wedding-plans/:id/archive`, `/api/v1/wedding-plans/:id/archive` | `archive` | owner/manager/editor style | none | archived plan | `WeddingPlan` | `smoke:wedding-plan` | Yes | PASS |

### Dashboard Summary

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/dashboard/home` | `DashboardController.getHome` / `DashboardService` | JWT | none | current plan/home aggregate | `WeddingPlan`, financial/task/guest/provider models | Not directly in `smoke:all` before failure | Not current main path | PARTIAL |
| GET | `/wedding-plans/:planId/dashboard-summary`, `/api/v1/wedding-plans/:planId/dashboard-summary` | `WeddingPlanDashboardController`, `ApiV1WeddingPlanDashboardController` / `DashboardService` | JWT + readable plan; finance fields permission-gated | none | plan, days, progress, money, tasks, guests, providers, notifications | `WeddingPlan`, `BudgetCategory`, `Expense`, `Debt`, `Installment`, `WeddingTask`, `Guest`, `PlanProviderLink`, `QuoteRequest`, `Notification` | FAIL in `smoke:dashboard-summary` | Yes, `/api/v1` | RISK |

Runtime/source mismatch:

- Source includes `importantItems`, `planProviders`, `importantNotifications`, and `generatedAt`.
- Runtime smoke showed these fields missing from the running backend.
- Result: current local runtime is not ready for the mobile dashboard contract.

### Money / Budget / Expenses / Debts / Installments

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST/GET | `/wedding-plans/:weddingPlanId/budget-categories`, `/api/v1/.../budget-categories` | `BudgetCategoriesController` / `BudgetCategoriesService` | JWT + financial read/manage | `CreateBudgetCategoryDto` | category decimal strings | `BudgetCategory`, `WeddingPlan` | `smoke:money-apis`, `smoke:budget-expense`, `smoke:backend-completion` | Yes | PASS |
| PATCH/DELETE | `/budget-categories/:id`, `/api/v1/budget-categories/:id` | `BudgetCategoriesController` | JWT + financial manage | `UpdateBudgetCategoryDto` | updated/deleted result | `BudgetCategory` | money smokes | Yes | PASS |
| POST/GET | `/wedding-plans/:weddingPlanId/expenses`, `/api/v1/.../expenses` | `ExpensesController` / `ExpensesService` | JWT + expense/financial permission | `CreateExpenseDto` | expense decimal strings | `Expense`, `BudgetCategory` | money smokes | Yes | PASS |
| GET | `/wedding-plans/:weddingPlanId/expenses/summary` | `ExpensesController.summary` | JWT + expense permission | none | paid/planned/cancelled totals | `Expense` | `smoke:budget-expense`, `smoke:dashboard-summary` | Yes | PASS |
| GET/PATCH/DELETE | `/expenses/:id`, `/api/v1/expenses/:id` | `ExpensesController` | JWT + expense/financial permission | `UpdateExpenseDto` | expense/deleted result | `Expense` | money smokes | Yes | PASS |
| POST/GET | `/wedding-plans/:weddingPlanId/debts`, `/api/v1/.../debts` | `DebtsController` / `DebtsService` | JWT + debt permission | `CreateDebtDto` | debt decimal strings | `Debt` | debt/money smokes | Yes | PASS |
| GET | `/wedding-plans/:weddingPlanId/debts/summary` | `DebtsController.summary` | JWT + debt permission | none | total/paid/remaining/counts | `Debt` | debt smokes | Yes | PASS |
| GET/PATCH/DELETE | `/debts/:id`, `/api/v1/debts/:id` | `DebtsController` | JWT + debt/financial permission | `UpdateDebtDto` | debt/deleted result | `Debt` | debt smokes | Yes | PASS |
| POST/GET | `/debts/:debtId/installments`, `/api/v1/debts/:debtId/installments` | `InstallmentsController` | JWT + debt/financial permission | `CreateInstallmentDto` | installment decimal strings | `Installment`, `Debt` | debt smokes | Yes | PASS |
| GET | `/wedding-plans/:weddingPlanId/installments/due` | `WeddingPlanInstallmentsController` | JWT + debt permission | none | due installments array | `Installment`, `Debt` | debt/dashboard smokes | Yes | PASS |
| PATCH | `/installments/:id/pay`, `/api/v1/installments/:id/pay` | `InstallmentsController.pay` | JWT + financial manage | none | paid installment and debt paid amount update | `Installment`, `Debt` | `smoke:backend-completion` | Not used by Flutter | PARTIAL |
| PATCH/DELETE | `/installments/:id`, `/api/v1/installments/:id` | `InstallmentsController` | JWT + financial manage | `UpdateInstallmentDto` | installment/deleted result | `Installment` | debt smokes | Yes | PASS |
| GET | `/wedding-plans/:planId/money-summary`, `/api/v1/wedding-plans/:planId/money-summary` | `MoneySummaryController` / `MoneySummaryService` | JWT + any financial read permission | none | permission-aware money summary | `BudgetCategory`, `Expense`, `Debt`, `Installment` | `smoke:money-apis`, `smoke:backend-completion` | Not current main path | PASS |

Money notes:

- Main read/write services route through `PermissionService`.
- Decimal storage uses Prisma `Decimal(14,2)`, while aggregate calculations convert to `Number` then format to fixed strings. This is acceptable for current smoke values but should be reviewed before large/high-precision finance use.
- Flutter uses `PATCH /installments/:id` for status/paidAt. The dedicated `/installments/:id/pay` route is currently backend/smoke-facing, not Flutter-facing.

### Tasks / Timeline

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST/GET | `/wedding-plans/:weddingPlanId/tasks`, `/api/v1/.../tasks` | `TasksController` / `TasksService` | JWT; read by plan readable; manage by owner/task permission/editor/helper/contributor | `CreateTaskDto` | task | `WeddingTask` | `smoke:tasks-apis`, `smoke:task-timeline`, `smoke:backend-completion` | Yes | PASS |
| GET | `/wedding-plans/:weddingPlanId/tasks/summary`, `/api/v1/.../tasks/summary` | `TasksController.summary` | JWT + readable plan | none | counts by task state | `WeddingTask` | task smokes | Not direct | PASS |
| GET/PATCH/DELETE | `/tasks/:id`, `/api/v1/tasks/:id` | `TasksController` | JWT + readable/manage rules | `UpdateTaskDto` | task/deleted result | `WeddingTask` | task smokes | Yes | PASS |
| POST/PATCH/DELETE | `/tasks/:id/checklist`, `/tasks/:id/checklist/:itemId`, `/api/v1/...` | `TasksController` | JWT + task manage | checklist DTOs | checklist item/task | `WeddingTaskChecklistItem` | `smoke:tasks-apis`, `smoke:backend-completion` | Not current UI | PARTIAL |
| PATCH | `/tasks/:id/assign`, `/api/v1/tasks/:id/assign` | `TasksController.assign` | JWT + task manage; assignee must belong to plan | `AssignTaskDto` | updated task | `WeddingTask`, `SharedMember`, `User` | `smoke:tasks-apis` | Not current UI | PARTIAL |
| GET | `/wedding-plans/:weddingPlanId/timeline` | `TimelineController` | JWT + readable plan; financial items hidden without debt permission | none | wedding date, upcoming tasks, due debts/installments | `WeddingTask`, `Debt`, `Installment` | `smoke:task-timeline` | Yes | PASS |

### Guests

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET/POST | `/wedding-plans/:weddingPlanId/guests`, `/api/v1/.../guests` | `GuestsController` / `GuestsService` | GET uses readable plan; POST requires guest manage | `CreateGuestDto` | guest | `Guest`, `GuestGroup` | `smoke:guests`, `smoke:guests-apis`, `smoke:backend-completion` | Yes, legacy | PARTIAL |
| POST | `/wedding-plans/:weddingPlanId/guests/bulk`, `/api/v1/.../guests/bulk` | `GuestsController.bulkCreate` | guest manage | `BulkGuestsDto` | guests array | `Guest` | `smoke:guests-apis`, `smoke:backend-completion` | Not current UI | PARTIAL |
| GET | `/wedding-plans/:weddingPlanId/guests/summary`, `/api/v1/.../guests/summary` | `GuestsController.summary` | readable plan | none | guest counts/status counts | `Guest`, `GuestGroup` | guest smokes | Not direct | PARTIAL |
| GET/PATCH/DELETE | `/guests/:id`, `/api/v1/guests/:id` | `GuestsController` | readable for GET; manage for PATCH/DELETE | `UpdateGuestDto` | guest/deleted result | `Guest` | guest smokes | Yes | PASS |
| GET/POST | `/wedding-plans/:weddingPlanId/guest-groups`, `/api/v1/.../guest-groups` | `GuestGroupsController` | readable/manage split | group DTOs | groups | `GuestGroup` | `smoke:guests-apis` | Not current UI | PARTIAL |
| PATCH/DELETE | `/guest-groups/:id`, `/api/v1/guest-groups/:id` | `GuestGroupsController` | guest manage | `UpdateGuestGroupDto` | group/deleted result | `GuestGroup` | `smoke:guests-apis` | Not current UI | PARTIAL |

Guest risk:

- Guest list data includes names and optional phone numbers. `GuestsService.findForPlan` uses `assertPlanReadable`, so every shared member can read guests. The current permission model has `canManageGuests` but not `canViewGuests`.

### Sharing / Roles / Permissions / Invites

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST/GET | `/wedding-plans/:weddingPlanId/shared-members` | `SharingController` / `SharingService` | owner manages/list legacy route | `CreateSharedMemberDto` | shared member with safe user display data | `SharedMember`, `User`, `WeddingPlan` | `smoke:sharing`, `smoke:sharing-roles` | Yes | PASS |
| PATCH/DELETE | `/shared-members/:id` | `SharingController` | owner manages | `UpdateSharedMemberDto` | shared member/deleted result | `SharedMember` | sharing smokes | Yes | PASS |
| GET | `/shared/wedding-plans` | `SharedWeddingPlansController` | JWT shared member | none | shared plans | `SharedMember`, `WeddingPlan` | `smoke:sharing` | Yes | PASS |
| GET/PATCH/DELETE | `/api/v1/wedding-plans/:weddingPlanId/members`, `/api/v1/.../members/:memberId` | API v1 sharing controllers | owner/manage members | member DTOs | member list/update/remove | `SharedMember` | `smoke:sharing-roles` | Not current UI | PARTIAL |
| POST | `/api/v1/wedding-plans/:weddingPlanId/invites` | `ApiV1WeddingPlanInvitesController` | owner/manage members | `CreatePlanInviteDto` | invite token/metadata | `PlanInvite`, `Notification` | `smoke:sharing-roles`, `smoke:notifications-apis` | Not current UI | PARTIAL |
| GET | `/api/v1/invites/:token` | `ApiV1InvitesController` | Public token lookup | token param | invite preview | `PlanInvite` | sharing-role smokes | Not current UI | PARTIAL |
| POST | `/api/v1/invites/:token/accept` | `ApiV1InviteAcceptController` | JWT; token phone must match when present | token param | accepted shared member | `PlanInvite`, `SharedMember`, `Notification` | sharing-role/notification smokes | Not current UI | PARTIAL |
| GET | `/api/v1/wedding-plans/:weddingPlanId/permissions/me` | `ApiV1WeddingPlanPermissionsController` | JWT readable plan | none | permission summary | `WeddingPlan`, `SharedMember` | `smoke:sharing-roles` | Not current UI | PARTIAL |

### Notifications

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/notifications`, `/api/v1/notifications` | `NotificationsController.list` | JWT; owned notifications only; optional plan readable filter | query `weddingPlanId` | notifications array | `Notification`, task/debt/installment for due generation | `smoke:notifications`, `smoke:notifications-apis`, `smoke:backend-completion` | Yes, legacy | PASS |
| GET | `/notifications/unread-count`, `/api/v1/notifications/unread-count` | `NotificationsController.unreadCount` | JWT owned notifications only | optional plan filter | `{ count }` | `Notification` | notification smokes | Yes | PASS |
| GET | `/notifications/:id`, `/api/v1/notifications/:id` | `NotificationsController.findOne` | JWT owner of notification | none | notification | `Notification` | `smoke:notifications-apis`, `smoke:backend-completion` | Not current UI | PASS |
| PATCH | `/notifications/:id/read`, `/api/v1/notifications/:id/read` | `NotificationsController.markRead` | JWT owner | none | notification | `Notification` | notification smokes | Yes | PASS |
| PATCH | `/notifications/read-all`, `/api/v1/notifications/read-all` | `NotificationsController.markAllRead` | JWT owner, optional plan filter | none | `{ updated }` | `Notification` | notification smokes | Yes | PASS |
| DELETE | `/notifications/:id`, `/api/v1/notifications/:id` | `NotificationsController.remove` | JWT owner | none | deleted result | `Notification` | notification smokes | Yes | PASS |

Notification notes:

- Due installment notification generation checks debt visibility before creating installment notifications for shared members.
- Notification deep link data exists as JSON `data`, but push/device-token infrastructure is not implemented.

### Marketplace / Providers / Quotes

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/cities` | `CitiesController` | Public | none | city list | `City` | `smoke:marketplace` | Yes | PASS |
| GET | `/provider-categories`, `/api/v1/provider-categories` | `ProviderCategoriesController` | Public | none | category list | `ProviderCategory` | marketplace/provider smokes | Yes | PASS |
| GET | `/providers`, `/api/v1/providers` | `ProvidersController` | Public | `ListProvidersQueryDto` | paged `{ items, meta }` | `Provider`, `City`, `ProviderCategory`, services/images | marketplace/provider smokes | Yes | PASS |
| GET | `/providers/:id`, `/api/v1/providers/:id` | `ProvidersController` | Public active provider only | id | provider details | `Provider` relations | marketplace/provider smokes | Yes | PASS |
| GET | `/providers/:id/services` | `ProvidersController.findProviderServices` | Public | id | services list | `ProviderService`, images | marketplace smoke | Yes | PASS |
| GET | `/providers/:id/packages` | `ProvidersController.findProviderPackages` | Public | id | packages list | `ProviderPackage` | marketplace smoke | Yes | PASS |
| GET | `/providers/:id/reviews` | `ProvidersController.findProviderReviews` | Public | id | published reviews | `ProviderReview`, safe user display | marketplace smoke | Yes | PASS |
| POST/DELETE | `/providers/:id/favorite` | `ProvidersController` | JWT | id | favorite/remove result | `FavoriteProvider`, `Provider` | marketplace smoke | Yes | PASS |
| GET | `/me/favorite-providers` | `MeMarketplaceController` | JWT | none | favorites | `FavoriteProvider` | marketplace smoke | Yes | PASS |
| POST | `/providers/:id/quote-requests` | `ProvidersController.createQuoteRequest` | JWT; optional plan readable if linked | `CreateQuoteRequestDto` | quote request | `QuoteRequest`, `Provider`, `WeddingPlan` | marketplace/dashboard smokes | Yes | RISK |
| GET/PATCH | `/me/quote-requests`, `/me/quote-requests/:id`, `/me/quote-requests/:id/cancel` | `MeMarketplaceController` | JWT; quote owner or plan readable when linked | none/cancel | quote request(s) | `QuoteRequest`, `QuoteOffer` | marketplace smoke | Not current UI | RISK |
| POST/PATCH/DELETE | `/providers/:id/reviews`, `/reviews/:id` | `ProvidersController`, `ReviewsController` | JWT, review owner | review DTOs | review | `ProviderReview`, `Provider` rating aggregate | marketplace smoke | Partial | PASS |
| POST/GET | `/api/v1/wedding-plans/:weddingPlanId/quote-requests` | `ApiV1WeddingPlanQuoteRequestsController` | JWT + plan readable | `CreatePlanQuoteRequestDto` | quote request(s) | `QuoteRequest`, `Provider`, `WeddingPlan` | providers-quotes/backend-completion | Not current main path | RISK |
| GET/PATCH | `/api/v1/quote-requests/:id`, `/api/v1/quote-requests/:id/cancel` | `ApiV1QuoteRequestsController` | JWT; quote owner or plan readable | none/cancel | quote request | `QuoteRequest`, `QuoteOffer` | providers-quotes smoke | Not current main path | RISK |
| PATCH | `/api/v1/quote-offers/:id/accept`, `/api/v1/quote-offers/:id/reject` | `ApiV1QuoteOffersController` | JWT; quote owner or plan readable | none | accepted/rejected offer, may create `PlanProviderLink` | `QuoteOffer`, `QuoteRequest`, `PlanProviderLink` | providers-quotes/backend-completion | Not current UI | RISK |

Quote risk:

- Plan-linked quote access uses `assertPlanReadable`. A shared viewer can potentially read quote budget ranges/offers and accept/reject offers, which mutates quote status and plan-provider links. This should require owner/manager or an explicit quote/provider permission.

### Provider Dashboard

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST | `/provider/apply` | `ProviderApplicationController.apply` | JWT | `ApplyProviderDto` | provider profile | `Provider`, `City`, `ProviderCategory` | `smoke:provider-dashboard` | Yes | PASS |
| GET/PATCH | `/provider/me/profile` | `ProviderDashboardController` | JWT provider owner | `UpdateProviderProfileDto` | provider profile | `Provider` | provider smoke | Yes | PASS |
| GET | `/provider/me/summary` | `ProviderDashboardController.getSummary` | JWT provider owner | none | provider counts | `Provider`, `ProviderService`, `QuoteRequest` | provider smoke | Yes | PASS |
| GET/POST/PATCH/DELETE | `/provider/me/services`, `/provider/me/services/:id` | `ProviderDashboardController` | JWT provider owner | service DTOs | service/deactivate result | `ProviderService` | provider smoke | Yes create/list | PASS |
| POST/PATCH/DELETE | `/provider/me/services/:id/images`, `/provider/me/services/:serviceId/images/:imageId` | `ProviderDashboardController` | JWT provider owner | image DTO | image/deleted result | `ProviderServiceImage` | provider smoke | Not current UI | PARTIAL |
| GET/POST/PATCH/DELETE | `/provider/me/packages`, `/provider/me/packages/:id` | `ProviderDashboardController` | JWT provider owner | package DTOs | package/deactivate result | `ProviderPackage` | provider smoke | Yes create/list | PASS |
| GET/PATCH | `/provider/me/quote-requests`, `/provider/me/quote-requests/:id`, `/provider/me/quote-requests/:id/status` | `ProviderDashboardController` | JWT provider owner | status DTO | quote request(s) | `QuoteRequest` | provider smoke | Yes list/status | PASS |
| GET | `/provider/me/reviews` | `ProviderDashboardController.findReviews` | JWT provider owner | none | reviews | `ProviderReview` | provider smoke | Not current UI | PARTIAL |
| GET/POST/PATCH/DELETE | `/api/v1/provider/...` aliases | `ApiV1ProviderController` | JWT provider owner | v1 DTOs | provider/profile/service/quote/offer results | provider models | providers-quotes smoke | Not current Flutter | PARTIAL |

### Admin APIs

All `/admin/*` endpoints require `JwtAuthGuard` plus `AdminGuard`.

| Method | Path | Controller / service | Auth / permission | DTO | Response shape | Prisma models | Smoke | Flutter/admin-web | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/admin/dashboard/stats` | `AdminController.getDashboardStats` | ADMIN+JWT | none | aggregate stats | `User`, `Provider`, `QuoteRequest`, `WeddingPlan`, `City`, `ProviderCategory` | None | Admin-web likely | PARTIAL |
| GET | `/admin/providers/applications` | `listProviderApplications` | ADMIN+JWT | `AdminProviderQueryDto` | paged provider applications | `Provider` relations | None | Admin-web likely | PARTIAL |
| GET | `/admin/providers/applications/:id` | `getProviderApplication` | ADMIN+JWT | id | provider application | `Provider` | None | Admin-web likely | PARTIAL |
| PATCH | `/admin/providers/:id/approve` | `approveProvider` | ADMIN+JWT | none/body optional | provider status active/reviewed | `Provider` | None | Admin-web likely | PARTIAL |
| PATCH | `/admin/providers/:id/reject` | `rejectProvider` | ADMIN+JWT | `AdminReviewActionDto` | provider rejected | `Provider` | None | Admin-web likely | PARTIAL |
| PATCH | `/admin/providers/:id/request-changes` | `requestProviderChanges` | ADMIN+JWT | `AdminReviewActionDto` | provider needs changes | `Provider` | None | Admin-web likely | PARTIAL |
| PATCH | `/admin/providers/:id/suspend` | `suspendProvider` | ADMIN+JWT | `AdminReviewActionDto` | provider suspended | `Provider` | None | Admin-web likely | PARTIAL |
| PATCH | `/admin/providers/:id/activate` | `activateProvider` | ADMIN+JWT | none/body optional | provider active | `Provider` | None | Admin-web likely | PARTIAL |
| GET | `/admin/providers`, `/admin/providers/:id` | provider list/detail | ADMIN+JWT | query/id | provider(s) | `Provider` relations | None | Admin-web likely | PARTIAL |
| GET/POST/PATCH/DELETE | `/admin/provider-categories`, `/admin/provider-categories/:id` | category CRUD | ADMIN+JWT | `AdminCatalogDto` | category/deactivated result | `ProviderCategory` | None | Admin-web likely | PARTIAL |
| GET/POST/PATCH/DELETE | `/admin/cities`, `/admin/cities/:id` | city CRUD | ADMIN+JWT | `AdminCatalogDto` | city/deactivated result | `City` | None | Admin-web likely | PARTIAL |
| GET | `/admin/users`, `/admin/users/:id` | user list/detail | ADMIN+JWT | query/id | safe-ish user records | `User` | None | Admin-web likely | PARTIAL |

Admin risk:

- Admin surface is substantial but has no smoke coverage in `backend/scripts/smoke`.

## 4. Module-by-module Audit

### Auth

Implemented:

- Register/login/JWT current user.
- OTP request/verify with hashed OTP codes.
- Safe user response strips `passwordHash`.
- Disabled users are rejected in JWT strategy and login.

Works:

- Auth smoke passed 21/21.
- `GET /auth/me` rejects missing token and returns safe user with token.

Risks/gaps:

- JWT secret fallback to `changeme`.
- Phone normalization is mostly delegated to Flutter; backend accepts raw phone strings.
- No refresh-token/logout endpoint is currently visible in the active API surface, despite earlier planning language.

### Onboarding

Implemented:

- Complete onboarding creates/updates an active plan and budget categories.
- Active plan read and set-active endpoints exist.

Works:

- Onboarding active plan smoke passed 30/30.

Risks/gaps:

- Guest-to-auth migration is still mostly mobile/local strategy; backend has authenticated onboarding but no broad local guest migration API.

### Wedding Plans

Implemented:

- Create/list/my/accessible/active/get/update/archive/set-active.
- Owner/shared readable access and manager/editor updates.

Works:

- WeddingPlan smoke passed 27/27.

Risks/gaps:

- No delete endpoint, which is acceptable for current MVP if archive is intended.

### Dashboard

Implemented in source:

- Dashboard summary uses real plan, budget, expenses, debts, installments, tasks, guests, provider links, quote count, notification count, permission summary.

Runtime result:

- Fails smoke because runtime response lacks expected new dashboard fields.

Risks/gaps:

- Current running backend cannot be trusted for mobile dashboard contract until rebuilt/restarted/aligned and smoke passes.

### Money

Implemented:

- Budget categories, expenses, debts, installments, money summary, due installments, mark/pay installment endpoint.

Works:

- Source paths use permission checks.
- Earlier smoke scripts after dashboard were not reached in this `smoke:all` run, but dedicated scripts exist.

Risks/gaps:

- `Number()` aggregation should be revisited before high-value/high-precision finance expansion.
- Dedicated pay endpoint is not used by Flutter.

### Tasks

Implemented:

- CRUD, summary, checklist items, assignment, timeline.

Works:

- Smoke coverage exists.
- Flutter uses core task CRUD and timeline.

Risks/gaps:

- Checklist and assignment are backend-only from current Flutter data usage.

### Guests

Implemented:

- Guests CRUD, bulk create, summary, guest groups, duplicate prevention by normalized name + normalized phone.

Works:

- Smoke coverage exists.
- Flutter uses basic guest list/create/update/delete.

Risks/gaps:

- No view permission separate from plan-readable access.
- Flutter does not yet use guest groups, bulk create, or summary endpoints.

### Sharing

Implemented:

- Legacy shared members.
- `/api/v1` members, invites, accept flow, permissions summary.
- Role defaults and permission flags for budget, expenses, debts, tasks, financial management.

Works:

- Smoke coverage exists for roles/invites.
- Flutter uses legacy member CRUD and shared wedding plans.

Risks/gaps:

- Flutter does not yet use `/api/v1/invites` or permission summary endpoint.
- Phone lookup/invites depend on normalized phone match but server does not centrally normalize.

### Notifications

Implemented:

- List, unread count, get by id, mark read, mark all read, delete.
- Due task/installment notification creation during list/count.
- Invite accepted and quote offer notifications are covered by scripts.

Works:

- Smoke coverage exists.
- Flutter uses notification list/count/read/delete.

Risks/gaps:

- Deep links are JSON data only; no push/device token backend.
- `/api/v1/notifications` class inherits base handlers, which should stay covered by smoke.

### Marketplace

Implemented:

- Public cities/categories/providers/services/packages/reviews.
- Favorites.
- Quote request creation.
- User quote request reads/cancel.
- Reviews.

Works:

- Public provider reference routes align with Flutter.
- Provider/service/package flows are planning/reference only.

Risks/gaps:

- Quote plan access uses readable-plan permission too broadly.
- Offline Flutter quote request fallback can create local `SENT` quote rows in cache/queue. UI must make pending sync obvious so users do not believe a server/provider action succeeded while local-only.

### Providers

Implemented:

- Provider apply/profile/summary/service/image/package/quote/review owner flows.
- `/api/v1/provider` compatibility routes.

Works:

- Smoke scripts exist.
- Flutter uses legacy provider dashboard routes.

Risks/gaps:

- Admin approval lifecycle exists but is not smoke-tested.
- Provider status naming differs between docs/UX (`pending_review`, `approved`, etc.) and Prisma enum (`PENDING`, `ACTIVE`, `NEEDS_CHANGES`, `SUSPENDED`, `REJECTED`), though admin service maps some incoming terms.

### Quotes

Implemented:

- User quote requests by provider or plan.
- Provider quote request reads/status/offer creation.
- User offer accept/reject.
- Accepting offer creates/updates `PlanProviderLink`.

Works:

- Backend has quote-to-plan link behavior.

Risks/gaps:

- Authorization is too broad for shared plan members.
- Quote requests include budget ranges and message; readable-plan access may expose sensitive planning details.

### Admin

Implemented:

- Provider application review/approval/rejection/request changes/suspend/activate.
- Provider list/detail.
- Provider category and city CRUD/deactivation.
- User list/detail.
- Dashboard stats.

Works:

- Admin guard requires JWT ADMIN role.

Risks/gaps:

- No smoke coverage.
- This audit did not modify or inspect admin-web behavior beyond route existence because the task forbids admin-web changes.

## 5. Prisma / Database Audit

Important models:

| Model | Purpose | Key relations / constraints | Risk |
| --- | --- | --- | --- |
| `User` | account identity | unique phone/email, active plan, owned/shared plans, provider profile, notifications | phone normalization not enforced server-side |
| `WeddingPlan` | central planning record | owner, active users, budget/expenses/debts/tasks/shared/quotes/guests/providers/notifications | good center model |
| `BudgetCategory` | budget buckets | cascades with plan, expenses set null on category delete | ok |
| `Expense` | spending record | plan cascade, optional category set null | ok |
| `Debt` | obligation | plan cascade, installments cascade | ok |
| `Installment` | scheduled payment | debt cascade | ok |
| `WeddingTask` | task/timeline item | plan cascade, optional assignee set null, indexed status/assignee | ok |
| `WeddingTaskChecklistItem` | task checklist | task cascade, indexed sort | ok |
| `SharedMember` | collaboration permissions | unique `(weddingPlanId, userId)`, plan/user cascade | lacks guest view permission |
| `PlanInvite` | invite token flow | unique token, expiry indexes, invitee set null | ok |
| `OtpCode` | OTP verification | hashed code, phone/purpose indexes | ok |
| `NotificationPreference` | notification settings | unique user, cascade | ok |
| `Notification` | user-owned alert | unique dedupeKey, user/plan indexes | ok |
| `Guest` | guest list | unique `(weddingPlanId, normalizedName, normalizedPhone)`, status indexes | uniqueness with nullable phone should be verified under PostgreSQL semantics |
| `GuestGroup` | guest grouping | unique `(weddingPlanId, name)` | ok |
| `City` | Yemen location | unique `(nameAr, countryCode)`, active/sort index | ok |
| `ProviderCategory` | provider category | unique slug, active/sort index | ok |
| `Provider` | provider profile | unique `userId`, status/city/category indexes | status naming differs from UX docs |
| `ProviderService` | provider offering | provider cascade, category/city indexes | ok |
| `ProviderServiceImage` | service image | service cascade | ok |
| `ProviderPackage` | package reference | provider cascade, service set null | ok |
| `FavoriteProvider` | saved provider | unique `(userId, providerId)` | ok |
| `ProviderReview` | provider review | unique `(userId, providerId)` | ok |
| `QuoteRequest` | quote lead | user/provider cascade, plan/service/city set null, status indexes | quote access permission risk |
| `QuoteOffer` | provider offer | quote/provider cascade, status indexes | offer accept/reject permission risk |
| `PlanProviderLink` | accepted/provider link to plan | unique `(weddingPlanId, providerId)` | ok but depends on quote permission |
| `BookingLead` | non-paid lead | user/provider cascade, plan/quote set null | enum has `CONFIRMED` and `COMPLETED`; no endpoint observed |

Important enums:

- Identity: `UserRole`, `UserStatus`, `OnboardingPath`, `WeddingPersona`.
- Plan/money: `WeddingPlanStatus`, `ExpenseStatus`, `DebtStatus`, `InstallmentStatus`.
- Tasks/sharing: `WeddingTaskStatus`, `WeddingTaskPriority`, `SharedMemberRole`.
- Provider/quotes: `ProviderStatus`, `ReviewStatus`, `QuoteRequestStatus`, `QuoteOfferStatus`, `PlanProviderLinkStatus`, `BookingLeadStatus`.
- Notifications/guests: `NotificationType`, `GuestSide`, `GuestStatus`, `GuestInvitationStatus`, `GuestAttendanceStatus`.

Migrations observed:

```text
20260602181910_init_user_model
20260602200934_add_wedding_plan_model
20260602211007_add_budget_expense_models
20260602215807_add_debt_installment_models
20260603205638_add_task_timeline_model
20260603212938_add_shared_members_permissions
20260611182100_add_provider_marketplace_foundation
20260612120000_add_provider_review_workflow
20260618002955_add_creditor_phone_to_debt
20260618180000_add_notifications_guests
20260619090000_prevent_duplicate_guests
20260619121203_add_onboarding_active_plan
20260619123546_add_task_checklist_assignment
20260619124545_add_guest_groups_statuses
20260619125929_add_plan_invites_roles
20260619130835_add_quote_offers_plan_provider_links
20260619131740_add_internal_notification_types
```

Data integrity risks:

- `BookingLeadStatus.CONFIRMED` and `COMPLETED` can be interpreted as confirmed booking lifecycle. There is no observed route exposing this model, but the enum conflicts with the strict MVP wording if activated later without explicit approval.
- Guest duplicate prevention uses nullable `normalizedPhone`. Confirm the migration handles duplicate guest names without phone as intended under PostgreSQL nullable unique behavior.
- Financial sums use JS `Number`; this is not ideal for future finance-heavy calculations.

Mismatch with Product/UX Blueprint:

- Provider/quote backend is now represented in the refreshed `API_CONTRACT.md`; keep future provider/quote route changes synchronized there first.
- Guest list is marked sensitive in security docs, but backend has no view-specific guest permission.
- Quote operations are server/provider actions and should not be broadly available to any readable shared plan member.

## 6. Smoke Coverage

Smoke command bundle:

`npm.cmd run smoke:all` runs:

```text
smoke:health
smoke:auth
smoke:wedding-plan
smoke:onboarding-active-plan
smoke:dashboard-summary
smoke:money-apis
smoke:budget-expense
smoke:debt-installment
smoke:tasks-apis
smoke:task-timeline
smoke:sharing
smoke:sharing-roles
smoke:notifications
smoke:notifications-apis
smoke:guests
smoke:guests-apis
smoke:otp-profile
smoke:marketplace
smoke:providers-quotes
smoke:provider-dashboard
smoke:backend-completion
```

Current run result:

| Smoke script | What it covers | Endpoints covered examples | Current status |
| --- | --- | --- | --- |
| `health-smoke.js` | health | `GET /health` | PASS |
| `auth-smoke.js` | register/login/me auth safety | `/auth/register`, `/auth/login`, `/auth/me` | PASS |
| `wedding-plan-smoke.js` | basic plan CRUD/archive and auth rejection | `/wedding-plans*` | PASS |
| `onboarding-active-plan-smoke.js` | onboarding, active plan, set-active | `/api/v1/onboarding/complete`, `/api/v1/wedding-plans/active`, `/set-active` | PASS |
| `dashboard-summary-smoke.js` | dashboard summary, owner/viewer privacy | `/api/v1/wedding-plans/:id/dashboard-summary` | FAIL |
| `money-apis-smoke.js` | money summary/API v1 finance | not reached in current bundle | Not run in bundle after failure |
| `budget-expense-smoke.js` | budget/expense legacy flows | not reached in current bundle | Not run in bundle after failure |
| `debt-installment-smoke.js` | debts/installments | not reached in current bundle | Not run in bundle after failure |
| `tasks-apis-smoke.js` | tasks/checklist/summary API v1 | not reached in current bundle | Not run in bundle after failure |
| `task-timeline-smoke.js` | timeline | not reached in current bundle | Not run in bundle after failure |
| `sharing-smoke.js` | legacy sharing | not reached in current bundle | Not run in bundle after failure |
| `sharing-roles-smoke.js` | invites/roles/permissions | not reached in current bundle | Not run in bundle after failure |
| `notifications-smoke.js` | notification legacy | not reached in current bundle | Not run in bundle after failure |
| `notifications-apis-smoke.js` | notification API v1/invite/quote notification | not reached in current bundle | Not run in bundle after failure |
| `guests-smoke.js` | guest legacy | not reached in current bundle | Not run in bundle after failure |
| `guests-apis-smoke.js` | guest API v1/groups/bulk | not reached in current bundle | Not run in bundle after failure |
| `otp-profile-smoke.js` | OTP/profile/settings | not reached in current bundle | Not run in bundle after failure |
| `marketplace-smoke.js` | public/provider references/favorites/reviews/quotes | not reached in current bundle | Not run in bundle after failure |
| `providers-quotes-smoke.js` | provider profile/services/quotes/offers | not reached in current bundle | Not run in bundle after failure |
| `provider-dashboard-smoke.js` | provider dashboard | not reached in current bundle | Not run in bundle after failure |
| `backend-completion-smoke.js` | end-to-end backend completion | not reached in current bundle | Not run in bundle after failure |

Dashboard failure details:

```text
FAIL - empty summary importantItems is array
FAIL - empty summary planProviders is array
FAIL - empty summary importantNotifications is array
FAIL - empty summary generatedAt exists
FAIL - summary importantItems includes overdue task
FAIL - summary importantItems includes due installment
FAIL - summary planProviders is array
FAIL - summary importantNotifications is array
Overall Result: FAIL
```

Coverage gaps:

- No `/admin/*` smoke coverage.
- No smoke specifically proving shared viewer cannot create/list/cancel/accept/reject plan quote requests/offers.
- No smoke specifically proving server-side phone normalization.
- No smoke specifically proving guest list visibility is correct for different roles.
- Because `smoke:all` stops at dashboard summary, later script status was not refreshed in this run.

## 7. Flutter API Compatibility

Flutter base client:

- Uses `ApiConfig.baseUrl`.
- Adds `Authorization: Bearer <token>` when token exists.
- Handles JSON map/list responses.
- Cleans `Cannot GET/POST/PATCH/DELETE` into a user-facing unavailable-service message.

Compatibility table:

| Flutter feature | API called | Backend exists? | Auth required? | Model match? | Risk |
| --- | --- | --- | --- | --- | --- |
| Auth login/register/me | `/auth/login`, `/auth/register`, `/auth/me` | Yes | login/register public, me JWT | Yes safe user | Backend phone normalization gap |
| Onboarding active plan | `/api/v1/onboarding/complete`, `/api/v1/wedding-plans/active` | Yes | JWT | Yes | PASS |
| Dashboard summary | `/api/v1/wedding-plans/:id/dashboard-summary` | Source yes, runtime mismatch | JWT | Source expects new fields; runtime failed smoke | P0 |
| Wedding plans | `/wedding-plans/my`, `/wedding-plans/:id`, `/wedding-plans`, patch/archive | Yes | JWT | Yes | PASS |
| Finance | `/wedding-plans/:id/budget-categories`, `/expenses`, summaries | Yes | JWT + finance permissions | Yes | PASS |
| Debts/installments | `/wedding-plans/:id/debts`, `/debts/:id`, `/debts/:id/installments`, `/installments/:id` | Yes | JWT + debt/finance permissions | Yes | Dedicated pay route unused |
| Tasks/timeline | `/wedding-plans/:id/tasks`, `/tasks/:id`, `/timeline` | Yes | JWT + task/read permissions | Yes | Checklist/assign backend-only |
| Guests | `/wedding-plans/:id/guests`, `/guests/:id` | Yes | JWT; readable/manage split | Yes | No guest view permission |
| Sharing | `/wedding-plans/:id/shared-members`, `/shared-members/:id`, `/shared/wedding-plans`, `/users/lookup` | Yes | JWT | Yes | API v1 invites/permissions not used by Flutter |
| Notifications | `/notifications`, `/notifications/unread-count`, `/notifications/:id/read`, delete | Yes | JWT | Yes | Deep-link/push not complete |
| Marketplace browse | `/cities`, `/provider-categories`, `/providers`, provider services/packages/reviews | Yes | Public reads | Yes | PASS |
| Favorites | `/providers/:id/favorite`, `/me/favorite-providers` | Yes | JWT | Yes | Offline queued write must be visibly pending |
| Quote request | `/providers/:id/quote-requests` | Yes | JWT | Yes | Permission risk for plan-linked quotes |
| Provider apply/dashboard | `/provider/apply`, `/provider/me/profile`, `/summary`, `/services`, `/packages`, quote status | Yes | JWT provider owner | Yes | Admin approval coverage missing |

Unused backend endpoints from current Flutter data usage:

- `/installments/:id/pay`
- `/tasks/:id/checklist*`
- `/tasks/:id/assign`
- `/api/v1/wedding-plans/:id/members`, invites, permissions
- `/api/v1/wedding-plans/:id/quote-requests`, `/api/v1/quote-offers/*`
- guest groups/bulk/summary
- provider service images
- admin APIs

Local/fake/offline fallback:

- Flutter queues or caches local writes for plans, finance, debts, installments, tasks, favorites, and quote requests through offline tables/sync queue.
- This is useful, but quote requests and favorite writes are server/provider actions. The UI must clearly show pending sync and must not imply the provider received the request while it is only local.

## 8. Security / Permission Findings

### High - Quote request/offer plan access is too broad

Evidence:

- `backend/src/marketplace/marketplace.service.ts` uses `assertPlanReadable` for creating plan quote requests, listing plan quote requests, and finding plan-linked quote requests/offers.
- Accepting a quote offer mutates `QuoteOffer`, rejects other offers, updates `QuoteRequest`, and upserts `PlanProviderLink`.

Why it matters:

- A shared viewer can potentially view quote budget ranges/messages/offers and accept/reject quote offers for a plan.
- Quote operations are provider-facing plan decisions and should not be available to every readable shared member.

Proposed fix:

- Introduce explicit quote/provider permissions or require owner/manager for plan quote create/list/accept/reject/cancel.
- Add smoke cases for viewer/helper/editor/finance-manager quote permissions.

### High - JWT secret fallback

Evidence:

- `backend/src/auth/auth.module.ts` and `backend/src/auth/jwt.strategy.ts` fall back to `changeme`.
- `backend/.env` currently does not define `JWT_SECRET` based on masked inspection.

Why it matters:

- If a backend process starts without `JWT_SECRET`, tokens can be signed/validated with a predictable secret.

Proposed fix:

- Fail startup when `JWT_SECRET` is missing in non-test runtimes.
- Add `.env.example` docs and a startup config check.

### Medium - Guest list visibility is not permission-based

Evidence:

- `GuestsService.findForPlan` uses `assertPlanReadable`.
- `SharedMember` has manage flags but no `canViewGuests`.

Why it matters:

- Guest names and phone numbers are sensitive collaboration data. Any shared member can read them once added to the plan.

Proposed fix:

- Decide if guests are visible to all plan members. If not, add `canViewGuests` or role-based read rules.

### Medium - Server phone normalization is inconsistent

Evidence:

- Flutter normalizes phones in auth, sharing, guests, debts, and provider apply.
- Backend auth register/login and sharing lookup/member creation use raw DTO phone values.

Why it matters:

- Raw API callers can create duplicate-looking users or failed lookups due to formatting differences.

Proposed fix:

- Centralize Yemeni phone normalization in backend DTO/service layer and use it consistently.

### Medium - Admin APIs lack smoke coverage

Evidence:

- `rg /admin backend/scripts/smoke` returned no admin smoke matches.

Why it matters:

- Provider approval lifecycle is important for marketplace safety and is currently unverified by smoke scripts.

Proposed fix:

- Add admin auth setup plus smoke checks for dashboard stats, provider review transitions, city/category CRUD, and user list/detail.

### Low - Money aggregation uses JS Number

Evidence:

- Several services convert Prisma Decimal strings to `Number()` and format with `.toFixed(2)`.

Why it matters:

- Current values are fine for smoke, but finance-heavy operations should avoid avoidable precision drift.

Proposed fix:

- Use Decimal-safe arithmetic utilities for totals if money volume grows.

## 9. Known Gaps

Real gaps only:

- Runtime backend is not aligned with current dashboard source. `smoke:dashboard-summary` fails.
- Admin APIs are implemented but not smoke-tested.
- Quote permissions are too broad for shared plan members.
- Guest read privacy lacks explicit permission semantics.
- Server-side phone normalization is incomplete.
- Guest-to-auth migration remains mostly a mobile/local strategy; no full backend migration flow was observed.
- Flutter does not yet use guest groups, bulk guest create, permissions summary, invites, checklist items, task assignment, provider images, or admin APIs.
- Notification push/device-token infrastructure is not implemented.
- API docs are partially stale around provider/marketplace inclusion.
- `BookingLead` model exists but no active API endpoint was observed; enum values include confirmed/completed states that need strict phase review before use.

## 10. Recommended Fix Order

P0:

- Align Docker/runtime backend with current source and rerun `npm.cmd run smoke:all`.
- Fix the dashboard summary runtime contract if a rebuild alone does not resolve it.

P1:

- Restrict quote create/list/cancel/accept/reject permissions.
- Add smoke coverage for quote permissions by shared role.
- Require `JWT_SECRET`; remove fallback for real runtimes.
- Add admin smoke coverage.
- Decide and implement guest view privacy rules.

P2:

- Normalize phones server-side across auth/sharing/provider/guest/debt paths.
- Keep `API_CONTRACT.md` synchronized as the route-level source of truth whenever provider-reference or quote-lead routes change.
- Add smoke for server phone normalization.
- Review Decimal arithmetic strategy.
- Document/guard `BookingLead` so it cannot imply paid or confirmed booking behavior without explicit approval.

## 11. Commands Run

| Command | Result |
| --- | --- |
| `git branch --show-current` | PASS: `phase/mobile-home-dashboard-ux-v2` |
| `git status --short` | PASS: clean before audit |
| `git log --oneline -20` | PASS: listed last 20 commits |
| `Get-ChildItem` / `rg --files` inventory commands | PASS |
| `Get-Content` approved docs and backend/mobile files | PASS |
| static route extraction Node command | PASS: 204 route handlers found |
| Prisma/schema grep commands | PASS |
| Flutter API usage extraction Node command | PASS |
| `docker compose ps` | PASS: backend/db healthy |
| `Invoke-RestMethod http://127.0.0.1:3115/health` | PASS: `status=ok`, `service=aarast-backend` |
| `npm.cmd run check` from `backend/` | PASS |
| `npx.cmd prisma validate` from `backend/` | PASS with Prisma 7 deprecation warning for `package.json#prisma` |
| `npm.cmd run smoke:all` from `backend/` | PASS after Docker rebuild; all 21 smoke suites passed |

## 12. Final Verdict

The backend is not ready for the next phase until the dashboard runtime contract and `smoke:all` are fixed.

Source completeness is strong, and local runtime readiness is no longer blocked after the full smoke pass. The dashboard summary issue was an initial stale-runtime failure resolved by Docker rebuild. The most important remaining security/permission blocker is quote access being granted by readable-plan membership instead of a stricter quote/manager permission.

During the 2026-06-20 audit, no backend code was changed and the only intended file change was this report. Later Markdown-only source-of-truth refreshes may add addenda without changing the audit evidence.
