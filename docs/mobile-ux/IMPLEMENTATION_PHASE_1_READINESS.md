# Phase 1 - Implementation Readiness

Date: 2026-06-19
Scope: Mobile rebuild readiness only
Status: Ready for review

## Purpose

This document records the first implementation-readiness slice for the Aarast mobile rebuild. The work prepares feature flag and route guard contracts without changing visible mobile behavior, navigation, backend, admin, Prisma, production config, or deployment files.

## What Was Prepared

- Added a mobile feature flag skeleton for upcoming rebuild capabilities.
- Added route guard type/result/policy skeletons for later routing work.
- Added unit tests for the new feature flag and route guard logic.
- Preserved the current `app_router.dart` and `MainShell` behavior.
- Preserved current offline/sqflite/JSON fallback behavior.

## Files Added

- `mobile/lib/core/config/app_feature_flags.dart`
- `mobile/lib/core/routing/route_guard_types.dart`
- `mobile/lib/core/routing/route_guard_result.dart`
- `mobile/lib/core/routing/route_guard_policy.dart`
- `mobile/test/core/config/app_feature_flags_test.dart`
- `mobile/test/core/routing/route_guard_policy_test.dart`
- `docs/mobile-ux/IMPLEMENTATION_PHASE_1_READINESS.md`

## Routes That Need Guards Later

- `/home`: future guest/current-plan and user shell guard.
- `/wedding-plans/:id/dashboard`: current plan, sharing, and privacy guard.
- `/wedding-plans/:id/plan-center`: current plan and ownership/sharing guard.
- `/wedding-plans/:id/finance`: current plan plus finance permission guard.
- `/wedding-plans/:id/expenses/create`: current plan plus finance write guard.
- `/wedding-plans/:id/debts`: current plan plus debt/finance permission guard.
- `/wedding-plans/:id/debts/create`: current plan plus finance write guard.
- `/debts/:debtId`: debt access and finance permission guard.
- `/debts/:debtId/installments/create`: debt access plus finance write guard.
- `/wedding-plans/:id/tasks`: current plan plus task access guard.
- `/wedding-plans/:id/tasks/create`: current plan plus task write guard.
- `/wedding-plans/:id/guests`: current plan plus guest permission guard.
- `/wedding-plans/:id/sharing`: owner/sharing permission guard.
- `/wedding-plans/:id/notifications`: current plan plus notification access guard.
- `/providers/:id/quote`: auth, current plan, provider quote flag, and online guard.
- `/provider/apply`: provider mode or controlled path guard.
- `/provider/dashboard`: provider-only guard.
- `/provider/services/new`: provider-only and provider status guard.
- `/provider/packages/new`: provider-only and provider status guard.

## Screens That Stay As They Are Now

- `SplashScreen`
- `OnboardingScreen`
- `LoginScreen`
- `RegisterScreen`
- `MainShell`
- `HomeScreen`
- `WeddingPlanDashboardScreen`
- Money, debt, task, guest, sharing, notification, settings, More, marketplace, provider, and support screens.

No screen was rebuilt or visually changed in this phase.

## Feature Flags

- `enableGuestFirstOnboarding`: future guest-first onboarding entry.
- `enableProviderMode`: future provider path activation.
- `enableProviderQuotes`: future quote request/quote lifecycle activation.
- `enableGuestContacts`: future explicit contact import/selection.
- `enableOfflineSync`: existing offline sync capability; kept enabled because it is already wired and must not be removed.
- `enableAIHelper`: future AI helper; disabled by default.
- `enablePushNotifications`: future push permission/deep-link behavior; disabled by default.
- `enableSubscriptions`: future monetization; disabled by default.
- `enableMaps`: future map/location UI; disabled by default.
- `enableAnalytics`: future product analytics; disabled by default.
- `enableNewUserBottomNavigation`: future user bottom navigation replacement; disabled by default.
- `enableProviderShell`: future provider-only shell; disabled by default.
- `enableSingleDashboardSummary`: future single dashboard summary source; disabled by default.

## Not Implemented Intentionally

- No onboarding screens.
- No navigation replacement.
- No `app_router.dart` integration.
- No `MainShell` behavior change.
- No backend changes.
- No Prisma changes.
- No admin-web changes.
- No production config changes.
- No notification permission request.
- No AI, subscriptions, payments, maps, analytics, provider shell, or quote lifecycle exposed to users.

## Acceptance Criteria

- Current branch is not `main`.
- Feature flags exist in mobile code.
- Incomplete or risky features are disabled by default.
- Offline sync is not disabled or removed.
- Route guard types include guest, auth, current plan, finance, task, guest, provider, user, and feature flag guard categories.
- Route guard results support allow, redirect, and blocked outcomes.
- Route guard skeleton is not wired into the current router.
- Existing mobile UI and navigation remain unchanged.
- Required mobile checks are run and reported.

## Risks

- The route guard skeleton is intentionally theoretical until Phase 3 wiring; future implementation must still validate every real route.
- `enableOfflineSync` is enabled because offline sync already exists; future teams must not treat it as permission to rewrite local storage.
- Feature flags are local constants only; remote/backend-driven flags are out of scope for this phase.
- Provider/user separation is not enforced until future route/shell integration.

## Next Step

Phase 2 - Guest-first Onboarding Skeleton.
