# Aarast Mobile Single Source Of Truth Plan

Date: 2026-06-19
Stage: Single Source of Truth Plan
Status: Planning document only

## 1. Decision

Any value shown in more than one place must come from one source, one calculation rule, and one permission-aware summary path.

No widget should invent progress, days remaining, budget totals, debt state, guest counts, provider counts, or unread notification counts.

## 2. Current Risks

Observed current risks:

- `MyWeddingPlansScreen` contains mock progress and days-left values for visual effect.
- `HomeDashboardProvider` and `DashboardSummaryProvider` aggregate similar data separately.
- Dashboard widgets calculate task progress and budget percentages locally.
- Provider/guest summary data is not yet unified.

## 3. Required Canonical Values

| Value | Canonical source direction |
|---|---|
| Current plan | App current-plan state |
| Days remaining | Plan summary/date utility from `WeddingPlan.weddingDate` |
| Progress percentage | Task/plan summary service |
| Total budget | WeddingPlan estimated budget or budget summary |
| Spent amount | Expense summary |
| Remaining budget | Budget summary calculation |
| Debt total | Debt summary |
| Paid debt | Debt summary |
| Remaining debt | Debt summary |
| Due installments | Installment due endpoint/summary |
| Open/done/overdue tasks | Task summary/timeline |
| Guest counts | Guest summary |
| Saved providers | Provider summary/favorites |
| Quote request counts | Quote summary |
| Unread notifications | Notification unread count |
| Pending sync count | Offline sync service |

## 4. Summary Object Direction

Future `PlanSummary` should include:

- plan id/title/status.
- date/days remaining.
- location summary.
- budget summary.
- debt summary.
- task summary.
- guest summary.
- provider/quote summary.
- sharing summary.
- notification summary.
- sync summary.
- permission visibility flags.

This can be assembled client-side first from existing endpoints, then backed by a server summary endpoint later if needed.

## 5. Permission-Aware Summaries

Rules:

- If user cannot view budget, budget values are hidden everywhere.
- If user cannot view expenses, spent/remaining values are hidden or reduced to allowed states.
- If user cannot view debts, installment/debt warnings are hidden.
- Task summaries can show only accessible tasks if future task privacy exists.
- Notifications must not reveal hidden details in previews.

## 6. Widget Rules

Widgets may format values, not calculate domain truth.

Allowed in widgets:

- Formatting date.
- Formatting money.
- Choosing visual color based on summary status.
- Showing empty/loading/error state.

Not allowed in widgets:

- Hardcoded progress percentages.
- Hardcoded days remaining.
- Independent budget math when summary exists.
- Fake provider/guest counts.
- Permission bypass calculations.

## 7. Implementation Sequence Later

1. Create summary model(s).
2. Centralize current-plan state.
3. Replace mock values in plan cards.
4. Replace dashboard local summary calculations.
5. Make Home, Money, Tasks, Providers, More consume summary.
6. Add tests for hidden financial values.
7. Add backend summary endpoint only if client aggregation is insufficient.

## 8. Acceptance Criteria

- Canonical values are listed.
- Summary object direction is defined.
- Permission-aware rules are defined.
- Widget calculation boundaries are defined.
- Implementation sequence is documented.
- No code is changed.

## 9. Risks

- Centralizing summaries can touch many screens; implementation must be incremental.
- Server summary endpoint can duplicate existing APIs if added too early.
- Hidden financial values must remain hidden in summary data, not only UI.
- Offline summaries need clear stale/pending labels.

## 10. Next Implementation Notes

- Next stage: `docs/mobile-ux/ERROR_LOADING_EMPTY_STATES_GUIDE.md`.
- Do not change dashboard or plan card code until Mobile Implementation Plan.

