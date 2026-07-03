# MVP Scope

## Current MVP Status - 2026-06-14

The current implementation has moved beyond the original planning-only docs and now includes the core Wedding Financial OS backend and Flutter flows, plus limited provider marketplace/reference flows:

- Implemented: auth, WeddingPlan, budget categories, expenses, debts, installments, tasks, timeline, sharing, and privacy-aware member permissions.
- Implemented: provider city/category/provider/service/package references, favorites, reviews, quote requests, provider application/dashboard, and admin provider approval/catalog/user management.
- Implemented for mobile: SQLite offline cache and sync queue for selected safe reads/writes.
- Partial: production routing is live for the API and current admin domain, but the target split between `aarast-admin.shadowgardn.com` and `aarast.shadowgardn.com` is not fully reflected by the committed Compose file.
- Blocked/pending: Meta WhatsApp production OTP/provider verification is not implemented; OTP remains provider-agnostic/local unless an official provider is approved.

The MVP still excludes payment processing, deposits, confirmed bookings, payment status, loans, credit, financing, AI planning automation, and internal chat.

## MVP Goal

The MVP should prove that Aarast can help a Yemen-based groom, bride, or close family member understand and control wedding financial and planning clarity before the marketplace or AI layers become the main focus.

## Included In MVP

- User authentication and basic account management.
- City and category foundations.
- Basic provider and service visibility only for planning references and early quote/lead context, not a full marketplace, paid booking, or confirmed deposit flow.
- Wedding plan creation.
- Budget categories.
- Expense tracking.
- Debt tracking.
- Installment tracking.
- Task tracking.
- Timeline or due-date tracking for important wedding items.
- Shared members for groom, bride, and family collaboration with privacy-aware access.
- Basic favorites or saved providers/services if marketplace data exists.
- Smoke-tested API behavior for critical units before expanding features.
- Simple admin management for vendors/services where required.

## Explicitly Excluded From MVP

- Payment processing.
- FinTech implementation.
- Loan, credit, or financing products.
- AI recommendations or AI planning automation.
- Internal chat.
- Full marketplace optimization.
- Complex vendor bidding.
- Advanced analytics.
- Advanced Flutter animations and premium UI polish, while still requiring a clean, usable, Arabic-first MVP interface.
- Multi-country support.

## MVP Target User

The first target user is a Yemen-based groom, bride, or close family member who is responsible for planning wedding costs, obligations, tasks, and provider decisions. The user may be coordinating with family members and comparing providers, but their main problem is financial and planning clarity.

## Success Criteria

- A user can create a wedding plan and understand the expected total budget.
- A user can record expenses, debts, and installments clearly.
- A user can see what is paid, unpaid, due soon, and overdue.
- A user can track tasks, responsibilities, and due dates.
- Shared members can collaborate without exposing unrelated private data, sensitive financial details, debts, installments, or private tasks.
- Core API units have smoke-test coverage before the project expands.
- The product direction remains Wedding Financial OS first, marketplace second.
