# Aarast Mobile

Flutter mobile app for Aarast / اعّرست.

## Current Audit Note - 2026-06-14

The mobile app is no longer only a foundation. It includes the core Wedding Financial OS flows, provider marketplace/reference screens, provider application/dashboard screens, and a SQLite offline cache/sync queue for selected safe mobile workflows.

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
  - Sharing overview
  - Add Shared Member
  - Edit Shared Member
  - Shared WeddingPlans
  - Provider Marketplace
  - Provider Details
  - Quote Request
  - Provider Apply
  - Provider Dashboard
  - Add Provider Service
  - Add Provider Package
- SQLite offline cache/sync queue for supported mobile platforms, with JSON fallback for web/test.

## What Is Not Implemented Yet

- Payment processing, deposits, payment status, AI, FinTech, internal chat, or confirmed booking flows.
- Production Meta WhatsApp OTP delivery.
- Full conflict resolution for offline sync beyond the MVP-safe queue/retry behavior.
- Admin-only workflows inside the mobile app.

## API Base URL

The backend base URL is configured in:

```text
lib/core/config/api_config.dart
```

Default local value:

```text
http://127.0.0.1:3115
```

Override it at run time with:

```bash
flutter run --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3115
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

Sharing endpoints are wired to:

- `POST /wedding-plans/:weddingPlanId/shared-members`
- `GET /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`

Marketplace endpoints are wired to:

- `GET /cities`
- `GET /provider-categories`
- `GET /providers`
- `GET /providers/:id`
- `GET /providers/:id/services`
- `GET /providers/:id/packages`
- `POST /providers/:id/favorite`
- `DELETE /providers/:id/favorite`
- `GET /me/favorite-providers`
- `POST /providers/:id/quote-requests`
- `GET /me/quote-requests`

Provider dashboard endpoints are wired to:

- `POST /provider/apply`
- `GET /provider/me/profile`
- `PATCH /provider/me/profile`
- `GET /provider/me/summary`
- Provider-owned service/package management routes.

Protected requests send the token as:

```text
Authorization: Bearer <accessToken>
```

## Local Development

### Local Ports

There are two local backend modes. The Flutter default points to Docker/local API port 3115; manual QA scripts can override it to port 3000.

| Service      | Port    | Notes                                          |
|--------------|---------|------------------------------------------------|
| Backend API  | 3115    | Docker Compose host port                       |
| Backend API  | 3000    | Manual QA script port                          |
| Flutter Web  | dynamic | Chrome assigns dynamically                     |
| PostgreSQL   | 5433    | `aarast-db` Docker container                   |

### Quick Start

Run from the project root (`D:\projects\aarast`):

```powershell
# Terminal 1: Start backend on port 3000
.\scripts\dev\start-backend.ps1

# Terminal 2: Start Flutter web, API -> http://127.0.0.1:3000
.\scripts\dev\start-flutter-web.ps1

# If port 3000 is blocked
.\scripts\dev\stop-port-3000.ps1
```

### Manual Flutter Commands

Install dependencies:

```bash
flutter pub get
```

Run on Chrome against Docker/local API port 3115:

```bash
flutter run -d chrome --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3115
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

> **Note**: Smoke tests may use temporary safe ports (e.g. 3148, 3160). Use port 3000 when following the manual QA PowerShell scripts, or port 3115 when testing against Docker Compose.

## Notes

- The mobile app still uses the direct backend routes documented in `../API_CONTRACT.md`.
- Core Flutter MVP screens are implemented.
- WeddingPlan Dashboard is fully redesigned as a command center (DashboardSummaryProvider + command cards).
- `../MOBILE_QA_PLAN.md` contains the Arabic-first manual QA checklist for hands-on validation.
- Offline SQLite details live in `OFFLINE_SQLITE.md`.
- The next step is production API URL validation and visual QA/stakeholder review of the dashboard and marketplace flows.
