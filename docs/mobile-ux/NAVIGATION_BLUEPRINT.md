# Aarast Mobile Navigation Blueprint

Date: 2026-06-19
Stage: Navigation Blueprint
Status: Draft ready for route/shell implementation planning

## 1. Navigation Decision

Aarast mobile must have two separated navigation systems:

- Wedding-user navigation for people organizing a wedding.
- Provider navigation for service providers.

The two systems must not share one bottom navigation. A user may switch path only through an explicit account/path action, not through repeated provider CTAs inside normal planning screens.

## 2. Current Navigation Problem

Current `/home` uses `MainShell` with an `IndexedStack` and four effective areas:

- Home/dashboard.
- Providers.
- Tasks.
- More.

Current gaps:

- No dedicated Money tab.
- Active plan is auto-selected from the first loaded plan.
- Provider marketplace appears as a normal user tab without a full provider/user split.
- Quick add includes common actions but does not include quote request.
- Several screens can open the same operation, which can become confusing without rules.

No route implementation should change until this Blueprint is accepted.

## 3. User Bottom Navigation

Required user tabs:

| Index | Label | Purpose | Root surface |
|---|---|---|---|
| 0 | الرئيسية | Today Center / generated dashboard for current plan | Home / Today Center |
| 1 | المال | Budget, expenses, debts, installments | Money |
| 2 | المهام | Tasks and timeline | Tasks |
| 3 | الموردون | Provider planning references and quote requests | Providers |
| 4 | المزيد | Account, plans, sharing, settings, support, secondary surfaces | More |

Rules:

- The selected current plan is shared across Home, Money, Tasks, Providers, and More.
- If no current plan exists, Home shows onboarding/plan creation continuation, and Money/Tasks/Providers show a plan-required state.
- Money tab must not expose private financial data to shared users without explicit permission.
- Providers tab is for browsing and quote requests, not provider dashboard management.
- More is not a duplicate primary navigation hub; it holds secondary and account-level actions.

## 4. Provider Bottom Navigation

Required provider tabs:

| Index | Label | Purpose | Root surface |
|---|---|---|---|
| 0 | الرئيسية | Provider profile status and summary | Provider Dashboard |
| 1 | الطلبات | Quote requests received by provider | Provider Requests |
| 2 | العروض | Services/packages/offers provider manages | Provider Offers |
| 3 | ملفي | Provider profile, service areas, verification status | Provider Profile |
| 4 | المزيد | Settings, support, logout, switch path | Provider More |

Rules:

- Provider navigation appears only after user chooses provider path and is authenticated or inside provider auth gate.
- Provider must never see wedding plan private dashboards through provider tabs.
- Provider quote requests show only the fields intentionally sent by the user.
- Provider status controls available actions:
  - draft: complete profile.
  - pending_review: read-only waiting state.
  - approved: manage services/packages and requests.
  - verified: same as approved with verified badge.
  - suspended/rejected: restricted state with support/admin guidance.
- Provider mode does not imply admin rights.

## 5. Global + Action Sheet

The user bottom navigation has a central `+` action sheet.

Allowed user actions:

| Action | Requires current plan | Requires account | Requires online | Permission |
|---|---|---|---|---|
| إضافة مصروف | Yes | No for local draft, yes for cloud sync | No for local draft | Owner or finance manager |
| إضافة مهمة | Yes | No for local draft, yes for shared assignment/sync | No for local draft | Owner, manager, task manager |
| إضافة ضيف | Yes | No for local draft, yes for cloud sync | No for local draft | Owner, manager, guest manager later |
| إضافة دين | Yes | No for local draft, yes for cloud sync | No for local draft | Owner or finance manager |
| طلب عرض سعر | Yes | Yes | Yes | Owner or provider manager later |

Rules:

- If no current plan exists, the `+` opens a plan-required sheet with "إنشاء خطة" as primary action.
- If a financial permission is missing, financial actions show locked explanation, not hidden crashes.
- Quote request opens provider selection or Providers tab with quote intent.
- The sheet must not include incomplete AI, subscription, payment, deposit, or confirmed booking actions.
- The same action may appear inside its domain page, but the user should not see many unrelated duplicates.

## 6. Operation Entry Points

| Operation | Primary entry | Secondary entry | Forbidden duplicates |
|---|---|---|---|
| Create plan | Onboarding completion or More -> My Plans | No-plan Home state | Do not show as repeated CTA on every domain card once a plan exists. |
| Switch plan | Home/Today current-plan selector | More -> My Plans | Do not silently switch from detail screens. |
| Add expense | Money tab and `+` sheet | Budget category detail later | Do not show in Providers unless linked quote flow exists. |
| Add budget category | Money tab | Onboarding suggested categories | Do not show from Home as generic action. |
| Add debt | Money tab and `+` sheet | Debt section in Money | Do not mix with payment/loan language. |
| Add installment | Debt details | Money debt section | Do not create installment without selected debt. |
| Add task | Tasks tab and `+` sheet | Generated dashboard next action | Do not duplicate inside every card. |
| Add guest | Guests surface and `+` sheet | Home guest prompt | Do not upload all contacts. |
| Request quote | Providers tab/provider detail and `+` sheet with provider intent | Home suggested provider card later | Do not request quote without plan/account gate. |
| Share plan | Sharing screen | Home sharing prompt, More | Do not auto-share financial data. |
| Manage settings | More -> Settings | Notification permission prompt later | Do not prompt settings from first launch. |
| Provider apply | Choose Path provider branch | More -> Provider path if intentionally exposed | Do not repeat "join provider" inside every user provider card. |

## 7. Route Guard Rules

### 7.1 Session Guards

- Splash checks current session and local guest state.
- Guest can access wedding-user onboarding, generated dashboard, and allowed local planning surfaces.
- Authenticated user can access cloud-backed owned/shared plan surfaces.
- Unauthenticated user opening account-required route sees an auth gate with reason and resume target.

### 7.2 Current Plan Guards

Routes requiring current plan:

- Home generated dashboard.
- Money.
- Tasks.
- Guests.
- Sharing.
- Plan notifications.
- Quote request.

Guard behavior:

- If current plan exists, continue.
- If local guest plan exists, use it where action allows local mode.
- If no plan exists, route to generated plan/onboarding continuation.
- If route includes a plan id, validate ownership or sharing permission before rendering private data.

### 7.3 Permission Guards

Financial routes:

- Money.
- Expenses.
- Budget categories.
- Debts.
- Installments.

Required permission:

- Owner, manager with finance permissions, or explicit finance manager rules.

Task routes:

- Owner or `canManageTasks` for writes.
- Shared members can read tasks according to backend rules.

Sharing routes:

- Owner manages members.
- Shared member can view only where intentionally allowed.

Guest routes:

- Owner/manager can write.
- Guest manager permission can be introduced later.

Provider routes:

- Provider dashboard requires authenticated provider path.
- Provider service/package management requires provider profile and allowed status.

### 7.4 Feature Guards

Incomplete features must stay behind flags:

- AI helper.
- Provider quotes beyond current planning-lead scope.
- Push notifications.
- Maps.
- Analytics.
- Subscriptions.
- Payments.
- Confirmed bookings/deposits.

If a feature is disabled:

- Hide the entry point, or
- Show an honest planning message only in internal/dev surfaces.

## 8. User/Provider Separation Rules

- Wedding users see user bottom navigation.
- Providers see provider bottom navigation.
- A provider can still create a wedding-user plan only after explicitly switching to wedding-user path.
- A wedding user can apply as provider only from Choose Path or a controlled More action.
- Provider dashboard must never be a tab inside wedding-user shell.
- Wedding dashboard must never show provider operational stats.
- Quote request details shown to provider are limited to submitted request fields.

## 9. Deep Link Rules

Deep links must resolve through guards:

| Deep link target | Guard |
|---|---|
| Task due | Auth/current plan or local plan; task access |
| Installment due | Auth/current plan; finance/debt permission |
| Budget exceeded | Auth/current plan; finance permission |
| Quote received/status | Auth/current plan; quote owner |
| Member joined | Auth/current plan; sharing access |
| Permission changed | Auth/current plan; affected member |
| Guest confirmed | Auth/current plan; guest access |
| Sync failed | Local/offline service state |

Rules:

- If target cannot be opened, show a safe fallback with reason.
- Do not reveal hidden financial titles/amounts in notification previews for unauthorized shared members.
- Push permission is requested only after the user has meaningful notification context.

## 10. Proposed Route Groups

Planning-level route groups only; exact route names may be finalized during implementation.

User app:

- `/welcome`
- `/choose-path`
- `/onboarding/persona`
- `/onboarding/location`
- `/onboarding/wedding-date`
- `/onboarding/priorities`
- `/onboarding/budget`
- `/onboarding/categories`
- `/home`
- `/money`
- `/tasks`
- `/providers`
- `/more`
- `/plans`
- `/plans/:planId`
- `/plans/:planId/guests`
- `/plans/:planId/sharing`
- `/plans/:planId/notifications`

Provider app:

- `/provider`
- `/provider/requests`
- `/provider/offers`
- `/provider/profile`
- `/provider/more`
- `/provider/apply`

Auth gates:

- `/login?resume=...`
- `/register?resume=...`
- `/provider/register?resume=...`

Implementation note:

- Existing route compatibility should be preserved with redirects where possible.
- Do not delete existing routes until migration plan and QA plan exist.

## 11. Acceptance Criteria

- User bottom navigation is defined as الرئيسية / المال / المهام / الموردون / المزيد.
- Provider bottom navigation is defined as الرئيسية / الطلبات / العروض / ملفي / المزيد.
- `+` action sheet actions and requirements are defined.
- Entry points and duplicate restrictions are documented for each operation.
- Route guards are documented for session, current plan, permissions, provider mode, and feature flags.
- User/provider separation rules are explicit.
- Deep-link guard rules are documented.
- No Flutter routes or shell code are changed by this document.

## 12. Risks

- Changing the shell without compatibility redirects can break existing deep links and manual QA paths.
- Current active plan selection is implicit; implementation must introduce one current-plan source carefully.
- Guest-first navigation requires local data migration planning before code changes.
- Provider shell may depend on admin/provider status flows that still need operations blueprint.
- Hiding duplicate CTAs can accidentally hide needed MVP actions unless the operation-entry table is followed.

## 13. Next Implementation Notes

- Next stage: Data Model Blueprint.
- Before writing Data Model Blueprint, read `backend/prisma/schema.prisma`.
- Do not implement route/shell changes yet.
- Navigation implementation should wait for State Management, Single Source of Truth, Auth Guest Strategy, Feature Flags, and Mobile Implementation Plan.

