# API Plan

This document describes API modules at a high level. It does not define final route contracts.

The current route-level source of truth is `API_CONTRACT.md`. Do not copy full endpoint lists into this planning file.

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
| Auth | Implemented register/login/current user plus OTP helpers. `passwordHash` is storage-only and must never be returned by APIs. |
| Users | Implemented current-user profile/settings helpers and lookup support for collaboration flows. Phone remains important for Yemen-first usage. |
| Cities | Implemented active Yemen city references plus admin city management. |
| Categories | Implemented provider category references plus admin category management. |
| Providers | Implemented public provider listing/details, provider profile/dashboard management, and admin review operations. |
| Services | Implemented public service reads and provider/admin service management. |
| Bookings | Not an active product flow. Booking-like data must remain non-binding unless explicitly approved; no paid or confirmed booking lifecycle is approved. |
| Favorites | Implemented save/remove/list provider favorites for planning comparison. |
| Reviews | Implemented provider review creation/update/delete and provider review reads. |
| Packages | Implemented provider package references for planning context only, with no purchase, deposit, or confirmed package booking. |
| Admin | Implemented protected management endpoints for dashboard stats, providers, provider categories, cities, and users; admin smoke coverage remains a follow-up. |

## Wedding Financial OS Modules

| Module | Planned API Surface |
| --- | --- |
| Wedding Plans | Implemented create/list/my/active/read/update/archive/set-active with legacy direct routes and `/api/v1` aliases. All private routes require JWT and plan access checks. |
| Onboarding | Implemented authenticated completion flow that creates real plan data and active-plan state. Guest-first drafts remain mobile/local until account gate. |
| Dashboard | Implemented plan-scoped dashboard summary with real aggregates, permissions, notifications, important items, and linked provider counts. Runtime/source alignment must be rechecked after the 2026-06-20 audit mismatch. |
| Notifications | Implemented persisted list/unread/read/read-all/delete, invite notification, quote-offer notification, and plan filtering. Notifications remain user-owned. |
| Budget Categories | Implemented protected create/list/update/delete under a WeddingPlan. |
| Expenses | Implemented protected create/list/detail/summary/update/delete. |
| Debts | Implemented protected create/list/detail/summary/update/delete. |
| Installments | Implemented protected create/list/due/pay/update/delete. |
| Money Summary | Implemented permission-aware money summary for plan-level mobile UI. |
| Tasks | Implemented create/list/detail/summary/checklist/assign/update/delete and timeline support. |
| Sharing | Implemented direct sharing, invite acceptance, role/permission updates, permission summary, and shared-plan reads. |
| Guests | Implemented create/list/detail/bulk/groups/summary/update/delete with duplicate-prevention support. |
| Quote Requests | Implemented non-binding plan/provider quote requests, provider offers, accept/reject, and plan-provider linking. These are planning leads, not purchase orders or confirmed bookings. |
| Attachments | Future/planned upload or reference APIs for receipts, agreements, quote files, and supporting images tied to expenses, debts, installments, or quote requests. This is planning-level only and not implementation in this documentation phase. |
| Timeline | Implemented protected WeddingPlan timeline endpoint with wedding date, upcoming tasks, due debts, and due installments. Owners can view all; shared members can view task timeline items while financial due items remain hidden unless debt permissions allow them. |

## Future Modules

| Module | Status |
| --- | --- |
| AI Planning | Future only; no MVP implementation. |
| Payments | Future only; no MVP implementation. |
| FinTech Partnerships | Future only; no MVP implementation. |
| Internal Chat | Excluded from MVP unless explicitly approved later. |
| Advanced Analytics | Future only after core usage exists. |

## Current Backend Completion Addendum

The backend has moved beyond the original MVP-only plan. Current source includes the backend completion phases documented in `docs/backend/BACKEND_COMPLETION_FINAL_REPORT.md`.

Keep these boundaries:

- Provider/service/package endpoints expose only approved/active references where relevant.
- User-owned quote requests, reviews, favorites, and provider dashboard records are scoped by authenticated ownership.
- Quote-offer accept/reject links providers to a plan as a planning relationship, not as a paid or confirmed booking.
- The 2026-06-20 audit still recommends tighter quote permissions, admin smoke coverage, guest read-privacy decisions, JWT secret hardening, and server-side phone normalization.
- Route-level details belong in `API_CONTRACT.md`.
