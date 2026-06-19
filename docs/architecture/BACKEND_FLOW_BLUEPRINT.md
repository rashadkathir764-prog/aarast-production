# Aarast Backend Flow Blueprint

Date: 2026-06-19
Stage: Backend Flow Blueprint
Status: Planning document only

## 1. Scope

This document defines backend flow expectations for the mobile product/UX rebuild. It is intentionally planning-level and does not change NestJS modules, Prisma schema, routes, migrations, or smoke tests.

The current backend already contains MVP routes for auth, wedding plans, finance, debts, installments, tasks, timeline, sharing, guests, notifications, OTP/profile, marketplace, and provider dashboard. Future changes must preserve working contracts unless a migration/API plan explicitly replaces them.

## 2. Flow Principles

- WeddingPlan remains the center of the user product.
- Authenticated ownership is required for server-owned private data.
- Guest-first starts local; server persistence begins at account gate.
- Shared members see only data allowed by explicit permissions.
- Provider interactions are quote/lead planning flows, not payment or confirmed booking flows.
- Backend errors must be specific enough for Arabic UX messages.
- Events should be emitted or logged at key domain transitions even if analytics implementation comes later.

## 3. Onboarding Flow

### Goal

Convert guest onboarding data into either a local generated plan or an authenticated server plan.

### Planning steps

1. Mobile collects:
   - path: wedding user or provider.
   - persona.
   - location.
   - wedding date.
   - priorities.
   - budget.
   - selected categories.
2. If user is guest:
   - store locally.
   - create local generated dashboard.
   - do not call private backend plan APIs yet.
3. If user is authenticated:
   - create server `WeddingPlan`.
   - create selected `BudgetCategory` records.
   - create starter `WeddingTask` records when task templates are implemented.
4. Return or build dashboard summary.

### Suggested endpoint shape

Existing compatible path:

- `POST /wedding-plans`
- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `POST /wedding-plans/:weddingPlanId/tasks`

Future aggregate endpoint if approved:

```http
POST /onboarding/wedding-plan
```

Request planning shape:

```json
{
  "persona": "BRIDE",
  "location": {
    "governorate": "Sanaa",
    "city": "Sanaa",
    "district": "Al-Sabeen",
    "neighborhood": "Hadda",
    "street": "optional",
    "addressNote": "optional"
  },
  "weddingDate": "2026-12-25",
  "priorities": ["budget", "tasks", "providers"],
  "budget": {
    "estimatedBudget": "1500000.00",
    "currency": "YER"
  },
  "categoryPresetKeys": ["hall", "food", "photography"]
}
```

Response planning shape:

```json
{
  "weddingPlan": {},
  "budgetCategories": [],
  "starterTasks": [],
  "dashboardSummary": {}
}
```

### Permissions

- Guest local path: no backend permission.
- Server path: authenticated user becomes owner.

### Errors

- `401`: login required for server plan creation.
- `400`: invalid date/budget/category.
- `409`: duplicate migration/import request if idempotency is later added.

### Events

- `onboarding_started`
- `path_selected`
- `persona_selected`
- `location_saved`
- `wedding_date_saved`
- `priorities_saved`
- `plan_created`
- `dashboard_generated`

## 4. Create Plan Flow

### Current MVP

Current `POST /wedding-plans` creates a plan with:

- title.
- city.
- wedding date.
- estimated budget.
- currency.

### Required rebuild behavior

Create plan should become the final step of onboarding or a deliberate action from Plans/More. It must not be an isolated minimal form in the primary UX.

### Endpoint suggestions

Keep:

- `POST /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

Future:

- `POST /wedding-plans/:id/setup/categories`
- `POST /wedding-plans/:id/setup/tasks`
- `GET /wedding-plans/:id/summary`

### Permissions

- Owner can create/update/archive.
- Shared manager may update limited plan fields only if approved.
- Shared viewer reads basic plan data only.

### Errors

- Not found style response for inaccessible private plan.
- Validation errors for invalid budget/date/currency.

### Events

- `plan_created`
- `plan_updated`
- `plan_archived`
- `current_plan_selected`

## 5. Provider Quote Flow

### Current MVP

Current backend has:

- Public provider/service/package listing.
- Authenticated favorite providers.
- `POST /providers/:id/quote-requests`.
- User quote request reads/cancel.
- Provider dashboard quote request reads/status update.

### Required rebuild flow

1. User opens Providers or Provider Detail.
2. User requests quote.
3. If guest, auth gate appears before request.
4. Backend creates `QuoteRequest` tied to user and optional `WeddingPlan`.
5. Provider reads request in provider dashboard.
6. Provider marks viewed/responded/rejected.
7. Backend creates notification for user.
8. Future: provider sends structured `QuoteOffer`.
9. Future: user accepts offer and backend creates `PlanProvider`.
10. Future: plan provider can link to expense/debt/installment.

### Endpoint suggestions

Existing:

- `POST /providers/:id/quote-requests`
- `GET /me/quote-requests`
- `GET /me/quote-requests/:id`
- `PATCH /me/quote-requests/:id/cancel`
- `GET /provider/me/quote-requests`
- `PATCH /provider/me/quote-requests/:quoteRequestId/status`

Future:

- `POST /provider/me/quote-requests/:id/offers`
- `GET /me/quote-requests/:id/offers`
- `POST /me/quote-offers/:id/accept`
- `POST /wedding-plans/:id/plan-providers`

### Request planning shape

```json
{
  "weddingPlanId": "plan_id",
  "serviceId": "service_id",
  "eventDate": "2026-12-25",
  "cityId": "city_id",
  "guestCount": 300,
  "budgetMin": "500000.00",
  "budgetMax": "800000.00",
  "message": "نحتاج عرض قاعة مع عشاء"
}
```

### Permissions

- User must own or be allowed to manage provider requests for plan.
- Provider can see only requests for their provider profile.
- Provider cannot see full budget/debts/guest list unless submitted in request fields.

### Errors

- `401`: auth required.
- `403`: user cannot request quote for this plan.
- `404`: provider/service unavailable.
- `409`: duplicate active request if duplicate prevention is approved.

### Events

- `quote_request_created`
- `quote_request_viewed`
- `quote_status_changed`
- `quote_offer_sent`
- `quote_offer_accepted`
- `plan_provider_created`

## 6. Money Flow

### Current MVP

Current backend supports:

- Budget categories.
- Expenses.
- Expense summary.
- Debts.
- Debt summary.
- Installments.
- Due installments.

### Required rebuild behavior

Money should be one backend-supported domain for:

- Budget.
- Categories.
- Expenses.
- Debts.
- Installments.
- Provider-linked costs later.

### Endpoint suggestions

Existing:

- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `GET /wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /budget-categories/:id`
- `DELETE /budget-categories/:id`
- `POST /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses/summary`
- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`

Future:

- `GET /wedding-plans/:id/money/summary`
- `POST /wedding-plans/:id/money/from-quote-offer`

### Permissions

- Owner can read/write.
- Shared member needs explicit finance permission.
- `canViewBudget`, `canViewExpenses`, `canViewDebts`, and `canManageFinancialRecords` must be respected separately.

### Errors

- Financial access denied must not leak amounts.
- Invalid decimals must return validation error.
- Deleted/missing category should not orphan user UX silently.

### Events

- `budget_category_created`
- `expense_created`
- `expense_updated`
- `debt_created`
- `installment_created`
- `installment_due`
- `budget_exceeded`

## 7. Debt And Installment Flow

### Flow

1. User opens Money.
2. User creates debt with creditor/provider/person.
3. User creates installments under debt.
4. Backend calculates summary and due installment list.
5. Notification service creates due/overdue alerts.
6. Dashboard reads only the summary source.

### Request planning shape

Debt:

```json
{
  "creditorName": "قاعة النور",
  "creditorPhone": "+967700000000",
  "title": "باقي القاعة",
  "totalAmount": "300000.00",
  "paidAmount": "50000.00",
  "dueDate": "2026-12-20",
  "note": "optional"
}
```

Installment:

```json
{
  "amount": "100000.00",
  "dueDate": "2026-10-01",
  "status": "PENDING",
  "note": "optional"
}
```

### Permissions

- Same financial permission rules as Money.

### Events

- `debt_created`
- `debt_paid`
- `installment_created`
- `installment_paid`
- `installment_overdue`

## 8. Task Flow

### Current MVP

Current backend supports task CRUD and a timeline endpoint.

### Required rebuild behavior

Tasks should be generated from wedding date and templates, then managed manually.

### Endpoint suggestions

Existing:

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`
- `GET /wedding-plans/:weddingPlanId/timeline`

Future:

- `POST /wedding-plans/:id/tasks/generate-from-template`
- `GET /task-templates`
- `PATCH /tasks/:id/assign`

### Permissions

- Owner can manage.
- Shared member can list tasks.
- Shared member can write only with task permission or manager role.

### Errors

- Invalid due date.
- Missing plan access.
- Attempt to modify task without permission.

### Events

- `task_created`
- `task_completed`
- `task_reopened`
- `task_overdue`
- `task_assigned`

## 9. Guest Flow

### Current MVP

Current backend supports guest create/list/update/delete under a plan.

### Required rebuild behavior

Guests must support:

- Manual add/edit/delete.
- Phone normalization.
- Duplicate prevention.
- Side/status/seats.
- Later selected contact import only.

### Endpoint suggestions

Existing:

- `GET /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests`
- `PATCH /guests/:id`
- `DELETE /guests/:id`

Future:

- `POST /wedding-plans/:id/guests/import-selected`
- `GET /wedding-plans/:id/guests/summary`

### Permissions

- Owner/manager can create/update/delete.
- Guest manager permission may be added later.
- Viewer access should be explicit if guest privacy becomes sensitive.

### Errors

- Duplicate guest by normalized name/phone.
- Invalid phone.
- Missing plan access.

### Events

- `guest_created`
- `guest_status_changed`
- `guest_deleted`

## 10. Sharing Flow

### Current MVP

Current backend supports adding registered users by phone or userId, listing, updating, deleting shared members, and reading shared plans.

### Required rebuild behavior

Sharing must be a privacy-first flow with explicit permissions and safe display data.

### Endpoint suggestions

Existing:

- `POST /wedding-plans/:weddingPlanId/shared-members`
- `GET /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`

Future:

- `GET /wedding-plans/:id/permission-presets`
- `POST /wedding-plans/:id/shared-members/preview-permissions`

### Permissions

- Owner manages sharing.
- Shared members do not manage sharing unless a future explicit permission exists.
- Financial access booleans must not be inferred from role alone.

### Errors

- Unknown phone.
- Duplicate member.
- Owner adding self.
- Both phone and userId supplied.
- Missing owner permission.

### Events

- `member_invited`
- `member_added`
- `member_permission_changed`
- `member_removed`

## 11. Notification Flow

### Current MVP

Current backend supports listing, unread count, mark read, read all, and delete.

### Required rebuild behavior

Notifications must be source-linked and actionable.

### Endpoint suggestions

Existing:

- `GET /notifications`
- `GET /notifications/unread-count`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `DELETE /notifications/:id`

Future:

- `POST /devices/push-tokens`
- `DELETE /devices/push-tokens/:id`
- `GET /notifications/:id/resolve-target`

### Notification payload planning shape

```json
{
  "type": "QUOTE_RECEIVED",
  "title": "وصل عرض سعر جديد",
  "body": "لديك تحديث على طلب القاعة.",
  "sourceType": "quote_request",
  "sourceId": "quote_id",
  "deepLink": "/quote-requests/quote_id",
  "data": {
    "weddingPlanId": "plan_id"
  }
}
```

### Permissions

- Notification owner only.
- Deep link target must re-check plan/resource access.
- Financial notification previews must avoid leaking amounts to unauthorized users.

### Events

- `notification_created`
- `notification_read`
- `notification_deleted`
- `push_permission_requested`
- `push_token_registered`

## 12. Common Error Contract

Mobile needs predictable error shape. Current backend can preserve its current behavior, but future standardization should include:

```json
{
  "message": "Arabic or translatable error message",
  "code": "PLAN_ACCESS_DENIED",
  "details": {}
}
```

Required UX mapping:

- `AUTH_REQUIRED`: show auth gate and resume action.
- `PLAN_REQUIRED`: show create/choose plan action.
- `FINANCE_PERMISSION_REQUIRED`: show locked financial state.
- `TASK_PERMISSION_REQUIRED`: show permission message.
- `PROVIDER_STATUS_REQUIRED`: show provider status explanation.
- `OFFLINE_UNAVAILABLE`: explain server/online requirement.
- `VALIDATION_ERROR`: highlight fields.

## 13. Backend Events

Events should be logged/emitted around important transitions:

- `onboarding_started`
- `onboarding_completed`
- `role_selected`
- `persona_selected`
- `plan_created`
- `current_plan_selected`
- `expense_created`
- `debt_created`
- `installment_created`
- `task_created`
- `task_completed`
- `guest_created`
- `quote_request_created`
- `quote_status_changed`
- `quote_offer_sent`
- `quote_offer_accepted`
- `notification_created`
- `sharing_member_added`
- `permission_changed`
- `sync_failed`
- `auth_gate_shown`
- `provider_profile_submitted`

These events can support observability and analytics later. Do not implement analytics in this stage.

## 14. Acceptance Criteria

- Onboarding flow is defined.
- Create plan flow is defined.
- Provider quote flow is defined.
- Money, debt/installment, task, guest, sharing, and notification flows are defined.
- Endpoint suggestions and request/response planning shapes are included.
- Permissions, errors, and events are documented.
- No backend, Prisma, migration, mobile, admin, Docker, or deployment code is changed.

## 15. Risks

- Creating aggregate onboarding endpoints too early can duplicate existing stable APIs.
- Quote offer and plan provider need schema work; do not implement before migration plan.
- Error-code standardization can touch many endpoints and needs tests.
- Notification deep links require route guards and data permissions.
- Guest migration needs local/offline planning before server code.

## 16. Next Implementation Notes

- Next stage: `docs/architecture/AUTH_GUEST_STRATEGY.md`.
- Keep current backend contract stable until API and mobile implementation plans approve changes.
- Smoke tests must be updated before any backend behavior change.

