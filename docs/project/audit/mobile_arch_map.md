# Mobile architecture map (existing app) for the groom-journey redesign

Date: 2026-10-20. Static read of `mobile/` at the current working tree. No code changed.
Paths are relative to `mobile/lib/` unless they start with `mobile/`, `docs/`, `scripts/` or `.github/`.
Prototype = `mobile/test/prototype/v3/*.dart` (ids in `v3_test.dart`, 188 ids); descriptions = `docs/project/audit/screens_inventory.md`.

---

## 1. Rules that constrain mobile code

### 1.1 Binding sources
| Source | What it forces on Mobile |
|---|---|
| `CLAUDE.md` | Read `AGENTS.md` + `ARCHITECTURE_CONSTITUTION.md` first. The phase allowances in `ARCHITECTURE.md` are history only. |
| `AGENTS.md:7-14` | Inspect before editing; tight scope; report every changed file; run the checks for the area and report PASS/FAIL; keep Arabic/RTL copy; **do not blindly overwrite the offline SQLite layer, marketplace/reference flows, provider dashboard, admin approval** (:13). |
| `AGENTS.md:16-28` | Workflow `UNDERSTAND → IDENTIFY OWNER → … → RUN ARCHITECTURE GATES → REVIEW DIFF → COMMIT`; no work on `main` (use a worktree for big work); **no new Mobile boundary-baseline entry, no unresolved local directive, no cross-area `part`** (:27). |
| `AGENTS.md:30-36` | No confirmed bookings with deposits/payment processing, loans/credit/financing (lending), FinTech, AI, or open messaging outside the quote-scoped chat, unless explicitly approved. |
| `AGENTS.md:62-68` | No git state changes unless Git work is requested. |
| `AGENTS.md:70-73` | Money data (expenses, debts, instalments, attachments) is private by default. Members see it only with an explicit permission. |
| `ARCHITECTURE_CONSTITUTION.md` L11 (:143) | Strict Mobile feature boundary: a feature consumes another feature only through the owner's `<feature>_api.dart`. The only core→feature edge allowed is route composition in `core/routing/**`. |
| L13/L14 (:145-146) | No baseline/ignore may hide a violation. Never weaken a gate. |
| L15 (:147) | Never change a behavioural test assertion, fixture or expected value just to get green. An approved behaviour change needs its own decision plus a regression proof. **This applies to the palette and visual-contract tests below.** |
| L17 (:149) | Routes, Arabic copy, permissions and Mobile routes must not change by accident. An intentional change needs scope, approval, tests and docs. |
| Constitution :178-183 | For Mobile, run the strict boundary script and its tests, plus the affected behaviour tests, docs checks and `git diff --check`. |
| `docs/mobile/README.md` | R9 strict boundary. Only `app.dart`, `main.dart` and `core/routing/app_router.dart` are composition roots. An unimported guest plan belongs to the installation: logout keeps it, and a successful `import-local` clears it. |
| `docs/frontend/MOBILE_ARCHITECTURE.md` | Server data is authoritative after login. A local guest plan is a draft, not a fake session. SQLite is cache/sync only. Route guards distinguish no-plan, guest, auth-required, permission-denied, provider-only, feature-disabled and missing-entity states. Chat send and media upload are online-only and never enter the SQLite sync queue. |
| `docs/frontend/DESIGN_SYSTEM.md:380-477` | Golden, test and verification gate for every migrated route: behaviour test, permission test, loading/empty/error/offline/read-only states, 320/420px RTL review, enlarged text, reviewed Golden, analyze plus full tests. |

### 1.2 DECISIONS.md items that constrain the redesign (`docs/project/DECISIONS.md`)
- :129 Flutter SQLite is a cache/sync layer only. PostgreSQL is the source of truth.
- :152 Flutter state is scoped by account and by selected plan. An account change disposes the provider subtree; a plan change replaces plan-scoped providers.
- :153 Offline replay is bound to its originating session (owner, generation, token).
- :222-224 `AuthController` + `SessionTeardownCoordinator` are the single logout/expiry boundary. Context persistence is bound to the user. `AarastSessionTransitionGate` owns auth-driven entry navigation.
- :251 Royal/Premium ornament is retired: no crowns, ornamental gradients, glow, glass or decorative shadows.
- :258-263 Plan Pulse is a deterministic projection, not AI. One Plan Path / Focus Mode grammar. Wedding Day Mode runs from 7 days before to 1 day after the wedding. One wedding-stage engine. The full dashboard summary is cached (schema v8). One temporal grammar `الآن / اليوم / هذا الأسبوع / لاحقًا / مكتمل`. A form ends in a receipt, never a success dialog.
- :264-265 Reference data comes from versioned published catalogs. Yemen geography is typed: governorate → district → locality.
- :271 **The Mobile identity is burgundy, soft-white and champagne, Golden-verified.** The prototype uses teal for the groom and rose for the bride (`mobile/test/prototype/c_journey/kit.dart:24-27`, `home.dart:1184`). Moving to teal needs a **new decision entry** plus deliberate test and Golden replacement (L15).
- :272 Home has an asymmetric hierarchy (one burgundy plan moment, one next decision, three signal cards, a larger Money surface).
- :391-402 (V1 scope): track money but never move it (no in-app payment, wallet or lending). Debts are `FundingSource` of kind `LOAN` with `LoanRepayment`. Funding sources and loans are **owner only**. A cost carries `payer`/`payerName`. Bookings are provider-confirmed without payment; availability checks are pending.

### 1.3 Machine-enforced visual/source gates (they will fail on a naive port of the prototype)
`mobile/test/core/widgets/aarast_visual_contract_test.dart`:
- :88 no raw `Card(` in `lib/features`, `lib/shared`
- :112 **no `Color(0x…)`, no `Colors.red/green/…`, no local `*Colors` classes** in `lib/features`, `lib/shared`, `lib/core/widgets`. New colours go only in `core/experience_v3/aarast_v3_foundations.dart:8` (`AarastV3Color`) and are surfaced through `core/theme/aarast_design_tokens.dart:77` (`AarastSemanticTokens`) / `AppTheme`.
- :143 **no `LinearGradient|RadialGradient|SweepGradient|BoxShadow(` anywhere under `lib/`.** The prototype's sky, lights and fireworks heroes (`lights.dart`, `home.dart:1252`) use gradients.
- :167 no Premium/Royal vocabulary. :197 Lucide icons only. :214/:235/:256 use `AarastDialog` / `AarastToast` / `showAarastBottomSheet`.
- :275 every routed screen file is listed and must use the shared V3 shell wrappers. **New screens must be added to this list.**
- :360 every IconButton has a tooltip. :368 use pressable primitives, not raw gestures. :382 no placeholders.
- :399 domain forms must use `AarastV3FocusPrompt` and `AarastFormDraftBinding`. Auth forms stay ephemeral.
- :467 **every `class *Screen extends` under production must be named in some test file.**
- :492 no raw `CircularProgressIndicator`. :513 use the V3 progress line. :532 no legacy shell primitives.
- `mobile/test/core/theme/aarast_design_tokens_test.dart:17-43` **pins the exact palette** (`brand == 0xFF800020`, etc.). A teal switch means changing these assertions, which L15 allows only with an approved decision.

### 1.4 Check commands (exact)
CI (`.github/workflows/ci.yml:131-152`, job `mobile`, `working-directory: mobile`, Flutter 3.41.7 stable):
```
node --test ../scripts/check-mobile-boundaries.test.mjs
node ../scripts/check-mobile-boundaries.mjs --strict
flutter pub get
flutter analyze
flutter test --exclude-tags golden
```
Docs job (`ci.yml:154-162`, repo root): `node scripts/docs-sync.mjs --check` and `node scripts/docs-verify.mjs`.
Local equivalents (`docs/SCRIPTS.md` / `docs/HANDOFF.md`, repo root):
```
node --test scripts/check-mobile-boundaries.test.mjs
node scripts/check-mobile-boundaries.mjs --check-baseline
node scripts/check-mobile-boundaries.mjs --strict      # today: "strict R9 mobile boundary check passed (legal=179)"
node scripts/docs-sync.mjs           # regenerates docs/frontend/MOBILE_ROUTES.md from core/routing (CI runs --check)
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
cd mobile && flutter analyze --no-pub && flutter test --no-pub
cd mobile && flutter test --tags golden                 # goldens (generated on Windows; Linux font rasterisation differs)
cd mobile && flutter test test/<file>_test.dart --update-goldens
cd mobile && flutter test test/prototype/v3/v3_test.dart --update-goldens   # prototype shots -> test/prototype/v3/out/<id>.png
git diff --check
```
Gate files: `scripts/check-mobile-boundaries.mjs`, `scripts/architecture/mobile-boundaries-baseline.json` (historical R9 lineage, cannot permit violations), `scripts/architecture/r9-mobile-strict-manifest.json`. Lint: `mobile/analysis_options.yaml` = `package:flutter_lints/flutter.yaml` with no custom rules. Test tags: `mobile/dart_test.yaml` (`golden`). `flutter` is **not installed in this container**. Only the node gates were run here.

---

## 2. Structure of `mobile/lib`

Stack: Flutter (Dart `^3.11.5`), **go_router 17** (routing), **provider 6** (`ChangeNotifier` + `ProxyProvider`, not Riverpod), **dio 5** (hand-written API classes, no codegen), **sqflite_sqlcipher** (encrypted offline cache plus sync queue), flutter_secure_storage (tokens, DB key, PII), shared_preferences, socket_io_client (chat realtime), firebase_messaging (push), sentry_flutter, lucide_icons, flutter_animate, google_fonts, flutter_contacts, image_picker, url_launcher (`mobile/pubspec.yaml`). Fonts are bundled: Tajawal (body), IBMPlexSansArabic (display), Amiri (logo only).

### 2.1 Composition roots
- `main.dart` (752 lines). Root `MultiProvider` at :276-315 holds the infra singletons (`ApiClient`, `LocalDatabase`, `OfflineSyncService`, `AuthRepository`, every `*Api`, `ReferenceCatalogProvider`). The session-scoped `MultiProvider` inside `AarastSessionBoundary` (:458-680) is keyed `account:<userId>`. `WeddingPlansProvider`, `AccountContextController` (ProxyProvider) and `SettingsProvider` are account-wide. `AppLockController` sits at :486. Plan-scoped providers are built via `_bindPlanScope`/`_forPlanScope` over `AccountContextController`: `ProviderDashboardProvider`, `ChatProvider`, `DashboardSummaryProvider`, `HomeDashboardProvider`, `FinanceProvider`, `FundingProvider`, `TaskTimelineProvider`, `SharingProvider`, `ContributionHistoryProvider`, `NotificationsProvider`, `GuestsProvider` (:645), …
- `app.dart` uses `MaterialApp.router` with locale fixed to `ar` (:74), `GlobalMaterialLocalizations` (:76), `AppTheme.light()` only (:77, **no dark theme**), and an RTL `Directionality` wrapper (:87).
- `core/routing/app_router.dart` is the single GoRouter (`AppRouter.create` :375). Route-name helpers are at :114-373. Per-area route trees are `part` files: `app_router.entry.dart`, `.marketplace.dart`, `.provider_portal.dart`, `.conversations.dart`, `.account.dart`, `.plan_shell.dart` (a `ShellRoute` wrapping `WeddingPlanShell`), `.wedding_plans.dart`. `weddingPlanRouteAccessForPath` (:402) maps a path segment to the required access (`ownerDashboard / viewPlan / manageTasks / manageGuests / manageProviders / inviteMembers / viewMoney / manageMoney`). Guards: `route_guard_policy.dart`, `route_guard_types.dart`, `app_route_guard_resolver.dart`. Back: `aarast_back_button_dispatcher.dart`, `root_tab_back_scope.dart`. The route list is auto-generated in `docs/frontend/MOBILE_ROUTES.md` (66 routes).

### 2.2 `core/`
| Dir | Contents |
|---|---|
| `config/` | `api_config.dart` (`AARAST_API_BASE_URL` dart-define; product builds fail closed), `app_feature_flags.dart` (**3 flags**: `enableGuestFirstOnboarding`, `enableOfflineSync`, `enablePushNotifications`, plus the dev flag `AARAST_DEV_BYPASS_LOGIN_GATES`), `observability_config.dart` |
| `network/api_client.dart` | dio client. Methods: `getJson` :434, `getJsonList` :443, `postJson` :456, `postJsonWithReceiveTimeout` :463, `postJsonWithBearer` :474, `patchJson` :512, `putJson` :524, `putJsonCancellable` :536, `mutateJson(path,data,{method,clientRequestId})` :557, `deleteJson` :586, `deleteJsonWithData` :595. Header `X-Client-Request-Id` :158. Single-flight token refresh :420. `ApiException` :649 |
| `offline/` | `local_database_mobile.dart` (SQLCipher, `_databaseVersion = 8` :38), `local_database_json.dart` (JSON/in-memory impl used by tests and web), `local_database_contract.dart`, `offline_tables.dart` (21 cache tables plus `sync_queue` and `local_meta`; queue entity types :61), `sync_queue.dart` (`SyncQueueItem{entityType, operation, endpoint, method, payloadJson, status, retryCount, planId, localEntityId}`), `offline_sync_service.dart` (`OfflineSyncService` :17: `syncPendingChanges` :277, `retryBlockedChanges` :479, `loadBlockedIssues` :64, plan quiesce/clear, cache-owner binding), `offline_status_widgets.dart` (`OfflineStatusBanner` :10, `OfflinePendingBadge` :145, `OfflineSyncNowTile` :190, `_SyncIssuesSheet` :251), `pending_plan_cleanup.dart`, `cache_policy.dart`, `offline_database_key_vault.dart` |
| `storage/` | `auth_storage.dart`, `token_vault.dart`, `sensitive_value_vault.dart` |
| `session/` | `safe_user.dart` (canonical user), `session_teardown_coordinator.dart`, `session_boundary.dart`, `session_scoped_change_notifier.dart`, `pending_account_deletion.dart` |
| `security/` | `app_lock_controller.dart` :18, `app_lock_gate.dart` (`AppLockGate` :13, `AppLockScreen` :44, `AppLockCodePad` :160) |
| `push/` | Firebase gateway, `push_notifications_controller.dart`, `push_registration_api.dart` |
| `media/media_upload_api.dart` | presign → PUT → verify |
| `forms/` | `aarast_form_draft_store.dart`, `aarast_form_draft_binding.dart` (secure autosaved drafts), `aarast_form_success.dart` |
| `experience_v3/` | **The design system.** `aarast_v3_foundations.dart` (`AarastV3Color` :8, `AarastV3Space` :48, `AarastV3Radius` :60, `AarastV3Motion` :67, `AarastV3Density` :78, `AarastV3Type` :92 with Tajawal/IBMPlexSansArabic), `aarast_v3_composition.dart` (PageFrame :6, ContextBar :49, NarrativeHeader :96, MetricRail :164, SectionHeader :257, SwipeActions :334, ListRow :446, MetricGrid :672, SignalLine :801, ProgressLine :919, PlanPath :966), `aarast_v3_forms.dart` (FocusPrompt etc.), `aarast_v3_adaptive.dart`, `aarast_v3_temporal.dart`, `aarast_v3_content.dart` (`AarastV3Copy`: shared Arabic state copy) |
| `theme/` | `app_theme.dart` (ThemeData light only), `aarast_design_tokens.dart` (spacing :8-23, radii, icon sizes, `bottomNavHeight 76`, `screenMaxWidth 560`; `AarastSemanticTokens` :77), `aarast_motion.dart` |
| `widgets/` | Shared primitives: `aarast_ui.dart`, `aarast_app_bar`, `aarast_bottom_sheet`, `aarast_button`, `aarast_dialog`, `aarast_toast`, `aarast_error_state`, `aarast_loading_state`, `aarast_skeleton`, `aarast_otp_field`, `aarast_share_sheet`, `aarast_pressable`, `aarast_progress_ring`, `aarast_status_badge`, `aarast_surface`, `brand/aarast_brand_mark.dart` (several are 1-line re-export stubs) |
| `utils/` | Arabic date/number/money formatters, `currency_label`, `plan_status_label`, `whatsapp_share` |
| `contacts/`, `phone/` | Contact picker (single contact), duplicate detection, Yemeni phone normaliser |
| `diagnostics/` | `AppLogger` (categories, memory ring, Sentry sink) |

**Palette today (burgundy):** `AarastV3Color.primary 0xFF800020`, `primaryDark 0xFF5A0015`, `primarySoft 0xFFF8E8EC`, champagne `brandAccent 0xFFD9B15F` / `brandAccentStrong 0xFF8A6A24`, canvas `0xFFFFFEFD`, ink `0xFF2D1A1E`, status colours mint/amber/cobalt/danger (`aarast_v3_foundations.dart:11-45`). **The prototype is teal** (`K.teal 0xFF0B6E69` groom, `0xFFB4536A` bride, plus saffron/lilac/sky/coral/green accents, `test/prototype/c_journey/kit.dart:15-43`) and has a dark mode (`home.dart:1180`).

**i18n:** no ARB/`intl` setup. All Arabic strings are inline in widgets. Shared state copy lives in `core/experience_v3/aarast_v3_content.dart`. Persona copy lives in `features/onboarding/models/persona_copy.dart`. Locale is hard-coded to `ar`.

### 2.3 `features/` (20 owners, each with a public barrel `<f>/<f>_api.dart`)
Layout per feature: `data/` (API class = "repository", one per backend area, often split into `part` files), `models/` (hand-written `fromJson`), `providers/` (`ChangeNotifier`), `screens/`, `widgets/`, `utils/`.
`account_contexts, auth, catalogs, chat, finance, guests, home, marketplace, more, notifications, onboarding, provider_portal, settings, sharing, shell, support, tasks, wedding_day, wedding_plans, welcome_gateway`.
`shared/` holds only `models/contact_phone_draft.dart` and `widgets/contact_phone_field.dart`.

### 2.4 Two shells (both exist; watch which one a change targets)
1. `features/shell/main_shell.dart` `MainShell` :39. It is mounted at `/home` via `DashboardEntryScreen` → `AccountContextEntryGate` (`account_contexts/widgets/account_context_entry_gate.dart:56`).
   - `_OwnerMainShell` :68 is an `IndexedStack` of `WeddingPlanDashboardScreen | MoneyOverviewScreen | TaskTimelineScreen | GuestListScreen | ProviderMarketplaceScreen` inside `PlanShellChrome`. Quick add is at `_showQuickAdd` :107.
   - `_ContributorMainShell` :376 renders `PlanCenterScreen` → `ContributorWorkspaceView`.
2. `features/shell/screens/wedding_plan_shell.dart` `WeddingPlanShell` :35 is the route `ShellRoute` for `/wedding-plans/:id/{dashboard,money…,tasks,guests,providers}` (tabs :59, quick-add routes :70-201, offline banner :286).

Tab bar and quick-add UI: `features/shell/widgets/aarast_plan_chrome.dart` (`AarastQuickActionSheet` :77, `AarastPlanNavigationBar` :170, tab labels :195-199 `الرئيسية/المال/المهام/الضيوف/الموردون`, `AarastPlanContextBar` :245). Quick-add logic: `features/wedding_plans/widgets/quick_add_actions.dart`. The prototype's 5th tab says «المزودين»; the code says «الموردون».

---

## 3–4. Groom (plan-owner) screens per area, with routes, state and endpoints

All endpoint paths are prefixed with `/api/v1`. "Q" means the write goes through the offline sync queue (`FinanceApi._mutation` `finance/data/finance_api.dart:168` → `ApiClient.mutateJson`, or the equivalent local-first path in the tasks, guests, plans and marketplace APIs). Tests fake the API by subclassing `ApiClient` (see §5).

### 3.1 Entry, welcome, onboarding, local plan
| Screen / widget | File | Route |
|---|---|---|
| Splash | `features/auth/screens/splash_screen.dart` | `/` (`app_router.entry.dart:6`) |
| Smart welcome, 3 steps (`_WelcomeStep{pathSelection, roleSelection, quickSetup}` :30). Path cards «إنشاء خطتك / وصلتني دعوة لخطة / أنا مزود خدمة» :353; login prompt :376; whose plan «العريس / العروسة» :391; quick setup «إنشاء خطة زفاف» :427 (date, location, budget). Saves a local draft :138; signed-in users call `completeOnboarding` :182 | `features/welcome_gateway/screens/smart_welcome_screen.dart`, `widgets/aarast_path_card.dart` | `/welcome`; `/onboarding` and `/dev/guest-onboarding` redirect here (`entry.dart:10-23`) |
| Plan creation fields (date, budget, decision field) | `features/wedding_plans/widgets/wedding_plan_creation_form.dart` (`WeddingPlanCreationFields` :31) | embedded |
| Location picker (governorate → district → locality) | `features/onboarding/widgets/location_picker_section.dart`, `data/yemen_administrative_api.dart`, `data/yemen_administrative_fallback.dart`, `providers/yemen_administrative_provider.dart` | embedded |
| Guest-onboarding draft storage | `features/onboarding/data/guest_onboarding_storage.dart`, `models/guest_onboarding_draft.dart`, `providers/guest_onboarding_provider.dart` | – |
| Local guest dashboard (plan on the phone before an account exists) | `features/home/screens/local_guest_dashboard_screen.dart` (rendered by `dashboard_entry_screen.dart:97`) | `/home` |
| Local plan → account migration (upload / keep / discard) | `features/onboarding/screens/local_plan_migration_screen.dart`, `data/local_plan_migration.dart` (`LocalPlanMigrationService` :38) | `/home` (`dashboard_entry_screen.dart:68`) |
| Post-auth entry gate and path chooser «اختر المسار» | `features/home/screens/dashboard_entry_screen.dart`, `features/account_contexts/widgets/account_context_entry_gate.dart`, `screens/account_context_selection_screen.dart`, `providers/account_context_controller.dart` | `/home` |
| Create plan (full form) / my plans | `features/wedding_plans/screens/create_wedding_plan_screen.dart`, `my_wedding_plans_screen.dart` | `/wedding-plans/create`, `/wedding-plans` (`app_router.account.dart:31-36`) |
| Money starter (preset categories) | `features/finance/widgets/money_starter_setup.dart`, `models/money_starter_catalog.dart` | inside Money |
| (dead?) `HomeScreen` | `features/home/screens/home_screen.dart`: no constructor call found in `lib/`, but it is listed in visual-contract :275 | – |

Endpoints (`features/wedding_plans/data/wedding_plans_api.dart`, provider `WeddingPlansProvider`): `POST onboarding/complete` :28, `POST onboarding/import-local` :42, `GET wedding-plans/active` :53, `GET wedding-plans/my` :110, `GET wedding-plans/:id` :129, `POST wedding-plans` :166/:200(Q), `POST wedding-plans/:id/set-active` :212, `PATCH wedding-plans/:id` :226/:256(Q), `PATCH wedding-plans/:id/archive` :268.
Contexts (`features/account_contexts/data/account_contexts_api.dart`, `AccountContextController`): `GET contexts` :21, `POST contexts/validate` :43.
Geography (`onboarding/data/yemen_administrative_api.dart`): `GET governorates` :18, `GET governorates/:id/districts` :39, `GET districts/:id/localities` :65. Catalog: `GET catalogs/bootstrap?version=` (`catalogs/data/reference_catalog_api.dart:26`, `ReferenceCatalogProvider`).

### 3.2 Auth and account security
| Screen / widget | File | Route |
|---|---|---|
| Login (password, plus «الدخول برمز واتساب» :319) | `features/auth/screens/login_screen.dart` | `/login?phone=` (`entry.dart:26`) |
| Register (name, phone, password → OTP). Duplicate-account copy `ACCOUNT_ALREADY_EXISTS` in `providers/auth_controller.sign_in.dart:313` | `features/auth/screens/register_screen.dart` | `/register` |
| OTP (WhatsApp delivery notice `_OtpNotice` :449) | `features/auth/screens/otp_screen.dart` (`OtpScreenArgs` :19) | `/otp` (extra args) |
| Reset password (phone → OTP → new password) | `features/auth/screens/reset_password_screen.dart` | `/reset-password` |
| Change phone (sheet) | `features/settings/widgets/change_phone_sheet.dart` (`ChangePhoneButton` :14, used by `settings_screen.dart:81`) | inside `/settings` |
| Delete account (confirm flow) | `features/auth/widgets/account_deletion_flow.dart` `confirmAccountDeletion` :8. Callers: `more/screens/more_screen.dart:254`, `wedding_plans/screens/plan_management_screen.contributor_account.dart:168`. Pending state: `core/session/pending_account_deletion.dart` | – |
| Logout / delete sheet «إدارة الحساب» | `features/more/widgets/more_screen_components.dart:334-380` | inside `/more` |
| App lock (choose code / PIN gate) | `features/settings/widgets/app_lock_settings.dart` (`AppLockSettingsSection` :15, `settings_screen.dart:127`); `core/security/app_lock_gate.dart` | overlay |
| State | `features/auth/providers/auth_controller.dart` plus parts `.session.dart`, `.sign_in.dart`; `utils/auth_action_guard.dart` (protected-action gate); `widgets/auth_wedding_widgets.dart` | – |

Endpoints (`features/auth/data/auth_repository.dart`): `POST auth/login` :39, `POST auth/register` :63, `POST auth/register/complete` :80, `GET auth/me` :102, `POST auth/otp/request` :113, `POST auth/otp/verify` :168, `POST auth/phone-change/request` :123, `POST auth/phone-change/confirm` :133, `POST auth/password-reset/request` :256, `POST auth/password-reset/confirm` :272, `POST auth/refresh` :293, `POST auth/logout` :471, `PATCH users/me` :372 (avatar after `POST media/uploads/presign` :351 and `/verify` :363), `DELETE users/me` :396, `POST account-deletions/status` :412, `POST invites/:token/request-otp` :144, `POST invites/:token/verify-otp` :221. Push: `PUT|DELETE push/installations/current` (`core/push/push_registration_api.dart:24-40`). **No sessions/devices list endpoint is called.**

### 3.3 Shell and Home / plan pulse
| Screen / widget | File | Route |
|---|---|---|
| Owner dashboard | `features/wedding_plans/screens/wedding_plan_dashboard_screen.dart` (`AarastDashboardView` call :251) | `/wedding-plans/:id/dashboard` (`app_router.plan_shell.dart:16`) or tab 0 of `MainShell` |
| Dashboard view (library plus parts): view, focus («next decision», plan pulse), money card, mosaic, sections, states (`AarastDashboardSkeleton`, `AarastDashboardState`), support | `features/wedding_plans/widgets/dashboard/aarast_dashboard_*.dart` | – |
| Stage engine (`foundation, planning, finalMonth, finalWeek, weddingDay, wrapUp`) | `features/wedding_plans/models/wedding_plan_stage.dart:1`, `wedding_stage_domain_guidance.dart`, `widgets/wedding_stage_context_line.dart` | – |
| Plan pulse publish | `features/wedding_plans/utils/plan_pulse_sync.dart` | – |
| Wedding Day Mode | `features/wedding_day/screens/wedding_day_mode_screen.dart`, `widgets/wedding_day_mode_view.dart`, `models/wedding_day_mode.dart` | `/wedding-plans/:id/wedding-day` (`app_router.wedding_plans.dart:45`) |
| Plan assistant (server-side Q&A) | `features/wedding_plans/screens/plan_assistant_screen.dart`, `widgets/plan_assistant_entry.dart` | `/wedding-plans/:id/assistant` (`wedding_plans.dart:34`) |
| Plan center (owner: plan identity, edit sheet, archive; contributor: workspace) | `features/wedding_plans/screens/plan_management_screen.dart` (`PlanCenterScreen` :41) plus parts `.plan_edit.dart` (`_PlanEditSheet` :251, `_confirmArchive` :160, date shift → `shiftOpenDueDates` :125), `.contributor_account.dart`; `widgets/plan_management_view.dart` (`_DangerSection` :407) | `/wedding-plans/:id/plan-center` (`wedding_plans.dart:6`) |
| Home providers | `features/home/providers/home_dashboard_provider.dart`, `features/home/data/dashboard_summary_sources.dart`, `features/wedding_plans/providers/dashboard_summary_provider.dart`, `home/widgets/home_widgets.dart` | – |

Endpoints: `GET wedding-plans/:id/dashboard-summary` (`wedding_plans_api.dart:88`, `DashboardSummaryProvider`; cached in `cached_dashboard_summaries`), `GET wedding-plans/:id/assistant` and `POST …/assistant/questions` (`wedding_plans/data/plan_assistant_api.dart:15,27`), `GET me/wedding-plans/:id/bookings` (`wedding_plans/data/plan_bookings_lookup.dart:40`).

### 3.4 Money (`features/finance/`, providers `FinanceProvider` and `FundingProvider`)
| Screen / widget | File | Route (`app_router.plan_shell.dart`) |
|---|---|---|
| Money overview (summary, next payment, costs, recent payments; WhatsApp share :143 via `models/money_share_text.dart`) | `screens/money_overview_screen.dart` | `/wedding-plans/:id/money` :30 |
| Budget (total plus allocation per category) | `screens/money_budget_screen.dart` | `…/money/budget` :50 |
| Budget category create/edit/details | `screens/budget_category_form_screen.dart`, `budget_category_details_screen.dart` | `…/money/categories/create` :57, `…/:categoryId` :67, `…/:categoryId/edit` :78 |
| Costs list / form / details (cancel :379, receipts) | `screens/costs_screen.dart`, `cost_form_screen.dart`, `cost_details_screen.dart`, `widgets/cost_receipts_section.dart` | `…/money/costs` :98, `/create` :108, `/:costId/edit` :121, `/:costId` :212 |
| Record payment / payment details (reverse :456) | `screens/cost_payment_screens.dart` (`RecordCostPaymentScreen` :25, `CostPaymentDetailsScreen` :308) | `…/costs/:costId/payments/create` :135, `…/money/payments/:paymentId` :144 |
| Payment schedules (list / form / details / pay) | `screens/payment_schedule_screens.dart` (:23, :498, :223, :829) | `…/money/schedules` :154, `…/costs/:costId/schedules/create` :171, `/:scheduleId/edit` :180, `/:scheduleId/pay` :191, `/:scheduleId` :202 |
| Funding sources and loans (owner only) | `screens/funding_sources_screen.dart`; `widgets/funding_widgets.dart` (`MoneyFundingCard` :14, `FundingSourceFormSheet` :147, `LoanRepaymentsSheet` :321); kinds `SAVINGS/FAMILY_SUPPORT/GIFT/LOAN/OTHER`, status `PLEDGED/RECEIVED` (`models/funding_source.dart:120-145`) | `…/money/funding` :163 |
| Quick-add cost/payment/schedule picker | `widgets/money_cost_action_picker.dart` | sheet |
| Read-only gate | `widgets/finance_write_access_block.dart` | – |
| Shared widgets | `widgets/money_widgets.dart` (`MoneySubpageScaffold` :17, `CostCard` :569, `PaymentCard` :713, `ScheduleCard` :792, …) | – |

Endpoints:
- `finance/data/finance_api.dart`: `GET wedding-plans/:id/money-summary` :53.
- `.budget.dart`: `GET wedding-plans/:id/budget-categories` :13, `PUT wedding-plans/:id/money-budget` :74 (Q), `POST wedding-plans/:id/budget-categories` :123 (Q), `PATCH budget-categories/:id` :167 (Q), `DELETE budget-categories/:id` :216 (Q).
- `.costs.dart`: `GET wedding-plans/:id/costs?…` :16, `GET costs/:id` :95, `POST wedding-plans/:id/costs` :150 (Q), `PATCH costs/:id` :211 (Q), `DELETE costs/:id` :250 (Q), `POST costs/:id/cancel` :288 (Q).
- `.payments.dart`: `GET wedding-plans/:id/cost-payments?…` :12, `GET cost-payments/:id` :71, `GET costs/:id/payments` :100, `POST costs/:id/payments` :143 (Q), `POST cost-payments/:id/reverse` :189 (Q).
- `.schedules.dart`: `GET wedding-plans/:id/payment-schedules/due` :13, `GET costs/:id/payment-schedules` :42, `POST costs/:id/payment-schedules` :70 (Q), `PATCH payment-schedules/:id` :120 (Q), `DELETE payment-schedules/:id` :173 (Q), `POST payment-schedules/:id/cancel` :226 (Q), `POST payment-schedules/:id/pay` :275 (Q).
- `funding_api.dart` (online only): `GET|POST wedding-plans/:id/funding-sources` :22/:57, `PATCH|DELETE funding-sources/:id` :78/:90, `POST funding-sources/:id/repayments` :99, `PATCH|DELETE loan-repayments/:id` :111/:119.
- `cost_receipts_api.dart`: `GET|POST costs/:id/receipts` :13/:26, `DELETE costs/:id/receipts/:rid` :34.
- Local-first plan support: `data/finance_local_data_source.dart`, `finance_local_summary.dart`, `finance_money_rules.dart`.
- Permissions: `FinanceProvider(financeApi, permissionsApi: sharingApi)`.

### 3.5 Tasks (`features/tasks/`, provider `TaskTimelineProvider`)
| Screen / widget | File | Route |
|---|---|---|
| Tasks and timeline (filters `all/overdue/today/upcoming/completed` in `.logic.dart:3`; timeline part; starter part; share button :226) | `screens/task_timeline_screen.dart` plus parts `.logic.dart`, `.timeline.dart`, `.starter.dart` | `/wedding-plans/:id/tasks` (`plan_shell.dart:221`), `/wedding-plans/:id/timeline` (`wedding_plans.dart:92`) |
| Create/edit task (draft, checklist, privacy) | `screens/create_task_screen.dart` plus `_checklist`, `_draft`, `_privacy`; `widgets/create_task_components.dart` | `/wedding-plans/:id/tasks/create` (:62), `/tasks/:taskId/edit` (:73) |
| Rows, checklist, starter sheet, progress | `widgets/task_list_row.dart`, `task_checklist_section.dart`, `task_starter_sheet.dart` (`models/task_starter_catalog.dart`), `tasks_progress_brief.dart`, `task_share_button.dart` | – |

Endpoints (`tasks/data/task_timeline_api.dart`): `GET wedding-plans/:id/tasks` :35, `GET …/timeline` :62, `GET …/tasks/summary` :98, `POST …/tasks/shift-due-dates` :84, `POST wedding-plans/:id/tasks` :164/:205 (Q), `PATCH tasks/:id/assign` :249/:509 (Q), `PATCH tasks/:id` :272/:299 (Q), `DELETE tasks/:id` :328/:346 (Q), `POST tasks/:id/checklist` :689, `PATCH|DELETE tasks/:id/checklist/:itemId` :705/:722.

### 3.6 Guests (`features/guests/`, provider `GuestsProvider`)
| Screen / widget | File | Route |
|---|---|---|
| Guest list (summary, filters, important guests, invitation link :141, groups sheet :170) | `screens/guest_list_screen.dart`, `guest_list_screen_helpers.dart` | `/wedding-plans/:id/guests` (`plan_shell.dart:242`); `/guests/add` (:231) opens the add sheet |
| Add/edit guest sheet (contact picker, duplicate check, party size) | `widgets/guest_form_sheet.dart` | sheet |
| Groups | `widgets/guest_groups_sheet.dart` | sheet |
| Attendance brief, row | `widgets/guest_attendance_brief.dart`, `guest_list_row.dart` | – |
| Guest RSVP page (web, not Flutter) | `deploy/public-site/rsvp.html`, `rsvp.js` | public site |

Endpoints (`guests/data/guests_api.dart`): `GET wedding-plans/:id/guests` :24, `GET …/guests/summary` :57, `GET|POST …/guest-groups` :74/:116, `PATCH|DELETE guest-groups/:id` :124/:133, `POST wedding-plans/:id/guests` :177, `PATCH|DELETE guests/:id` :231/:244, `POST guests/:id/invitation-link` :255. Guests are cached offline (`cached_guests`) and are queue entity type `guest`.

### 3.7 Providers / marketplace (`features/marketplace/`, `features/chat/`)
| Screen / widget | File | Route |
|---|---|---|
| Directory / plan providers tab (budget-matched services `results.dart:3`, offers inbox `_OffersInboxCard` :273, expired offer :485, offer decision :630, accepted/booking area :746, filters `sections.dart:256-300`, search :213) | `marketplace/screens/provider_marketplace_screen.dart` plus parts `.results/.sections/.labels` | `/providers` (`app_router.marketplace.dart:9`), `/wedding-plans/:id/providers?quoteId=` (`plan_shell.dart:249`) |
| Provider details (trust signals, gallery, sections) | `screens/provider_details_screen.dart` (plus `.widgets`), `widgets/provider_details_view.dart`, `provider_details_sections.dart`, `provider_trust_signals.dart`, `provider_photo_gallery.dart` | `/providers/:id?weddingPlanId=` (:19) |
| Quote request | `screens/quote_request_screen.dart` | `/providers/:id/quote` (:40); `/quote-request` redirects (:63) |
| Favorites / compare | `screens/favorite_providers_screen.dart` | `/providers/favorites` (:15) |
| Booking request / cancel / review sheet | `widgets/quote_booking_area.dart` (`requestBooking` :160, `cancelBooking` :199, `_ProviderReviewSheet` :231); `quote_status_chip.dart`; `models/marketplace_booking.dart` | inside the plan providers tab |
| Auth gate | `widgets/provider_auth_gate.dart` | wrapper |
| Conversations list / chat (mute/block/report :277-286) / quote→chat entry | `chat/widgets/conversation_list_view.dart`, `chat/screens/chat_screen.dart`, `chat/screens/quote_conversation_entry_screen.dart`; `chat/providers/chat_provider.dart`; realtime `chat/data/chat_realtime_client.dart` (Socket.IO) | `/conversations`, `/conversations/:id`, `/quotes/:id/conversation` (`app_router.conversations.dart:9-31`) |
| State | `marketplace/providers/marketplace_provider.dart` plus `.directory/.details/.quotes` | – |

Endpoints (`marketplace/data/marketplace_api.dart`, customer part): `GET cities` :19, `GET provider-categories` :37, `GET providers?…` :84, `GET providers/:id` :145, `GET providers/:id/services|packages|reviews` :167/:220/:245, `GET services` :199, `POST providers/:id/views` :286, `POST|DELETE providers/:id/favorite` :291/:315 (also Q :303/:328), `GET me/favorite-providers` :267, `POST wedding-plans/:id/quote-requests` or `POST providers/:id/quote-requests` :384-385, `GET me/quote-requests` :403, `GET wedding-plans/:id/quote-requests` :423, `GET quote-requests/:id` :446, `PATCH quote-requests/:id/cancel` :457, `PATCH quote-offers/:id/accept|reject` :472/:483, `POST me/quote-requests/:id/booking` :497, `PATCH me/bookings/:id/cancel` :520, `POST providers/:id/reviews` :509. Lines :663-989 are the provider-portal side (out of scope).
Chat (`chat/data/chat_api.dart`): `GET conversations` :15, `GET quote-requests/:id/conversation` :20, `GET conversations/:id` :28, `GET …/timeline` :40, `GET …/quote-requests` :48, `POST …/messages` :59, `GET …/attachments/:aid/download` :82, `PATCH …/read|mute|block` :89/:96/:102, `POST …/report` :108.

### 3.8 Collaboration (participants, invites, permissions) (`features/sharing/`, providers `SharingProvider` and `ContributionHistoryProvider`)
| Screen / widget | File | Route |
|---|---|---|
| Participants plus invites list | `screens/sharing_screen.dart`, `widgets/shared_member_card.dart` | `/wedding-plans/:id/sharing` (`wedding_plans.dart:103`) |
| Add participant (lookup by phone, permission editor) | `screens/add_shared_member_screen.dart`, `widgets/permission_editor.dart`, `models/plan_role_permissions.dart` | `…/sharing/add` (:137) |
| Edit participant permissions | `screens/edit_shared_member_screen.dart` | `…/sharing/:memberId/edit` (:148) |
| Invite accept flow (`_InviteAccessStep` phone → otp/accountSetup → invites; notices for expired/revoked/other phone) | `screens/invite_decision_screen.dart` plus parts `.steps`, `.details`, `.notices` | `/invites`, `/invites/:token` (`app_router.account.dart:10-16`); app links `AppRouter.inviteHttpsLink` |
| Plans shared with me | `screens/shared_wedding_plans_screen.dart`, `widgets/shared_plan_card.dart` | `/shared/wedding-plans` (`wedding_plans.dart:160`) |
| Activity history | `screens/contribution_history_screen.dart` | `/wedding-plans/:id/contributions` (:126) |
| Leave plan | `services/plan_leave_coordinator.dart`; UI `wedding_plans/screens/plan_management_screen.contributor_account.dart:308` | – |
| Contributor home and permissions | `wedding_plans/widgets/contributor_workspace_view.dart` plus parts, `contributor_permissions_sheet.dart` | contributor `MainShell` |
| Route permission gate | `account_contexts/widgets/wedding_plan_context_gate.dart` | wrapper |

Endpoints (`sharing/data/sharing_api.dart`): `GET wedding-plans/:id/permissions/me` :23, `GET …/members` :32, `GET users/lookup` :59, `POST …/members` :91, `GET|POST …/invites` :100/:121, `DELETE …/invites/:inviteId` :141, `POST …/invites/:inviteId/reissue` :159, `GET invites/:token` :177, `GET invites/mine` :182, `POST invites/:token/accept|decline` :187/:217, `PATCH|DELETE …/members/:id` :229/:237, `DELETE …/members/me` :254 (leave), `GET …/contributions` :269, `GET shared/wedding-plans` :281.

### 3.9 Notifications, settings, more, support
| Screen | File | Route |
|---|---|---|
| Notifications (account or plan scoped) | `features/notifications/screens/notifications_screen.dart`; `utils/notification_route_policy.dart`, `notification_copy.dart`; provider `NotificationsProvider` | `/notifications` (`account.dart:6`), `/wedding-plans/:id/notifications` (`wedding_plans.dart:115`) |
| Settings (account card, notification prefs `_NotificationSettingsCard` :209, push delivery status `_DeliveryStatusRow` :286, app lock :127, change phone :81) | `features/settings/screens/settings_screen.dart`; `providers/settings_provider.dart` | `/settings` |
| More (plans, tools, sync-now tile :144, account-actions sheet) | `features/more/screens/more_screen.dart`, `widgets/more_screen_components.dart` | `/more` |
| Support | `features/support/screens/support_screen.dart` | `/support` |

Endpoints: `GET notifications` :14, `GET notifications/unread-count` :39, `PATCH notifications/:id/read` :46, `PATCH notifications/read-all` :54, `DELETE notifications/:id` :62, `PATCH notifications/:id/archive` :66 (`notifications/data/notifications_api.dart`); `GET|PATCH users/me/settings` (`settings/data/settings_api.dart:10,15`).

### 3.10 Plan archive
Archive only: `PATCH wedding-plans/:id/archive` via `WeddingPlansProvider.archiveWeddingPlan` (`plan_management_screen.plan_edit.dart:228`). Status label `ARCHIVED → مؤرشفة` is in `core/utils/plan_status_label.dart:9`. **The client has no archived-plan view, no un-archive, no pause, no delete-plan and no "date passed" prompt.**

### 3.11 Offline sync summary
- Queued (Q) entity types (`core/offline/offline_tables.dart:61`): `wedding_plan, plan_member, guest, task, budget_category, money_budget, cost, cost_payment, payment_schedule, booking, quote_request`.
- Online only: funding/loans, receipts, chat, media, notifications, settings, invites.
- Blocked or conflicting items surface only as the `_SyncIssuesSheet` list (`offline_status_widgets.dart:251`). There is no per-field merge UI.

---

## 5. Test infrastructure
- Totals: 265 `*_test.dart` files under `mobile/test/` (`core/` 60, `features/` 162, `offline/` 9, `prototype/` 9, root 24 (mostly golden previews), `shared/` 1), plus `mobile/integration_test/` (3: account-context Android, runtime smoke, provider→groom session flow). The last recorded full run is 1164/1164 (`docs/mobile/README.md`).
- Layout mirrors `lib/`: `test/features/<feature>/…_test.dart`, `test/core/<dir>/…`, `test/offline/…`. Cross-cutting contract tests: `test/features/large_screen_boundaries_test.dart`, `secondary_screens_320_test.dart`, `mobile_truth_cleanup_test.dart`, `test/core/widgets/aarast_visual_contract_test.dart`, `test/core/theme/aarast_design_tokens_test.dart`, `test/core/routing/*` (route guard, app links, router error).
- **API fakes:** there is no mock library (no mockito/mocktail). Tests subclass `ApiClient` with recording fakes, e.g. `_RecordingApiClient extends ApiClient` (`test/features/finance/finance_api_contract_test.dart:170`, `super(tokenProvider: () async => null)`, overriding `mutateJson`/`putJson`/`getJsonList`…). Other tests subclass the feature API (`_FakeFinanceApi` in `test/money_overview_preview_test.dart`). The same pattern appears in about 20 files (auth, marketplace, tasks, finance, chat, notifications, guests, sharing, offline).
- Offline fixtures: the JSON `LocalDatabase` (`lib/core/offline/local_database_json.dart`) backs offline and session tests (`test/offline/*`, `test/features/tasks/super3_tasks_contract_test.dart`). Account-context fixtures: `test/features/account_contexts/account_context_test_data.dart`.
- Helpers: `test/support/preview_fonts.dart` (`loadPreviewAppFonts`), `test/support/library_source.dart` (reads a library plus its parts for source-contract tests), `test/fonts/`.
- **Goldens:** 22 files tagged `@Tags(['golden'])` (root `*_preview_test.dart` plus `features/account_contexts/account_context_entry_gate_error_layout_test.dart`). PNGs live in `test/goldens/` (41 files) plus `test/features/{marketplace,account_contexts}/goldens/`. They are generated on Windows; CI excludes them (`--exclude-tags golden`). Regenerate with `flutter test <file> --update-goldens`.
- Prototypes (`test/prototype/{v3,c_journey,bride_profile,provider,admin}/`) are throwaway golden harnesses. `v3_test.dart` is tagged golden and renders at 390 px width, DPR 2, into `out/<id>.png`. The prototype kit is `test/prototype/c_journey/kit.dart` (`Phone`, `K` palette, `tx`, `btn`, …). None of it is imported by `lib/`.
- CI: a single workflow, `.github/workflows/ci.yml`. The mobile job is at :131-152 (boundary tests, strict boundary, pub get, analyze, `flutter test --exclude-tags golden`). There is no Android/iOS build in CI.

---

## 6. Prototype id → existing real screen
Legend: **✓** a real screen covers the purpose (visual redesign only) · **◐** partial (the screen exists but lacks the main new behaviour, or the purpose is covered by a component/state rather than a screen) · **✗** none.

| id | status | existing file(s) / route | gap note |
|---|---|---|---|
| a01_splash | ✓ | `auth/screens/splash_screen.dart` `/` | new visual |
| a02_who | ✓ | `welcome_gateway/screens/smart_welcome_screen.dart:353` pathSelection, login prompt :376 | |
| a02b_whose | ✓ | smart_welcome roleSelection :391 | |
| a02c_whose_bride | ✓ | smart_welcome roleSelection (bride) | bride theming none |
| a03_name | ◐ | smart_welcome quickSetup :427 + `wedding_plans/widgets/wedding_plan_creation_form.dart` | no groom/bride name step |
| a04_date | ◐ | quickSetup date field | no Hijri, no Ramadan warning; date required |
| a05_city | ✓ | `onboarding/widgets/location_picker_section.dart` | |
| a06_mahr | ✗ | — (mahr exists only as starter category `money_starter_catalog.dart:183` / task) | mahr model none |
| a07_budget | ◐ | quickSetup budget + `finance/widgets/money_starter_setup.dart` | "men's wedding only" split none |
| a08_ready | ◐ | `home/screens/local_guest_dashboard_screen.dart` | no "ready" summary |
| a08b_register | ✓ | `auth/screens/register_screen.dart` `/register` | |
| a09_otp | ✓ | `auth/screens/otp_screen.dart` `/otp` | |
| a10_login | ✓ | `auth/screens/login_screen.dart` `/login` (WhatsApp code :319) | |
| b01_home_fresh | ✓ | `wedding_plans/screens/wedding_plan_dashboard_screen.dart` + `widgets/dashboard/*` | |
| b02_home_active | ◐ | same | no quick-entry, mahr agreement or funding "with you / promised" |
| b03_quick_entry | ✗ | (structured quick add only: `shell/widgets/aarast_plan_chrome.dart:77`) | NL/voice parsing none |
| b04_home_week | ◐ | dashboard with stage `finalWeek` (`wedding_plan_stage.dart`) | events/prayer times none |
| b05_home_day | ◐ | `wedding_day/screens/wedding_day_mode_screen.dart` `/wedding-plans/:id/wedding-day` | rafd button none |
| b06_rafd | ✗ | — | rafd ledger none |
| b07_home_after | ◐ | dashboard stage `wrapUp` | thanks, rating and book none |
| b08_notifications | ✓ | `notifications/screens/notifications_screen.dart` | lock-screen redaction unverified |
| b09_widget | ✗ | — | native home widget none |
| b10_dark | ✗ | — (`app.dart:77` light only) | |
| b11_assistant | ✓ | `wedding_plans/screens/plan_assistant_screen.dart` `/assistant` | |
| b12_events | ✗ | — | no events model |
| b13_event_edit | ✗ | — | |
| b14_loading | ◐ | `core/widgets/aarast_skeleton.dart`, `AarastDashboardSkeleton` | component |
| b15_error | ◐ | `core/widgets/aarast_error_state.dart`, `AarastDashboardState`, `home/widgets/home_widgets.dart:40` | component |
| c01_money_summary | ✓ | `finance/screens/money_overview_screen.dart` `/money` | formula changes (api_map_B §0.1) |
| c02_money_items | ◐ | `costs_screen.dart` + `money_budget_screen.dart` | two-section (agreement/your wedding) split none |
| c03_money_payments | ✓ | `payment_schedule_screens.dart:23` `/money/schedules` | swipe-to-pay new |
| c04_money_offline | ◐ | `core/offline/offline_status_widgets.dart` banner/badge | undo none |
| c05_money_funding | ✓ | `finance/screens/funding_sources_screen.dart` `/money/funding` | |
| c06_pay_sheet | ✓ | `cost_payment_screens.dart:25` RecordCostPaymentScreen; `PayPaymentScheduleScreen` :829 | voice amount, private flag new |
| c07_item_detail | ✓ | `cost_details_screen.dart` + `budget_category_details_screen.dart` + `widgets/cost_receipts_section.dart` | chat link new |
| c08_what_if | ✗ | — | |
| c09_add_item | ✓ | `budget_category_form_screen.dart` `/money/categories/create` | gold-in-grams new |
| c10_add_cost | ✓ | `cost_form_screen.dart` `/money/costs/create` + `PaymentScheduleFormScreen` | |
| c11_payment_detail | ✓ | `cost_payment_screens.dart:308` (reverse :456) | |
| c12_add_source | ✓ | `finance/widgets/funding_widgets.dart:147` FundingSourceFormSheet | |
| c13_loan | ✓ | `funding_widgets.dart:321` LoanRepaymentsSheet | reminders new |
| c14_share | ◐ | `money_overview_screen.dart:143` + `models/money_share_text.dart` | hide-amounts option |
| d01_tasks | ✓ | `tasks/screens/task_timeline_screen.dart` `/tasks` | |
| d02_add_task | ✓ | `tasks/screens/create_task_screen.dart` `/tasks/create` | "after Asr" times new |
| d03_starter | ✓ | `tasks/widgets/task_starter_sheet.dart`, `task_timeline_screen.starter.dart` | |
| d04_task_detail | ◐ | `create_task_screen.dart` edit + `task_checklist_section.dart` | no detail screen, contact link |
| d05_contract_papers | ✗ | — | |
| e01_guests_men | ✓ | `guests/screens/guest_list_screen.dart` `/guests` | hall capacity, remind-all new |
| e03_contacts | ◐ | `core/contacts/contact_picker_service.dart` (single pick) | bulk import none |
| e04_invite | ◐ | `guest_list_screen.dart:141` invitation link | card design none |
| e05_rsvp | ◐ | `deploy/public-site/rsvp.html` (web, not Flutter) | |
| e06_add_guest | ✓ | `guests/widgets/guest_form_sheet.dart` `/guests/add` | |
| e07_guest_detail | ◐ | guest_form_sheet (edit), `guest_list_row.dart` | rafd/invite trail none |
| e08_reminder | ✗ | — | |
| e09_rafd_book | ✗ | — | |
| e10_thanks | ✗ | — | |
| f01_prov_requests | ◐ | `marketplace/screens/provider_marketplace_screen.dart` plan mode `/wedding-plans/:id/providers` (`_OffersInboxCard` `.results.dart:273`) | per-service pipeline view |
| f02_prov_explore | ✓ | provider_marketplace_screen `/providers` (`.results.dart:3`) | availability on your day pending |
| f03_prov_page | ✓ | `marketplace/screens/provider_details_screen.dart` `/providers/:id` | |
| f04_compare | ◐ | `marketplace/screens/favorite_providers_screen.dart` | offer-vs-offer compare |
| f05_book_sheet | ◐ | `marketplace/widgets/quote_booking_area.dart:160` | |
| f06_chat | ✓ | `chat/screens/chat_screen.dart` `/conversations/:id` | offer card in chat partial |
| f07_quote | ✓ | `marketplace/screens/quote_request_screen.dart` `/providers/:id/quote` | |
| f08_chats | ✓ | `chat/widgets/conversation_list_view.dart` `/conversations` | |
| f09_favorites | ✓ | `favorite_providers_screen.dart` `/providers/favorites` | |
| f10_pick_unit | ✗ | — | |
| f11_deposits | ✗ | — | |
| f12_held | ✗ | — | |
| f13_team_arrived | ✗ | — | |
| f14_delivery | ✗ | — | |
| g01_family | ✓ | `sharing/screens/sharing_screen.dart` `/sharing` | |
| g02_account | ◐ | `more/screens/more_screen.dart` `/more` + `settings/screens/settings_screen.dart` `/settings` | Hijri, large text, dark, data saver none |
| g03_postpone | ◐ | `plan_management_screen.plan_edit.dart:125` (date edit + shift tasks) | booking/payment impact none |
| g04_rate | ✓ | `quote_booking_area.dart:231` `_ProviderReviewSheet` | |
| g05_book | ✗ | — | |
| g06_add_participant | ✓ | `sharing/screens/add_shared_member_screen.dart` `/sharing/add` + `widgets/permission_editor.dart` | |
| g07_notif | ◐ | `settings_screen.dart:209` | quiet hours none |
| g08_lock | ✓ | `settings/widgets/app_lock_settings.dart` | biometrics? |
| g09_change_phone | ✓ | `settings/widgets/change_phone_sheet.dart` | |
| g10_support | ✓ | `support/screens/support_screen.dart` `/support` | |
| g11_logout | ✓ | `more/widgets/more_screen_components.dart:334` + `auth/widgets/account_deletion_flow.dart` | |
| q01_invite_phone | ✓ | `sharing/screens/invite_decision_screen.dart` (phone step) `/invites/:token` | |
| q02_invite_account | ✓ | invite_decision `.steps.dart` (accountSetup/otp) | |
| q03_invite_decision | ✓ | invite_decision `.details.dart` | |
| q04_choose_path | ✓ | `account_contexts/screens/account_context_selection_screen.dart` | |
| q05_tasks_mine | ◐ | task_timeline_screen (permission-scoped) | "mine" filter |
| q06_money_view | ◐ | money_overview + `finance/widgets/finance_write_access_block.dart` | |
| q07_money_locked | ◐ | `account_contexts/widgets/wedding_plan_context_gate.dart` (denied state) | "ask owner" none |
| q08_providers_locked | ◐ | wedding_plan_context_gate | |
| q09_bride_view | ✗ | — | |
| q10_account_plans | ◐ | `sharing/screens/shared_wedding_plans_screen.dart` + `plan_management_screen.contributor_account.dart` | |
| q11_leave | ✓ | `plan_management_screen.contributor_account.dart:308` + `sharing/services/plan_leave_coordinator.dart` | |
| q12_changed | ✗ | — | |
| q13_permission_request | ✗ | — | |
| q14_request_sent | ✗ | — | |
| q15_rafd_writer | ✗ | — | |
| q16_providers_view | ✗ | — | |
| q17_bride_helper | ✗ | — | |
| q18_wedding_day | ◐ | wedding_day_mode_screen (viewPlan access) | |
| q19_plan_states | ◐ | wedding_plan_context_gate states | paused/postponed none |
| q20_removed | ◐ | wedding_plan_context_gate (revoked) | |
| q21_notifications | ✓ | notifications_screen | |
| x01_home_no_date | ✗ | — (date required in quickSetup) | |
| x02_date_approx | ✗ | — | |
| x03_money_no_budget | ◐ | money_overview + `shouldShowMoneyStarter` | "help me estimate" none |
| x04_from_family | ◐ | smart_welcome «وصلتني دعوة» → `/invites` | |
| x05_invite_landing | ✓ | invite_decision_screen details | |
| x06_helper_home | ◐ | `wedding_plans/widgets/contributor_workspace_view.dart` (contributor `main_shell.dart:376`) | |
| x07_participant_states | ◐ | sharing_screen (reissue/cancel invites) | delivery states |
| x08_pledge_check | ◐ | funding sources (PLEDGED→RECEIVED) | partial receipt |
| x09_prov_hard | ◐ | `.results.dart:485` expired, `quote_status_chip.dart` | alternatives none |
| x10_reject_offer | ◐ | `.results.dart:630` `_OfferDecisionArea` (reject) | reason/message |
| x11_cancel_booking | ◐ | `quote_booking_area.dart:199` | deposit refund none |
| x12_rate_sent | ✗ | — (toast only) | |
| x13_rafd_later | ✗ | — | |
| x14_payment_reversed | ✓ | CostPaymentDetailsScreen (reversed state) | |
| x15_cancel_item | ◐ | `cost_details_screen.dart:379` cancel; category delete | impact preview |
| x16_task_menu | ◐ | `tasks/widgets/task_list_row.dart` | |
| x17_otp_wrong | ◐ | otp_screen error states | attempts left / SMS |
| x18_session_expired | ◐ | `core/session/session_teardown_coordinator.dart` + login | |
| x19_conflict | ◐ | `offline_status_widgets.dart:251` `_SyncIssuesSheet` | field merge none |
| x20_activity | ◐ | `sharing/screens/contribution_history_screen.dart` `/contributions` | filters |
| x21_guests_empty | ◐ | guest_list_screen empty state | |
| x22_providers_empty | ◐ | provider_marketplace empty state | outside booking none |
| x23_pause_plan | ✗ | — | |
| x24_plan_paused | ✗ | — | |
| y01_where_are_you | ✗ | — | |
| y02_expat_home | ✗ | — | |
| y03_remit | ✗ | — | |
| y04_custody | ✗ | — | |
| y05_hand_cash | ✗ | — | |
| y06_moment_week | ✗ | — | |
| y07_moment_day | ✗ | — (Wedding Day Mode is not a moment) | |
| y08_moment_mahr | ✗ | — | |
| y09_moment_booked | ✗ | — | |
| y10_father_home | ✗ | — | |
| y11_search | ✗ | — | |
| y12_lights_home | ✗ | — | gradients banned |
| y13_decor_providers | ✗ | — (catalog category only) | |
| y14_fireworks_task | ✗ | — | |
| z01_impact_chain | ✗ | — | |
| z02_weekly_digest | ✗ | — | |
| z03_cashflow | ✗ | — | |
| z04_receipt_scan | ◐ | `finance/widgets/cost_receipts_section.dart` (upload) | OCR none |
| z05_smart_tasks | ✗ | — | |
| z06_attendance | ◐ | `guests/widgets/guest_attendance_brief.dart` | forecast none |
| z07_agreement | ✗ | — | |
| w01_forgot_password | ✓ | `auth/screens/reset_password_screen.dart` `/reset-password` | |
| w02_register_errors | ✓ | register_screen + `auth_controller.sign_in.dart:313` | |
| w03_whatsapp_missing | ◐ | otp_screen `_OtpNotice` :449 | |
| w04_devices | ✗ | — | |
| w05_delete_account | ◐ | `auth/widgets/account_deletion_flow.dart:8` | export copy, type «حذف» |
| w06_delete_pending | ◐ | `core/session/pending_account_deletion.dart` | 30-day grace UI |
| w07_pin_entry | ✓ | `core/security/app_lock_gate.dart:44` AppLockScreen | |
| w08_pin_wrong | ◐ | `core/security/app_lock_controller.dart` | lockout copy |
| w09_local_draft | ✓ | `onboarding/screens/local_plan_migration_screen.dart` | |
| w10_edit_plan | ✓ | `plan_management_screen.plan_edit.dart:251` `_PlanEditSheet` | approx date |
| w11_plan_switcher | ◐ | `wedding_plans/screens/my_wedding_plans_screen.dart` `/wedding-plans` + shared plans | archived section |
| w12_date_passed | ✗ | — | |
| w13_archive_plan | ◐ | `plan_management_screen.plan_edit.dart:160` `_confirmArchive` | |
| w14_archived_view | ✗ | — | |
| w15_delete_plan | ✗ | — | |
| w16_invite_states | ✓ | invite_decision `.notices.dart` | |
| w18_category_over | ◐ | budget_category_details_screen | resolution options |
| w19_allocate | ✓ | `finance/screens/money_budget_screen.dart` `/money/budget` | |
| w20_payer_filter | ✗ | — (`payer` field exists on `WeddingCost`) | |
| w21_partial_refund | ✗ | — | |
| w22_receipts | ◐ | cost_receipts_section (per cost) | plan-wide list |
| w23_item_locked | ◐ | cost_details_screen (delete vs cancel) | |
| w24_timeline | ✓ | `task_timeline_screen.timeline.dart` `/timeline` | |
| w25_private_task | ✓ | `tasks/screens/create_task_screen_privacy.dart` | |
| w26_overdue | ◐ | `task_timeline_screen.logic.dart:3` overdue filter | one-tap postpone |
| w27_guest_groups | ✓ | `guests/widgets/guest_groups_sheet.dart` | |
| w28_bulk_guests | ✗ | — | |
| w29_guests_offline | ◐ | guest list cached read (offline banner) | |
| w30_directory_filters | ◐ | provider_marketplace `.sections.dart:256-300` | price/availability |
| w31_offer_expired | ✓ | `.results.dart:485` `_ExpiredOfferRow` | |
| w32_chat_menu | ✓ | `chat_screen.dart:277-286` mute/block/report | |
| w33_provider_status | ◐ | `marketplace/widgets/provider_trust_signals.dart` | |
| w34_booking_states | ◐ | quote_booking_area + quote_status_chip | |
| w35_rate_locked | ◐ | quote_booking_area review gating | |
| w36_ai_consent | ✗ | — | |
| w37_ai_limit | ◐ | plan_assistant_screen error/limit states | |
| w38_not_enough_data | ✗ | — | |
| w39_push_off | ◐ | `settings_screen.dart:286` `_DeliveryStatusRow` | |
| w40_privacy | ◐ | support_screen links (privacy/terms) | data export none |
| w41_pending_queue | ◐ | `OfflineSyncNowTile` (`more_screen.dart:144`) + `_SyncIssuesSheet` | |
| w42_section_states | ◐ | `aarast_loading_state` / `aarast_error_state` / `aarast_skeleton` + `AarastV3Copy` | |

**Coverage (188 ids):** ✓ 59 (31%) · ◐ 70 (37%) · ✗ 59 (31%) → **129/188 ≈ 69% have some real counterpart; 31% are a straight re-skin of an existing screen.**
By section, the ✗ ids cluster in: rafd (b06, e09, e10, x13, q15), events/week moments (b12, b13, y06–y09, y12), expat/custody (y01–y05), smart/AI (z01–z03, z05, z07, b03, c08, w36, w38), provider-side extensions (f10–f14), plan lifecycle (x01, x02, x23, x24, w12, w14, w15), participant requests (q12–q14, q16, q17, q09, y10), devices/bulk (w04, w28), payer/refund (w20, w21).

---

## 7. Touch-point checklist for the implementation plan
1. **Palette / identity:** `core/experience_v3/aarast_v3_foundations.dart` → `core/theme/aarast_design_tokens.dart` → `core/theme/app_theme.dart` (add dark theme, `app.dart:77`). Update `test/core/theme/aarast_design_tokens_test.dart`, all goldens under `test/goldens/`, DECISIONS (new entry superseding 2026-08-10) and `docs/frontend/DESIGN_SYSTEM.md`. Native icons follow DECISIONS :156 (`mobile/tool/generate_native_brand_assets.py`).
2. **Heroes with lights and fireworks** need a gradient-free implementation (CustomPainter with solid fills) or an approved narrow exception to `aarast_visual_contract_test.dart:143`.
3. **Tabs:** `features/shell/widgets/aarast_plan_chrome.dart:195-199` (labels) and both shells (`main_shell.dart:68`, `screens/wedding_plan_shell.dart:59`).
4. **New routes:** add them to the right `core/routing/app_router.<area>.dart` part plus a helper in `app_router.dart`, update `weddingPlanRouteAccessForPath` if they sit under `/wedding-plans/:id/…`, then run `node scripts/docs-sync.mjs`.
5. **New screens:** export each from its feature barrel `<f>_api.dart` (the router imports only barrels), add it to the visual-contract screen list (:275), and name it in a widget test (:467). Forms need `AarastV3FocusPrompt` + `AarastFormDraftBinding` (:399).
6. **New server data** (events, mahr, rafd, pause, devices, payer filter…) gets a new `data/*_api.dart` method in the owning feature. Decide queued vs online-only and, if queued, add the entity type in `core/offline/offline_tables.dart:61` plus handling in `offline_sync_service.dart`. A schema change bumps `_databaseVersion` (`local_database_mobile.dart:38`).
7. **Permissions:** keep funding and loans owner-only (`funding_api.dart` and `FundingProvider`); money gating is in `wedding_plan_context_gate.dart` + `finance_write_access_block.dart`.
