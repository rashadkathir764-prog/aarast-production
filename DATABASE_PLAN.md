# Database Plan

This document describes planned entities at a planning level only. It does not define migrations, schema syntax, indexes, or implementation details.

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents a person using Aarast, such as groom, bride, family member, provider, or admin. The MVP User shape is planned as `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`. `phone` is important for Yemen-first usage. `passwordHash` must store hashed passwords only, never plaintext passwords. Initial roles are `USER`, `ADMIN`, and `PROVIDER`; `PROVIDER` is reserved for later provider flows and must not implement provider logic now. Initial statuses are `ACTIVE` and `DISABLED`. |
| Provider | Represents a vendor or business that offers wedding-related services. |
| Service | Represents a specific service offered by a provider, such as hall rental, photography, salon, catering, or decoration. |
| Category | Groups services into discoverable wedding-service categories. |
| City | Supports Yemen-specific location filtering and local availability. |
| Booking | Represents an existing or future booking/lead record. In the MVP, this means non-binding interest or lead tracking only, not paid booking, confirmed reservation, or deposit. |
| Favorite | Lets users save providers or services for later comparison. |
| Review | Captures user feedback about a provider or service in later marketplace phases, unless reviews already exist in the baseline. Reviews are not required for the Wedding Financial OS MVP. |
| Package | Represents bundled provider offerings, such as full hall packages or photography packages. |

## Wedding Financial OS Entities

| Entity | Purpose |
| --- | --- |
| WeddingPlan | The main planning record for a wedding. The Prisma model is implemented with `ownerUserId`, `title`, `city`, `weddingDate`, `estimatedBudget`, `currency`, `status`, `createdAt`, and `updatedAt`; API implementation is still pending. |
| BudgetCategory | Implemented for owner-scoped WeddingPlan budget groups, with optional target amounts and links to expenses. |
| Expense | Implemented for owner-scoped WeddingPlan spending records with amount, status, optional date, optional note, and optional BudgetCategory link. |
| Debt | Tracks money owed for wedding-related obligations. |
| Installment | Tracks scheduled payments for a debt, package, service, or other wedding obligation. |
| Task | Tracks planning work, responsibility, due dates, and completion status. |
| SharedMember | Represents a groom, bride, family member, or helper invited into a wedding plan with defined access. |
| QuoteRequest | Represents a request sent to one or more providers for pricing or package details. |
| Attachment | Represents an optional supporting file or image for expenses, debts, installments, quote requests, or provider agreements. This is planning-level only and does not require implementation in the Docs Foundation phase. |

## Planning Principles

- WeddingPlan is the center of the MVP data model.
- WeddingPlan implementation depends on database persistence and an authenticated user context.
- Persistence/Auth readiness order is Prisma + PostgreSQL foundation first, User model second, Auth foundation third, ownership context fourth, and WeddingPlan module after those prerequisites.
- User model design comes before Auth foundation and must stay limited to the minimal MVP identity shape.
- User model design is documentation-only until explicitly approved for Prisma schema implementation; no Prisma model or migration belongs to this design-alignment task.
- WeddingPlan remains the first Wedding Financial OS domain module after persistence and ownership prerequisites are ready.
- WeddingPlan now has implemented BudgetCategory and Expense relations; SharedMember, Debt, Installment, and Task relations are not implemented yet.
- Every WeddingPlan must have clear ownership.
- WeddingPlan ownership must not rely on a mock-auth shortcut; ownership must come from authenticated user context.
- Owner-scoped records should use an explicit `ownerUserId` pattern and must be checked against the authenticated user before private access.
- Shared access must be permission-based, not full access by default.
- Financial data such as expenses, debts, and installments must be private by default.
- SharedMember, Debt, Installment, and Task are later slices and are not part of the Budget + Expense backend slice.
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment, deposit, confirmed booking, loan, credit, or financing data should be added until explicitly approved in a later phase.
- Production migrations and Docker/Dokploy deployment work are outside the Persistence/Auth readiness planning task.
- Database migrations are outside the Docs Foundation task.
