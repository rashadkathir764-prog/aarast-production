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
**Stack:** Flutter (mobile) · NestJS (backend) · PostgreSQL · Docker (local) · Dokploy (VPS, later)

## Architecture

```
mobile/   → Flutter app (Dart) — Arabic-first, RTL
backend/  → NestJS API (TypeScript) — port 3000
          → PostgreSQL — port 5433 (Docker: aarast-db)
scripts/dev/ → PowerShell quick-start scripts
```

## Key Dev Ports

| Service     | Port | Notes                            |
|-------------|------|----------------------------------|
| Backend API | 3000 | `http://127.0.0.1:3000`         |
| Flutter Web | dyn  | Chrome assigns dynamically       |
| PostgreSQL  | 5433 | Docker container `aarast-db`     |

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

Aarast Dashboard (Claude Design handoff) implemented in Flutter and wired as the home screen (`/home` renders the user's primary plan dashboard). Backend MVP core API done and documented in `API_CONTRACT.md`. Next: visual QA and stakeholder review.

## Key Docs

`CURRENT_STATUS.md` · `CHANGELOG.md` · `API_CONTRACT.md` · `DECISIONS.md` · `PHASES.md` · `MVP_SCOPE.md`

## mx* Integration

- **Project:** `aarast` (ID 30)
- Run `/mxSave` before `/compact`; run `mx_briefing(project='aarast')` after
- Specs/plans/decisions → mxlore docs; session notes → `/mxSave`
