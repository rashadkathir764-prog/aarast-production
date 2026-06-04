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
- Cities
- Categories
- Services
- Bookings / Booking Leads only if already present, as non-binding interest or lead tracking. Smoke tests must not imply paid booking, confirmed reservation, deposit, or payment status.
- Favorites
- Reviews only as a baseline if already present. Reviews belong to later marketplace phases and are not required for the Wedding Financial OS MVP.
- Provider Profile

## Planned Future Units To Smoke Test

- Wedding Plan
- Budget
- Expenses
- Debts
- Installments
- Tasks
- Sharing
- Quote Requests
- Attachments
- Timeline / Due Dates

## MVP Smoke-Test Boundaries

- `smoke:all` is the backend MVP regression smoke command. It runs health, auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing smoke scripts in sequence.
- Smoke tests must not validate payment processing, deposit confirmation, loan, credit, financing, or confirmed booking behavior in the MVP.
- Future Wedding Financial OS smoke tests must verify that private financial data is not exposed to shared members unless permissions allow it.
- This document is documentation only; no smoke-test code is created in this phase.

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
