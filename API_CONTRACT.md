# API Contract

This document freezes the current Aarast backend MVP API contract for Flutter MVP integration. It reflects the current NestJS implementation and smoke-tested route surface.

## Base URL

Local backend example:

```text
http://127.0.0.1:3000
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

Only the owner can add, list, update, or remove shared members for a WeddingPlan. The owner cannot add themselves as a shared member, unknown phone numbers are rejected without auto-creating users, and duplicate members are rejected.

## Error Behavior

- Missing or invalid JWT returns `401`.
- Validation errors are rejected by the global validation pipe.
- Access to private resources that the user does not own or cannot access may return a not-found style response.
- Login with a wrong password returns `401`.

## MVP Exclusions

The current MVP backend contract does not include:

- payments
- deposits
- confirmed booking
- marketplace/provider/vendor flows
- AI
- FinTech
- chat
- Flutter/mobile implementation
- Docker/Dokploy deployment implementation
