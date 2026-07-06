# Aarast Premium 2027 Screen Contracts

Date: 2026-06-26
Scope: Flutter mobile production surfaces.
Status: Implementation-layer screen contracts for the Premium 2027 pass.

> Current identity note (2026-07-02): Premium 2027 is now a technical
> implementation layer. The final mobile product identity is
> `../../MOBILE_SOFT_ROYAL_UI_PLAN.md` (`Soft Royal Wedding`).

## Global Contract

Every production mobile screen should feel like one Aarast product:

- Use the tokenized maroon, champagne gold, pearl, warm ivory, ink, and semantic state palette.
- Use `AarastPageScaffold`, `AarastScreenFrame`, `AarastScaffold`, `AuthWeddingScaffold`, or `GuestOnboardingStepScaffold` for every routed production screen.
- Use `AarastCard` for repeated cards and framed panels.
- Use shared status badges for compact domain states.
- Preserve existing route names, provider contracts, and API semantics.
- Keep Arabic RTL alignment and avoid compact text overflow.
- Show loading, error, empty, locked, and unavailable states honestly.
- Do not reuse, restore, copy, or visually match old designs, Markdown decisions, screenshots, prototypes, rebuild screens, or legacy widgets as final UI.
- Inspect old files only for product logic, then rebuild the interface through Premium 2027 tokens and shared components.

## Navigation Contract

Current production shell tabs:

| Tab | Responsibility | Visual rule |
| --- | --- | --- |
| Home | Current plan summary and today center | Royal dashboard surface, action sheet, truthful summary values |
| Money | Budget, expenses, debts, and installments | Privacy-sensitive cards, semantic paid/planned/overdue states |
| Tasks | Timeline and task actions | Clear priority/status chips, no hidden task counts |
| Providers | Marketplace and quote entry points | Request/quote language only, no booking/payment confirmation |
| More | Settings, sharing, guests, notifications, secondary tools | Quiet utility layout, not a marketing page |

The plus action sheet remains an entry-point surface, not a proof that every downstream backend operation is complete.

## Screen Family Contracts

| Family | Files / entry points | Contract |
| --- | --- | --- |
| Startup and auth | `SplashScreen`, login, register, OTP | Keep auth truth explicit. Do not bypass account gates in production copy. Use the shared warm background and tokenized controls. |
| Guest onboarding | Guest welcome, choose path, persona, location, date, priorities, budget, categories, generated preview | Local-first states must remain clear. Do not present generated local summaries as saved backend plans. |
| Home dashboard | `MainShell`, `WeddingPlanDashboardScreen`, royal home widgets | Use one premium dashboard language, preserve five production tabs, keep summary values from the existing providers/adapters. |
| Plans | My plans, create plan, plan center | Plan identity and event data must be readable and truthful. Optional data should look optional, not silently saved. |
| Money | Budget categories, expenses, debt/installment screens | Financial details are private by default. Visual status must distinguish planned, paid, partial, cancelled, pending, and overdue without implying payments were processed. |
| Tasks | Timeline, task cards, create/edit task | Status, priority, and due dates must scan quickly. Reopen/edit/delete actions must preserve existing provider behavior. |
| Guests | Guest list and guest-related summaries | Guest counts and invite states must reflect available data only. No invented RSVP or attendance truth. |
| Sharing | Share screen, add/edit member, shared plans, invite decision | Permission surfaces must be explicit. Financial permissions must stay separate from general collaboration permissions. |
| Providers | Marketplace, provider details, quote request, provider dashboard/apply/package/service screens | Provider surfaces can support discovery and requests. They must not imply confirmed bookings, deposits, settlement, financing, or internal chat. |
| Notifications | Notifications screen | Use concise status and empty states. Deep links must go only to existing routed surfaces. |
| Settings and more | Settings, more menu, secondary account tools | Utility-first layout with clear actions, no decorative landing composition. |

## Action Contract

| Action type | Required behavior |
| --- | --- |
| Create or edit domain record | Keep the existing provider/API/offline behavior. Use loading state while submitting. |
| Delete or destructive action | Use danger styling and existing confirmation paths. |
| Financial action | Respect permissions and avoid exposing private amounts to shared members without access. |
| Provider quote action | Use request/review language. Do not use confirmed booking, deposit, or payment language. |
| Unavailable action | Prefer disabled, locked, API-required, or coming-soon treatment over fake success. |

## Loading, Error, Empty

- Loading should use skeletons or compact tokenized spinners inside the existing layout.
- Errors should be recoverable where a retry exists.
- Empty states should describe the real missing data and the next valid action.
- Local/guest-only data should remain distinguishable from account-backed data.

## Visual Completeness Bar

A screen family can be considered Premium 2027 aligned when:

1. Every production screen in the family renders through one of the approved Premium wrappers listed in the global contract.
2. Repeated surfaces use `AarastCard`.
3. Compact states use shared status badges or semantic theme colors.
4. It has no direct routed-screen `Scaffold(`, `PrimaryActionButton`, or `primary_action_button.dart` usage under `mobile/lib/features/**/screens`.
5. It has no raw production `Card(` usage under `mobile/lib/features` or `mobile/lib/shared`.
6. It preserves current route/provider/test behavior.
7. It does not add future-phase features or product claims.

## Current Production Screen Gate

The Premium 2027 implementation gate tracks the routed production files from `AppRouter` plus screens rendered by the home/onboarding entry flows. Development preview routes under `/dev/...` are not production defaults and remain guarded by feature flags.

Each production screen must show a visible Premium surface change in its own rendered tree. Theme-only changes do not count unless the screen file also renders through one of the shared Premium wrappers above or a direct feature wrapper that itself is Premium 2027 aligned.

## Superseded Visual Inputs

Earlier mobile UX documents, screenshots, prototype images, rebuild screens, and legacy widgets are not visual references for the final UI. For current implementation, this document and `AARAST_PREMIUM_2027_DESIGN_SYSTEM.md` are the active Premium 2027 visual contracts.

The final UI identity is now governed by `../../MOBILE_SOFT_ROYAL_UI_PLAN.md`.
Older files may still be read to understand product logic, API truth, routing, permissions, privacy, and phase boundaries. They must not be reused, restored, copied, or matched visually outside the final Soft Royal Wedding identity.
