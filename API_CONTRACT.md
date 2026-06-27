# API Contract

This document is the route-level source of truth for the current Aarast backend contract. Other Markdown files should link here instead of copying endpoint lists.

Current documentation snapshot: 2026-06-21.

Source status:

- Backend source contains the Wedding Financial OS API surface plus provider-reference and quote-lead support.
- `docs/backend/BACKEND_COMPLETION_FINAL_REPORT.md` records a 2026-06-19 local PASS for backend completion smoke and full smoke.
- `docs/backend/BACKEND_API_FULL_AUDIT_REPORT.md` records a later 2026-06-20 Docker runtime/source mismatch in dashboard summary smoke. Treat source contract completeness and local runtime readiness as separate until the runtime is rebuilt/restarted and smoke checks are rerun.
- Provider/quote routes are planning and lead workflows only. They are not paid marketplace, payment, deposit, or confirmed booking flows.

## Base URL

Local backend example:

```text
http://127.0.0.1:3115
```

The current backend does not configure a global `/api` prefix. Flutter clients should call routes directly from the base URL, for example `GET /health` and `POST /auth/login`.

## Common Rules

- JSON request and response bodies are used for API routes.
- Protected routes require `Authorization: Bearer <accessToken>`.
- Private resources use ownership and sharing checks.
- Some unauthorized private-resource access is intentionally returned as not found style behavior.
- `passwordHash` is never returned.
- Owner user objects are not exposed in WeddingPlan responses.
- Financial visibility is private by default and controlled by owner access or explicit sharing permissions.
- Direct legacy routes and `/api/v1` aliases coexist for many current modules. Existing mobile consumers may continue using direct routes while new rebuild work should prefer the documented `/api/v1` route where present.

## Auth

### `POST /auth/register`

Request:

```json
{
  "name": "Rashad",
  "phone": "+967700000000",
  "email": "optional@example.com",
  "password": "secret123"
}
```

Response:

```json
{
  "accessToken": "jwt-token",
  "user": {
    "id": "user_id",
    "name": "Rashad",
    "phone": "+967700000000",
    "email": "optional@example.com",
    "role": "USER",
    "status": "ACTIVE",
    "createdAt": "2026-06-04T00:00:00.000Z",
    "updatedAt": "2026-06-04T00:00:00.000Z"
  }
}
```

### `POST /auth/login`

Request:

```json
{
  "phone": "+967700000000",
  "password": "secret123"
}
```

Response shape matches register.

### `GET /auth/me`

Requires JWT. Returns the safe current user object without `passwordHash`.

Additional current auth/profile routes:

- `POST /auth/otp/request`
- `POST /auth/otp/verify`
- `PATCH /users/me`
- `GET /users/lookup?phone=<phone>`
- `GET /users/me/settings`
- `PATCH /users/me/settings`
- `GET /me`
- `GET /api/v1/me`

OTP/profile routes are account and settings helpers. They do not add payment, booking, financing, AI, or chat behavior.

## Wedding Plans

Protected routes:

- `POST /wedding-plans`
- `GET /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

Current `/api/v1/wedding-plans` aliases exist for the same create/list/my/active/set-active/get/update/archive surface.

Create request:

```json
{
  "title": "Wedding Plan",
  "city": "Sanaa",
  "weddingDate": "2026-12-25T00:00:00.000Z",
  "estimatedBudget": "1500000.00",
  "currency": "YER"
}
```

Response:

```json
{
  "id": "plan_id",
  "ownerUserId": "user_id",
  "title": "Wedding Plan",
  "city": "Sanaa",
  "weddingDate": "2026-12-25T00:00:00.000Z",
  "estimatedBudget": "1500000.00",
  "currency": "YER",
  "status": "PLANNING",
  "createdAt": "2026-06-04T00:00:00.000Z",
  "updatedAt": "2026-06-04T00:00:00.000Z"
}
```

Shared members can read basic plan info. Updating or archiving requires owner access or manager-style sharing permission.

## Onboarding And Active Plan

Protected routes:

- `POST /onboarding/complete`
- `POST /api/v1/onboarding/complete`
- `GET /wedding-plans/active`
- `GET /api/v1/wedding-plans/active`
- `POST /wedding-plans/:id/set-active`
- `POST /api/v1/wedding-plans/:id/set-active`

Onboarding completion creates real server-owned plan data, selected budget categories, and active-plan state for an authenticated user. Guest-first mobile drafts remain a mobile/local strategy until the user reaches an account gate.

## WeddingPlan Dashboard Summary

Protected routes:

- `GET /dashboard/home`
- `GET /wedding-plans/:id/dashboard-summary`
- `GET /api/v1/wedding-plans/:id/dashboard-summary`

The dashboard summary powers the mobile Home / Today Center. Existing count and money fields remain stable, and the response may also include source-backed detail arrays:

- `dataScope: "ACCOUNT_BACKED"` and `accountBacked: true` to distinguish server/account-backed data from local guest preview data.
- `incompleteGuestsCount`: persisted guests missing basic planning contact/name fields.
- `quoteStatusBreakdown`: `pending`, `offered`, `accepted`, and `rejectedClosed` counts.
- `acceptedProvidersCount`: stable alias for accepted/active `PlanProviderLink` count.
- `financialWarnings`: simple computable warnings such as budget exceeded or installment due soon.

- `importantItems`: actionable task/installment/provider cards for "Ø§Ù„Ø£Ù‡Ù… Ø§Ù„ÙŠÙˆÙ…".
- `planProviders`: providers actually linked to the current WeddingPlan.
- `importantNotifications`: latest user-owned notifications for this WeddingPlan.
- `generatedAt`: server timestamp used by the mobile sync/status copy.

Financial installment details appear only when the current user has the required debt/financial permission. Notifications are always scoped to the authenticated user. Provider cards are planning/reference data only and do not imply paid booking, deposits, payment status, loans, credit, financing, AI, or chat.

## Notifications

Protected routes:

- `GET /notifications`
- `GET /notifications/unread-count`
- `GET /notifications/:id`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `DELETE /notifications/:id`

The same notification routes are also exposed under `/api/v1/notifications`.

`GET /notifications`, `GET /api/v1/notifications`, `GET /notifications/unread-count`, and `GET /api/v1/notifications/unread-count` accept an optional `weddingPlanId` query parameter. Notifications are always owned by the authenticated user. The backend may create idempotent task and installment due notifications while listing/counting notifications.

Notification response:

```json
{
  "id": "notification_id",
  "userId": "user_id",
  "weddingPlanId": "plan_id",
  "type": "TASK_DUE_SOON",
  "title": "Ù…Ù‡Ù…Ø© Ù‚Ø±ÙŠØ¨Ø©",
  "body": "Confirm hall - ØªØ³ØªØ­Ù‚ Ù‚Ø±ÙŠØ¨Ø§Ù‹ (20/12/2026).",
  "data": {
    "taskId": "task_id",
    "weddingPlanId": "plan_id"
  },
  "readAt": null,
  "createdAt": "2026-06-18T00:00:00.000Z",
  "updatedAt": "2026-06-18T00:00:00.000Z"
}
```

Unread count response:

```json
{ "count": 3 }
```

## Budget Categories

Protected routes:

- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `GET /wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /budget-categories/:id`
- `DELETE /budget-categories/:id`

Create request:

```json
{
  "name": "Hall",
  "targetAmount": "500000.00"
}
```

Financial endpoints are private by default and must remain permission-aware for shared plan users.
Current `/api/v1/wedding-plans/:weddingPlanId/budget-categories` and `/api/v1/budget-categories/:id` aliases exist for create/list/update/delete.

## Expenses

Protected routes:

- `POST /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses/summary`
- `PATCH /expenses/:id`
- `DELETE /expenses/:id`

Create request:

```json
{
  "title": "Hall deposit reference",
  "amount": "250000.00",
  "budgetCategoryId": "category_id",
  "status": "PAID",
  "expenseDate": "2026-06-04T00:00:00.000Z",
  "note": "Optional note"
}
```

Expense responses use decimal values as strings.

Additional current expense routes:

- `GET /expenses/:id`
- `GET /api/v1/expenses/:id`

Current `/api/v1/wedding-plans/:weddingPlanId/expenses` and `/api/v1/expenses/:id` aliases exist for create/list/get/update/delete.

## Debts And Installments

Debt routes:

- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `GET /debts/:id`
- `PATCH /debts/:id`
- `DELETE /debts/:id`

Create debt request:

```json
{
  "creditorName": "Vendor or person",
  "creditorPhone": "+967 777 123 456",
  "title": "Remaining hall amount",
  "totalAmount": "300000.00",
  "paidAmount": "50000.00",
  "dueDate": "2026-12-15T00:00:00.000Z",
  "status": "OPEN",
  "note": "Optional note"
}
```

`creditorPhone` is optional and may be `null`. Phase 2A accepts manual entry only; contact picking is not implemented.

Installment routes:

- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`
- `PATCH /installments/:id/pay`
- `PATCH /installments/:id`
- `DELETE /installments/:id`

Create installment request:

```json
{
  "amount": "100000.00",
  "dueDate": "2026-12-20T00:00:00.000Z",
  "paidAt": null,
  "status": "PENDING",
  "note": "Optional note"
}
```

Current `/api/v1` aliases exist for debt list/get/update/delete, installment create/list/pay/update/delete, and due-installment reads.

## Money Summary

Protected routes:

- `GET /wedding-plans/:planId/money-summary`
- `GET /api/v1/wedding-plans/:planId/money-summary`

Money summaries must remain permission-aware. Shared users without financial permissions must not receive private budget, expense, debt, or installment details.

Super Money UI should consume the `/api/v1` route and may use stable aliases in addition to existing fields:

- `totalBudget`, `totalSpent`, `totalDebts`, and `debtRemaining`.
- `paidInstallmentsCount`, `remainingInstallmentsCount`, and `nextInstallment`.
- `categorySummaries` with allocated/spent/remaining values when category and expense permissions allow them.
- `financialWarnings` for budget exceeded, category exceeded, overdue/due-soon installments, or uncategorized expenses when computable.

Day/week/month financial reports are not a current contract. The backend exposes current aggregate totals only.

## Tasks

Protected routes:

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks/summary`
- `GET /tasks/:id`
- `POST /tasks/:id/checklist`
- `PATCH /tasks/:id/checklist/:itemId`
- `DELETE /tasks/:id/checklist/:itemId`
- `PATCH /tasks/:id/assign`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`

Create request:

```json
{
  "title": "Confirm hall",
  "description": "Call the hall manager",
  "dueDate": "2026-12-05T00:00:00.000Z",
  "status": "TODO",
  "priority": "HIGH"
}
```

Owners can manage tasks. Shared members can list tasks and can manage tasks only when `canManageTasks` is true or their role is `MANAGER`.

Current `/api/v1/wedding-plans/:weddingPlanId/tasks` and `/api/v1/tasks/:id` aliases exist for create/list/summary/get/checklist/assign/update/delete.

Task summary also exposes Super UI aliases: `total`, `completed`, `pendingInProgress`, `overdue`, `dueToday`, `highPriority`, and `assigneeSummary`.

Task records currently support `assigneeUserId` and assignment counts. Money/guest/provider entity links are not part of the current task model and must not be faked by clients.

## Timeline

Protected route:

- `GET /wedding-plans/:weddingPlanId/timeline`

Response includes:

- `weddingDate`
- `upcomingTasks`
- `dueDebts`
- `dueInstallments`

Shared members can see task timeline items. Financial due items are hidden unless the shared member has the relevant debt permission.

## Sharing

Protected routes:

- `POST /wedding-plans/:weddingPlanId/shared-members`
- `GET /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`
- `GET /api/v1/wedding-plans/:weddingPlanId/members`
- `PATCH /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `DELETE /api/v1/wedding-plans/:weddingPlanId/members/:memberId`
- `POST /api/v1/wedding-plans/:weddingPlanId/invites`
- `GET /api/v1/invites/:token`
- `POST /api/v1/invites/:token/accept`
- `GET /api/v1/wedding-plans/:weddingPlanId/permissions/me`

Create shared member request:

```json
{
  "phone": "+967700000000",
  "role": "VIEWER",
  "canViewBudget": false,
  "canViewExpenses": false,
  "canViewDebts": false,
  "canManageTasks": false,
  "canManageFinancialRecords": false
}
```

The create route accepts either `phone` or `userId`. Flutter uses `phone` so owners can add an already-registered user by phone number. Existing `userId` request support is preserved for compatibility. Requests that provide both `userId` and `phone` are rejected with `400`.

Shared member response:

```json
{
  "id": "shared_member_id",
  "weddingPlanId": "plan_id",
  "userId": "shared_user_id",
  "user": {
    "id": "shared_user_id",
    "name": "Shared Member Name",
    "phone": "+967700000000"
  },
  "role": "VIEWER",
  "canViewBudget": false,
  "canViewExpenses": false,
  "canViewDebts": false,
  "canManageTasks": false,
  "canManageFinancialRecords": false,
  "createdAt": "2026-06-04T00:00:00.000Z",
  "updatedAt": "2026-06-04T00:00:00.000Z"
}
```

The `user` object is safe display data only. It must not include `passwordHash`, refresh tokens, email, role, status, or a full user object.

Only the owner can add, list, update, or remove shared members for a WeddingPlan. The owner cannot add themselves as a shared member, unknown phone numbers are rejected without auto-creating users, and duplicate members are rejected.

Invite routes support explicit acceptance flows. They do not create chat or broad social collaboration features.

## Guests

Protected routes:

- `GET /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests`
- `POST /wedding-plans/:weddingPlanId/guests/bulk`
- `GET /wedding-plans/:weddingPlanId/guests/summary`
- `GET /wedding-plans/:weddingPlanId/guest-groups`
- `POST /wedding-plans/:weddingPlanId/guest-groups`
- `GET /guests/:id`
- `PATCH /guests/:id`
- `DELETE /guests/:id`
- `PATCH /guest-groups/:id`
- `DELETE /guest-groups/:id`

Create guest request:

```json
{
  "name": "Guest Name",
  "phone": "+967700000000",
  "side": "FAMILY",
  "status": "INVITED",
  "seatsCount": 1,
  "notes": "Optional note"
}
```

Guest response:

```json
{
  "id": "guest_id",
  "weddingPlanId": "plan_id",
  "name": "Guest Name",
  "phone": "+967700000000",
  "side": "FAMILY",
  "status": "INVITED",
  "seatsCount": 1,
  "notes": "Optional note",
  "createdAt": "2026-06-18T00:00:00.000Z",
  "updatedAt": "2026-06-18T00:00:00.000Z"
}
```

Users with readable plan access can list guests. Creating, updating, and deleting guests requires owner or manager access.

Current `/api/v1` aliases exist for guest list/create/bulk/summary/groups/get/update/delete.

Guest summary also exposes Super UI aliases and cleanup fields:

- `confirmed`, `pending`, `waiting`, `declined`, and `notAttending`.
- `missingPhoneCount`, `missingNameCount`, and `incompleteGuestsCount`.
- `expectedSeatsCount` and `companionsExpectedCount`.
- `bySideForSuper` with `groom`, `bride`, and `unknown` buckets while preserving the existing enum-keyed `bySide`.
- `byGroup` counts when guest groups exist.

Incomplete guest detection is informational only. It must not block saving guests.

## Provider References And Quote Leads

Current provider routes are planning/reference and lead workflows. They do not create paid bookings, deposits, payment status, loans, credit, financing, AI, or chat.

Public/reference routes:

- `GET /cities`
- `GET /provider-categories`
- `GET /providers`
- `GET /providers/:id`
- `GET /providers/:id/services`
- `GET /providers/:id/packages`
- `GET /providers/:id/reviews`
- `GET /services`
- `GET /services/:id`
- `GET /api/v1/provider-categories`
- `GET /api/v1/providers`
- `GET /api/v1/providers/:id`

Authenticated user routes:

- `POST /providers/:id/favorite`
- `DELETE /providers/:id/favorite`
- `GET /me/favorite-providers`
- `POST /providers/:id/quote-requests`
- `GET /me/quote-requests`
- `GET /me/quote-requests/:id`
- `PATCH /me/quote-requests/:id/cancel`
- `POST /providers/:id/reviews`
- `PATCH /reviews/:id`
- `DELETE /reviews/:id`

Plan-scoped `/api/v1` quote routes:

- `POST /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/wedding-plans/:weddingPlanId/quote-requests`
- `GET /api/v1/quote-requests/:id`
- `PATCH /api/v1/quote-requests/:id/cancel`
- `PATCH /api/v1/quote-offers/:id/accept`
- `PATCH /api/v1/quote-offers/:id/reject`

Accepting an offer returns the accepted offer and `planProviderLink`, and explicitly returns:

- `automaticFinancialRecordCreated: false`
- `financialSuggestion`
- `nextActions`, including `recordExpense`, `recordDebt`, `createFollowUpTask`, and `viewAcceptedProvider`

Accepting an offer must not silently create expenses, debts, installments, tasks, payments, deposits, or confirmed bookings.

Provider dashboard routes:

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
- `GET /api/v1/provider/me`
- `POST /api/v1/provider/profile`
- `PATCH /api/v1/provider/profile`
- `POST /api/v1/provider/services`
- `PATCH /api/v1/provider/services/:id`
- `DELETE /api/v1/provider/services/:id`
- `GET /api/v1/provider/quote-requests`
- `GET /api/v1/provider/quote-requests/:id`
- `POST /api/v1/provider/quote-requests/:id/offers`
- `PATCH /api/v1/provider/quote-offers/:id`

Known follow-up from the 2026-06-20 audit: quote request/offer permissions should be tightened before shared-plan users are allowed to manage quote decisions broadly.

## Admin APIs

Admin routes are JWT-protected and require admin authorization:

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

Known follow-up from the 2026-06-20 audit: admin route smoke coverage is still needed.

## Error Behavior

- Missing or invalid JWT returns `401`.
- Validation errors are rejected by the global validation pipe.
- Access to private resources that the user does not own or cannot access may return a not-found style response.
- Login with a wrong password returns `401`.

## MVP Exclusions

The current MVP backend contract does not include:

- payments
- deposits
- paid bookings
- confirmed booking or reservation lifecycle
- marketplace checkout, commissions, subscriptions, or monetization
- AI
- FinTech
- chat
- Flutter/mobile implementation
- Docker/Dokploy deployment implementation
