# Phase 2B - Guest-first Onboarding Handoff

Date: 2026-06-19
Scope: Safe routing, local persistence, and generated dashboard handoff skeleton
Status: Ready for review

## What Was Built

- Added JSON serialization for `GuestOnboardingDraft`.
- Added simple validation helpers for path, persona, location seed, timeline seed, and local preview readiness.
- Added `GuestOnboardingStorage` using `SharedPreferences` only.
- Added explicit persistence methods to `GuestOnboardingProvider`.
- Added `GeneratedDashboardSeed` to build a local preview summary from a draft.
- Added a dev-only guest onboarding route protected by `enableGuestFirstOnboarding`.

## Local Draft Persistence

The draft is saved in `SharedPreferences` under:

```text
aarast.guest_onboarding_draft.v1
```

The storage API is intentionally small:

- `saveDraft`
- `loadDraft`
- `clearDraft`
- `hasDraft`

No SQLite migration, local database change, offline sync service change, backend call, or Prisma change was added.

## Not Wired Intentionally

- The provider is not registered in `main.dart`.
- The current `/onboarding` route is not replaced.
- `SplashScreen` still uses the current startup behavior.
- `MainShell` behavior is unchanged.
- No real `WeddingPlan` is created.
- No backend migration or guest-to-account migration is implemented.

## Routing

A temporary internal route was added:

```text
/dev/guest-onboarding
```

It is protected by `AppFeatureFlags.defaults.enableGuestFirstOnboarding`. Because the flag remains `false` by default, opening the route directly redirects to the current `/onboarding` route. The default app route is unchanged.

## Future Handoff

A later phase can use `GeneratedDashboardSeed` as the local handoff object before creating a real `WeddingPlan`. The real handoff should:

1. Load the saved guest draft.
2. Build a local preview.
3. Show the generated dashboard/Today Center path behind the feature flag.
4. Create a real server `WeddingPlan` only after auth/migration rules are approved.
5. Preserve local data until migration succeeds.

## Acceptance Criteria

- Current branch is not `main`.
- `enableGuestFirstOnboarding` remains `false` by default.
- Local persistence uses `SharedPreferences` only.
- No backend, Prisma, admin-web, Docker, deployment, or production config files are changed.
- Current onboarding, splash, default route, and `MainShell` behavior stay unchanged.
- Generated dashboard handoff is a local model only.
- Logic tests cover serialization, storage, seed generation, provider persistence, and route flag behavior.
- `dart format`, `flutter analyze`, `flutter test`, and `git diff --check` are run and reported.

## Risks

- The dev route is still not a complete onboarding flow; it only opens the first skeleton screen when the flag is enabled.
- Draft persistence stores private planning data on-device; later phases must keep clear/migration behavior explicit.
- `GeneratedDashboardSeed` is a preview helper, not the single source of truth for the real dashboard.
- Real route progression and account migration still need careful Phase 2C work.

## Next Step

Phase 2C - Complete safe internal route flow, local draft hydration, and guarded generated dashboard preview.
