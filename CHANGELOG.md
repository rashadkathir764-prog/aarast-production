# Changelog

## 2026-06-02 - Phase 3 Persistence/Auth Readiness Planning

- Documented the approved readiness order: Prisma + PostgreSQL foundation, User model, Auth foundation, ownership context, then WeddingPlan module.
- Clarified that WeddingPlan ownership must not use a mock-auth shortcut.
- Clarified that production migrations and Docker/Dokploy deployment work are outside this planning task.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 WeddingPlan Design Alignment

- Clarified that WeddingPlan implementation depends on backend persistence and authenticated ownership readiness.
- Kept WeddingPlan as the first Wedding Financial OS domain module after prerequisites.
- Documented the first planned WeddingPlan slice and confirmed SharedMember, Budget, Expenses, Debts, Installments, and Tasks are later slices.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 2 Health Smoke Baseline

- Added a Node-based health smoke script for `GET /health`.
- Added backend `smoke` and `smoke:health` package scripts.
- Kept Phase 2 limited to the existing health endpoint; no product modules, tests, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were added.

## 2026-06-02 - Phase 1 Backend Foundation

- Added the minimal NestJS backend foundation in `backend/` with a basic `GET /health` endpoint.
- Verified `npm install`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, and `GET /health`.
- Committed the backend foundation as `b67246438c4537af91d5445d05507dc569a07885` on `phase/1-backend-foundation`.
- Confirmed no product modules, Flutter/mobile app, migrations, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat logic, marketplace logic, or confirmed booking logic were created.

## 2026-06-01 - Docs Foundation

- Created/updated the root Markdown documentation foundation for Aarast / اعّرست, including `DEPLOYMENT_PLAN.md`.
- Documented Docker for local isolation and Dokploy for later VPS deployment; clarified these are planning-only in this phase and no Dockerfile, docker-compose, Dokploy config, or deployment scripts were created.
- Clarified the MVP is Wedding Financial OS first and marketplace second.
- Clarified early provider/service features are planning references and quote/lead flows only.
- Explicitly excluded payment processing, deposits, confirmed bookings, payment status, loans, credit, financing, FinTech, AI, and internal chat from the MVP unless later approved.
- Added private-by-default financial data rules for expenses, debts, installments, attachments, and private tasks.
- Added Attachment as a planning-level entity/API concept.
- Documented Git worktree as the intended workflow, with actual usage blocked until the correct Git repository root is confirmed.
- Strengthened `AGENTS.md` rules and approved-docs discipline.
- Confirmed no application code, tests, Git actions, dependencies, migrations, Docker files, Dokploy config, Flutter screens, backend modules, deployment scripts, or business logic were created.
