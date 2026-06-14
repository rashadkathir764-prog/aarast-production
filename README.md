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
| Admin dashboard | `https://aarast.shadowgardn.com` | `8095 -> 80` |

## Local Development Ports

All manual QA must use the following fixed ports. Smoke tests may use temporary safe ports, but manual QA always targets port 3000.

| Service      | Port | Notes                                      |
|--------------|------|-----------------------------------------|
| Backend API  | 3000 | `http://127.0.0.1:3000`                 |
| Flutter Web  | dynamic | Chrome assigns dynamically; API points to 3000 |
| PostgreSQL   | 5433 | `aarast-db` Docker container            |

### Quick Start Scripts

Scripts are in `scripts/dev/`. Run from the project root (`D:\projects\aarast`):

```powershell
# 1. Start backend on port 3000
.\scripts\dev\start-backend.ps1

# 2. Start Flutter web (in a new terminal), API -> 127.0.0.1:3000
.\scripts\dev\start-flutter-web.ps1

# 3. Free port 3000 if something is blocking it
.\scripts\dev\stop-port-3000.ps1
```

> **Note**: Smoke tests may use temporary safe ports (e.g. 3148, 3160) to avoid conflicts.
> Manual QA must always use port 3000.

## Privacy

Financial data such as expenses, debts, installments, attachments, and private tasks is private by default and shared only by explicit permissions.

## Documentation

- [Product Vision](PRODUCT_VISION.md)
- [MVP Scope](MVP_SCOPE.md)
- [Phases](PHASES.md)
- [Database Plan](DATABASE_PLAN.md)
- [API Plan](API_PLAN.md)
- [API Contract](API_CONTRACT.md)
- [Testing Plan](TESTING_PLAN.md)
- [Smoke Tests](SMOKE_TESTS.md)
- [Deployment Plan](DEPLOYMENT_PLAN.md)
- [Mobile QA Plan](MOBILE_QA_PLAN.md)
- [Manual QA Report](MANUAL_QA_REPORT.md)
- [Git Worktree Guide](GIT_WORKTREE_GUIDE.md)
- [Agent Rules](AGENTS.md)
- [Decisions](DECISIONS.md)
- [Changelog](CHANGELOG.md)
- [Mobile README](mobile/README.md)

## Current Project Status

Current phase: Dashboard Command Center redesign merged and verified.

The backend MVP core API is implemented, regression-verified, and documented in `API_CONTRACT.md`. Flutter work includes Auth, WeddingPlan, Dashboard Command Center, Budget + Expense screens, Debt + Installment screens, Task + Timeline screens, and Sharing screens. The WeddingPlan Dashboard was redesigned as a full command center showing live financial, debt, task, and sharing summaries with modern Flutter widgets. The next step is visual QA and stakeholder review of the new dashboard. Marketplace, payments, AI, chat, Docker/Dokploy deployment, and production deployment work are not part of this slice.
