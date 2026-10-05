# Surface register — source census and review status

Source: `14eccb50c6b2e050b044c7b00ac38a7e64f5164b`. Task2 IN PROGRESS.

## Count reconciliation

- 63 GoRoute declarations from actual router constructor blocks; matched against63 source occurrences.
- Generated64 route strings include a dashboard suffix (aarast_back_button_dispatcher.dart:48) and a preview constant (app_router.dart:158) that are not declared GoRoutes. Root splash is declared but excluded from that string scanner.
- No scanner changes or new finding from this distinction; docs-sync checks its declared string inventory.
- 20 Mobile feature directories;495 widget declaration candidates within feature screens/widgets and main_shell.
- This narrower source census differs from the earlier496 broad feature widget candidates by scope; neither number counts cards or unique user screens.
- 18 Admin page source files. Redirects/layout/error/actions/modals require semantic review.
- Each candidate below is SOURCE LOCATED only. Purpose/authority/data/formula/action/state/recovery/runtime verdict remain UNREVIEWED until its containing code is traced. Do not mark this register a completed audit.

## Review record format

For each semantic surface/control, retain:
ID | actor/context | entry | screen/section/card/control | applicable state | need | source/formula/unit/freshness | authority | action/effect | next actor | failure/recovery | code | tests | runtime | verdict.

## Declared route entries

Paths below are labeled `mobile:` logical navigation, not Backend API endpoints.

| ID | Logical entry | Area candidate | Source | State |
| --- | --- | --- | --- | --- |
| R01 | `mobile:/notifications` | notifications | mobile/lib/core/routing/app_router.account.dart:5 | Partial semantic SOURCE: S16/S39; full state/device coverage pending |
| R02 | `mobile:/invites` | sharing | mobile/lib/core/routing/app_router.account.dart:9 | Partial semantic SOURCE: S25; full state/device coverage pending |
| R03 | `mobile:/invites/:token` | sharing | mobile/lib/core/routing/app_router.account.dart:13 | Partial semantic SOURCE: S25; full state/device coverage pending |
| R04 | `mobile:/more` | more | mobile/lib/core/routing/app_router.account.dart:18 | Partial semantic SOURCE: S73; full state/device coverage pending |
| R05 | `mobile:/settings` | settings | mobile/lib/core/routing/app_router.account.dart:22 | Partial semantic SOURCE: S17; full state/device coverage pending |
| R06 | `mobile:/support` | support | mobile/lib/core/routing/app_router.account.dart:26 | Partial semantic SOURCE: S18; full state/device coverage pending |
| R07 | `mobile:/wedding-plans` | wedding-plans | mobile/lib/core/routing/app_router.account.dart:30 | Partial semantic SOURCE: S65; full state/device coverage pending |
| R08 | `mobile:/wedding-plans/create` | wedding_plans | mobile/lib/core/routing/app_router.account.dart:34 | Partial semantic SOURCE: S65; full state/device coverage pending |
| R09 | `mobile:/conversations` | chat | mobile/lib/core/routing/app_router.conversations.dart:8 | Partial semantic SOURCE: S69; full state/device coverage pending |
| R10 | `mobile:/conversations/:id` | chat | mobile/lib/core/routing/app_router.conversations.dart:15 | Partial semantic SOURCE: S33; full state/device coverage pending |
| R11 | `mobile:/quotes/:id/conversation` | chat | mobile/lib/core/routing/app_router.conversations.dart:25 | Partial semantic SOURCE: S70; full state/device coverage pending |
| R12 | `mobile:/` | auth/entry | mobile/lib/core/routing/app_router.entry.dart:5 | Partial semantic SOURCE: S71; full state/device coverage pending |
| R13 | `mobile:/welcome` | welcome | mobile/lib/core/routing/app_router.entry.dart:9 | Partial semantic SOURCE: S01; full state/device coverage pending |
| R14 | `mobile:/onboarding` | onboarding | mobile/lib/core/routing/app_router.entry.dart:15 | Partial semantic SOURCE: S71; alias to welcome; full state/device coverage pending |
| R15 | `mobile:/dev/guest-onboarding` | dev | mobile/lib/core/routing/app_router.entry.dart:20 | Partial semantic SOURCE: S71; dev preview flag, not a separate Release feature; full state/device coverage pending |
| R16 | `mobile:/login` | auth | mobile/lib/core/routing/app_router.entry.dart:25 | Partial semantic SOURCE: S21; full state/device coverage pending |
| R17 | `mobile:/register` | auth | mobile/lib/core/routing/app_router.entry.dart:30 | Partial semantic SOURCE: S22; full state/device coverage pending |
| R18 | `mobile:/reset-password` | auth | mobile/lib/core/routing/app_router.entry.dart:37 | Partial semantic SOURCE: S24; full state/device coverage pending |
| R19 | `mobile:/otp` | auth | mobile/lib/core/routing/app_router.entry.dart:42 | Partial semantic SOURCE: S23; full state/device coverage pending |
| R20 | `mobile:/home` | home/context/local migration | mobile/lib/core/routing/app_router.entry.dart:57 | Partial semantic SOURCE: S03/S04/S71/S72; full state/device coverage pending |
| R21 | `mobile:/providers` | marketplace | mobile/lib/core/routing/app_router.marketplace.dart:8 | Partial semantic SOURCE: S66/S70; full state/device coverage pending |
| R22 | `mobile:/providers/favorites` | marketplace | mobile/lib/core/routing/app_router.marketplace.dart:14 | Partial semantic SOURCE: S67; full state/device coverage pending |
| R23 | `mobile:/providers/:id` | marketplace | mobile/lib/core/routing/app_router.marketplace.dart:18 | Partial semantic SOURCE: S13/S68; full state/device coverage pending |
| R24 | `mobile:/providers/:id/quote` | marketplace | mobile/lib/core/routing/app_router.marketplace.dart:39 | Partial semantic SOURCE: S29; full state/device coverage pending |
| R25 | `mobile:/providers/:id/quote-request` | marketplace | mobile/lib/core/routing/app_router.marketplace.dart:62 | Partial semantic SOURCE: S29; same quote form route family; full state/device coverage pending |
| R26 | `mobile:/wedding-plans/:id/dashboard` | wedding_plans | mobile/lib/core/routing/app_router.plan_shell.dart:15 | Partial semantic SOURCE: S05/S10/S11; full state/device coverage pending |
| R27 | `mobile:/wedding-plans/:id/money` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:29 | Partial semantic SOURCE: S07/S08/S09; full state/device coverage pending |
| R28 | `mobile:/wedding-plans/:id/money/budget` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:49 | Partial semantic SOURCE: S41; full state/device coverage pending |
| R29 | `mobile:/wedding-plans/:id/money/categories/create` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:56 | Partial semantic SOURCE: S42; full state/device coverage pending |
| R30 | `mobile:/wedding-plans/:id/money/categories/:categoryId` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:66 | Partial semantic SOURCE: S43; full state/device coverage pending |
| R31 | `mobile:/wedding-plans/:id/money/categories/:categoryId/edit` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:77 | Partial semantic SOURCE: S42; full state/device coverage pending |
| R32 | `mobile:/wedding-plans/:id/money/costs` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:97 | Partial semantic SOURCE: S44; full state/device coverage pending |
| R33 | `mobile:/wedding-plans/:id/money/costs/create` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:107 | Partial semantic SOURCE: S45; full state/device coverage pending |
| R34 | `mobile:/wedding-plans/:id/money/costs/:costId/edit` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:120 | Partial semantic SOURCE: S45; full state/device coverage pending |
| R35 | `mobile:/wedding-plans/:id/money/costs/:costId/payments/create` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:134 | Partial semantic SOURCE: S47; full state/device coverage pending |
| R36 | `mobile:/wedding-plans/:id/money/payments/:paymentId` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:143 | Partial semantic SOURCE: S48; full state/device coverage pending |
| R37 | `mobile:/wedding-plans/:id/money/schedules` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:153 | Partial semantic SOURCE: S49; full state/device coverage pending |
| R38 | `mobile:/wedding-plans/:id/money/costs/:costId/schedules/create` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:162 | Partial semantic SOURCE: S50; full state/device coverage pending |
| R39 | `mobile:/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/edit` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:171 | Partial semantic SOURCE: S50; full state/device coverage pending |
| R40 | `mobile:/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId/pay` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:182 | Partial semantic SOURCE: S50; full state/device coverage pending |
| R41 | `mobile:/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:193 | Partial semantic SOURCE: S49; full state/device coverage pending |
| R42 | `mobile:/wedding-plans/:id/money/costs/:costId` | finance | mobile/lib/core/routing/app_router.plan_shell.dart:203 | Partial semantic SOURCE: S46; full state/device coverage pending |
| R43 | `mobile:/wedding-plans/:id/tasks` | tasks | mobile/lib/core/routing/app_router.plan_shell.dart:212 | Partial semantic SOURCE: S26; full state/device coverage pending |
| R44 | `mobile:/wedding-plans/:id/guests/add` | guests | mobile/lib/core/routing/app_router.plan_shell.dart:222 | Partial semantic SOURCE: S20/S28; embedded guest form entry; full state/device coverage pending |
| R45 | `mobile:/wedding-plans/:id/guests` | guests | mobile/lib/core/routing/app_router.plan_shell.dart:233 | Partial semantic SOURCE: S28; full state/device coverage pending |
| R46 | `mobile:/wedding-plans/:id/providers` | marketplace | mobile/lib/core/routing/app_router.plan_shell.dart:240 | Partial semantic SOURCE: S66/S70; full state/device coverage pending |
| R47 | `mobile:/provider/apply` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:5 | Partial semantic SOURCE: S54; full state/device coverage pending |
| R48 | `mobile:/provider/apply/status` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:13 | Partial semantic SOURCE: S54; application status surface; full state/device coverage pending |
| R49 | `mobile:/provider/dashboard` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:21 | Partial semantic SOURCE: S12/S30/S34/S55/S56; full state/device coverage pending |
| R50 | `mobile:/provider/profile/edit` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:30 | Partial semantic SOURCE: S54; full state/device coverage pending |
| R51 | `mobile:/provider/services/new` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:40 | Partial semantic SOURCE: S55; full state/device coverage pending |
| R52 | `mobile:/provider/packages/new` | provider_portal | mobile/lib/core/routing/app_router.provider_portal.dart:50 | Partial semantic SOURCE: S55; full state/device coverage pending |
| R53 | `mobile:/wedding-plans/:id/plan-center` | wedding_plans | mobile/lib/core/routing/app_router.wedding_plans.dart:5 | Partial semantic SOURCE: S06/S14/S15; full state/device coverage pending |
| R54 | `mobile:/wedding-plans/:id/wedding-day` | wedding_day | mobile/lib/core/routing/app_router.wedding_plans.dart:31 | Partial semantic SOURCE: S35; full state/device coverage pending |
| R55 | `mobile:/wedding-plans/:id/tasks/create` | tasks | mobile/lib/core/routing/app_router.wedding_plans.dart:48 | Partial semantic SOURCE: S27; full state/device coverage pending |
| R56 | `mobile:/wedding-plans/:id/tasks/:taskId/edit` | tasks | mobile/lib/core/routing/app_router.wedding_plans.dart:59 | Partial semantic SOURCE: S27; full state/device coverage pending |
| R57 | `mobile:/wedding-plans/:id/timeline` | tasks | mobile/lib/core/routing/app_router.wedding_plans.dart:78 | Partial semantic SOURCE: S26; timeline mode; full state/device coverage pending |
| R58 | `mobile:/wedding-plans/:id/sharing` | sharing | mobile/lib/core/routing/app_router.wedding_plans.dart:89 | Partial semantic SOURCE: S51; full state/device coverage pending |
| R59 | `mobile:/wedding-plans/:id/notifications` | notifications | mobile/lib/core/routing/app_router.wedding_plans.dart:101 | Partial semantic SOURCE: S16/S39; full state/device coverage pending |
| R60 | `mobile:/wedding-plans/:id/contributions` | sharing | mobile/lib/core/routing/app_router.wedding_plans.dart:112 | Partial semantic SOURCE: S19; full state/device coverage pending |
| R61 | `mobile:/wedding-plans/:id/sharing/add` | sharing | mobile/lib/core/routing/app_router.wedding_plans.dart:123 | Partial semantic SOURCE: S52; full state/device coverage pending |
| R62 | `mobile:/wedding-plans/:id/sharing/:memberId/edit` | sharing | mobile/lib/core/routing/app_router.wedding_plans.dart:134 | Partial semantic SOURCE: S53; full state/device coverage pending |
| R63 | `mobile:/shared/wedding-plans` | sharing | mobile/lib/core/routing/app_router.wedding_plans.dart:146 | Partial semantic SOURCE: S65; full state/device coverage pending |

## Non-route surfaces to trace explicitly

- Owner MainShell's five tabs and quick-add sheet/long-press.
- Contributor PlanCenter workspace and permission/account/leave sheets.
- ProviderPortal's five tabs, state-specific operation blocks and profile preview.
- LocalPlanMigrationScreen before authenticated context entry.
- RouterErrorScreen, context loading/error/no-path/selection states.
- Embedded guest forms, money forms/details/action pickers, media galleries, quote dialogs.
- All Admin sidebar/layout/not-found/confirmation/table actions.
- Public invite/privacy/support and Android notification/link/permission entry surfaces.
- Core reusable components outside the feature candidate list: trace from usage; do not assume an absence here means unused.

## Widget declaration candidates

Candidate is not a usability verdict or a reachable screen.

### account_contexts

- `W001` — `AccountContextSelectionScreen` — mobile/lib/features/account_contexts/screens/account_context_selection_screen.dart:11 — UNREVIEWED.
- `W002` — `_AccountPathCard` — mobile/lib/features/account_contexts/screens/account_context_selection_screen.dart:93 — UNREVIEWED.
- `W003` — `AccountContextEntryGate` — mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart:15 — UNREVIEWED.
- `W004` — `_ReplaceRoute` — mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart:92 — UNREVIEWED.
- `W005` — `WeddingPlanContextGate` — mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart:26 — UNREVIEWED.
- `W006` — `SelectedWeddingPlanContextGate` — mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart:127 — UNREVIEWED.
- `W007` — `_LoginRequiredPlanContext` — mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart:197 — UNREVIEWED.
- `W008` — `_MismatchedPlanContext` — mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart:239 — UNREVIEWED.

### auth

- `W009` — `LoginScreen` — mobile/lib/features/auth/screens/login_screen.dart:16 — UNREVIEWED.
- `W010` — `LoginExperience` — mobile/lib/features/auth/screens/login_screen.dart:155 — UNREVIEWED.
- `W011` — `_LoginTopBar` — mobile/lib/features/auth/screens/login_screen.dart:332 — UNREVIEWED.
- `W012` — `_LoginRecoveryRow` — mobile/lib/features/auth/screens/login_screen.dart:369 — UNREVIEWED.
- `W013` — `_LoginNarrative` — mobile/lib/features/auth/screens/login_screen.dart:429 — UNREVIEWED.
- `W014` — `_InlineDivider` — mobile/lib/features/auth/screens/login_screen.dart:464 — UNREVIEWED.
- `W015` — `_RegisterPrompt` — mobile/lib/features/auth/screens/login_screen.dart:495 — UNREVIEWED.
- `W016` — `OtpScreen` — mobile/lib/features/auth/screens/otp_screen.dart:35 — UNREVIEWED.
- `W017` — `_OtpNotice` — mobile/lib/features/auth/screens/otp_screen.dart:449 — UNREVIEWED.
- `W018` — `RegisterScreen` — mobile/lib/features/auth/screens/register_screen.dart:22 — UNREVIEWED.
- `W019` — `_RegisterNarrative` — mobile/lib/features/auth/screens/register_screen.dart:304 — UNREVIEWED.
- `W020` — `_AccountTypeSegmentedControl` — mobile/lib/features/auth/screens/register_screen.dart:350 — UNREVIEWED.
- `W021` — `_SegmentOption` — mobile/lib/features/auth/screens/register_screen.dart:407 — UNREVIEWED.
- `W022` — `_ProviderModeNote` — mobile/lib/features/auth/screens/register_screen.dart:459 — UNREVIEWED.
- `W023` — `_ProviderDropdown` — mobile/lib/features/auth/screens/register_screen.dart:479 — UNREVIEWED.
- `W024` — `_ProviderReferenceFields` — mobile/lib/features/auth/screens/register_screen.dart:521 — UNREVIEWED.
- `W025` — `_ProviderReferenceLoading` — mobile/lib/features/auth/screens/register_screen.dart:602 — UNREVIEWED.
- `W026` — `ResetPasswordScreen` — mobile/lib/features/auth/screens/reset_password_screen.dart:23 — UNREVIEWED.
- `W027` — `_OtpNotice` — mobile/lib/features/auth/screens/reset_password_screen.dart:496 — UNREVIEWED.
- `W028` — `SplashScreen` — mobile/lib/features/auth/screens/splash_screen.dart:12 — UNREVIEWED.
- `W029` — `AuthWeddingScaffold` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:9 — UNREVIEWED.
- `W030` — `AuthBrandMark` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:61 — UNREVIEWED.
- `W031` — `AuthObscureToggle` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:107 — UNREVIEWED.
- `W032` — `AuthPanel` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:132 — UNREVIEWED.
- `W033` — `AuthTextField` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:154 — UNREVIEWED.
- `W034` — `AuthInlineError` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:277 — UNREVIEWED.
- `W035` — `AuthBackButton` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:313 — UNREVIEWED.
- `W036` — `AuthFooterLink` — mobile/lib/features/auth/widgets/auth_wedding_widgets.dart:328 — UNREVIEWED.

### catalogs

- No screen/widget class found in this census scope; data/catalog consumers must be traced.

### chat

- `W037` — `ChatScreen` — mobile/lib/features/chat/screens/chat_screen.dart:17 — UNREVIEWED.
- `W038` — `_ChatHeader` — mobile/lib/features/chat/screens/chat_screen.dart:314 — UNREVIEWED.
- `W039` — `_ConversationEventCard` — mobile/lib/features/chat/screens/chat_screen.dart:411 — UNREVIEWED.
- `W040` — `_MessageBubble` — mobile/lib/features/chat/screens/chat_screen.dart:477 — UNREVIEWED.
- `W041` — `_PrivateChatImage` — mobile/lib/features/chat/screens/chat_screen.dart:548 — UNREVIEWED.
- `W042` — `_PrivateImageFailure` — mobile/lib/features/chat/screens/chat_screen.dart:662 — UNREVIEWED.
- `W043` — `_Composer` — mobile/lib/features/chat/screens/chat_screen.dart:675 — UNREVIEWED.
- `W044` — `_ProviderNotJoinedNotice` — mobile/lib/features/chat/screens/chat_screen.dart:753 — UNREVIEWED.
- `W045` — `_ConversationUnavailableNotice` — mobile/lib/features/chat/screens/chat_screen.dart:775 — UNREVIEWED.
- `W046` — `_BlockedNotice` — mobile/lib/features/chat/screens/chat_screen.dart:797 — UNREVIEWED.
- `W047` — `QuoteConversationEntryScreen` — mobile/lib/features/chat/screens/quote_conversation_entry_screen.dart:10 — UNREVIEWED.
- `W048` — `ConversationListView` — mobile/lib/features/chat/widgets/conversation_list_view.dart:12 — UNREVIEWED.
- `W049` — `_ConversationTile` — mobile/lib/features/chat/widgets/conversation_list_view.dart:96 — UNREVIEWED.

### finance

- `W050` — `BudgetCategoryDetailsScreen` — mobile/lib/features/finance/screens/budget_category_details_screen.dart:16 — UNREVIEWED.
- `W051` — `_CategoryHero` — mobile/lib/features/finance/screens/budget_category_details_screen.dart:193 — UNREVIEWED.
- `W052` — `_CategoryDivider` — mobile/lib/features/finance/screens/budget_category_details_screen.dart:306 — UNREVIEWED.
- `W053` — `_CategoryValue` — mobile/lib/features/finance/screens/budget_category_details_screen.dart:320 — UNREVIEWED.
- `W054` — `BudgetCategoryFormScreen` — mobile/lib/features/finance/screens/budget_category_form_screen.dart:19 — UNREVIEWED.
- `W055` — `CostsScreen` — mobile/lib/features/finance/screens/costs_screen.dart:14 — UNREVIEWED.
- `W056` — `_MoreFiltersButton` — mobile/lib/features/finance/screens/costs_screen.dart:375 — UNREVIEWED.
- `W057` — `_FilterChip` — mobile/lib/features/finance/screens/costs_screen.dart:398 — UNREVIEWED.
- `W058` — `CostDetailsScreen` — mobile/lib/features/finance/screens/cost_details_screen.dart:17 — UNREVIEWED.
- `W059` — `_CostHero` — mobile/lib/features/finance/screens/cost_details_screen.dart:346 — UNREVIEWED.
- `W060` — `_CostHeroValue` — mobile/lib/features/finance/screens/cost_details_screen.dart:437 — UNREVIEWED.
- `W061` — `_CostContextCard` — mobile/lib/features/finance/screens/cost_details_screen.dart:478 — UNREVIEWED.
- `W062` — `_InfoRow` — mobile/lib/features/finance/screens/cost_details_screen.dart:537 — UNREVIEWED.
- `W063` — `_CostPrimaryDecision` — mobile/lib/features/finance/screens/cost_details_screen.dart:603 — UNREVIEWED.
- `W064` — `_CostMoreMenu` — mobile/lib/features/finance/screens/cost_details_screen.dart:643 — UNREVIEWED.
- `W065` — `CostFormScreen` — mobile/lib/features/finance/screens/cost_form_screen.dart:31 — UNREVIEWED.
- `W066` — `_CostSaveSummary` — mobile/lib/features/finance/screens/cost_form_screen.dart:693 — UNREVIEWED.
- `W067` — `_CostSaveMetric` — mobile/lib/features/finance/screens/cost_form_screen.dart:805 — UNREVIEWED.
- `W068` — `_NoCategory` — mobile/lib/features/finance/screens/cost_form_screen.dart:840 — UNREVIEWED.
- `W069` — `_DateField` — mobile/lib/features/finance/screens/cost_form_screen.dart:864 — UNREVIEWED.
- `W070` — `_ProviderPicker` — mobile/lib/features/finance/screens/cost_form_screen.dart:900 — UNREVIEWED.
- `W071` — `RecordCostPaymentScreen` — mobile/lib/features/finance/screens/cost_payment_screens.dart:23 — UNREVIEWED.
- `W072` — `CostPaymentDetailsScreen` — mobile/lib/features/finance/screens/cost_payment_screens.dart:300 — UNREVIEWED.
- `W073` — `_PaymentLimitCard` — mobile/lib/features/finance/screens/cost_payment_screens.dart:442 — UNREVIEWED.
- `W074` — `_DateButton` — mobile/lib/features/finance/screens/cost_payment_screens.dart:476 — UNREVIEWED.
- `W075` — `_PaymentHero` — mobile/lib/features/finance/screens/cost_payment_screens.dart:497 — UNREVIEWED.
- `W076` — `_PaymentInformation` — mobile/lib/features/finance/screens/cost_payment_screens.dart:519 — UNREVIEWED.
- `W077` — `_PaymentInfoLine` — mobile/lib/features/finance/screens/cost_payment_screens.dart:552 — UNREVIEWED.
- `W078` — `_ReversalReasonDialog` — mobile/lib/features/finance/screens/cost_payment_screens.dart:591 — UNREVIEWED.
- `W079` — `MoneyBudgetScreen` — mobile/lib/features/finance/screens/money_budget_screen.dart:22 — UNREVIEWED.
- `W080` — `_AllocationSummary` — mobile/lib/features/finance/screens/money_budget_screen.dart:425 — UNREVIEWED.
- `W081` — `_AllocationValue` — mobile/lib/features/finance/screens/money_budget_screen.dart:497 — UNREVIEWED.
- `W082` — `_BudgetCategoryRow` — mobile/lib/features/finance/screens/money_budget_screen.dart:568 — UNREVIEWED.
- `W083` — `_CategoryMoneyMetric` — mobile/lib/features/finance/screens/money_budget_screen.dart:688 — UNREVIEWED.
- `W084` — `_LockedCurrencyRow` — mobile/lib/features/finance/screens/money_budget_screen.dart:730 — UNREVIEWED.
- `W085` — `MoneyOverviewScreen` — mobile/lib/features/finance/screens/money_overview_screen.dart:37 — UNREVIEWED.
- `W086` — `_MoneyRootStateList` — mobile/lib/features/finance/screens/money_overview_screen.dart:303 — UNREVIEWED.
- `W087` — `_MoneyCostsSection` — mobile/lib/features/finance/screens/money_overview_screen.dart:324 — UNREVIEWED.
- `W088` — `_MoneySnapshot` — mobile/lib/features/finance/screens/money_overview_screen.dart:417 — UNREVIEWED.
- `W089` — `_LedgerMetric` — mobile/lib/features/finance/screens/money_overview_screen.dart:587 — UNREVIEWED.
- `W090` — `_LedgerDivider` — mobile/lib/features/finance/screens/money_overview_screen.dart:634 — UNREVIEWED.
- `W091` — `_MoneySettingsMenu` — mobile/lib/features/finance/screens/money_overview_screen.dart:648 — UNREVIEWED.
- `W092` — `_MoneySettingsItem` — mobile/lib/features/finance/screens/money_overview_screen.dart:724 — UNREVIEWED.
- `W093` — `_NextPaymentCard` — mobile/lib/features/finance/screens/money_overview_screen.dart:749 — UNREVIEWED.
- `W094` — `PaymentSchedulesScreen` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:23 — UNREVIEWED.
- `W095` — `PaymentScheduleDetailsScreen` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:223 — UNREVIEWED.
- `W096` — `PaymentScheduleFormScreen` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:492 — UNREVIEWED.
- `W097` — `PayPaymentScheduleScreen` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:822 — UNREVIEWED.
- `W098` — `_ScheduleCounts` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:1056 — UNREVIEWED.
- `W099` — `_ScheduleHero` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:1095 — UNREVIEWED.
- `W100` — `_ScheduleActions` — mobile/lib/features/finance/screens/payment_schedule_screens.dart:1132 — UNREVIEWED.
- `W101` — `_MoneyCostActionPicker` — mobile/lib/features/finance/widgets/money_cost_action_picker.dart:46 — UNREVIEWED.
- `W102` — `_CostChoiceRow` — mobile/lib/features/finance/widgets/money_cost_action_picker.dart:109 — UNREVIEWED.
- `W103` — `_NoEligibleCosts` — mobile/lib/features/finance/widgets/money_cost_action_picker.dart:193 — UNREVIEWED.
- `W104` — `MoneyStarterSetup` — mobile/lib/features/finance/widgets/money_starter_setup.dart:13 — UNREVIEWED.
- `W105` — `_ToggleAllButton` — mobile/lib/features/finance/widgets/money_starter_setup.dart:317 — UNREVIEWED.
- `W106` — `_StarterIntro` — mobile/lib/features/finance/widgets/money_starter_setup.dart:342 — UNREVIEWED.
- `W107` — `_StarterGroupView` — mobile/lib/features/finance/widgets/money_starter_setup.dart:440 — UNREVIEWED.
- `W108` — `_CustomCategoryGroup` — mobile/lib/features/finance/widgets/money_starter_setup.dart:478 — UNREVIEWED.
- `W109` — `_StarterCategoryRow` — mobile/lib/features/finance/widgets/money_starter_setup.dart:517 — UNREVIEWED.
- `W110` — `_CustomCategoryComposer` — mobile/lib/features/finance/widgets/money_starter_setup.dart:647 — UNREVIEWED.
- `W111` — `_StarterActionBar` — mobile/lib/features/finance/widgets/money_starter_setup.dart:716 — UNREVIEWED.
- `W112` — `_SelectionHint` — mobile/lib/features/finance/widgets/money_starter_setup.dart:787 — UNREVIEWED.
- `W113` — `_StarterErrorLine` — mobile/lib/features/finance/widgets/money_starter_setup.dart:816 — UNREVIEWED.
- `W114` — `MoneySubpageScaffold` — mobile/lib/features/finance/widgets/money_widgets.dart:17 — UNREVIEWED.
- `W115` — `_MoneySubpageHeader` — mobile/lib/features/finance/widgets/money_widgets.dart:62 — UNREVIEWED.
- `W116` — `_MoneyHeaderButton` — mobile/lib/features/finance/widgets/money_widgets.dart:153 — UNREVIEWED.
- `W117` — `MoneySectionCard` — mobile/lib/features/finance/widgets/money_widgets.dart:188 — UNREVIEWED.
- `W118` — `MoneyDisclosureCard` — mobile/lib/features/finance/widgets/money_widgets.dart:257 — UNREVIEWED.
- `W119` — `MoneyRecordHero` — mobile/lib/features/finance/widgets/money_widgets.dart:287 — UNREVIEWED.
- `W120` — `MoneyAmountText` — mobile/lib/features/finance/widgets/money_widgets.dart:416 — UNREVIEWED.
- `W121` — `MoneyPrivacyButton` — mobile/lib/features/finance/widgets/money_widgets.dart:475 — UNREVIEWED.
- `W122` — `MoneyMetricCard` — mobile/lib/features/finance/widgets/money_widgets.dart:506 — UNREVIEWED.
- `W123` — `CostCard` — mobile/lib/features/finance/widgets/money_widgets.dart:569 — UNREVIEWED.
- `W124` — `PaymentCard` — mobile/lib/features/finance/widgets/money_widgets.dart:696 — UNREVIEWED.
- `W125` — `ScheduleCard` — mobile/lib/features/finance/widgets/money_widgets.dart:775 — UNREVIEWED.
- `W126` — `MoneyStatusBadge` — mobile/lib/features/finance/widgets/money_widgets.dart:895 — UNREVIEWED.
- `W127` — `MoneyMessageBanner` — mobile/lib/features/finance/widgets/money_widgets.dart:921 — UNREVIEWED.

### guests

- `W128` — `GuestListScreen` — mobile/lib/features/guests/screens/guest_list_screen.dart:34 — UNREVIEWED.
- `W129` — `_GuestsContent` — mobile/lib/features/guests/screens/guest_list_screen.dart:378 — UNREVIEWED.
- `W130` — `_ImportantGuestsCard` — mobile/lib/features/guests/screens/guest_list_screen.dart:549 — UNREVIEWED.
- `W131` — `_GuestListSectionHeader` — mobile/lib/features/guests/screens/guest_list_screen.dart:583 — UNREVIEWED.
- `W132` — `_GuestFilterBar` — mobile/lib/features/guests/screens/guest_list_screen.dart:613 — UNREVIEWED.
- `W133` — `_GuestLoadingState` — mobile/lib/features/guests/screens/guest_list_screen.dart:672 — UNREVIEWED.
- `W134` — `_SkeletonBox` — mobile/lib/features/guests/screens/guest_list_screen.dart:693 — UNREVIEWED.
- `W135` — `_InlineError` — mobile/lib/features/guests/screens/guest_list_screen.dart:711 — UNREVIEWED.
- `W136` — `GuestAttendanceBrief` — mobile/lib/features/guests/widgets/guest_attendance_brief.dart:8 — UNREVIEWED.
- `W137` — `_GuestMetric` — mobile/lib/features/guests/widgets/guest_attendance_brief.dart:188 — UNREVIEWED.
- `W138` — `_LocalPlanningBadge` — mobile/lib/features/guests/widgets/guest_attendance_brief.dart:228 — UNREVIEWED.
- `W139` — `GuestFormSheet` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:16 — UNREVIEWED.
- `W140` — `GuestSheetHandle` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:422 — UNREVIEWED.
- `W141` — `_GuestFormHeader` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:440 — UNREVIEWED.
- `W142` — `_CompactDecisionSurface` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:496 — UNREVIEWED.
- `W143` — `_GuestOptionalDetails` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:518 — UNREVIEWED.
- `W144` — `_ChipPickerRow` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:573 — UNREVIEWED.
- `W145` — `_CompactStepper` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:653 — UNREVIEWED.
- `W146` — `_StepperButton` — mobile/lib/features/guests/widgets/guest_form_sheet.dart:712 — UNREVIEWED.
- `W147` — `GuestListRow` — mobile/lib/features/guests/widgets/guest_list_row.dart:18 — UNREVIEWED.
- `W148` — `_GuestPrimaryAction` — mobile/lib/features/guests/widgets/guest_list_row.dart:182 — UNREVIEWED.
- `W149` — `_MetaRow` — mobile/lib/features/guests/widgets/guest_list_row.dart:214 — UNREVIEWED.
- `W150` — `_MetaItem` — mobile/lib/features/guests/widgets/guest_list_row.dart:251 — UNREVIEWED.
- `W151` — `_StatusChip` — mobile/lib/features/guests/widgets/guest_list_row.dart:280 — UNREVIEWED.
- `W152` — `_GuestMenu` — mobile/lib/features/guests/widgets/guest_list_row.dart:307 — UNREVIEWED.

### home

- `W153` — `DashboardEntryScreen` — mobile/lib/features/home/screens/dashboard_entry_screen.dart:23 — UNREVIEWED.
- `W154` — `HomeScreen` — mobile/lib/features/home/screens/home_screen.dart:13 — UNREVIEWED.
- `W155` — `LocalGuestDashboardScreen` — mobile/lib/features/home/screens/local_guest_dashboard_screen.dart:28 — UNREVIEWED.
- `W156` — `_LocalSyncNotice` — mobile/lib/features/home/screens/local_guest_dashboard_screen.dart:313 — UNREVIEWED.
- `W157` — `HomeLoadingSkeleton` — mobile/lib/features/home/widgets/home_widgets.dart:12 — UNREVIEWED.
- `W158` — `HomeErrorCard` — mobile/lib/features/home/widgets/home_widgets.dart:40 — UNREVIEWED.
- `W159` — `HomeTopHeader` — mobile/lib/features/home/widgets/home_widgets.dart:79 — UNREVIEWED.
- `W160` — `HomeNoPlanWelcome` — mobile/lib/features/home/widgets/home_widgets.dart:165 — UNREVIEWED.
- `W161` — `HomeSharedPlansCard` — mobile/lib/features/home/widgets/home_widgets.dart:363 — UNREVIEWED.
- `W162` — `_SharedPlanRow` — mobile/lib/features/home/widgets/home_widgets.dart:402 — UNREVIEWED.

### marketplace

- `W163` — `FavoriteProvidersScreen` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:18 — UNREVIEWED.
- `W164` — `_ProviderComparePicker` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:230 — UNREVIEWED.
- `W165` — `_FavoriteProvidersHero` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:267 — UNREVIEWED.
- `W166` — `_ProviderComparisonSurface` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:308 — UNREVIEWED.
- `W167` — `_ComparisonColumn` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:399 — UNREVIEWED.
- `W168` — `_ComparisonFact` — mobile/lib/features/marketplace/screens/favorite_providers_screen.dart:482 — UNREVIEWED.
- `W169` — `ProviderDetailsScreen` — mobile/lib/features/marketplace/screens/provider_details_screen.dart:21 — UNREVIEWED.
- `W170` — `_ContactIconButton` — mobile/lib/features/marketplace/screens/provider_details_screen.widgets.dart:28 — UNREVIEWED.
- `W171` — `_DetailsFrame` — mobile/lib/features/marketplace/screens/provider_details_screen.widgets.dart:56 — UNREVIEWED.
- `W172` — `ProviderMarketplaceScreen` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart:36 — UNREVIEWED.
- `W173` — `_MarketplaceSkeleton` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.labels.dart:252 — UNREVIEWED.
- `W174` — `_ErrorCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.labels.dart:268 — UNREVIEWED.
- `W175` — `_LoginRequiredCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.labels.dart:285 — UNREVIEWED.
- `W176` — `_BudgetMatchedServicesSection` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:3 — UNREVIEWED.
- `W177` — `_BudgetMatchedServiceCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:66 — UNREVIEWED.
- `W178` — `_LocationContextCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:218 — UNREVIEWED.
- `W179` — `_OffersInboxCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:273 — UNREVIEWED.
- `W180` — `_OfferQuoteTile` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:395 — UNREVIEWED.
- `W181` — `_ExpiredOfferRow` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:485 — UNREVIEWED.
- `W182` — `_CompactQuoteStatusRow` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:536 — UNREVIEWED.
- `W183` — `_OfferDecisionArea` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:630 — UNREVIEWED.
- `W184` — `_OfferAcceptedArea` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:746 — UNREVIEWED.
- `W185` — `_OfferFactCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:1050 — UNREVIEWED.
- `W186` — `_ResultsHeader` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:1099 — UNREVIEWED.
- `W187` — `_ProviderCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:1127 — UNREVIEWED.
- `W188` — `_ProviderFactPill` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.results.dart:1235 — UNREVIEWED.
- `W189` — `_TopMarketplaceCommandCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:3 — UNREVIEWED.
- `W190` — `_MarketplaceMiniMetric` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:111 — UNREVIEWED.
- `W191` — `_MarketplaceHeaderAction` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:147 — UNREVIEWED.
- `W192` — `_MarketplaceSearch` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:213 — UNREVIEWED.
- `W193` — `_FilterChips` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:256 — UNREVIEWED.
- `W194` — `_CityFilterChip` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:300 — UNREVIEWED.
- `W195` — `_NoBudgetMatchesCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:432 — UNREVIEWED.
- `W196` — `_BudgetMatchContextCard` — mobile/lib/features/marketplace/screens/provider_marketplace_screen.sections.dart:502 — UNREVIEWED.
- `W197` — `QuoteRequestScreen` — mobile/lib/features/marketplace/screens/quote_request_screen.dart:27 — UNREVIEWED.
- `W198` — `_QuoteLocationContext` — mobile/lib/features/marketplace/screens/quote_request_screen.dart:704 — UNREVIEWED.
- `W199` — `_QuoteContactContext` — mobile/lib/features/marketplace/screens/quote_request_screen.dart:778 — UNREVIEWED.
- `W200` — `_QuoteAuthRequired` — mobile/lib/features/marketplace/screens/quote_request_screen.dart:838 — UNREVIEWED.
- `W201` — `_DateField` — mobile/lib/features/marketplace/screens/quote_request_screen.dart:863 — UNREVIEWED.
- `W202` — `ProviderAuthGate` — mobile/lib/features/marketplace/widgets/provider_auth_gate.dart:14 — UNREVIEWED.
- `W203` — `_ProviderAccountRequiredGate` — mobile/lib/features/marketplace/widgets/provider_auth_gate.dart:173 — UNREVIEWED.
- `W204` — `ProviderDetailsSections` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:10 — UNREVIEWED.
- `W205` — `_SectionDivider` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:118 — UNREVIEWED.
- `W206` — `_EditorialSectionHeader` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:130 — UNREVIEWED.
- `W207` — `_AboutSection` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:186 — UNREVIEWED.
- `W208` — `_ContactDetail` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:273 — UNREVIEWED.
- `W209` — `_ServicesSection` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:311 — UNREVIEWED.
- `W210` — `_ServiceLine` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:371 — UNREVIEWED.
- `W211` — `_PackagesSection` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:452 — UNREVIEWED.
- `W212` — `_PackageBlock` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:500 — UNREVIEWED.
- `W213` — `_FeatureChip` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:574 — UNREVIEWED.
- `W214` — `_ReviewsSection` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:609 — UNREVIEWED.
- `W215` — `_ReviewLine` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:663 — UNREVIEWED.
- `W216` — `_EditorialRetry` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:719 — UNREVIEWED.
- `W217` — `_EditorialEmpty` — mobile/lib/features/marketplace/widgets/provider_details_sections.dart:772 — UNREVIEWED.
- `W218` — `ProviderDetailsView` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:11 — UNREVIEWED.
- `W219` — `_ProviderDetailsStaleWarning` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:120 — UNREVIEWED.
- `W220` — `_ProviderHero` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:188 — UNREVIEWED.
- `W221` — `_ProviderTextHero` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:230 — UNREVIEWED.
- `W222` — `_HeroLightButton` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:390 — UNREVIEWED.
- `W223` — `_ProviderMeta` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:429 — UNREVIEWED.
- `W224` — `_MetaBadge` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:477 — UNREVIEWED.
- `W225` — `_PriceBand` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:518 — UNREVIEWED.
- `W226` — `_GallerySection` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:580 — UNREVIEWED.
- `W227` — `_GalleryThumb` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:694 — UNREVIEWED.
- `W228` — `_GalleryLoadingState` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:762 — UNREVIEWED.
- `W229` — `_GalleryImageFallback` — mobile/lib/features/marketplace/widgets/provider_details_view.dart:774 — UNREVIEWED.
- `W230` — `_ProviderPhotoGallery` — mobile/lib/features/marketplace/widgets/provider_photo_gallery.dart:20 — UNREVIEWED.
- `W231` — `ProviderResultCard` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:10 — UNREVIEWED.
- `W232` — `_VendorImage` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:211 — UNREVIEWED.
- `W233` — `_VendorImagePlaceholder` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:275 — UNREVIEWED.
- `W234` — `_FeaturedBadge` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:298 — UNREVIEWED.
- `W235` — `_RatingChip` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:327 — UNREVIEWED.
- `W236` — `_LocationLabel` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:353 — UNREVIEWED.
- `W237` — `_BudgetChip` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:380 — UNREVIEWED.
- `W238` — `_FavoriteHeart` — mobile/lib/features/marketplace/widgets/provider_result_card.dart:416 — UNREVIEWED.
- `W239` — `QuoteStatusChip` — mobile/lib/features/marketplace/widgets/quote_status_chip.dart:7 — UNREVIEWED.

### more

- `W240` — `MoreScreen` — mobile/lib/features/more/screens/more_screen.dart:21 — UNREVIEWED.
- `W241` — `MoreMenuSectionTitle` — mobile/lib/features/more/widgets/more_screen_components.dart:49 — UNREVIEWED.
- `W242` — `MoreHeader` — mobile/lib/features/more/widgets/more_screen_components.dart:70 — UNREVIEWED.
- `W243` — `MoreAvatarSourceTile` — mobile/lib/features/more/widgets/more_screen_components.dart:82 — UNREVIEWED.
- `W244` — `MoreProfileCard` — mobile/lib/features/more/widgets/more_screen_components.dart:127 — UNREVIEWED.
- `W245` — `_IdentityChip` — mobile/lib/features/more/widgets/more_screen_components.dart:246 — UNREVIEWED.
- `W246` — `MoreMenuGroup` — mobile/lib/features/more/widgets/more_screen_components.dart:271 — UNREVIEWED.
- `W247` — `MoreActionTile` — mobile/lib/features/more/widgets/more_screen_components.dart:282 — UNREVIEWED.
- `W248` — `MoreDangerGroup` — mobile/lib/features/more/widgets/more_screen_components.dart:319 — UNREVIEWED.
- `W249` — `_DangerTile` — mobile/lib/features/more/widgets/more_screen_components.dart:397 — UNREVIEWED.
- `W250` — `MoreOptionalLoginTile` — mobile/lib/features/more/widgets/more_screen_components.dart:449 — UNREVIEWED.
- `W251` — `MoreVersionFooter` — mobile/lib/features/more/widgets/more_screen_components.dart:474 — UNREVIEWED.
- `W252` — `MoreSheetHandle` — mobile/lib/features/more/widgets/more_screen_components.dart:503 — UNREVIEWED.

### notifications

- `W253` — `NotificationsScreen` — mobile/lib/features/notifications/screens/notifications_screen.dart:20 — UNREVIEWED.
- `W254` — `_NotificationGroupHeader` — mobile/lib/features/notifications/screens/notifications_screen.dart:296 — UNREVIEWED.
- `W255` — `_NotificationRow` — mobile/lib/features/notifications/screens/notifications_screen.dart:317 — UNREVIEWED.
- `W256` — `_NotificationStatus` — mobile/lib/features/notifications/screens/notifications_screen.dart:371 — UNREVIEWED.

### onboarding

- `W257` — `LocalPlanMigrationScreen` — mobile/lib/features/onboarding/screens/local_plan_migration_screen.dart:17 — UNREVIEWED.
- `W258` — `_CountChip` — mobile/lib/features/onboarding/screens/local_plan_migration_screen.dart:338 — UNREVIEWED.
- `W259` — `LocationPickerSection` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:10 — UNREVIEWED.
- `W260` — `_LocationGuidance` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:183 — UNREVIEWED.
- `W261` — `_AreaAndNeighborhoodFields` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:212 — UNREVIEWED.
- `W262` — `_LocationCatalogError` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:278 — UNREVIEWED.
- `W263` — `_LocationField` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:307 — UNREVIEWED.
- `W264` — `_LocationSelect` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:339 — UNREVIEWED.
- `W265` — `_LocationPickerSheet` — mobile/lib/features/onboarding/widgets/location_picker_section.dart:468 — UNREVIEWED.

### provider_portal

- `W266` — `AddProviderPackageScreen` — mobile/lib/features/provider_portal/screens/add_provider_package_screen.dart:19 — UNREVIEWED.
- `W267` — `_InlineError` — mobile/lib/features/provider_portal/screens/add_provider_package_screen.dart:285 — UNREVIEWED.
- `W268` — `AddProviderServiceScreen` — mobile/lib/features/provider_portal/screens/add_provider_service_screen.dart:21 — UNREVIEWED.
- `W269` — `_InlineError` — mobile/lib/features/provider_portal/screens/add_provider_service_screen.dart:312 — UNREVIEWED.
- `W270` — `EditProviderProfileScreen` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:24 — UNREVIEWED.
- `W271` — `_ProfileEditNotice` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:290 — UNREVIEWED.
- `W272` — `_LockedCategoryNote` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:321 — UNREVIEWED.
- `W273` — `_ReferenceDataWarning` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:351 — UNREVIEWED.
- `W274` — `_InlineError` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:367 — UNREVIEWED.
- `W275` — `_ProfileDropdown` — mobile/lib/features/provider_portal/screens/edit_provider_profile_screen.dart:389 — UNREVIEWED.
- `W276` — `ProviderApplyScreen` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:26 — UNREVIEWED.
- `W277` — `ProviderApplyStatusScreen` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:306 — UNREVIEWED.
- `W278` — `_AuthRequiredCard` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:336 — UNREVIEWED.
- `W279` — `_AlreadyProviderCard` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:373 — UNREVIEWED.
- `W280` — `_ReferenceDataWarning` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:396 — UNREVIEWED.
- `W281` — `_ProviderReviewNote` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:412 — UNREVIEWED.
- `W282` — `_InlineError` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:440 — UNREVIEWED.
- `W283` — `_ApplyDropdown` — mobile/lib/features/provider_portal/screens/provider_apply_screen.dart:462 — UNREVIEWED.
- `W284` — `ProviderPackageManagementCard` — mobile/lib/features/provider_portal/screens/provider_catalog_management_widgets.dart:15 — UNREVIEWED.
- `W285` — `ProviderHomeTab` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:18 — UNREVIEWED.
- `W286` — `_ProviderLifecycleNotice` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:99 — UNREVIEWED.
- `W287` — `_ProviderIdentityHero` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:166 — UNREVIEWED.
- `W288` — `_ProviderMetrics` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:280 — UNREVIEWED.
- `W289` — `_QuickActions` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:354 — UNREVIEWED.
- `W290` — `_QuoteSummaryTile` — mobile/lib/features/provider_portal/screens/provider_home_tab.dart:383 — UNREVIEWED.
- `W291` — `ProviderPortalScreen` — mobile/lib/features/provider_portal/screens/provider_portal_screen.dart:14 — UNREVIEWED.
- `W292` — `_ProviderOperationsUnavailable` — mobile/lib/features/provider_portal/screens/provider_portal_screen.dart:101 — UNREVIEWED.
- `W293` — `ProviderProfileTab` — mobile/lib/features/provider_portal/screens/provider_profile_tab.dart:25 — UNREVIEWED.
- `W294` — `_ProviderReviewsSection` — mobile/lib/features/provider_portal/screens/provider_profile_tab.dart:201 — UNREVIEWED.
- `W295` — `_ProfileMediaCard` — mobile/lib/features/provider_portal/screens/provider_profile_tab.dart:272 — UNREVIEWED.
- `W296` — `_PortfolioGallery` — mobile/lib/features/provider_portal/screens/provider_profile_tab.dart:362 — UNREVIEWED.
- `W297` — `ProviderRequestsTab` — mobile/lib/features/provider_portal/screens/provider_requests_tab.dart:18 — UNREVIEWED.
- `W298` — `_ProviderRequestCard` — mobile/lib/features/provider_portal/screens/provider_requests_tab.dart:124 — UNREVIEWED.
- `W299` — `ProviderServicesTab` — mobile/lib/features/provider_portal/screens/provider_services_tab.dart:26 — UNREVIEWED.
- `W300` — `_ServiceManagementCard` — mobile/lib/features/provider_portal/screens/provider_services_tab.dart:319 — UNREVIEWED.
- `W301` — `ProviderAccountActions` — mobile/lib/features/provider_portal/widgets/provider_account_actions.dart:8 — UNREVIEWED.
- `W302` — `_ProviderAccountTile` — mobile/lib/features/provider_portal/widgets/provider_account_actions.dart:359 — UNREVIEWED.
- `W303` — `ProviderPortalBottomNav` — mobile/lib/features/provider_portal/widgets/provider_portal_bottom_nav.dart:9 — UNREVIEWED.

### settings

- `W304` — `SettingsScreen` — mobile/lib/features/settings/screens/settings_screen.dart:15 — UNREVIEWED.
- `W305` — `_AccountCard` — mobile/lib/features/settings/screens/settings_screen.dart:151 — UNREVIEWED.
- `W306` — `_NotificationSettingsCard` — mobile/lib/features/settings/screens/settings_screen.dart:200 — UNREVIEWED.
- `W307` — `_DeliveryStatusRow` — mobile/lib/features/settings/screens/settings_screen.dart:277 — UNREVIEWED.
- `W308` — `_StaticPreferencesCard` — mobile/lib/features/settings/screens/settings_screen.dart:318 — UNREVIEWED.
- `W309` — `_SwitchRow` — mobile/lib/features/settings/screens/settings_screen.dart:342 — UNREVIEWED.
- `W310` — `_MessageCard` — mobile/lib/features/settings/screens/settings_screen.dart:382 — UNREVIEWED.

### sharing

- `W311` — `AddSharedMemberScreen` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:28 — UNREVIEWED.
- `W312` — `_InviteCreatedView` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:602 — UNREVIEWED.
- `W313` — `_LookupButton` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:752 — UNREVIEWED.
- `W314` — `_FoundUserStrip` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:791 — UNREVIEWED.
- `W315` — `_LookupAvatar` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:851 — UNREVIEWED.
- `W316` — `_LookupEmpty` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:888 — UNREVIEWED.
- `W317` — `_InlineError` — mobile/lib/features/sharing/screens/add_shared_member_screen.dart:921 — UNREVIEWED.
- `W318` — `ContributionHistoryScreen` — mobile/lib/features/sharing/screens/contribution_history_screen.dart:10 — UNREVIEWED.
- `W319` — `_HistoryPaginationControl` — mobile/lib/features/sharing/screens/contribution_history_screen.dart:112 — UNREVIEWED.
- `W320` — `_CoverageNotice` — mobile/lib/features/sharing/screens/contribution_history_screen.dart:160 — UNREVIEWED.
- `W321` — `_ContributionEventCard` — mobile/lib/features/sharing/screens/contribution_history_screen.dart:186 — UNREVIEWED.
- `W322` — `EditSharedMemberScreen` — mobile/lib/features/sharing/screens/edit_shared_member_screen.dart:21 — UNREVIEWED.
- `W323` — `InviteDecisionScreen` — mobile/lib/features/sharing/screens/invite_decision_screen.dart:28 — UNREVIEWED.
- `W324` — `_InviteDetails` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:3 — UNREVIEWED.
- `W325` — `_InvitePlanHero` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:79 — UNREVIEWED.
- `W326` — `_InviteJoinedHero` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:158 — UNREVIEWED.
- `W327` — `_EndedMembershipHero` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:214 — UNREVIEWED.
- `W328` — `_InvitePermissionsCard` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:230 — UNREVIEWED.
- `W329` — `_WeddingRingsMark` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:357 — UNREVIEWED.
- `W330` — `_PermissionTile` — mobile/lib/features/sharing/screens/invite_decision_screen.details.dart:404 — UNREVIEWED.
- `W331` — `_InviteListCard` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:3 — UNREVIEWED.
- `W332` — `_NoInviteState` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:64 — UNREVIEWED.
- `W333` — `_InviteAccountSetupNotice` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:107 — UNREVIEWED.
- `W334` — `_InviteNotice` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:153 — UNREVIEWED.
- `W335` — `_FieldLabel` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:202 — UNREVIEWED.
- `W336` — `_InlineError` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:222 — UNREVIEWED.
- `W337` — `_ClosedInviteStatus` — mobile/lib/features/sharing/screens/invite_decision_screen.notices.dart:248 — UNREVIEWED.
- `W338` — `_PhoneStep` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:3 — UNREVIEWED.
- `W339` — `_InviteJourneyProgress` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:63 — UNREVIEWED.
- `W340` — `_InviteJourneyMarker` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:112 — UNREVIEWED.
- `W341` — `_InviteWelcomeHero` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:182 — UNREVIEWED.
- `W342` — `_PrivacyLine` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:250 — UNREVIEWED.
- `W343` — `_AccountSetupStep` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:275 — UNREVIEWED.
- `W344` — `_OtpStep` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:374 — UNREVIEWED.
- `W345` — `_InvitesStep` — mobile/lib/features/sharing/screens/invite_decision_screen.steps.dart:520 — UNREVIEWED.
- `W346` — `SharedWeddingPlansScreen` — mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart:17 — UNREVIEWED.
- `W347` — `_SharedPlansContent` — mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart:84 — UNREVIEWED.
- `W348` — `SharingScreen` — mobile/lib/features/sharing/screens/sharing_screen.dart:20 — UNREVIEWED.
- `W349` — `_SharingContent` — mobile/lib/features/sharing/screens/sharing_screen.dart:299 — UNREVIEWED.
- `W350` — `_SectionTitle` — mobile/lib/features/sharing/screens/sharing_screen.dart:472 — UNREVIEWED.
- `W351` — `_PrivacyStrip` — mobile/lib/features/sharing/screens/sharing_screen.dart:492 — UNREVIEWED.
- `W352` — `_PendingInviteCard` — mobile/lib/features/sharing/screens/sharing_screen.dart:522 — UNREVIEWED.
- `W353` — `SharedPermissionEditor` — mobile/lib/features/sharing/widgets/permission_editor.dart:11 — UNREVIEWED.
- `W354` — `_GroupLabel` — mobile/lib/features/sharing/widgets/permission_editor.dart:222 — UNREVIEWED.
- `W355` — `_PermissionRow` — mobile/lib/features/sharing/widgets/permission_editor.dart:243 — UNREVIEWED.
- `W356` — `_RoleChip` — mobile/lib/features/sharing/widgets/permission_editor.dart:301 — UNREVIEWED.
- `W357` — `SharedMemberCard` — mobile/lib/features/sharing/widgets/shared_member_card.dart:11 — UNREVIEWED.
- `W358` — `SharedPlanCard` — mobile/lib/features/sharing/widgets/shared_plan_card.dart:13 — UNREVIEWED.

### shell

- `W359` — `MainShell` — mobile/lib/features/shell/main_shell.dart:39 — UNREVIEWED.
- `W360` — `_OwnerMainShell` — mobile/lib/features/shell/main_shell.dart:68 — UNREVIEWED.
- `W361` — `_ContributorMainShell` — mobile/lib/features/shell/main_shell.dart:376 — UNREVIEWED.
- `W362` — `_InvalidShellContext` — mobile/lib/features/shell/main_shell.dart:444 — UNREVIEWED.
- `W363` — `WeddingPlanShell` — mobile/lib/features/shell/screens/wedding_plan_shell.dart:35 — UNREVIEWED.
- `W364` — `_LocalPlanSummaryBridge` — mobile/lib/features/shell/screens/wedding_plan_shell.dart:324 — UNREVIEWED.
- `W365` — `AarastQuickActionSheet` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:77 — UNREVIEWED.
- `W366` — `AarastPlanNavigationBar` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:170 — UNREVIEWED.
- `W367` — `AarastPlanContextBar` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:245 — UNREVIEWED.
- `W368` — `AarastQuickActionButton` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:325 — UNREVIEWED.
- `W369` — `_QuickActionRow` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:394 — UNREVIEWED.
- `W370` — `_PlanNavigationItem` — mobile/lib/features/shell/widgets/aarast_plan_chrome.dart:490 — UNREVIEWED.
- `W371` — `PlanShellChrome` — mobile/lib/features/shell/widgets/plan_shell_chrome.dart:9 — UNREVIEWED.

### support

- `W372` — `SupportScreen` — mobile/lib/features/support/screens/support_screen.dart:14 — UNREVIEWED.
- `W373` — `_DiagnosticReportCard` — mobile/lib/features/support/screens/support_screen.dart:73 — UNREVIEWED.
- `W374` — `_QuickHelpCard` — mobile/lib/features/support/screens/support_screen.dart:206 — UNREVIEWED.
- `W375` — `_HelpTile` — mobile/lib/features/support/screens/support_screen.dart:263 — UNREVIEWED.
- `W376` — `_SafetyStrip` — mobile/lib/features/support/screens/support_screen.dart:301 — UNREVIEWED.
- `W377` — `_SupportLinkRow` — mobile/lib/features/support/screens/support_screen.dart:333 — UNREVIEWED.
- `W378` — `_SupportBoundaryCard` — mobile/lib/features/support/screens/support_screen.dart:404 — UNREVIEWED.
- `W379` — `_BoundaryLine` — mobile/lib/features/support/screens/support_screen.dart:452 — UNREVIEWED.

### tasks

- `W380` — `CreateTaskScreen` — mobile/lib/features/tasks/screens/create_task_screen.dart:27 — UNREVIEWED.
- `W381` — `TaskTimelineScreen` — mobile/lib/features/tasks/screens/task_timeline_screen.dart:33 — UNREVIEWED.
- `W382` — `_TaskTimelineContent` — mobile/lib/features/tasks/screens/task_timeline_screen.dart:125 — UNREVIEWED.
- `W383` — `_TaskFilterChips` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:4 — UNREVIEWED.
- `W384` — `_TaskFilterPill` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:43 — UNREVIEWED.
- `W385` — `_GroupedTimeline` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:121 — UNREVIEWED.
- `W386` — `_ImportantNowHeader` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:232 — UNREVIEWED.
- `W387` — `_TimelineGroupHeader` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:269 — UNREVIEWED.
- `W388` — `_CompletedToggleCard` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:305 — UNREVIEWED.
- `W389` — `_EmptyTasksCard` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:370 — UNREVIEWED.
- `W390` — `_TimelineLoadingState` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:405 — UNREVIEWED.
- `W391` — `_SkeletonBox` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:428 — UNREVIEWED.
- `W392` — `_InlineError` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:451 — UNREVIEWED.
- `W393` — `_SheetHandle` — mobile/lib/features/tasks/screens/task_timeline_screen.timeline.dart:484 — UNREVIEWED.
- `W394` — `CreateTaskDetailsDisclosure` — mobile/lib/features/tasks/widgets/create_task_components.dart:15 — UNREVIEWED.
- `W395` — `CreateTaskResponsibleSection` — mobile/lib/features/tasks/widgets/create_task_components.dart:39 — UNREVIEWED.
- `W396` — `CreateTaskParticipantRow` — mobile/lib/features/tasks/widgets/create_task_components.dart:163 — UNREVIEWED.
- `W397` — `CreateTaskParticipantBadge` — mobile/lib/features/tasks/widgets/create_task_components.dart:242 — UNREVIEWED.
- `W398` — `CreateTaskSelectorField` — mobile/lib/features/tasks/widgets/create_task_components.dart:277 — UNREVIEWED.
- `W399` — `CreateTaskPriorityChip` — mobile/lib/features/tasks/widgets/create_task_components.dart:349 — UNREVIEWED.
- `W400` — `CreateTaskCategoryRow` — mobile/lib/features/tasks/widgets/create_task_components.dart:406 — UNREVIEWED.
- `W401` — `CreateTaskSheetHandle` — mobile/lib/features/tasks/widgets/create_task_components.dart:449 — UNREVIEWED.
- `W402` — `TasksProgressBrief` — mobile/lib/features/tasks/widgets/tasks_progress_brief.dart:9 — UNREVIEWED.
- `W403` — `_TaskMetric` — mobile/lib/features/tasks/widgets/tasks_progress_brief.dart:154 — UNREVIEWED.
- `W404` — `_LocalPlanBadge` — mobile/lib/features/tasks/widgets/tasks_progress_brief.dart:194 — UNREVIEWED.
- `W405` — `TaskListRow` — mobile/lib/features/tasks/widgets/task_list_row.dart:14 — UNREVIEWED.
- `W406` — `_MetaRow` — mobile/lib/features/tasks/widgets/task_list_row.dart:166 — UNREVIEWED.
- `W407` — `_DueChip` — mobile/lib/features/tasks/widgets/task_list_row.dart:271 — UNREVIEWED.
- `W408` — `_CompletionBurst` — mobile/lib/features/tasks/widgets/task_list_row.dart:310 — UNREVIEWED.
- `W409` — `_TaskMenu` — mobile/lib/features/tasks/widgets/task_list_row.dart:363 — UNREVIEWED.

### wedding_day

- `W410` — `WeddingDayModeScreen` — mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart:21 — UNREVIEWED.
- `W411` — `_MissingSummaryState` — mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart:256 — UNREVIEWED.
- `W412` — `WeddingDayModeView` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:13 — UNREVIEWED.
- `W413` — `_WeddingDayHeader` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:210 — UNREVIEWED.
- `W414` — `_HeaderDetail` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:293 — UNREVIEWED.
- `W415` — `_WeddingDayTaskRow` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:318 — UNREVIEWED.
- `W416` — `_SectionHeading` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:354 — UNREVIEWED.
- `W417` — `_CalmEmpty` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:384 — UNREVIEWED.
- `W418` — `_UnavailableMessage` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:424 — UNREVIEWED.
- `W419` — `_InlineNotice` — mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart:438 — UNREVIEWED.

### wedding_plans

- `W420` — `CreateWeddingPlanScreen` — mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart:22 — UNREVIEWED.
- `W421` — `_SheetHandle` — mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart:318 — UNREVIEWED.
- `W422` — `MyWeddingPlansScreen` — mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart:19 — UNREVIEWED.
- `W423` — `_PlansContent` — mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart:104 — UNREVIEWED.
- `W424` — `_SharedPlansLink` — mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart:170 — UNREVIEWED.
- `W425` — `_PlanCard` — mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart:221 — UNREVIEWED.
- `W426` — `_ContributorLeavePlanConfirmation` — mobile/lib/features/wedding_plans/screens/plan_management_screen.contributor_account.dart:403 — UNREVIEWED.
- `W427` — `_ContributorAccountActionTile` — mobile/lib/features/wedding_plans/screens/plan_management_screen.contributor_account.dart:521 — UNREVIEWED.
- `W428` — `PlanCenterScreen` — mobile/lib/features/wedding_plans/screens/plan_management_screen.dart:36 — UNREVIEWED.
- `W429` — `_ManagementLoadError` — mobile/lib/features/wedding_plans/screens/plan_management_screen.dart:442 — UNREVIEWED.
- `W430` — `_PlanEditSheet` — mobile/lib/features/wedding_plans/screens/plan_management_screen.plan_edit.dart:157 — UNREVIEWED.
- `W431` — `WeddingPlanDashboardScreen` — mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart:23 — UNREVIEWED.
- `W432` — `ContributorWorkspaceView` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.dart:38 — UNREVIEWED.
- `W433` — `_ContributorHistoryCard` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:3 — UNREVIEWED.
- `W434` — `_ContributorRoleStrip` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:63 — UNREVIEWED.
- `W435` — `_ContributorPlanHero` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:103 — UNREVIEWED.
- `W436` — `_HeroMeta` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:178 — UNREVIEWED.
- `W437` — `_ContributorNextActionCard` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:208 — UNREVIEWED.
- `W438` — `_ContributorSectionHeader` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:285 — UNREVIEWED.
- `W439` — `_ContributorSectionsPanel` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:382 — UNREVIEWED.
- `W440` — `_ContributorSectionRow` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.sections.dart:451 — UNREVIEWED.
- `W441` — `_ContributorUpdatesCard` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.updates.dart:3 — UNREVIEWED.
- `W442` — `_ContributorUpdateRow` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.updates.dart:107 — UNREVIEWED.
- `W443` — `_ContributorPermissionsCard` — mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.updates.dart:174 — UNREVIEWED.
- `W444` — `_DashboardMoneyCard` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:3 — UNREVIEWED.
- `W445` — `_DashboardMoneyHeader` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:119 — UNREVIEWED.
- `W446` — `_DashboardMoneyOverview` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:207 — UNREVIEWED.
- `W447` — `_DashboardMoneyFigure` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:340 — UNREVIEWED.
- `W448` — `_DashboardAnimatedAmount` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:385 — UNREVIEWED.
- `W449` — `_DashboardUnsetBudgetSummary` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:413 — UNREVIEWED.
- `W450` — `_DashboardPaymentAttention` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_money_card.dart:470 — UNREVIEWED.
- `W451` — `_DashboardMobileMosaic` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_mosaic.dart:3 — UNREVIEWED.
- `W452` — `_DashboardFocusCard` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_mosaic.dart:55 — UNREVIEWED.
- `W453` — `_DashboardSignalStrip` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_mosaic.dart:189 — UNREVIEWED.
- `W454` — `_DashboardSignalCard` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_mosaic.dart:299 — UNREVIEWED.
- `W455` — `_FocusPanel` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:3 — UNREVIEWED.
- `W456` — `_PlanPulse` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:28 — UNREVIEWED.
- `W457` — `_PlanSignalRow` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:90 — UNREVIEWED.
- `W458` — `_MoneySection` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:176 — UNREVIEWED.
- `W459` — `_SetupSection` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:332 — UNREVIEWED.
- `W460` — `_SharingSection` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:421 — UNREVIEWED.
- `W461` — `_SetupRow` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:486 — UNREVIEWED.
- `W462` — `_UnsetBudget` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_sections.dart:543 — UNREVIEWED.
- `W463` — `AarastDashboardSkeleton` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_states.dart:3 — UNREVIEWED.
- `W464` — `AarastDashboardState` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_states.dart:39 — UNREVIEWED.
- `W465` — `_SkeletonLine` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_states.dart:140 — UNREVIEWED.
- `W466` — `_DashboardTeamStrip` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_support.dart:3 — UNREVIEWED.
- `W467` — `_LocalStateBadge` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_support.dart:94 — UNREVIEWED.
- `W468` — `_SectionAction` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_support.dart:119 — UNREVIEWED.
- `W469` — `_MoneyMetric` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_support.dart:138 — UNREVIEWED.
- `W470` — `AarastDashboardView` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart:24 — UNREVIEWED.
- `W471` — `_DashboardHeader` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart:243 — UNREVIEWED.
- `W472` — `_PlanMoment` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart:334 — UNREVIEWED.
- `W473` — `_WeddingDayEntry` — mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart:508 — UNREVIEWED.
- `W474` — `PlanManagementView` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:10 — UNREVIEWED.
- `W475` — `_ManagementHeader` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:153 — UNREVIEWED.
- `W476` — `_PlanIdentityCard` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:198 — UNREVIEWED.
- `W477` — `_LocationSection` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:256 — UNREVIEWED.
- `W478` — `_PreferencesSection` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:302 — UNREVIEWED.
- `W479` — `_CompletenessSection` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:347 — UNREVIEWED.
- `W480` — `_DangerSection` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:407 — UNREVIEWED.
- `W481` — `_SectionCard` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:445 — UNREVIEWED.
- `W482` — `_DataRow` — mobile/lib/features/wedding_plans/widgets/plan_management_view.dart:488 — UNREVIEWED.
- `W483` — `WeddingPlanCreationScope` — mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart:15 — UNREVIEWED.
- `W484` — `WeddingPlanCreationFields` — mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart:31 — UNREVIEWED.
- `W485` — `_PlanDecisionField` — mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart:158 — UNREVIEWED.
- `W486` — `_PlanBudgetFields` — mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart:241 — UNREVIEWED.
- `W487` — `_PlanCreationError` — mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart:312 — UNREVIEWED.
- `W488` — `WeddingStageContextLine` — mobile/lib/features/wedding_plans/widgets/wedding_stage_context_line.dart:8 — UNREVIEWED.

### welcome_gateway

- `W489` — `SmartWelcomeScreen` — mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart:32 — UNREVIEWED.
- `W490` — `_WelcomeHero` — mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart:519 — UNREVIEWED.
- `W491` — `_WelcomeBackButton` — mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart:592 — UNREVIEWED.
- `W492` — `_WelcomeStepDots` — mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart:610 — UNREVIEWED.
- `W493` — `_LoginPrompt` — mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart:675 — UNREVIEWED.
- `W494` — `AarastPathCard` — mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart:15 — UNREVIEWED.
- `W495` — `_PathTrailing` — mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart:171 — UNREVIEWED.

## Admin page candidates

- `A01` — admin-web/src/features/audit/AuditLogsPage.tsx — UNREVIEWED.
- `A02` — admin-web/src/features/auth/LoginPage.tsx — UNREVIEWED.
- `A03` — admin-web/src/features/catalog/AdministrativeAreasPage.tsx — UNREVIEWED.
- `A04` — admin-web/src/features/catalog/CategoriesPage.tsx — UNREVIEWED.
- `A05` — admin-web/src/features/catalog/CitiesPage.tsx — UNREVIEWED.
- `A06` — admin-web/src/features/catalog/ReferenceCatalogsPage.tsx — UNREVIEWED.
- `A07` — admin-web/src/features/catalog/ServicesPage.tsx — UNREVIEWED.
- `A08` — admin-web/src/features/dashboard/DashboardPage.tsx — UNREVIEWED.
- `A09` — admin-web/src/features/dashboard/ReportsPage.tsx — UNREVIEWED.
- `A10` — admin-web/src/features/moderation/ConversationReportsPage.tsx — UNREVIEWED.
- `A11` — admin-web/src/features/moderation/ReviewsPage.tsx — UNREVIEWED.
- `A12` — admin-web/src/features/notifications/NotificationsPage.tsx — UNREVIEWED.
- `A13` — admin-web/src/features/providers/ProviderApplicationDetailsPage.tsx — UNREVIEWED.
- `A14` — admin-web/src/features/providers/ProviderApplicationsPage.tsx — UNREVIEWED.
- `A15` — admin-web/src/features/providers/ProviderDetailsPage.tsx — UNREVIEWED.
- `A16` — admin-web/src/features/providers/ProvidersPage.tsx — UNREVIEWED.
- `A17` — admin-web/src/features/users/UserDetailsPage.tsx — UNREVIEWED.
- `A18` — admin-web/src/features/users/UsersPage.tsx — UNREVIEWED.

## First semantic review batch — source, not full acceptance

These rows classify20 meaningful surfaces, not the complete495 declaration backlog. Source pointers remain in the candidate list and03-findings/02-journeys. Each row needs its applicable child controls and runtime states expanded.

| ID | Surface and purpose | Data/authority and behavior traced | Assessment / next proof |
| --- | --- | --- | --- |
| S01 | Welcome path cards: plan/invite/provider | Session/local entry; choice does not grant a role | Useful distinct jobs; resume/back/device pending |
| S02 | Basic plan setup | Persona/name/location/date/currency; local versus authenticated branch, validation/error | SOURCE REVIEWED; unknown wedding date is a product question, not an approved missing requirement |
| S03 | Local plan migration | Snapshot counts; server response before local clearing; upload/error/discard confirmation |3 mapping/scoping tests PASS; retry/live import NOT PROVEN |
| S04 | Context entry | Controller/contextKey; loading/error/no paths/selection/resume |8 gate tests PASS; not a live authorization verdict |
| S05 | Owner shell | Selected owner plan; five tabs, lazy instances and quick-add | Back/context/long-press combinations pending |
| S06 | Contributor workspace | Current context rights intersect dashboard rights; separate sections/account/history | SOURCE and previous DEVICE evidence; full permission matrix pending |
| S07 | Money starter | Loaded money+canManageMoney+no budget/rows; manual or category setup | Existing harness covers selected atomic setup; contributor copy decision pending |
| S08 | Money snapshot | Canonical summary+amountsHidden; budget/schedules destinations | Selected320/1.3 flows PASS; full semantics/API comparison pending |
| S09 | Next payment reminder | schedule/currency, not actual payment; details or record-payment | F02 unmasked path; not proof of authorization leak |
| S10 | Tasks signal | remaining=total-completed; overdue count; detail changes at0 | Formula correct; wording Q01; actual user interpretation pending |
| S11 | Dashboard next step | Backend importantItems, then deterministic summary/permission rules | Context-sensitive intent exists; live item/action effect pending |
| S12 | Provider portal | status/capabilities; Active operations versus lifecycle notices | Appropriate operations guard in source; do not approve to mask UX |
| S13 | Public profile preview | Own profile id goes to public Active-only endpoint; quote footer separate | F03; needs state-appropriate action, not Pending publicity |
| S14 | Contributor rights sheet | Current flags displayed; non-scroll sheet/close action | F04; prior physical clipping; other sizes pending |
| S15 | Plan edit | Draft payload versus DTO whitelist | F01; currency semantics need preserving, not broadening DTO |
| S16 | Notifications | Account/plan suppression; unread/loading/error/empty/grouping/read action | Full route/account isolation and real Push pending |
| S17 | Settings | Auth account gate+draft/loading/error/devicePush availability | Persistence/permission/restart pending |
| S18 | Diagnostic support | Availability disables send; confirmation before sending | Honest disabled state; consent/redaction/send failure not executed |
| S19 | Contributor history | Frozen events/coverage; loading/error/empty/pagination | No real contribution created in this phase |
| S20 | Guest save feedback | Provider response; plan-scoped draft clears only on success; next-add/error | Retry/offline/duplicate/permission cases pending |

Remaining declarations and states retain UNREVIEWED; these rows do not justify declaring Task2 complete.

## Second semantic batch — controls and handoffs

SOURCE REVIEWED means the listed slice was traced; each row retains device/API proof separately. These20 rows bring the semantic register to40 slices, not40 complete screens or495 reviewed widgets.

| ID | Job / controls | Data, visibility and states | Effect / next actor | Source and proof |
| --- | --- | --- | --- | --- |
| S21 | Login: phone/password, reveal password, login, OTP alternative, recovery, register | Yemeni phone normalization; form validation; auth.isSubmitting/error; safe local resume | Password-auth or requested LOGIN OTP; no session from an unverified account response | auth/screens/login_screen.dart:91–139; current auth tests, device pending |
| S22 | Register: customer/provider, name, phone, password; provider city/category/optional description | Reference loading/error/retry; validated required fields; pending registration is in memory | startRegistration first; OTP proof then account; provider application after session, partial failure explicitly shown | register_screen.dart:249–289; otp_screen.dart:140–199; no real registration performed |
| S23 | OTP: code field, verify, resend cooldown, recovery actions/back | Confirmed delivery only for DELIVERED; uncertain text differs; local-dev fixture isolated from real proof | Purpose-specific verification; retry clears field only after a request result; account switch generation guarded | auth_otp.dart:40–61; otp_screen.dart:102–199; selected tests PASS, real OTP not sent |
| S24 | Password recovery: phone then code/new password/confirmation, resend, done/login | Form and code validation, submission/error, account-not-found after proof | Backend confirm before done; new session is not assumed from password reset | reset_password_screen.dart:350–451; current source slice; device/server pending |
| S25 | Private invitation: phone/account setup/code, rights, accept/decline/open | Token-bound recipient proof; pending vs active/ended membership; no stale-account resolve; decline confirmation | Explicit acceptance, then select exact plan contributor context; never duplicate auto-accept | invite_decision_screen.dart:70–83/:288–374; selected invite tests PASS |
| S26 | Tasks: progress, filters, completed toggle, grouped list, row/check/menu/swipe | Plan-filtered data; load/error vs stale inline error; tasks route requires manageTasks; late/done/cancelled logic | create/edit/assign/complete/reopen/delete, summary pulse; next responsible person sees server assignment | task_timeline_screen.dart:175–350; provider:295–319; F05; selected tests PASS do not cover partial save |
| S27 | Task form: title, category, date, priority, manual/member/self responsibility, save | Scoped draft; local/cloud distinction; save busy/error; responsibility payload separate from existing task patch | Create or edit; edit+assignment may partially save; draft clears only on result | create_task_screen.dart:461–560; task_timeline_provider.dart; F05 |
| S28 | Guests: attendance brief, filters, row actions, add/edit sheet, status/delete confirmation | guests route requires manageGuests; empty/loading/error; phone duplicate policy differs for local exploration; groups/seats/status | Save then scoped draft clear/pulse/add-next; cancel sheet leaves unsaved input policy | guest_list_screen.dart:147–217/:330–440; guest_form_sheet tests PASS; no real guest written |
| S29 | Quote form: service/date/area/guests/budget/message/draft/save | Selected plan required at submission; account gate; request contacts from current account; clear error/reference retry | createQuoteRequest with exact selected plan; returned plan checked, then plan-provider destination | quote_request_screen.dart:593–655; no current server quote |
| S30 | Provider requests: ALL/NEW/OFFERED/CLOSED, request cards, conversation/offer | lifecycleStatus maps SENT/VIEWED→PENDING_PROVIDER, RESPONDED→RECEIVED; pending offer controls edit | Provider sends/updates pending offer; requester is next decision maker | provider_requests_tab.dart:37–137; quote-lifecycle.ts; full live handoff pending |
| S31 | Pending versus accepted offer updates | Server re-reads under locks; updates require offer PENDING and request RESPONDED | Pending offer can change; accepted offer cannot use this mutation | provider-dashboard.service.ts:929–963; revision history is not implied; DB proof pending |
| S32 | Provider review: create/edit/delete/rating | Active provider, not own provider, one review per user/provider; edit/delete owns review | Review mutation and published aggregate; no completed-engagement eligibility check in this path | marketplace.service.ts:635–709; later proposal, not missing current requirement |
| S33 | Scoped conversation: header/history/messages/system events/older/image/composer/report/block | Load error with retry differs from empty; blocked/provider-not-joined/canSend conditions; private image refresh | Send preserves failure, read receipt/timeline; quote event goes to relation context | chat_screen.dart:57–153; chat reliability tests PASS; no real send/read |
| S34 | Provider profile/gallery/logo/cover/account actions | Profile displayed for lifecycle states; service-image gallery message unconditional; operations-only reviews; public preview unguarded | Profile/media changes, preview, sync/context exit/logout/delete-account are separate | provider_profile_tab.dart:35–193/:362–383; F03/Q02; no upload/delete |
| S35 | Wedding Day: priority tasks, contacts, providers, quick destinations | Real due/priority/window selection; cached summary and stale notice; route viewPlan; fresh task read without rights returns[] | Quick destinations unconditional; completion callback unguarded if a task is present with rights false (component proof), not proof of a fresh read-only journey | wedding_day_mode_screen.dart:134–236; view:100–190/:340; F06 corrected after independent review; live stale/revoked proof pending |
| S36 | Admin provider decision actions | PROVIDERS_WRITE plus state-specific approve/changes/reject/suspend/reactivate; note on changes/reject/suspend | Confirmation then API then refresh; provider learns lifecycle decision through existing channels | providerHelpers.tsx:24–150; lifecycle/RBAC tests PASS; no real admin decision |
| S37 | Admin users/provider/reviews/report lists | Global pagination.total differs from counts explicitly labelled in-page; search/status/filter/loading/error/empty | Open details; permission-gated mutations, no access proven from sidebar hiding alone | UsersPage/ProvidersPage/ReviewsPage/ConversationReportsPage;24 selected tests PASS |
| S38 | Admin operational report/audit | DB operational source/generatedAt; audit ATTEMPT→SUCCEEDED/FAILED; no private plan ledger in report slice | Read overview and history; no editing of audit events in this page | ReportsPage.tsx:18–108; AuditLogsPage.tsx:126–160; direct API/runtime pending |
| S39 | Notification routing/token registration | Safe internal route policy; payment/quote metadata; Firebase availability/authorization/session generation; notification tap opens feed | Feed decision then context guard; registration binds installation to current account | notification_route_policy.dart; push_notifications_controller.dart:43–118; selected isolation/route tests PASS; actual Push pending |
| S40 | Public invite fallback |43-character token format, invalid button disabled; valid custom-scheme href; no invite details fetched in JS | Browser→installed app, else explanatory page; does not prove verified Android App Links | deploy/public-site/invite.js:4–26; source only, current domain/certificate/phone proof pending |

### Additional source interpretation limits

- Auth/session and public invite source do not establish the currently installed/deployed SHA.
- Guest mutation authority is stored flags. API_CONTRACT contains a stale role-fallback paragraph: D01; not a live authorization leak.
- Offline cache fallback applies to network failure, not403; replay of ambiguous mutations is separately classified. Queue host/real DB remain untested here.
- Pending-offer edits and rating availability are the current product contract. Versioned offers and verified completed-relationship reviews need a product decision, not a hidden audit fix.

## Third semantic batch — financial records and collaboration controls

These rows record inspected controls and transitions, not a live financial/permission verdict. Financial routes distinguish viewMoney from manageMoney (app_router.dart:410–412); provider methods enforce writes as well. Sensitive mutations were not run against a real account.

| ID | Surface / controls | Purpose, authority and applicable states | Effect / handoff / recovery | Source / proof |
| --- | --- | --- | --- | --- |
| S41 | Budget: total, locked currency, category rows/allocation, add category, save | Optional overall ceiling distinct from actual spending; duplicate normalized names, allocations without total, over-allocation blocked; loading/draft/error/busy | Save budget and allocations; clear scoped draft only on success, return changed; no actual payment from budgeting | money_budget_screen.dart:343–395 and category/summary widgets; selected320 tests, API/device pending |
| S42 | Category create/edit: name, allocated amount, save | Category names normalized/deduplicated excluding current category; allocation cannot exceed remaining ceiling or use a nonexistent ceiling | create returns category ID; edit returns changed; preserved input/draft on failure | budget_category_form_screen.dart:173–223; no real category write |
| S43 | Category detail: allocated/cost/paid/unpaid, cost rows, add/edit/delete | Read versus manage rights; money display uses shared presentation; delete confirmation explicitly says empty category | Navigate cost/create; confirmed delete then back; server deletion constraints require separate proof | budget_category_details_screen.dart:49–188/:200–298; detail fixture tests only |
| S44 | Costs list: search/clear, all/open/paid quick filter, extended status/category sheet, reset/apply/load more, row/add | Filters are actual status/category parameters; distinguish no results, first-load failure and stale-data error; create visible only to manager | Debounced/search/filter reads, pagination; row→cost detail; returning from add triggers refresh | costs_screen.dart:49–200/:214–360; no live pagination/large dataset proof |
| S45 | Cost form: category/name/total, optional initial payment, no party/Aarast provider/external party, contact, agreement date/note, save summary | Manager-only route; create versus edit; provider picker with search/pagination/errors; accepted-offer currency mismatch clears automatic amount/link and warns; no silent conversion | createCost or updateCost; actual optional initial payment differs from agreement total; successful draft clear and detail CTA | cost_form_screen.dart:239–556/:564–684; amount/party/quote behavior SOURCE, real transactions pending |
| S46 | Cost detail: total/paid/unpaid, information, next schedule, payment ledger, schedules, edit/cancel | Read-only explanation for viewer; write actions conditional on rights and noncancelled cost; loading/error/not found have separate recovery | record actual payment or future reminder; cancellation confirmation preserves ledger semantics; provider/source navigation is informational | cost_details_screen.dart:75–234/:251–334/:488–529; detail fixture tests PASS |
| S47 | Record payment: amount/current balance, paid date, optional method/note, save | Must be actual paid amount, positive and within current client balance; manager/noncancelled/busy guard; missing/error/read-only distinct | Payment mutation then refresh; F07 confirmed-save/read-failure truth gap; retries require reconciliation | RecordCostPaymentScreen in cost_payment_screens.dart:77–273; local F07 reproduction, not DB/device |
| S48 | Payment detail: amount/date/method/note, original/reversal status, reverse with required reason | Reversal is separate preserved record; manager and eligible original only; no edit-to-hide-history behavior implied | Confirm reason→reversePayment→refresh; viewers get explicit read-only text, already reversed/reversal has no repeat CTA | cost_payment_screens.dart:326–438/:591–661; no real reversal |
| S49 | Schedule list/detail: pending/late/paid counts, rows, linked cost/payment, add/edit/pay/cancel/delete | A reminder is not paid money or reservation; manager required for actions, eligible cost and schedule state; errors distinct from empty | Navigate fixed schedule payment or edit; cancel retains record, delete is separately confirmed; links to payment only when linked | payment_schedule_screens.dart:58–195/:262–484/:1148–1182; SOURCE |
| S50 | Schedule form/pay: amount/due date/note; pay uses fixed schedule amount, paid date/method/note | New due date not past; edits can represent existing dates; amount positive within cost unpaid; pay date not future; rights/state gate | Create/update reminder does not record payment; paySchedule does; success clears its scoped draft and returns changed | payment_schedule_screens.dart:559–798/:875–1032; no real schedule fulfillment |
| S51 | Sharing overview: privacy strip, add member, pending invite delivery/cooldown/reissue/cancel, member roles/rows | Fresh access checked; login/expired/denied/load failure separate; manage-members required; owner row not editable | New invitation is not active membership; reissue uses protection cooldown; edit member opens selected ID; cancellation is real mutation, not navigation | sharing_screen.dart:99–180/:328–465/:617–656; invite state tests PASS |
| S52 | Add member: phone lookup, role presets, eight explicit rights, create/link/copy/retry/back | Refresh authority before lookup/submit; duplicate member/pending invitation handled; role selection seeds rights, not runtime authority; managing money implies viewing, removing view removes manage | Existing pending invite can reissue; delivered/uncertain/link fallback remain distinct; back asks whether link saved; explicit recipient acceptance still needed | add_shared_member_screen.dart:225–423; permission_editor.dart:148–210; no real invitation sent |
| S53 | Edit member: current member, role/rights, save/remove confirmation | Refresh generation, exact plan/access/member re-read; missing/denied/load/session guards; rights editable only with manageMembers | Save explicit rights or remove membership; next contributor must observe changed/revoked authority; runtime/cache revocation still pending | edit_shared_member_screen.dart:187–306; no rights changed in this audit |
| S54 | Provider apply/edit: business name, contact on profile, city, primary category on application, description/draft/save | Login gate; existing applicant gets lifecycle state; reference-safe values; edit does not grant approval; missing/error/busy distinct | Application→Admin review; profile update→portal; no public appearance merely from saved draft | provider_apply_screen.dart:74–210/:271–323; edit_provider_profile_screen.dart:78–203/:264–306; live approval not tested |
| S55 | Provider services/packages: add, edit, active toggle; names/category/base price/unit/city/description; package price/linked service/items | Active listing capability; new service/package forms show explicit unavailable state before approval; fixed current currency contract, not availability/booking | Structured listing only; toggles/update reflected in catalogue; after successful add draft clears and optional add-another | add_provider_service_screen.dart:64–222/:280–309; add_provider_package_screen.dart:60–205/:248–283; provider_services_tab.dart:130–209 |
| S56 | Service images: gallery selection/upload/link, delete image, partial-result feedback | Picker permission failure explicit; bounded selection, busy service ID; upload to service-image purpose, then link to exact service; per-file error not all-or-nothing claim | Count saved versus failed; abort on certain server errors; deletion calls service-image API; public reference and storage object lifecycle distinct | provider_services_tab.dart:210–310; source only, no upload/cleanup performed |

## Fourth semantic batch — Admin reference and operational surfaces

Each page below is an administrative job; no customer private financial ledger is assumed. Action visibility alone is not proof of direct API authority. No live administrative decision was taken.

| ID | Surface / controls | Data, role and states | Effect / next actor / limits | Source |
| --- | --- | --- | --- | --- |
| S57 | Admin login/MFA/recovery: phone/password, challenge code, cancel, recovery phone/code/new password/confirmation/resend | Auth/session loading/error; safe return path; neutral recovery notice distinguishes DELIVERED; strong password12–72 plus letter/number | Password plus applicable MFA→admin session; reset clears password and returns to login, not automatic privileged session | auth/LoginPage.tsx:28–150 and recovery/render helpers; source review, no real login/MFA |
| S58 | Admin dashboard: users/providers/plans/requests, pending-review list, provider status chart, quick destinations | Real stats + max5 PENDING requests; attention count/status totals not financial/bookings; loading/error/no-data distinct; quick links unfiltered F08 | Pick review then provider detail; overview helps order decisions; read-only role must not gain writes | DashboardPage.tsx:39–58/:126–285; current role/route source checked |
| S59 | Categories/cities: total/active/provider/service counts, table, edit/disable confirmation, side form/reset | CATALOG_READ/WRITE; Arabic/English/name/order; category slug/icon/Groom/Bride visibility, city country; error/retry separate | Save reference data; disable explicitly not permanent delete in UI; downstream discovery filters/cache impact pending | CategoriesPage.tsx:75–98/:114–277; CitiesPage.tsx:66–84/:106–219 |
| S60 | Reference catalogs: select catalog, group/element/pending counts, revision selector/publish/stop, create/edit draft | Stable key, labels/groups/icon/order/audiences/recommended/active; draft not visible to app before publish; read/write permissions | Save revision→explicit publish or older-revision republish; devices receive on next sync, not an immediate phone update claim | ReferenceCatalogsPage.tsx:108–232/:242–430; no catalog edited/published |
| S61 | Administrative areas: governorate→district→locality selectors, counts/table, add/edit/stop, type/parent/order | Parent-dependent buttons prevent locality without district; current selection defines count; manual phone fallback acknowledged; read/write guards | Save scoped geographic reference; app location choices affected after load/sync; no existing location changed | AdministrativeAreasPage.tsx:82–223/:231–380 |
| S62 | Admin services: provider search/select, title/base price form, city/category/status/search, table/pagination/active/featured toggles | SERVICES_READ/WRITE; total results vs explicitly in-page counts; errors not zero; provider selection separate from service search | Create/toggle listing on actual provider, then reload; does not approve provider or create booking | ServicesPage.tsx:67–154/:166–352; no service mutation |
| S63 | Admin notification register: search/type/priority/read filters, counters, row read/archive/delete/pagination | NOTIFICATIONS_READ/WRITE; global unread vs page unread distinction; administrative-wide source, not current user's mobile feed | Change stored notification metadata; this page is NOT a broadcast composer or proof of device delivery | NotificationsPage.tsx:57–131/:145–253; live mutation/delivery pending |
| S64 | Admin user/provider details: identity/contact/status/dates, linked profile, state history, services/packages/request/review counts, state actions | Current server response; load/error/notfound distinct; USERS_WRITE and protected-admin-account policy, provider status action matrix | Enable/disable ordinary account, decide provider status only with authority; downstream live session invalidation not executed | UserDetailsPage.tsx:22–130; UsersPage.tsx:66–185; ProviderDetailsPage.tsx:26–161 and providerHelpers.tsx; selected contracts only |

## Fifth semantic batch — discovery, entry and account utility

| ID | Surface / controls | Purpose / applicable states / authority | Effect / handoff / recovery | Source / limits |
| --- | --- | --- | --- | --- |
| S65 | My/shared plans: plan cards, create, shared shortcut; create title/location/date/budget/currency | Own versus granted plans; no-data/load/error/session separated; required geographic selection and form validation; optional budget | Re-read/select exact owner or contributor context before navigating; new plan may exist if later context activation fails, explicitly reports activation issue | my_wedding_plans_screen.dart:72–94/:117–161; shared_wedding_plans_screen.dart:159–192; create_wedding_plan_screen.dart:206–259; no plan created |
| S66 | Discovery: search/clear, category chips, city picker/all, saved/messages shortcuts, location context, budget-match context/clear/results/load more | Active public catalogue versus account/plan scoped requests; budget matches use available service prices, not availability or guaranteed final price; empty/first error/stale/loading-more separate | Open provider or request for selected service; remove filters to recover no matches; region can prefill from selected plan | provider_marketplace_screen.dart:204–366; sections.dart:213–569; results.dart:3–218; live search/cache pending |
| S67 | Favorites: select up to3, comparison columns, details/remove/undo, add/browse | Existing BASIC comparison: category/city/price/rating/services; account-required, empty/error/stale;2 initially when available, max3 | Save/remove account favorite; undo sends restoration; comparison is not reservation/date check or category-specific feature evaluation | favorite_providers_screen.dart:51–222/:443–470; source only; do not propose duplicate basic comparison |
| S68 | Public provider detail: hero/gallery, favorite/share, provider/service/package/review sections, selected quote CTA | Public Active profile; partial service/package/review errors separate; favorites protected; featured status not financial guarantee; account quotes scoped to matching context | Share approved public link, open photos, request service quote; F03 covers missing/error profile footer; review eligibility is current contract S32 | provider_details_screen.dart:185–290; provider_details_view.dart:49–108; no public phone/contact/upload action taken |
| S69 | Conversation list: rows/avatar/status/last message/unread/muted, load more/refresh | Auth gate, quote-scoped relation; no-list vs load failure; title mentions plan but source supports scoped conversations, no open messaging authority | Row→existing conversation; counters/feed must remain scoped; muted marker not message delivery proof | conversation_list_view.dart:49–181; selected chat fixture tests only |
| S70 | Quote entry / inbox decisions: open-or-resolve conversation, offer details/expiry/new request, accept/reject, linked cost/chat | Quote auth gate; selected plan must match returned request; submit busy/error; expiry distinct from rejection and acceptance | Backend accept then reload finance and show linked cost; not payment/booking; entry resolves actual conversation or explicit retryable failure | quote_conversation_entry_screen.dart:33–87; marketplace results.dart:273–960; marketplace_screen.dart:634–683; live requester/provider handoff pending |
| S71 | Splash/home/router error/legacy entry | Auth checking/termination; guest local snapshot; authenticated migration before context entry; aliases onboarding→welcome and dev preview flag; safe error route display | Redirect only after session resolution; migration choice then context; routing error returns context selector without changing account identity | splash_screen.dart:44–63; dashboard_entry_screen.dart:49–105; app_router.entry.dart:14–23; app_router.dart:432–477 |
| S72 | Local-plan dashboard | Actual local draft/SQLite summary; local money/tasks/guests/plan routes; cloud actions still account-gated, dev exploration flags separate | Local planning before account; return refreshes local summary; sync requires account then migration; no local OTP treated as phone verification | local_guest_dashboard_screen.dart:126–217/:269–304; migration/context fixtures PASS; real import/restart pending |
| S73 | More/account utilities: identity/avatar, my/shared/create plans, context exit, saved/settings/support, sync, login/logout/delete | Account/context-dependent entries; exit context differs from logout; deletion explicitly confirmed; auth teardown failures must remain visible | Avatar camera/gallery with max5MB and JPG/PNG/WebP; update then success/error; logout/sync/deletion are data operations not harmless navigation | more_screen.dart:40–150/:159–322; no upload/logout/delete performed; physical permissions/recovery pending |
| S74 | Public privacy/support pages | Arabic/RTL static information, support email, deletion/privacy/sync guidance; no support ticket API created by the page | Mail client or read guidance; existing mail address availability not verified; public-site build/origin is deployment-specific, outside current server scope | deploy/public-site/privacy.html and support.html; templates/build path read; no external requests |

## Semantic review backlog

- Expand each containing build/helper into actual visible controls, conditions, data sources and navigation effects.
- Classify wrappers/parts/dead declarations with evidence, not naming preference.
- Bind applicable states and actor permissions; capture tests and runtime independently.
- Record N/A reasons and blockers. No blank evidence becomes PASS.

## Current device checkpoint — 2026-10-05

USB is now connected; the owner manually logged in.06-device-observations.md records the observed read/navigation states for S01/S05/S07/S10/S11/S16/S17/S21/S26/S28/S51/S53/S65/S66/S67/S73. This is partial runtime evidence, not16 completed screens or closure of their child controls, writes, errors and role permutations. Installed package com.aarast.aarast_mobile.qa, version1.0.0/code9, does not attribute the APK to source HEAD.

- Tasks:1 completed,0 remaining; home generic100% progress recorded as Q05, arithmetic agrees with current task formula.
- Guests:1 pending,1 expected seat; scrolling reaches row/actions. No RSVP/send/edit/delete performed.
- Money: starter with10 categories selected; no setup/cost/payment submitted.
- Sharing: owner/helper displayed; explicit editor rights and bottom controls inspected, exited without changes. This does not retest contributor sheet F04.
- Marketplace stays empty after clear-filters; favorites/shared-plans empty. No live provider/quote/comparison/contributor acceptance inferred.
- Settings claims device Push enabled for a registered device; real Push not tested. Notifications list read without opening/marking/archiving entries.

All495 widget candidates and applicable states still require reconciliation; this checkpoint does not change Task2's IN PROGRESS status.

## Element/state reconciliation — home, quick add and owner plan center

This expands existing S05/S10/S11/S15 rather than inventing new screens. Source:14eccb50c6b2e050b044c7b00ac38a7e64f5164b. Current phone evidence is independent and its APK revision is not attributed. DEVICE OBSERVED is limited to current records/read navigation; unexecuted branches remain explicit.

| Element | Job / authoritative input / condition | Effect and recovery | Evidence / unproven states |
| --- | --- | --- | --- |
| Home first load/error/empty/context mismatch | Dashboard summary and selected plan must agree; initial loading skeleton, first error with retry, no-summary create entry, missing/mismatched selected-plan protective state | Retry/load exact context; no mismatched plan displayed as success | wedding_plan_dashboard_screen.dart:154–284; source reviewed. Current loaded owner observed; forced network errors/context mismatch not exercised on phone |
| Greeting/header/context | Identify current person/plan; avatar/account and plan management are different destinations | Avatar opens account utilities; hero opens plan center; do not conflate context exit with logout | Dashboard view and screen callbacks; current loaded owner observed. Local/contributor/provider alternatives are separately registered |
| Stage/date/countdown | Actual plan date and time-derived stage; Wedding Day entry only within its applicable window | Open contextual day view; stage is not an availability/booking guarantee | aarast_dashboard_view.dart; current planning display observed. No phone clock/date altered to manufacture other stages |
| Home completion | completed tasks / total tasks, rounded; no tasks returns0 | Indicator, not a write or full-wedding readiness percentage | Backend presenter/service plus current1 completed task. Q05: general label needs a meaning decision, not a formula fix |
| Main attention priority | Server importantItems first; fallback ranks permitted due/overdue/quote/guest/invite/setup actions | Exact action destination, or calm plan review; caller must retain current-plan scope | aarast_dashboard_focus.dart; focused native tests PASS. Current budget prompt observed; all server important-item variants and resulting writes not accepted |
| Tasks signal | Remaining tasks=max(total-completed,0), overdue count, existing-total condition changes detail to مكتملة | Open current plan tasks | aarast_dashboard_mosaic.dart:204–218; current0 remaining/1 completed observed; Q01 remains wording ambiguity |
| Guests/providers signals | Guests total/status indicators; providers are linked/requested provider records and pending/received quote counts | Open plan guests/providers; provider number is not confirmed booking count | aarast_dashboard_mosaic.dart:220–270; pending guest and empty discovery observed. Populated quotes/date availability not proven |
| Money card/privacy | Only canViewMoney; canonical budget/confirmed/paid/outstanding/remaining; display hiding is local | Open money; local hide control masks amounts and semantics for this card | aarast_dashboard_money_card.dart; current budget starter observed, populated card/privacy not physically retested. F02 is another reminder card, not this component |
| Team/invites | Owner or canManageMembers; participants and pending invitations separate | Sharing management with exact plan scope, refresh after return | aarast_dashboard_support.dart + screen callbacks; current team count agrees with list. No invite or membership change performed |
| Shell tabs and add control | Owner plan five-tab shell; home opens action selector, task tab opens task form, guest tab opens local add request | Tab navigation is not a save. Quick-add callbacks route to actual forms/context; last action remembered per plan in memory | main_shell.dart:107–189/:235–241; canonical routing/ranking tests PASS. Current selector observed; long-press/Back permutations remain untested physically |
| Quick-add recommendations | Current tab base order, explicit capabilities, urgency, stage and remembered action; no money actions without management | Quote opens plan-provider discovery unless an explicit quote callback is supplied; choosing an action is not Backend quote submission | quick_add_actions.dart;29-quick-add.png. Q06 addresses meaning of الأنسب الآن, not a false successful quote. No action chosen on phone |
| Plan identity/location | Current plan data, required versus optional geographic fields; edit controls only with management rights/local draft capability | Actual basic/location editors, no automatic save on open | plan_management_view.dart and PlanCenterScreen;30/34 images. No field/switch/save edited; location picker/error/keyboard variants pending |
| Plan participants/rights | Owner, participant count, pending invites, current management state | Sharing editor destination, not implicit role grant |34-plan-center-lower.png; source callbacks. Counts observed, other roles/revocation not live accepted |
| Preferences/data completeness | Title/date/required location/currency/priorities: five equally weighted completeness checks | Explicit missing fields listed. This is metadata completeness, separate from task progress and wedding readiness | plan_management_view.dart:128–150; current80%, only priorities missing,35/36 images. Arithmetic/source agree; no new generic readiness metric required |
| Basic-plan editor | Current draft, explicit fields, validation/busy/error/save; scroll-controlled sheet | Save is mutation; open/scroll/Back is read navigation. F01 payload-contract issue and F09 top inset are distinct | Actual editor opened twice/closed unchanged. F09 diagnostic measures heading y14 with inset30. Keyboard/save/network failure not exercised on phone |
| Archive safety panel | Owner management; current active versus archived state; copy distinguishes archive from deletion | Actual archive requires confirmation and changes plan status; never press as read navigation | plan_management_view.dart:408–440;36-plan-center-safety.png shows reachable control. Confirmation/effect/reactivation/revocation not exercised |

Wide layout >=760, true keyboard, no-rights/revoked context, stale cached error, populated finance/quotes, live saves and multi-actor handoffs remain NOT PROVEN for this batch. Existing fixtures cover selected inputs only. No element-count percentage or all-state PASS is claimed.

## Element/state reconciliation — starter and manual budget

Existing finance surfaces are expanded here; this is not permission to set up the owner's real budget. Current manual route uses the same finance contracts, not a second ledger.

| Element | Purpose / condition / actual effect | Proof and limits |
| --- | --- | --- |
| Entry/load/access | Starter only after money loaded, canManageMoney, no budget/categories/costs/payments/due schedules and no summary cost/schedule counts. First failure gets retry, not a fabricated empty starter | money_overview_screen.dart:79–110/:292–300. Current empty owner state observed; no-rights/network/offline branches not forced on phone |
| Persona/catalog | Explicit persona, exact selected account context/active or selected plan/local draft, then neutral. Managed catalogue if present, otherwise built-in category names | money_overview_screen.dart:196–226; money_starter_catalog.dart. Catalogue fallback is reference choices, not fake amounts or access. Bride/neutral fixtures in29-test batch; real Bride context pending |
| Recommended selection/group/count | Recommended category IDs selected initially; checkmarks and count reflect draft selection; group descriptions; select-all alternates all versus recommended essentials | money_starter_setup.dart:37–242. Current10 selected displayed; no selections toggled physically. Choices are not costs/commitments/paid money |
| Custom category | Local draft name, whitespace/normalized duplicate checks, blank error, add/remove custom selection | money_starter_setup.dart:258–308/:647–712. No real custom name entered; fixture tests PASS. Removing a custom draft is not deleting a server category |
| Starter submit | Explicit selected names; disabled when none/busy, preserved visible error; single saveBudget call with null allocations/current nullable total, then budget screen only after success | money_overview_screen.dart:228–252; FinanceProvider._replaceBudget consumes returned summary/categories, no separate reload here. Existing18-test money journey includes one selected-category fixture write; real DB atomicity/retry not retested in this phase |
| Manual alternative | Opens moneyBudget route without category batch or budget save |37/38/39 images, source callback:108–109. Initial authority-check loading settled into actual form; no false failure inferred from spinner |
| Layout/actions | Scrollable groups, embedded bottom clearance; >=1.6 text scale puts actions inline; fixed action area otherwise; enabled/error semantics | money_starter_setup.dart:70–225/:517–647/:716–846. Current1.15 visible actions observed;320/2.0 native starter fixture PASS. Physical screen-reader/focus permutations not accepted |
| Budget authority/load/hydration | Exact plan money read, finance write-access block, hydrate only loaded matching/error-free state; fields retain draft independently | money_budget_screen.dart:41–82/:258–301. Owner form/empty state observed; no revoked-session/cache/refresh failure induced |
| Budget total/currency/allocation | Optional positive total; currency choices before costs, locked once costs exist; sum allocations versus total, explicit pending-budget/over-budget meaning | money_budget_screen.dart:85–172/:303–309/:343–375/:425–538/:730–769. Empty total/zero allocation and choices observed; no money typed/currency changed; lock state not physically exercised |
| Categories | Actual saved category rows link detail; separate create route; only actual created ID/changed result triggers category reload | money_budget_screen.dart:180–244/:311–342. Current no-category message/button observed after scroll. No create/remove/details written |
| Draft status | Local encrypted form store, budget-plan scope; binding tracks total controller and currency extras, restore guards; clear on confirmed successful save | money_budget_screen.dart:395–422; aarast_form_draft_binding.dart; aarast_form_draft_store.dart. Current automatic draft-saved status appeared after input focus, with no typed value. It is not Backend save, not proof every allocation/name is restored, and not restart/recovery acceptance |
| Save/validation | Blank total + no categories rejected; normalized duplicate names rejected; positive allocations need total; sum cannot exceed total; successful result clears draft then pop(true) | money_budget_screen.dart:343–393. Save is intentionally enabled to validate when pressed; do not call enabled empty Save a false success. No validation/submit pressed on phone |
| Return/keyboard | Actual numeric keyboard opens; after dismissal scroll reaches no-category region and Save; source Back callback pops(false) |39–42 images. USB disconnected before intended final Back, so actual return not observed. No entered value or save. Save hidden behind IME is a limited observation, not proven unreachable or an automatic defect; no general keyboard acceptance claimed |

## Widget declaration reconciliation for these batches

The original W-list is a candidate index. The following groups now have PARTIAL SOURCE REVIEW linked to the element/state tables above; they are not fully accepted widgets or additional screens. Containing controls still need their remaining states/consumers. All other candidates remain as previously listed.

| Candidate group | Containing surface / evidence | Remaining gap |
| --- | --- | --- |
| W359–W360 | Owner shell/router context and current add actions; actual current tabs and selector observed | Every context/tab/back/long-press combination, loading/revocation and alternate shell consumers |
| W365–W366, W368–W370 | Sheet/row/action/nav render helpers: callbacks/selection/description/close semantics and text-scale branches traced | Screen-reader/compact-height/large-text/long-press physical acceptance; context bar W367 separate |
| W428–W431 | PlanCenter/load-state/editor and owner dashboard root; current loaded state, F01/F09, actual local probe and source guards | Contributor/local/server/no-rights/error/keyboard/save combinations not all accepted |
| W451–W454, W463–W466 | Mobile mosaic/focus/signals/team plus skeleton/state render helpers; source conditions/formulas/callbacks, current owner subset | Render helpers are not independent routes. Empty/error/populated/no-rights and all underlying action effects remain pending |
| W470–W482 | Main dashboard header/hero/day entry and plan-management header/identity/location/preferences/completeness/archive/card/row | Current narrow loaded owner subset only. Day/wide/keyboard/archive/write conditions not closed; source metadata formula proved |
| W079–W080, W084, W104–W113 | Manual budget root/allocation/locked currency and starter group/row/custom/action/error helpers | Current owner empty/read/keyboard subset; selected fixture tests. Populated allocation/draft restart/currency lock/error/save/multi-actor proof remains pending |

Wide-only dashboard sections W455–W462 and money sub-renderers W444–W450 need their own containing-control review. Their declaration/part relationship alone is not enough to mark them reviewed, optional, dead or safe. No code removed.
