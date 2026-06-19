# Phase 2C - Internal Guest Onboarding Flow

Date: 2026-06-19
Scope: Mobile internal guest-first onboarding flow behind feature flag
Status: Ready for review

## What Was Connected Internally

- `/dev/guest-onboarding` now opens an internal flow controller instead of only the first welcome skeleton screen.
- The internal flow connects:
  - Welcome -> Choose Path
  - Choose Path -> Persona for wedding users
  - Choose Path -> safe provider pending screen for provider path
  - Persona -> Location
  - Location -> Wedding Date
  - Wedding Date -> Priorities
  - Priorities -> Budget
  - Budget -> Suggested Categories
  - Suggested Categories -> Generated Dashboard Preview

## Why There Is No User-Facing Behavior Change

- `enableGuestFirstOnboarding` remains `false` by default.
- `/dev/guest-onboarding` remains guarded by the feature flag.
- When the flag is disabled, the dev route redirects to the current `/onboarding` route.
- The default app route is unchanged.
- The existing `/onboarding` route still opens the current onboarding screen.
- `MainShell`, `/home`, provider dashboard routes, backend APIs, Prisma, and admin web are unchanged.

## Draft Hydration

- The first internal flow screen initializes `GuestOnboardingProvider` with `GuestOnboardingStorage`.
- `GuestOnboardingStorage` still uses `SharedPreferences` only.
- The flow calls `loadOrStartDraft` before rendering the onboarding steps.
- If a saved draft exists, the flow uses it.
- If no saved draft exists, the flow starts with `GuestOnboardingDraft.empty()`.
- No backend, SQLite, migration, or `OfflineSyncService` behavior is used.

## Explicit Save

- Important choices are saved explicitly through provider methods:
  - path
  - persona
  - location
  - wedding date
  - priorities
  - budget
  - categories
- The flow does not add complex autosave behavior.

## Generated Preview

- `GeneratedDashboardPreviewScreen` reads the current local draft.
- It builds a `GeneratedDashboardSeed`.
- It displays:
  - city/location label
  - wedding date label
  - estimated budget label
  - priorities
  - selected categories
  - next best action
- It does not create a real `WeddingPlan`.
- It does not call an API.
- It does not change the current dashboard.

## Provider Path Handling

- Selecting provider path inside the internal flow saves the provider path in the local draft.
- The flow opens a safe provider pending screen.
- It does not open provider dashboard.
- It does not open real provider registration.
- It stays behind the disabled-by-default guest onboarding flag.

## Acceptance Criteria

- Current branch is not `main`.
- `enableGuestFirstOnboarding` remains `false` by default.
- `/dev/guest-onboarding` remains guarded.
- Flag disabled redirects to current `/onboarding`.
- Initial route remains unchanged.
- Existing `/onboarding` remains unchanged.
- `/home` and `MainShell` remain unchanged.
- Draft hydration uses `SharedPreferences` only.
- Explicit save exists after important updates.
- Provider path is handled by a safe pending screen.
- Generated preview is local-only and creates no real plan.
- No backend, Prisma, admin, Docker, deployment, or production config changes are included.

## Risks

- This is still an internal development flow, not the production onboarding replacement.
- Local draft data remains device-local and will need a later migration plan before account handoff.
- Generated preview is not the real dashboard single source of truth.
- Provider path is intentionally pending until provider auth/navigation work is approved.

## Next Step

Phase 3 - Navigation + Route Guards, or Phase 2D if review finds a missing guest onboarding detail.
