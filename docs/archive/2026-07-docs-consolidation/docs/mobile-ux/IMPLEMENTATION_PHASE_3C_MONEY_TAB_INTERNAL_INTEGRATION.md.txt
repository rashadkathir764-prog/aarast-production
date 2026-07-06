# Phase 3C - Money Tab Internal Integration Behind Feature Flag

Date: 2026-06-19
Scope: Internal Money tab content inside `UserRebuildShell` only
Status: Ready for review

## What Was Connected Inside Money Tab

- Added `UserRebuildMoneyTab` as an internal-only Money tab surface under `mobile/lib/features/shell/rebuild/`.
- Connected `UserRebuildShell` so `UserRebuildTab.money` renders the dedicated Money tab content instead of the generic placeholder.
- The internal Money tab describes the future finance areas:
  - الميزانية
  - المصروفات
  - الديون
  - الأقساط
- When no current plan exists, it shows the safe internal no-plan message:
  - "تبويب المال التجريبي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات"
- Added a safe no-finance-permission placeholder path for later permission wiring.

## Why There Is No User-Facing Behavior Change

- `enableNewUserBottomNavigation` remains `false` by default.
- `/dev/user-navigation-shell` remains guarded by the feature flag.
- The active `/home` route still opens the current `MainShell`.
- The new Money tab is reachable only inside the guarded internal shell when the flag is explicitly enabled for development.

## Why No Fake Plan ID Was Used

Phase 3C does not have a real current-plan source for the rebuild shell yet. Passing a fake `planId` to existing finance screens would hide missing state wiring and could accidentally call real finance APIs with invalid data.

The Money tab therefore renders a no-plan internal placeholder until a real current-plan contract exists.

## Why No Backend Was Called

This phase is a UI contract step inside the experimental shell only. It does not instantiate `BudgetExpenseScreen`, `FinanceProvider`, debt providers, API clients, or any backend-backed screen.

## What Remains For The Next Phase

- Add internal content for the remaining rebuild tabs if approved.
- Define a real current-plan source for the rebuild shell.
- Define finance permission inputs before exposing real budget, expenses, debts, or installments.
- Connect `BudgetExpenseScreen` only after a safe current `planId` and permission contract exist.

## Acceptance Criteria

- Current branch is not `main`.
- `enableNewUserBottomNavigation` remains disabled by default.
- `/dev/user-navigation-shell` remains guarded.
- Default app route remains unchanged.
- `/home` behavior remains unchanged.
- `MainShell` remains unchanged.
- Money tab exists inside `UserRebuildShell`.
- Money tab shows the safe no-plan internal placeholder when no current plan exists.
- No fake `planId` is used.
- No backend calls are introduced.
- No backend, Prisma, admin-web, deployment, payment, AI, subscriptions, maps, analytics, or notification-permission behavior was added.

## Risks

- The Money tab is still a contract placeholder and does not prove real finance screen readiness.
- Future integration must not connect `BudgetExpenseScreen` until a real current plan ID exists.
- Future permission wiring must preserve private-by-default financial visibility for shared members.

## Next Step

Recommended next step:

```text
Phase 3D - Remaining tabs internal integration
```

Alternative if state readiness is prioritized:

```text
Phase 4 - Single Source of Truth readiness
```
