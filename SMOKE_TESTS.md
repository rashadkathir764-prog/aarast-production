# Smoke Tests

## Current Smoke Commands - 2026-06-14

Local backend health with Docker Compose:

```powershell
cd D:\projects\aarast
docker compose up -d --build
Invoke-RestMethod http://127.0.0.1:3115/health
```

Backend smoke suite:

```powershell
cd D:\projects\aarast\backend
$env:SMOKE_BASE_URL="http://127.0.0.1:3115"
npm run smoke:health
npm run smoke:auth
npm run smoke:wedding-plan
npm run smoke:budget-expense
npm run smoke:debt-installment
npm run smoke:task-timeline
npm run smoke:sharing
npm run smoke:otp-profile
npm run smoke:marketplace
npm run smoke:provider-dashboard
npm run smoke:all
```

Manual endpoint spot checks:

```powershell
Invoke-RestMethod http://127.0.0.1:3115/health
Invoke-RestMethod http://127.0.0.1:3115/provider-categories
Invoke-RestMethod http://127.0.0.1:3115/providers
```

Admin auth and dashboard stats require an admin JWT:

```powershell
$login = Invoke-RestMethod http://127.0.0.1:3115/auth/login -Method Post -ContentType "application/json" -Body '{"phone":"+967700000000","password":"<admin-password>"}'
Invoke-RestMethod http://127.0.0.1:3115/admin/dashboard/stats -Headers @{ Authorization = "Bearer $($login.accessToken)" }
```

Flutter web smoke:

```powershell
cd D:\projects\aarast\mobile
flutter run -d chrome --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3115
```

SQLite offline manual smoke:

- Login while online.
- Open plans, dashboard, finance, debts, tasks, sharing, and marketplace pages to seed cache.
- Disconnect network.
- Confirm cached reads render where data exists.
- Create a supported offline write such as a task or expense.
- Confirm pending/offline UI appears.
- Reconnect and use sync now from More.
- Confirm pending count clears or the error remains visible.

Production spot checks:

```powershell
Invoke-WebRequest https://aarast-api.shadowgardn.com/health -UseBasicParsing
Invoke-WebRequest https://aarast.shadowgardn.com/ -UseBasicParsing
Invoke-WebRequest https://aarast-admin.shadowgardn.com/ -UseBasicParsing
```

As of the 2026-06-14 audit, API health and `aarast.shadowgardn.com` returned HTTP 200; `aarast-admin.shadowgardn.com` returned HTTP 502.

## Meaning In This Project

Smoke tests are fast checks that confirm critical units are alive, reachable, and behaving at a basic expected level. They are not full regression tests. They should answer one simple question: is this unit safe enough to continue building on?

Smoke tests should verify:

- The app or API starts.
- Required routes respond.
- Authentication works where required.
- Protected routes reject unauthenticated or unauthorized access.
- Basic happy-path requests work.
- Basic failure responses are understandable.

## Existing Units To Smoke Test First

- Auth
- Cities
- Categories
- Services
- Bookings / Booking Leads only if already present, as non-binding interest or lead tracking. Smoke tests must not imply paid booking, confirmed reservation, deposit, or payment status.
- Favorites
- Reviews only as a baseline if already present. Reviews belong to later marketplace phases and are not required for the Wedding Financial OS MVP.
- Provider Profile

## Implemented Units To Smoke Test

- Wedding Plan
- Budget
- Expenses
- Debts
- Installments
- Tasks
- Sharing
- Quote Requests
- Timeline / Due Dates

## Future Units To Smoke Test

- Attachments, when implemented.
- Production SMS/WhatsApp OTP delivery, when an approved provider is wired.
- Payment/deposit/confirmed booking flows only if explicitly approved later.

## MVP Smoke-Test Boundaries

- `smoke:all` is the backend MVP regression smoke command. It runs health, auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, Sharing, OTP/Profile, Marketplace, and Provider Dashboard smoke scripts in sequence.
- Smoke tests must not validate payment processing, deposit confirmation, loan, credit, financing, or confirmed booking behavior in the MVP.
- Future Wedding Financial OS smoke tests must verify that private financial data is not exposed to shared members unless permissions allow it.
- This document is documentation only; no smoke-test code is created in this phase.

## Current Provider Foundation Smoke Commands

From `backend/`:

- `npm run smoke:otp-profile`
- `npm run smoke:marketplace`
- `npm run smoke:provider-dashboard`

All scripts use `SMOKE_BASE_URL`; marketplace/provider-dashboard smokes can also use `SMOKE_DATABASE_URL` to create local active provider fixtures safely. These smoke tests cover planning/reference and quote-lead behavior only, not paid bookings or payment state.

## PASS/FAIL Report Format

Each smoke-test run should produce a short report using this format:

```text
Smoke Test Report
Date:
Environment:
Branch/Worktree:

Unit: Auth
Status: PASS or FAIL
Checks:
- PASS/FAIL - check name
- PASS/FAIL - check name
Notes:

Unit: Cities
Status: PASS or FAIL
Checks:
- PASS/FAIL - check name
Notes:

Overall Result: PASS or FAIL
Blocking Issues:
- Issue 1
- Issue 2
```

## Reporting Rules

- PASS means the required basic checks succeeded.
- FAIL means one or more required basic checks failed.
- Any FAIL must include the command, route, or action that failed when available.
- A smoke-test report should be saved or copied into the relevant phase notes when implementation work begins.
- This document defines smoke-test expectations only; it does not add test code.
