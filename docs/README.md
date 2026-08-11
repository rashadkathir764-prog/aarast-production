# Aarast Documentation Map

Snapshot date: 2026-08-11

This is the documentation entry point for Aarast. The repository previously had
more than 100 Markdown files. The active set is now intentionally small, and
old files are preserved as `.md.txt` archive references.

## Inventory Policy

The explicit lists below are the authoritative source-of-truth inventory. A
numeric file total is intentionally not maintained because historical working
notes are archived rather than treated as product truth. Historical Markdown
references remain under `docs/archive/` and are not active source documents.
The remaining non-Markdown prototype assets under `docs/mobile-ux/prototypes/`
are reference-only and will be retired with the P2 visual migration.

## Read Order

1. `README.md`
2. `AGENTS.md`
3. `docs/README.md`
4. `docs/project/STATUS.md`
5. Area-specific docs below

When docs and implementation disagree, inspect the current source/config before
changing behavior.

## Active Docs

### Root

- `README.md` - project entry point.
- `AGENTS.md` - agent rules.
- `CHANGELOG.md` - change history.

### Project

- `docs/project/PRODUCT.md`
- `docs/project/SCOPE_AND_PHASES.md`
- `docs/project/STATUS.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`

### Backend

- `docs/backend/README.md`
- `docs/backend/API_CONTRACT.md`
- `docs/backend/DATABASE.md`
- `docs/backend/STATUS_AND_RISKS.md`

### Frontend

- `docs/frontend/README.md`
- `docs/frontend/MOBILE.md`
- `docs/frontend/MOBILE_ARCHITECTURE.md`
- `docs/frontend/DESIGN_SYSTEM.md`
- `docs/frontend/OFFLINE_SQLITE.md`
- `docs/frontend/ADMIN_WEB.md`

### Generated References

- `docs/SCRIPTS.md`
- `docs/frontend/MOBILE_ROUTES.md`
- `docs/frontend/ADMIN_ROUTES.md`

### QA

- `docs/qa/README.md`
- `docs/qa/MOBILE_QA.md`

### Deployment

- `docs/deployment/README.md`
- `docs/deployment/DOKPLOY_RUNBOOK.md`
- `docs/deployment/OPENWA_OTP_MVP.md`
- `deploy/openwa-otp-staging/README.md`
- `docs/deployment/SCALING.md`
- `docs/deployment/STORE_RELEASE.md`
- `docs/deployment/STORE_LISTING.md`
- `docs/deployment/PLAY_DATA_SAFETY.md`

### Legal

- `docs/legal/PRIVACY_POLICY.md`

### Archive

- `docs/archive/README.md`

## Source Of Truth By Area

| Area | Source |
| --- | --- |
| Product identity and exclusions | `docs/project/PRODUCT.md` |
| Scope and phase discipline | `docs/project/SCOPE_AND_PHASES.md` |
| Current status | `docs/project/STATUS.md` |
| Decisions | `docs/project/DECISIONS.md` |
| Current modernization execution | `docs/project/EXECUTION_PLAN.md` |
| Backend overview | `docs/backend/README.md` |
| Backend routes | `docs/backend/API_CONTRACT.md` |
| Database model intent | `docs/backend/DATABASE.md` |
| Backend status and risks | `docs/backend/STATUS_AND_RISKS.md` |
| Mobile/frontend overview | `docs/frontend/README.md` |
| Mobile product and UX | `docs/frontend/MOBILE.md` |
| Mobile architecture | `docs/frontend/MOBILE_ARCHITECTURE.md` |
| Design system and tokens | `docs/frontend/DESIGN_SYSTEM.md` |
| Mobile V3 architecture artifact | `docs/design/AARAST_MOBILE_EXPERIENCE_SYSTEM_V3.docx` |
| Mobile offline layer | `docs/frontend/OFFLINE_SQLITE.md` |
| Admin web | `docs/frontend/ADMIN_WEB.md` |
| Testing and QA | `docs/qa/README.md` |
| Mobile QA | `docs/qa/MOBILE_QA.md` |
| Deployment | `docs/deployment/README.md` |
| Dokploy runbook | `docs/deployment/DOKPLOY_RUNBOOK.md` |
| Temporary OpenWA OTP gate | `docs/deployment/OPENWA_OTP_MVP.md` |
| Scaling and capacity | `docs/deployment/SCALING.md` |
| Play Store release | `docs/deployment/STORE_RELEASE.md` |
| Store listing copy | `docs/deployment/STORE_LISTING.md` |
| Play data-safety answers | `docs/deployment/PLAY_DATA_SAFETY.md` |
| Privacy policy | `docs/legal/PRIVACY_POLICY.md` |

## Archive Rules

- Archived `.md.txt` files are historical references, not active project docs.
- Do not update archived docs for current work.
- If an archived topic becomes active again, create or update one compact active
  doc and link it here.
- Do not restore large sets of old docs without an explicit reason.

The canonical integration branch is `main`; release candidates enter it only
through reviewed, green Git history. Resolve the exact source revision with
`git rev-parse HEAD` and bind deployed images and artifacts to that immutable
revision instead of copying a self-referential SHA into this tracked document.
Superseded plans, visual prototypes, and duplicated status documents remain
recoverable in the archive; only the compact sources listed above govern
implementation. The quarantined `codex/guest-invitation-campaigns` branch is a
separate preserved WIP and is not part of the current release line.

## Guard

Run this before accepting documentation changes:

```powershell
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Run `docs-sync.mjs` once after package, schema, or route changes stabilize to
refresh the generated references. Its `--check` mode is the acceptance gate for
remaining generated-table drift. `docs-verify` checks route, migration,
snapshot, and link references. `git diff --check` catches whitespace errors.
Only the first command updates generated Markdown; the remaining commands are
read-only.
