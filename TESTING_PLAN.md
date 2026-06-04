# Testing Plan

## Testing Strategy

Aarast should use layered testing, starting with smoke tests for critical API units before expanding into broader feature work. The goal is to catch broken foundations early and keep every phase verifiable.

This documentation phase defines the testing strategy only. It does not create test code.

## Smoke Tests

Smoke tests are the first priority. They confirm that the most important units start, respond, authenticate, authorize, and return expected high-level results. They should be quick to run and easy to report as PASS or FAIL.

Smoke API tests should come before large feature expansion because they protect the project from building new work on unstable foundations.

The backend MVP regression command is `npm run smoke:all` from `backend/`. It runs the current health, auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing smoke scripts in sequence.

No smoke-test code is created during the Docs Foundation phase.

## Unit Tests

Unit tests should cover isolated business rules and service behavior, especially:

- Authorization and ownership decisions.
- Budget calculations.
- Expense totals.
- Debt status.
- Installment due states.
- Task completion rules.
- Private-by-default financial visibility for expenses, debts, installments, and attachments.
- Shared member restrictions that prevent access to private financial details unless permission allows it.
- Data validation behavior.

## Integration Tests

Integration tests should verify that modules work together across real application boundaries, such as:

- Authenticated user access to private wedding plans.
- Shared member permissions.
- Provider/service listing and non-binding booking lead or quote request creation only if those units already exist.
- Quote request creation tied to a wedding plan, without confirmed booking, paid booking, deposit, or payment status behavior in the MVP.
- Attachment access rules for receipts, agreements, quote files, and supporting images tied to expenses, debts, installments, or quote requests as planning-level future coverage.
- Admin-only management flows.

## Manual QA

Manual QA should validate user journeys that are difficult to trust through automated tests alone:

- First-time account setup.
- Wedding plan creation.
- Adding budget categories, expenses, debts, installments, and tasks.
- Inviting shared members.
- Confirming shared members cannot see private financial details, debts, installments, attachments, or private tasks unless permission allows it.
- Reviewing due items.
- Comparing saved providers or services only as planning references, not paid booking or full marketplace flows.

## Priority Order

1. Smoke API tests for existing critical units.
2. Smoke API tests for Wedding Financial OS modules.
3. Unit tests for authorization and calculations.
4. Integration tests for shared flows.
5. Manual QA for end-to-end product journeys.
