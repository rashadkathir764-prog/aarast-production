# Aarast / اعّرست

Aarast / اعّرست is a Yemen-focused mobile app for people planning marriage and managing the full wedding process. The product starts as a Wedding Financial OS for budgets, expenses, debts, installments, tasks, timelines, and shared family planning. Early vendor/provider features are planning references and quote/lead flows only, not a full marketplace, paid booking, confirmed reservation, or deposit flow. A broader marketplace, AI planning, and FinTech partnerships can be added later after the planning foundation is stable.

## Stack Overview

- Mobile app: Flutter
- Backend: NestJS
- Database: PostgreSQL
- Admin dashboard: simple admin panel for managing vendors and services
- Local operations: Docker for local service isolation and reproducible runtime environments
- Deployment operations: Dokploy for later VPS deployment and operations
- Workflow: Git worktree is the intended workflow for isolated branches and feature work, but actual worktree usage is blocked until the correct Git repository root is confirmed.
- Testing: smoke tests for critical units before expanding feature scope

Docker and Dokploy are part of the planned operations stack, but no Dockerfile, docker-compose file, or Dokploy configuration has been created in the current documentation phase.

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
- [Git Worktree Guide](GIT_WORKTREE_GUIDE.md)
- [Agent Rules](AGENTS.md)
- [Decisions](DECISIONS.md)
- [Changelog](CHANGELOG.md)
- [Mobile README](mobile/README.md)

## Current Project Status

Current phase: Flutter MVP Start.

The backend MVP core API is implemented, regression-verified, and documented in `API_CONTRACT.md`. Flutter work includes Auth, WeddingPlan, dashboard foundation, Budget + Expense screens, Debt + Installment screens, and Task + Timeline screens. Sharing, marketplace, payments, AI, chat, Docker/Dokploy deployment, and production deployment work are not part of this slice.
