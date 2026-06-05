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
- Financial navigation cards are visible to shared users even without financial permissions; future improvement should hide or lock them based on permissions.

## Final Verdict

MVP core flow PASS.

## Next Recommended Step

Bug-fix polish pass, then prepare deployment planning.
