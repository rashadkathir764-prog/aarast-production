# Aarast Documentation Map

Snapshot date: 2026-09-13

This is the documentation entry point for Aarast. The repository previously had
more than 100 Markdown files. The active set is now intentionally small, and
old files are preserved as `.md.txt` archive references.

## Modular Monolith R12C — Local Completion — 2026-09-13

R12C is complete locally.
Dependency debt is 0; the dependency baseline is deleted and the import gate
is strict and unbaselined.
Ownership remains 385/781.
The architecture target remains incomplete; R13–R18 remain.
Commits exist only on the local recovery branch
`recovery/r12c-t5-takeover-20260913`. No push, merge, deployment, production
mutation, remote CI, provider delivery, phone acceptance, or release is
claimed.

The active architecture, status, decisions, execution plan, changelog, and
generated scripts reference describe the same R12C local-completion state.
The Finance projection, Messaging lifecycle port, and Marketplace
provider-access policy passed Tasks 2-6 and the final gate; the final report
is
`docs/superpowers/reports/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-report.md`.
Local completion does not authorize R13 or any external action.
The byte-lineage governance is closed (spec section 19; closure record
`backend/architecture/modular-monolith-closure.json`, lineage commit
`4bae5c6d`); the scanners verify live invariants from then on and governed
files are ordinary reviewed code.

## Modular Monolith R12B — Local Completion — 2026-09-06

R12B is complete locally.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation followed on 2026-09-13 (see above).
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.

The active architecture, status, decisions, execution plan, changelog, and
generated scripts reference now describe the same R12B local-completion state.
The Planning location boundary and Onboarding local DTO work passed Task 5 and
its independent `0/0/0` review. The Task 6 candidate review approved activation;
activated exact-state re-review remains the final close gate. Local completion
does not authorize R12C or any external action.

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

### Mobile

- `docs/mobile/README.md`

### Archive

- `docs/archive/README.md`

## Modular Monolith Status And Plans

- `docs/superpowers/specs/2026-08-04-modular-monolith-architecture-design.md`
  - the original approved architecture target, tracked verbatim (SHA-256
    `db4232f9795b5211532c454f838996af7e50d5aefee13a20d5e3e513539845f4`, the
    bytes the R11 reconciliation recorded from its external location). It
    is the requirement source; it does not describe the current state.
- `docs/superpowers/reports/2026-09-13-product-forensic-audit.md`
  - the full product forensic audit after the exit audit: inventory and
    coverage per area, backend domains, database/migration integrity (the
    ContributionEvent index-name drift, fixed without a migration), Flutter,
    Admin, bidirectional backend/frontend contracts (0 unmatched client
    calls), advisories, tests-as-truth; four defects fixed in their own
    commits; three product decisions recorded.
- `docs/superpowers/reports/2026-09-13-architecture-exit-audit.md`
  - the architecture exit audit after the R12C closure: sixteen findings
    (gates that pinned product bytes and inventories, a silent R3 CLI, an
    ownership gate that passed vacuously without the generated Prisma client,
    dead phase tools, temp-root leaks, one duplicate mobile file, drifting
    generated desktop registrants, stale statements) classified and fixed,
    0 open. Declared legacy (ownership 385/781, legacy backend roots) is
    recorded, not counted as open.
- `docs/superpowers/reports/2026-09-13-modular-monolith-requirement-traceability-matrix.md`
  - traces every requirement of the original target and the R0–R12C
    phases to its live proof at the closure of R12C. Verdict: the execution
    wave R0–R12C is closed; the modular-monolith mission is **not** closed
    (ownership 385/781, pure Finance domain, erasure-port saga, port-based
    insights/reminders and the Mobile fate-map remainder stay open as
    R13–R20 of the remaining-target design).
- `docs/superpowers/specs/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-design.md`,
  `docs/superpowers/plans/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies.md`,
  and
  `docs/superpowers/reports/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-report.md`
  - locally completed R12C from the same immutable base commit. Three
    contracts moved to owner public slices (Finance projection, Messaging
    lifecycle port, Marketplace provider-access policy), dependency IDs `10`,
    `12-17`, `19-20` retired, the dependency baseline deleted, the import gate
    strict, and ownership unchanged at 385/781. The spec's section 18 records
    the governance-portability amendment. Commits exist only on the local
    recovery branch; no push, merge, deployment, provider delivery, or release
    is claimed.
- `docs/superpowers/specs/2026-09-02-modular-monolith-r12b-planning-public-contracts-design.md`,
  `docs/superpowers/plans/2026-09-02-modular-monolith-r12b-planning-public-contracts.md`,
  and
  `docs/superpowers/reports/2026-09-02-modular-monolith-r12b-planning-public-contracts-report.md`
  - locally completed R12B: the Planning wedding-location public move, two
    Onboarding local DTO re-expressions, dependency IDs `7-9`, `11`, `18`,
    `21-22` retired (16 -> 9), and the qs 6.16.0 security prerequisite.
- `docs/superpowers/specs/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-design.md`,
  `docs/superpowers/plans/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts.md`,
  and
  `docs/superpowers/reports/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-report.md`
  - locally completed R12A from immutable local R10/R11 entry
    `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. Five contracts moved to owner
    public slices, nine consumers were rewritten, dependency debt is exactly 16,
    and ownership remains 385/781. Task 5 tests, smokes, and independent review
    passed. Task 6 documentation/scope/identity and independent review passed;
    no
    commit, push, merge, deployment, provider delivery, or release is claimed.
- `docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md`,
  `docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md`,
  and
  `docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md`
  - locally completed R11 authority, execution contract, and evidence receipt
    reconcile the
    original architecture target with the locally closed R0-R10 wave. R10 is
    committed locally at `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
    R11 changed documentation only and keeps the live Backend debt explicit at
    dependency 22 and ownership 385/781. Its nine-file scope, architecture,
    documentation, and independent-review gates passed. It does not authorize R12 source work,
    push, merge, deployment, remote CI, real provider delivery, or release.
- `docs/superpowers/specs/2026-08-30-modular-monolith-r10-admin-closeout-design.md`,
  `docs/superpowers/plans/2026-08-30-modular-monolith-r10-admin-closeout.md`,
  and
  `docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md`
  - reviewed R10 Admin design, staged execution contract, and final local
  evidence receipt from immutable R9 closeout
  `e560e5784278907dd6bf565327c3abfa0c9b8cab`. The eight Admin owners are
  strict, the four old roots are absent, 101/101 Admin tests and the complete
  Backend/Mobile/Prisma/runtime/docs matrix pass, and independent review is
  approved. Backend debt remains 22 and 385/781. No commit, push, merge,
  deployment, remote CI, real WhatsApp delivery, or live Firebase Push is
  claimed by R10.
- `docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md`
  and
  `docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md`
  - exact local R9 completion receipts from immutable base
  `833a4f1d31781b45cd0a68ecee1b969ac85f237f` at application candidate
  `0f61bf283b455c4404182f5028ab78d2448053d3`. All 19 Mobile owner APIs are
  strict, feature/root debt is zero, and the
  legal projection is 159. Full local gates, the owner-selected `SM-S938B`
  session-invalidation/two-relaunch journey, and independent review passed.
  Live Firebase Push is unverified. That R9 receipt claimed no push, merge,
  deployment, remote CI, S10 work, or R10; the separately approved R10 result
  is recorded above.
- `docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-design.md`
  and
  `docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries.md`
  - approved R9 design and staged execution contract. The completion receipts
  above record the later local result and the reviewed C5 correction.
- `docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`
  and
  `docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`
  - exact local R8 completion receipts from immutable R7 closeout
  `c2b728bfe54304562923facfb6094e0de04c0b27` at application candidate
  `464d785a0440b8494768a26a70ac1de73a4bff2c`. Project-owned globals are zero;
  Prisma importers are 21/21 with missing 0; Realtime importers are 2; singleton
  identities and the exact external Schedule/Throttler behaviors are preserved.
  Full local gates, immutable runtime, independent reviews, and the authorized
  26-phone task/chat/restore journey passed. R7 is stopped and preserved for
  rollback. Push, merge, deployment, remote CI, and R9 have not started.
- `docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md`
  and
  `docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md`
  - immutable owner-approved R8 design and staged implementation contract from
  R7 closeout `c2b728bfe54304562923facfb6094e0de04c0b27`. The design/plan, exact scope,
  semantic-global scanner, explicit importer closure, R3 projection, provider
  identities, frozen external dependencies, and protected surfaces remain the
  historical execution contract; the completion receipts above record the
  later locally completed result.
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

## R10 Local Completion Stop Boundary

R10 Admin phase is locally complete in the working tree from immutable R9
closeout `e560e5784278907dd6bf565327c3abfa0c9b8cab`. Stop before commit, push,
merge, deployment, production mutation, remote CI, store release, or S10. The
remaining Backend debt needs a separate approved phase.

That historical stop was lifted only for the later owner-authorized local R10
commit `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. It did not authorize external
Git or deployment activity.

## R11 Target Reconciliation Stop Boundary

R11 is a documentation-only reconciliation from the immutable local R10
commit. Its only allowed paths are the nine Markdown files listed in the R11
plan. Stop before R12 source work, any additional commit, push, merge,
deployment, production mutation, remote CI, provider delivery, or release.

## R12A Local Closeout Boundary

R12A is complete locally after Task 5 and Task 6 evidence, documentation,
exact-scope, identity, and independent-review gates passed. Do not commit, push,
merge, deploy, start R12B, mutate production, run remote CI, deliver to a
provider, or release. The next permitted work is R12B design/planning only after
separate owner approval.
