# Aarast Mobile Current State Audit

Date: 2026-06-19
Branch: phase/mobile-home-dashboard-ux-v2
Scope: Flutter mobile current-state audit only
Result: Product/UX rebuild needed before visual polish

## 1. What Was Read

Official rebuild guide:

- `docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md`

Approved project documents:

- `PRODUCT_VISION.md`
- `MVP_SCOPE.md`
- `PHASES.md`
- `DATABASE_PLAN.md`
- `API_PLAN.md`
- `TESTING_PLAN.md`
- `SMOKE_TESTS.md`
- `GIT_WORKTREE_GUIDE.md`
- `DEPLOYMENT_PLAN.md`
- `DECISIONS.md`
- `AGENTS.md`
- `README.md`
- `API_CONTRACT.md`
- `MOBILE_QA_PLAN.md`
- `MANUAL_QA_REPORT.md`
- `mobile/README.md`

Mobile code inspected by static read/search:

- `mobile/lib/main.dart`
- `mobile/lib/app.dart`
- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/features/shell/main_shell.dart`
- `mobile/lib/features/home/**`
- `mobile/lib/features/auth/screens/**`
- `mobile/lib/features/wedding_plans/screens/**`
- `mobile/lib/features/finance/screens/**`
- `mobile/lib/features/debts/screens/**`
- `mobile/lib/features/tasks/screens/**`
- `mobile/lib/features/guests/screens/**`
- `mobile/lib/features/sharing/screens/**`
- `mobile/lib/features/notifications/screens/**`
- `mobile/lib/features/settings/screens/**`
- `mobile/lib/features/more/screens/**`
- `mobile/lib/features/marketplace/screens/**`
- `mobile/lib/core/offline/**`

No application code was modified during this audit.

## 2. Current Mobile Architecture Snapshot

The app is a Flutter Arabic-first RTL app using `go_router`, `provider`, `shared_preferences`, API repositories, and an offline sync layer.

`mobile/lib/main.dart` wires the current app around these major providers:

- Auth/session: `AuthController`, `AuthRepository`, `AuthStorage`.
- Plans: `WeddingPlansProvider`.
- Dashboard summaries: `DashboardSummaryProvider` and `HomeDashboardProvider`.
- Money: `FinanceProvider`.
- Debts/installments: `DebtInstallmentProvider`.
- Tasks/timeline: `TaskTimelineProvider`.
- Sharing: `SharingProvider`.
- Notifications: `NotificationsProvider`.
- Guests: `GuestsProvider`.
- Settings: `SettingsProvider`.
- Marketplace/provider mode: `ProviderMarketplaceProvider`, `ProviderDashboardProvider`.
- Offline: `OfflineSyncService` plus local database implementations.

`mobile/lib/core/routing/app_router.dart` exposes routes for Auth, Home shell, wedding plans, plan dashboard, plan center, finance, debts, installments, tasks, sharing, guests, notifications, settings, provider marketplace, provider details, quote request, provider apply, provider dashboard, service/package creation, and support placeholder.

`mobile/lib/features/shell/main_shell.dart` is currently the active post-login shell for `/home`. It uses an `IndexedStack` with four visible areas:

- Home overview: selected plan dashboard when an active plan exists, otherwise `HomeScreen`.
- Providers: embedded `ProviderMarketplaceScreen`.
- Tasks: active plan `TaskTimelineScreen`.
- More: `MoreScreen`.

This does not match the rebuild README target user bottom navigation of:

- الرئيسية
- المال
- المهام
- الموردون
- المزيد

The current shell also auto-selects the first loaded plan as `_activePlanId`. That is workable for MVP continuity but not enough for the rebuild because the product needs an intentional generated dashboard after onboarding and a clear current-plan source.

## 3. Screen Classification

Classification meanings:

- Keep: usable with minor copy/QA only.
- Refactor: keep base behavior, redesign structure/entry/state contracts.
- Rebuild: replace flow structure after Blueprint approval.
- Merge: fold into another planned surface.
- Remove: retire or hide after replacement.

| Area | Screen/file | Classification | Reason |
|---|---|---|---|
| App start | `SplashScreen` | Keep | Restores session and routes to onboarding/home. Needs later guest-first routing alignment only. |
| Onboarding | `OnboardingScreen` | Rebuild | Current screen is a welcome/marketing page that sends users to registration. Missing Choose Path, Persona, Location Setup, Wedding Date, Priorities, Budget Setup, Suggested Categories, and guest-first plan creation. |
| Auth | `LoginScreen` | Refactor | Functional login surface, but account should be requested only at gates that require server identity. |
| Auth | `RegisterScreen` | Rebuild | Mixes customer and provider signup in one account-first flow. Rebuild should split user/provider paths and support guest migration after signup. |
| Auth | `OtpScreen` | Refactor | Useful OTP foundation, but route role in guest-first flow must be defined. |
| Shell | `MainShell` | Rebuild | Current navigation has four effective tabs and no Money tab. Active plan is first loaded plan, not a deliberate generated/current plan state. |
| Home | `HomeScreen` and `home_widgets.dart` | Merge | Used when no active plan exists and has useful sections, but should merge into a new guest/no-plan Today Center and generated dashboard flow. |
| Home dashboard | `WeddingPlanDashboardScreen` | Rebuild | Current wireframe is intentionally logic-first and crowded. It includes AI snack behavior, provider placeholder rows, guest/provider summaries without a full product contract, and needs a single dashboard source. |
| Plan management | `PlanCenterScreen` | Refactor | Useful plan-management direction and recent lifecycle fix. Needs alignment with Navigation Blueprint and plan edit/roles rules. |
| Plans list | `MyWeddingPlansScreen` | Refactor | Useful list, but contains mock progress/days values for visual effect and a shared tab that does not fully replace `SharedWeddingPlansScreen`. |
| Plan creation | `CreateWeddingPlanScreen` | Rebuild | Creates only title/city/date/budget. Rebuild must become the final step of onboarding after persona, location, date, priorities, budget, and suggested categories. |
| Money | `BudgetExpenseScreen` | Refactor | Good MVP money base with permission-aware access, loading/error/empty states, categories, expenses, edit/delete. Needs new Money UX, single source of truth, and dashboard integration. |
| Money form | `CreateBudgetCategoryScreen` | Keep | Narrow functional form. Keep behavior and restyle later after Design System. |
| Money form | `CreateExpenseScreen` | Refactor | Functional create/edit form. Needs provider/category/linking rules, offline state clarity, and permission-aware entry contract. |
| Debts | `DebtInstallmentScreen` | Refactor | Strong MVP base with summary, filters, permission gates, empty/error/loading states. Needs Money integration and upcoming installment priority rules. |
| Debts | `DebtDetailsScreen` | Keep | Useful debt detail/installment surface. Needs only UX copy/state polish after Blueprint. |
| Debt form | `CreateDebtScreen` | Refactor | Functional form. Needs contact/phone, provider linkage, privacy, and validation rules from Product/Data Blueprints. |
| Installment form | `CreateInstallmentScreen` | Keep | Useful form for existing debt model. Needs minor state/copy alignment later. |
| Tasks | `TaskTimelineScreen` | Refactor | Strong task/timeline base with filters, due list, complete/reopen/delete. Needs task templates tied to wedding date and persona/assignee rules. |
| Task form | `CreateTaskScreen` | Refactor | Useful form. Needs templates, suggested due dates, assignment rules, and current-plan entry rules. |
| Guests | `GuestListScreen` | Refactor | Persisted guests are implemented with add/edit/delete/status and contact validation. Needs UX integration, grouping rules, import strategy, privacy, and no broad contact upload. |
| Sharing | `SharingScreen` | Refactor | Functional but plain. Needs richer permission explanation, owner-only actions, and privacy-first UX. |
| Sharing | `AddSharedMemberScreen` | Refactor | Good phone lookup and permission switches. Needs persona copy and permission presets. |
| Sharing | `EditSharedMemberScreen` | Refactor | Useful permission editing surface. Needs same permission presets and audit wording. |
| Sharing | `SharedWeddingPlansScreen` | Keep | Useful dedicated surface for shared plans. May later merge into More/Plans according to Navigation Blueprint. |
| Notifications | `NotificationsScreen` | Refactor | Persisted notifications list exists with read/delete/read-all. Needs deep-link contract and notification type mapping. |
| Settings | `SettingsScreen` | Refactor | Real settings/profile/notification preferences base. Needs content/persona/account/offline settings rules. |
| More | `MoreScreen` | Refactor | Useful hub for account, notifications, plans, providers, settings, support, logout. Needs cleanup after Navigation Blueprint to prevent duplicate entry points. |
| Support | `AarastComingSoonScreen` via `/support` | Rebuild | Placeholder is acceptable while support blueprint is pending, but should not be treated as product-complete. |
| Marketplace | `ProviderMarketplaceScreen` | Refactor | Real provider listing/search/filter/favorite flow exists. Needs plan-location matching, feature flag/phase rules, and less repeated provider CTA in user path. |
| Marketplace | `ProviderDetailsScreen` | Refactor | Real provider details/services/packages/reviews and quote CTA. Needs quote-to-plan acceptance path and share behavior. |
| Marketplace | `QuoteRequestScreen` | Refactor | Real quote form exists and requires auth. Needs guest gate strategy, plan context, and future quote-to-plan conversion rules. |
| Provider mode | `ProviderApplyScreen` | Rebuild | Provider apply exists, but provider path must be explicitly split from user flow and gated by provider/admin operations. |
| Provider mode | `ProviderApplyStatusScreen` | Refactor | Useful status placeholder after provider application. Needs backend/admin lifecycle copy. |
| Provider mode | `ProviderDashboardScreen` | Refactor | Rich provider dashboard exists with status, stats, services, packages, quotes. Needs provider-only navigation and admin approval assumptions. |
| Provider mode | `AddProviderServiceScreen` | Refactor | Useful provider-owned service form. Needs category/location validation and feature flag gating. |
| Provider mode | `AddProviderPackageScreen` | Refactor | Useful provider package form. Needs provider operations rules and marketplace launch readiness. |
| Legacy/unused dashboard widgets | `new_dashboard_widgets.dart` | Remove | Contains mock fixed counts, snack placeholders (`قيد الإعداد`), and unsafe route fallback patterns like empty plan id. Should not be used in the rebuild. |
| Dashboard widget library | `aarast_dashboard_widgets.dart` | Refactor | Contains useful bottom nav/account/dashboard components but mixes wireframe and visual widgets. Extract reusable design-system pieces later. |
| Offline core | `core/offline/**` | Keep | Existing local database/sync queue/cache/status layer must be preserved. Do not delete offline/sqflite/json behavior. |

## 4. Main Problems Found

1. Startup is account-first, not guest-first.
   - The current onboarding CTA leads to registration.
   - The required rebuild wants guest use, plan creation, and signup only when an operation needs ownership/server/sync/sharing/quote.

2. User and provider flows are mixed.
   - User marketplace surfaces show provider join CTAs.
   - `RegisterScreen` can start provider signup.
   - Provider dashboard/apply routes are globally accessible routes rather than a separate provider shell.

3. Navigation does not match the target model.
   - Current shell has Home/Providers/Tasks/More plus center action.
   - Target user navigation requires Home/Money/Tasks/Providers/More.
   - Provider navigation is not a distinct shell yet.

4. Dashboard data is not yet a single product source.
   - `HomeDashboardProvider` and `DashboardSummaryProvider` both aggregate similar plan data.
   - `MyWeddingPlansScreen` uses mock progress/days values.
   - Dashboard, plans list, and plan center can show different interpretations of progress/readiness.

5. Home Dashboard is still a product wireframe, not a final UX.
   - It intentionally uses compact wireframe sections.
   - It exposes AI advice with a snackbar saying AI is not enabled.
   - Provider rows say provider/quote linkage is not summarized in the plan yet.

6. Plan creation is too shallow for the new product direction.
   - Current create plan only collects title, city, date, estimated budget, and currency.
   - Required flow needs persona, location detail, priorities, budget setup, suggested categories, generated dashboard, and guest migration.

7. Quote/provider flow exists but is not closed into plan operations.
   - Quote request can be sent.
   - Provider dashboard can review quote requests.
   - The product still lacks a defined accepted quote to `PlanProvider` to expense/debt/dashboard path.

8. Empty/loading/error states exist but are inconsistent.
   - Many MVP screens have decent states.
   - Support remains placeholder.
   - Some routes use snackbars for unavailable/incomplete features.
   - No cross-screen guide exists yet.

9. Arabic copy is scattered in widgets.
   - Persona-based groom/bride/helper/provider text is not centralized.
   - The copy matrix must come before a large rewrite.

10. Offline support exists but is not product-specified per screen.
   - Offline sync/cache layer is present.
   - The app still needs a screen-by-screen rule for local-only, pending-sync, synced, failed, and server-required actions.

## 5. Risks

- Rebuilding visual UI before Product/UX/Data/Architecture Blueprints will likely recreate the same dashboard and navigation contradictions.
- Changing routes before `NAVIGATION_BLUEPRINT.md` could break existing MVP flows and deep links.
- Changing Prisma/API before `docs/architecture/DATA_MODEL_BLUEPRINT.md` and `docs/architecture/BACKEND_FLOW_BLUEPRINT.md` could break smoke-tested backend contracts.
- Removing or casually replacing offline code could destroy local/sync behavior the README explicitly says to preserve.
- Leaving AI/provider/subscription/push/maps style features visible without feature flags risks showing incomplete features to users.
- Duplicated summary calculations can expose wrong budget/progress/debt/task state across Home, Plans, and Dashboard.
- Provider/user flow mixing can confuse users and create privacy issues.
- Sharing and finance permission mistakes can expose private financial data to shared members.

## 6. Priorities

### Priority 1 - Product Logic

- Define guest-first entry and signup gates.
- Define separate user/provider journeys.
- Define how a plan is created from onboarding.
- Define how quote requests convert into plan providers.
- Define what is forbidden until feature flags/admin operations exist.

### Priority 2 - UX Blueprint

- Specify every planned screen, entry point, displayed data, primary/secondary action, and states.
- Replace account-first onboarding with Welcome -> Choose Path -> Persona -> Location -> Wedding Date -> Priorities -> Budget -> Suggested Categories -> Generated Dashboard.

### Priority 3 - Navigation

- Replace the current four-area shell with the target user navigation after the Navigation Blueprint is approved.
- Define a provider-only shell.
- Define + action sheet rules and duplicate-entry restrictions.

### Priority 4 - Single Source Of Truth

- Choose one current-plan source.
- Choose one summary source for days remaining, progress, budget, debts, tasks, guests, providers, notifications, and sync state.
- Remove mock values from plan cards and legacy dashboard widgets.

### Priority 5 - Safe Implementation Planning

- Keep finance/debt/task/guest/sharing MVP bases where they work.
- Rebuild onboarding, shell, dashboard, plan creation, provider/user separation, and feature-flag behavior after the core Blueprints.

## 7. Screens To Rebuild

These should not be patched cosmetically first:

- `OnboardingScreen`
- `RegisterScreen` as a mixed customer/provider entry
- `MainShell`
- `WeddingPlanDashboardScreen`
- `CreateWeddingPlanScreen`
- Provider/user path split around `ProviderApplyScreen` and provider dashboard access
- Support placeholder route

Reason: these screens define product entry, role separation, navigation, plan generation, and first dashboard logic. Patching them visually before the Blueprints will preserve the wrong structure.

## 8. Screens To Develop/Refactor Only

These have useful MVP foundations and should usually be improved, not discarded:

- `BudgetExpenseScreen`
- `CreateBudgetCategoryScreen`
- `CreateExpenseScreen`
- `DebtInstallmentScreen`
- `DebtDetailsScreen`
- `CreateDebtScreen`
- `CreateInstallmentScreen`
- `TaskTimelineScreen`
- `CreateTaskScreen`
- `GuestListScreen`
- `SharingScreen`
- `AddSharedMemberScreen`
- `EditSharedMemberScreen`
- `SharedWeddingPlansScreen`
- `NotificationsScreen`
- `SettingsScreen`
- `MoreScreen`
- `ProviderMarketplaceScreen`
- `ProviderDetailsScreen`
- `QuoteRequestScreen`
- `ProviderDashboardScreen`
- `AddProviderServiceScreen`
- `AddProviderPackageScreen`

Reason: these screens already map to backend/API slices or useful MVP user operations. They need product rules, state rules, permissions, and navigation alignment before visual polish.

## 9. Screens/Widgets To Merge Or Remove Later

- Merge `HomeScreen` and `home_widgets.dart` into the future no-plan/guest Today Center path.
- Merge or reorganize shared plan entry between `MyWeddingPlansScreen`, `SharedWeddingPlansScreen`, and `MoreScreen`.
- Remove `new_dashboard_widgets.dart` after confirming it is not imported by active routes.
- Replace `AarastComingSoonScreen` usage for `/support` after Support/Disputes Blueprint.

## 10. Acceptance Criteria For Phase 0

- Current active branch is not `main`.
- Official rebuild README was read.
- Approved project docs were read.
- Current mobile routes, shell, screens, providers, and offline layer were inspected.
- Every current screen family is classified as Keep, Refactor, Rebuild, Merge, or Remove.
- Problems, risks, priorities, rebuild screens, and refactor-only screens are documented.
- No Flutter/backend/admin/deployment/business logic was modified.
- `REBUILD_EXECUTION_PROGRESS.md` is updated.
- `git diff --check` passes before commit.

## 11. Next Implementation Notes

- Next document must be `docs/mobile-ux/PRODUCT_LOGIC_BLUEPRINT.md`.
- Do not implement the onboarding rebuild yet.
- Do not change routes yet.
- Do not change Prisma/API yet.
- Do not remove offline/sqflite/json storage code.
- Do not expose AI, subscriptions, push permission prompts, provider marketplace launch assumptions, or payments.
