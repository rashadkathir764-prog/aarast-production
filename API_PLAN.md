# API Plan

This document describes planned API modules and endpoints at a high level only. It does not implement endpoints or define final route contracts.

The frozen MVP backend API contract for Flutter integration is documented in `API_CONTRACT.md`.

## API Principles

- Keep response formats consistent.
- Protect private wedding-plan and financial data by ownership and sharing rules.
- WeddingPlan APIs require persistence and authenticated ownership before implementation.
- API readiness order is Prisma + PostgreSQL foundation, User model, Auth foundation, ownership context, then WeddingPlan APIs.
- Do not use mock-auth shortcuts for WeddingPlan ownership.
- Private owner-scoped APIs must compare the authenticated user id with the resource `ownerUserId` before returning or mutating private data.
- Keep admin-only operations separated from public/customer flows.
- Smoke test critical modules before expanding scope.
- Treat marketplace APIs as supporting the Wedding Financial OS, not replacing it.
- Do not introduce payment processing, deposit confirmation, loan, credit, or financing endpoints in the MVP.

## Existing-Style Foundation Modules

| Module | Planned API Surface |
| --- | --- |
| Auth | Future Auth foundation after the User model exists; register, login, refresh session, logout, and current-user behavior must not be implemented during User model design alignment. |
| Users | Planned around the minimal MVP User shape: `id`, `name`, `phone`, `email`, `role`, `status`, `createdAt`, and `updatedAt`. `passwordHash` is storage-only and must never be returned by APIs. Phone is important for Yemen-first usage. |
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
| Wedding Plans | Implemented protected MVP endpoints: `POST /wedding-plans`, `GET /wedding-plans/my`, `GET /wedding-plans/:id`, `PATCH /wedding-plans/:id`, and `PATCH /wedding-plans/:id/archive`. All routes require JWT. Owners have full access; shared members can read basic plan info, while update/archive requires `MANAGER`. No DELETE endpoint is implemented yet. |
| Budget Categories | Implemented protected owner-scoped endpoints to create/list categories under a WeddingPlan, update a category, and delete a category. |
| Expenses | Implemented protected owner-scoped endpoints to create/list expenses under a WeddingPlan, view a simple summary, update an expense, and delete an expense. |
| Debts | Implemented protected owner-scoped endpoints to create/list debts under a WeddingPlan, view a simple debt summary, update a debt, and delete a debt. |
| Installments | Implemented protected owner-scoped endpoints to create/list installments under a Debt, view pending/overdue installments due for a WeddingPlan, update an installment, and delete an installment. |
| Tasks | Implemented protected endpoints to create/list tasks under a WeddingPlan, update a task, and delete a task. Owners have full access; shared members can list tasks, while task create/update/delete requires `canManageTasks` or `MANAGER`. |
| Sharing | Implemented protected endpoints: `POST /wedding-plans/:weddingPlanId/shared-members`, `GET /wedding-plans/:weddingPlanId/shared-members`, `PATCH /shared-members/:id`, `DELETE /shared-members/:id`, and `GET /shared/wedding-plans`. Owners manage shared members; shared users can list plans shared with them. |
| Quote Requests | Create non-binding requests for pricing or package details tied to a plan, category, service, or package; these are not purchase orders or confirmed bookings. |
| Attachments | Future/planned upload or reference APIs for receipts, agreements, quote files, and supporting images tied to expenses, debts, installments, or quote requests. This is planning-level only and not implementation in this documentation phase. |
| Timeline | Implemented protected WeddingPlan timeline endpoint with wedding date, upcoming tasks, due debts, and due installments. Owners can view all; shared members can view task timeline items while financial due items remain hidden unless debt permissions allow them. Quote requests and booking leads are not implemented yet. |

## Future Modules

| Module | Status |
| --- | --- |
| AI Planning | Future only; no MVP implementation. |
| Payments | Future only; no MVP implementation. |
| FinTech Partnerships | Future only; no MVP implementation. |
| Internal Chat | Excluded from MVP unless explicitly approved later. |
| Advanced Analytics | Future only after core usage exists. |
