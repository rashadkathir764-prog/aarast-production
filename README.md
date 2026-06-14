# Aarast / اعّرست

Aarast / اعّرست is a Yemen wedding planning and provider marketplace platform. The product is still positioned as a Wedding Financial OS first: budgets, expenses, debts, installments, tasks, timelines, and shared family planning come before marketplace optimization, payments, AI, or FinTech.

## Current Architecture

| Area | Current state |
| --- | --- |
| Backend | NestJS + Prisma + PostgreSQL, with JWT auth and smoke scripts. |
| Mobile | Flutter Arabic-first app with a SQLite offline-first local layer on supported mobile platforms and a JSON fallback for web/test. |
| Admin Web | React + Vite + TypeScript admin dashboard. |
| Local Docker | Root `docker-compose.yml` runs PostgreSQL and backend. |
| Production | Dokploy Compose files exist under `deploy/dokploy/`; deployment is live for current configured domains but still needs the target admin/mobile split to be finalized. |

## Implemented Features

- Auth: register, login, `GET /auth/me`, provider-agnostic OTP request/verify, profile/settings endpoints.
- Wedding plans: owner-scoped plan creation, listing, detail, update, and archive.
- Sharing/members: shared members, role/permission flags, shared plan listing, privacy-aware task and financial visibility.
- Tasks/timeline: task CRUD, timeline view, due debts/installments.
- Budget/expenses: budget categories, expenses, and expense summary.
- Debts/installments: debt records, installment records, due installment views, and summaries.
- Provider marketplace references: cities, categories, provider/service/package listing, favorites, reviews, quote requests, and non-paid lead context.
- Provider dashboard: provider application, provider profile, service/image/package management, quote-request status updates, and review reads.
- Admin workflow: admin login through `/auth/login`, dashboard stats, provider approval/rejection/request-changes/suspend/activate, city/category/user/provider management pages.
- Mobile offline layer: local cache tables, sync queue, offline banners, cached read fallback, and queued writes for selected safe mobile workflows.

## Explicitly Out Of Scope

- Payment processing.
- Confirmed bookings or paid reservations.
- Deposits or payment status.
- Loans, credit, financing, or FinTech flows.
- AI planning automation.
- Internal chat.

## Local Development

There are two local modes:

| Mode | Backend URL | Notes |
| --- | --- | --- |
| Manual QA scripts | `http://127.0.0.1:3000` | `scripts/dev/start-backend.ps1` builds and starts `backend/dist/main.js` on port 3000. |
| Docker Compose | `http://127.0.0.1:3115` | Root `docker-compose.yml` maps backend container port `3000` to host port `3115`. |

Run from `D:\projects\aarast`:

```powershell
# Manual backend + Flutter web
.\scripts\dev\start-backend.ps1
.\scripts\dev\start-flutter-web.ps1

# Docker backend + PostgreSQL
docker compose up -d --build
Invoke-RestMethod http://127.0.0.1:3115/health
```

Backend:

```powershell
cd D:\projects\aarast\backend
npm run check
npm run build
npm run smoke:all
```

Mobile:

```powershell
cd D:\projects\aarast\mobile
flutter pub get
flutter analyze
flutter test
flutter build web --debug
flutter run -d chrome --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3115
```

Admin Web:

```powershell
cd D:\projects\aarast\admin-web
npm run build
npm run dev
```

## Useful URLs

Local:

- Backend Docker API: `http://127.0.0.1:3115`
- Backend manual QA API: `http://127.0.0.1:3000`
- Admin Web Vite dev: usually `http://127.0.0.1:5173`
- Flutter Web: Chrome-selected dev URL unless a port is supplied.

Production/current:

- API: `https://aarast-api.shadowgardn.com`
- Current deployed admin web: `https://aarast.shadowgardn.com`
- Target admin domain under review: `https://aarast-admin.shadowgardn.com`
- Target Flutter/mobile web domain under review: `https://aarast.shadowgardn.com`

Latest audit check on 2026-06-14: API health and `aarast.shadowgardn.com` returned HTTP 200; `aarast-admin.shadowgardn.com` returned HTTP 502 and needs upstream routing/service verification.

## Deployment

Dokploy production files are in `deploy/dokploy/`.

Current committed Compose routing:

| Service | Public/domain status | Host -> Container |
| --- | --- | --- |
| Backend API | `https://aarast-api.shadowgardn.com` | `8093 -> 3000` |
| Admin Web | currently documented/deployed at `https://aarast.shadowgardn.com` | `8095 -> 80` |
| Flutter Web | not present as a separate Dokploy service in the current Compose file | not configured |

Target routing still to reconcile in deployment config/docs:

- API: `aarast-api.shadowgardn.com` on host port `8093`.
- Admin: `aarast-admin.shadowgardn.com` expected on host port `8094`.
- Flutter Web/Mobile Web: `aarast.shadowgardn.com` expected on host port `8095`.

## Security Notes

- No secrets belong in Git.
- Do not commit `.env`, database passwords, JWT secrets, Meta/WhatsApp tokens, SMTP secrets, or API keys.
- `passwordHash` is storage-only and must never be returned.
- SQLite stores only local cache/sync data and a safe current-user profile; it must not store passwords, OTP codes, raw tokens, or secrets.
- Financial data is private by default and visible to shared members only through explicit permissions.

## Documentation

- [Project Status](PROJECT_STATUS.md)
- [Product Vision](PRODUCT_VISION.md)
- [MVP Scope](MVP_SCOPE.md)
- [Phases](PHASES.md)
- [Database Plan](DATABASE_PLAN.md)
- [API Plan](API_PLAN.md)
- [API Contract](API_CONTRACT.md)
- [Testing Plan](TESTING_PLAN.md)
- [Smoke Tests](SMOKE_TESTS.md)
- [Deployment Plan](DEPLOYMENT_PLAN.md)
- [Deployment Troubleshooting](DEPLOYMENT_TROUBLESHOOTING.md)
- [Mobile QA Plan](MOBILE_QA_PLAN.md)
- [Manual QA Report](MANUAL_QA_REPORT.md)
- [Git Worktree Guide](GIT_WORKTREE_GUIDE.md)
- [Agent Rules](AGENTS.md)
- [Decisions](DECISIONS.md)
- [Changelog](CHANGELOG.md)
- [Backend README](backend/README.md)
- [Mobile README](mobile/README.md)
- [Dokploy Runbook](deploy/dokploy/README.md)
