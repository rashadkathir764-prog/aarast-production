# Backend Phase 3 - Dashboard Summary API

Date: 2026-06-19
Status: Implemented

## Scope

Phase 3 adds a wedding-plan dashboard summary endpoint for the mobile app. The endpoint calculates values from real backend records and does not generate fake dashboard data.

No Flutter UI, admin-web code, payments, deposits, bookings, AI, maps, push, or production configuration was changed.

## Endpoint

New mobile contract:

- `GET /api/v1/wedding-plans/:planId/dashboard-summary`

Compatibility endpoint:

- `GET /wedding-plans/:planId/dashboard-summary`

Existing endpoint preserved:

- `GET /dashboard/home`

## Response Fields

The endpoint returns:

- `planId`
- `title`
- `weddingDate`
- `city`
- `status`
- `daysRemaining`
- `progressPercentage`
- `budgetTotal`
- `spentTotal`
- `remainingBudget`
- `debtTotal`
- `paidDebtTotal`
- `unpaidDebtTotal`
- `dueInstallmentsCount`
- `totalTasks`
- `completedTasks`
- `overdueTasks`
- `todayTasks`
- `guestCount`
- `confirmedGuests`
- `providerCount`
- `quoteRequestsCount`
- `unreadNotificationsCount`
- `currentUserRole`
- `permissions`

## Calculation Rules

- `daysRemaining` is calculated from `WeddingPlan.weddingDate`; it is `null` when no date exists.
- `progressPercentage` is based on completed tasks divided by total tasks.
- `budgetTotal` uses `WeddingPlan.estimatedBudget` first, then budget category targets if no estimated budget exists.
- `spentTotal` uses paid expenses only.
- `remainingBudget` is `budgetTotal - spentTotal`.
- Debt totals exclude cancelled debts.
- `dueInstallmentsCount` counts pending or overdue installments due today or earlier.
- `todayTasks` counts non-done, non-cancelled tasks due today.
- `overdueTasks` counts non-done, non-cancelled tasks due before today.
- Guest counts are calculated from real `Guest` rows.
- `quoteRequestsCount` is calculated from real `QuoteRequest` rows for the plan.
- `providerCount` remains `0` until a real plan-provider link model exists in a later phase.
- `unreadNotificationsCount` counts unread notifications owned by the current user for the plan.

## Privacy

The endpoint uses the existing `PermissionService`.

- Owner sees all summary values.
- Shared members without finance permission receive `null` for private finance values.
- Task and guest counts remain visible to readable plan members.
- Unauthorized users receive the same not-found behavior as other protected plan APIs.

## Smoke Coverage

Added:

- `npm run smoke:dashboard-summary`

Included in:

- `npm run smoke:all`

Covered cases:

- Empty plan summary returns real zeros.
- Populated plan summary calculates money, debt, installments, tasks, guests, and quote request count.
- Unauthorized access returns `401`.
- Unrelated user is blocked.
- Viewer permissions are included.
- Viewer finance values are hidden.

## Verification

Expected commands for this phase:

- `npm.cmd run check`
- `npx.cmd prisma validate`
- `npm.cmd run smoke:dashboard-summary`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`

No Prisma migration is required for Phase 3.
