# Aarast Full Screen Truth Audit

Generated: 2026-06-26

Scope: mobile UX/product logic, backend/API truth, route/data-source mapping, and available runtime verification.

Status terms:

- `PASS`: verified by current command or code evidence.
- `PARTIAL`: real implementation exists, but one or more product, UX, permission, copy, visual, or runtime gaps remain.
- `P0`: must be fixed before broad phone QA or release-candidate review.
- `P1`: should be fixed before visual polish or pilot QA.
- `P2`: polish/cleanup after the product truth is stable.
- `UNKNOWN`: not proven by runtime visual/device evidence in this audit.

## 1. Executive Summary

Aarast is not yet ready to be treated as a fully truthful mobile product surface. The backend is comparatively strong and broad: schema, modules, tests, and smoke coverage exist for auth, onboarding, plans, dashboard summary, money, debts/installments, tasks, guests, sharing, notifications, marketplace, quotes, and provider dashboard. The mobile app has most screen families and API providers, and the current automated checks pass.

The blocking problem is not that "nothing exists"; the problem is that live mobile truth is inconsistent. The app mixes live backend-backed flows, local guest flows, guarded rebuild/dev flows, old shell flows, and user-visible local/dev/internal copy. This can mislead a QA tester or real user about whether data is saved locally, synced to backend, protected by account, provider-only, or still experimental.

Top product truth risks:

1. `/onboarding` directly opens `GuestOnboardingFlowScreen` even though the guarded dev route and documentation history say guest-first onboarding should stay disabled by default until activated.
2. `AppFeatureFlags.devBypassLoginGatesForUxExploration` is `true`, which makes protected provider/account gates unsafe as a default product truth.
3. User-visible copy still contains "local", "temporary", "experimental", "backend/server" and "current server" language in several screens.
4. `PlanCenterScreen` displays saved address details with fallback values like `اختياري`, which reads like saved data instead of missing optional detail.
5. Persona/gender-aware Arabic copy is not applied consistently; many user and provider screens are hardcoded feminine.
6. The live shell has Home/Money/Providers/More, while the approved user navigation target includes Tasks as a bottom tab.
7. Dashboard summary has competing sources: backend aggregate summary is used in newer screens, while legacy home state still fetches and calculates domain data separately.
8. Provider quote acceptance exists, but follow-up finance actions are not prefilled or linked to the accepted provider/quote.
9. Backend APIs are green in smoke, but many mobile screens are only statically inspected; visual/device coverage is not complete.
10. Existing widget/golden tests are useful, but they do not prove all screens with real backend data on a physical phone.

Verdict: backend foundation is mostly PASS for MVP domains; mobile is PARTIAL with P0 truth blockers. Do not start broad visual polish or next phone QA as "ready" until the P0 list below is fixed.

## 2. Safety Log

Initial required safety gate:

| Check | Result |
| --- | --- |
| `git status --short` | PASS: clean at start |
| `git branch --show-current` | PASS: `phase/mobile-home-dashboard-ux-v2` |
| `git log -1 --oneline` | PASS: `daf41e9 feat: complete aarast mobile product logic foundation` |

Scope discipline:

| Rule | Result |
| --- | --- |
| Source edits | PASS: no source files edited |
| Git state changes | PASS: no branch, stage, commit, push, reset, checkout, or worktree action |
| Docker/deploy/config changes | PASS: none |
| Allowed report file | PASS: this file only |

Documentation and code areas inspected:

- Root docs: `PRODUCT_VISION.md`, `MVP_SCOPE.md`, `PHASES.md`, `DATABASE_PLAN.md`, `API_PLAN.md`, `TESTING_PLAN.md`, `SMOKE_TESTS.md`, `GIT_WORKTREE_GUIDE.md`, `DEPLOYMENT_PLAN.md`, `DECISIONS.md`, `AGENTS.md`.
- Mobile rebuild docs: `docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md`, `CURRENT_STATE_AUDIT.md`, `MOBILE_IMPLEMENTATION_PLAN.md`, `UX_BLUEPRINT.md`, `NAVIGATION_BLUEPRINT.md`, implementation phase docs, QA/design/state docs.
- Mobile code: `mobile/lib/core`, `mobile/lib/features`, route table, screens, widgets, providers, APIs, models, tests.
- Backend code: `backend/prisma/schema.prisma`, `backend/src`, `backend/scripts/smoke`, `backend/test`.

Verification commands run:

| Command | Result |
| --- | --- |
| `flutter analyze` from `mobile` | PASS: no issues found |
| `flutter test` from `mobile` | PASS: 173 tests passed |
| `npx.cmd prisma validate` from `backend` | PASS: schema valid |
| `npm.cmd test` from `backend` | PASS: 23 tests passed |
| `npm.cmd run smoke:all` from `backend` | PASS: all smoke suites completed against `http://127.0.0.1:3115` |

Important runtime limitation: no new manual screenshots or physical-device walkthrough were created during this audit. Visual coverage is therefore limited to existing widget/golden/layout tests plus static inspection.

## 3. Full Screen Inventory Table

| Area | Screen / Surface | File | Route / Entry | Data Source | Backend/API Truth | Runtime Coverage | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Startup | `SplashScreen` | `mobile/lib/features/auth/screens/splash_screen.dart` | `/` | auth storage, guest storage | routes by token/local guest state | widget route tests indirectly | PARTIAL |
| Auth | `OnboardingScreen` legacy | `mobile/lib/features/auth/screens/onboarding_screen.dart` | not active in current router | static copy | none | unknown | P1 legacy/unused |
| Auth | `LoginScreen` | `mobile/lib/features/auth/screens/login_screen.dart` | `/login` | `AuthController` | `/api/v1/auth/login` | auth tests + smoke | PARTIAL |
| Auth | `RegisterScreen` | `mobile/lib/features/auth/screens/register_screen.dart` | `/register` | `AuthController`, city/category lists for provider path | `/api/v1/auth/register`, provider support | tests/smoke | PARTIAL: feminine copy |
| Auth | `OtpScreen` | `mobile/lib/features/auth/screens/otp_screen.dart` | `/otp` | `AuthController` | OTP endpoints | backend smoke | PARTIAL |
| Onboarding | `GuestOnboardingFlowScreen` | `mobile/lib/features/onboarding/screens/guest_onboarding_flow_screen.dart` | `/onboarding`, `/dev/guest-onboarding` | local draft/storage, seed | local-first; not backend complete onboarding by default | widget tests | P0 route truth mismatch |
| Onboarding | `GuestWelcomeScreen` | `mobile/lib/features/onboarding/screens/guest_welcome_screen.dart` | child of guest flow | local draft | none | widget tests via flow | PARTIAL |
| Onboarding | `ChoosePathScreen` | `mobile/lib/features/onboarding/screens/choose_path_screen.dart` | child of guest flow | local draft | none | widget tests via flow | PARTIAL |
| Onboarding | `PersonaScreen` | `mobile/lib/features/onboarding/screens/persona_screen.dart` | child of guest flow | persona draft/copy | maps to persona concept | widget tests via flow | PARTIAL |
| Onboarding | `LocationSetupScreen` | `mobile/lib/features/onboarding/screens/location_setup_screen.dart` | child of guest flow | local location draft | backend has structured plan location | widget tests via flow | PARTIAL |
| Onboarding | `WeddingDateScreen` | `mobile/lib/features/onboarding/screens/wedding_date_screen.dart` | child of guest flow | local date draft | backend supports wedding date | widget tests via flow | PARTIAL |
| Onboarding | `PrioritiesScreen` | `mobile/lib/features/onboarding/screens/priorities_screen.dart` | child of guest flow | local priorities | no direct backend persistence verified | widget tests via flow | PARTIAL |
| Onboarding | `BudgetSetupScreen` | `mobile/lib/features/onboarding/screens/budget_setup_screen.dart` | child of guest flow | local budget draft | backend plan budget exists | widget tests via flow | PARTIAL |
| Onboarding | `SuggestedCategoriesScreen` | `mobile/lib/features/onboarding/screens/suggested_categories_screen.dart` | child of guest flow | local category seed | backend budget categories exist | widget tests via flow | PARTIAL: local-only label |
| Onboarding | `GeneratedDashboardPreviewScreen` | `mobile/lib/features/onboarding/screens/generated_dashboard_preview_screen.dart` | child of guest flow | generated local preview | no server save | widget/golden preview tests | PARTIAL: local temporary label |
| Onboarding | `ProviderPathPendingScreen` | `mobile/lib/features/onboarding/screens/provider_path_pending_screen.dart` | child of guest flow | static | provider apply exists separately | unknown | PARTIAL |
| Onboarding | `ActivePlanOnboardingScreen` | `mobile/lib/features/onboarding/screens/active_plan_onboarding_screen.dart` | unclear/not routed in current router | backend active plan | `/api/v1/onboarding/complete`, active plan | some tests | UNKNOWN active use |
| Home | `DashboardEntryScreen` | `mobile/lib/features/home/screens/dashboard_entry_screen.dart` | `/home` | auth storage, guest storage | chooses `MainShell` or local guest dashboard | widget route tests | PARTIAL |
| Home | `MainShell` | `mobile/lib/features/shell/main_shell.dart` | authenticated `/home` | active plan provider + dashboard source | backend active plan/dashboard summary | widget tests | P1 nav mismatch |
| Home | `HomeScreen` legacy/embedded | `mobile/lib/features/home/screens/home_screen.dart` | embedded in `MainShell` | `HomeDashboardProvider` | fetches active plan, tasks, debts, summary separately | layout tests | P1 duplicate source |
| Home | `LocalGuestDashboardScreen` | `mobile/lib/features/home/screens/local_guest_dashboard_screen.dart` | returning local guest `/home` | local guest storage/generated summary | no backend unless sign-up/migrate | widget tests | PARTIAL: local copy visible |
| Home | `WeddingPlanDashboardScreen` | `mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart` | `/wedding-plans/:id/dashboard` | `DashboardSummaryProvider` | backend dashboard summary | widget/layout/golden tests | PARTIAL |
| Home | `RoyalHomeTodayCenter` widget | `mobile/lib/features/wedding_plans/widgets/royal_home_today_center.dart` | dashboard component | `DashboardSummary` | backend summary model | widget tests | PARTIAL: local role/date text |
| Dev shell | `UserRebuildShell` | `mobile/lib/features/shell/rebuild/user_rebuild_shell.dart` | `/dev/user-navigation-shell` | internal readiness adapters | should be flag-gated | widget tests | UNKNOWN/P2: dev-only copy |
| Plans | `MyWeddingPlansScreen` | `mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart` | `/wedding-plans` | `WeddingPlansProvider` | `/api/v1/wedding-plans/my` | unknown visual | PARTIAL |
| Plans | `CreateWeddingPlanScreen` | `mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart` | `/wedding-plans/create` | `WeddingPlansProvider` | create plan endpoint with offline fallback | unknown visual | PARTIAL: feminine copy |
| Plans | `PlanCenterScreen` | `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart` | `/wedding-plans/:id/plan-center` | dashboard summary, marketplace quotes | backend summary + quotes + plan | not visually verified | P0/P1 truth gaps |
| Money | `BudgetExpenseScreen` | `mobile/lib/features/finance/screens/budget_expense_screen.dart` | `/wedding-plans/:id/finance` | `FinanceProvider` | budget/expense/money APIs | tests unknown | PARTIAL |
| Money | `CreateBudgetCategoryScreen` | `mobile/lib/features/finance/screens/create_budget_category_screen.dart` | `/wedding-plans/:id/budget-categories/create` | `FinanceProvider` | budget category API + offline queue | tests unknown | PARTIAL |
| Money | `CreateExpenseScreen` | `mobile/lib/features/finance/screens/create_expense_screen.dart` | create/edit expense routes | `FinanceProvider` | expense API + offline queue | tests unknown | PARTIAL: feminine copy |
| Debts | `DebtInstallmentScreen` | `mobile/lib/features/debts/screens/debt_installment_screen.dart` | `/wedding-plans/:id/debts` | `DebtInstallmentProvider` | debt/installment APIs | backend smoke | PARTIAL |
| Debts | `DebtDetailsScreen` | `mobile/lib/features/debts/screens/debt_details_screen.dart` | `/debts/:debtId` | `DebtInstallmentProvider` | debt details/installments | unknown visual | PARTIAL |
| Debts | `CreateDebtScreen` | `mobile/lib/features/debts/screens/create_debt_screen.dart` | `/wedding-plans/:id/debts/create` | `DebtInstallmentProvider` | create debt + offline queue | unknown visual | PARTIAL: feminine copy |
| Debts | `CreateInstallmentScreen` | `mobile/lib/features/debts/screens/create_installment_screen.dart` | `/debts/:debtId/installments/create` | `DebtInstallmentProvider` | create installment + offline queue | unknown visual | PARTIAL |
| Tasks | `TaskTimelineScreen` | `mobile/lib/features/tasks/screens/task_timeline_screen.dart` | `/wedding-plans/:id/tasks`, `/timeline` | `TaskTimelineProvider` | tasks/timeline APIs | some widget tests | PARTIAL: no bottom tab |
| Tasks | `CreateTaskScreen` | `mobile/lib/features/tasks/screens/create_task_screen.dart` | create/edit task routes | `TaskTimelineProvider` | create/update task + offline queue | unknown visual | PARTIAL: feminine copy |
| Guests | `GuestListScreen` | `mobile/lib/features/guests/screens/guest_list_screen.dart` | `/wedding-plans/:id/guests` | `GuestsProvider` | guests APIs | some tests | PARTIAL: feminine copy |
| Sharing | `SharingScreen` | `mobile/lib/features/sharing/screens/sharing_screen.dart` | `/wedding-plans/:id/sharing` | `SharingProvider` | sharing/invite APIs | backend smoke | PARTIAL |
| Sharing | `AddSharedMemberScreen` | `mobile/lib/features/sharing/screens/add_shared_member_screen.dart` | `/wedding-plans/:id/sharing/add` | `SharingProvider` | create shared member/invite | unknown visual | PARTIAL: feminine copy |
| Sharing | `EditSharedMemberScreen` | `mobile/lib/features/sharing/screens/edit_shared_member_screen.dart` | `/shared-members/:id/edit` | `SharingProvider` | update shared member | unknown visual | PARTIAL |
| Sharing | `SharedWeddingPlansScreen` | `mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart` | `/shared-wedding-plans` | `SharingProvider` | shared plans endpoint | unknown visual | PARTIAL |
| Sharing | `InviteDecisionScreen` | `mobile/lib/features/sharing/screens/invite_decision_screen.dart` | `/invites/:token` | invite token | invite accept/reject | backend smoke | PARTIAL |
| Notifications | `NotificationsScreen` | `mobile/lib/features/notifications/screens/notifications_screen.dart` | `/notifications`, `/wedding-plans/:id/notifications` | `NotificationsProvider` | notifications APIs | smoke only | PARTIAL |
| More | `MoreScreen` | `mobile/lib/features/more/screens/more_screen.dart` | `/more` | static/account nav | mixed destinations | unknown visual | PARTIAL: feminine copy |
| Settings | `SettingsScreen` | `mobile/lib/features/settings/screens/settings_screen.dart` | `/settings` | `SettingsProvider` | profile/settings APIs | unknown visual | PARTIAL |
| Support | `AarastComingSoonScreen` | `mobile/lib/core/widgets/aarast_coming_soon_screen.dart` | `/support` | static | no support backend in MVP | unknown visual | PARTIAL |
| Marketplace | `ProviderMarketplaceScreen` | `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart` | `/providers`, embedded Providers tab | `MarketplaceProvider` | marketplace provider APIs | partial tests | PARTIAL: feminine/technical copy |
| Marketplace | `ProviderDetailsScreen` | `mobile/lib/features/marketplace/screens/provider_details_screen.dart` | `/providers/:id` | `MarketplaceProvider` | provider details/services/reviews | unknown visual | PARTIAL |
| Marketplace | `QuoteRequestScreen` | `mobile/lib/features/marketplace/screens/quote_request_screen.dart` | `/providers/:id/quote` | `MarketplaceProvider`, guest location | create quote request API/local fallback | tests unknown | PARTIAL: feminine copy |
| Provider | `ProviderAuthGate` | `mobile/lib/features/marketplace/widgets/provider_auth_gate.dart` | wrapper for provider routes | auth storage + dev bypass | account gate | widget tests | P0 while dev bypass true |
| Provider | `ProviderApplyScreen` | `mobile/lib/features/marketplace/screens/provider_apply_screen.dart` | `/provider/apply` | `MarketplaceProvider` | provider apply API | unknown visual | PARTIAL: feminine/technical copy |
| Provider | `ProviderApplyStatusScreen` | `mobile/lib/features/marketplace/screens/provider_apply_screen.dart` | `/provider/apply/status` | provider profile | provider dashboard/profile API | unknown visual | PARTIAL |
| Provider | `ProviderDashboardScreen` | `mobile/lib/features/marketplace/screens/provider_dashboard_screen.dart` | `/provider/dashboard` | `ProviderDashboardProvider` | provider dashboard APIs | backend smoke | PARTIAL: provider/user shell separation |
| Provider | `AddProviderServiceScreen` | `mobile/lib/features/marketplace/screens/add_provider_service_screen.dart` | `/provider/services/new` | `ProviderDashboardProvider` | create service API | unknown visual | PARTIAL: feminine copy |
| Provider | `AddProviderPackageScreen` | `mobile/lib/features/marketplace/screens/add_provider_package_screen.dart` | `/provider/packages/new` | `ProviderDashboardProvider` | create package API | unknown visual | PARTIAL |

## 4. Backend-Mobile Truth Matrix

| Domain | Backend Truth | Mobile Truth | Verification | Status |
| --- | --- | --- | --- | --- |
| Auth / OTP / profile | Controllers, DTOs, JWT, safe user, OTP smoke exist | login/register/OTP screens exist | backend tests/smoke PASS, mobile tests PASS | PARTIAL: copy/persona and provider path copy issues |
| Onboarding | `/api/v1/onboarding/complete`, active plan smoke exist | default `/onboarding` is local guest flow | smoke PASS, widget tests PASS | P0: activation/route truth mismatch |
| Wedding plans | schema/model/API/provider/screens exist | list/create/active/plan center/dashboard exist | smoke PASS, mobile tests PASS | PARTIAL: local fallback and Plan Center truth gaps |
| Dashboard summary | backend aggregate endpoint exists | new provider uses aggregate; legacy home also calculates/fetches separately | smoke PASS | P1: single source not fully enforced |
| Money / budget / expenses | modules, DTOs, smoke exist | finance screens/API/provider exist with offline queue | smoke PASS | PARTIAL: visual/device and permission rendering not fully verified |
| Debts / installments | modules, DTOs, smoke exist | debt screens/API/provider exist with offline queue | smoke PASS | PARTIAL: visual/device coverage incomplete |
| Tasks / timeline | modules, DTOs, smoke exist | task timeline/create/edit exist | smoke PASS | PARTIAL: live bottom nav does not expose Tasks tab |
| Guests | modules, DTOs, smoke exist | guest list exists | smoke PASS | PARTIAL: contact picker/device permission unknown |
| Sharing / participants | sharing service/permissions/smoke exist | sharing/add/edit/invite screens exist | smoke PASS | PARTIAL: finance privacy UI needs more device verification |
| Notifications | notifications modules/smoke exist | global and plan notification routes exist | smoke PASS | PARTIAL: push/deep-link runtime unknown |
| Marketplace / providers | provider/category/service/review/quote schema and modules exist | marketplace/details/request/apply/dashboard screens exist | smoke PASS | PARTIAL: provider/user separation and copy gaps |
| Quote requests/offers/links | quote lifecycle backend and smoke exist | request, accept/reject, plan quotes UI exists | smoke/test PASS | PARTIAL: accepted quote does not prefill/link finance follow-up |
| Provider dashboard | backend provider dashboard modules exist | provider dashboard/service/package screens exist | smoke PASS | PARTIAL: gated route depends on dev bypass |
| Location/city/address | backend plan/provider location fields and city data exist | onboarding/quote/Plan Center use location | smoke PASS | P0/P1: missing address displayed as saved `اختياري` |
| Phone/contact/dedupe | auth/profile and guest endpoints exist | phone/contact helpers exist | tests/smoke partial | UNKNOWN: real contact permission/device flow |

## 5. Screen Truth Problems

| Priority | Finding | Evidence | Impact |
| --- | --- | --- | --- |
| P0 | Guest-first onboarding is both default-routed and supposedly disabled by flag | `app_router.dart` routes `/onboarding` to `GuestOnboardingFlowScreen`; `/dev/guest-onboarding` is the only guarded route; `enableGuestFirstOnboarding` default is false | QA cannot know if guest-first is live, experimental, or accidental |
| P0 | Account/provider gates are weakened by default dev bypass | `app_feature_flags.dart` has `devBypassLoginGatesForUxExploration = true` | Protected actions may appear allowed without real account truth |
| P0 | Plan Center shows missing saved address values as `اختياري` | `plan_center_screen.dart` detail rows use `اختياري` fallback | User may believe optional fields are saved data |
| P0 | Local guest plan can look like a real product path | local dashboard and generated preview use saved local plan behavior | Users may confuse local-only data with backend-synced plan |
| P1 | Live shell lacks target Tasks bottom tab | `MainShell` comment and bottom nav show Home/Money/Providers/More; rebuild shell has five tabs behind dev route | Navigation does not match approved user blueprint |
| P1 | Multiple dashboard/home providers calculate/fetch similar truth | `DashboardSummaryProvider` uses aggregate; `HomeDashboardProvider` fetches tasks/debts/summary separately | Count and status drift risk |
| P1 | Accepted quote financial actions are generic | Plan quote card navigates to create expense/debt without carrying quote/provider/amount context | User can create unrelated financial records after accepting offer |
| P1 | Provider mode exists but not a separate production shell | provider dashboard/apply routes are separate, but user/provider mode separation is incomplete | Wrong-role navigation and QA confusion |
| P1 | Some old/rebuild surfaces remain visible through dev routes/tests | `UserRebuildShell` and placeholder tabs include experimental copy | Safe if truly dev-only, risky if accidentally enabled |

## 6. Copy/Text Problems

| Priority | Copy Problem | Evidence | Better Product Direction |
| --- | --- | --- | --- |
| P0 | Technical backend/server copy appears in user flows | `api_client.dart`: "تشغيل الخلفية"; `marketplace_provider.dart`: "الخادم الحالي"; `provider_apply_screen.dart`: "تأكدي من تشغيل الخلفية" | Use friendly connection copy: `تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.` |
| P0 | Local/dev wording appears in product surfaces | `ملخص محلي مؤقت`, `الخطة محفوظة محلياً`, `تجربة محلية`, `صلاحيات محلية`, `تبويب ... التجريبي` | Distinguish guest draft/pending sync without technical labels |
| P1 | Provider path copy implies operational readiness | provider apply/dashboard copy shows provider onboarding, services, packages | Keep provider operations clearly reviewed/pending; do not imply confirmed bookings/payments |
| P1 | Empty states are often useful but not always persona-neutral | finance/debt/task/guest copy uses feminine verbs | Use persona-aware content keys or neutral Arabic |
| P2 | Support route uses coming-soon content | `/support` maps to coming soon | Acceptable for MVP if honest, but needs final support policy before pilot |

## 7. Persona/Gender Problems

Persona model and persona copy exist, but many screens do not consume them. Hardcoded feminine copy appears across user, provider, marketplace, guests, sharing, tasks, and finance screens.

Examples:

| Area | Evidence | Issue |
| --- | --- | --- |
| More | `ابدئي خطة جديدة`, `تواصلي معنا` | wrong for groom/helper |
| Marketplace | `اختاري قاعات`, `ابدئي البحث`, `ابحثي عن مورد` | wrong for groom/helper |
| Quote request | `حددي`, `اكتبي`, `أضيفي`, `ارسلي`, `اختاري التاريخ` | wrong for groom/helper |
| Provider apply/dashboard | `أضيفي نشاطك`, `تستطيعين`, `تواصلي مع الإدارة` | wrong for male provider or neutral business account |
| Register/create plan | `ابدئي`, `اختاري المدينة`, `اختاري التاريخ` | wrong for groom/helper |
| Guests/tasks/finance/debts/sharing | `أضيفي`, `اختاري`, `ابحثي` | copy is not persona-aware |

Required truth: user role and persona are separate. Bride/groom/helper/provider/member copy should not be hardcoded as one feminine voice across the app.

## 8. Date/Locale Problems

No English month/day strings were found in the inspected mobile text. However, several active widgets use numeric date formatting such as `yyyy/mm/dd` or `yyyy-mm-dd`.

| Priority | Finding | Impact |
| --- | --- | --- |
| P1 | `RoyalHomeTodayCenter` formats some dates numerically | dashboard feels less localized and less human |
| P1 | finance/debt/task cards use numeric date formats | deadline/payment interpretation is less clear |
| P2 | Arabic month names exist in some dashboard widgets, but not consistently | inconsistent product tone |

Required direction: use consistent Arabic date rendering such as `الأحد، 28 ديسمبر 2026` for primary dates and compact Arabic numeric dates only where space demands it.

## 9. Fake/Local/Placeholder Exposure

| Priority | Surface | Exposure | Risk |
| --- | --- | --- | --- |
| P0 | Guest onboarding/default `/onboarding` | local draft and generated dashboard are default reachable | local data can be mistaken for backend truth |
| P0 | Dev bypass | protected actions can bypass account check | privacy and auth truth risk |
| P0 | API error copy | "الخادم الحالي" and "تشغيل الخلفية" | user sees internal implementation language |
| P1 | Generated dashboard preview | `ملخص محلي مؤقت` | acceptable if clearly guest draft; risky as default product |
| P1 | Plan Center local fallback | `تجربة محلية`, `صلاحيات محلية` | internal state leaks into product copy |
| P1 | Offline API fallbacks | local IDs such as `local-plan-*`, `local-task-*`, `local-debt-*`, `local-quote-*` are hidden in IDs but drive state | needs consistent pending-sync UX |
| P2 | Rebuild shell placeholders | `تبويب المال التجريبي`, `تبويب المهام التجريبي` | safe only if never production reachable |

## 10. Duplicate Flow Table

| Flow | Current Entry Points | Truth Risk | Recommendation |
| --- | --- | --- | --- |
| Add expense | MainShell quick add, dashboard quick add, Plan Center quick add, finance screen | duplicate but useful; risk is inconsistent source/refresh | keep one canonical create route and one shared action definition |
| Add debt | MainShell quick add, dashboard quick add, Plan Center quick add, debt screen, accepted quote follow-up | accepted quote context is lost | allow optional quote/provider prefill |
| Add task | MainShell quick add, dashboard quick add, Plan Center checklist/quick actions, task screen | duplicate; not in bottom tab | align with Tasks tab strategy |
| Add guest | MainShell quick add, dashboard quick add, guest screen | mostly OK | keep guest screen as canonical |
| Browse/request providers | bottom tab, dashboard card, Plan Center provider card, quote screen | user can enter provider flow from many places | keep marketplace canonical; avoid implying booking/payment |
| Plan location/budget setup | onboarding, create/edit plan, Plan Center setup checklist | completion truth can drift | Plan Center should read real saved fields and mark completed |
| Notifications | global route, plan route, dashboard cards | deep-link behavior not fully proven | verify deep links and plan scoping |
| Provider apply/dashboard | register provider hint, provider apply route, provider dashboard route | provider/user path separation incomplete | separate provider shell or strict role gate |

## 11. Missing Backend vs Missing Mobile

| Domain | Missing/Weak Backend | Missing/Weak Mobile |
| --- | --- | --- |
| Auth/profile | no major smoke blocker found | persona-aware auth/register copy; device auth edge cases |
| Guest onboarding migration | backend onboarding exists, but guest local-to-account migration truth needs explicit contract | default local route activation, sync/migration UX |
| Plan Center | backend supports plan/location/summary | truth display for completed checklist, address fallbacks, quote financial linkage |
| Money | backend exists and smokes pass | visual coverage, shared-member finance permission device QA |
| Debts/installments | backend exists and smokes pass | visual coverage, mark-paid/unmark-paid UX cross-check |
| Tasks | backend exists and smokes pass | bottom nav integration and visual coverage |
| Guests | backend exists and smokes pass | contact permission runtime, duplicate contact UX |
| Sharing | backend permission services exist | full privacy rendering for shared members |
| Notifications | backend exists and smokes pass | push permission, deep-link, offline notification behavior |
| Marketplace | backend exists and smokes pass | non-technical errors, provider/user shell split |
| Quotes | backend lifecycle exists | quote-to-expense/debt prefill/linking |
| Provider dashboard | backend exists and smokes pass | strict account/provider role gate while dev bypass is true |
| Support/disputes | support docs exist; production backend may be deferred | support screen still coming-soon |
| Payments/bookings/deposits | intentionally not in MVP | do not add; copy must not imply confirmed bookings/payments |

## 12. Navigation Logic Findings

1. `/home` is the active entry point and routes through `DashboardEntryScreen`.
2. Authenticated users reach `MainShell`; local guest users can reach `LocalGuestDashboardScreen`.
3. Live `MainShell` uses four bottom-nav concepts: Home, Money, Providers, More.
4. The approved rebuild target includes five user tabs: Home, Money, Tasks, Providers, More.
5. `/dev/user-navigation-shell` contains the five-tab shell, but it is guarded by `enableNewUserBottomNavigation`.
6. `/dev/guest-onboarding` is guarded by `enableGuestFirstOnboarding`, but `/onboarding` directly opens the same guest flow.
7. Marketplace browsing is public, while quote/provider apply/dashboard routes use `ProviderAuthGate`.
8. `ProviderAuthGate` truth is undermined while global dev bypass is true.
9. Plan-specific inner routes are broad and real: finance, debts, tasks, sharing, guests, notifications.
10. Support is honest coming-soon, but should not become a hidden dead end during phone QA.

Navigation verdict: PARTIAL. The route table is coherent enough for development, but not yet truthful enough for broad QA because live/default route behavior disagrees with guarded feature-flag intent.

## 13. Visual/Layout Risk Findings

| Risk | Evidence | Status |
| --- | --- | --- |
| Dashboard layout | existing layout tests cover multiple widths and dashboard widgets | PARTIAL PASS |
| Plan Center | large screen with many sections, bottom nav, quick add, quote cards, edit sheets | UNKNOWN visual runtime |
| Finance | forms/lists/offline states exist | UNKNOWN visual runtime |
| Debts/installments | multiple lists/details/forms | UNKNOWN visual runtime |
| Tasks | timeline, filters, create/edit | PARTIAL/UNKNOWN |
| Guests | list/contact flows | UNKNOWN real device permission |
| Sharing | role/permission UI | UNKNOWN visual runtime |
| Marketplace | lists, filters, provider cards/details/request | UNKNOWN visual runtime |
| Provider dashboard | long dashboard, services, packages, quotes | UNKNOWN visual runtime |
| RTL text fit | many Arabic strings and cards | PARTIAL: analyze/tests pass, but no full screenshot pass |
| Bottom nav/add button overlap | previous shell patterns are sensitive to persistent bottom nav | PARTIAL: dashboard tests help, all screens not covered |

Do not mark any untested screen visually OK until phone screenshots or Playwright/Flutter driver style visual evidence exists.

## 14. Runtime Verification Coverage

Verified by current commands:

- `flutter analyze`: PASS.
- `flutter test`: PASS, 173 tests.
- `npx.cmd prisma validate`: PASS.
- `npm.cmd test`: PASS, 23 tests.
- `npm.cmd run smoke:all`: PASS.

Mobile coverage proven by existing tests includes:

- feature flags and guarded route behavior.
- guest onboarding flow and generated/local dashboard handoff.
- local guest dashboard.
- protected submit/auth guard behavior.
- provider auth gate behavior.
- Royal Home Today Center section contracts and quick actions.
- home dashboard layout at selected widths.
- dashboard preview/golden-style coverage.
- internal rebuild shell/readiness widgets.

Backend smoke coverage proven:

- health, auth, wedding plan, onboarding active plan, dashboard summary.
- money, budget/expense, debts/installments.
- tasks/timeline.
- guests and guests APIs.
- sharing and sharing roles.
- notifications and notifications APIs.
- marketplace, providers/quotes, provider dashboard.
- UX backend support and backend completion smoke suites.

Still UNKNOWN by runtime visual evidence:

- Plan Center full screen and edit/archive sheets.
- My plans and create plan screens.
- full finance forms and edit/delete flows.
- debt details/installment creation visual states.
- task timeline filters and create/edit visual states.
- guest contact picker and device permission UX.
- sharing permission screens on real member roles.
- notification deep links and push permission behavior.
- marketplace filtering, details, quote request, and provider dashboard on device.
- real logged-in phone session against backend after cold start.
- offline/pending-sync visual states across all domains.

## 15. P0 Fix Plan

1. Fix onboarding activation truth.
   - Decide whether guest-first onboarding is live now.
   - If live, update flags/docs/tests so `/onboarding` is intentionally live.
   - If not live, restore `/onboarding` to the approved non-guest path and keep `GuestOnboardingFlowScreen` only behind `/dev/guest-onboarding`.
   - Ensure local guest data is labeled as draft/pending account, not backend-saved truth.

2. Remove unsafe default dev bypass.
   - Make `devBypassLoginGatesForUxExploration` false by default for normal builds.
   - Keep any bypass compile-time/dev-only and visibly named.
   - Update tests so `ProviderAuthGate` and `AuthActionGuard` prove both protected and dev-only behavior.

3. Remove internal/technical copy from user-facing surfaces.
   - Replace "تشغيل الخلفية", "الخادم الحالي", "الخلفية", "تجريبي", "محلي" where shown to normal users.
   - Use friendly connection/pending-sync messages.
   - Keep debug wording only in dev-only screens that cannot be production reached.

4. Fix Plan Center truth.
   - Do not show `اختياري` as a read-only saved address value.
   - Hide missing optional address rows or show clear completion prompts.
   - Mark location/budget checklist rows completed when backend summary/plan fields are present.
   - Verify Plan Center with widget/device screenshot tests.

5. Apply persona-aware or neutral Arabic copy in global user/provider screens.
   - Start with routes likely seen in first phone QA: onboarding, home, marketplace, quote request, create plan, finance, tasks, guests, sharing, more.
   - Use persona/content matrix instead of hardcoded feminine verbs.

## 16. P1 Fix Plan

1. Align live navigation with approved user tabs.
   - Choose whether Tasks becomes a live bottom tab now or remains a pushed route.
   - Do not leave the dev shell as the only five-tab implementation.

2. Enforce a single dashboard summary source.
   - Prefer backend aggregate summary for display metrics.
   - Remove or clearly isolate legacy separate calculations in `HomeDashboardProvider`.

3. Link accepted quotes to finance follow-up.
   - Carry provider, quote, amount/range, and category context into create expense/debt.
   - Do not create financial records automatically.

4. Build visual test coverage for high-risk screens.
   - Plan Center, finance, debts, tasks, guests, sharing, marketplace, provider dashboard.

5. Standardize Arabic date formatting.
   - Use a shared date formatter for primary dates and compact secondary dates.

6. Separate provider mode from user mode.
   - Provider dashboard/apply should not feel like a normal user tab.
   - Gate by account and provider status without dev bypass.

## 17. P2 Polish Plan

1. Retire or quarantine legacy/rebuild placeholder surfaces once replacements are live.
2. Normalize success/offline/pending-sync banners across domains.
3. Tighten empty-state hierarchy and one-primary-action rule per screen.
4. Add screenshots/manual QA notes for small Android widths and common keyboard states.
5. Replace coming-soon support with the approved support/disputes UX when that phase is active.
6. Consolidate repeated quick action definitions into a shared action registry.
7. Clean mojibake/encoding artifacts where search output indicates corrupted strings.

## 18. Codex-Ready Fix Prompts

### Prompt 1 - P0 Onboarding Activation Truth

You are working in `D:\projects\aarast`. Scope: mobile only. Do not modify backend, deploy files, Docker files, or Git state. Read `AGENTS.md`, `PRODUCT_VISION.md`, `MVP_SCOPE.md`, `PHASES.md`, and `docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md` first. Fix the route/flag contradiction where `/onboarding` directly opens `GuestOnboardingFlowScreen` while `enableGuestFirstOnboarding` is false and `/dev/guest-onboarding` is guarded. Decide from docs whether guest-first is live or dev-only; implement the smallest safe change and update only directly relevant tests/docs if needed. Run `flutter analyze` and `flutter test`. Report exact files changed and PASS/FAIL.

Likely files:

- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/core/config/app_feature_flags.dart`
- `mobile/test/**guest_onboarding**`
- possibly one relevant docs file if activation truth changes

### Prompt 2 - P0 Remove Unsafe Dev Auth Bypass

You are working in `D:\projects\aarast`. Scope: mobile auth/gates only. Do not change UX unrelated to auth guards. Inspect `AppFeatureFlags.devBypassLoginGatesForUxExploration`, `ProviderAuthGate`, and `AuthActionGuard`. Make protected provider/account actions require a real account by default, while preserving an explicit dev-only bypass if needed for local exploration. Update tests to cover default protected behavior and dev-only behavior separately. Run `flutter analyze` and `flutter test`.

Likely files:

- `mobile/lib/core/config/app_feature_flags.dart`
- `mobile/lib/features/marketplace/widgets/provider_auth_gate.dart`
- `mobile/lib/features/auth/utils/auth_action_guard.dart`
- related tests

### Prompt 3 - P0 User-Facing Copy Cleanup

You are working in `D:\projects\aarast`. Scope: mobile copy only. Do not change backend/API behavior. Search for user-visible technical/dev/local copy such as `الخلفية`, `الخادم الحالي`, `تجريبي`, `ملخص محلي`, `تجربة محلية`, `صلاحيات محلية`, and replace production-reachable messages with friendly Arabic product copy. Keep dev-only diagnostic wording only behind dev-only routes. Run `flutter analyze` and `flutter test`.

Likely files:

- `mobile/lib/core/network/api_client.dart`
- `mobile/lib/features/marketplace/providers/marketplace_provider.dart`
- `mobile/lib/features/marketplace/screens/provider_apply_screen.dart`
- `mobile/lib/features/home/screens/local_guest_dashboard_screen.dart`
- `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart`
- `mobile/lib/features/onboarding/screens/generated_dashboard_preview_screen.dart`

### Prompt 4 - P0 Plan Center Saved Truth

You are working in `D:\projects\aarast`. Scope: `PlanCenterScreen` and directly related tests only. Fix missing location/address/budget truth so saved read-only details do not show `اختياري` as if it were data. Completed checklist rows must reflect real saved plan/summary fields. Do not invent data. Add focused widget tests for complete location, partial location, missing optional address, and budget-present/budget-missing states. Run `flutter analyze` and `flutter test`.

Likely files:

- `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart`
- `mobile/test/**plan_center**`

### Prompt 5 - P0 Persona-Aware Arabic Copy Pass

You are working in `D:\projects\aarast`. Scope: copy and content-selection only; do not redesign screens. Read the persona/content docs first. Replace hardcoded feminine user copy in first-phone-QA paths with persona-aware or neutral Arabic copy. Start with marketplace, quote request, create plan, finance create forms, tasks, guests, sharing, More, and provider apply. Add focused tests where copy is selected by persona. Run `flutter analyze` and `flutter test`.

Likely files:

- `mobile/lib/features/onboarding/models/persona_copy.dart`
- `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart`
- `mobile/lib/features/marketplace/screens/quote_request_screen.dart`
- `mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart`
- `mobile/lib/features/finance/screens/create_expense_screen.dart`
- `mobile/lib/features/tasks/screens/create_task_screen.dart`
- `mobile/lib/features/guests/screens/guest_list_screen.dart`
- `mobile/lib/features/sharing/screens/add_shared_member_screen.dart`
- `mobile/lib/features/more/screens/more_screen.dart`

### Prompt 6 - P1 Runtime Visual Coverage

You are working in `D:\projects\aarast`. Scope: tests only unless a test reveals a real bug. Add visual/widget coverage for Plan Center, finance, debts, tasks, guests, sharing, marketplace, provider dashboard, and offline/pending-sync states. Do not change product behavior unless a failing test proves an existing bug. Run `flutter analyze` and `flutter test`; if backend is needed, run the relevant smoke script before claiming integrated readiness.

Likely files:

- `mobile/test/**`
- no production files unless tests reveal a bug
