# Phase 5A - Money Flow Stabilization Readiness

Date: 2026-06-19
Scope: Internal Money readiness states only
Status: Ready for review

## What Was Added

- Added `MoneyFlowReadiness` under `mobile/lib/features/finance/models/`.
- Added readiness states for the internal Money tab:
  - missing current plan
  - missing financial permission
  - waiting for source-backed finance data
  - ready
  - offline pending sync
  - loading
  - blocked by error
- Updated `UserRebuildMoneyTab` to render these readiness states.
- Added tests for the model and internal Money tab behavior.

## Why This Is A Stabilization Step Only

This phase does not connect real finance screens. It only gives the experimental Money tab a clearer readiness contract before any future integration.

The tab still does not instantiate:

- `BudgetExpenseScreen`
- `FinanceProvider`
- debt providers
- API clients
- local database services

## Why No Backend Calls Were Added

`MoneyFlowReadiness` is derived from already-provided snapshots, especially `PlanSummaryReadiness`. It does not fetch or mutate data.

## Why No Fake Plan ID Was Used

The default state is `MoneyFlowReadiness.empty()`, which has no current plan ID, no counts, and no money totals.

The Money tab only shows source-backed values when a caller explicitly provides a readiness snapshot.

## Why `/home` Was Not Changed

`/home` still uses the current production `MainShell`. This phase only changes the guarded rebuild Money tab.

## Why `MainShell` Was Not Changed

`MainShell` remains untouched and is still the active shell for real users.

## Acceptance Criteria

- Current branch is not `main`.
- `enableNewUserBottomNavigation` remains disabled by default.
- `enableSingleDashboardSummary` remains disabled by default.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Money readiness defaults to no-plan and no fake values.
- Financial permission is represented before finance data can be considered ready.
- Offline pending sync is represented without triggering notification permission or sync UI changes.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- This is not a complete finance workflow.
- Future phases must map real sharing permissions into `MoneyFlowReadiness` carefully.
- Real finance screens must not be connected until a safe current plan ID and permission contract are available.

## Next Step

Recommended next step:

```text
Phase 6A - Tasks Guests Sharing Readiness
```

Alternative if finance integration needs another gate:

```text
Phase 5B - Permission-mapped money adapter behind flag
```
