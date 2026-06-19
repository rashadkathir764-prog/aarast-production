# Backend Phase 4 - Money APIs

Date: 2026-06-19
Status: Implemented

## Scope

Phase 4 completes the backend money API surface needed by the mobile app using the existing budget, expense, debt, and installment models.

No payment processing, deposits, subscriptions, loans, credit, FinTech behavior, Flutter UI, admin-web code, production configuration, or destructive migration was added.

## Endpoints

New `/api/v1` compatibility endpoints:

- `GET /api/v1/wedding-plans/:planId/budget-categories`
- `POST /api/v1/wedding-plans/:planId/budget-categories`
- `PATCH /api/v1/budget-categories/:id`
- `DELETE /api/v1/budget-categories/:id`
- `GET /api/v1/wedding-plans/:planId/expenses`
- `POST /api/v1/wedding-plans/:planId/expenses`
- `GET /api/v1/expenses/:id`
- `PATCH /api/v1/expenses/:id`
- `DELETE /api/v1/expenses/:id`
- `GET /api/v1/wedding-plans/:planId/debts`
- `POST /api/v1/wedding-plans/:planId/debts`
- `GET /api/v1/debts/:id`
- `PATCH /api/v1/debts/:id`
- `DELETE /api/v1/debts/:id`
- `GET /api/v1/debts/:debtId/installments`
- `POST /api/v1/debts/:debtId/installments`
- `PATCH /api/v1/installments/:id`
- `PATCH /api/v1/installments/:id/pay`
- `DELETE /api/v1/installments/:id`
- `GET /api/v1/wedding-plans/:planId/money-summary`

New unprefixed compatibility endpoints:

- `GET /expenses/:id`
- `GET /debts/:id`
- `PATCH /installments/:id/pay`
- `GET /wedding-plans/:planId/money-summary`

Existing unprefixed list/create/update/delete endpoints remain available.

## Money Summary

`GET /api/v1/wedding-plans/:planId/money-summary` returns real calculated values:

- budget total
- category target total
- paid expenses total
- planned expenses total
- cancelled expenses total
- remaining budget
- debt total
- paid debt total
- unpaid debt total
- due installment count
- overdue installment count
- categories, expenses, debts, and installments counts
- finance permission summary

The endpoint blocks members with no finance visibility. Members with partial finance permissions receive only the sections their permissions allow.

## Installment Pay

`PATCH /api/v1/installments/:id/pay`:

- requires financial management permission.
- sets installment status to `PAID`.
- sets `paidAt` if it was not already set.
- increments the parent debt `paidAmount` once when the installment was not already paid.
- updates debt status to `PARTIALLY_PAID` or `PAID` based on the resulting paid amount.

This is not a payment-processing endpoint. It records an internal payment state only.

## Rules Preserved

- JWT is required.
- Existing `PermissionService` guards remain the source of truth.
- No negative category, expense, debt, or installment amounts are accepted.
- Totals are calculated from real database records.
- Deleted records use the existing hard-delete behavior because the current schema has no `deletedAt`.
- Currency comes from the wedding plan.

## Smoke Coverage

Added:

- `npm run smoke:money-apis`

Included in:

- `npm run smoke:all`

Covered cases:

- budget category CRUD through `/api/v1`.
- expense CRUD plus `GET /api/v1/expenses/:id`.
- debt CRUD plus `GET /api/v1/debts/:id`.
- installment create/list/update/delete.
- pay installment.
- money summary calculations.
- negative expense amount rejected.
- unauthenticated access blocked.
- non-finance shared viewer blocked from money summary.

## Verification

Expected commands for this phase:

- `npm.cmd run check`
- `npx.cmd prisma validate`
- `npm.cmd run smoke:money-apis`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`

No Prisma migration is required for Phase 4.
