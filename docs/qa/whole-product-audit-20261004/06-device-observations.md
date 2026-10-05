# Current phone observations — 2026-10-05

This is a read/navigation checkpoint in the whole-product audit, not completed device acceptance.

Latest connection state: USB disconnected after the manual budget read/keyboard batch, before the intended final Back. Earlier observations below remain historical evidence for this continuation; they do not assert the device is currently connected. No account logout or budget submission was performed.

## Identity and privacy

- Source reviewed:14eccb50c6b2e050b044c7b00ac38a7e64f5164b, staging/integration-decoupling-20261002. No tracked application changes.
- Authorized USB device: Samsung SM_S938B. Serial deliberately omitted. Aarast foreground checked before captures.
- Installed package: com.aarast.aarast_mobile.qa; version1.0.0/code9; minSDK24/target36. Device font scale1.15; screenshot resolution1440×3120. Neither package version nor successful rendering proves the APK's source revision.
- Owner entered credentials manually after the empty login screen. No password, token, authentication storage or OTP read/captured by the audit.
- Current UI identifies the context as صاحب الخطة and shows the logged-in account in the owner member row. This supports owner-context UI observation; it is not a complete server authorization matrix.
- Raw images remain outside Git at C:/Users/Rashad/AppData/Local/Aarast/Staging/WholeProductAudit-20261005-Device/. Names, phones, plan identifiers and private screenshots must not be copied into reports or Git.
- Normal application reads and the owner's manual login communicated with its configured Backend. No SSH, infrastructure inspection, deployment, server resource changes or direct DB/API mutation tests occurred. Abdo/resources/other projects were not accessed.

## Observed sequence

Immediate skeleton captures are loading observations, not failures. Settled captures below establish what was eventually rendered. A row marked OBSERVED means its stated read/render/navigation happened, not that all writes, errors and roles were accepted.

| Surface / register | Observed current behavior | Evidence filename outside Git | Outcome and limits |
| --- | --- | --- | --- |
| Entry/login S01/S21 | Welcome gives plan/invite/provider/login paths. Empty password login form and alternate WhatsApp OTP/register/forgot-password actions visible at1.15 text scale |01-entry.png,02-login.png | OBSERVED. Owner performed login; credentials/real OTP flow not inspected |
| Owner home S05/S10/S11 | Five tabs; planning stage/date/countdown;100% completion; priority to set budget; task card0 with مكتملة; guest pending1; team2 |03-after-owner-login.png,11-home.png | OBSERVED. Completion meaning is Q05; no full wedding readiness claim |
| Tasks S26 | Settled summary:1 completed,0 remaining,0 today,100%. Expanding completed group reveals one task, its due date and assignee |05-tasks-loaded.png,06-completed-tasks-expanded.png | OBSERVED. No complete/reopen/edit/assign/delete/call action taken |
| Guests S28 | One guest, one expected seat, pending response. Status/filter/attention copy and update-response control visible; vertical scroll exposes the entire row/action |07-guests.png,08-guests-scrolled.png,09-current-guests.png | OBSERVED. Initial lower content is scrollable, not a proven clipping defect. No guest invitation delivery, RSVP or write tested |
| Money starter S07 | Empty-money setup offers10 preselected categories, explicit no automatic amounts/commitments, batch-category creation and manual alternative |10-money.png | OBSERVED. Setup submit creates data; it was not pressed. No budget/category/cost/payment/schedule written; finance-detail acceptance remains pending |
| Sharing overview S51 | Privacy statement for money; owner plus one helper; add-member and member rights summary |12-sharing.png | OBSERVED. The displayed accepted member is evidence of current list state, not a new invitation/acceptance performed here |
| Existing member editor S53 | Role choices and explicit organization/money/notification rights. Provider/conversation power is explained. Scroll reaches save and remove controls |13-member-rights.png,14-member-rights-bottom.png | OBSERVED. No role, switch, save or removal pressed; Android Back exits unchanged. This is not the contributor rights sheet of F04 |
| Marketplace S66 | No providers under initial filters; clear-filters shows loading then returns no-provider state |15-marketplace.png,16-marketplace-cleared.png,17-marketplace-settled.png | OBSERVED. Cause of empty catalogue not proven; no global claim that providers do not exist. Real quote/provider handoff cannot be accepted from this state |
| Favorites/comparison S67 | Favorites loads then displays empty state and browse destination |18-favorites.png,19-favorites-settled.png | OBSERVED. Basic comparison exists in source but could not be exercised with these empty saved records; no favorite changed |
| Account menu S73 | Context explicitly صاحب الخطة; shared plans, own plans, create-plan, exit-path, favorites/settings/help destinations visible |21-account-menu.png | OBSERVED. No context exit, logout, new plan or profile edit performed |
| Shared plans S65 | Empty state says no plans shared with this account |22-shared-plans.png | OBSERVED. Other actors/accounts unknown; no membership inference from role names; no context switched |
| Settings S17 | In-app notifications available; device notifications displayed as enabled for this account on a registered device; reminder/message switches; unchanged Save disabled |24-settings-settled.png | OBSERVED. No setting saved. This is capability/status display, not actual FCM delivery to the phone |
| Notifications S16 | Two unread entries: an accepted-invitation event and a task reminder. Read-all and archive controls visible |27-notifications-settled.png | OBSERVED. No item/read-all/archive pressed; no notification destination or actual Push arrival tested. Existing reminder is history, not proof that completed-task reminders are still generated |

## Q05 — progress meaning needs an explicit decision

The home hero says إنجاز100% while its next priority is to establish the budget. The Tasks screen shows one completed task and no remaining tasks. Current source confirms the percentage is completed tasks / total tasks, rounded; with no tasks it returns0:

- backend/src/dashboard/dashboard-summary.presenter.ts:392–398.
- backend/src/dashboard/dashboard.service.ts:360.
- mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart:483/:494 uses the general completion label and plan-progress semantics.
- mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_mosaic.dart:204–218 shows the remaining-task number and مكتملة when it reaches0 with existing tasks.

The arithmetic agrees with the observed task state. This is a wording/meaning question, not a proven calculation bug or a reason to invent a wedding-readiness formula. Proposed smallest decision: explicitly label task progress if that is the intended metric. Q01 remains a separate ambiguity in the task-card number/description. No labels or calculations changed.

## What this means for the next stage

1. Retain the useful separation of tasks, financial records, guest counts and explicit sharing rights. The current limited records cannot validate a complete wedding relationship or all actor permissions.
2. Continue semantic/state inventory without inferring a bug from an empty list. Record the actual source/runtime identity and a disposable Staging-only data/actor scope before later write tests.
3. Later finance acceptance needs a real budget/cost/payment/schedule fixture; requester/provider acceptance needs a visible test provider and both parties; contributor acceptance needs a known shared context. Do not create/approve accounts or grant rights as a shortcut in this read phase.
4. Real Push, current APK/Backend revision attribution, invite cold-start/resume, offline/reconnect, failed-write recovery and multi-actor journeys remain NOT PROVEN.

## Additional native check

Executed from the actual worktree/mobile:

    flutter test --no-pub test/features/auth/login_screen_responsive_test.dart --reporter expanded

Exit0,3 tests PASS: compact login fields;320px RTL/1.3 text;320px RTL/2.0 text. Log: login-responsive.log in the outside-Git directory above. These fixture tests do not establish keyboard behavior, real authentication, OTP, or that the installed APK was built from this HEAD. Existing default-platform Flutter plugin warnings remain.

Audit remains IN PROGRESS. No application code/config/schema fix, Git mutation, server deployment or product-data mutation was performed by these audit controls. Local navigation/filters, normal app reads and the owner's own login are explicitly acknowledged.

## Continued home/plan read checkpoint

| Element | Current observation | Outside-Git evidence | Limits |
| --- | --- | --- | --- |
| Home/quick add | Current home priority is budget setup; selector recommends طلب عرض سعر as الأنسب الآن, with guest/cost/task alternatives |28-resumed-home.png,29-quick-add.png | No action selected; Back closed. Q06: differently scoped suggestions, not a proven send/ranking defect |
| Plan center | Plan identity, geographic data, owner/team counts, preferences, metadata completeness, archive explanation |30-plan-center.png,34-plan-center-lower.png,35-plan-center-preferences.png,36-plan-center-safety.png | No private values transcribed; missing optional address is not called a defect. Archive/location/member actions not executed |
| Actual basic editor | Heading overlaps Android status area on two opens; scroll exposes Save, Back closes unchanged |31-plan-edit.png,32-plan-edit-bottom.png,33-plan-edit-reopened.png | F09 source/local proof below. No draft input changed or Save submitted; no keyboard/save acceptance |
| Distinct percentages | Home task progress100%; plan metadata completeness80%, explicitly missing priorities |28-resumed-home.png,35-plan-center-preferences.png | Five metadata checks in plan_management_view.dart:128–150 agree. This is evidence to clarify labels, not wrong arithmetic or a new overall wedding readiness calculation |

### Native focused tests

From mobile, executed:

    flutter test --no-pub test/features/wedding_plans/aarast_dashboard_focus_test.dart test/features/wedding_plans/canonical_quick_add_actions_test.dart test/features/wedding_plans/plan_management_view_test.dart test/features/finance/money_starter_setup_test.dart --reporter expanded

Exit0,29 tests PASS; home-plan-elements-native-tests.log outside Git. These add to the prior249 selected tests:254 Mobile +24 Admin =278 PASS. Not a full suite or a device acceptance verdict. Existing default-platform Flutter plugin warnings remain.

### F09 diagnostic, outside Git

    flutter test --no-pub C:/Users/Rashad/AppData/Local/Aarast/Staging/WholeProductAudit-20261005-Device/plan_edit_safe_area_probe_test.dart --reporter expanded

Uses actual PlanCenterScreen and its actual editor, mock local storage,320×720/1.3 scale and top inset30, with a Dio adapter forbidding real HTTP. First attempt exit1: launch tap occurred before scroll layout settled and missed the viewport. Scratch-only correction settles/asserts the hit target; actual finding assertion retained. Rerun exit0/1 diagnostic test: heading top14 < inset30; Save hit-testable after scroll, never submitted. Log plan-edit-safe-area-proof.log. PASS means reproduced defect, not fixed product. Installed Flutter removes top padding when the sheet's useSafeArea=false, making its inner SafeArea insufficient.

Four outside-Git diagnostics now reproduce F05/F06/F07/F09 separately from the278 passing native selected tests. Task2 remains IN PROGRESS; no later actor/write gate closed.

## Manual budget read/keyboard checkpoint

-37-money-starter-return.png: starter still displayed10 selected categories. No batch submit or selection change.
-38-budget-manual-open.png: authority-check spinner after choosing أفضل ترتيبها بنفسي.39-budget-manual-settled.png: actual empty budget form, currency choices, zero allocation and category-create control. This settled state replaces the loading observation; no loading defect inferred.
-40-budget-keyboard.png: numeric keyboard after focus of empty total field, no text entry. Local status changed to saved draft automatically; this is not a Backend budget save. Normal local cache/draft side effects of app navigation are acknowledged.
-41-budget-bottom-no-save.png: keyboard dismissed, still upper form; despite filename it is not proof of lower content.42-budget-empty-categories.png: subsequent scroll reaches entire no-category message and visible Save. Save/create/category/currency/privacy actions not pressed.
- Final intended Back did not execute: ADB returned no devices/emulators, so actual return to starter is NOT PROVEN. Last observed screen is the empty manual budget form. No draft or cache was deleted to make the audit look clean. Restart, full draft recovery, validation, saved totals, real write/retry and permission changes remain NOT PROVEN. Source review can continue independently; this USB loss is a blocker for further physical navigation only.
