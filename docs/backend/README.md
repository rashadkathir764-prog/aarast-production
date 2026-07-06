# Backend

Snapshot date: 2026-07-05

The backend is a NestJS + Prisma + PostgreSQL API. It is the source of truth for
account-backed wedding plans, financial records, permissions, provider
references, quote leads, provider dashboard behavior, admin operations, and
notifications, rotating refresh sessions, quote-scoped conversations,
Socket.IO delivery, signed provider/chat media, and report moderation.

## Active Backend Docs

- `docs/backend/API_CONTRACT.md` - route-level API contract.
- `docs/backend/DATABASE.md` - data-model intent and privacy rules.
- `docs/backend/STATUS_AND_RISKS.md` - current backend status and known risks.

## Commands

From `backend/`:

```powershell
npm run check
npm run build
npm run smoke:all
```

Smoke scripts use `SMOKE_BASE_URL`. Some provider/marketplace smokes may also
use `SMOKE_DATABASE_URL` for local fixtures.

## Boundaries

Backend provider and quote flows are planning/reference and lead workflows only.
Quote conversations are limited to the requester and provider account on a real
quote request. They must not create payments, deposits, confirmed bookings,
loans, credit, financing, AI, open messaging, or marketplace checkout behavior.
