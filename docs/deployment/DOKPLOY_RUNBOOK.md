# Aarast Dokploy Deployment Runbook

This folder prepares Aarast for a Dokploy Docker Compose deployment. It does not deploy anything by itself.

## Current Audit Note - 2026-06-14

Current committed Compose:

- `backend`: host `8093` -> container `3000`, domain `aarast-api.shadowgardn.com`.
- `admin-web`: host `8094` -> container `80`, documented/deployed at `aarast-admin.shadowgardn.com`.
- No separate Flutter web/mobile service exists in this Compose file.

Target split under review:

- API: `aarast-api.shadowgardn.com` on host port `8093`.
- Admin: `aarast-admin.shadowgardn.com` on host port `8094`.
- Flutter Web/Mobile Web: `aarast.shadowgardn.com` on host port `8095`.

Do not claim the full target split is live until Dokploy/NPM are updated and verified. Earlier audits saw `aarast-admin.shadowgardn.com` return HTTP 502 before the admin service was moved to the target host port.

## Services

- `postgres`: private PostgreSQL 16 database with the named volume `aarast_postgres_data`.
- `backend`: NestJS API built from `backend/Dockerfile`, exposed on host port `8093` and container port `3000`.
- `admin-web`: React/Vite admin dashboard built from `admin-web/Dockerfile`, exposed on host port `8094` and container port `80`.

PostgreSQL must stay private. Do not create a public domain or host-port binding for the database.

## Required Environment Variables

Copy `deploy/dokploy/.env.example` into Dokploy's environment editor or into a private `.env` file managed outside Git. Never commit the real `.env`.

Required:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ORIGINS`
- `NODE_ENV`
- `PORT`
- `VITE_API_BASE_URL`
- `AUTH_OTP_MODE`
- `AUTH_LOGIN_THROTTLE_PEPPER`

Current backend note: the backend code reads `JWT_SECRET`. The compose file maps `JWT_ACCESS_SECRET` into the backend container as `JWT_SECRET`. `JWT_REFRESH_SECRET` is documented for the production secret contract, but it is not consumed by the current backend code.

Channel-dependent required values:

- `AUTH_OTP_MODE=whatsapp`: configure the `WHATSAPP_*` Graph API/template values.
- `AUTH_OTP_MODE=openwa`: configure `OPENWA_BASE_URL`, `OPENWA_SESSION_ID`,
  `OPENWA_API_KEY`, and the existing private `OPENWA_DOCKER_NETWORK`.

Optional:

- `OTP_EXPIRES_MINUTES`
- `OTP_MAX_ATTEMPTS`
- `AARAST_EXPOSE_OTP_IN_SMOKE`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `EMAIL_FROM`

Production never echoes OTP codes. Meta remains the supported long-term
channel; the hardened OpenWA channel is the explicitly risk-accepted MVP path.
Its API key must come from the bootstrap secret and its session must pass the
`otp-readiness` contract before backend traffic is switched.

Use the Docker network service name for PostgreSQL:

```env
DATABASE_URL=postgresql://aarast_app:replace-with-strong-postgres-password@postgres:5432/aarast?schema=public
```

Set CORS and API URLs for the public domains:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
VITE_API_BASE_URL=https://aarast-api.shadowgardn.com
```

The production admin image and Compose file also default to this public API
origin so a missing build argument can never produce a browser bundle that
calls `127.0.0.1`. The admin build gate rejects any production bundle that
contains the development loopback origin or omits the current MFA login route.

If only the admin dashboard calls the API, `aarast-admin.shadowgardn.com` is enough. If Flutter web/mobile also runs on `aarast.shadowgardn.com`, include both browser origins:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
```

## Dokploy UI Steps

1. Open Dokploy.
2. Create a project named `Aarast`.
3. Add a Docker Compose application.
4. Select the GitHub repository for Aarast.
5. Select the protected `main` release branch.
6. Set the compose file path to `deploy/dokploy/docker-compose.yml`.
7. Add environment variables from `deploy/dokploy/.env.example`, replacing every placeholder secret with a strong generated value.
8. Create a domain for the backend service:
   - Service: `backend`
   - Internal port: `3000`
   - Host port: `8093`
   - Domain: `aarast-api.shadowgardn.com`
9. Create a domain for the admin dashboard service:
   - Service: `admin-web`
   - Internal port: `80`
   - Host port: `8094`
   - Domain: `aarast-admin.shadowgardn.com`
10. Enable SSL for both domains.
11. Deploy.
12. Open logs for `postgres`, `backend`, and `admin-web`.
13. Test API liveness and readiness at `https://aarast-api.shadowgardn.com/health`
    and `https://aarast-api.shadowgardn.com/ready`.
14. Open `https://aarast-admin.shadowgardn.com`, confirm the browser bundle calls
    the public API origin, and complete password plus OTP admin login.

If the target split is used, open `https://aarast-admin.shadowgardn.com` for admin and reserve `https://aarast.shadowgardn.com` for Flutter web/mobile.

## Domain And DNS Plan

Create DNS records before deployment:

- `aarast-api.shadowgardn.com` points to the Dokploy server.
- `aarast.shadowgardn.com` points to the Dokploy server.
- `aarast-admin.shadowgardn.com` points to the Dokploy server.

All deployed browser domains must have SSL enabled in Dokploy. Keep `CORS_ORIGINS` limited to the domains that actually call the API.

## Migration And Startup Behavior

The backend service runs:

```sh
npx prisma migrate deploy && node dist/main.js
```

`prisma migrate deploy` applies committed migrations only. Do not run `prisma migrate dev`, `prisma db push`, database resets, or destructive migration commands against production.

Before the first production deployment, confirm a database backup and rollback process exists. For later deployments, check migration SQL before deploying.

## Admin User Setup

The current production image does not include a production-safe admin reset command. Do not use hardcoded development credentials for production.

Before launch, create an approved one-off admin creation flow that accepts secrets from Dokploy environment variables or a secure console prompt. Never paste the admin password, Meta token, WhatsApp token, JWT secret, or database password into chat or commit them.

## Marketplace Bootstrap

The production marketplace can be initialized without running the broad development seed by using the limited, idempotent bootstrap script:

```sh
AARAST_PROVIDER_TEST_PASSWORD="set-this-outside-git" npm run prod:bootstrap-marketplace
```

The script upserts Yemen-first city references, provider categories, one clearly marked test provider account, and one active provider service. It does not delete data and must not be used as a payment, booking, deposit, loan, credit, or financing setup.

## Health Checks

After deploy:

```powershell
Invoke-RestMethod https://aarast-api.shadowgardn.com/health
```

Expected result: HTTP 200 with the backend health payload.

Then open:

```text
https://aarast-admin.shadowgardn.com
```

Expected result: admin dashboard loads and sends API requests to `https://aarast-api.shadowgardn.com`.

## Backups

Enable backups for the PostgreSQL volume `aarast_postgres_data` in Dokploy or the VPS backup layer. Test restore before real user data is stored.

## Rollback

1. In Dokploy, open the Aarast application deployment history.
2. Select the previous known-good deployment.
3. Redeploy the previous version.
4. Check `backend` logs and `https://aarast-api.shadowgardn.com/health`.
5. Check `admin-web` loads.
6. If a database migration was applied, use the pre-deploy backup and a documented restore plan. Do not manually edit production data as a rollback shortcut.

## Local Review Commands

These commands are safe for reviewing this deployment preparation locally:

```powershell
cd D:\projects\aarast
git diff -- deploy/dokploy admin-web/Dockerfile admin-web/nginx.conf .gitignore
git status --short --untracked-files=all
```
