# Deployment

Snapshot date: 2026-07-05

Deployment source files live under `deploy/dokploy/`. This folder is the compact
documentation entry point for deployment.

## Current Runtime From Committed Files

Local Docker Compose:

- PostgreSQL: `5433 -> 5432`
- Backend: `3115 -> 3000`

Production Dokploy Compose:

- Backend API: `8093 -> 3000`
- Admin web: `8094 -> 80`

Public domains documented for the current deployment path:

- Backend API: `https://aarast-api.shadowgardn.com`
- Admin web: `https://aarast-admin.shadowgardn.com`

## Rules

- Do not modify Docker, Docker Compose, Dokploy, domains, ports, migrations, or
  production secrets unless deployment work is explicitly requested.
- Never write real secrets into Markdown.
- Production deployment is not complete without post-deploy smoke checks.

