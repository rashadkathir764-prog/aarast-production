# Deployment Plan

## Current Audit Status - 2026-06-14

Current committed Dokploy Compose services:

| Service | Compose service | Host -> Container | Current/expected domain |
| --- | --- | --- | --- |
| API | `backend` | `8093 -> 3000` | `https://aarast-api.shadowgardn.com` |
| Admin Web | `admin-web` | `8095 -> 80` | currently `https://aarast.shadowgardn.com` |
| Flutter Web/Mobile Web | not present in Compose | not configured | target `https://aarast.shadowgardn.com` after the domain split is implemented |

Target routing under review:

- API: `https://aarast-api.shadowgardn.com` on host port `8093`.
- Admin: `https://aarast-admin.shadowgardn.com` on host port `8094`.
- Flutter Web/Mobile Web: `https://aarast.shadowgardn.com` on host port `8095`.

The current Compose file does not yet define the target admin service on `8094` or a separate Flutter web service on `8095`. Do not claim that target split is deployed until Compose/Dokploy/NPM are updated and verified.

Live HTTP check on 2026-06-14:

- `https://aarast-api.shadowgardn.com/health`: HTTP 200.
- `https://aarast.shadowgardn.com/`: HTTP 200.
- `https://aarast-admin.shadowgardn.com/`: HTTP 502 Bad Gateway.

502 note: Nginx Proxy Manager can resolve the domain while the upstream Dokploy service/port is unreachable or mapped to the wrong host port. Check the Dokploy service health, host port, NPM forward host/port, and container logs before changing app code.

CORS note: when the target split is implemented, `CORS_ORIGINS` should include every approved web/admin origin that calls the API, for example `https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com`.

This document started as planning-only. Local Docker runtime files now exist for the approved backend and PostgreSQL development setup. Dokploy production Compose files now exist under `deploy/dokploy/` for the approved VPS deployment path.

## Prerequisites

Deployment work must not begin until the correct Git repository root is confirmed. This prevents deployment files, environment references, and operational decisions from being attached to the wrong folder or subproject.

## Local Environment Isolation

Docker is used for local backend and PostgreSQL isolation through:

- `docker-compose.yml`
- `backend/Dockerfile`
- `backend/.dockerignore`

The local Compose setup runs:

- `aarast-db` on host port `5433` and container port `5432`.
- `aarast-backend` on host port `3115` and container port `3000`.

The backend container runs `prisma migrate deploy` before starting the NestJS API.

## VPS Deployment Direction

Dokploy is used for the approved VPS deployment path. The production Compose application is defined in `deploy/dokploy/docker-compose.yml`, with environment defaults documented in `deploy/dokploy/.env.example` and the runbook in `deploy/dokploy/README.md`.

Current production routing:

- Backend API domain: `https://aarast-api.shadowgardn.com`
- Admin dashboard domain: `https://aarast.shadowgardn.com`
- Backend host port: `8093`, mapped to container port `3000`
- Admin dashboard host port: `8095`, mapped to container port `80`

Required production values:

```env
PORT=3000
CORS_ORIGINS=https://aarast.shadowgardn.com
VITE_API_BASE_URL=https://aarast-api.shadowgardn.com
```

When `aarast-admin.shadowgardn.com` becomes the admin dashboard origin, update `CORS_ORIGINS` to include both deployed web origins:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
```

## Environment Staging

Future deployment planning must distinguish between development, staging, and production environments.

- Development is for local and early integration checks.
- Staging is for production-like validation before release.
- Production is for real users and must not be the first deployment target.

## Secrets Discipline

- Do not commit `.env` files.
- Do not write production secrets in Markdown.
- Do not commit database passwords, JWT secrets, API keys, or Dokploy secrets.
- Runtime secrets must be managed through environment variables or the deployment platform in a later approved phase.

## Current Phase Boundary

During Docs Foundation:

- No Dockerfile should be created unless explicitly requested.
- No docker-compose file should be created unless explicitly requested.
- No Dokploy configuration should be created unless explicitly requested.
- No deployment scripts should be created unless explicitly requested.
- No application code, backend modules, Flutter screens, package installs, or migrations should be added.

The local Docker backend/database files and Dokploy production files were created after explicit deployment requests, not as part of the original Docs Foundation scope.

## Deferral Rule

Production deployment is now represented by the approved Dokploy Compose runbook and must stay synchronized with `deploy/dokploy/`. Any Dokploy UI redeploy should use the same host ports, domains, and environment values documented above.

## Production Deployment Requirements

Before production deployment, Aarast must document:

- Environment variables.
- Domains and DNS.
- Database configuration.
- File and object storage.
- Backups and restore process.
- Logs and operational visibility.
- Rollback process.
- Smoke checks after deployment.

## Database Safety

Production migrations must require a documented backup and rollback plan before execution.

## Post-Deployment Verification

Every deployment must run post-deploy smoke checks before being considered successful. A deployment is not complete until the critical health, authentication, API, and affected feature checks pass in the target environment.
