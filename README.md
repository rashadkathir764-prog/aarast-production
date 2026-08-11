# Aarast / اعّرست

Aarast is a Yemen-first wedding planning product. Its center is a Wedding
Financial OS for plans, a general budget, budget categories, costs, payments,
payment schedules, tasks, guests, sharing, and privacy-aware family
coordination.

Provider features support discovery, quote requests, provider operations, and
quote-scoped conversations. They do not create paid bookings, deposits,
payments, loans, credit, financing, or an open social inbox.

## Stack

- Mobile: Flutter.
- Backend: NestJS, Prisma, and PostgreSQL.
- Admin web: React, Vite, and TypeScript.
- Local operations: Docker Compose.
- Production operations: Dokploy Compose.

## Documentation

Start with [the documentation map](docs/README.md). It defines the active
sources of truth, reading order, archive rules, and verification commands.

Primary references:

- [Project handoff](docs/HANDOFF.md)
- [Product](docs/project/PRODUCT.md)
- [Scope and phases](docs/project/SCOPE_AND_PHASES.md)
- [Current status](docs/project/STATUS.md)
- [Decisions](docs/project/DECISIONS.md)
- [Backend API contract](docs/backend/API_CONTRACT.md)
- [Database model](docs/backend/DATABASE.md)
- [Mobile and frontend](docs/frontend/README.md)
- [Testing and QA](docs/qa/README.md)
- [Deployment](docs/deployment/README.md)

Historical files under `docs/archive/` are references only and are not active
project instructions.

## Current Handoff State

Backend, Admin Web, the fail-closed public site, all committed database
migrations, and the production backup/restore gate were accepted on 2026-08-11.
The signed Android `1.0.0+8` APK is a direct-install artifact, not a Play Store
submission. Physical-device OTP/Push/session acceptance, operated Sentry and
metrics, iOS evidence, final AAB/store upload, and store approval remain open.
Use [the handoff guide](docs/HANDOFF.md) for exact evidence, safe continuation
order, external dependencies, and commands.

## Privacy And Scope

Financial data is private by default and may be shared only through explicit
permissions. Payment processing, confirmed bookings, deposits, FinTech,
production AI automation, and unsolicited provider messaging remain excluded
unless a later decision explicitly approves them.

## Agent Rules

Automation must follow [AGENTS.md](AGENTS.md), preserve unrelated user changes,
and run the checks required by the area it touches.
