# Phase 4A - Single Source of Truth Readiness

Date: 2026-06-19
Scope: Source-readiness model only
Status: Ready for review

## What Was Added

- Added `PlanSummaryReadiness` under `mobile/lib/features/wedding_plans/models/`.
- The model can hold source-backed dashboard inputs when they already exist:
  - current `WeddingPlan`
  - `ExpenseSummary`
  - `DebtSummary`
  - due installments
  - tasks
  - shared members
  - offline sync status
- Added tests for:
  - safe `empty()` state
  - no fake current plan ID
  - source-backed counts only when lists are provided
  - optional finance and sync snapshots
  - loading/error states blocking dashboard-adapter readiness

## Why This Is A Readiness Step Only

The current dashboard providers fetch multiple data sources directly. Phase 4A does not replace those providers and does not introduce a new fetch path.

This phase creates a small, pure model that future adapters can use once the rebuild shell has a real current-plan source.

## Why No Backend Calls Were Added

`PlanSummaryReadiness` is a data contract. It does not import API clients, providers, repositories, network helpers, or local database implementations.

It only accepts values that are already provided by another caller.

## Why No Fake Plan ID Was Used

`currentPlanId` is derived only from a real `WeddingPlan`. `PlanSummaryReadiness.empty()` leaves all source fields absent and returns `null` for plan IDs and counts.

This prevents the rebuild shell from accidentally rendering dashboard summaries against synthetic state.

## Why `/home` Was Not Changed

The active `/home` route still uses the current production `MainShell` and existing dashboard behavior. Phase 4A only adds a model that can be used later behind a feature flag.

## Why `MainShell` Was Not Changed

`MainShell` remains the live shell. No shell routing, startup route, onboarding behavior, or user-facing navigation was changed.

## Acceptance Criteria

- Current branch is not `main`.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- `enableNewUserBottomNavigation` remains disabled by default.
- `enableGuestFirstOnboarding` remains disabled by default.
- `PlanSummaryReadiness.empty()` does not create fake IDs, counts, money values, or sync state.
- The readiness model can carry existing source snapshots without calling APIs.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- This does not yet prove that the rebuild dashboard can obtain a real current plan.
- Existing dashboard providers still own their current fetch behavior.
- Future adapter work must keep this model source-backed and feature-flagged.

## Next Step

Recommended next step:

```text
Phase 4B - Dashboard Summary Adapter behind Feature Flag
```

Alternative if state architecture needs review first:

```text
Phase 4A architecture review before adapter wiring
```
