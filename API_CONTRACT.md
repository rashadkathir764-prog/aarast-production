# API Contract

This document records the current Aarast backend API contract used by the Flutter app and admin web. It reflects the current NestJS implementation and smoke-tested route surface as of the 2026-06-14 audit.

## Base URL

Local backend example:

```text
http://127.0.0.1:3115
```

Manual QA scripts can also run the backend at `http://127.0.0.1:3000`. The current backend does not configure a global `/api` prefix. Clients should call routes directly from the base URL, for example `GET /health` and `POST /auth/login`.

## Common Rules

- JSON request and response bodies are used for API routes.
- Protected routes require `Authorization: Bearer <accessToken>`.
- Private resources use ownership and sharing checks.
- Some unauthorized private-resource access is intentionally returned as not found style behavior.
- `passwordHash` is never returned.
- Owner user objects are not exposed in WeddingPlan responses.
- Financial visibility is private by default and controlled by owner access or explicit sharing permissions.

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

## Wedding Plans

Protected routes:

- `POST /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

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

Financial endpoints currently remain owner-protected in the implemented MVP.

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

## Debts And Installments

Debt routes:

- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `PATCH /debts/:id`
- `DELETE /debts/:id`

Create debt request:

```json
{
  "creditorName": "Vendor or person",
  "title": "Remaining hall amount",
  "totalAmount": "300000.00",
  "paidAmount": "50000.00",
  "dueDate": "2026-12-15T00:00:00.000Z",
  "status": "OPEN",
  "note": "Optional note"
}
```

Installment routes:

- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`
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

## Tasks

Protected routes:

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
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

## Provider Marketplace References

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

Authenticated user marketplace routes:

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

These routes are planning/reference and quote-lead flows only. They do not create paid bookings, deposits, payment status, loans, credit, financing, AI, or chat behavior.

## Provider Dashboard

Provider routes:

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

## Admin

Admin web uses `/auth/login` and requires the authenticated user role to be `ADMIN`. Admin API routes include:

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

Admin pages for bookings, payments, notifications, reports, and settings are partial/readiness screens unless matching backend endpoints are added.

## Error Behavior

- Missing or invalid JWT returns `401`.
- Validation errors are rejected by the global validation pipe.
- Access to private resources that the user does not own or cannot access may return a not-found style response.
- Login with a wrong password returns `401`.

## MVP Exclusions

The current backend contract does not include:

- payments
- deposits
- confirmed booking
- AI
- FinTech
- chat
- production SMS/WhatsApp OTP delivery
- public booking-lead management APIs
