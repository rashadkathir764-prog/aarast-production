# Aarast Backend

Minimal NestJS backend foundation for Aarast / اعّرست.

## Current Scope

- NestJS application shell.
- Basic health endpoint at `GET /health`.
- TypeScript build and check scripts.
- Example environment file with `PORT`.
- Local Docker runtime through the root `docker-compose.yml`.

## Out Of Scope

- Product business modules.
- Database migrations.
- Flutter screens.
- Dokploy files.
- Payment, FinTech, AI, chat, or confirmed booking logic.

## Scripts

- `npm run check`
- `npm run build`
- `npm run start`

## Local Docker

From the repository root:

```powershell
docker compose up -d --build
```

Local ports:

- Backend: `http://127.0.0.1:3115`
- PostgreSQL: `127.0.0.1:5433`
