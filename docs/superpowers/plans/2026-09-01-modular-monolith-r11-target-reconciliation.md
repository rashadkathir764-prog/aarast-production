# Modular Monolith R11 Target Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish one tracked, truthful source of authority for the remaining
modular-monolith target and an ordered R11-R20 completion program without
changing application behavior or hiding the existing Backend debt.

**Architecture:** R11 is documentation-only. It reconciles the approved
2026-08-04 target with the locally completed R0-R10 execution wave, derives an
exact gap ledger from the live architecture manifests, and updates the active
documentation so later phases cannot confuse phase completion with target
completion. Every later implementation area receives its own just-in-time
design and plan; this plan does not batch independent Backend or Mobile
subsystems into one code change.

**Tech Stack:** Markdown, PowerShell, Git read-only inspection, Node.js,
dependency-cruiser, the existing Backend/Admin/Mobile architecture scanners,
and the existing documentation verification scripts.

**Spec:**
`C:\Users\Rashad\Downloads\Telegram Desktop\2026-08-04-modular-monolith-architecture-design.md`
(original approved target), reconciled against
`docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md` and
the live repository state.

## Global Constraints

- Repository root is exactly `D:\projects\aarast-modular-monolith` on branch
  `modular-monolith`.
- Immutable R9 closeout and historical R10 comparison base is
  `e560e5784278907dd6bf565327c3abfa0c9b8cab`.
- Immutable local R10 closeout and R11 comparison base is
  `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1` (`refactor(admin): complete
  modular monolith R10`). R10 is committed locally; it has not been pushed,
  merged, deployed, or proven by remote CI.
- This plan is the first intentional post-R10 path. It is outside the R10
  closeout commit and must not be added to the fixed historical R10
  changed-path allowlist.
- R11 changes Markdown only. It must not modify Backend, Mobile, Admin source,
  Prisma schema or migrations, package files or lockfiles, CI, Docker,
  Compose, Dokploy, deployment, generated route inventories, or runtime
  configuration.
- No additional commit, push, merge, branch, checkout, reset, worktree, deployment,
  production mutation, remote CI, store action, real WhatsApp send, or live
  Firebase Push is authorized by this plan.
- The current Backend debt is exactly 22 dependency records and 385 physical-
  ownership records / 781 occurrences. A different live value is a stop signal
  that requires a fresh audit before editing documentation.
- The original target remains: one owner per table, cross-module access only
  through public contracts, a pure Finance domain, acyclic modules,
  `forwardRef()` count 0, machine-enforced CI boundaries, and zero observable
  behavior change.
- HTTP routes, methods, authentication flags, response shapes, error codes,
  Arabic copy, permissions, transaction boundaries, database schema,
  migrations, Mobile routes, Admin routes, and deployment topology remain
  unchanged.
- Existing tests are behavior oracles. Later implementation plans may change
  existing tests only for mechanical import-path moves unless a separately
  reviewed correction is approved and documented before implementation.
- The dependency and ownership baselines are debt ledgers, not proof of target
  completion. They may shrink only by exact reviewed projections and may be
  deleted only when their live counts are zero.
- `R0-R10 execution wave locally closed` and `R10 Admin phase complete` remain
  valid historical statements. `Modular-monolith architecture target complete`
  is forbidden until the final R20 gate proves every original invariant.
- Every future phase must have its own design, implementation plan, scope
  fence, independent review, complete affected tests, architecture gates,
  documentation gates, and real-phone QA when Mobile behavior is in scope.
- Secrets, credentials, tokens, OTPs, phone numbers, raw business payloads,
  private financial data, and environment values must never appear in plans,
  reports, commands, or captured evidence.

## Planned File Responsibilities

| Path | Responsibility |
| --- | --- |
| `docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md` | This reviewed execution contract; it is not an R10 path and does not implement subsequent phases |
| `docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md` | Canonical tracked delta between the original target and the completed R0-R10 wave, including the exact gap ledger and R11-R20 order |
| `ARCHITECTURE.md` | Human-readable canonical laws plus explicit post-R10 target-completion semantics |
| `docs/README.md` | Active source-of-truth index linking the R11 design, plan, and report |
| `docs/project/STATUS.md` | Current state: R10 locally committed, R11 reconciliation status, exact remaining debt, and external stop boundary |
| `docs/project/DECISIONS.md` | Accepted decision that later phase labels narrowed the original sequence but did not cancel its final target |
| `docs/project/EXECUTION_PLAN.md` | Ordered R11-R20 program and phase-entry/exit dependencies |
| `CHANGELOG.md` | Documentation-only reconciliation receipt with no application or release claim |
| `docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md` | Evidence-backed R11 completion receipt and the exact next authorized planning action |

No other file is created or modified by R11.

## Program Decomposition Locked By R11

R11 records this order. Each row after R11 requires a separate design and plan;
the row is a program boundary, not permission to edit code.

| Phase | Bounded outcome | Required zero/projection gate |
| --- | --- | --- |
| R11 | Reconcile target, current state, debt ledger, and future phase order in active docs | Docs agree; live debt remains truthfully 22 and 385/781 |
| R12A | Replace Backoffice/Catalog authority and mutation deep imports with owner public contracts | Retire dependency records 1-6; 22 -> 16 |
| R12B | Replace Planning DTO reuse and Planning-location read-model deep imports | Retire dependency records 7-9, 11, 18, 21-22; 16 -> 9 |
| R12C | Replace Finance presenter, Messaging lifecycle, and Marketplace access-policy deep imports | Retire dependency records 10, 12-17, 19-20; 9 -> 0; delete dependency baseline only after strict scan passes |
| R13 | Complete Planning and Finance internals, including pure Finance domain and owner-only Prisma infrastructure | Retire exact approved projections from Planning 24/37 and Finance 20/48 |
| R14A | Complete Identity internals and preserve the owner-side invite OTP port before any Collaboration work | Retire the exact Identity projection 60/78 |
| R14B | Complete Collaboration internals only after R14A exits, without changing OTP, sharing, permission, or history behavior | Retire the exact Collaboration projection 28/80; combined R14 total 88/158 |
| R15 | Complete Tasks and Guests internals as separate bounded contexts | Retire exact approved projections from Tasks 6/12 and Guests 4/7 |
| R16 | Complete Catalog, Marketplace, Media, Messaging, and Notifications internals in five separately reviewed subplans | Retire exact approved projections from Catalog 3/8, Marketplace 78/161, Media 1/1, Messaging 28/39, Notifications 30/79 |
| R17 | Re-express Insights and Backoffice as consumers of owner ports only | Retire exact approved projections from Insights 36/79 and Backoffice 67/152 |
| R18 | Prove the ownership ledger already entered at zero, enforce repo-wide ownership strictness without a baseline, and delete the zero-valued ownership baseline | Entry ownership must already be 0/0; strict scan stays 0/0 after baseline deletion; any nonzero record returns to its owning R13-R17 phase |
| R19 | Audit the unproven remainder of the original Mobile fate map, then execute only confirmed gaps in separate Mobile plans | Provider portal, god-file, phone, and shared redistribution are either proven complete or completed; strict boundary gate stays green |
| R20 | Run one final all-surface closeout and produce the architecture-target completion report | Dependency 0, ownership 0/0, all baselines gone, all binding invariants re-proven in one run |

The ownership allocation is exhaustive and non-overlapping: R13 retires
44 records / 85 occurrences, R14A retires 60/78, R14B retires 28/80, R15
retires 10/19, R16 retires 140/288, and R17 retires 103/231. Together
R13-R17 retire exactly
385/781. The reason projection (foreign-model 301/563 plus scanner-unknown
84/218) is a cross-cut of those same records, not a second backlog assigned to
R18. R18 may begin only after R17 proves 0/0; it is a strict zero-proof and
baseline-deletion phase, not an ownership-retirement phase.

---

### Task 1: Freeze The Reconciliation Inputs And Stop On Drift

**Files:**

- Inspect only: `C:\Users\Rashad\Downloads\Telegram Desktop\2026-08-04-modular-monolith-architecture-design.md`
- Inspect only: `docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md`
- Inspect only: `admin-web/architecture/r10-admin-boundaries.json`
- Inspect only: `backend/.dependency-cruiser-known-violations.json`
- Inspect only: `backend/architecture/ownership-baseline.json`
- Inspect only: `backend/architecture/ownership-registry.json`
- Inspect only: `ARCHITECTURE.md`
- Inspect only: `docs/README.md`
- Inspect only: `docs/project/STATUS.md`
- Inspect only: `docs/project/DECISIONS.md`
- Inspect only: `docs/project/EXECUTION_PLAN.md`

**Interfaces:**

- Consumes: the original 657-line approved target, immutable R9 closeout,
  completed R10 evidence, and live machine-readable debt ledgers.
- Produces: a verified input receipt with exact repository identity, original-
  spec hash, phase semantics, dependency records, and ownership counts. No file
  is modified in this task.

- [ ] **Step 1: Confirm repository identity and preserve the existing dirty worktree**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git status --short
```

Expected: root is `D:/projects/aarast-modular-monolith`, branch is
`modular-monolith`, and HEAD is the immutable local R10 closeout
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. At R11 entry, status contains
only this untracked R11 plan. Stop on any other changed path. Do not clean,
stage, reset, checkout, or overwrite any existing path.

- [ ] **Step 2: Verify the original target identity and required clauses**

```powershell
$target = 'C:\Users\Rashad\Downloads\Telegram Desktop\2026-08-04-modular-monolith-architecture-design.md'
(Get-Content -LiteralPath $target).Count
Get-FileHash -Algorithm SHA256 -LiteralPath $target
Select-String -LiteralPath $target -Pattern '^## Objective$','^## Binding External Invariants$','^### The four dependency laws$','^## Execution Order$','Long-running mission drift'
```

Expected: 657 lines, SHA-256
`db4232f9795b5211532c454f838996af7e50d5aefee13a20d5e3e513539845f4`, and
all five clauses found. Stop if the file is missing or the hash differs.

- [ ] **Step 3: Recompute the exact dependency ledger**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture:imports
node -e "const fs=require('fs');const x=JSON.parse(fs.readFileSync('.dependency-cruiser-known-violations.json','utf8'));const by=x.reduce((a,v)=>(a[v.rule.name]=(a[v.rule.name]||0)+1,a),{});console.log(JSON.stringify({records:x.length,byRule:by},null,2));process.exitCode=x.length===22?0:1"
```

Expected: import architecture passes against the frozen ledger and prints 22
records grouped exactly as:

```json
{
  "context-backoffice-cross-context": 1,
  "context-catalog-cross-context": 5,
  "context-insights-cross-context": 2,
  "context-marketplace-cross-context": 10,
  "context-messaging-cross-context": 1,
  "context-notifications-cross-context": 1,
  "context-planning-cross-context": 2
}
```

- [ ] **Step 4: Recompute the exact ownership ledger**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture:ownership
node -e "const fs=require('fs');const v=JSON.parse(fs.readFileSync('architecture/ownership-baseline.json','utf8')).violations;const sum=(key)=>Object.fromEntries(Object.entries(v.reduce((a,x)=>{const k=key(x);a[k]??={records:0,occurrences:0};a[k].records++;a[k].occurrences+=x.count;return a;},{})).sort());console.log(JSON.stringify({records:v.length,occurrences:v.reduce((n,x)=>n+x.count,0),byContext:sum(x=>x.context),byReason:sum(x=>x.reason)},null,2));process.exitCode=v.length===385&&v.reduce((n,x)=>n+x.count,0)===781?0:1"
```

Expected: ownership scan passes against the frozen ledger and reports exactly
385 records / 781 occurrences, with these context projections:

| Context | Records | Occurrences |
| --- | ---: | ---: |
| backoffice | 67 | 152 |
| catalog | 3 | 8 |
| collaboration | 28 | 80 |
| finance | 20 | 48 |
| guests | 4 | 7 |
| identity | 60 | 78 |
| insights | 36 | 79 |
| marketplace | 78 | 161 |
| media | 1 | 1 |
| messaging | 28 | 39 |
| notifications | 30 | 79 |
| planning | 24 | 37 |
| tasks | 6 | 12 |

The reason projection must be foreign-model 301/563,
unknown-relation-shape 83/216, and unknown-sql-composition 1/2.

- [ ] **Step 5: Re-run the cumulative architecture and documentation gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
```

Expected: all three commands pass. Passing with a baseline means
"no regression beyond declared debt"; it does not mean the target is complete.

- [ ] **Step 6: Record the Task 1 checkpoint without Git mutation**

Record the commands, exact counts, and PASS results in the future R11 report.
Stop if any count or source hash differs. Do not commit; Git work requires a
separate explicit owner request.

---

### Task 2: Create The Canonical Remaining-Target Design

**Files:**

- Create: `docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md`

**Interfaces:**

- Consumes: Task 1's verified receipt, the original target, current active
  architecture docs, the 22 dependency records, and the 385/781 ownership
  projection.
- Produces: the sole tracked design governing post-R10 target completion. It
  preserves the original final architecture while versioning the execution
  sequence as R11-R20.

- [ ] **Step 1: Write the authority and status header**

Start the design with this exact semantic contract:

```markdown
# Modular Monolith Remaining Target Design

**Status:** Proposed post-R10 reconciliation. It becomes active only after
owner review. It does not authorize implementation, Git mutation, deployment,
or release activity.

The 2026-08-04 architecture document remains the source of the final target.
`ARCHITECTURE.md` remains the repository's canonical human-readable law. This
design resolves execution-sequence drift after the locally closed R0-R10 wave;
it does not weaken, cancel, or silently redefine the original target.

`R0-R10 execution wave locally closed` is not equivalent to
`modular-monolith architecture target complete`. The latter remains false
while dependency debt is 22 or ownership debt is 385/781.
```

- [ ] **Step 2: Add the exact R0-R10 reconciliation matrix**

Use this matrix without converting partial results into complete results:

| Original phase | Verified result through 2026-08-30 | Reconciliation |
| --- | --- | --- |
| R0 Governance | Governance, scanners, baselines, and CI foundations exist | Complete for its original scope |
| R1 Platform + shared-kernel | Target platform/shared-kernel relocation completed | Complete for its original scope |
| R2 Schema folder split | Native Prisma schema-folder split and equivalence gates completed | Complete for its original scope |
| R3 Ports-first strangler | 13 contexts and public/full module structure exist, but 22 cross-context records remain behind a baseline | Partial against the original zero-baseline exit |
| R4 Finance internal | One Finance-to-Planning budget write debt was retired; the full Finance internal/domain target remains | Partial |
| R5 Identity internal | 44 Identity files relocated and old roots removed; Identity ownership remains 60/78 | Partial against the original ownership-strict exit |
| R6 Collaboration internal | OTP transport separation and later Collaboration relocation landed; Collaboration ownership remains 28/80 | Partial against the original ownership-strict exit |
| R7 Remaining modules internal | The executed R7 relocated Collaboration, not all originally listed remaining modules | Original R7 scope remains incomplete |
| R8 Consumers + hardening | Project globals and missing Prisma wiring were corrected; Insights/Backoffice port-only consumption, repo-wide ownership zero, and baseline deletion remain | Partial |
| R9 Mobile | Strict public APIs and legal projection 159 passed; the broader provider-portal/god-file/phone/shared fate map was not fully re-proven | Partial until a fate-map audit closes it |
| R10 Admin + closeout | Admin restructure is complete and locally verified; the whole architecture target is not closed | Admin complete; final closeout incomplete |

- [ ] **Step 3: Add all 22 dependency records as an immutable numbered ledger**

Copy this exact list into the design so every R12 subplan retires named records
rather than adjusting a count blindly:

| ID | Consumer -> deep dependency |
| ---: | --- |
| 1 | `src/admin/admin-mutation-executor.ts` -> `src/marketplace/provider-review-rating.ts` |
| 2 | `src/catalogs/administrative-catalog.service.ts` -> `src/admin/admin-mutation-gate.ts` |
| 3 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin-permission.decorator.ts` |
| 4 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin-permission.guard.ts` |
| 5 | `src/catalogs/catalogs.controller.ts` -> `src/admin/admin.guard.ts` |
| 6 | `src/catalogs/reference-catalog.service.ts` -> `src/admin/admin-mutation-gate.ts` |
| 7 | `src/dashboard/dashboard.contracts.ts` -> `src/wedding-plans/wedding-location.ts` |
| 8 | `src/dashboard/dashboard.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 9 | `src/marketplace/marketplace.presenter.ts` -> `src/wedding-plans/wedding-location.ts` |
| 10 | `src/marketplace/marketplace.service.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 11 | `src/marketplace/marketplace.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 12 | `src/marketplace/quote-offer-acceptance.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 13 | `src/marketplace/quote-offer-acceptance.ts` -> `src/wedding-costs/wedding-cost.presenter.ts` |
| 14 | `src/marketplace/quote-offer-rejection.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 15 | `src/marketplace/quote-request-cancellation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 16 | `src/marketplace/quote-request-creation.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 17 | `src/provider-dashboard/provider-dashboard.service.ts` -> `src/conversations/conversation-lifecycle.ts` |
| 18 | `src/provider-dashboard/provider-dashboard.service.ts` -> `src/wedding-plans/wedding-location.ts` |
| 19 | `src/conversations/conversations.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |
| 20 | `src/notifications/notifications.service.ts` -> `src/provider-dashboard/provider-access-policy.ts` |
| 21 | `src/onboarding/dto/import-local-plan.dto.ts` -> `src/guests/dto/create-guest.dto.ts` |
| 22 | `src/onboarding/dto/import-local-plan.dto.ts` -> `src/tasks/dto/create-task.dto.ts` |

- [ ] **Step 4: Add the ownership ledger and exact retirement rules**

Copy Task 1's context and reason tables into the design. State that each future
phase must:

1. define the exact records and occurrences it owns before source edits;
2. add RED scanner/contract coverage for every intended boundary;
3. route foreign access through the owner public contract;
4. move Prisma access into the owner's `infrastructure/` path;
5. update the baseline by exact deletion only, never by regeneration;
6. stop on any unrelated addition, count increase, or scanner ambiguity;
7. preserve transaction scope, lock order, errors, routes, DTOs, and Arabic;
8. delete the ownership baseline only after live strict zero is proven.

Allocate the context projections exactly once: R13 owns Planning and Finance
(44/85), R14A owns Identity (60/78), R14B owns Collaboration (28/80) and may
start only after R14A exits, R15 owns Tasks and Guests (10/19), R16 owns
Catalog, Marketplace, Media, Messaging, and
Notifications (140/288), and R17 owns Insights and Backoffice (103/231). The
design must state that these totals sum to the entire 385/781 ledger and that
the reason totals are alternate classifications of the same records. R18 must
enter at 0/0, rerun strict ownership without the baseline, delete the baseline,
and stop rather than absorb any residual record.

- [ ] **Step 5: Add the R11-R20 program and entry/exit dependencies**

Copy the Program Decomposition table from this plan. Add these dependencies:

```text
R11 -> R12A -> R12B -> R12C -> R13 -> R14A Identity
R14A Identity -> R14B Collaboration -> R15
R15 -> R16 catalog -> R16 marketplace -> R16 media
R16 marketplace -> R16 messaging -> R16 notifications
R16 all -> R17 -> R18 -> R19 audit/confirmed work -> R20
```

Explain that R16 consists of five separately reviewable subplans and R19 begins
with a read-only fate-map audit. No Mobile implementation is allowed if that
audit proves the original target already satisfied.

- [ ] **Step 6: Add permanent stop rules and final definition of done**

The design's final target gate must require all of the following in one
verified run:

- dependency-cruiser strict with no known-violations file;
- ownership strict at 0 records / 0 occurrences with no ownership baseline;
- all 13 Backend contexts import only public contracts;
- owner-only Prisma access, pure Finance domain, acyclic graph,
  `forwardRef()` 0, and project `@Global()` 0;
- unchanged Prisma schema and migrations with equivalence proof;
- Backend check/build/full tests/full managed smoke;
- Mobile analyze/full tests/boundary strict and real-phone affected journeys;
- Admin architecture/typecheck/build/full tests/honesty/runtime checks;
- unchanged generated Backend, Mobile, and Admin route contracts;
- docs sync/verify and `git diff --check` green;
- independent code, architecture, runtime, and cumulative-plan review;
- a final report that distinguishes local completion from push, merge,
  deployment, remote CI, real delivery providers, and store release.

- [ ] **Step 7: Review Task 2 without modifying any application path**

Read the new design top to bottom against lines 13-28, 86-104, 148-161, and
603-644 of the original target. Confirm every original incomplete outcome maps
to R12-R20 and that no original completed outcome is scheduled for gratuitous
rework.

---

### Task 3: Reconcile The Active Architecture And Project Documents

**Files:**

- Modify: `ARCHITECTURE.md`
- Modify: `docs/README.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Consumes: the proposed remaining-target design from Task 2.
- Produces: one consistent active-document story: R10 Admin is locally
  committed, R0-R10 is a closed execution wave with declared gaps, R11 is the
  proposed reconciliation, and the architecture target remains incomplete.

- [ ] **Step 1: Add the post-R10 contract to `ARCHITECTURE.md`**

After the existing R10 section, add a `Post-R10 Target Completion Contract`
section that:

- links the new design and this plan;
- preserves the existing R0-R10 historical evidence unchanged;
- states exact live debt 22 and 385/781;
- lists R11-R20 with the same bounded outcomes as the design;
- forbids widening a phase after its plan is approved;
- requires exact baseline subtraction, not regenerated baselines;
- reserves `architecture target complete` for R20 only.

- [ ] **Step 2: Link the R11 artifacts from `docs/README.md`**

Insert one new first item under `Modular Monolith Status And Plans`. It must say
that the R11 design and plan reconcile the original target with current state,
do not authorize implementation, and retain the exact 22 and 385/781 debt.
Do not remove or rewrite the R0-R10 historical entries.

- [ ] **Step 3: Update current state in `docs/project/STATUS.md`**

At the current modular-monolith status section, add:

```markdown
- R11 target reconciliation is planned, not implemented.
- R10 is locally committed at `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`;
  push, merge, deployment, and remote CI remain unproven and are not authorized.
- The architecture target remains incomplete at dependency 22 and ownership
  385/781.
- The next implementation work is forbidden until the R11 design is reviewed
  and a separate R12A design/plan is approved.
```

Keep all release, provider-delivery, and device limitations truthful.

- [ ] **Step 4: Record the source-of-truth decision in `docs/project/DECISIONS.md`**

Add one accepted-for-planning decision row with this substance:

| Decision | Status | Rationale |
| --- | --- | --- |
| Version the post-R10 execution sequence as R11-R20 while preserving the 2026-08-04 final target. | Proposed for owner approval | Later R4-R9 plans narrowed their phase labels without updating the original external specification. Active docs already disclose the remaining 22 and 385/781 debt. The reconciliation makes that drift explicit, keeps completed work, forbids false target-complete language, and restores just-in-time phase gates. |

Do not describe the row as implemented until all R11 tasks pass.

- [ ] **Step 5: Add the executable program to `docs/project/EXECUTION_PLAN.md`**

Add a `Post-R10 Architecture Target Completion` section containing the exact
R11-R20 table and dependency chain from Task 2. Each future row must point to a
not-yet-created just-in-time design/plan requirement rather than naming
unreviewed source edits.

- [ ] **Step 6: Add a documentation-only entry to `CHANGELOG.md`**

Record only that a post-R10 reconciliation plan/design was added and active
docs were aligned. State that R11 changed no application source, API, schema,
runtime, Git history, deployment, or release state; the local R10 commit
predates R11 and is the immutable R11 base.

- [ ] **Step 7: Inspect the active-doc diff as one unit**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git diff -- ARCHITECTURE.md docs/README.md docs/project/STATUS.md docs/project/DECISIONS.md docs/project/EXECUTION_PLAN.md CHANGELOG.md
```

Expected: only post-R10 authority, status, phase order, and links change. Stop
if any prior gate result, product behavior, route, schema, deployment fact, or
R10 evidence is rewritten.

---

### Task 4: Write The R11 Evidence Receipt

**Files:**

- Create: `docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md`

**Interfaces:**

- Consumes: Task 1 evidence and the reviewed Task 2-3 documentation diff.
- Produces: a concise final R11 receipt that supports one next action only:
  owner review followed by a separate R12A design/plan.

- [ ] **Step 1: Write the verdict without overclaiming**

Use this verdict:

```markdown
Verdict: **R11 documentation reconciliation complete locally. The
modular-monolith architecture target remains incomplete.**
```

If any Task 5 verification fails, replace `complete locally` with `blocked`
and name the failing command.

- [ ] **Step 2: Record exact evidence and scope**

The report must include:

- repository root, branch, R9 historical base, R10/R11 base HEAD, and
  original-spec SHA-256;
- changed-file list containing only the nine R11 Markdown paths;
- R0-R10 reconciliation matrix result;
- dependency 22 grouped 1/5/2/10/1/1/2;
- ownership 385/781, context table, and reason table;
- PASS/FAIL for architecture imports, ownership, cumulative architecture,
  docs-sync, docs-verify, and diff check;
- explicit statement that baselines still exist and therefore target
  completion is false;
- explicit statement that R11 changed no source, tests, schema, migrations,
  packages, CI, deployment, Git history, runtime, phone, WhatsApp, Push, or
  release state, and that the local R10 commit predates R11.

- [ ] **Step 3: Record gaps and the only next authorized planning action**

List R12-R20 as remaining. End with:

```markdown
Next action: obtain owner approval for the R11 authority model, then create the
separate R12A design and implementation plan for dependency records 1-6. Do
not implement R12A from this report.
```

---

### Task 5: Run The R11 Documentation And Scope Gates

**Files:**

- Verify: all nine R11 Markdown paths
- Verify unchanged: every non-Markdown application, test, configuration,
  schema, migration, package, CI, Docker, Compose, Dokploy, and deployment path

**Interfaces:**

- Consumes: completed R11 documentation.
- Produces: a PASS/FAIL gate and a reviewed handoff. It does not commit or
  start R12.

- [ ] **Step 1: Verify the exact R11 path fence**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --input-type=module -e "import{execFileSync}from'node:child_process';import{checkR10Scope}from'./scripts/check-r10-scope.mjs';const root=process.cwd();const base='e560e5784278907dd6bf565327c3abfa0c9b8cab';const head='4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';const raw=execFileSync('git',['diff','--name-only','-z','--no-renames','--diff-filter=ACDMRTUXB',base,head,'--'],{cwd:root});const paths=raw.toString().split('\0').filter(Boolean).map(p=>p.replace(/\\/g,'/'));const r=checkR10Scope({repoRoot:root,task:'task-11'},{changedPaths:paths});console.log({historicalR10Base:base,historicalR10Head:head,historicalR10Paths:paths.length,historicalR10Scope:r.ok,errors:r.errors});process.exitCode=r.ok?0:1"
node --input-type=module -e "import{collectChangedPaths}from'./scripts/check-r10-scope.mjs';const root=process.cwd();const base='4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1';const allowed=new Set(['ARCHITECTURE.md','CHANGELOG.md','docs/README.md','docs/project/DECISIONS.md','docs/project/EXECUTION_PLAN.md','docs/project/STATUS.md','docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md','docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md','docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md']);const all=collectChangedPaths({repoRoot:root,base});const missing=[...allowed].filter(p=>!all.includes(p));const unexpected=all.filter(p=>!allowed.has(p));const nonMarkdown=all.filter(p=>!p.toLowerCase().endsWith('.md'));console.log({r11Base:base,r11Paths:all.length,missing,unexpected,nonMarkdown});process.exitCode=all.length===allowed.size&&missing.length===0&&unexpected.length===0&&nonMarkdown.length===0?0:1"
```

Expected: the first command reports `historicalR10Paths: 178`,
`historicalR10Scope: true`, and `errors: []` for the immutable
`e560e578...4d0d3ee9` interval. The second command reports `r11Paths: 9`,
`missing: []`, `unexpected: []`, and `nonMarkdown: []` against the independent
R11 base `4d0d3ee9`. Do not add R11 files to the R10 manifest; R10's historical
fence remains immutable.

- [ ] **Step 2: Verify all new active links resolve**

```powershell
$required = @(
  'docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md',
  'docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md',
  'docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md'
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
$missing
if ($missing.Count -ne 0) { throw 'R11 link target missing' }
```

Expected: no missing path.

- [ ] **Step 3: Scan the R11 artifacts for placeholder language and false completion**

```powershell
$r11 = @(
  'docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md',
  'docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md',
  'docs/superpowers/reports/2026-09-01-modular-monolith-r11-reconciliation-report.md'
)
rg -n 'T[B]D|implement[ ]later|fill[ ]in[ ]details|architecture target complete' $r11
```

Expected before implementation: the plan may contain the quoted forbidden
completion phrase only in explanatory/negative form. The design and report
must not contain placeholders or a positive target-complete claim.

- [ ] **Step 4: Run documentation verification**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: all commands pass. Existing line-ending notices without diff errors
are non-failing; any actual whitespace error is a stop.

- [ ] **Step 5: Re-run architecture debt truth checks**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync('.dependency-cruiser-known-violations.json','utf8'));const o=JSON.parse(fs.readFileSync('architecture/ownership-baseline.json','utf8')).violations;const n=o.reduce((s,x)=>s+x.count,0);console.log({dependency:d.length,ownershipRecords:o.length,ownershipOccurrences:n});process.exitCode=d.length===22&&o.length===385&&n===781?0:1"
```

Expected: architecture passes and the exact debt remains 22 and 385/781.
R11 must not make a source debt disappear through documentation.

- [ ] **Step 6: Perform the required self-review against the original spec**

Check each item and correct the R11 documents inline if necessary:

1. Every original incomplete phase outcome maps to one R12-R20 phase.
2. No R11 step authorizes application code, Git, deployment, or provider use.
3. The 22 dependency records and 385/781 ownership projection are exact.
4. R12-R20 ordering respects Finance-before-Marketplace, the explicit
   R14A-Identity-before-R14B-Collaboration gate, Identity-before-Backoffice,
   and R8-style hardening before Mobile/final closeout.
5. No baseline can be regenerated, widened, or deleted early.
6. No existing test can be weakened to pass a relocation.
7. Every future phase has a separate design/plan/review requirement.
8. Historical R0-R10 evidence remains recoverable and is not rewritten as
   failure.
9. `architecture target complete` remains reserved for R20.
10. R13-R17 own the entire non-overlapping 385/781 retirement, and R18 enters
    at 0/0 solely to prove strict zero and delete the ownership baseline.

- [ ] **Step 7: Stop for owner review**

Report the nine changed Markdown paths and every PASS/FAIL result. Do not
commit, push, merge, deploy, or begin R12A. The next action requires explicit
owner approval of the R11 authority model.

## Execution Handoff

Plan creation is complete when this file passes its self-review. Execution has
two valid modes after owner approval:

1. **Subagent-Driven (recommended):** use
   `superpowers:subagent-driven-development`, one fresh worker per task, with
   specification and quality review between tasks.
2. **Inline Execution:** use `superpowers:executing-plans` in this session with
   review checkpoints after each task.

Neither mode authorizes Git or R12 implementation. Those remain separate owner
decisions.
