# Phase 8A - Notifications Offline Release Readiness

Date: 2026-06-19
Scope: Notification/offline release readiness contract only
Status: Ready for review

## What Was Added

- Added `NotificationOfflineReleaseReadiness` under `mobile/lib/features/notifications/models/`.
- The readiness contract can carry source-backed release signals for:
  - push notification flag state
  - offline sync flag state
  - sync status
  - pending sync count
  - in-app notification count
  - unread count
- Added tests proving that notification permission is not requested by default.

## Why This Is Readiness Only

This phase does not register push notifications, ask for notification permission, create background handlers, or change app startup behavior.

It only defines a safe readiness contract for future release checks.

## Why Push Permission Is Not Requested

`enablePushNotifications` remains `false` by default. The readiness contract always returns `shouldRequestNotificationPermission == false`.

If a caller tries to mark notification permission as requested, the contract reports `permissionRequestBlocked`.

## Why Offline Behavior Was Not Changed

Offline sync already has existing service and status snapshots. This phase only reads `SyncStatusSnapshot` as an input and does not change:

- sqflite/mobile local database behavior
- JSON fallback behavior
- sync queue behavior
- app lifecycle sync behavior

## Why No Backend Calls Were Added

`NotificationOfflineReleaseReadiness` accepts existing snapshots only. It does not import API clients, providers, repositories, local databases, permission plugins, or network helpers.

## Why `/home` Was Not Changed

`/home` still uses the current production `MainShell`. This phase adds no route wiring and no active UI replacement.

## Why `MainShell` Was Not Changed

`MainShell` remains untouched and continues to own the live user shell.

## Acceptance Criteria

- Current branch is not `main`.
- `enablePushNotifications` remains disabled by default.
- `enableOfflineSync` remains enabled by default.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Notification permission is not requested.
- In-app notification counts are source-backed only.
- Pending sync, offline, and sync-error states are represented without changing sync behavior.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- This does not implement real push notifications.
- Future release work must add platform permission handling only behind explicit approval.
- Offline sync release gates still need device/runtime QA before production rollout.

## Next Step

Recommended next step:

```text
Release readiness audit for guarded mobile rebuild contracts
```

Alternative if notifications are approved later:

```text
Phase 8B - Push notification permission design behind explicit flag
```
