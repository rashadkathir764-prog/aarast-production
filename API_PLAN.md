# API Plan

This document describes planned API modules and endpoints at a high level only. It does not implement endpoints or define final route contracts.

## API Principles

- Keep response formats consistent.
- Protect private wedding-plan and financial data by ownership and sharing rules.
- WeddingPlan APIs require persistence and authenticated ownership before implementation.
- Keep admin-only operations separated from public/customer flows.
- Smoke test critical modules before expanding scope.
- Treat marketplace APIs as supporting the Wedding Financial OS, not replacing it.
- Do not introduce payment processing, deposit confirmation, loan, credit, or financing endpoints in the MVP.

## Existing-Style Foundation Modules

| Module | Planned API Surface |
| --- | --- |
| Auth | Register, login, refresh session, logout, current user. |
| Users | Profile reads and safe profile updates. |
| Cities | List active Yemen cities and admin city management. |
| Categories | List active service categories and admin category management. |
| Providers | Public provider listing/details and provider profile management. |
| Services | Public service listing/details and provider/admin service management. |
| Bookings | Non-binding booking leads or interest requests only if already present. MVP Bookings must not include paid booking, confirmed reservation, deposit, or payment status. |
| Favorites | Save and remove providers or services for comparison. |
| Reviews | Later marketplace-phase APIs for creating, listing, or moderating reviews unless already present. Reviews are not required for the Wedding Financial OS MVP. |
| Packages | Provider service bundles used only as planning references and quote context in the MVP, with no purchase, deposit, or confirmed package booking. |
| Admin | Protected management endpoints or admin-panel routes for core resources. |

## Wedding Financial OS Modules

| Module | Planned API Surface |
| --- | --- |
| Wedding Plans | First Wedding Financial OS domain API after persistence and authenticated ownership are ready. Initial shape is limited to owner, title, city, wedding date, estimated budget, currency, status, and timestamps. |
| Budget Categories | Define planned budget groups and target amounts. |
| Expenses | Add, update, list, and summarize wedding expenses. |
| Debts | Track owed amounts, creditors, due dates, and status. |
| Installments | Track scheduled payments and payment status. |
| Tasks | Create, assign, complete, and filter wedding tasks. |
| Sharing | Invite shared members and manage access levels. |
| Quote Requests | Create non-binding requests for pricing or package details tied to a plan, category, service, or package; these are not purchase orders or confirmed bookings. |
| Attachments | Future/planned upload or reference APIs for receipts, agreements, quote files, and supporting images tied to expenses, debts, installments, or quote requests. This is planning-level only and not implementation in this documentation phase. |
| Timeline | Show due dates for tasks, debts, installments, quote requests, booking leads if present, and key wedding events. |

## Future Modules

| Module | Status |
| --- | --- |
| AI Planning | Future only; no MVP implementation. |
| Payments | Future only; no MVP implementation. |
| FinTech Partnerships | Future only; no MVP implementation. |
| Internal Chat | Excluded from MVP unless explicitly approved later. |
| Advanced Analytics | Future only after core usage exists. |
