# Product

Snapshot date: 2026-07-05

Aarast / اعّرست is a Yemen-first wedding planning product. The product center
is a Wedding Financial OS: wedding plans, budget categories, financial
commitments, payment records, expenses, manual debts, installments, tasks,
timelines, guests, sharing, and privacy-aware family coordination.

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

Financial planning now uses `FinancialCommitment` as the backbone for agreed
costs. Every agreed amount must belong to a budget category and may also point
to a provider, quote, plan-provider link, payment record, installment, manual
debt, or invoice-like note. A provider offer acceptance may suggest creating a
financial commitment, but it must not create one silently.

## Boundaries

Currently excluded unless explicitly approved:

- Payment processing.
- Deposits.
- Paid or confirmed bookings.
- Payment status flows.
- Loans, credit, financing, or FinTech.
- Production AI planning automation.
- Open or unsolicited marketplace messaging outside a quote request.
- Marketplace checkout, commissions, subscriptions, or monetization.

## Privacy

Financial data is private by default. Financial commitments, payment records,
expenses, debts, installments, attachments, private tasks, and sensitive plan
details must not be shown to shared members unless explicit permissions allow
it.

## Growth Order

1. Wedding Financial OS.
2. Provider references and quote leads.
3. Broader marketplace only after the planning product is stable.
4. AI and FinTech only after explicit product, privacy, legal, and operational
   review.
