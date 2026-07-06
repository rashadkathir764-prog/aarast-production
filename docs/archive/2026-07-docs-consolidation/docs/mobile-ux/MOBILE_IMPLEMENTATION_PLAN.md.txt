# Aarast Mobile Implementation Plan

Date: 2026-06-19
Stage: Mobile Implementation Plan
Status: Planning document only

## 1. Purpose

This plan converts the product, UX, navigation, architecture, state, offline, and privacy blueprints into a safe mobile implementation sequence.

It does not authorize code changes by itself. Each implementation task must cite the relevant blueprint, define acceptance criteria, and run the required checks.

## 2. Current Mobile Reality

Current mobile implementation includes:

- Flutter app with `go_router`, Provider state management, `shared_preferences`, and `sqflite`.
- `MainShell` currently hosts an RTL indexed stack with Home, Providers, Tasks, and More.
- Current shell does not yet expose the target user bottom navigation as Home, Money, Tasks, Providers, More.
- Current quick add supports expense, debt, task, guest-list entry, and new plan.
- User and provider routes both exist in `app_router.dart`.
- `DashboardSummaryProvider` and `HomeDashboardProvider` duplicate similar aggregation responsibilities.
- Offline cache and sync queue are already wired into money, debts, tasks, plans, sharing, and marketplace APIs.
- Existing screens include money, debts/installments, tasks, providers, guests, sharing, notifications, settings, and plans.

## 3. Implementation Principles

- Do not start visual polish before product contracts are stable.
- Do not rewrite broad screens in one patch.
- Do not modify backend/admin routes unless the specific implementation task requires it.
- Do not change local database schema without following `docs/architecture/MIGRATION_PLAN.md`.
- Do not expose unfinished AI, maps, subscriptions, payments/deposits, push, analytics, quote acceptance, or provider operations without feature flags.
- Preserve offline/sqflite and JSON fallback behavior.
- Preserve user changes and commit small phases only when requested.
- Every repeated summary number must flow through the single source of truth plan.

## 4. Phase 1 - Implementation Readiness

Goal: prepare contracts without user-facing behavior changes.

Tasks:

- Add or confirm mobile feature flag definitions.
- Add route and state acceptance criteria to implementation tickets.
- Identify current routes that need guards.
- Identify screens that will be rebuilt vs refactored using `CURRENT_STATE_AUDIT.md`.
- Define exact widget tests before replacing shell/navigation behavior.

Exit criteria:

- Implementation tickets reference the required blueprints.
- No incomplete route can become visible accidentally.
- Test plan exists for every route touched.

## 5. Phase 2 - Guest-First Onboarding Skeleton

Goal: introduce the product entry sequence safely.

Sequence:

1. Welcome.
2. Choose Path.
3. Persona.
4. Location setup.
5. Wedding date.
6. Priorities.
7. Budget setup.
8. Suggested categories.
9. Generated dashboard handoff.

Rules:

- Account is not required at first launch.
- Provider path must be separate from wedding-user path.
- Guest draft must be stored locally.
- Location permission is requested only if user taps "use my location".
- Push permission is not requested here.

Checks:

- Widget tests for onboarding steps.
- Route tests for user/provider path split.
- Manual smoke: install fresh, complete guest onboarding, reach dashboard without login.

## 6. Phase 3 - Navigation and Route Guards

Goal: align navigation with `NAVIGATION_BLUEPRINT.md`.

User bottom navigation:

- Home.
- Money.
- Tasks.
- Providers.
- More.

Provider bottom navigation:

- Home.
- Requests.
- Offers.
- Profile.
- More.

Implementation steps:

- Replace shell tab mapping behind a feature flag first if risky.
- Add Money tab using existing finance screen with active plan ID.
- Keep Providers tab as marketplace browse only until quote/acceptance is ready.
- Add route guards for no-plan, guest-only, auth-required, permission-denied, provider-only, and feature-disabled states.
- Remove duplicate entry points after each destination has one approved path.

Checks:

- No bottom-nav item opens a blank or wrong-role screen.
- No route leaks provider-only screen to normal user flow.
- Auth-required route shows account gate instead of hard redirecting unexpectedly.

## 7. Phase 4 - Single Dashboard Summary Source

Goal: stop duplicate summary calculations.

Implementation steps:

- Create one current-plan summary provider/service contract.
- Migrate Home and plan dashboard to that source.
- Preserve permission checks for shared members.
- Add cached/offline summary behavior.
- Remove duplicate aggregation only after tests prove parity.

Screens affected:

- Home / Today Center.
- Wedding plan dashboard.
- My Plans summary cards.
- More dashboard snippets if any.

Checks:

- Days remaining, progress, budget, spent, debt, task, guest, provider, and unread counts match across screens.
- Offline dashboard uses cached data and marks stale state.

## 8. Phase 5 - Money Flow Stabilization

Goal: preserve existing finance strengths while aligning with blueprint.

Implementation steps:

- Keep existing budget/expense/debt/installment APIs.
- Add clear Money landing model if needed.
- Keep expenses/debts private by default.
- Gate write actions by permission.
- Make mark-paid/edit/delete behavior explicit before adding new UI.
- Confirm offline write queue for expenses, debts, and installments.

Checks:

- Shared member without finance permission cannot view private financial details.
- Offline expense/debt create queues and syncs.
- Totals match dashboard source.

## 9. Phase 6 - Tasks, Guests, and Sharing

Goal: make collaboration flows reliable after core shell is stable.

Implementation steps:

- Align task timeline with wedding date and task templates.
- Add Today/upcoming/overdue grouping.
- Keep guest contact import permission user-triggered only.
- Keep shared member permissions explicit.
- Add no-plan and no-permission states.

Checks:

- Task create/edit/delete respects offline queue where supported.
- Guest duplicate prevention remains intact.
- Sharing cannot expose private finance details without permission.

## 10. Phase 7 - Providers and Quotes

Goal: align provider marketplace with product rules without pretending confirmed booking/payment exists.

Implementation steps:

- Keep provider browse/search visible only when stable.
- Keep quote request behind auth gate.
- Hide quote acceptance/provider-in-plan until backend/data model are ready.
- Keep provider admin verification requirements visible in documentation, not user promises.
- Do not add payment/deposit status.

Checks:

- Provider/user flows stay separated.
- Quote request uses location and selected category where available.
- Provider appears in plan only after an approved implementation task creates the data model/API path.

## 11. Phase 8 - Notifications, Offline, and Release Readiness

Goal: make cross-cutting behaviors stable before visual polish.

Implementation steps:

- Add notification list/deep-link handling from blueprint.
- Request push permission only after meaningful trigger.
- Keep offline status visible on affected screens.
- Add sync failure recovery states.
- Complete QA matrix and release gate.

Checks:

- Notification opens useful route or safe fallback.
- Offline queued action never claims cloud success.
- Manual smoke passes before visual polish begins.

## 12. Minimum Test Set Per Mobile Patch

For docs-only tasks:

- `git diff --check`.

For mobile code tasks:

- `dart format` on touched Dart files.
- `flutter analyze`.
- `flutter test`.
- Targeted widget/provider tests for touched flow.
- Manual smoke for visible navigation or post-login changes.

For backend-touching tasks:

- Backend check command from current package scripts.
- Relevant smoke script.

## 13. Acceptance Criteria

- Implementation is sequenced after the required blueprints.
- Current mobile reality and risks are reflected.
- Guest-first, route guards, single source, offline, privacy, and provider/user separation are included.
- Test requirements are clear.
- No code is changed.

## 14. Risks

- Rebuilding shell before guest/current-plan state is ready can create dead routes.
- Replacing dashboard aggregation too quickly can break finance/task summaries.
- Adding quote/provider acceptance without backend data support can create fake marketplace behavior.
- Visual polish before logic stabilization can hide product defects.

## 15. Next Implementation Notes

- Next stage: `docs/testing/MOBILE_QA_PLAN.md`.
- First code phase should be a narrow skeleton behind feature flags, not a full screen rewrite.
