# Aarast Mobile

Flutter mobile foundation for Aarast / Ø§Ø¹Ù‘Ø±Ø³Øª.

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
- Current rebuild documentation also covers guest-first onboarding, route guards, single-source dashboard summaries, provider/user separation, and privacy-aware states. Those rebuild areas should be implemented behind feature flags and verified through `../docs/testing/MOBILE_QA_PLAN.md`.

## What Is Not Implemented Yet

- Paid marketplace, payment processing, deposits, confirmed bookings, loans, credit, financing, AI, FinTech, or internal chat flows.
- Full mobile wiring for every newer backend completion surface, such as guest groups, invite accept flow, provider quote offers, and notification deep-link handling.
- Docker, Dokploy, or deployment configuration.

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

Do not duplicate endpoint lists in this file. The route-level source of truth is `../API_CONTRACT.md`.

Current backend compatibility includes direct legacy routes and newer `/api/v1` route groups for many modules. Mobile code should keep using the repository API client/repository layer and only add new routes after updating `../API_CONTRACT.md` and the relevant mobile QA plan.

Protected requests send the token as:

```text
Authorization: Bearer <accessToken>
```

## Local Development

### Fixed Ports

All manual QA uses fixed ports. Smoke tests may use temporary ports, but manual QA always targets the local Docker backend host port 3115.

| Service      | Port    | Notes                                          |
|--------------|---------|------------------------------------------------|
| Backend API  | 3115 | `http://127.0.0.1:3115` |
| Flutter Web  | dynamic | Chrome assigns dynamically; API points to 3115 |
| PostgreSQL   | 5433    | `aarast-db` Docker container                   |

### Quick Start

Run from the project root (`D:\projects\aarast`):

```powershell
# Terminal 1: Start backend on local Docker host port 3115
.\scripts\dev\start-backend.ps1

# Terminal 2: Start Flutter web, API -> http://127.0.0.1:3115
.\scripts\dev\start-flutter-web.ps1

# If local Docker backend port 3115 is blocked
docker compose restart backend
```

### Manual Flutter Commands

Install dependencies:

```bash
flutter pub get
```

Run on Chrome (API points to port 3115):

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

> **Note**: Smoke tests may use temporary safe ports (e.g. 3148, 3160).
> Manual QA must always use local Docker backend port 3115.

## Notes

- The backend API contract is maintained in `../API_CONTRACT.md`.
- Core Flutter MVP screens are implemented.
- WeddingPlan Dashboard is fully redesigned as a command center (DashboardSummaryProvider + command cards).
- `../MOBILE_QA_PLAN.md` is the legacy Arabic-first manual QA checklist.
- `../docs/testing/MOBILE_QA_PLAN.md` is the current rebuild QA gate.
- New rebuild work should stay narrow, feature-flagged, and aligned with `../docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md`.
