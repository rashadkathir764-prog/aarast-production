# Aarast Mobile Screen Audit Matrix

Date: 2026-07-02
Scope: Flutter mobile production surfaces only.
Identity: Soft Royal Wedding.
Status: Phase A baseline. No UI changes made by this audit.

## Legend

| Status | Meaning |
| --- | --- |
| `Aligned` | Uses the shared system and the product logic is clear enough for release. |
| `Partially aligned` | Mostly usable, but needs content, component, or state tightening. |
| `Broken logic` | Flow, gate, data truth, or action availability is confusing or unsafe. |
| `Visual drift` | Screen uses local colors/layout/components that do not feel like the same app. |
| `Content misplaced` | Content exists, but appears in the wrong hierarchy or screen location. |

## Top 10 Stabilization Priorities

| Priority | Screen family | Entry points / files | Current status | Main issue | Required correction | Component needed | Phase |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Home dashboard | `mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart`, `mobile/lib/features/wedding_plans/widgets/aarast_dashboard_widgets.dart` | Visual drift | Large local dashboard widget grammar, raw colors, local gradients, and dense dashboard sections create identity drift. | Rebuild dashboard sections through shared Soft Royal cards, truthful metrics, and one clear next action. | Dashboard header, metric tile, quick action, status badge | C |
| 2 | Startup / welcome | `mobile/lib/features/auth/screens/splash_screen.dart`, `mobile/lib/features/onboarding/screens/guest_welcome_screen.dart`, `mobile/lib/features/onboarding/screens/generated_dashboard_preview_screen.dart` | Partially aligned | First-run story must clearly separate local guest preview from saved account-backed plan. | Tighten copy hierarchy, local-vs-account truth, and primary CTA order. | Startup scaffold, hero header, primary/secondary buttons, preview state | C |
| 3 | App shells and bottom navigation | `mobile/lib/features/shell/main_shell.dart`, `mobile/lib/features/shell/screens/wedding_plan_shell.dart` | Partially aligned | Shells intentionally own navigation but still use direct `Scaffold(` and custom chrome. | Document shell exception or wrap the shell chrome in a shared Soft Royal shell component. | Bottom nav, shell scaffold, floating action sheet | C |
| 4 | More / utility hub | `mobile/lib/features/more/screens/more_screen.dart` | Content misplaced | Secondary actions can feel like a mixed menu instead of a calm account/tools hub. | Group utilities by user intent and keep one clear primary account/action area. | Utility section, list row, locked state | C |
| 5 | Money | `mobile/lib/features/finance/screens/budget_expense_screen.dart`, debts/installments screens | Visual drift | Financial surfaces include local `_RoyalColors`, raw colors, and mixed financial hierarchy. | Consolidate budget/expense/debt states into shared privacy-safe financial cards. | Financial summary, status badge, empty/error state | D |
| 6 | Tasks | `mobile/lib/features/tasks/screens/task_timeline_screen.dart`, `create_task_screen.dart` | Partially aligned | Task priority, due dates, and completion states need faster scanning and no hidden fake certainty. | Use one task row/card pattern and tokenized priority/status states. | Task card, priority badge, timeline empty state | D |
| 7 | Guests | `mobile/lib/features/guests/screens/guest_list_screen.dart` | Partially aligned | Guest counts and invitation meaning must stay truthful to available data. | Keep guest list, counts, and actions in a clear planning hierarchy. | Guest summary, guest row, empty state | D |
| 8 | Providers | `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart`, provider details, quote request, provider account screens | Visual drift | Provider surfaces must stay request/quote-based and not imply booking/payment completion. | Standardize provider cards, quote CTAs, locked/API-required states, and wording. | Provider card, quote CTA, locked state | D / E |
| 9 | Plan Center | `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart` | Visual drift | Local `_RoyalColors`, direct color usage, and dense plan sections reduce identity consistency. | Reorder plan identity, event details, and planning modules into shared section grammar. | Plan header, section title, module card | D |
| 10 | Auth and secondary account screens | login/register/OTP/settings/support/sharing/notifications | Partially aligned | Forms and secondary states need one Soft Royal rhythm and consistent unavailable/error copy. | Standardize form field spacing, validation states, and account/sync gates. | Form field, error state, locked state, settings row | E |

## Current Technical Observations

- Production routed `*_screen.dart` files already have a static guard against direct
  `Scaffold(`, `Card(`, and legacy `PrimaryActionButton` usage.
- Direct Material `Card(` usage is already guarded across `mobile/lib/features` and
  `mobile/lib/shared`.
- The deeper instability is local visual systems inside screens and widgets:
  raw colors, screen-local color classes, local gradients, and one-off layout grammar.
- The shell files require an explicit decision because they are navigation containers,
  not ordinary routed content screens.

## Do Not Fix Everything At Once

This matrix is intentionally a release-stabilization queue. Each phase should fix the
highest-impact journey first, preserve working product logic, and avoid broad rewrites.

## Phase C Progress

| Area | Status | Notes |
| --- | --- | --- |
| Welcome gateway | Partially stabilized | Added one consistent Soft Royal journey header, tightened role/setup spacing, replaced local primary buttons with shared `AarastButton`, and kept required local-plan data gate. |
| Generated preview | Partially stabilized | Added explicit local-draft notice so the preview does not imply cloud sync/share readiness. |
| More | Partially stabilized | Added section grouping for plans, account/help, and sync without changing route destinations. |
| Bottom navigation | Kept | The current live shell has Home, Money, Tasks, Guests, Providers. No new More tab was invented because that would change the active product contract. |
| Home dashboard | Partially stabilized | Renamed the awkward priority section to `الأهم الآن`, added supportive hierarchy copy, kept real summary data, and aligned the shell gold depth without changing dashboard routes or counts. |

## Phase D Progress

| Area | Status | Notes |
| --- | --- | --- |
| Money | Partially stabilized | Clarified the finance header, made budget status readable as a pill, kept local/permission finance guards intact, and replaced UI-instruction empty copy with truthful planning copy. |
| Tasks | Partially stabilized | Replaced the loose title row with a shared Soft Royal header, kept local task behavior intact, and made empty states truthful per filter instead of pointing to visual controls. |
| Guests | Partially stabilized | Replaced the loose title row with a shared Soft Royal header, kept local guest behavior intact, and made empty states truthful per guest filter without implying invitations or sharing occurred. |
| Providers | Partially stabilized | Kept public browsing open, removed public zero-count account stats, clarified that providers support quote requests only, and avoided booking/payment implications. |
| Plan Center | Partially stabilized | Replaced the loose header with a shared Soft Royal header and removed generic unavailable copy from metric values while keeping route ownership and local guest behavior intact. |

## Phase E Progress

| Area | Status | Notes |
| --- | --- | --- |
| Sharing auth gates | Partially stabilized | Preserved the guest/local gate before protected sharing APIs and added resume routing so login from a sharing gate returns to the protected sharing route instead of dropping the user at a generic account entry. |
| Support | Partially stabilized | Replaced the routed Coming Soon page with a local Soft Royal support guide that gives safe help actions, privacy boundaries, and real navigation to settings, notifications, and shared plans without implying tickets, refunds, payments, or guaranteed dispute resolution. |
| Notifications + Settings | Partially stabilized | Added account gates before protected settings/account-notification loads, kept local plan notifications open without backend calls, and added 320px RTL regression coverage for the gated states. |
