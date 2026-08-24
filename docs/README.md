# Aarast Documentation Map

Snapshot date: 2026-08-24

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
4. `docs/HANDOFF.md`
5. `docs/project/STATUS.md`
6. Area-specific docs below

When docs and implementation disagree, inspect the current source/config before
changing behavior.

## Active Docs

### Root

- `README.md` - project entry point.
- `AGENTS.md` - agent rules.
- `ARCHITECTURE.md` - canonical modular-monolith architecture and phase contract.
- `CHANGELOG.md` - change history.

### Project

- `docs/HANDOFF.md`
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

## Modular Monolith Status And Plans

- `docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`
  and
  `docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`
  - exact local R7 completion receipts from immutable R6 closeout
  `31ea5324007fc71fa4b3590fbb98a454ee1deaa7` at application candidate
  `aafb47ea1742c278f6a5ed24799ada7bc23721b0`. All 18 files are in the final
  Collaboration boundary; strict reports source 0/target 18, dependency 22,
  ownership 385/781. Full local gates, immutable runtime, independent review,
  and the authenticated phone sharing/cleanup/restore journey passed. R6 is
  stopped and preserved for rollback. R8, push, merge, deployment, and remote
  CI have not started.
- `docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-design.md`
  and
  `docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation.md`
  - owner-approved R7 design from immutable R6 closeout
  `31ea5324007fc71fa4b3590fbb98a454ee1deaa7`. The exact 18-file fate map,
  public snapshot contract, historical R3-R6 handoffs, 31-minus-9 dependency
  projection, 385/781 path-only ownership projection, optional realtime
  invariant, and exact future R7 scope are machine-checked by the design-stage
  R7 manifest/scanner. The immutable design and implementation plan are the
  historical execution contract; the completion receipts above record the
  later locally completed result.
- `docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md`
  and
  `docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md`
  - exact local R6 completion specification and execution receipt from
  completed-R5 base `ce0c0d19824bff79d91417e2fe4617914c6bcd70` at
  application candidate `cefe07a76b0e615d4fecbb666514d9a2b87a7d37`.
  Identity owns the provider-neutral public transient-delivery port and private
  adapter; Collaboration no longer imports the concrete OpenWA transport. Full
  local gates, immutable runtime, and phone sharing/restore passed with OpenWA
  disabled truthfully and R5 preserved for rollback. It is the immutable base
  for the locally completed R7 phase above. No push, merge, deployment, or
  remote CI is claimed.
- `docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md`
  - immutable approved R6 execution plan. Its unchecked runtime/closeout boxes
  preserve the pre-execution snapshot; the active completion receipts above
  record the later local result.
- `docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md`
  - immutable R5 execution snapshot from local R4 receipt
  `9dab73acdc187a4a18d8a675713d8ded40a16d02`. Its in-progress wording records
  the pre-runtime application checkpoint; the active status, decisions, QA,
  architecture, and changelog receipts record the later local completion at
  application candidate `8cfee451a76bb17e20d278a1646dde4387bf7b18`.
  All 44 Identity files moved one-to-one, the four old roots are absent, local
  gates/runtime/phone passed, and API, behavior, schema, Mobile, Admin, and
  deployment stayed frozen. No push, merge, deployment, or remote CI is
  claimed. Its docs-only closeout commit is the immutable base for the approved
  R6 plan above.
- `docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md`
  - immutable pre-runtime/application-candidate execution snapshot. Its
  in-progress status records the stop before authorized Git, runtime, phone, and
  final receipts; this active index plus `docs/project/STATUS.md`, decisions,
  QA, and the changelog record the later closeout. R4 is locally complete from immutable base
  `502b181a2ce624458fd7eae064f194497ec0151e`. Finance now routes the one
  `WeddingPlan` budget write through the Planning public port, the exact
  ownership debt is retired, exhaustive local gates and immutable runtime passed,
  and the owner confirmed saved Money values after force-close/reopen. No push,
  merge, deployment, or remote-CI result is claimed. It is the completed base
  for the locally completed R5 phase above.
- `docs/superpowers/plans/2026-08-14-modular-monolith-r3-nest-boundaries.md`
  - completed R3 strict Nest-boundary plan from immutable R2 closeout base
  `6b06eb096aca8cc6684d365d16e05d4cd8529898`. The strict 13-context Nest graph,
  exhaustive local gates, immutable Docker runtime, independent reviews, and
  owner phone checkpoint passed. A phone-discovered Mobile session-restore race
  was corrected and verified by force-stop/relaunch without logout.
- `docs/superpowers/plans/2026-08-13-modular-monolith-r2-prisma-schema.md`
  - completed R2 native Prisma schema-folder plan and immutable base for R3.
- `docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md`
  - completed local R1 execution plan. The target `platform/` and
  `shared-kernel/` layout was implemented in separately reviewed checkpoints on
  `modular-monolith`, anchored to immutable R0 candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. Full local gates, managed smoke,
  independent source/runtime review, and the owner's phone application
  checkpoint passed on 2026-08-13. No R1 push, merge, or remote CI is claimed.
- `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md` -
  completed R0 governance plan and historical predecessor to R1.

## Source Of Truth By Area

| Area | Source |
| --- | --- |
| Modular-monolith architecture and phase gates | `ARCHITECTURE.md` |
| Project continuation and owner handoff | `docs/HANDOFF.md` |
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
