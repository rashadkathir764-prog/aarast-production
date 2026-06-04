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

## What Is Not Implemented Yet

- Budget, expenses, debts, installments, tasks, sharing, or timeline screens.
- Financial dashboard cards are placeholders only.
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
- This phase implements mobile WeddingPlan + Dashboard foundation only.
- Financial screens are placeholders only.
- Budget/Expense/Debt/Installment/Task/Sharing mobile screens are not implemented yet.
- The next planned mobile step after merge is Flutter Budget + Expense screens.
