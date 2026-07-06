# Aarast Backend

NestJS backend foundation for Aarast / اعّرست.

## Current Audit Note - 2026-06-14

The backend is implemented beyond the original foundation scope. It currently includes the Wedding Financial OS modules, provider marketplace references, provider dashboard, admin APIs, Prisma migrations, smoke scripts, and Docker runtime. `npm run check` and `npm run build` passed during the 2026-06-14 audit.

## Current Scope

- Health endpoint at `GET /health`.
- Password auth plus provider-agnostic OTP request/verify endpoints.
- Profile and notification settings endpoints.
- Wedding Financial OS APIs for plans, budget categories, expenses, debts, installments, tasks, timeline, and sharing.
- Provider reference marketplace APIs for cities, categories, providers, services, packages, favorites, reviews, quote requests, and provider dashboard catalog management.
- Optional dashboard aggregator at `GET /dashboard/home`.
- Local Docker runtime through the root `docker-compose.yml`.

## Out Of Scope

- Flutter screen changes.
- Dokploy production files.
- Payment processing, deposits, paid booking, loan, credit, financing, FinTech, AI, or internal chat logic.

## Scripts

- `npm run check`
- `npx prisma validate`
- `npm run build`
- `npm run seed`
- `npm run smoke:all`
- `npm run smoke:otp-profile`
- `npm run smoke:marketplace`
- `npm run smoke:provider-dashboard`

## OTP Local Development

`POST /auth/otp/request` stores only a hashed OTP. In non-production it returns the generated code for local testing. In production, expose the code only for isolated smoke environments by explicitly setting `AARAST_EXPOSE_OTP_IN_SMOKE=true`; do not use that flag for real users.

## Smoke Environment

Smoke scripts use `SMOKE_BASE_URL` and default to `http://127.0.0.1:3115`. Marketplace and provider-dashboard smokes can set `SMOKE_DATABASE_URL` when they need to create local ACTIVE marketplace fixtures.

## Local Docker

From the repository root:

```powershell
docker compose up -d --build
```

Local ports:

- Backend: `http://127.0.0.1:3115`
- PostgreSQL: `127.0.0.1:5433`
