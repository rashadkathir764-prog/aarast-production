# Groom Journey Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the groom journey in the real Flutter app (`mobile/lib`) to match the v3 prototype, screen by screen, using only endpoints the backend already serves.

**Architecture:** This is a re-skin plus behaviour change of existing feature owners (`welcome_gateway`, `onboarding`, `auth`, `wedding_plans`, `finance`, `tasks`, `guests`, `marketplace`, `chat`, `sharing`, `settings`, `more`, `shell`). No backend change. The work runs in vertical slices. Slice 0 changes the shared identity once, in `core/experience_v3/`. Every later slice ports its screens onto the existing data layer and providers, removing anything the server cannot back. Each slice gets its own detailed plan file just before it starts (rolling plan), written from the tables in this document.

**Tech Stack:** Flutter 3.41.7 (`/home/user/sdk/flutter/bin/flutter`), go_router 17, provider 6, dio 5, sqflite_sqlcipher, lucide_icons, Tajawal and IBMPlexSansArabic.

**Spec:**
- Screens and copy: `mobile/test/prototype/v3/*.dart`, rendered in `mobile/test/prototype/v3/out/<id>.png`.
- What is buildable and what to drop per screen: `docs/project/audit/groom_build_classification.md`. Section A is the screen list. Section C contains the decisions.
- Where each screen lives today: `docs/project/audit/mobile_arch_map.md`. Section 6 maps prototype ids to files, and §7 is the touch-point checklist.
- Endpoint contracts: `docs/project/audit/api_map_*.md` and `api_inventory.md`.

**Branch:** `groom-journey-build`, made from `ccr-f548c940-73gd06`. Rashad's rule: **no merge** into any other branch. Push only to `groom-journey-build`.

## Global Constraints

- Read `AGENTS.md` and `ARCHITECTURE_CONSTITUTION.md` before any change (`CLAUDE.md`).
- **L11:** a feature uses another feature only through `<feature>/<feature>_api.dart`. The only core→feature edge allowed is `core/routing/**`.
- **L13/L14:** no new boundary-baseline entry, no ignore, and no weakened gate.
- **L15:** never edit a test assertion, fixture or expected value to get green. A behaviour change needs a recorded decision (Part 1 of this plan, then `docs/project/DECISIONS.md`) plus a regression proof.
- **L17:** a route, Arabic copy or permission must not change by accident. Every intended change is listed in the slice plan and in the commit message.
- Colours only come from `AarastV3Color` (`core/experience_v3/aarast_v3_foundations.dart`) and are surfaced through `AarastSemanticTokens`. No `Color(0x…)` and no `Colors.*` in `lib/features`, `lib/shared` or `lib/core/widgets` (visual-contract test :112).
- No `LinearGradient`, `RadialGradient`, `SweepGradient` or `BoxShadow(` anywhere under `lib/` (:143).
- Every new routed screen file:
  - is added to the visual-contract screen list (:275),
  - is named in a widget test (:467),
  - is exported from its feature barrel.
- Domain forms use `AarastV3FocusPrompt` and `AarastFormDraftBinding` (:399). Auth forms stay ephemeral.
- Lucide icons only. Dialogs, toasts and sheets use `AarastDialog`, `AarastToast` and `showAarastBottomSheet`.
- Every IconButton has a tooltip. No placeholders.
- Every write that can be queued carries `X-Client-Request-Id` (`ApiClient.mutateJson`). Chat send and media upload stay online-only.
- Funding sources and loans stay owner-only (`funding_api.dart`, `FundingProvider`).
- A screen must never show a number, state or promise the backend cannot back (classification "How to read this").
- Arabic copy is copied verbatim from the prototype, except where the classification "Drop or defer" column or a section C decision changes it.
- Password minimum is 6 characters everywhere (C7, matches the backend and the existing `register_screen.dart:197`).
- Check commands. Run them in `mobile/` unless marked as repo root:
  - `node --test ../scripts/check-mobile-boundaries.test.mjs`
  - `node ../scripts/check-mobile-boundaries.mjs --strict`
  - `flutter analyze --no-pub`
  - `flutter test --no-pub --exclude-tags golden`
  - repo root: `node scripts/docs-sync.mjs --check`
  - repo root: `node scripts/docs-verify.mjs`
  - repo root: `git diff --check`
- Before every commit, run `git checkout -- mobile/linux mobile/windows` (Flutter regenerates these plugin files).

## Review Focus

1. **Text size 200% and 320 px width.** Every ported screen must stay overflow-free at 320 px RTL and with large text. Each slice task adds one 320 px test per screen. The existing `*_320_test.dart` pattern and `secondary_screens_320_test.dart` are the model.
2. **A member who is not the owner opens an owner screen.** Money, funding and participant management must show the calm lock, never a broken list or a 403 toast. Each slice adds one permission test per gated screen, using `account_context_test_data.dart`.
3. **Offline in the middle of a write.** A write queued offline must appear as «ينتظر الإرسال» and must never be counted twice (C17). Each money and tasks write task adds an offline test on the JSON `LocalDatabase`.
4. **Old local plan, new design.** A user who made a local plan on the old welcome flow and opens the new build must still reach w09 and import it. Slice 1 Task 1.6 pins this with a migration test.
5. **Server numbers vs client numbers.** The gap, shortfall and counts are never recomputed on the client (C2, C6). Each home and money task asserts the screen shows the server field unchanged.

---

## Part 1. Decisions for Rashad before any code

These are the logic errors found in the new design, and the conflicts between the design and the code rules. Each row has my recommendation. Code starts only after Rashad approves or changes each row. The approved answers are then written to `docs/project/DECISIONS.md` in Task 0.1.

### 1.1 Design against code rules (found while planning)

| # | Problem | Recommendation |
|---|---|---|
| D0 | The code pins burgundy `#800020` (DECISIONS :271 and `aarast_design_tokens_test.dart:17-43`). The new design is teal `#0B6E69` for the groom. | New decision: the groom identity is teal. Change the values in **one file** (`aarast_v3_foundations.dart`). Update the palette test under L15 with this decision as the reason. |
| D1 | Four prototype colours fail readability (WCAG AA 4.5) when used as text on white: coral `#D9583B` 3.88, green `#2E8A5E` 4.27, saffron ink `#A9680F` 4.49, and saffron `#F2A93B` on teal 3.05. The existing test requires ≥ 4.5. | Keep the test. Use darker text shades with the same hue: danger `#B8432A` (5.42), success `#25774F` (5.48), accent `#9A5F0E` (5.23). The light shades stay as fills. The accent on teal becomes `#FBDFA6` (4.70). |
| D2 | The bride is rose in the prototype by a build-time switch (`--dart-define=BRIDE`). The real app needs one build for both. Today's colours are `static const`. | The groom ships first in teal. The bride's rose becomes a theme switch by persona, as a separate task after this journey. It goes to the section B discussion (Part 4). |
| D3 | The lights and fireworks heroes (b04, y12, y14 and the wedding-day hero) use gradients. The code bans every gradient (:143). | Keep the ban. Draw the lights with a `CustomPainter` that uses solid colours and opacity. None of these screens is in section A except y14, which is a task screen, and its hero is drawn the same way. |
| D4 | Tab five reads «الموردون» in the code (19 files, 3 tests) and «المزودين» in the design. | Rename to «المزودين» everywhere, as one copy change with its own decision, and update the 3 tests under L15. |
| D5 | a02 in the design has no «أنا مزود خدمة» path. The current code has it, and a test pins it (`smart_welcome_screen_test.dart:73`). | Keep a small line at the bottom of a02: «عندك خدمة للأعراس؟ سجّل كمزود». The test stays the same. |
| D6 | The design has a dark mode (b10), but the app has no dark theme. | Not in this build. b10 is in slice 10 (1.1). |

### 1.2 Design decisions that block section A screens (classification C.1)

| # | Question | Recommendation |
|---|---|---|
| C1 | Is the mahr inside the budget or outside? | Outside. Budget = the wedding only. In the interim, hide `groom-mahr` from the starter categories, so no data needs moving later. |
| C2 | What does «ناقصك» mean? | Show the server's numbers with their real names: «اتفقت على», «معك», «ومع الموعود ناقصك». Never compute the gap on the phone. |
| C3 | Do payments move when the wedding is postponed? | Not today. g03 copy: «المهام تنتقل، والدفعات تبقى على مواعيدها». |
| C4 | Delete account. | Hide «احذف حسابي» from g11 until the 30-day grace exists (w05 is in section B). |
| C5 | «خطة واحدة مفتوحة». | Drop the rule. A plan for a brother is a second plan. |
| C6 | How many starter tasks? | The real catalog count (20 for the groom today), never a fixed number. |
| C7 | Password length. | 6 everywhere. |
| C12 | Debt after the wedding. | Loans outstanding + agreements still unpaid after the date. |
| C15 | Removing an item. | «يرجع 200 ألف للاحتياط» and «ينحذف البند». |
| C24 | When is the venue step done? | A confirmed venue booking, or a recorded venue agreement. |
| C27 | What does «يعدّل» mean for tasks? | Add tasks and finish his own or assigned ones. Others' tasks are read-only. |
| C28 | Assigning tasks to the father (view-only). | In the interim, show only the members whose stored rights allow tasks. |
| C29 | The father as the card host. | His name is card text only. The groom sends from his own phone. |
| C30 | Sending to 124 guests on WhatsApp. | One after another from the groom's phone («التالي 3 من 124»), plus «انسخ الرابط». |
| C31 | Reminder links. | The reminder makes a new link and says «هذا رابطك الجديد، والقديم ما عاد يشتغل». |
| C58 | Unsent changes after signing in again. | They are sent if the same account signs in again. This needs a DECISIONS update (it replaces DECISIONS :153). |
| C63 | Participant roles. | In the interim: مساعد = HELPER, أهل = FAMILY, يشوف بس = VIEWER. The «العروسة» preset is not offered. |

The C.2 wording fixes (C17, C18, C20, C22, C25, C33, C39, C40, C44 to C47, C49 to C52, C59, C60, C62) do not need a decision. They are applied as written in the classification, inside the slice that owns the screen.

---

## Part 2. How each screen is built (definition of done)

Every screen in every slice follows the same checklist. The slice plan lists the screen's files and values, and this checklist is not repeated there.

1. Open the prototype PNG (`mobile/test/prototype/v3/out/<id>.png`) and source, the classification row, and the real file from arch map §6.
2. Write the failing widget test first. It must:
   - render the screen with a fake API (subclass `ApiClient`, as in `test/features/finance/finance_api_contract_test.dart:170`),
   - assert the Arabic copy and the server values shown,
   - assert that every item the classification says to drop is absent (`findsNothing`).
3. Port the layout onto `AarastV3*` primitives. Add a primitive to `core/experience_v3/` only when two or more screens need it.
4. Wire the existing provider. Add an API method only when the endpoint exists and is not yet called.
5. Cover these states: loading, empty, error, offline, read-only (when gated), and 320 px with large text.
6. Run the slice's tests, then the full check list in Global Constraints. Commit one screen, or one tight group of screens, per commit.
7. Render a before/after image for Rashad at the end of each slice.

---

## Part 3. Slices

### Slice 0. Foundation (identity, tab name, decisions)

Detailed now, because every later slice depends on it.

#### Task 0.1: Record the approved decisions

**Files:**
- Modify: `docs/project/DECISIONS.md` (add a dated section «Current Decisions Addendum - 2026-10-20»)
- Modify: `docs/frontend/DESIGN_SYSTEM.md` (palette section)

**Interfaces:**
- Produces: decision rows D0, D1, D3, D4, D5, C58, and the C.1 answers. Later tasks cite them in their commit messages.

- [ ] **Step 1:** Write one row per approved item from Part 1, in the existing table format (`| Decision | Status | Rationale |`). D0 says it supersedes the 2026-08-10 burgundy row (:271). C58 says it supersedes the offline replay row (:153).
- [ ] **Step 2:** Run `node scripts/docs-verify.mjs` from the repo root. Expected: PASS.
- [ ] **Step 3:** Commit `docs(decisions): approve groom journey identity and interim rules`.

#### Task 0.2: Teal identity in the V3 foundations

**Files:**
- Modify: `mobile/lib/core/experience_v3/aarast_v3_foundations.dart:8-45`
- Modify: `mobile/test/core/theme/aarast_design_tokens_test.dart:17-43` (expected values only, citing D0 and D1)
- Modify: `mobile/lib/core/theme/aarast_design_tokens.dart:77` (`AarastSemanticTokens`) only if a new role is added

**Interfaces:**
- Produces: the same names as today (`AarastV3Color.primary` and the others), so no feature file changes. New names: `AarastV3Color.lilac` and `lilacSoft`, plus the semantic tokens `AarastSemanticTokens.highlight` and `highlightMuted`.

Values (from `mobile/test/prototype/c_journey/kit.dart:14-43`, corrected by D1):

| Role | New value | Prototype source |
|---|---|---|
| canvas | `0xFFF2F4F3` | `K.bg` |
| paper | `0xFFFFFFFF` | `K.surface` |
| paperQuiet | `0xFFF7F8F8` | between bg and white |
| ink | `0xFF13211F` | `K.ink` |
| inkSoft | `0xFF23332F` | darker step of ink |
| text | `0xFF13211F` | `K.ink` |
| textMuted | `0xFF55625E` | `K.muted` |
| textFaint | `0xFF8A9592` | `K.faint` (not used as body text: 3.09) |
| line | `0xFFE2E7E5` | `K.line` |
| lineStrong | `0xFFC9D1CE` | darker step of line |
| primary | `0xFF0B6E69` | `K.teal` |
| primaryDark | `0xFF064B47` | `K.tealDark` |
| primarySoft | `0xFFDCEFEC` | `K.tealSoft` |
| onPrimary | `0xFFFFFFFF` | white |
| onPrimaryMuted | `0xFFDCEFEC` | `K.tealSoft` |
| brandAccent (decorative) | `0xFFFBDFA6` | saffron, lightened for 4.5 on teal (D1) |
| brandAccentStrong | `0xFF9A5F0E` | saffron ink, darkened (D1) |
| brandAccentSoft | `0xFFFCEFD8` | `K.saffronSoft` |
| cobalt / cobaltSoft | `0xFF2F6E9E` / `0xFFE0EEF8` | `K.sky` / `K.skySoft` |
| mint / mintSoft | `0xFF25774F` / `0xFFDDF1E6` | `K.green` darkened (D1) / `K.greenSoft` |
| amber / amberSoft | `0xFF9A5F0E` / `0xFFFCEFD8` | saffron ink / soft |
| danger / dangerSoft | `0xFFB8432A` / `0xFFFBE5DF` | `K.coral` darkened (D1) / `K.coralSoft` |
| rose / roseSoft | `0xFFB4536A` / `0xFFF8E4EA` | the bride's colour, kept for later |
| lilac / lilacSoft (new) | `0xFF6A4FA3` / `0xFFECE6F6` | `K.lilac` (the «مبدئي» status) |

- [ ] **Step 1:** Change the expected values in `aarast_design_tokens_test.dart` 'define the active mobile palette' to the table above. Add `expect(AarastSemanticTokens.highlight, const Color(0xFF6A4FA3));`. Do not touch the contrast test or the other tests.
- [ ] **Step 2:** Run `flutter test --no-pub test/core/theme/aarast_design_tokens_test.dart`. Expected: FAIL on `canvas` (still `0xFFFFFEFD`).
- [ ] **Step 3:** Change the values in `AarastV3Color`, add `lilac` and `lilacSoft`, and add `highlight` and `highlightMuted` to `AarastSemanticTokens`. Update the file's top comment to say the identity is the groom's teal (D0).
- [ ] **Step 4:** Run the same test. Expected: PASS, including 'keeps text-capable roles AA-readable on paper' unchanged.
- [ ] **Step 5:** Run `flutter test --no-pub --exclude-tags golden`. Expected: PASS. Any other failure is a test that pins burgundy. List it, stop, and bring it to Rashad (L15). Do not edit it silently.
- [ ] **Step 6:** Regenerate the goldens with `flutter test --tags golden --update-goldens`. Check them visually, because Linux rasterises fonts differently from Windows. Commit `feat(mobile): groom teal identity (D0, D1)` and include the regenerated goldens.

#### Task 0.3: Rename the providers tab to «المزودين»

**Files:**
- Modify: the 16 `lib/` files that contain «الموردون» (list from `grep -rln "الموردون" lib`). Only the word changes; «مورد» used as a singular becomes «مزود».
- Modify: `test/features/marketplace/super5_providers_contract_test.dart`, `provider_marketplace_shell_navigation_regression_test.dart`, `test/features/wedding_plans/plan_management_view_test.dart` (expected copy only, citing D4)

- [ ] **Step 1:** In the three tests, change the expected «الموردون» to «المزودين». Run them. Expected: FAIL.
- [ ] **Step 2:** Replace the word in `lib/`, and review each hit: `plan_role_permissions.dart` and `permission_editor.dart` are permission labels, so they become «المزودين» too.
- [ ] **Step 3:** Run `grep -rn "الموردون\|المورد" lib`. Expected: no output.
- [ ] **Step 4:** Run the three tests and the full suite. Expected: PASS. Commit `feat(mobile): rename providers tab to المزودين (D4)`.

#### Task 0.4: Shared pieces the prototype repeats

**Files:**
- Create: `mobile/lib/core/experience_v3/aarast_v3_status.dart` (`AarastV3StatusTag`, built on the existing badge)
- Modify: `mobile/lib/core/experience_v3/aarast_v3.dart` (the V3 barrel) to export it
- Test: `mobile/test/core/experience_v3/aarast_v3_status_test.dart`

**Interfaces:**
- Produces: `AarastV3StatusTag({required String label, required AarastV3Tone tone})` with `enum AarastV3Tone { brand, success, warning, danger, info, highlight, neutral }`. It maps each tone to the `AarastSemanticTokens` pair (text colour on soft fill). Slices 2 to 9 use it for every status word («محجوز», «مبدئي», «ينتظر ردك» and the others).

- [ ] **Step 1:** Test `renders each tone with its token pair`. For every tone, assert that the text colour and the background equal the token pair, and that the contrast is ≥ 4.5.
- [ ] **Step 2:** Run it. Expected: FAIL (file missing).
- [ ] **Step 3:** Implement. Use no raw colours.
- [ ] **Step 4:** Run it and the visual-contract test. Expected: PASS. Commit.

Other primitives (the hero card, the big number row, the step list) are added in the slice that first needs them, not here (YAGNI).

#### Task 0.5: Slice 0 check

- [ ] Run every command in Global Constraints. Expected: all PASS.
- [ ] Render the current home, money and tasks screens in teal and send them to Rashad as the "before slices" picture.
- [ ] Push with `git push -u origin groom-journey-build`.

---

### Slice 1. Start, onboarding and sign-in (17 screens)

Detailed now. Order: a01 → a02 → a02b → a03 → a04 → a05 → a07 → a08 → a08b → a09 → a10 → w01 → w02 → w03 → x17 → x18 → w09.

The real flow today is the local plan first, then the account (`smart_welcome_screen.dart`, three steps `_WelcomeStep` :30, saved as a `GuestOnboardingDraft`, uploaded by `LocalPlanMigrationService` through `POST onboarding/import-local`). The new design keeps that order. It splits the one quick-setup step into one question per screen, ends with «خطتك جاهزة», and asks for the account only when the plan is saved. **No new endpoint.**

#### Task 1.1: a01 splash and a02 «أهلًا فيك»

**Files:**
- Modify: `lib/features/auth/screens/splash_screen.dart`
- Modify: `lib/features/welcome_gateway/screens/smart_welcome_screen.dart` (pathSelection step :353 and the login prompt :376)
- Test: `test/features/welcome_gateway/smart_welcome_screen_test.dart` (add cases, keep the existing ones)

**What the screens show:**
- a01: the logo and nothing else. The "deletion pending" route is not drawn (w06 is in section B).
- a02:
  - two choices: «أجهّز لعرسي» and «وصلتني دعوة».
  - the main button: «التالي» (C52).
  - the line «عندي حساب · ادخل».
  - a small line at the bottom: «عندك خدمة للأعراس؟ سجّل كمزود» (D5).

- [ ] **Step 1:** Add the test `a02 shows two wedding paths, التالي, and the provider line`. Also assert `find.text('أنشئ حسابي')` finds nothing.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Port the layout. Keep the existing routes: invite → `/invites`, login → `/login`, provider → provider apply.
- [ ] **Step 4:** Run the whole `smart_welcome_screen_test.dart`. Expected: PASS, including the old 'Provider path opens provider apply route'. Commit.

#### Task 1.2: a02b «خطة مين؟», a03 the name, a04 the date, a05 the city

**Files:**
- Modify: `smart_welcome_screen.dart`. Split `quickSetup` into steps; the enum becomes `{pathSelection, roleSelection, names, date, city, budget, ready}`.
- Modify: `lib/features/onboarding/models/guest_onboarding_draft.dart` (`quickLocalPlanSetup` accepts `weddingDate == null` with `weddingDateUnknown: true`)
- Test: `test/features/onboarding/guest_onboarding_draft_test.dart`, `smart_welcome_screen_test.dart`

**Values:**
- a02b: «العريس» or «العروسة», saved as `GuestPersona.groom` or `bride` and sent as `persona`.
- a03: the groom's name and the bride's name. The plan title is «عرس {groom} و{bride}». Only the title is stored, not the partner name.
- a04: a day picker that also shows the Hijri date and the Ramadan warning (computed on the phone), plus «ما حددنا الموعد بعد». "Month only" is not offered (F10).
- a05: the existing `location_picker_section.dart` on `GET /cities`.

- [ ] **Step 1:** Draft test `quick setup with unknown date stores weddingDate null and weddingDateUnknown true`. Run it. Expected: FAIL (`weddingDate` is required today).
- [ ] **Step 2:** Make `weddingDate` nullable in `quickLocalPlanSetup`. Run it. Expected: PASS.
- [ ] **Step 3:** Widget tests:
  - one per step: the step's copy, and that «التالي» stays disabled until the step is answered;
  - `title is built as عرس محمد وسلمى`;
  - `a04 shows Ramadan warning for a date inside Ramadan 1448`.

  Run them. Expected: FAIL.
- [ ] **Step 4:** Port the four steps. No Hijri converter exists in `lib/` today, so add `core/utils/hijri_date.dart` with its own unit test (Umm al-Qura table, years 1447 to 1450).
- [ ] **Step 5:** Run the existing test 'Organizer path saves complete local plan setup' unchanged, plus the new ones. Expected: PASS. Commit.

#### Task 1.3: a07 the budget and a08 «خطتك جاهزة»

**Files:**
- Modify: `smart_welcome_screen.dart` (budget and ready steps)
- Modify: `lib/features/finance/models/money_starter_catalog.dart`, through the `finance_api.dart` barrel (filter `groom-mahr`, C1)
- Test: `smart_welcome_screen_test.dart`, `test/features/finance/money_starter_catalog_test.dart` (create it if missing)

**Values:**
- a07: a typed number in the plan currency, with «أكمل بدون ميزانية». There are no range buttons and no «ما أدري، ساعدني». The line reads «المهر محسوب لحاله» (C1).
- a08:
  - the item count and the task count from `GET /catalogs/bootstrap` (`money.starter.categories` without `groom-mahr`, and `tasks.starter` for the persona);
  - the copy «{n} مهمة جاهزة» with the real number, 20 for the groom (C6);
  - nothing about events or the mahr.

- [ ] **Step 1:** Write two tests:
  - `starter categories for a groom exclude groom-mahr`;
  - `a08 shows the catalog task count, not 30`. Use a fake catalog with 20 tasks, and assert `find.text('20 مهمة جاهزة')`.

  Run them. Expected: FAIL.
- [ ] **Step 2:** Implement the filter in the catalog model, not in the screen, so Money uses the same list. Then port both steps.
- [ ] **Step 3:** Run them. Expected: PASS. Commit.

#### Task 1.4: a08b «احفظ خطتك», a09 the WhatsApp code, w02, w03, x17

**Files:**
- Modify: `lib/features/auth/screens/register_screen.dart`, `otp_screen.dart`
- Modify: `lib/features/auth/providers/auth_controller.sign_in.dart:313` (where `ACCOUNT_ALREADY_EXISTS` is shown)
- Test: `test/features/auth/register_screen_responsive_test.dart`, `otp_delivery_truth_test.dart`, `auth_error_contract_test.dart` (add cases)

**Values:**
- a08b: phone and password, minimum 6. The name comes from a03, so it is not asked again.
- a09: a 6-digit code sent by WhatsApp, a resend after 60 seconds (the quota is one per minute), and no SMS line.
- w02: «هذا الرقم عليه حساب» appears **after** the code (C49). «ادخل» opens a10 with the phone filled in.
- w03: «الرمز ما وصل» with resend. The lockout line is not shown.
- x17: a plain «الرمز غلط». No attempts counter is shown.
- After the code succeeds: `POST /auth/register/complete`, then the existing `LocalPlanMigrationService` upload (`import-local`).

- [ ] **Step 1:** Write four tests:
  - `register does not ask for name when draft has one`;
  - `ACCOUNT_ALREADY_EXISTS is shown after OTP, never on the form`;
  - `wrong code shows الرمز غلط without a counter`;
  - `resend is disabled for 60 seconds`.

  Run them. Expected: FAIL.
- [ ] **Step 2:** Implement. Keep the auth forms ephemeral (no draft binding).
- [ ] **Step 3:** Run the auth tests folder. Expected: PASS. Commit.

#### Task 1.5: a10 sign in, w01 forgot password, x18 sign in again

**Files:**
- Modify: `login_screen.dart`, `reset_password_screen.dart`
- Modify: `core/session/session_teardown_coordinator.dart` (only the copy shown on expiry)
- Test: `login_screen_responsive_test.dart`, `reset_password_flow_test.dart`

**Values:**
- a10: phone and password, or «ادخل برمز واتساب» (OTP LOGIN).
- w01:
  - Code and new password go in one form, and a wrong code shows after submit.
  - After the confirm call: «غيّرنا كلمة المرور وطلعناك من كل الأجهزة», then the app signs in automatically with the new password.
- x18: «ادخل مرة ثانية». The unsent-changes line follows the C58 answer. If C58 is approved: «تعديلاتك محفوظة وبتنرسل لما تدخل بنفس الحساب». If not: «تعديلاتك محفوظة على الجوال».

- [ ] **Step 1:** Write two tests: `reset confirm signs in again with the new password` (assert `/auth/login` is called after `/auth/password-reset/confirm`) and the x18 copy. Run them. Expected: FAIL.
- [ ] **Step 2:** Implement. If C58 is approved, change the replay binding in `offline_sync_service.dart` to "same userId and plan access still holds", with its own test in `test/offline/`. That test must show that a different account's sign-in still drops the queue.
- [ ] **Step 3:** Run auth, offline and session tests. Expected: PASS. Commit.

#### Task 1.6: w09 «خطة على الجوال وخطة في الحساب»

**Files:**
- Modify: `lib/features/onboarding/screens/local_plan_migration_screen.dart`
- Test: `test/features/onboarding/local_plan_migration_test.dart`

**Values:**
- Two choices: «خلّها خطة ثانية» (import-local, which always makes a new plan) and «تجاهلها» (local only).
- «تجاهلها» asks for confirmation twice (C62).
- «ضمّها لخطتي» is not offered (there is no merge mode).

- [ ] **Step 1:** Write two tests:
  - `discard needs two confirmations`;
  - `a draft saved by the old welcome flow still imports` (Review Focus 4). Use a `GuestOnboardingDraft` JSON in the old shape with a required date, and assert the `import-local` body.

  Run them. Expected: the first FAILS. The second may pass already; keep it as a guard.
- [ ] **Step 2:** Implement. Run the tests. Expected: PASS. Commit.

#### Task 1.7: Slice 1 check

- [ ] Run every command in Global Constraints. Expected: all PASS.
- [ ] Walk the whole flow once on a real device or emulator with the dev backend, if one is reachable. Otherwise run an integration-style widget test from a02 to the home screen with fake APIs.
- [ ] Render a01 to w09 next to the prototype PNGs for Rashad. Push.

---

### Slices 2 to 10 (each gets its own plan file before it starts)

For each screen, the endpoints and the drops are in the classification section A row with the same id. The real file is in arch map §6. Only what the slice plan must decide first is listed here.

| Slice | Screens in build order | Real owners and files | Decide first | Watch out |
|---|---|---|---|---|
| 2. Shell and home (8) | b14, b15, w42, w41, b08, b01, b02, x01 | `shell/main_shell.dart`, `screens/wedding_plan_shell.dart`, `widgets/aarast_plan_chrome.dart`, `wedding_plans/widgets/dashboard/*`, `notifications/screens/notifications_screen.dart`, `core/offline/offline_status_widgets.dart` | C2, C17, C24, C25, C60 | Both shells must change together (arch map §2.4). The home reads `dashboard-summary` and `money-summary` as they are; no client gap. b01 has three steps (no mahr). x01 needs Task 1.2's nullable date. |
| 3. Money read (8) | c01, c02, c03, c05, c07, c11, x03, w22 | `finance/screens/money_overview_screen.dart`, `costs_screen.dart`, `payment_schedule_screens.dart`, `funding_sources_screen.dart`, `cost_details_screen.dart`, `cost_payment_screens.dart`, `widgets/cost_receipts_section.dart` | C1, C2, C20, C22 | Owner view first; non-owners get the lock (Review Focus 2). w22 makes one call per cost; cache it. |
| 4. Money write (12) | c04, c06, c09, c10, c12, c13, x08, x14, x15, w18, w19, w23 | same plus `budget_category_form_screen.dart`, `cost_form_screen.dart`, `money_budget_screen.dart`, `widgets/funding_widgets.dart` | C2, C3, C12, C15, C18 | c10 and c12 are several calls: each one retries with its own `X-Client-Request-Id`, and the screen shows the part that is left. |
| 5. Tasks (10) | d01, d02, d03, d04, d05, x16, w24, w25, w26, y14 | `tasks/screens/task_timeline_screen*.dart`, `create_task_screen*.dart`, `widgets/task_starter_sheet.dart`, `task_checklist_section.dart`, `task_list_row.dart` | C6, C28, C39 | d04 is a new detail screen (today the edit form is used). d05 is a titled checklist only. y14's hero follows D3. |
| 6. Guests (12) | e01, e03, e06, e07, w27, w28, w29, x21, e04, e05, e08, w38 | `guests/screens/guest_list_screen.dart`, `widgets/guest_form_sheet.dart`, `guest_groups_sheet.dart`, `core/contacts/`, `deploy/public-site/rsvp.*` | C29, C30, C31, C33 | e03 needs picking several contacts at once (today `contact_picker_service.dart` picks one). Check `flutter_contacts` multi-select before the slice plan. |
| 7. Providers, customer side (24) | x22, f02, w30, w33, f03, f09, y13, f07, f08, f06, w32, f01, f04, f05, y09, x10, x09, w31, w34, x11, w35, g04, x12, b07 | `marketplace/screens/*`, `widgets/quote_booking_area.dart`, `chat/screens/chat_screen.dart`, `chat/widgets/conversation_list_view.dart` | C25, C40, C44, C45, C46, C47, and the unclaimed-listing question (Part 4) | AGENTS.md :13 says marketplace flows must not be overwritten blindly: port the UI, keep `marketplace_api` calls as they are. Needs slice 4 (accepting an offer creates a cost). |
| 8. Account, settings and plan (15) | g02, g07, g10, g11, w39, w07, w08, g08, w10, g03, w11, g01, g06, x07, x20 | `more/`, `settings/`, `core/security/app_lock_*`, `wedding_plans/screens/plan_management_screen*.dart`, `my_wedding_plans_screen.dart`, `sharing/screens/*` | C3, C4, C5, C27, C31, C50, C51, C59, C63 | g08 becomes the lock settings screen (C50). g11 hides delete (C4). |
| 9. Participant (15) | x04, q01, q02, q03, q04, x06, q17, q05, q18, q07, q08, q10, q12, q19, q21 | `sharing/screens/invite_decision_screen*.dart`, `account_contexts/screens/account_context_selection_screen.dart`, `wedding_plans/widgets/contributor_workspace_view.dart`, `account_contexts/widgets/wedding_plan_context_gate.dart` | C7, C27, C63 | q17 shows the bride's plan in rose, which needs D2. Until then q17 uses teal. |
| 10. Version 1.1 extras (7) | b09, b10, b11, w36, w37, c14, g09 | `wedding_plans/screens/plan_assistant_screen.dart`, `settings/widgets/change_phone_sheet.dart` | C22, D6 | Built after V1. b09 needs native widget work (Android and iOS), which is outside Flutter. |

---

## Part 4. Screens with no endpoint (for discussion after the build)

These screens are not built in this plan. Each needs backend work first. They are grouped by the backend work that unblocks them (classification B.3). The "My view" column is my recommendation for the order in which to discuss them.

| Backend work | Screens it unblocks | Size | My view |
|---|---|---|---|
| Events and the wedding-day program (`PlanEvent`, `GET P/home`) | b04, b05, b12, b13, y06, y07, y12, plus the q09 and q18 program | L | **First.** It is the biggest gap and the heart of the Yemeni wedding (المقيل، الزفة، العشاء). It needs C8 decided first (one program). |
| Rafd book | b05, b06, e09, e10, x13, q15 | M | **Second.** Rafd is daily wedding behaviour, and the wedding day screen needs it. |
| Mahr and the money formula (the agreement section, the server gap) | a06, y08, c08, plus the deferred parts of b01, b02, c01 and c02 | M | **Third.** It finishes what slice 3 leaves out. It depends on C1. |
| Plan lifecycle (done, pause, archive, delete) | w12, w13, w14, w15, x23, x24, plus q19's other states | L | After the wedding-day work. It needs C4 and C57. |
| Section-level permissions (لا / يشوف / يعدّل) | q06, q09, q16, y10, plus the full g01, g06 and x07 | L | Together with the bride (q09). |
| Account deletion with 30 days of grace, and the devices list | w04, w05, w06 | L | Required before the store launch (store rules require account deletion). |
| Marketplace v2 on the customer side (units, holds, deposits, team on the way, delivery) | f10, f11, f12, f13, f14 | L | With the provider journey (PROVIDER_JOURNEY.md). It needs the DECISIONS approval in C66. |
| Permission requests and leaving a plan | q11, q13, q14, q20 | M | After section-level permissions. |
| Invite v2 (preview, distinct errors, 7 days) | x05, w16 | S | Small. It can go with any slice after 9. |
| Single items | y01 to y05 (expat and custody), b03 and z04 (AI), z01 to z03, z05 to z07, w20, w21, w40, x02, x19, y11, g05 | S to L | Each one is decided on its own. AI items need the AGENTS.md approval (C66). |
| The bride's rose theme (D2) | the whole bride journey, q17 | M (mobile only) | Right after this groom build: no backend is needed, only a theme switch by persona. |

Other open questions that are not screens:
- The 6 market questions to real vendors (`docs/project/research/`).
- The unclaimed-listing decision: does an unclaimed provider receive requests? PROVIDER_JOURNEY says yes; 4.18 and `409 PROVIDER_NOT_CLAIMED` say no.
- Whether to grow the task catalog from 20 to the designed list (C6).
