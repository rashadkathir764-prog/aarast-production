# Phase 2A - Guest-first Onboarding Skeleton

Date: 2026-06-19
Scope: Mobile guest-first onboarding skeleton only
Status: Ready for review

## What Was Built

- Added a `GuestOnboardingDraft` model for the future guest-first onboarding path.
- Added `GuestOnboardingProvider` for in-memory draft updates only.
- Added skeleton screens for Welcome, Choose Path, Persona, Location, Wedding Date, Priorities, Budget, Suggested Categories, and Generated Dashboard Preview.
- Added logic-only tests for draft and provider behavior.

## What Remains Disabled

- `enableGuestFirstOnboarding` remains `false` by default.
- The new screens are not connected to `app_router.dart`.
- The existing `/onboarding` route still opens the current account-first onboarding screen.
- No guest draft persistence is enabled yet.
- No backend migration or server plan creation is enabled.

## Why There Is No User-Facing Behavior Change

The skeleton files are not registered in the application router, not registered in `main.dart`, and not linked from `MainShell` or the current onboarding screen. Current users continue through the existing startup, onboarding, auth, shell, and plan creation behavior.

## How It Can Be Enabled Later

Phase 2B can add safe internal routes such as `/dev/guest-onboarding` behind `AppFeatureFlags.defaults.enableGuestFirstOnboarding`, then add local persistence and a generated dashboard handoff after route tests prove that the current default path is unchanged when the flag is disabled.

## Acceptance Criteria

- Current branch is not `main`.
- `enableGuestFirstOnboarding` remains `false` by default.
- No backend, Prisma, admin-web, Docker, deploy, or production config files are changed.
- No route replaces the current `/onboarding` route.
- No `MainShell` behavior changes.
- New onboarding model supports path, persona, location, wedding date, priorities, budget, and selected category keys.
- Provider supports in-memory setters and reset.
- Logic tests cover the draft and provider.
- `dart format`, `flutter analyze`, `flutter test`, and `git diff --check` are run and reported.

## Risks

- The skeleton screens are not a complete product flow until safe routing and persistence are added.
- In-memory draft state will be lost if wired without persistence in a later phase.
- Provider path remains conceptual and must not be exposed as a real provider onboarding flow before auth/provider operations are ready.
- Generated dashboard preview is not the real dashboard and must stay clearly separated from Home/Today Center work.

## Next Step

Phase 2B - Safe routing/local persistence/generated dashboard handoff.
