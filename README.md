# Aarast / اعّرست

Aarast is a Yemen-first wedding planning product. Its center is a Wedding
Financial OS for plans, budgets, expenses, debts, installments, tasks, guests,
sharing, and privacy-aware family coordination.

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

## Privacy And Scope

Financial data is private by default and may be shared only through explicit
permissions. Payment processing, confirmed bookings, deposits, FinTech,
production AI automation, and unsolicited provider messaging remain excluded
unless a later decision explicitly approves them.

## Agent Rules

Automation must follow [AGENTS.md](AGENTS.md), preserve unrelated user changes,
and run the checks required by the area it touches.
