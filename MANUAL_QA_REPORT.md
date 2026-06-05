# Manual QA Report

## Date And Context

- Date: 2026-06-05
- Project: Aarast / اعّرست
- Scope: Hands-on MVP QA run for the completed backend MVP Core API and Flutter MVP screens.
- QA type: Manual browser-based validation of the main MVP planning flows.

## Environment

- Backend local: `http://127.0.0.1:3000`
- Flutter web local: Chrome
- Database: local Aarast PostgreSQL development database
- Deployment status: local development only; no deployment work has started.

## Passed Flows

- Auth register/login/logout: PASS
- Create WeddingPlan: PASS
- Open WeddingPlan Dashboard: PASS
- Create Budget Category: PASS
- Create Expense: PASS
- Expense summary updated: PASS
- Create Debt: PASS
- Create Installment: PASS
- Debt summary/details updated: PASS
- Create Task: PASS
- Timeline summary updated: PASS
- Add shared member: PASS
- Shared member can access shared plan: PASS
- Shared member with `canManageTasks` can create task: PASS

## Known QA Notes

- Sharing add member currently requires technical `userId`; future improvement should allow phone/search.

## Resolved In Bug-Fix Polish Pass 1

- Financial navigation cards for shared users now respect shared permissions on the WeddingPlan Dashboard.
- Shared users without financial permissions see locked/disabled financial cards with a clear permission message.
- Shared users with relevant financial permissions can access the matching finance or debt/installment navigation.
- Backend permissions were unchanged.

## Manual Sanity Notes For Bug-Fix Polish Pass 1

- Owner dashboard should still show finance, debt/installment, task/timeline, and sharing cards.
- Shared viewer without financial permissions should not get direct financial navigation from the dashboard.
- Shared user with `canManageTasks` should still be able to use task/timeline navigation.

## Final Verdict

MVP core flow PASS.

## Next Recommended Step

Continue the bug-fix polish pass for remaining UX issues, especially adding shared members by phone/search instead of technical `userId`, then prepare deployment planning.
