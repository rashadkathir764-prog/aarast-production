# Product

Snapshot date: 2026-07-15

Aarast / اعّرست is a Yemen-first wedding planning product. The product center
is a Wedding Financial OS: wedding plans, one general budget, budget
categories, costs, payments, payment schedules, tasks, timelines, guests,
sharing, and privacy-aware family coordination.

Provider and marketplace features are support flows only at the current stage:
provider references, services, packages, favorites, reviews, quote requests,
provider portal, quote-scoped conversations, and admin approval/catalog
operations. They must remain
planning/reference and quote-lead flows until an explicit later phase approves a
broader marketplace.

The approved conversation scope is deliberately narrow: a conversation exists
only between the requester and the provider account attached to a real quote
request. It is not an open social inbox and it does not create a booking or a
financial record.

Financial planning uses one domain only:

- `WeddingPlan.estimatedBudget` is the optional general budget. A null value
  means the budget is still unset; category allocations never replace it. The
  user may save this budget before creating categories.
- `BudgetCategory` groups and allocates the general budget.
- `WeddingCost` records one agreed or immediate cost and must belong to exactly
  one budget category. It may optionally reference either an Aarast provider or
  an external party. It has no due-date field; payment timing belongs only to
  `PaymentSchedule.dueDate`.
- `CostPayment` records money that actually left the user. It belongs to one
  cost and inherits that cost's category and provider/party context.
- `PaymentSchedule` is a dated, non-reserving reminder under one cost. It does
  not deduct money, reserve outstanding balance, change totals, or block a
  direct payment. Each reminder amount is checked independently against the
  current outstanding cost when created or edited; reminders are not summed as
  reservations. Any payment that completes the cost cancels its remaining
  pending reminders.

An accepted provider offer may prefill a cost draft only after an explicit
user confirmation. Acceptance never creates a cost, payment, schedule, task,
deposit, or booking silently.

## Boundaries

Currently excluded unless explicitly approved:

- Payment processing.
- Deposits.
- Paid or confirmed bookings.
- Provider booking/payment-processing status, settlement, and gateway flows.
  This boundary does not exclude the user's own manual CostPayment ledger.
- Loans, credit, financing, or FinTech.
- Production AI planning automation.
- Open or unsolicited marketplace messaging outside a quote request.
- Marketplace checkout, commissions, subscriptions, or monetization.

## Privacy

Financial data is private by default. Budgets, categories, costs, payments,
payment schedules, attachments, private tasks, and sensitive plan details must
not be shown to shared members unless `canViewMoney` allows it. Financial write
actions require `canManageMoney`.

## Growth Order

1. Wedding Financial OS.
2. Provider references and quote leads.
3. Broader marketplace only after the planning product is stable.
4. AI and FinTech only after explicit product, privacy, legal, and operational
   review.
