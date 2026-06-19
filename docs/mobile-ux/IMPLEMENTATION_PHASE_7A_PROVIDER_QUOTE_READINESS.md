# Phase 7A - Providers Quotes Readiness

Date: 2026-06-19
Scope: Provider quote readiness contract only
Status: Ready for review

## What Was Added

- Added `ProviderQuoteReadiness` under `mobile/lib/features/marketplace/models/`.
- The readiness contract can carry source-backed provider quote snapshots for:
  - provider count
  - service count
  - quote request count
  - new quote request count
  - pending sync count
- Added tests proving that source counts stay hidden while `enableProviderQuotes` remains disabled.

## Why This Is Readiness Only

This phase does not open marketplace screens, quote request screens, provider dashboard screens, or provider-mode surfaces.

It only defines a safe contract for future provider/quote integration behind feature flags.

## Why Provider Quotes Stay Disabled

`enableProviderQuotes` remains `false` by default. The readiness contract returns `featureDisabled` and hides provider/quote counts unless a test/dev caller explicitly enables the flag.

## Why No Bookings Or Payments Were Added

The readiness model intentionally does not represent:

- confirmed bookings
- deposits
- payment status
- payment processing
- loans or financing

Quote readiness is treated as planning context only.

## Why No Backend Calls Were Added

`ProviderQuoteReadiness` accepts existing snapshots only. It does not import API clients, providers, repositories, local databases, or network helpers.

## Why `/home` Was Not Changed

`/home` still uses the current production `MainShell`. This phase adds no route wiring and no active UI replacement.

## Why `MainShell` Was Not Changed

`MainShell` remains untouched and continues to own the live user shell.

## Acceptance Criteria

- Current branch is not `main`.
- `enableProviderQuotes` remains disabled by default.
- `enableProviderMode` remains disabled by default.
- `enableNewUserBottomNavigation` remains disabled by default.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Provider and quote counts are hidden unless `enableProviderQuotes` is explicitly enabled for a test/dev caller.
- No bookings, deposits, payment status, payment processing, loans, or financing flows are introduced.
- Offline pending sync is represented without notification permission prompts.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- This does not prove real provider marketplace or quote request UI readiness.
- Future wiring must keep quote readiness separate from confirmed booking/payment semantics.
- Provider-mode and provider-shell flags must remain off until explicitly approved.

## Next Step

Recommended next step:

```text
Phase 8A - Notifications Offline Release Readiness
```

Alternative if provider planning needs another gate:

```text
Phase 7B - Provider quote adapter behind flag
```
