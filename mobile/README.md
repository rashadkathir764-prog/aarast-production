# Aarast Mobile

Flutter mobile foundation for Aarast / اعّرست.

## What Is Implemented

- Arabic-first RTL app shell.
- Material 3 theme using the project design colors: deep burgundy, warm gold, and ivory.
- Auth API client using Dio.
- Access-token and safe-user storage using `shared_preferences`.
- Simple Provider-based auth state.
- Routing with `go_router`.
- Screens:
  - Splash
  - Login
  - Register
  - Home placeholder
  - My WeddingPlans
  - Create WeddingPlan
  - WeddingPlan Dashboard
  - Budget + Expense overview
  - Create Budget Category
  - Create Expense
  - Debt + Installment overview
  - Create Debt
  - Debt Details
  - Create Installment
  - Task + Timeline overview
  - Create Task

## What Is Not Implemented Yet

- Sharing screens.
- Sharing dashboard card is a placeholder only.
- Marketplace, payment, deposit, AI, FinTech, chat, or confirmed booking flows.
- Backend API changes.
- Docker, Dokploy, or deployment configuration.

## API Base URL

The backend base URL is configured in:

```text
lib/core/config/api_config.dart
```

Default local value:

```text
http://127.0.0.1:3000
```

Override it at run time with:

```bash
flutter run --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3000
```

The current backend has no global `/api` prefix. Auth endpoints are wired to:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

WeddingPlan endpoints are wired to:

- `POST /wedding-plans`
- `GET /wedding-plans/my`
- `GET /wedding-plans/:id`
- `PATCH /wedding-plans/:id`
- `PATCH /wedding-plans/:id/archive`

BudgetCategory endpoints are wired to:

- `POST /wedding-plans/:weddingPlanId/budget-categories`
- `GET /wedding-plans/:weddingPlanId/budget-categories`
- `PATCH /budget-categories/:id`
- `DELETE /budget-categories/:id`

Expense endpoints are wired to:

- `POST /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses`
- `GET /wedding-plans/:weddingPlanId/expenses/summary`
- `PATCH /expenses/:id`
- `DELETE /expenses/:id`

Debt endpoints are wired to:

- `POST /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts`
- `GET /wedding-plans/:weddingPlanId/debts/summary`
- `PATCH /debts/:id`
- `DELETE /debts/:id`

Installment endpoints are wired to:

- `POST /debts/:debtId/installments`
- `GET /debts/:debtId/installments`
- `GET /wedding-plans/:weddingPlanId/installments/due`
- `PATCH /installments/:id`
- `DELETE /installments/:id`

Task endpoints are wired to:

- `POST /wedding-plans/:weddingPlanId/tasks`
- `GET /wedding-plans/:weddingPlanId/tasks`
- `PATCH /tasks/:id`
- `DELETE /tasks/:id`

Timeline endpoint is wired to:

- `GET /wedding-plans/:weddingPlanId/timeline`

Protected requests send the token as:

```text
Authorization: Bearer <accessToken>
```

## Run

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Analyze and test:

```bash
flutter analyze
flutter test
```

Optional lightweight web build check:

```bash
flutter build web --debug
```

## Notes

- The backend API contract remains unchanged.
- This phase implements Flutter Task + Timeline screens only.
- Sharing mobile screens are not implemented yet.
- The next planned mobile step after merge is Flutter Sharing screens.
