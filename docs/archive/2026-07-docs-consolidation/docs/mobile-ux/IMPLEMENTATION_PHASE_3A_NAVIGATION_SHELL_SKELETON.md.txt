# Phase 3A - Navigation Shell Skeleton Behind Feature Flag

Date: 2026-06-19
Scope: Mobile internal user navigation shell skeleton only
Status: Ready for review

## What Was Built

- Added an internal wedding-user navigation shell skeleton under `mobile/lib/features/shell/rebuild/`.
- Added the approved five user tabs:
  - الرئيسية
  - المال
  - المهام
  - الموردون
  - المزيد
- Added tab definitions with Arabic label, icon, semantic purpose, and current-plan requirement.
- Added a simple `IndexedStack` shell with a safe internal placeholder:
  - "هذه شاشة تجريبية للتنقل الجديد"
- Added lightweight tests for tab definitions, shell rendering, and route flag behavior.

## Internal Route

An internal development route was added:

```text
/dev/user-navigation-shell
```

The route is guarded by:

```text
AppFeatureFlags.enableNewUserBottomNavigation
```

When the flag is disabled, the route redirects to the current stable `/home` route.

## Current MainShell Preservation

The existing `MainShell` was not modified.

- Current `/home` still opens the existing `MainShell`.
- Current bottom navigation remains unchanged.
- Current quick-add behavior remains unchanged.
- The new shell is not used as a replacement for the active shell.

## Feature Flag

`enableNewUserBottomNavigation` remains `false` by default in `AppFeatureFlags.defaults`.

This means the new user navigation skeleton is not visible to normal users.

## Acceptance Criteria

- Current branch is not `main`.
- New user navigation shell exists as an internal skeleton only.
- User tabs are exactly: الرئيسية / المال / المهام / الموردون / المزيد.
- Money tab exists and is marked as requiring a current plan.
- `enableNewUserBottomNavigation` remains disabled by default.
- `/dev/user-navigation-shell` is guarded by the feature flag.
- Disabled flag redirects safely to `/home`.
- Default route remains unchanged.
- Existing `/home` behavior remains unchanged.
- Existing `MainShell` remains unchanged.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- The new shell is a skeleton only and does not yet connect to real current-plan state.
- The route currently uses a local static flag, not remote configuration.
- Future work must add real route/current-plan/permission guards before any user-facing activation.
- Redirecting the disabled dev route to `/home` is safe for current behavior, but future guard wiring should be tested through real router navigation.

## Next Step

Recommended next step:

```text
Phase 3B - Route Guard Wiring gradually
```

Alternative if 3A remains stable after review:

```text
Phase 3B - Money tab integration behind flag
```
