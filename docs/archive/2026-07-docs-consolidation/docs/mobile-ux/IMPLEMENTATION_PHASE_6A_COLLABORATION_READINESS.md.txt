# Phase 6A - Tasks Guests Sharing Readiness

Date: 2026-06-19
Scope: Collaboration readiness contract only
Status: Ready for review

## What Was Added

- Added `CollaborationFlowReadiness` under `mobile/lib/features/sharing/models/`.
- The readiness contract can carry source-backed collaboration snapshots for:
  - tasks
  - open tasks
  - shared members
  - guest counts when explicitly allowed by feature flag
  - pending sync count
- Added tests proving that guest counts are not exposed while `enableGuestContacts` remains disabled.

## Why This Is Readiness Only

This phase does not open or replace task, guest, or sharing screens. It only defines a safe readiness contract for later integration.

No new task mutations, guest invitations, member edits, or sharing actions were added.

## Why Guest Contacts Stay Disabled

`enableGuestContacts` remains `false` by default. If guest data is passed while the flag is disabled, the readiness contract marks guest contacts as blocked and does not expose a visible guest count.

## Why No Backend Calls Were Added

`CollaborationFlowReadiness` accepts existing snapshots only. It does not import API clients, providers, repositories, local databases, or network helpers.

## Why `/home` Was Not Changed

`/home` still uses the current production `MainShell`. This phase adds no route wiring and no active UI replacement.

## Why `MainShell` Was Not Changed

`MainShell` remains untouched and continues to own the live user shell.

## Acceptance Criteria

- Current branch is not `main`.
- `enableGuestContacts` remains disabled by default.
- `enableNewUserBottomNavigation` remains disabled by default.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Guest counts are hidden unless `enableGuestContacts` is explicitly enabled for a test/dev caller.
- Tasks and shared-member counts are source-backed only.
- Offline pending sync is represented without notification permission prompts.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- This does not prove real guest, task, or sharing screen readiness.
- Future wiring must respect sharing permissions and guest-contact feature flags.
- Guest data should remain non-visible until product approval for guest contacts is explicit.

## Next Step

Recommended next step:

```text
Phase 7A - Providers Quotes Readiness
```

Alternative if collaboration needs another gate:

```text
Phase 6B - Permission-mapped collaboration adapter behind flag
```
