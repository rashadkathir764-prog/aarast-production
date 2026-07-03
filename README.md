# Aarast / اعّرست

Aarast / اعّرست is a Yemen-focused mobile app for people planning marriage and managing the full wedding process. The product starts as a Wedding Financial OS for budgets, expenses, debts, installments, tasks, timelines, and shared family planning. Early vendor/provider features are planning references and quote/lead flows only, not a full marketplace, paid booking, confirmed reservation, or deposit flow. A broader marketplace, AI planning, and FinTech partnerships can be added later after the planning foundation is stable.

## Stack Overview

- Mobile app: Flutter
- Backend: NestJS
- Database: PostgreSQL
- Admin dashboard: simple admin panel for managing vendors and services
- Local operations: Docker for local service isolation and reproducible runtime environments
- Deployment operations: Dokploy VPS deployment via `deploy/dokploy/`
- Workflow: Git worktree is the intended workflow for isolated branches and feature work, but actual worktree usage is blocked until the correct Git repository root is confirmed.
- Testing: smoke tests for critical units before expanding feature scope

Docker and Dokploy are part of the operations stack. Local Docker files support backend/database isolation, and `deploy/dokploy/` contains the approved production Compose runbook for the current Aarast domains.

Production deployment uses:

| Service | Public URL | Host -> Container |
|---------|------------|------------------|
| Backend API | `https://aarast-api.shadowgardn.com` | `8093 -> 3000` |
| Admin dashboard | `https://aarast-admin.shadowgardn.com` | `8094 -> 80` |

## Local Development Ports

All manual QA must use the following fixed ports. Smoke tests may use temporary safe ports, but manual QA always targets the local Docker backend host port 3115.

| Service      | Port | Notes                                      |
|--------------|------|-----------------------------------------|
| Backend API  | 3115 | `http://127.0.0.1:3115` |
| Flutter Web  | dynamic | Chrome assigns dynamically; API points to 3115 |
| PostgreSQL   | 5433 | `aarast-db` Docker container            |

### Quick Start Scripts

Scripts are in `scripts/dev/`. Run from the project root (`D:\projects\aarast`):

```powershell
# 1. Start backend on local Docker host port 3115
.\scripts\dev\start-backend.ps1

# 2. Start Flutter web (in a new terminal), API -> 127.0.0.1:3115
.\scripts\dev\start-flutter-web.ps1

# 3. Free port 3000 if something is blocking it
docker compose restart backend
```

> **Note**: Smoke tests may use temporary safe ports (e.g. 3148, 3160) to avoid conflicts.
> Manual QA must always use local Docker backend port 3115.

## Privacy

Financial data such as expenses, debts, installments, attachments, and private tasks is private by default and shared only by explicit permissions.

## Source Of Truth

Use this map when updating docs so `README.md` stays an entry point instead of becoming a second copy of every plan.

| Area | Primary source |
|------|----------------|
| Current project state | [Current Status](CURRENT_STATUS.md) and [Status Summary](docs/status.md) |
| Product scope and phase boundaries | [Product Vision](PRODUCT_VISION.md), [MVP Scope](MVP_SCOPE.md), [Phases](PHASES.md) |
| Backend route contract | [API Contract](API_CONTRACT.md) |
| Database model intent | [Database Plan](DATABASE_PLAN.md) |
| Testing and smoke expectations | [Testing Plan](TESTING_PLAN.md), [Smoke Tests](SMOKE_TESTS.md), [Mobile Rebuild QA Plan](docs/testing/MOBILE_QA_PLAN.md) |
| Mobile UX rebuild direction | [Mobile Product UX Rebuild README](docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md) |
| Deployment runbook | [Deployment Plan](DEPLOYMENT_PLAN.md) |
| Agent rules and decisions | [Agent Rules](AGENTS.md), [Decisions](DECISIONS.md) |

## Documentation Index

- [Current Status](CURRENT_STATUS.md)
- [Project Status Summary](docs/status.md)
- [Product Vision](PRODUCT_VISION.md)
- [MVP Scope](MVP_SCOPE.md)
- [Phases](PHASES.md)
- [Database Plan](DATABASE_PLAN.md)
- [API Plan](API_PLAN.md)
- [API Contract](API_CONTRACT.md)
- [Testing Plan](TESTING_PLAN.md)
- [Smoke Tests](SMOKE_TESTS.md)
- [Deployment Plan](DEPLOYMENT_PLAN.md)
- [Mobile QA Plan - legacy MVP manual checklist](MOBILE_QA_PLAN.md)
- [Mobile Rebuild QA Plan](docs/testing/MOBILE_QA_PLAN.md)
- [Manual QA Report](MANUAL_QA_REPORT.md)
- [Git Worktree Guide](GIT_WORKTREE_GUIDE.md)
- [Agent Rules](AGENTS.md)
- [Decisions](DECISIONS.md)
- [Changelog](CHANGELOG.md)
- [Mobile README](mobile/README.md)
- [Mobile Product UX Rebuild README](docs/mobile-ux/README_AARAST_MOBILE_PRODUCT_UX_REBUILD.md)
- [Backend Completion Final Report](docs/backend/BACKEND_COMPLETION_FINAL_REPORT.md)
- [Backend + API Full Audit Report](docs/backend/BACKEND_API_FULL_AUDIT_REPORT.md)

## Current Documentation Snapshot

Snapshot date: 2026-06-21. This section is a short orientation only; use the source-of-truth map above for the owning docs.

The backend source now contains the broad Wedding Financial OS implementation plus provider-reference and quote-lead support: auth/profile, onboarding, active plan, dashboard summary, money, tasks/checklists, guests/groups, sharing/invites/permissions, notifications, provider catalog/dashboard, plan-scoped quotes, and admin APIs. `API_CONTRACT.md` is the route-level source of truth; other docs should link to it instead of copying endpoint lists.

The latest backend completion report shows local source verification passing on 2026-06-19. The later backend/API audit on 2026-06-20 found a runtime/source mismatch in the Docker-backed dashboard smoke run, plus permission and security follow-ups. Treat source completeness and runtime readiness as separate until the local runtime is rebuilt/restarted and smoke checks are rerun.

Mobile remains Flutter, Arabic-first, and Wedding Financial OS-first. The active rebuild docs define the next mobile direction: guest-first onboarding, separated user/provider navigation, single-source summaries, privacy-aware UI states, and narrow feature-flagged implementation phases.

Still excluded unless explicitly approved: payment processing, deposits, paid or confirmed bookings, loans, credit, financing, AI, internal chat, and broad marketplace monetization.
