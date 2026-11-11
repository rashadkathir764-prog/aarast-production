# Groom Screens In The Home's Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring every couple-side screen of the mobile app to the layout language the owner approved on the plan's home (commit `6f33d33`), one screen at a time, each shown to him before the next.

**Architecture:** No new direction and no new screens. The home's pieces move into the journey kit once (Task 0), then each screen is re-laid with those pieces through one fixed cycle: screen card, picture before, change, checks, picture after, owner's word, commit. Data, routes, copy rules and decisions stay as they are unless a task says otherwise.

**Tech Stack:** Flutter 3.41.7 (CI pin), `mobile/lib/core/experience_v3` (journey kit), `provider`, golden and widget tests under `mobile/test`.

**Spec:** the owner's approved picture is the home as built in `6f33d33` (`mobile/lib/features/wedding_plans/widgets/dashboard/`), with `docs/frontend/DESIGN_SYSTEM.md`, `.claude/skills/aarast-screen/SKILL.md` and the mockup at https://claude.ai/artifact/16ndxb8HpiV3e6XeGuShto (a reference for layout, not a law of pixels). Owner's order of 2026-11-11 opens the frontend freeze (D67) for this work; it is recorded in `DECISIONS.md` in Task 0.

## Global Constraints

- The owner's taste, in his words: «نظيف، منطقي، أنيق، متميز» and neither «مبالغة» nor «رسمي زيادة» nor «حاد». In practice:
  - One thing leads each screen: one figure or one question, then one action.
  - An action is one row: a 48 tile that says when or what, the words, the button at the row's end. The button drops under the words below 300 wide, on enlarged text, or with a label over 12 letters.
  - A card is paper with a hairline (`JourneyBox(borderColor: AarastV3Color.line, borderWidth: AarastV3Space.hair)`), corner `AarastV3Radius.card`. No tinted card, no shadow, no new gradient.
  - A verdict or state is a small chip with its icon. A share is an arch or a thin bar. A list is one card of rows with hairlines between them.
  - An icon alone only for search, back and favourite. Every other control carries its word.
  - Nothing is drawn that the server does not send. No invented state, no extra screen.
- The countdown card on the home stays as it is (owner's order).
- Sizes only from `JourneyType`, `AarastV3Space`, `AarastV3Radius`, `AarastV3Icon` (`test/core/widgets/aarast_design_ratchet_test.dart` fails on a written number).
- Works at 320 and 420 wide and at text scale 1.3; every target is 48.
- Yemeni dialect in the reader's gender (`context.say`), «أقساط» is banned, amounts through `compactMoneyFigure` and `keepCurrencyOnLine`, and they respect «أخفِ المبالغ».
- One colour per plan (`context.accent`); status colours only with a word or an icon.
- Cross-feature imports only through a feature's `*_api.dart`. No file under `widgets/dashboard` over 700 lines.
- Decisions in force are not changed by layout work (for example D59, D79, D102 to D109). A task that needs one changed stops and asks the owner.
- A test is changed only when it pins the old layout, never to hide a broken rule; the commit says which and why.
- Checks before every commit: `flutter analyze` clean, and `flutter test --exclude-tags golden` with no failure that is not in the baseline list (54 on the Linux box on 2026-11-11, saved by Task 0).
- One screen, one commit, with its screen card in the message. Work lands on the session's branch; the owner merges.
- One batch per session, and a session stops after each screen for the owner's word. This keeps the token use small.

## Review Focus

- A long Arabic label or a seven-digit amount at 320 wide and text scale 1.3: the row must wrap or drop its button, never clip. Each screen's task renders this case.
- «أخفِ المبالغ» on: every figure the task moved must still hide. Each money task asserts it.
- A reader who is not the owner (partner, helper, «يشوف بس»): the re-laid screen must not show a control the role cannot use. Each task renders one non-owner role where the screen has one.
- Offline or a stale copy: the «قديمة» mark and the saved-on-phone notice must survive the new layout. Tasks on screens that carry them keep their existing tests green.
- The bride's plan: rose accent and feminine copy on every re-laid screen. Each task renders the bride once.

---

## Inventory (couple side, 2026-11-11)

Done: the plan's home (all states share one view).

| Batch | Section | Screens (file under `mobile/lib/features/`) | Sheets |
|---|---|---|---|
| 1 | Money tab | `finance/screens/money_overview_screen*.dart`: الملخص، البنود، الدفعات، من وين | كيف حسبناها، مشاركة |
| 2 | Money pages | `budget_category_details_screen`, `budget_category_form_screen`, `cost_form_screen`, `cost_details_screen`, `cost_payment_screens` (سجّل دفعة، دفع موعد، صفحة دفعة), `money_budget_screen`, `funding_sources_screen`, `wedding_plans/screens/mahr_screen`, `payer_payments_screen`, `money_receipts_screen` | 20 (`due_date_sheets`, `funding_sheets`, `payment_schedule_sheet`, others inline) |
| 3 | Tasks | `tasks/screens/task_timeline_screen*` (القائمة، الوقت، الأشهر), `task_details_screen`, `create_task_screen*` | `task_starter_sheet`, `task_link_sheet`, 3 inline |
| 4 | Guests | `guests/screens/guest_list_screen`, `guest_details_screen`, `guest_import_screen`, `guest_invite_screen*`, `guest_attendance_screen` | `guest_form_sheet`, `guest_groups_sheet`, `guest_send_sheet`, 4 inline |
| 5 | Providers | `marketplace/screens/provider_marketplace_screen*` (استكشف، طلباتي، المحادثات، المفضلة), `provider_details_screen`, `quote_request_screen`, `provider_requests_screen`, `plan_bookings_screen`, `provider_reviews_screen`, `favorite_providers_screen`, `booking_moment_screen`, `chat/screens/chat_screen` | `quote_decision_sheets`, `review_report_sheet`, 5 inline, 2 in chat |
| 6 | The door | `welcome_gateway/screens/smart_welcome_screen*` (الباب، من أنت، الأسئلة الثلاثة، خطتك جاهزة), `auth/screens/register_screen`, `otp_screen`, `login_screen`, `reset_password_screen`, `onboarding/screens/local_plan_migration_screen` | date picker |
| 7 | Account and team | `more/screens/more_screen`, `settings/screens/*` (6), `support/screens/support_screen`, `wedding_plans/screens/my_wedding_plans_screen`, `plan_management_screen`, `plan_assistant_screen`, `mahr_moment_screen`, `wedding_moment_screen`, `wedding_day/screens/plan_events_screen`, `notifications/screens/notifications_screen`, `sharing/screens/sharing_screen`, `edit_shared_member_screen`, `contribution_history_screen` | `change_phone_sheet`, `set_password_sheet`, `add_participant_sheet`, quick add, 6 inline |

About 60 screen files and 57 sheets. Out of this plan: the participant shell, the provider portal and the admin panel.

Order follows what the couple opens most: money, tasks, guests, providers, then the door and the account. The door is approved by contract (D75) and the money tab was rebuilt two days ago (D102): for both, a task changes layout only where the owner says so after seeing the picture.

---

### Task 0: The home's pieces move into the kit

**Files:**
- Modify: `mobile/lib/core/experience_v3/aarast_journey.dart`
- Modify: `mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_next_step.dart`, `aarast_dashboard_money_card.dart`, `aarast_dashboard_tiles.dart`
- Test: `mobile/test/core/experience_v3/journey_home_pieces_test.dart`
- Modify: `docs/project/DECISIONS.md`, `docs/project/STATUS.md`
- Create: `docs/qa/mobile-test-baseline-linux.txt`

**Interfaces:**
- Produces, all in `aarast_journey.dart`:
  - `JourneyCard({required Widget child, EdgeInsetsGeometry padding, Key? key})`: paper, hairline, card corner.
  - `JourneyActionRow({required Widget tile, required String eyebrow, required String title, InlineSpan? detail, required String action, required VoidCallback onAction, Color? eyebrowColor})`: the one-row action with the drop rule above.
  - `JourneyCountTile({required String count, required String unit, required Color color, required Color soft})`: the 48 tile («5 أيام»).
  - `JourneyVerdictChip({required bool ok, required String words})`.
  - `JourneyArch({required int count, required double? share, required Color color})`: 64 by 36, line 5.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('the action row keeps one row at 360 and drops its button at 320', (tester) async {
  Future<void> at(double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(host(JourneyCard(child: JourneyActionRow(
      tile: const JourneyCountTile(count: '5', unit: 'أيام', color: AarastV3Color.brandAccentStrong, soft: AarastV3Color.brandAccentSoft),
      eyebrow: 'الخطوة الجاية', title: 'دفعة القاعة', action: 'سجّل الدفعة', onAction: () {}))));
  }
  await at(360);
  expect(tester.getCenter(find.text('سجّل الدفعة')).dy, closeTo(tester.getCenter(find.text('دفعة القاعة')).dy, 24));
  await at(320);
  expect(tester.getTopLeft(find.text('سجّل الدفعة')).dy, greaterThan(tester.getBottomLeft(find.text('دفعة القاعة')).dy));
  expect(tester.takeException(), isNull);
});
testWidgets('the verdict chip says good and bad with an icon', (tester) async {
  await tester.pumpWidget(host(const JourneyVerdictChip(ok: false, words: 'ينقصك 300 ألف')));
  expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
});
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/core/experience_v3/journey_home_pieces_test.dart`
Expected: FAIL, the widgets are not defined.

- [ ] **Step 3: Move the five widgets into the kit under the names above and make the home use them**

The bodies exist in the three dashboard files (`_DaysTile`, `_VerdictChip`, `_ArchPainter`, the next step's `LayoutBuilder`); move them, do not rewrite them.

- [ ] **Step 4: Run the checks**

Run: `flutter analyze && flutter test --exclude-tags golden test/core test/features/wedding_plans test/features/home`
Expected: analyze clean; failures only from the baseline list.

- [ ] **Step 5: Record and commit**

Save the baseline list to `docs/qa/mobile-test-baseline-linux.txt` (one failing test per line, from `flutter test --exclude-tags golden --reporter=failures-only`). Add one line to `DECISIONS.md`: «D110: الرئيسية وباقي شاشات العريس تأخذ لغة الرئيسية المعتمدة (2026-11-11) شاشة شاشة، وهذا استثناء من التجميد (D67). بطاقة العد تبقى». Add the resume point to `STATUS.md`. Commit: `refactor(kit): the home's pieces become kit widgets`.

---

### Tasks 1 to 7: one batch each, the same cycle for every screen in it

A batch's screens are the rows of the inventory, in the order written. For each screen:

**Files:**
- Modify: the screen's files named in the inventory.
- Test: the screen's existing tests under `mobile/test/features/<section>/`, plus one new test only for a rule the new layout adds.

**Interfaces:**
- Consumes: Task 0's kit widgets, exactly as named.
- Produces: nothing new for other tasks. A piece two screens need goes into the kit first, in its own commit.

- [ ] **Step 1: Fill the screen card** from `.claude/skills/aarast-screen/SKILL.md` (goal, main action, where from, where to, data source for every figure, roles). A blank that cannot be filled stops the task and goes to the owner.
- [ ] **Step 2: Render the screen as it is** with its preview or prototype test (`flutter test --update-goldens test/prototype/now_<section>`), copy the pictures out, and restore the repository's images (`git restore --source=HEAD --worktree -- test/prototype test/goldens`).
- [ ] **Step 3: Write down what changes, in three lines or fewer,** against the Global Constraints: what leads, what the one action is, what goes away. Show the owner the before picture and these lines when the change removes or moves information. Layout-only changes go ahead.
- [ ] **Step 4: Change the screen** with the kit widgets. Keep every key, every semantic label and every copy string unless the card says otherwise.
- [ ] **Step 5: Run the checks.** `flutter analyze` clean; `flutter test --exclude-tags golden test/features/<section> test/core` with no failure outside `docs/qa/mobile-test-baseline-linux.txt`. At the end of the batch, the whole suite once.
- [ ] **Step 6: Render again** in these cases: default, 320 wide with text scale 1.3, amounts hidden (money screens), the bride, one non-owner role where it exists. Look at each picture.
- [ ] **Step 7: Commit and push** one screen: `ui(<section>): <screen> in the home's language`, the card in the body, the changed tests named.
- [ ] **Step 8: Show the owner the after picture and stop** until he answers. His correction is the next commit on the same screen.

At the end of each batch: update the resume point in `STATUS.md`, and list for the owner what he must regenerate on Windows (`flutter test --update-goldens` for the batch's golden files).

Batch contents and what is known to need a decision before work starts:

- **Task 1, the money tab:** four tabs. Open question for the owner: the tab's three header icons take words («شارك»), or stay.
- **Task 2, money pages:** ten screens. The record-payment form keeps D106's partial payment rule.
- **Task 3, tasks:** three screens. The swipe to finish stays; a visible way to finish is added only if the owner says so.
- **Task 4, guests:** five screens. Reminders are sent from the owner's own WhatsApp (C30, D83).
- **Task 5, providers:** nine screens. Open question: two tabs («خدمات عرسك», «استكشف») with chats as a labelled button, or the four tabs as today. Nothing starts before his answer.
- **Task 6, the door:** nine screens under D75's contract. Each screen is shown before it is touched.
- **Task 7, account and team:** about twenty screens, mostly rows; expected to be the lightest batch.
