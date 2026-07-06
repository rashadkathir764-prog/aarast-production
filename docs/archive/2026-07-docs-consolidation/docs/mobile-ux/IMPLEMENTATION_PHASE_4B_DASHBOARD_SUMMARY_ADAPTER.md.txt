# Phase 4B - Dashboard Summary Adapter Behind Feature Flag

Date: 2026-06-19
Scope: Internal rebuild home adapter only
Status: Ready for review

## What Was Added

- Added `UserRebuildDashboardSummaryAdapter` under `mobile/lib/features/shell/rebuild/`.
- Wired the rebuild shell home tab to the adapter.
- The adapter remains guarded by `enableSingleDashboardSummary`.
- When the flag is disabled, the adapter renders the existing safe internal home placeholder.
- When the flag is enabled with no source-backed plan, it renders a safe no-plan state.
- When the flag is enabled and `PlanSummaryReadiness` contains real source snapshots, it can render an internal summary for:
  - plan title
  - estimated budget and currency
  - task count
  - due installment count
  - shared member count
  - pending sync count

## Why This Is Behind A Feature Flag

`enableSingleDashboardSummary` remains `false` by default. The active app route does not enable this adapter.

This keeps the new summary contract testable inside the rebuild shell without activating the redesigned dashboard for users.

## Why No Real Data Fetch Was Added

The adapter accepts `PlanSummaryReadiness` as an input. It does not call API clients, providers, repositories, local databases, or sync services.

All displayed values are source-backed by the caller.

## Why `/home` Was Not Changed

`/home` still points to the existing production shell and dashboard. Phase 4B only changes the guarded rebuild shell path.

## Why `MainShell` Was Not Changed

The current `MainShell` remains the live user shell. The adapter is under `mobile/lib/features/shell/rebuild/` and is not wired into the production shell.

## Why No Fake Data Was Added

The adapter defaults to `PlanSummaryReadiness.empty()` and `AppFeatureFlags.defaults`. It shows no plan summary until the flag is explicitly enabled and a real readiness snapshot is injected.

## Acceptance Criteria

- Current branch is not `main`.
- `enableSingleDashboardSummary` remains disabled by default.
- `enableNewUserBottomNavigation` remains disabled by default.
- `enableGuestFirstOnboarding` remains disabled by default.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Adapter is reachable only inside guarded rebuild shell work.
- No fake `planId`, fake counts, or fake budget values are used.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- The adapter is only as reliable as the future source that injects `PlanSummaryReadiness`.
- It does not yet prove production dashboard migration readiness.
- Future wiring must avoid enabling `enableSingleDashboardSummary` by default.

## Next Step

Recommended next step:

```text
Phase 5A - Money Flow Stabilization Readiness
```

Alternative if state-source work needs more hardening:

```text
Phase 4C - Current plan source contract behind flag
```
