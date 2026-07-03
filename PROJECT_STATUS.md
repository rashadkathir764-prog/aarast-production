# Project Status Snapshot

This is a historical audit snapshot imported from `aarast-production/main`.
Do not treat it as current release readiness without rerunning the checks on the
active branch and runtime.

Audit date: 2026-06-14
Repository root at audit time: `D:\projects\aarast`
Observed branch at audit time: `main`
Requested/context branch: `phase/frontend-rebuild-v1`
Latest important mobile commit in request: `7ba8d42 feat(mobile): add SQLite offline cache and sync queue`

## Module Status

| Module | Status | Notes |
| --- | --- | --- |
| Backend | DONE | NestJS + Prisma + PostgreSQL with auth, Wedding Financial OS, sharing, marketplace references, provider dashboard, admin APIs, and smoke scripts. |
| Mobile | DONE/PARTIAL | Flutter core planning flows, provider marketplace screens, and SQLite offline cache/sync queue are implemented. Needs continued visual QA and production API build verification. |
| Admin Web | PARTIAL | React/Vite dashboard, provider approval/catalog/user flows are implemented. Bookings/settings/payments/notifications/reports are partial or placeholder screens where backend endpoints are missing. |
| PostgreSQL | DONE | Prisma schema and migrations exist for current backend source of truth. |
| SQLite Offline Layer | DONE/PARTIAL | Implemented for safe mobile cache and selected queued writes. First login and sensitive/admin/provider-dashboard operations remain online-only. |
| Deployment | IN PROGRESS | API and current admin domain responded during audit; target admin/mobile domain split is not fully configured in Compose. |
| Meta WhatsApp OTP | BLOCKED | Provider-agnostic OTP exists; Meta WhatsApp production delivery needs business verification, provider wiring, and secure secrets. |
| Payments/Deposits/FinTech/AI/Chat | NOT STARTED | Explicitly excluded unless approved later. |

## Backend Status

Implemented:

- `GET /health`
- Auth register/login/me and OTP request/verify.
- Profile/settings endpoints.
- WeddingPlan, BudgetCategory, Expense, Debt, Installment, Task, Timeline, Sharing.
- City/category/provider/service/package references.
- Favorites, reviews, quote requests.
- Provider application/dashboard.
- Admin dashboard stats, provider approval workflow, cities/categories/users/providers.

Limitations:

- No payment processing, deposits, confirmed booking flow, loans, credit, financing, AI, or internal chat.
- BookingLead exists in the Prisma schema, but public/admin booking-lead management is not fully exposed.
- OTP is local/provider-agnostic; no production WhatsApp/SMS provider is wired.

## Mobile Status

Implemented:

- Arabic-first RTL Flutter app.
- Auth, onboarding, WeddingPlan dashboard, finance, debts/installments, tasks/timeline, sharing, marketplace, provider application/dashboard screens.
- SQLite-backed local cache/sync queue on supported mobile platforms.
- JSON fallback for web/test.
- Offline UI indicators and selected queued writes.

Limitations:

- First login requires internet.
- Web fallback is not SQLite.
- Provider dashboard/admin/shared-member permission writes remain online-only.
- Remote images may not be available offline.

## Admin Web Status

Implemented:

- Admin login with JWT role check.
- Dashboard stats.
- Provider applications/details and approval actions.
- Providers, categories, cities, users, services, reviews pages.

Partial:

- Bookings page is a backend-required placeholder.
- Settings page is read-only/API-required.
- Sidebar links exist for payments, notifications, and reports, but matching routes/endpoints are not complete.
- Admin production target domain `aarast-admin.shadowgardn.com` returned HTTP 502 during this audit.

## Deployment Status

Current committed Compose:

| Service | Host -> Container | Domain |
| --- | --- | --- |
| Backend | `8093 -> 3000` | `https://aarast-api.shadowgardn.com` |
| Admin Web | `8095 -> 80` | currently `https://aarast.shadowgardn.com` |
| Flutter Web | not configured | target `https://aarast.shadowgardn.com` |

Historical live checks on 2026-06-14:

- `https://aarast-api.shadowgardn.com/health`: HTTP 200.
- `https://aarast.shadowgardn.com/`: HTTP 200.
- `https://aarast-admin.shadowgardn.com/`: HTTP 502.

## Known Blockers

- Align Dokploy/NPM/Compose with target domain split: API `8093`, Admin `8094`, Flutter Web `8095`.
- Fix `aarast-admin.shadowgardn.com` 502 by checking upstream service/port mapping.
- Add a separate Flutter web deployment service if `aarast.shadowgardn.com` should serve mobile/web instead of admin.
- Complete Meta WhatsApp business verification/provider integration before production WhatsApp OTP.
- Add backend/admin endpoints before activating booking/payment/report/notification admin pages.

## Next Recommended Tasks

1. Verify Dokploy service ports and NPM forward hosts.
2. Fix `aarast-admin.shadowgardn.com` 502.
3. Recheck `https://aarast-api.shadowgardn.com/health` after any deployment changes.
4. Add/deploy Flutter web with production API URL if `aarast.shadowgardn.com` should be the public mobile web app.
5. Continue admin UI polish and remove or gate placeholder nav items.
6. Resume Meta verification after official site/domain and business requirements are ready.
