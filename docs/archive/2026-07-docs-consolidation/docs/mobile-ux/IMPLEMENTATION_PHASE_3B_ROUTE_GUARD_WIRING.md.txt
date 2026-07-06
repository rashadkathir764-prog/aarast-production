# Phase 3B - Gradual Route Guard Wiring

Date: 2026-06-19
Scope: Mobile route guard resolver and dev-route-only wiring
Status: Ready for review

## What Was Wired

- Added `AppRouteGuardResolver` to translate `RouteGuardResult` outcomes into `go_router` redirect paths.
- Wired the resolver only into internal development routes:
  - `/dev/guest-onboarding`
  - `/dev/user-navigation-shell`
- Kept `/dev/guest-onboarding` guarded by `enableGuestFirstOnboarding`.
- Kept `/dev/user-navigation-shell` guarded by `enableNewUserBottomNavigation`.
- Preserved the existing fallback behavior:
  - Disabled guest onboarding flag redirects to `/onboarding`.
  - Disabled user navigation flag redirects to `/home`.

## Why Wiring Is Limited To Dev Routes

The current route guard model is still a gradual foundation. Applying it broadly to production routes now could change visible user behavior, force unexpected auth gates, or alter existing route flows before current-plan and permission state are ready.

Limiting Phase 3B to dev routes lets the app validate feature-flag guard plumbing without exposing new navigation or changing active user paths.

## Why `/home` Was Not Changed

`/home` remains the stable entry into the current `MainShell`. Phase 3B does not replace the active shell, does not add the Money tab to the active bottom navigation, and does not apply new guards to `/home`.

## Why `MainShell` Was Not Changed

`MainShell` is the active user shell and still owns the current `/home` behavior. It was intentionally left untouched to avoid changing visible navigation, quick-add behavior, active plan selection, or existing tab state.

## Acceptance Criteria

- Current branch is not `main`.
- `enableGuestFirstOnboarding` remains disabled by default.
- `enableNewUserBottomNavigation` remains disabled by default.
- `/dev/guest-onboarding` remains guarded.
- `/dev/user-navigation-shell` remains guarded.
- Disabled guest onboarding flag redirects to `/onboarding`.
- Disabled user navigation flag redirects to `/home`.
- Default app route remains `AppRouter.splash`.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- The resolver currently supports feature-flag guard wiring for dev routes only; broader route guard adoption still needs current-plan, auth, and permission state design.
- A blocked guard requires an explicit fallback path, so future route wiring must choose safe destination routes intentionally.
- `AppFeatureFlags` remains local/static; remote or backend-driven flags are still out of scope.

## Next Step

Recommended next step:

```text
Phase 3C - Money tab internal integration behind flag
```

Alternative if route guard review finds state-readiness gaps:

```text
Phase 4 - Single Source of Truth readiness
```
