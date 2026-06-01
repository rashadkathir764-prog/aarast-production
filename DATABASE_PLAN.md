# Database Plan

This document describes planned entities at a planning level only. It does not define migrations, schema syntax, indexes, or implementation details.

## Current And Marketplace Entities

| Entity | Purpose |
| --- | --- |
| User | Represents a person using Aarast, such as groom, bride, family member, provider, or admin. |
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
| WeddingPlan | The main planning record for a wedding, owned or shared by users. |
| BudgetCategory | Groups planned spending, such as hall, gold, furniture, clothing, photography, salon, transport, food, or gifts. |
| Expense | Records actual or expected payments tied to the wedding plan and optionally a budget category or provider. |
| Debt | Tracks money owed for wedding-related obligations. |
| Installment | Tracks scheduled payments for a debt, package, service, or other wedding obligation. |
| Task | Tracks planning work, responsibility, due dates, and completion status. |
| SharedMember | Represents a groom, bride, family member, or helper invited into a wedding plan with defined access. |
| QuoteRequest | Represents a request sent to one or more providers for pricing or package details. |
| Attachment | Represents an optional supporting file or image for expenses, debts, installments, quote requests, or provider agreements. This is planning-level only and does not require implementation in the Docs Foundation phase. |

## Planning Principles

- WeddingPlan is the center of the MVP data model.
- Every WeddingPlan must have clear ownership.
- Shared access must be permission-based, not full access by default.
- Financial data such as expenses, debts, and installments must be private by default.
- Marketplace entities support planning and quote/lead context; they must not replace the financial planning core.
- No payment, deposit, confirmed booking, loan, credit, or financing data should be added until explicitly approved in a later phase.
- Database migrations are outside the Docs Foundation task.
