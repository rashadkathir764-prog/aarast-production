# Aarast Mobile Premium Roadmap

Snapshot date: 2026-07-14

This active roadmap records the current product and visual contract. Commit
history and removed screen names are not a source of truth. The live code,
`docs/project/PRODUCT.md`, `docs/frontend/MOBILE.md`, and the QA contracts own
the implementation details.

## Product Direction

Aarast is an Arabic-first Wedding Financial OS. Premium means clear, honest,
compact, and dependable on a real phone. It does not mean adding decorative
cards, duplicate actions, or accounting vocabulary the user must learn.

Every user-facing money surface uses only these concepts:

- `الميزانية`: the optional general plan budget.
- `التصنيف`: a user-created group and optional allocation inside the budget.
- `التكلفة`: an agreed or immediate cost assigned to exactly one category.
- `الدفعة`: money actually paid against one cost.
- `موعد الدفع`: a dated reminder under one cost; it is not paid money.

The implementation domain is `WeddingCost`, `CostPayment`, and
`PaymentSchedule`. Removed expense, commitment, financial-payment, installment,
and debt domains are not compatibility paths and must not reappear in screens,
routes, providers, caches, tests, copy, or generated references.

## Money Information Architecture

The Money root answers three questions without requiring accounting knowledge:

1. What is my budget and how much remains?
2. What costs do I have and how much is still unpaid?
3. What payment date is next?

Its visible structure is:

1. One budget card. When unset it says so and offers setup; category allocation
   totals never impersonate the general budget.
2. Compact category cards with allocation, confirmed cost, paid, and remaining
   only when those values are meaningful.
3. Costs, with clear paid/outstanding state and optional provider or external
   party context.
4. Upcoming payment dates.
5. Payment history inside each cost only; the root has no recent-operations
   section.

The root FAB contains only `إضافة تكلفة` and remains available before a general
budget is configured.
Budget editing belongs to the budget card. A payment chooses a cost and inherits
its category and provider/party; it never asks the user to classify the same
money twice.

## Required Money Screens

The complete routed surface is:

- Money overview.
- Set or edit general budget.
- Create or edit category.
- Category details with its costs and totals.
- Costs list.
- Create or edit cost, including inline category creation.
- Cost details with payments and payment dates.
- Record payment.
- Payment details and append-only reversal.
- Create or edit payment date.
- Payment-date details and explicit pay action.

An accepted plan-scoped quote already has one automatically created cost. The
marketplace opens that record instead of offering a second manual cost draft. A
cost always requires one category and may optionally reference either an Aarast
provider or an external party, never both.

## Cross-Screen Design Contract

Every screen must:

- preserve Arabic RTL reading order and natural Arabic copy;
- use the plan currency dynamically and consistently;
- fit at 320px width with 1.3 text scale without overflow;
- expose one clear primary action and avoid duplicate FAB/card actions;
- use the shared header, spacing, typography, buttons, cards, and state system;
- show real loading, empty, error/retry, offline, pending-sync, read-only, and
  denied states where applicable;
- hide all write actions without `canManageMoney` and load no private values
  without `canViewMoney`;
- clear plan-scoped money state before loading a different plan;
- never present a schedule as paid or add it to totals before a payment exists.

Visual polish may not hide invalid or incomplete states. Null is displayed as
unset, not zero. Hidden financial values are absent, not replaced by zeros.

## Definition Of Done

A money screen or flow is complete only when all of the following pass:

1. Product contract and navigation review.
2. Real backend and offline mapping contract tests.
3. Permission tests for owner, viewer, manager, and denied member.
4. Fresh, empty, healthy, near-limit, over-budget, paid, outstanding, reversed,
   cancelled, offline, pending, error, and retry states as relevant.
5. 320px RTL and 1.3 text-scale widget coverage.
6. Golden coverage of the actual routed screen, not an isolated hero widget.
7. `flutter analyze` and the complete mobile test suite.
8. Physical-device verification for the end-to-end critical flow.

No document or test may call a screen `10/10` merely because it builds or an
isolated widget looks correct. Completion is evidence-based and applies to the
whole routed flow.

## Other Product Surfaces

Tasks, guests, sharing, providers, quotes, provider operations, account, and
support continue to use the same design contract. Provider flows remain
planning/reference and quote-started: multiple requests may share one
plan/provider conversation, but there is no silent booking, deposit, payment
processing, financing, or open unsolicited messaging.

## Current Execution Order

1. Finish the destructive prelaunch money-domain cleanup across backend,
   mobile, offline cache, tests, and generated documentation.
2. Close the complete Money QA gate above.
3. Re-run full backend, mobile, admin, documentation, and Docker quality gates.
4. Continue non-finance premium work only after the canonical Money flow is
   stable, so visual work cannot preserve obsolete product behavior.
