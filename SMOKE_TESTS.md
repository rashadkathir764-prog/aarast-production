# Smoke Tests

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
- Wedding Plan and active plan
- Dashboard summary
- Budget and expenses
- Debts and installments
- Tasks and timeline
- Sharing and sharing roles
- Notifications and notification APIs
- Guests and guest APIs
- OTP/Profile
- Cities
- Categories
- Services
- Bookings / Booking Leads only if already present, as non-binding interest or lead tracking. Smoke tests must not imply paid booking, confirmed reservation, deposit, or payment status.
- Favorites
- Reviews as provider-reference support.
- Provider Profile
- Provider quote flows
- Backend completion journey

## Planned Future Units To Smoke Test

- Attachments
- Push/device-token notification infrastructure if approved later.
- Admin API smoke coverage for dashboard stats, provider review transitions, catalog CRUD, and user list/detail.

## MVP Smoke-Test Boundaries

- `smoke:all` is the backend regression smoke command. It runs health, auth, WeddingPlan, onboarding/active plan, dashboard summary, money APIs, Budget + Expense, Debt + Installment, Task APIs, Task + Timeline, Sharing, Sharing Roles, Notifications, Notification APIs, Guests, Guest APIs, OTP/Profile, Marketplace, Providers/Quotes, Provider Dashboard, and Backend Completion smoke scripts in sequence.
- Smoke tests must not validate payment processing, deposit confirmation, loan, credit, financing, or confirmed booking behavior in the MVP.
- Future Wedding Financial OS smoke tests must verify that private financial data is not exposed to shared members unless permissions allow it.
- This document is documentation only; no smoke-test code is created in this phase.

## Current Focused Smoke Commands

From `backend/`:

- `npm run smoke:health`
- `npm run smoke:auth`
- `npm run smoke:wedding-plan`
- `npm run smoke:onboarding-active-plan`
- `npm run smoke:dashboard-summary`
- `npm run smoke:money-apis`
- `npm run smoke:budget-expense`
- `npm run smoke:debt-installment`
- `npm run smoke:tasks-apis`
- `npm run smoke:task-timeline`
- `npm run smoke:sharing`
- `npm run smoke:sharing-roles`
- `npm run smoke:notifications`
- `npm run smoke:notifications-apis`
- `npm run smoke:guests`
- `npm run smoke:guests-apis`
- `npm run smoke:otp-profile`
- `npm run smoke:marketplace`
- `npm run smoke:providers-quotes`
- `npm run smoke:provider-dashboard`
- `npm run smoke:backend-completion`
- `npm run smoke:all`

All scripts use `SMOKE_BASE_URL`; marketplace/provider-dashboard/provider-quote smokes can also use `SMOKE_DATABASE_URL` to create local active provider fixtures safely. These smoke tests cover planning/reference and quote-lead behavior only, not paid bookings or payment state.

Current caution: the 2026-06-20 backend/API audit found a Docker runtime/source mismatch in `smoke:dashboard-summary`. Rebuild/restart the local runtime and rerun smoke before claiming current runtime readiness.

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
