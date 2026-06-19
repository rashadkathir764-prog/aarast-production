# Aarast Backend Full Completion Audit

Date: 2026-06-19
Branch: `phase/mobile-home-dashboard-ux-v2`
Scope: Backend Phase 1 audit and completion plan only.

This document audits the current NestJS/Prisma backend against the mobile product UX rebuild needs. It does not change backend code, Prisma schema, migrations, mobile UI, admin UI, Docker, deployment, or production configuration.

## 1. Current Backend State

### 1.1 Stack

- Runtime: NestJS 11, TypeScript, Node scripts.
- Database: PostgreSQL through Prisma.
- Auth: JWT bearer auth with `JwtAuthGuard`, password login/register, local OTP request/verify support.
- Validation: global Nest `ValidationPipe` with `whitelist` and `forbidNonWhitelisted`.
- Mobile API style: routes are registered without a global `/api/v1` prefix in code. Mobile calls paths such as `/wedding-plans/my` against `AARAST_API_BASE_URL`.
- Smoke coverage: script-based smoke tests exist under `backend/scripts/smoke`. No Jest/unit test files were found in `backend/src` or `backend/test`.

### 1.2 Registered Backend Modules

Current modules in `backend/src/app.module.ts`:

- `PrismaModule`
- `AuthModule`
- `WeddingPlansModule`
- `BudgetCategoriesModule`
- `ExpensesModule`
- `DebtsModule`
- `InstallmentsModule`
- `TasksModule`
- `TimelineModule`
- `SharingModule`
- `UsersModule`
- `MarketplaceModule`
- `ProviderDashboardModule`
- `DashboardModule`
- `NotificationsModule`
- `GuestsModule`
- `AdminModule`

### 1.3 Controllers And Services

Current controllers:

- `health.controller.ts`
- `auth/auth.controller.ts`
- `users/users.controller.ts`
- `wedding-plans/wedding-plans.controller.ts`
- `budget-categories/budget-categories.controller.ts`
- `expenses/expenses.controller.ts`
- `debts/debts.controller.ts`
- `installments/installments.controller.ts`
- `tasks/tasks.controller.ts`
- `timeline/timeline.controller.ts`
- `sharing/sharing.controller.ts`
- `marketplace/marketplace.controller.ts`
- `provider-dashboard/provider-dashboard.controller.ts`
- `dashboard/dashboard.controller.ts`
- `notifications/notifications.controller.ts`
- `guests/guests.controller.ts`
- `admin/admin.controller.ts`

Current domain services mirror the controllers and include shared helper services:

- `auth/auth.service.ts`
- `auth/ownership-context.service.ts`
- `sharing/permission.service.ts`
- `prisma/prisma.service.ts`
- domain services for wedding plans, finance, tasks, timeline, sharing, marketplace, provider dashboard, dashboard, notifications, guests, admin, and users.

### 1.4 Guards And Authorization Foundation

- `JwtAuthGuard` protects private API controllers and route groups.
- `AdminGuard` protects admin routes after JWT auth.
- `PermissionService` centralizes plan access:
  - owner access.
  - shared member readable access.
  - manager-level plan updates.
  - explicit financial read permissions: budget, expenses, debts.
  - explicit financial manage permission.
  - task manage permission.
- Public endpoints currently include health, register/login/OTP request/verify, and public marketplace catalog reads.

### 1.5 DTO Coverage

Class-validator DTOs exist for:

- Auth register/login/OTP.
- User profile/settings.
- Wedding plan create/update.
- Budget category create/update.
- Expense create/update.
- Debt create/update.
- Installment create/update.
- Task create/update.
- Guest create/update.
- Sharing create/update.
- Marketplace provider listing, service listing, quote requests, provider reviews.
- Provider dashboard profile/services/packages/images/quote status.
- Admin catalog and provider review actions.

## 2. Existing Prisma Models

### 2.1 Existing Enums

- `UserRole`: `USER`, `ADMIN`, `PROVIDER`
- `UserStatus`: `ACTIVE`, `DISABLED`
- `WeddingPlanStatus`: `PLANNING`, `ARCHIVED`
- `ExpenseStatus`: `PLANNED`, `PAID`, `CANCELLED`
- `DebtStatus`: `OPEN`, `PARTIALLY_PAID`, `PAID`, `CANCELLED`
- `InstallmentStatus`: `PENDING`, `PAID`, `OVERDUE`, `CANCELLED`
- `WeddingTaskStatus`: `TODO`, `IN_PROGRESS`, `DONE`, `CANCELLED`
- `WeddingTaskPriority`: `LOW`, `MEDIUM`, `HIGH`
- `SharedMemberRole`: `VIEWER`, `CONTRIBUTOR`, `MANAGER`
- `OtpPurpose`: `REGISTER`, `LOGIN`, `VERIFY_PHONE`, `RESET_PASSWORD`
- `ProviderStatus`: `PENDING`, `ACTIVE`, `NEEDS_CHANGES`, `SUSPENDED`, `REJECTED`
- `ReviewStatus`: `PUBLISHED`, `HIDDEN`, `PENDING`
- `QuoteRequestStatus`: `SENT`, `VIEWED`, `RESPONDED`, `ACCEPTED`, `REJECTED`, `CANCELLED`
- `BookingLeadStatus`: `NEW`, `IN_PROGRESS`, `CONFIRMED`, `CANCELLED`, `COMPLETED`
- `NotificationType`: `TASK_DUE_SOON`, `TASK_OVERDUE`, `INSTALLMENT_DUE_SOON`, `INSTALLMENT_OVERDUE`, `SHARING_INVITATION`, `SHARING_UPDATED`, `GENERAL`
- `GuestSide`: `GROOM`, `BRIDE`, `FAMILY`, `FRIEND`, `OTHER`
- `GuestStatus`: `INVITED`, `CONFIRMED`, `DECLINED`, `PENDING`

### 2.2 Existing Models

- Identity and settings: `User`, `OtpCode`, `NotificationPreference`
- Wedding Financial OS: `WeddingPlan`, `BudgetCategory`, `Expense`, `Debt`, `Installment`, `WeddingTask`, `SharedMember`, `Guest`
- Notifications: `Notification`
- Marketplace/provider: `City`, `ProviderCategory`, `Provider`, `ProviderService`, `ProviderServiceImage`, `ProviderPackage`, `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `BookingLead`

### 2.3 Existing Migrations

- `20260602181910_init_user_model`
- `20260602200934_add_wedding_plan_model`
- `20260602211007_add_budget_expense_models`
- `20260602215807_add_debt_installment_models`
- `20260603205638_add_task_timeline_model`
- `20260603212938_add_shared_members_permissions`
- `20260611182100_add_provider_marketplace_foundation`
- `20260612120000_add_provider_review_workflow`
- `20260618002955_add_creditor_phone_to_debt`
- `20260618180000_add_notifications_guests`
- `20260619090000_prevent_duplicate_guests`

No migration was added or modified in this audit phase.

## 3. Existing Endpoints

Paths below are shown as code-level paths, without an `/api/v1` prefix.

### 3.1 Health And Auth

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/otp/request`
- `POST /auth/otp/verify`
- `GET /auth/me`

### 3.2 Users

- `PATCH /users/me`
- `GET /users/lookup?phone=...`
- `GET /users/me/settings`
- `PATCH /users/me/settings`

### 3.3 Wedding Plans

- `POST /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

### 3.4 Budget And Expenses

- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `GET /wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /budget-categories/:id`
- `DELETE /budget-categories/:id`
- `POST /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses/summary`
- `PATCH /expenses/:id`
- `DELETE /expenses/:id`

### 3.5 Debts And Installments

- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `PATCH /debts/:id`
- `DELETE /debts/:id`
- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`
- `PATCH /installments/:id`
- `DELETE /installments/:id`

### 3.6 Tasks And Timeline

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`
- `GET /wedding-plans/:weddingPlanId/timeline`

### 3.7 Sharing

- `POST /wedding-plans/:weddingPlanId/shared-members`
- `GET /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`

### 3.8 Guests

- `GET /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests`
- `PATCH /guests/:id`
- `DELETE /guests/:id`

### 3.9 Public Marketplace

- `GET /cities`
- `GET /provider-categories`
- `GET /providers`
- `GET /providers/:id`
- `GET /providers/:id/services`
- `GET /providers/:id/packages`
- `GET /providers/:id/reviews`
- `GET /services`
- `GET /services/:id`

### 3.10 Authenticated Marketplace

- `POST /providers/:id/favorite`
- `DELETE /providers/:id/favorite`
- `POST /providers/:id/quote-requests`
- `POST /providers/:id/reviews`
- `GET /me/favorite-providers`
- `GET /me/quote-requests`
- `GET /me/quote-requests/:id`
- `PATCH /me/quote-requests/:id/cancel`
- `PATCH /reviews/:id`
- `DELETE /reviews/:id`

### 3.11 Provider Dashboard

- `POST /provider/apply`
- `GET /provider/me/profile`
- `PATCH /provider/me/profile`
- `GET /provider/me/summary`
- `GET /provider/me/services`
- `POST /provider/me/services`
- `GET /provider/me/services/:id`
- `PATCH /provider/me/services/:id`
- `DELETE /provider/me/services/:id`
- `POST /provider/me/services/:id/images`
- `PATCH /provider/me/services/:serviceId/images/:imageId`
- `DELETE /provider/me/services/:serviceId/images/:imageId`
- `GET /provider/me/packages`
- `POST /provider/me/packages`
- `PATCH /provider/me/packages/:id`
- `DELETE /provider/me/packages/:id`
- `GET /provider/me/quote-requests`
- `GET /provider/me/quote-requests/:id`
- `PATCH /provider/me/quote-requests/:id/status`
- `GET /provider/me/reviews`

### 3.12 Dashboard And Notifications

- `GET /dashboard/home`
- `GET /notifications`
- `GET /notifications/unread-count`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `DELETE /notifications/:id`

### 3.13 Admin

- `GET /admin/dashboard/stats`
- `GET /admin/providers/applications`
- `GET /admin/providers/applications/:id`
- `PATCH /admin/providers/:id/approve`
- `PATCH /admin/providers/:id/reject`
- `PATCH /admin/providers/:id/request-changes`
- `PATCH /admin/providers/:id/suspend`
- `PATCH /admin/providers/:id/activate`
- `GET /admin/providers`
- `GET /admin/providers/:id`
- `GET /admin/provider-categories`
- `POST /admin/provider-categories`
- `PATCH /admin/provider-categories/:id`
- `DELETE /admin/provider-categories/:id`
- `GET /admin/cities`
- `POST /admin/cities`
- `PATCH /admin/cities/:id`
- `DELETE /admin/cities/:id`
- `GET /admin/users`
- `GET /admin/users/:id`

## 4. Existing Mobile Contract Read-Only Notes

Mobile currently consumes the existing backend through data classes under `mobile/lib`, including:

- `WeddingPlansApi`: `/wedding-plans/my`, `/wedding-plans/:id`, create/update/archive.
- `BudgetExpenseApi`: budget category and expense endpoints plus expense summary.
- `DebtInstallmentApi`: debt summary, due installments, installment CRUD.
- `TaskTimelineApi`: task CRUD and timeline endpoint.
- `GuestsApi`: guest CRUD.
- `SharingApi`: shared members, user lookup, shared plans.
- `MarketplaceApi`: cities, categories, providers, services, packages, favorites, quote requests.
- `ProviderDashboardApi`: provider profile, services, packages, quote request status, summary.
- `NotificationsApi`: list, unread count, mark read, read all, delete.
- `DashboardSummaryProvider`: currently aggregates multiple existing endpoints client-side for a plan.

Important gap: mobile currently auto-selects a first loaded plan in `MainShell` and has internal/dev guest-onboarding surfaces behind feature flags. There is no backend-owned active plan contract yet.

## 5. Missing Coverage By UX Area

### 5.1 Onboarding

Existing:

- Auth register/login/OTP.
- Mobile has internal guest onboarding draft/skeleton paths behind feature flags.
- `POST /wedding-plans` can create a minimal server plan for authenticated users.

Missing:

- No backend onboarding module.
- No `POST /onboarding/complete`.
- No persisted persona/groom/bride/helper fields.
- No onboarding draft/setup state model.
- No structured priorities persisted on server.
- No aggregate "create plan + categories + starter tasks" transaction endpoint.
- No backend migration path from guest local plan to server plan.

### 5.2 Create Wedding Plan And Active Plan

Existing:

- `WeddingPlan` has title, city string, optional date, optional estimated budget, currency, status, owner.
- `GET /wedding-plans/my` lists owned plans.
- `GET /wedding-plans/:id` is readable by owner/shared member and hides budget when permissions do not allow it.
- `PATCH /wedding-plans/:id/archive` exists.

Missing:

- No `GET /wedding-plans` alias.
- No `GET /wedding-plans/active`.
- No `POST /wedding-plans/:id/set-active`.
- No `activePlanId` on user/profile and no active flag on plan.
- No structured location fields: governorate, district, neighborhood, street, address note.
- No active plan inclusion for shared plans.
- `estimatedBudget` currently accepts negative decimals in `WeddingPlansService`; finance services reject negative amounts.

### 5.3 Dashboard / Today Center

Existing:

- `GET /dashboard/home` returns the first planning plan owned by the user plus budget/expense/debt/due installment/task/member/marketplace summaries.
- Mobile `DashboardSummaryProvider` separately aggregates plan, expense summary, debt summary, due installments, tasks, and members.

Missing:

- No `GET /wedding-plans/:planId/dashboard-summary`.
- Existing `/dashboard/home` is user-owned-plan oriented, not explicit plan-id oriented.
- Existing dashboard summary does not enforce shared-member permission through `PermissionService`.
- Missing requested summary fields: `daysRemaining`, `progressPercentage`, `budgetTotal`, combined `spentTotal`, `remainingBudget`, task counts by overdue/today/done, guest counts, provider count linked to plan, quote request count by plan, unread notifications count by plan, `currentUserRole`, and permissions summary.
- No offline/sync metadata in backend summary response.

### 5.4 Money

Existing:

- Budget category CRUD.
- Expense create/list/update/delete and expense summary.
- Debt create/list/update/delete and debt summary.
- Installment create/list/due/update/delete.
- Financial read/manage permissions are enforced for budget, expenses, and debts.
- Non-negative validation exists in finance services.

Missing:

- No `GET /expenses/:id`.
- No `GET /debts/:id`.
- No dedicated `PATCH /installments/:id/pay`.
- No aggregate `GET /wedding-plans/:planId/money-summary`.
- No `Creditor` model.
- No `PaymentRecord` model.
- No attachment/receipt model.
- No soft delete fields for finance records; deletes are hard deletes.
- Expense/debt/installment records do not link to provider, service, quote, package, or future plan provider.

### 5.5 Tasks

Existing:

- Task create/list/update/delete.
- Timeline endpoint includes upcoming tasks and financial due items where debt permissions allow.
- Task write permissions support owner, manager, or `canManageTasks`.

Missing:

- No `GET /tasks/:id`.
- No `GET /wedding-plans/:planId/tasks/summary`.
- No checklist item model or endpoints.
- No task assignment model or endpoint.
- No `URGENT` priority enum.
- No task comments.
- No generated task templates endpoint.
- No assignee/member relation.

### 5.6 Guests

Existing:

- Guest create/list/update/delete.
- Guest uniqueness exists by plan, normalized name, and normalized phone.
- Yemeni phone normalization exists.
- Plan manager/owner can mutate guests; readable by plan-readable users.

Missing:

- No `GET /guests/:id`.
- No `POST /wedding-plans/:planId/guests/bulk`.
- No guest groups.
- No guest companions.
- No `GET /wedding-plans/:planId/guests/summary`.
- No dedicated guest permissions such as `canViewGuests` or `canManageGuests`.
- Duplicate protection only applies when phone is present and pairs name+phone.

### 5.7 Sharing, Roles, And Permissions

Existing:

- Direct registered-user sharing by phone or user id.
- Roles: `VIEWER`, `CONTRIBUTOR`, `MANAGER`.
- Explicit permission booleans: budget, expenses, debts, task management, financial record management.
- Sharing notifications are created on member add/update.
- Owners manage shared members.

Missing:

- No `PlanInvite` model.
- No invite token flow.
- No `GET /invites/:token`.
- No `POST /invites/:token/accept`.
- No `GET /wedding-plans/:planId/permissions/me`.
- Requested roles `OWNER`, `EDITOR`, `FINANCE_MANAGER`, and `HELPER` are not modeled as plan roles; ownership is represented by `WeddingPlan.ownerUserId`, and finance behavior is represented by booleans.
- No explicit owner protection endpoint is needed for self-removal today because owners are not `SharedMember` rows, but future member endpoints must preserve last-owner protection if owner transfer is added.

### 5.8 Providers And Quote Requests

Existing:

- Public provider, service, package, city, and category listing.
- Provider profile application and management.
- Provider-owned services, images, packages.
- User favorite providers and reviews.
- User creates quote requests through `POST /providers/:id/quote-requests`.
- User lists/cancels own quote requests.
- Provider lists quote requests and updates request status.

Missing:

- No wedding-plan-scoped quote request list: `GET /wedding-plans/:planId/quote-requests`.
- No `POST /wedding-plans/:planId/quote-requests` path.
- No `QuoteOffer` model.
- No provider offer create/update endpoints.
- No quote offer accept/reject endpoints.
- No `PlanProviderLink` / `PlanProvider` model.
- Accepting a quote does not link provider to plan.
- Provider service areas are not normalized beyond city/address/optional coordinates.
- No provider quote notification generation was found in the quote request/status flow.
- `BookingLeadStatus.CONFIRMED` exists in schema and must remain lead-only; it can be confusing against the no-confirmed-bookings MVP boundary.

### 5.9 Notifications

Existing:

- Notification list, unread count, mark read, read all, delete.
- Internal due task/installment notifications are generated when listing/counting notifications.
- Sharing add/update creates notifications.
- Dedupe keys exist.

Missing:

- No `GET /notifications/:id`.
- No typed `sourceType`, `sourceId`, or `deepLink` columns; data is JSON only.
- Missing notification types for quote status, budget exceeded, debt overdue, member joined, permission changed, guest confirmed, sync failed.
- No device token model or push infrastructure.
- No guest/local notification server model.
- Financial notification body can include installment amount when the current user has debt permission; any future sharing expansion must continue avoiding leaks.

### 5.10 Provider Path

Existing:

- Provider application/profile/service/package/quote dashboard exists.
- User role is updated to `PROVIDER` after provider application.
- Admin can approve/reject/request changes/suspend/activate providers.

Missing:

- No separate provider navigation contract in backend is required, but backend lacks service-area granularity and quote offers.
- Provider status does not include a distinct `VERIFIED` enum value.
- Provider cannot send structured offers, only update request status.

## 6. Required Endpoints For Full Completion

The requested new contracts should be added without breaking existing paths. Prefer adding aliases or new endpoints while preserving current mobile/admin consumers.

### 6.1 Phase 2: Onboarding And Active Plan

- `GET /me` or alias to existing `GET /auth/me`.
- `GET /wedding-plans` or alias to existing `GET /wedding-plans/my`.
- `POST /wedding-plans`
- `GET /wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `POST /onboarding/complete`

### 6.2 Phase 3: Dashboard Summary

- `GET /wedding-plans/:planId/dashboard-summary`

### 6.3 Phase 4: Money

- Existing finance endpoints should be preserved.
- Add:
  - `GET /expenses/:id`
  - `GET /debts/:id`
  - `PATCH /installments/:id/pay`
  - `GET /wedding-plans/:planId/money-summary`

### 6.4 Phase 5: Tasks

- Add:
  - `GET /tasks/:id`
  - `POST /tasks/:id/checklist`
  - `PATCH /tasks/:id/checklist/:itemId`
  - `DELETE /tasks/:id/checklist/:itemId`
  - `PATCH /tasks/:id/assign`
  - `GET /wedding-plans/:planId/tasks/summary`

### 6.5 Phase 6: Guests

- Add:
  - `GET /guests/:id`
  - `POST /wedding-plans/:planId/guests/bulk`
  - `GET /wedding-plans/:planId/guest-groups`
  - `POST /wedding-plans/:planId/guest-groups`
  - `PATCH /guest-groups/:id`
  - `DELETE /guest-groups/:id`
  - `GET /wedding-plans/:planId/guests/summary`

### 6.6 Phase 7: Sharing

- Add:
  - `GET /wedding-plans/:planId/members` as alias or replacement for shared members.
  - `POST /wedding-plans/:planId/invites`
  - `GET /invites/:token`
  - `POST /invites/:token/accept`
  - `PATCH /wedding-plans/:planId/members/:memberId`
  - `DELETE /wedding-plans/:planId/members/:memberId`
  - `GET /wedding-plans/:planId/permissions/me`

### 6.7 Phase 8: Providers And Quotes

- Preserve existing public/provider dashboard routes.
- Add plan-scoped quote routes:
  - `POST /wedding-plans/:planId/quote-requests`
  - `GET /wedding-plans/:planId/quote-requests`
  - `GET /quote-requests/:id`
  - `PATCH /quote-requests/:id/cancel`
- Add provider offer routes:
  - `GET /provider/quote-requests`
  - `GET /provider/quote-requests/:id`
  - `POST /provider/quote-requests/:id/offers`
  - `PATCH /provider/quote-offers/:id`
  - `PATCH /quote-offers/:id/accept`
  - `PATCH /quote-offers/:id/reject`

### 6.8 Phase 9: Notifications

- Preserve existing notification routes.
- Add:
  - `GET /notifications/:id`
  - typed/deep-link-compatible response fields.
- Add event generation for:
  - invite received/accepted.
  - quote offer received/status changed.
  - installment due soon/overdue.
  - task overdue.
  - member accepted invite.

## 7. Required Migrations

No migrations are required for Phase 1. Future phases likely need these migration groups:

### 7.1 Phase 2 Migration Group: Persona, Setup, And Active Plan

Options:

- Add `UserProfile` with persona/default location/active plan relation.
- Or add profile fields to `User`.
- Add active plan support through `User.activeWeddingPlanId` or a unique active flag per user/plan.
- Add onboarding/setup metadata if server-backed:
  - persona.
  - priorities JSON.
  - selected category preset keys.
  - setup completion timestamp.
- Add structured plan location fields or defer to Phase 8 location migration if the first cut only maps to current `city`.

### 7.2 Phase 3 Migration Group: Summary Support

Prefer no table at first. Compute from existing models. Add indexes only if summary queries become slow:

- `WeddingTask(weddingPlanId, status, dueDate)`
- `Debt(weddingPlanId, status, dueDate)`
- `Expense(weddingPlanId, status)`
- `Notification(userId, weddingPlanId, readAt)`
- `QuoteRequest(weddingPlanId, status)`

### 7.3 Phase 4 Migration Group: Money Completion

Potential models/fields:

- `Creditor`
- `PaymentRecord` if a payment-history audit trail is needed.
- soft delete fields: `deletedAt` for budget categories, expenses, debts, installments.
- optional provider/quote references on expenses/debts after `PlanProvider` exists.
- attachment model later only after upload/storage plan.

### 7.4 Phase 5 Migration Group: Task Completion

- `TaskChecklistItem`
- `TaskAssignment`
- optional `TaskComment`
- `URGENT` task priority enum value.
- optional task template seed table if templates should be server-managed.

### 7.5 Phase 6 Migration Group: Guests Completion

- `GuestGroup`
- `GuestCompanion`
- optional guest source/import metadata.
- optional guest permission fields on `SharedMember`.

### 7.6 Phase 7 Migration Group: Invites And Permission Summary

- `PlanInvite`
- invite token/hash, expiry, status, inviter, acceptedAt.
- optional expanded role enum or keep current roles plus permission presets.
- optional sharing permissions: `canViewGuests`, `canManageGuests`, `canManageProviders`, `canViewLocation`, `canManageSharing`.

### 7.7 Phase 8 Migration Group: Provider Quotes To Plan

- `QuoteOffer`
- `PlanProvider` / `PlanProviderLink`
- provider service areas.
- optional expense/debt links to plan provider, provider, quote offer, service, or package.

### 7.8 Phase 9 Migration Group: Notifications

- extend `NotificationType`.
- add `sourceType`, `sourceId`, `deepLink` columns or standardize JSON shape first.
- add device token model only when push is explicitly approved.

## 8. Risks

### 8.1 Scope And Phase Risks

- The requested full backend completion spans many phases and should not be implemented in a single migration or commit.
- Existing mobile code consumes current routes. Replacing paths instead of adding compatible routes would break mobile.
- The code has no global `/api/v1` prefix. Introducing one globally without compatibility would break current clients.

### 8.2 Privacy Risks

- Financial data must remain private by permission, including summaries and notifications.
- Dashboard summary must be permission-aware, not just detail endpoints.
- Provider quote flow must not expose full plan, budget, debts, guests, or shared members to providers.
- Guest list visibility needs a clear permission decision before adding guest manager roles.

### 8.3 Product Boundary Risks

- No payments, deposits, subscriptions, AI, maps, loans, credit, financing, or confirmed booking flow should be added.
- `BookingLeadStatus.CONFIRMED` can conflict with the no-confirmed-booking rule and must be treated as lead-only until renamed or gated.

### 8.4 Data And Migration Risks

- Active plan state needs a single source of truth. Mobile currently auto-selects the first loaded plan.
- Guest-first local plan migration can create duplicates if not idempotent.
- Adding soft deletes later changes existing hard-delete assumptions.
- Adding enum values requires careful Prisma migration handling and tests.

### 8.5 Test Risks

- Current coverage is mostly smoke scripts; no unit/integration test files were found.
- New permission-sensitive endpoints need tests before moving to the next phase.
- `npm run smoke:all` depends on a running local backend/database environment.

### 8.6 Security Risks

- `JwtStrategy` falls back to `JWT_SECRET ?? 'changeme'`; production/staging must always set a real secret.
- Notifications currently create due installment bodies with amounts for users who can read debts. Future shared roles must keep this check intact.

## 9. Phased Execution Plan

### Phase 2: Onboarding + Active Plan

Goal:

- Add authenticated onboarding completion and active plan support without breaking existing `/wedding-plans/my`.

Suggested implementation:

- Add active plan source on user/profile.
- Add `GET /me` alias if needed.
- Add `GET /wedding-plans` alias if needed.
- Add `GET /wedding-plans/active`.
- Add `POST /wedding-plans/:id/set-active`.
- Add `POST /onboarding/complete` as a transaction:
  - validate user.
  - create/update profile/persona/setup metadata.
  - create real `WeddingPlan`.
  - create selected starter `BudgetCategory` records.
  - optionally create starter tasks only if templates are ready.
  - set active plan.
  - return real plan id.
- Tests/smoke:
  - unauthorized blocked.
  - create plan.
  - active plan.
  - complete onboarding returns a real plan id.
  - user cannot access another user's plan.

### Phase 3: Dashboard Summary

Goal:

- Add one permission-aware plan summary endpoint for the new mobile Today Center.

Suggested implementation:

- Add `GET /wedding-plans/:planId/dashboard-summary`.
- Use `PermissionService.assertPlanReadable`.
- Return zero values from real empty aggregates, never fake data.
- Hide financial fields when permissions deny access.
- Include role/permission summary.
- Include unread notification count filtered by user and plan.
- Preserve `/dashboard/home`.

### Phase 4: Money APIs

Goal:

- Complete money aggregate and detail endpoints while preserving current finance routes.

Suggested implementation:

- Add `GET /expenses/:id`, `GET /debts/:id`, `PATCH /installments/:id/pay`, and `GET /wedding-plans/:planId/money-summary`.
- Decide whether to add soft delete now or keep current hard deletes and document the limitation.
- Keep negative amount validation.
- Keep financial permission checks per summary and detail route.

### Phase 5: Tasks APIs

Goal:

- Add detail, checklist, assignment, and summary support.

Suggested implementation:

- Add checklist and assignment models if approved.
- Add task summary calculations for total, done, overdue, today.
- Add permission checks for assignment and writes.
- Preserve current task CRUD and timeline.

### Phase 6: Guests APIs

Goal:

- Add bulk, groups, detail, and summary.

Suggested implementation:

- Add `GuestGroup` first, then optional companions.
- Add summary endpoint.
- Add bulk import endpoint that accepts selected contacts only.
- Decide guest read/write permission fields before exposing to shared users.

### Phase 7: Sharing + Roles + Permissions

Goal:

- Add invite token flow and explicit permission summary.

Suggested implementation:

- Keep existing direct sharing endpoints for compatibility.
- Add `PlanInvite`.
- Add invite accept flow.
- Add `permissions/me`.
- Map product roles to current roles plus booleans or migrate role enum carefully.

### Phase 8: Providers + Quote Requests

Goal:

- Move from quote request status only to structured offers and plan-provider links.

Suggested implementation:

- Keep public/provider dashboard routes.
- Add plan-scoped quote routes.
- Add `QuoteOffer`.
- Add `PlanProvider`.
- On accepted offer, link provider to plan.
- Create user notifications when provider sends/updates offer.
- Do not add payments, deposits, confirmed booking, or subscriptions.

### Phase 9: Notifications

Goal:

- Make notifications actionable and source-linked.

Suggested implementation:

- Add missing notification types.
- Add source/deep link fields or standardize JSON payloads.
- Add `GET /notifications/:id`.
- Add event creation from invites, quote offers, installment/task due jobs, and member accept.
- No push permission or FCM/device tokens unless explicitly approved.

### Phase 10: Smoke + Seed + Final Report

Goal:

- Add completion smoke coverage and seed data for development only.

Suggested implementation:

- Extend `backend/scripts/smoke/all-smoke.js`.
- Add focused smoke scripts for new endpoints.
- Add dev seed data only:
  - user.
  - wedding plan.
  - budget categories.
  - tasks.
  - guests.
  - providers.
  - quote request.
  - notifications.
- Add final backend completion report with endpoints, migrations, tests, known gaps, and mobile integration order.

## 10. Phase 1 Verification Notes

Initial required checks:

- `git branch --show-current`: `phase/mobile-home-dashboard-ux-v2`
- `git status --short`: clean before Phase 1 edits.
- `git log --oneline -10`: inspected before edits.

Phase 1 file changes:

- Added this audit document only.

No backend code, Prisma schema, migrations, mobile UI, admin UI, Docker, deployment, package installation, or production config changes were made in Phase 1.
