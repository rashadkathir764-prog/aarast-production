# Database Plan

This document describes the product data model at a planning/status level. It does not replace `backend/prisma/schema.prisma` as the schema source of truth.

Current documentation snapshot: 2026-06-21. Route-level behavior belongs in `API_CONTRACT.md`.

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents a person using Aarast, such as groom, bride, family member, provider, or admin. `phone` is important for Yemen-first usage. `passwordHash` must store hashed passwords only, never plaintext passwords. Current roles include `USER`, `ADMIN`, and `PROVIDER`; provider flows are implemented as planning/reference and quote-lead flows, not paid marketplace or confirmed booking flows. |
| Provider | Represents a vendor or business that offers wedding-related services. |
| Service | Represents a specific service offered by a provider, such as hall rental, photography, salon, catering, or decoration. |
| Category | Groups services into discoverable wedding-service categories. |
| City | Supports Yemen-specific location filtering and local availability. |
| Booking | Represents an existing or future booking/lead record. In the MVP, this means non-binding interest or lead tracking only, not paid booking, confirmed reservation, or deposit. |
| Favorite | Lets users save providers or services for later comparison. |
| Review | Captures user feedback about a provider/service reference. Reviews are implemented as provider-reference support, not as paid marketplace monetization. |
| Package | Represents bundled provider offerings, such as full hall packages or photography packages. |

## Wedding Financial OS Entities

| Entity | Purpose |
| --- | --- |
| WeddingPlan | The main planning record for a wedding. The Prisma model and owner-scoped API are implemented with `ownerUserId`, `title`, `city`, `weddingDate`, `estimatedBudget`, `currency`, `status`, `createdAt`, and `updatedAt`. |
| Notification | Implemented for persisted user-owned alerts with optional WeddingPlan context, type, title, body, JSON data, read timestamp, dedupe key, and timestamps. Notifications are private to the authenticated user. |
| BudgetCategory | Implemented for owner-scoped WeddingPlan budget groups, with optional target amounts and links to expenses. |
| Expense | Implemented for owner-scoped WeddingPlan spending records with amount, status, optional date, optional note, and optional BudgetCategory link. |
| Debt | Implemented for owner-scoped WeddingPlan obligations, including creditor, optional manually entered creditor phone, title, total amount, paid amount, optional due date, status, and optional note. Contact picking is not implemented in Phase 2A. |
| Installment | Implemented for owner-scoped scheduled payments under debts, including amount, optional due date, optional paid date, status, and optional note. |
| Task | Implemented as `WeddingTask` for owner-scoped WeddingPlan planning work, including title, optional description, optional due date, status, priority, checklist/assignment support, and timestamps. |
| WeddingTaskChecklistItem | Implemented for task checklist rows tied to a WeddingTask. |
| SharedMember | Implemented for permission-based WeddingPlan collaboration. A shared member links a User to a WeddingPlan with role `VIEWER`, `CONTRIBUTOR`, or `MANAGER`, plus explicit permissions for budget, expenses, debts, task management, and financial-record management. |
| PlanInvite | Implemented for invite-token based sharing and acceptance flows. |
| Guest | Implemented for WeddingPlan guest management with name, optional phone, side, invitation status, seats count, optional notes, and timestamps. |
| GuestGroup | Implemented for grouping WeddingPlan guests. |
| QuoteRequest | Implemented for non-binding pricing/package requests tied to a user, provider, service/category/city, and optionally a WeddingPlan. |
| QuoteOffer | Implemented for provider responses to quote requests. Accepting/rejecting an offer is a planning decision only, not a paid booking. |
| PlanProviderLink | Implemented to connect an accepted provider/offer to a WeddingPlan as planning context. |
| Attachment | Represents an optional supporting file or image for expenses, debts, installments, quote requests, or provider agreements. This is planning-level only and does not require implementation in the Docs Foundation phase. |

## Planning Principles

- WeddingPlan is the center of the MVP data model.
- WeddingPlan implementation depends on database persistence and an authenticated user context.
- Persistence/Auth readiness work has already moved past the original docs-only foundation. Future schema changes must still be explicit, phased, migrated, and smoke-tested.
- WeddingPlan remains the first Wedding Financial OS domain module after persistence and ownership prerequisites are ready.
- WeddingPlan now has implemented BudgetCategory, Expense, Debt, WeddingTask, and SharedMember relations.
- Every WeddingPlan must have clear ownership.
- WeddingPlan ownership must not rely on a mock-auth shortcut; ownership must come from authenticated user context.
- Owner-scoped records should use an explicit `ownerUserId` pattern and must be checked against the authenticated user before private access.
- Shared access must be permission-based, not full access by default.
- Financial data such as expenses, debts, and installments must be private by default.
- SharedMember permissions are implemented as a backend slice; financial endpoints remain protected and must not expose expenses, debts, or installments to shared members unless permissions explicitly allow it in an approved endpoint flow.
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment, deposit, confirmed booking, loan, credit, or financing data should be added until explicitly approved in a later phase.
- Production migrations and Docker/Dokploy deployment work remain separate from docs-only tasks unless explicitly requested.
- New database migrations are outside docs-only tasks.

## Implemented Provider Reference Foundation

The backend now includes the approved provider-reference and quote-lead foundation:

- `OtpCode` for provider-agnostic local OTP request/verify flows, storing only hashed codes.
- User profile additions: `phoneVerifiedAt`, `lastLoginAt`, `avatarUrl`, and `locale`.
- `NotificationPreference` for safe default account settings.
- `Notification` for persisted task, installment, sharing, and quote alerts with deduplication.
- `Guest` and `GuestGroup` for saved WeddingPlan guest lists and grouping.
- `City` and `ProviderCategory` for Yemen-first marketplace filters.
- `Provider`, `ProviderService`, `ProviderServiceImage`, and `ProviderPackage` for public planning references.
- `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `QuoteOffer`, `PlanProviderLink`, and `BookingLead` for saved providers, reviews, quote leads, accepted planning provider links, and non-paid lead context.
- `WeddingTaskChecklistItem` plus task assignment support.
- `PlanInvite` for invite-based collaboration.

These models do not add payment processing, deposits, confirmed reservations, loans, credit, or financing behavior.
