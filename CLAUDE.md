# Aarast — Wedding Financial OS (Yemen)

> **AI Start Here** — Read these files to get started:
>
> | Document | Purpose |
> |----------|---------|
> | [CLAUDE.md](./CLAUDE.md) | Architecture, conventions, rules (this file) |
> | [docs/status.md](./docs/status.md) | Current project status, open items |
>
> **Documentation rules (MCP-based):**
> - Decisions ONLY via `/mxDecision` -> Knowledge-DB (doc_type='decision')
> - Plans ONLY via `/mxPlan` -> Knowledge-DB (doc_type='plan')
> - Specs ONLY via `/mxSpec` -> Knowledge-DB (doc_type='spec')
> - `/mxSave` updates CLAUDE.md + docs/status.md (local) + session notes (DB)
> - Search documents: `mx_search(project='aarast', ...)` or `mx_briefing(project='aarast')`
> - CLAUDE.md stays compact: links + rules + architecture. No long backlogs.

**Slug:** `aarast`
**Stack:** Flutter (mobile) · React/Vite (admin web) · NestJS (backend) · PostgreSQL · SQLite mobile cache · Docker (local) · Dokploy (VPS)

## Architecture

```
mobile/   → Flutter app (Dart) — Arabic-first, RTL, SQLite offline cache
admin-web/ → React/Vite admin dashboard
backend/  → NestJS API (TypeScript) — port 3000 via manual scripts, 3115 via Docker host mapping
          → PostgreSQL — port 5433 (Docker: aarast-db)
scripts/dev/ → PowerShell quick-start scripts
```

## Key Dev Ports

| Service     | Port | Notes                            |
|-------------|------|----------------------------------|
| Backend API | 3000 | Manual QA scripts |
| Backend API | 3115 | Docker Compose host port |
| Flutter Web | dyn  | Chrome assigns dynamically |
| PostgreSQL  | 5433 | Docker container `aarast-db` |

## Quick Start

```powershell
.\scripts\dev\start-backend.ps1       # backend on :3000
.\scripts\dev\start-flutter-web.ps1   # flutter web (new terminal)
.\scripts\dev\stop-port-3000.ps1      # free port if blocked
```

## Hard Constraints

- Financial data (expenses, debts, installments, attachments, private tasks) is **private by default**
- Shared members get access only via explicit `SharedMember` permissions
- No marketplace payments, confirmed bookings, deposits, or FinTech flows in MVP
- Provider/service features are quote/lead references only (no paid booking)
- No mock-auth shortcuts — ownership always uses real authenticated user context

## Current Phase

Full project audit and documentation refresh completed on 2026-06-14. Backend MVP/provider/admin APIs are implemented, Flutter includes core planning plus provider marketplace screens and SQLite offline cache/sync queue, and admin-web includes provider approval/catalog/user flows. Deployment is partial: current API/admin-domain checks pass for `aarast-api.shadowgardn.com` and `aarast.shadowgardn.com`, while target `aarast-admin.shadowgardn.com` returns 502 until Dokploy/NPM/ports are aligned.

## Key Docs

`PROJECT_STATUS.md` · `CURRENT_STATUS.md` · `CHANGELOG.md` · `API_CONTRACT.md` · `DECISIONS.md` · `PHASES.md` · `MVP_SCOPE.md` · `DEPLOYMENT_TROUBLESHOOTING.md`

## mx* Integration

- **Project:** `aarast` (ID 30)
- Run `/mxSave` before `/compact`; run `mx_briefing(project='aarast')` after
- Specs/plans/decisions → mxlore docs; session notes → `/mxSave`
