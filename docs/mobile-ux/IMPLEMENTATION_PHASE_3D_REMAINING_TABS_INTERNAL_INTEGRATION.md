# Phase 3D - Remaining Tabs Internal Integration

Date: 2026-06-19
Scope: Internal rebuild tab surfaces only
Status: Ready for review

## What Was Connected

- Added `UserRebuildPlaceholderTab` for the remaining internal rebuild tabs:
  - الرئيسية
  - المهام
  - الموردون
  - المزيد
- Updated `UserRebuildShell` so non-money tabs render tab-specific internal placeholder surfaces.
- Kept `UserRebuildMoneyTab` as the dedicated Money tab surface from Phase 3C.
- Added widget tests for the safe placeholder states.

## Why This Is Limited To Internal Dev Routes

The rebuilt shell remains reachable only through `/dev/user-navigation-shell`, which stays guarded by `enableNewUserBottomNavigation`.

This phase is a contract-readiness step. It gives each approved tab a safe internal surface without activating the new navigation for real users.

## Why `/home` Was Not Changed

`/home` remains owned by the current production `MainShell`. Replacing `/home` would activate the new navigation before the state source, permissions, offline behavior, and QA gates are ready.

## Why `MainShell` Was Not Changed

`MainShell` is still the active user shell. This phase only improves the guarded rebuild shell under `mobile/lib/features/shell/rebuild/`.

## Why No Real Feature Screens Were Reused

The remaining tabs do not yet have a safe current-plan source in the rebuild shell. Reusing real task, provider, or settings screens could accidentally depend on missing state or backend-backed flows.

The placeholders therefore describe the intended internal areas without:

- calling backend APIs
- creating fake `planId` values
- showing bookings, payments, maps, analytics, AI, or subscriptions
- changing onboarding or first launch behavior

## Acceptance Criteria

- Current branch is not `main`.
- `enableNewUserBottomNavigation` remains disabled by default.
- `/dev/user-navigation-shell` remains guarded.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Remaining rebuild tabs have safe internal surfaces.
- Money tab remains connected to the Phase 3C internal Money surface.
- No fake `planId` is used.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- The remaining tabs are still readiness placeholders, not real product workflows.
- Future integration must wait for a real current-plan source and permission contract.
- Provider surfaces must not imply confirmed bookings, deposits, or payment status before those phases are approved.

## Next Step

Recommended next step:

```text
Phase 4A - Single Source of Truth readiness
```

Alternative if navigation needs another review pass:

```text
Phase 3D QA review before state-source work
```
