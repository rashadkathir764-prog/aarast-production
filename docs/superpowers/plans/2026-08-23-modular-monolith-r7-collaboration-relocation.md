# Modular Monolith R7 Collaboration Relocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relocate the exact 18 legacy Collaboration TypeScript files into the
existing `backend/src/modules/collaboration` API, internal, and public slices
without changing runtime behavior, then prove the result through architecture,
behavior, smoke, immutable-runtime, and authenticated-phone gates.

**Architecture:** The move is one-to-one and staged: first the public snapshot
builder and its consumers, then Contribution History, then Sharing. Earlier
R3-R6 scanners keep proving their immutable historical revisions while the R7
scanner alone proves the live staged and strict layouts. No compatibility path,
facade, duplicate implementation, baseline regeneration, or service rewrite is
permitted.

**Tech Stack:** Windows/PowerShell, Node.js 22, TypeScript, NestJS 11, Prisma
6.19.3, Node test runner, dependency-cruiser, Docker, Flutter/ADB phone QA.

**Spec:**
`docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-design.md`

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch
  `modular-monolith`.
- Immutable R7 base is `31ea5324007fc71fa4b3590fbb98a454ee1deaa7`.
- Approved design-governance checkpoint is
  `0fcea51ecc1e62459f805976150cc96ae17bf172`.
- Local checkpoint commits are authorized. Do not create or switch branches or
  worktrees.
- Do not push, merge, mutate PR #76, deploy, run remote CI, or start R8.
- Move exactly the 18 manifest entries. Do not add a barrel, re-export, facade,
  symlink, junction, fallback import, second implementation, or deferred-removal
  artifact.
- Preserve all 19 routes, DTO rules, response shapes, errors, Arabic/English
  copy, permissions, privacy, transactions, locks, retries, events, logs,
  metrics, timeouts, token identity, provider lifetime, and singleton bindings.
- Preserve `SharingService` as one implementation. Only required import paths
  may change inside it.
- Preserve the existing optional `SharingService.realtime` dependency at
  constructor index 5 with `@Optional()`, `MESSAGING_REALTIME_PORT`, and current
  `undefined` behavior. Add no other optional or default constructor dependency.
- Preserve Prisma schema, migrations, seed, package dependencies,
  `package-lock.json`, Mobile, Admin Web, workflows, Dockerfiles, Compose,
  Dokploy, ports, domains, and secrets.
- Existing behavior assertions, values, fixtures, skips, setup order, and
  cleanup semantics are frozen. Only exact path/import/DI rewiring required by
  the move may change.
- The dependency baseline must move from 31 to exactly 22 by deleting the exact
  nine manifest keys. Ownership remains exactly 385 records / 781 occurrences,
  with only the four manifest path projections changing.
- Every application/scanner code-changing task ends with its focused tests,
  `npm run architecture`, `npm run check`, diff review,
  `git diff --check`, and a reviewed local checkpoint before the next task
  begins. Verification-only tasks require a clean immutable commit, not an
  empty commit.
- No pass inherited from R6 is valid after an R7 source edit. Re-run every gate
  claimed for the exact current candidate.

## Planned File Responsibilities

| Path group | Responsibility |
| --- | --- |
| `backend/architecture/r7-collaboration-relocation.json` | Fixed base, stage, 18 moves, 114-path fence, DI/controller handoffs, optionality, dependency retirement, and ownership projections |
| `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs` | Live AST, filesystem identity, staged layout, baseline, ownership, protected-surface, and strict no-legacy gate |
| `backend/test/architecture-r7-collaboration-relocation.test.ts` | Positive and adversarial R7 stage/parity/scope tests |
| `backend/src/modules/collaboration/public/contribution-snapshot.builder.ts` | Sole public stateless snapshot implementation with four frozen exports |
| `backend/src/modules/collaboration/api/**` | Two controllers and six DTOs at their final owner paths |
| `backend/src/modules/collaboration/internal/**` | Nine moved services/contracts/policies plus four existing internal Nest modules |
| Nine cross-context snapshot callers | Import the final public builder and retire nine dependency debts |
| `backend/.dependency-cruiser-known-violations.json` | Remove only the exact nine obsolete snapshot records |
| `backend/architecture/ownership-baseline.json` | Change only four source paths while preserving 385/781 semantics |
| R3-R6 scanner/test handoffs | Prove historical revisions while delegating exact R7 final paths |
| Behavior tests and managed smokes in the 114-path fence | Mechanical import/path-literal changes only; assertions stay frozen |
| Active architecture/project/QA docs | Record stage, observed counts, candidates, runtime/phone evidence, and stop boundary |

---

### Task 0: Checkpoint The Approved Execution Contract

**Files:**

- Create:
  `docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation.md`
- Modify:
  `docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-design.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`

**Interfaces:**

- Consumes: approved R7 design and governance checkpoint `0fcea51e`.
- Produces: one approved implementation order and an explicit no-application-
  move planning checkpoint.

- [ ] **Step 1: Verify the exact planning preflight**

Run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
git branch --show-current
git rev-parse HEAD
git status --short
git merge-base --is-ancestor 31ea5324007fc71fa4b3590fbb98a454ee1deaa7 HEAD
npm --prefix backend run architecture:r7
```

Expected: branch `modular-monolith`, HEAD exactly
`0fcea51ecc1e62459f805976150cc96ae17bf172`, ancestor exit 0, R7
`stage=design, source=18, target=0`, and `git status --short` lists exactly the
nine documentation paths declared by Task 0 with no application/config drift.

- [ ] **Step 2: Review plan coverage and placeholders**

Run:

```powershell
$plan = 'docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation.md'
$redFlags = @(
  'T' + 'BD',
  'T' + 'ODO',
  'implement ' + 'later',
  'fill in ' + 'details',
  'similar ' + 'to',
  'frozen ' + 'signature',
  '\.\.\.'
) -join '|'
rg -n $redFlags $plan
rg -n '^### Task [0-8]:' $plan
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: no placeholder matches, exactly Tasks 0-8, and all documentation and
whitespace checks pass.

- [ ] **Step 3: Create the local planning checkpoint**

Stage exactly the nine documentation paths above, inspect
`git diff --cached --name-status` and `git diff --cached --check`, then commit:

```powershell
git commit -m "docs: approve modular monolith R7 plan"
```

Expected: a docs-only local checkpoint and clean worktree. Do not push.

---

### Task 1: Extend R7 Into A Staged Relocation And Parity Gate

**Files:**

- Modify: `backend/architecture/r7-collaboration-relocation.json`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify: `backend/test/architecture-r3-scope.test.ts`
- Create ignored:
  `.superpowers/sdd/2026-08-23-modular-monolith-r7-collaboration-relocation/task-1-report.md`

**Interfaces:**

- Consumes: the exact 18-entry manifest, four public exports, four constructor
  handoffs, two controller inventories, nine debt keys, and 385/781 ownership
  contract.
- Produces: `design`, `snapshot`, `history`, `relocated`, and `strict` stages;
  exact stage counts; normalized source-parity evidence; and a fail-closed live
  scanner.

- [ ] **Step 1: Write the staged-layout RED**

Add table-driven tests with this exact contract:

```ts
const expectedStageCounts = {
  design: { sourceFiles: 18, targetFiles: 0 },
  snapshot: { sourceFiles: 17, targetFiles: 1 },
  history: { sourceFiles: 12, targetFiles: 6 },
  relocated: { sourceFiles: 0, targetFiles: 18 },
  strict: { sourceFiles: 0, targetFiles: 18 },
} as const;
```

The fixture must reject mixed layouts, both source and target, neither path,
converging targets, a directory junction, an extra file under either final
slice, and an undeclared legacy file.

- [ ] **Step 2: Write behavior-parity and bypass RED tests**

For every move, capture an immutable base source fingerprint and compare the
active file after normalizing only reviewed relative import specifiers. Add
negative fixtures for a changed statement, class, method, decorator, route,
parameter, error text, default, optional marker, token, dynamic dependency,
extra export, extra file, or compatibility re-export.

The public builder must retain exactly:

```ts
export function buildContributionSnapshot(
  entityType: ContributionEntityType,
  source: SnapshotSource,
): Prisma.JsonObject;
export function canonicalJson(value: unknown): string;
export function hashContributionSnapshot(snapshot: unknown): string;
export function validateContributionSnapshot(
  snapshot: unknown,
): asserts snapshot is Prisma.JsonObject;
```

and only imports `node:crypto`, `@nestjs/common`, and `@prisma/client`.

- [ ] **Step 3: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r7-collaboration-relocation.test.ts
```

Expected: FAIL because the scanner currently accepts only `design` and does not
yet carry all 18 normalized parity fingerprints.

- [ ] **Step 4: Implement the smallest staged scanner**

Use the TypeScript compiler AST and exact manifest data. The implementation
must select one active path per move, validate its stage, compare the normalized
AST/source contract, reject runtime imports from another context into
`internal/` or `api/`, and produce bounded plain output:

```js
Object.freeze({
  ok: true,
  stage: manifest.stage,
  sourceFiles,
  targetFiles,
  dependencyRecords,
  ownershipRecords,
  ownershipOccurrences,
});
```

Do not add a generic allow pattern or modify
`.dependency-cruiser.cjs`/`ownership-scan.cjs`; their existing generic module
classification already covers Collaboration.

- [ ] **Step 5: Run GREEN and checkpoint**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r7-collaboration-relocation.test.ts test/architecture-r3-scope.test.ts
npm run architecture
npm run check
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: PASS at `design`, 18/0, dependency 31, ownership 385/781. Review the
exact diff and create a local Task 1 checkpoint. Do not push.

---

### Task 2: Move The Public Snapshot Builder And Retire Nine Debts

**Files:**

- Move:
  `backend/src/contribution-history/contribution-snapshot.builder.ts` ->
  `backend/src/modules/collaboration/public/contribution-snapshot.builder.ts`
- Modify the nine cross-context callers:
  `backend/src/budget-categories/budget-categories.service.ts`,
  `backend/src/wedding-costs/wedding-costs.service.ts`,
  `backend/src/guests/guests.service.ts`,
  `backend/src/marketplace/quote-offer-acceptance.ts`,
  `backend/src/marketplace/quote-offer-rejection.ts`,
  `backend/src/marketplace/quote-request-cancellation.ts`,
  `backend/src/marketplace/quote-request-creation.ts`,
  `backend/src/tasks/tasks.service.ts`, and
  `backend/src/wedding-plans/wedding-plans.service.ts`
- Modify same-context caller: `backend/src/sharing/sharing.service.ts`
- Modify legacy history caller:
  `backend/src/contribution-history/contribution-history.service.ts`
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/architecture/r7-collaboration-relocation.json`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/test/architecture-r6-sharing-otp-transport.test.ts`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify import paths only:
  `backend/test/contribution-history-dedupe.test.ts` and
  `backend/test/contribution-history-privacy.test.ts`
- Create ignored: task-2 report under the R7 SDD directory.

**Interfaces:**

- Consumes: the frozen four-export builder contract.
- Produces: one final public builder implementation, eleven rewired callers,
  manifest `stage=snapshot`, 17/1 files, and dependency baseline 22.

- [ ] **Step 1: Write the public-boundary RED**

Prove all nine cross-context callers import exactly:

```ts
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
```

Adjust only the relative prefix required by each caller. Prove
`SharingService` imports
`../modules/collaboration/public/contribution-snapshot.builder` until it moves,
and prove the still-legacy `ContributionHistoryService` imports its three
helper exports from the same final public builder:

```ts
import {
  canonicalJson,
  hashContributionSnapshot,
  validateContributionSnapshot,
} from "../modules/collaboration/public/contribution-snapshot.builder";
```

The old builder path must be absent, all four exports retain their signatures,
and the exact nine dependency keys disappear rather than changing targets.
Add independent RED fixtures to the R3, R5, and R6 tests before editing their
scanners: each historical scanner must still prove its immutable 31-record
revision, while its explicit R7 handoff must accept only the exact live
22-record projection. Each fixture must reject replacing the historical 31
with 22, accepting live 31, a renamed debt, or an unrelated deletion.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-contexts.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/contribution-history-dedupe.test.ts test/contribution-history-privacy.test.ts
npm run architecture:imports
```

Expected: FAIL because R3/R5/R6 do not yet expose the historical-31/live-22 R7
handoff, the builder and callers still use the legacy path, and the live
baseline still contains 31 records.

- [ ] **Step 3: Move once and rewire imports mechanically**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git mv backend/src/contribution-history/contribution-snapshot.builder.ts backend/src/modules/collaboration/public/contribution-snapshot.builder.ts
```

Update only the import specifiers. Do not alter the builder body, exports,
validation, privacy rules, size limits, hashes, exceptions, or messages.

- [ ] **Step 4: Reconcile the exact dependency evidence**

Delete the nine manifest-named records from
`.dependency-cruiser-known-violations.json`. Extend R3, R5, and R6 historical
projection so each proves its immutable 31-record revision while R7 proves the
live 22-record baseline. Reject a retained renamed key, an unrelated deletion,
or a count other than 22.

- [ ] **Step 5: Run GREEN and checkpoint**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-contexts.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/contribution-history-dedupe.test.ts test/contribution-history-privacy.test.ts
npm run architecture
npm run check
npm run build
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: R7 `snapshot` 17/1, dependency 22, ownership 385/781, all four public
exports unchanged, and no old builder file. Review and commit the Task 2
checkpoint locally. Do not push.

---

### Task 3: Move Contribution History API And Internals

**Files:**

- Move the five remaining `backend/src/contribution-history/**` files to their
  exact manifest targets under `modules/collaboration/api` and `internal`.
- Modify: `backend/src/modules/collaboration/collaboration.module.ts`
- Modify:
  `backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts`
- Modify:
  `backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts`
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify import/path literals only:
  `backend/scripts/smoke/phase2-conversation-revocation-smoke.ts`,
  `backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts`, and
  `backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts`
- Modify import/path literals only:
  `backend/test/architecture-r3-closure.test.ts`,
  `backend/test/architecture-r3-collaboration-ports.test.ts`,
  `backend/test/contribution-history-dedupe.test.ts`,
  `backend/test/contribution-history-list-consistency.test.ts`,
  `backend/test/contribution-history-privacy.test.ts`,
  `backend/test/contributor-live-read-boundary.test.ts`, and
  `backend/test/contributor-task-guest-scope.test.ts`
- Modify: `backend/architecture/ownership-baseline.json`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Create ignored: task-3 report under the R7 SDD directory.

**Interfaces:**

- Consumes: final public snapshot builder and existing Collaboration history/
  scope Symbol bindings.
- Produces: six final Contribution History files total, manifest
  `stage=history`, 12/6 files, controller identity 2 operations, and the exact
  5-record/7-occurrence ownership path projection.

- [ ] **Step 1: Write the history-relocation RED**

Pin the final paths, controller inventory, `ContributionHistoryService` and
`ContributorScopeService` provider identities, `useExisting` aliases, module
exports, internal relative imports, and zero `src/contribution-history` runtime
imports. Add a negative fixture where a controller route, `CurrentUser`, query
parameter, provider class, or ownership semantic field changes.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-collaboration-ports.test.ts test/architecture-r3-contexts.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r7-collaboration-relocation.test.ts test/contribution-history-freeze.test.ts test/contribution-history-list-consistency.test.ts test/contributor-live-read-boundary.test.ts test/contributor-task-guest-scope.test.ts
```

Expected: FAIL because the R3/R5 live handoffs, five Contribution History
files, and live path literals remain at the legacy root.

- [ ] **Step 3: Perform the five one-to-one moves**

```powershell
Set-Location D:\projects\aarast-modular-monolith
New-Item -ItemType Directory -Path backend/src/modules/collaboration/api/dto -Force | Out-Null
git mv backend/src/contribution-history/contribution-history.contracts.ts backend/src/modules/collaboration/internal/contribution-history.contracts.ts
git mv backend/src/contribution-history/contribution-history.controller.ts backend/src/modules/collaboration/api/contribution-history.controller.ts
git mv backend/src/contribution-history/contribution-history.service.ts backend/src/modules/collaboration/internal/contribution-history.service.ts
git mv backend/src/contribution-history/contributor-scope.service.ts backend/src/modules/collaboration/internal/contributor-scope.service.ts
git mv backend/src/contribution-history/dto/list-contributions.dto.ts backend/src/modules/collaboration/api/dto/list-contributions.dto.ts
```

Change only relative import specifiers. Rewire the Collaboration modules and
the still-legacy `SharingService` to the final internal/public paths without
adding a public service export or duplicate provider. Because the service now
moves beside Collaboration internals, update its Task 2 public-builder import
from `../modules/collaboration/public/contribution-snapshot.builder` to
`../public/contribution-snapshot.builder` mechanically.

- [ ] **Step 4: Reconcile historical tests, smokes, and ownership paths**

Update only import/path literals in affected tests and managed smokes. In the
ownership baseline, replace the history service source path for exactly five
records / seven occurrences; keep every other field and the total 385/781
unchanged.

- [ ] **Step 5: Run GREEN and checkpoint**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-collaboration-ports.test.ts test/architecture-r3-contexts.test.ts test/architecture-r3-scope.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r7-collaboration-relocation.test.ts test/contribution-history-dedupe.test.ts test/contribution-history-freeze.test.ts test/contribution-history-list-consistency.test.ts test/contribution-history-privacy.test.ts test/contributor-live-read-boundary.test.ts test/contributor-task-guest-scope.test.ts
npm run architecture
npm run check
npm run build
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: R7 `history` 12/6, dependency 22, ownership 385/781, and no tracked
file under `backend/src/contribution-history`. Review and commit locally.

---

### Task 4: Move Sharing API, DTOs, And Internals

**Files:**

- Move all 12 `backend/src/sharing/**` files to the exact manifest targets.
- Modify: `backend/src/modules/collaboration/collaboration.module.ts`
- Modify:
  `backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts`
- Modify:
  `backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts`
- Modify import/path literals only in all 11 manifest-listed managed smokes:
  `backend/scripts/smoke/phase2-auth-lifecycle-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-conversation-revocation-smoke.ts`,
  `backend/scripts/smoke/phase2-marketplace-write-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-notification-authorization-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-notification-preferences-smoke.ts`,
  `backend/scripts/smoke/phase2-plan-permission-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-quote-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts`,
  `backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts`, and
  `backend/scripts/smoke/phase3-context-transition-smoke.ts`
- Modify import/path literals only in architecture tests:
  `backend/test/architecture-r1-layout.test.ts`,
  `backend/test/architecture-r3-collaboration-ports.test.ts`,
  `backend/test/architecture-r3-composition.test.ts`,
  `backend/test/architecture-r3-contexts.test.ts`,
  `backend/test/architecture-r3-identity-port.test.ts`,
  `backend/test/architecture-r3-notifications-port.test.ts`,
  `backend/test/architecture-r5-identity-relocation.test.ts`,
  `backend/test/architecture-r6-sharing-otp-transport.test.ts`, and
  `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify import/path literals only in behavior tests:
  `backend/test/archived-plan-lifecycle.test.ts`,
  `backend/test/contexts.test.ts`,
  `backend/test/contribution-history-freeze.test.ts`,
  `backend/test/contributor-live-read-boundary.test.ts`,
  `backend/test/contributor-permission-authority.test.ts`,
  `backend/test/invite-delivery.test.ts`,
  `backend/test/notification-logic.test.ts`,
  `backend/test/plan-permissions.test.ts`,
  `backend/test/sharing-member-scope.test.ts`,
  `backend/test/sharing-permission-ceiling.test.ts`,
  `backend/test/sharing-reinvite-authority.test.ts`, and
  `backend/test/sharing-self-leave.test.ts`
- Modify: `backend/architecture/ownership-baseline.json`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Create ignored: task-4 report under the R7 SDD directory.

**Interfaces:**

- Consumes: final Contribution History internal/public paths and the existing
  Identity, Messaging, Notifications, and Collaboration public tokens.
- Produces: all 18 files at final paths, manifest `stage=relocated`, 0/18 files,
  17 Sharing controller operations, four constructor handoffs, one frozen
  optional dependency, and the remaining 23-record/73-occurrence ownership
  path projection.

- [ ] **Step 1: Write the Sharing relocation RED**

Pin the exact final files and prove:

```ts
constructor(
  private readonly prisma: PrismaService,
  private readonly permissions: PermissionService,
  @Inject(NOTIFICATIONS_PORT)
  private readonly notifications: NotificationsPort,
  private readonly invitationDelivery: InvitationDeliveryService,
  private readonly history: ContributionHistoryService,
  @Optional()
  @Inject(MESSAGING_REALTIME_PORT)
  private readonly realtime?: MessagingRealtimePort,
) {}
```

Also pin `InvitationDeliveryService.transientDelivery` at index 0 with
`IDENTITY_TRANSIENT_DELIVERY_PORT` and `InviteAccessService.auth` at index 1
with `IDENTITY_AUTH_PORT`. Add negative fixtures for index, token, class,
`@Optional()`, `?`, default initializer, duplicate provider, controller route,
guard, DTO decorator, and unknown error drift.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r1-layout.test.ts test/architecture-r3-collaboration-ports.test.ts test/architecture-r3-composition.test.ts test/architecture-r3-contexts.test.ts test/architecture-r3-identity-port.test.ts test/architecture-r3-notifications-port.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts
```

Expected: FAIL because the Sharing implementation still occupies the legacy
root.

- [ ] **Step 3: Perform the 12 exact moves**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git mv backend/src/sharing/dto/create-plan-invite.dto.ts backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts
git mv backend/src/sharing/dto/create-shared-member.dto.ts backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts
git mv backend/src/sharing/dto/leave-plan.dto.ts backend/src/modules/collaboration/api/dto/leave-plan.dto.ts
git mv backend/src/sharing/dto/request-invite-otp.dto.ts backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts
git mv backend/src/sharing/dto/update-shared-member.dto.ts backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts
git mv backend/src/sharing/dto/verify-invite-otp.dto.ts backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts
git mv backend/src/sharing/invitation-delivery.service.ts backend/src/modules/collaboration/internal/invitation-delivery.service.ts
git mv backend/src/sharing/invite-access.service.ts backend/src/modules/collaboration/internal/invite-access.service.ts
git mv backend/src/sharing/permission.service.ts backend/src/modules/collaboration/internal/permission.service.ts
git mv backend/src/sharing/plan-permissions.ts backend/src/modules/collaboration/internal/plan-permissions.ts
git mv backend/src/sharing/sharing.controller.ts backend/src/modules/collaboration/api/sharing.controller.ts
git mv backend/src/sharing/sharing.service.ts backend/src/modules/collaboration/internal/sharing.service.ts
```

Update relative imports and the three Collaboration composition files only.
Do not restructure `SharingService`, reorder its constructor, or alter its
body.

- [ ] **Step 4: Rewire every affected test and managed smoke mechanically**

Use `rg -n 'src/sharing|sharing/|src/contribution-history|contribution-history/'`
across `backend/src`, `backend/test`, and `backend/scripts/smoke`. Every changed
assertion must be a path/import identity from the manifest; expected behavior,
setup, order, and cleanup remain byte-identical.

- [ ] **Step 5: Reconcile ownership and historical handoffs**

Project only these final sources: invite access 1/1, permission 2/6, and
sharing service 20/66. Preserve total 385/781. R3/R5/R6 scanners must verify
their immutable bases and exact final handoffs; R7 verifies the live final
paths.

- [ ] **Step 6: Run focused GREEN and checkpoint**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/archived-plan-lifecycle.test.ts test/contexts.test.ts test/contribution-history-freeze.test.ts test/contributor-live-read-boundary.test.ts test/contributor-permission-authority.test.ts test/invite-delivery.test.ts test/notification-logic.test.ts test/plan-permissions.test.ts test/sharing-member-scope.test.ts test/sharing-permission-ceiling.test.ts test/sharing-reinvite-authority.test.ts test/sharing-self-leave.test.ts
node --test -r ts-node/register test/architecture-r1-layout.test.ts test/architecture-r3-collaboration-ports.test.ts test/architecture-r3-composition.test.ts test/architecture-r3-contexts.test.ts test/architecture-r3-identity-port.test.ts test/architecture-r3-notifications-port.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts
npm run architecture
npm run check
npm run build
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: R7 `relocated` 0/18, dependency 22, ownership 385/781, and no tracked
file under either legacy root. Review and create the Task 4 local checkpoint.

---

### Task 5: Promote R7 To Strict And Create The Application Candidate

**Files:**

- Modify: `backend/architecture/r7-collaboration-relocation.json`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Create ignored: task-5 report under the R7 SDD directory.

**Interfaces:**

- Consumes: the fully relocated 0/18 source layout and reconciled 22 + 385/781
  baselines.
- Produces: `stage=strict`, no legacy roots/imports, no compatibility artifact,
  cumulative R1-R7 green architecture, and one immutable application-candidate
  commit.

- [ ] **Step 1: Write strict-stage RED**

Require absence of both legacy directories, all legacy import literals, old
baseline keys, internal/API cross-context imports, duplicate exports,
unregistered target files, symlinks/junctions, `forwardRef()`, and new globals.
Require final controller, provider, DI, builder, dependency, and ownership
inventories.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r7-collaboration-relocation.test.ts
```

Expected: FAIL while the manifest remains `relocated`.

- [ ] **Step 3: Promote only the verified manifest/scanner state**

Set `stage` to `strict`. Do not change product source or generated script docs;
verify the existing script inventory through
`node scripts/docs-sync.mjs --check` from repository root.

- [ ] **Step 4: Run the complete pre-candidate gate**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npx prisma generate
npm run security:prisma-config-merge
Set-Location D:\projects\aarast-modular-monolith
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: all PASS, R7 strict 0/18, dependency 22, ownership 385/781, one
intentional platform skip only if still reported, and protected surfaces
unchanged.

- [ ] **Step 5: Create the application candidate checkpoint**

From `D:\projects\aarast-modular-monolith`, review
`git diff 0fcea51e --name-status`, verify every path belongs to the 114-path
manifest, stage only reviewed paths, run staged whitespace/path checks, commit
locally, record the full SHA, and confirm clean status. Do not push.

---

### Task 6: Exhaustively Verify And Independently Review The Candidate

**Files:** No product changes planned. Any correction requires a reproduced
failure, an in-scope root cause, a failing regression test, and a separate
reviewed checkpoint.

**Interfaces:**

- Consumes: immutable strict application candidate from Task 5.
- Produces: one exact verified candidate approved for local runtime and phone
  QA, or a truthful blocked result.

- [ ] **Step 1: Run security, dependency, and Prisma gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm audit --audit-level=high
npm audit --omit=dev
npm run security:prisma-config-merge
npx prisma validate
npx prisma generate
```

Expected: zero qualifying audit findings, Prisma 6.19.3 validation/generation
PASS, exact R7 package-script projection, no dependency/override/lock drift,
and no unapproved package field. Then prove schema semantics and protected
bytes with one unique OS-temp root:

```powershell
$proof = Join-Path ([IO.Path]::GetTempPath()) `
  ('aarast-r7-prisma-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proof | Out-Null
try {
  git archive 31ea5324007fc71fa4b3590fbb98a454ee1deaa7 backend/prisma/schema | tar -xf - -C $proof
  node scripts/prisma/dmmf-fingerprint.cjs --output (Join-Path $proof 'candidate-dmmf.json')
  npx prisma migrate diff --exit-code `
    --from-schema-datamodel (Join-Path $proof 'backend/prisma/schema') `
    --to-schema-datamodel prisma/schema
  git diff --exit-code 31ea5324007fc71fa4b3590fbb98a454ee1deaa7 -- `
    prisma/schema prisma/migrations prisma/seed.ts prisma.config.ts package-lock.json
} finally {
  $resolvedProof = (Resolve-Path -LiteralPath $proof -ErrorAction SilentlyContinue).Path
  $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
  if ($resolvedProof -and $resolvedProof.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedProof -Recurse -Force
  }
}
```

Expected: DMMF 52 models / 41 enums, migrate diff exit 0 with no difference,
protected diff empty, and the exact temp directory absent afterward.

- [ ] **Step 2: Run focused behavior and managed concurrency smokes**

Run the 11 manifest-listed managed smoke packages first:

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run smoke:phase2-auth-lifecycle-concurrency
npm run smoke:phase2-conversation-revocation
npm run smoke:phase2-marketplace-write-concurrency
npm run smoke:phase2-money-authorization-concurrency
npm run smoke:phase2-notification-authorization-concurrency
npm run smoke:phase2-notification-preferences
npm run smoke:phase2-plan-permission-concurrency
npm run smoke:phase2-quote-concurrency
npm run smoke:phase2-sharing-permission-concurrency
npm run smoke:phase2-task-guest-permission-concurrency
npm run smoke:phase3-context-transition
```

Expected: every package PASS with its cleanup success.

- [ ] **Step 3: Run the aggregate managed suite**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run smoke:all
```

Expected: all 30 managed packages PASS, no secret output, and zero managed
database/container/media residue. Do not run a real-recipient OpenWA mutation.

- [ ] **Step 4: Re-run static and full gates on the same commit**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
npm run build
npm test
Set-Location D:\projects\aarast-modular-monolith
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
git status --short
```

Expected: all PASS and empty status.

- [ ] **Step 5: Run an independent exact-diff review**

Give the reviewer the design, this plan, immutable base, candidate SHA, complete
diff, stage/baseline outputs, and test receipts. Require explicit Critical,
Important, and Minor classification. Resolve every Critical/Important finding
test-first; document Minor findings without hiding them.

---

### Task 7: Bind Immutable Runtime And Authenticated Phone Evidence

**Files:** No tracked source changes expected. Evidence reports remain ignored
under the R7 SDD directory.

**Interfaces:**

- Consumes: the exact clean candidate approved in Task 6 and the accepted local
  environment without printing secrets.
- Produces: immutable image/revision identity, protected probe/cutover health,
  preserved R6 rollback, and owner phone PASS/FAIL evidence.

- [ ] **Step 1: Build and inspect the immutable image**

```powershell
Set-Location D:\projects\aarast-modular-monolith
$candidate = git rev-parse HEAD
docker build --build-arg AARAST_GIT_REVISION=$candidate -t aarast-backend:r7-candidate-$($candidate.Substring(0,8)) -f backend/Dockerfile backend
docker image inspect aarast-backend:r7-candidate-$($candidate.Substring(0,8)) --format '{{index .Config.Labels "org.opencontainers.image.revision"}} {{.Id}}'
```

Expected: the full candidate SHA and one immutable image ID. Audit production
dependencies inside the image and require zero qualifying findings.

- [ ] **Step 2: Run an isolated loopback probe**

Use the accepted local environment injection without echoing it. Start a
temporary loopback-only R7 container on a non-cutover port, then verify exact
migration discovery, `/live` 200, `/ready` 200, database/Redis/media readiness,
restart 0, OOM false, and zero sanitized fatal/secret-name markers. Capture the
sanitized result, then stop and remove the probe in a `finally` path on both
PASS and FAIL; cleanup failure fails the probe gate.

- [ ] **Step 3: Cut over locally while preserving rollback**

Stop but do not delete or overwrite the accepted R6 runtime/image. Start the
R7 image on the existing approved local/LAN network and port. Verify local and
LAN `/live` and `/ready` 200, readiness dependencies up, restart 0, OOM false,
and sanitized logs. If any R7 start/health/cutover check fails, stop and remove
the failed R7 runtime, restart the preserved R6 runtime, recheck local and LAN
`/live` and `/ready`, and record rollback PASS/FAIL before stopping. A failed
R7 gate remains failed even when rollback succeeds.

- [ ] **Step 4: Prove the phone is connected to the R7 candidate**

Use the installed Android SDK `adb.exe` if `adb` is absent from `PATH`. Prove
one authorized device, the installed Aarast package, the app API base/LAN
endpoint, and server-side R7 image revision before functional testing. Do not
record device serial, phone, token, OTP, or credential.

- [ ] **Step 5: Exercise and clean the exact phone journey**

On the authenticated phone:

1. restore session and selected context;
2. open dashboard and read sharing state;
3. create one clearly synthetic local invitation;
4. wait for the existing cooldown and reissue it;
5. read members, invitations, and permissions;
6. cancel the synthetic invitation through the existing route and verify a new
   read no longer returns it;
7. force-close the app and reopen it;
8. verify restored dashboard, session, context, and sharing state.

Cleanup failure fails the phone gate. If OpenWA is disabled, record only the
truthful provider-disabled outcome; do not claim delivery.

- [ ] **Step 6: Record sanitized evidence**

Keep only candidate/image identity, route names, status codes, counts,
timestamps, restart/OOM state, and owner PASS/FAIL. Retain no phone number, OTP,
access/invitation token, raw body, credential, or business value.

---

### Task 8: Close R7 Locally And Stop Before R8

**Files:**

- Create:
  `docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`
- Create:
  `docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`
- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`

**Interfaces:**

- Consumes: exact strict candidate, full verification, immutable runtime, phone
  evidence, and preserved R6 rollback.
- Produces: truthful local R7 completion receipts and a clean docs-only
  closeout checkpoint. It does not authorize R8.

- [ ] **Step 1: Write exact completion receipts**

Record immutable base, design/plan/task checkpoints, final candidate SHA,
image tag/ID/revision, observed architecture/dependency/ownership/test/audit/
smoke counts, Prisma equivalence, protected-surface result, independent-review
verdict, runtime health, phone result, cleanup, rollback state, and every
changed tracked path.

- [ ] **Step 2: State the boundary truthfully**

The receipt must state: R7 is locally complete only if every required gate
passed; R6 remains stopped and preserved for rollback; no push, merge, PR
mutation, deployment, remote CI, or real-recipient delivery occurred; and R8
has not started.

- [ ] **Step 3: Run final gates after the documentation edit**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
Set-Location ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: all PASS with R7 strict 0/18, dependency 22, and ownership 385/781.

- [ ] **Step 4: Create the docs-only closeout checkpoint**

Stage exactly the ten completion/documentation paths, verify staged names and
whitespace, commit locally, and confirm the worktree is clean. Do not push.

- [ ] **Step 5: Stop**

Report exact local R7 status and wait for the owner's next instruction. Do not
design or implement R8 in this task.

## Plan Self-Review Receipt

- Every design requirement maps to Tasks 1-8; no source fate or runtime gate is
  omitted.
- The move is split into three independently reviewable application
  checkpoints: snapshot, history, and sharing.
- RED precedes every scanner or source change; GREEN and a local checkpoint end
  every task.
- The exact 18 moves, 114-path fence, 19 routes, four exports, four constructor
  handoffs, two controller inventories, one optional dependency, nine retired
  debts, and 385/781 ownership outcome are explicit.
- Historical R3-R6 evidence remains immutable; only R7 certifies live staged
  paths and the 22-record dependency result.
- `SharingService` decomposition, R8 globals, schema/package/client/deployment
  changes, compatibility artifacts, and real-recipient delivery remain outside
  scope.
- Full tests, Prisma, audits, all managed smokes, immutable image, rollback,
  authenticated phone create/reissue/read/cancel/force-close/reopen, independent
  review, and docs-only closeout are mandatory before local completion.
