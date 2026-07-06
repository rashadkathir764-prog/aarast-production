# Aarast Mobile State Management Plan

Date: 2026-06-19
Stage: State Management Plan
Status: Planning document only

## 1. Decision

The rebuild should keep the current Provider-based architecture until a specific implementation plan proves a migration is necessary. The priority is not a new state library; the priority is a single product state model.

## 2. Current State Reality

Current mobile uses `provider` and `ChangeNotifier` classes:

- `AuthController`
- `WeddingPlansProvider`
- `DashboardSummaryProvider`
- `HomeDashboardProvider`
- `FinanceProvider`
- `DebtInstallmentProvider`
- `TaskTimelineProvider`
- `SharingProvider`
- `NotificationsProvider`
- `GuestsProvider`
- `SettingsProvider`
- `ProviderMarketplaceProvider`
- `ProviderDashboardProvider`
- `OfflineSyncService`

Current risks:

- Home and Dashboard have separate summary providers.
- Current plan is selected implicitly in `MainShell`.
- Dashboard, plan cards, and other screens can compute values independently.
- Guest/local plan state is not a first-class state yet.

## 3. Required Global State

Global app state:

- authState.
- currentUser.
- userRole.
- selectedPath: wedding user or provider.
- persona.
- currentPlan.
- guestPlan.
- location.
- syncState.
- featureFlags.
- notificationSummary.
- appSettings.

Provider mode state:

- providerProfile.
- providerStatus.
- providerNavigationState.

## 4. Required Domain State

Wedding domain:

- weddingPlans.
- currentPlanSummary.
- budgetSummary.
- taskSummary.
- guestSummary.
- providerSummary.
- notificationSummary.
- sharingSummary.

Finance domain:

- categories.
- expenses.
- debts.
- installments.
- dueInstallments.

Provider marketplace:

- cities/categories.
- provider filters.
- provider list.
- cached providers.
- quote request draft.

Offline:

- pendingSyncCount.
- lastSyncedAt.
- local-to-server ID mappings.
- sync errors.

## 5. Current Plan Rule

There must be one current-plan source.

Rules:

- Shell reads current plan from one state holder.
- Home, Money, Tasks, Providers, More use the same current plan.
- Plan switch updates all dependent summaries.
- Deep links can set current plan after access validation.
- No screen should silently choose first plan except as an explicit fallback state.

## 6. Summary State Rule

There must be one summary source per repeated value:

- days remaining.
- progress percentage.
- total budget.
- spent.
- remaining.
- debt total.
- due installments.
- tasks open/done/overdue.
- guest counts.
- provider counts.
- unread notifications.

Implementation direction:

- Create a `PlanSummary` concept or service before dashboard rewrite.
- Reuse backend summaries where available.
- Avoid computing dashboard numbers in widgets.

## 7. Guest State Rule

Guest plan state must be explicit:

- local plan id.
- persona.
- location.
- wedding date.
- priorities.
- budget.
- selected categories.
- local records.
- migration status.

Migration states:

- local_only.
- migration_pending.
- migrating.
- migrated.
- migration_failed.

## 8. Loading/Error/Empty State Rule

Each provider should expose:

- isLoading.
- errorMessage.
- noticeMessage where useful.
- hasData.
- isRefreshing if needed.

Avoid:

- blank screens.
- swallowing all errors without state.
- clearing cached data on refresh failure.

## 9. Acceptance Criteria

- Current Provider-based approach is acknowledged.
- Required global and domain states are defined.
- One current-plan rule is defined.
- One summary source rule is defined.
- Guest state and migration states are defined.
- Loading/error/empty state expectations are defined.
- No mobile code is changed.

## 10. Risks

- Replacing state library during product rebuild would widen scope.
- Leaving duplicate summary providers can preserve conflicting dashboard values.
- Guest migration without explicit state can lose data.
- Deep links can show wrong plan if current-plan state is implicit.

## 11. Next Implementation Notes

- Next stage: `docs/mobile-architecture/SINGLE_SOURCE_OF_TRUTH_PLAN.md`.
- Do not refactor providers until Mobile Implementation Plan.
- Current-plan and summary cleanup should be an early implementation slice after docs.

