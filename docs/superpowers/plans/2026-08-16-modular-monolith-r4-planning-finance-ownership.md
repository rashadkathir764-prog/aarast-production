# Modular Monolith R4 Planning/Finance Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Execution status:** In progress. Tasks 1-3 are implemented and Task 4 Steps
1-4 are verified. The candidate is awaiting explicit Git authorization before
immutable image/runtime/phone work; Task 5 and R5 have not started.

**Goal:** Remove Finance's one direct `WeddingPlan` write by routing it through
an exact singleton Planning public write port while preserving the existing
caller-owned serializable transaction and all observable behavior.

**Architecture:** A dependency-free Planning internal leaf owns
`WeddingPlanBudgetWriter`. `PlanningBudgetWritePublicModule` exposes the exact
same instance through `PLANNING_BUDGET_WRITE_PORT` and `useExisting`. Finance
injects the public port and passes its existing `Prisma.TransactionClient`; no
new transaction, repository, compatibility facade, or product behavior is
introduced.

**Tech Stack:** NestJS 11, TypeScript 5.9, Prisma 6.19.3, Node.js 22 in CI,
dependency-cruiser 18.1.0, Node's built-in test runner, PostgreSQL, Docker,
Flutter 3.41.7, Markdown documentation.

## Global Constraints

- `R4_BASE` is exactly
  `502b181a2ce624458fd7eae064f194497ec0151e`.
- Work only in `D:\projects\aarast-modular-monolith` on the existing
  `modular-monolith` branch.
- Do not stage, commit, push, merge, branch, checkout, reset, create a worktree,
  mutate PR #76, or claim remote CI without separate explicit owner approval.
- Do not start R5 or retire any ownership debt except the one exact R4 key.
- Preserve routes, DTOs, payloads, status codes, Arabic/error text, permissions,
  lock order, serializable transaction/retry behavior, category semantics,
  summary semantics, and response ordering.
- Keep the Prisma folder at 14 files / 52 models / 41 enums / 76 migrations.
  Schema, seed, migrations, generated API/DB/Mobile/Admin contracts, package
  dependencies, lockfiles, Mobile source, Admin source, CI, Compose, deployment,
  and both frozen `@Global()` declarations remain unchanged.
- The Planning implementation must receive the caller's exact transaction
  object. It must not inject `PrismaService`, call `$transaction`, or catch,
  translate, retry, or hide errors.
- Public modules export Symbol tokens only. Finance may import Planning public
  files, never Planning full/internal/implementation files.
- Existing behavioral tests may change only by adding the exact deterministic
  Planning port constructor stub/wiring. Assertions, expected values, fixtures,
  product/error/Arabic literals, timeouts, skips, and test selection remain
  frozen.
- RED must precede production edits. Every review finding receives its own
  reproducible RED before the smallest root correction.
- Reports contain no credentials, tokens, request/response bodies, raw logs,
  `.env` values, connection strings, or absolute OS-temp paths.

## File and Contract Map

### New tracked files

| Path | Responsibility |
| --- | --- |
| `backend/architecture/r4-planning-finance-boundary.json` | Immutable R4 base, exact debt, exact contract, and exact changed-path allowlist |
| `backend/src/modules/planning/public/planning-budget-write.port.ts` | Public token, input, and interface only |
| `backend/src/modules/planning/public/planning-budget-write-public.module.ts` | Public `useExisting` alias and Symbol-only export |
| `backend/src/modules/planning/internal/wedding-plan-budget-writer.ts` | Sole physical `WeddingPlan` budget/currency writer |
| `backend/src/modules/planning/internal/planning-budget-write.internal.module.ts` | Sole implementation registration and internal alias |
| `backend/test/architecture-r4-planning-finance-boundary.test.ts` | Fixed-base scope, exact Nest/DI/source/ownership laws, and near-misses |
| `docs/superpowers/specs/2026-08-16-modular-monolith-r4-planning-finance-ownership-design.md` | Approved R4 design |
| `docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md` | This implementation plan |

### Existing files changed during implementation

| Path | Exact change |
| --- | --- |
| `backend/src/modules/planning/planning.module.ts` | Import the static Planning budget-write public module |
| `backend/src/modules/finance/internal/finance-services.internal.module.ts` | Import the Planning public module for `MoneyBudgetService` |
| `backend/src/money/money-budget.service.ts` | Inject/call the public port; delete direct `tx.weddingPlan.update` |
| `backend/architecture/r3-context-boundaries.json` | Add exact Planning provider contract and exact module metadata/path entries |
| `backend/scripts/architecture/r3-context-scan.cjs` | Extend the canonical contract inventory and exact Planning token/type identity law |
| `backend/scripts/architecture/r3-scope.cjs` | Preserve the immutable R3 receipt while delegating only the byte-exact R4 path fence |
| `backend/architecture/ownership-baseline.json` | Remove exactly one frozen R4 debt after candidate proof |
| `backend/test/financial-integrity.test.ts` | Add deterministic port stubs only; preserve assertions and values |
| `backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts` | Wire the real owner writer into the existing manually-constructed smoke service |
| `backend/test/architecture-r3-context-modules-a.test.ts` | Add the exact new owner-private leaf/module expectation |
| `backend/test/architecture-r3-contexts.test.ts` | Add exact token/type/consumer identity near-misses for the R4 contract |
| `backend/test/architecture-r3-scope.test.ts` | Prove R3 remains immutable and only the exact R4 delta is delegated |
| `backend/package.json` | Add `architecture:r4` and append it to `architecture` only |
| `docs/SCRIPTS.md` | Generated package-script catalog update only |

### Final receipt files

Only after implementation/runtime/review pass:

```text
ARCHITECTURE.md
CHANGELOG.md
docs/README.md
docs/backend/README.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/qa/README.md
```

### Public interface

```typescript
export const PLANNING_BUDGET_WRITE_PORT = Symbol(
  'PLANNING_BUDGET_WRITE_PORT',
);

export interface UpdateWeddingPlanBudgetInput {
  weddingPlanId: string;
  estimatedBudget: Prisma.Decimal | null;
  currency: string;
}

export interface PlanningBudgetWritePort {
  updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void>;
}
```

---

### Task 1: Freeze R4 Governance and the Baseline Gate

**Files:**
- Create: `backend/architecture/r4-planning-finance-boundary.json`
- Create: `backend/test/architecture-r4-planning-finance-boundary.test.ts`
- Modify: `backend/scripts/architecture/r3-scope.cjs`
- Modify: `backend/test/architecture-r3-scope.test.ts`
- Modify: `backend/package.json`
- Modify (generated): `docs/SCRIPTS.md`
- Test: `backend/test/architecture-r4-planning-finance-boundary.test.ts`

**Interfaces:**
- Consumes: R4 base `502b181a...`, current 386/782 ownership baseline, current
  R3 manifest, and live Git path inventory.
- Produces: `architecture:r4`, an exact R4 manifest, a baseline-stage green
  gate, a fail-closed R3-to-R4 phase handoff, and the strict-stage RED harness
  used by Task 2.

- [x] **Step 0: Read the governing sources completely**

Before editing, read `AGENTS.md`, `ARCHITECTURE.md`, `docs/README.md`,
`docs/project/PRODUCT.md`, `docs/project/SCOPE_AND_PHASES.md`,
`docs/project/STATUS.md`, `docs/project/DECISIONS.md`,
`docs/project/EXECUTION_PLAN.md`, `docs/backend/README.md`,
`docs/backend/API_CONTRACT.md`, `docs/backend/DATABASE.md`,
`docs/qa/README.md`, `docs/deployment/README.md`, this design, and this plan.
Treat source/config and the immutable R4 manifest as higher authority than old
historical receipts. Do not read or print secrets.

- [x] **Step 1: Record the immutable preflight**

Run from the repository root:

```powershell
git branch --show-current
git rev-parse HEAD
git status --short
git merge-base --is-ancestor 502b181a2ce624458fd7eae064f194497ec0151e HEAD
```

Expected: branch `modular-monolith`, exact HEAD `502b181a...`, empty status,
ancestor command exit `0`. If any value differs, stop before editing.

- [x] **Step 2: Write the baseline test and capture RED**

Create `backend/test/architecture-r4-planning-finance-boundary.test.ts` first.
It must require the manifest at the exact path below, pin `R4_BASE`, assert the
exact debt, validate a sorted/unique relative allowlist, and expose a helper
that computes tracked plus untracked paths with Git rename detection disabled.

Run:

```powershell
node --test -r ts-node/register `
  test/architecture-r4-planning-finance-boundary.test.ts
```

Expected: FAIL because
`backend/architecture/r4-planning-finance-boundary.json` does not exist. A
TypeScript, loader, or unrelated fixture failure is not an accepted RED.

- [x] **Step 3: Create the exact baseline manifest**

Create `backend/architecture/r4-planning-finance-boundary.json` with this
shape and exact values, then complete the remaining test assertions:

```json
{
  "schemaVersion": 1,
  "baseRevision": "502b181a2ce624458fd7eae064f194497ec0151e",
  "stage": "baseline",
  "ownershipDebt": {
    "key": "backend/src/money/money-budget.service.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model",
    "count": 1
  },
  "providerContract": {
    "token": "PLANNING_BUDGET_WRITE_PORT",
    "methods": ["updateBudgetInTransaction"],
    "implementations": ["WeddingPlanBudgetWriter"],
    "consumers": [
      {
        "source": "backend/src/money/money-budget.service.ts",
        "kind": "constructor-injection"
      }
    ]
  },
  "expectedStrictOwnership": {
    "records": 385,
    "occurrences": 781
  },
  "allowedChangedPaths": []
}
```

Populate `allowedChangedPaths` with the byte/order-exact sorted union of every
path named in this plan's File and Contract Map. Do not permit directories,
globs, package locks, application paths outside the named three source wiring
files, or later-phase receipt files.

The completed R3 allowlist remains byte-for-byte immutable. Update the R3
scope verifier only to recognize this exact R4 manifest, exact R4 base, and
byte/order-exact R4 allowlist. The R3 test must compare the R3 subset against
the frozen R3 receipt and reject every non-R3 path not present in the exact R4
fence. It must not append R4 paths to the R3 manifest or silently ignore later
phase paths.

- [x] **Step 4: Complete the baseline-stage architecture test**

The test must parse the manifest as bounded plain data, pin `baseRevision`,
assert sorted/unique relative paths, run Git with rename detection disabled,
and prove the current debt exists exactly once:

```typescript
const changed = execFileSync('git', [
  'diff', '--no-renames', '--name-only', R4_BASE, '--',
], { cwd: repositoryRoot, encoding: 'utf8' })
  .split(/\r?\n/u)
  .filter(Boolean);
const untracked = execFileSync('git', [
  'ls-files', '--others', '--exclude-standard', '--',
], { cwd: repositoryRoot, encoding: 'utf8' })
  .split(/\r?\n/u)
  .filter(Boolean);
const livePaths = [...new Set([...changed, ...untracked])].sort();
assert.deepEqual(
  livePaths.filter((entry) => !manifest.allowedChangedPaths.includes(entry)),
  [],
);

const baseline = JSON.parse(readFileSync(
  join(backendRoot, 'architecture', 'ownership-baseline.json'),
  'utf8',
));
assert.deepEqual(
  baseline.violations.filter((item: { key: string }) =>
    item.key === manifest.ownershipDebt.key),
  [{
    key: manifest.ownershipDebt.key,
    file: 'backend/src/money/money-budget.service.ts',
    context: 'finance',
    owner: 'planning',
    model: 'WeddingPlan',
    operation: 'update',
    mode: 'write',
    source: 'delegate',
    reason: 'foreign-model',
    count: 1,
  }],
);
```

Add near-misses for a wrong base, duplicate/reordered allowlist, traversal,
high-similarity forbidden deletion, substituted debt key, and same-count
ownership substitution.

- [x] **Step 5: Wire the architecture command**

Add exactly:

```json
"architecture:r4": "node --test -r ts-node/register test/architecture-r4-planning-finance-boundary.test.ts"
```

Append `&& npm run architecture:r4` to the existing `architecture` script.
Change no dependency or other script.

- [x] **Step 6: Refresh only generated script documentation**

Run:

```powershell
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
```

Expected: only `docs/SCRIPTS.md` changes from package-script generation; check
reports drift `0` and errors `0`.

- [x] **Step 7: Prove the baseline governance gate is green**

Run from `backend`:

```powershell
npm run architecture:r4
npm run architecture
npm run check
```

Expected: PASS. The R4 gate is green only in manifest stage `baseline`; no
production behavior has changed.

- [x] **Step 8: Independent review checkpoint**

Review the manifest, scope/near-misses, base pin, exact debt record, package
script, and generated doc read-only. Fix any finding with a test-first
regression. Do not begin Task 2 until the review verdict is PASS.

- [ ] **Step 9: Optional local checkpoint commit**

Execute only after separate owner authorization for Git:

```powershell
git add backend/architecture/r4-planning-finance-boundary.json `
  backend/test/architecture-r4-planning-finance-boundary.test.ts `
  backend/package.json docs/SCRIPTS.md `
  docs/superpowers/specs/2026-08-16-modular-monolith-r4-planning-finance-ownership-design.md `
  docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md
git commit -m "test: freeze modular monolith R4 boundary"
```

Without authorization, leave files unstaged and record hashes in the ignored
Task 1 report instead.

---

### Task 2: Add the Planning Write Port and Migrate Finance

**Files:**
- Create: `backend/src/modules/planning/public/planning-budget-write.port.ts`
- Create: `backend/src/modules/planning/public/planning-budget-write-public.module.ts`
- Create: `backend/src/modules/planning/internal/wedding-plan-budget-writer.ts`
- Create: `backend/src/modules/planning/internal/planning-budget-write.internal.module.ts`
- Modify: `backend/src/modules/planning/planning.module.ts`
- Modify: `backend/src/modules/finance/internal/finance-services.internal.module.ts`
- Modify: `backend/src/money/money-budget.service.ts`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/architecture/r4-planning-finance-boundary.json`
- Modify: `backend/test/architecture-r3-context-modules-a.test.ts`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r4-planning-finance-boundary.test.ts`
- Modify: `backend/test/financial-integrity.test.ts`
- Modify: `backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts`

**Interfaces:**
- Consumes: the Task 1 R4 manifest/gate and existing Finance serializable
  transaction.
- Produces: exact singleton `PLANNING_BUDGET_WRITE_PORT`, one physical owner
  writer, and a Finance consumer that never touches `tx.weddingPlan`.

- [x] **Step 1: Switch the manifest/test to strict and capture RED**

Change the R4 manifest stage to `strict`. Extend the R4 test to require all four
new files, exact module metadata, singleton alias identity, the exact R3
provider-contract entry, no `weddingPlan` delegate in MoneyBudgetService, and no
frozen debt in the live ownership candidate.

Run:

```powershell
node --test -r ts-node/register `
  test/architecture-r4-planning-finance-boundary.test.ts `
  test/financial-integrity.test.ts
```

Expected: FAIL for missing Planning port/module/writer and the still-present
direct delegate/debt. No compile or fixture setup failure is accepted as RED.

- [x] **Step 2: Create the public contract**

Create `planning-budget-write.port.ts`:

```typescript
import type { Prisma } from '@prisma/client';

export const PLANNING_BUDGET_WRITE_PORT = Symbol(
  'PLANNING_BUDGET_WRITE_PORT',
);

export interface UpdateWeddingPlanBudgetInput {
  weddingPlanId: string;
  estimatedBudget: Prisma.Decimal | null;
  currency: string;
}

export interface PlanningBudgetWritePort {
  updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void>;
}
```

The file may import only Prisma types. It may not import Nest, Finance,
`PrismaService`, or a legacy Planning service.

- [x] **Step 3: Create the owner-private writer**

Create `wedding-plan-budget-writer.ts`:

```typescript
import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type {
  PlanningBudgetWritePort,
  UpdateWeddingPlanBudgetInput,
} from '../public/planning-budget-write.port';

@Injectable()
export class WeddingPlanBudgetWriter implements PlanningBudgetWritePort {
  async updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void> {
    await tx.weddingPlan.update({
      where: { id: input.weddingPlanId },
      data: {
        estimatedBudget: input.estimatedBudget,
        currency: input.currency,
      },
    });
  }
}
```

- [x] **Step 4: Create the internal/public module chain**

Create `planning-budget-write.internal.module.ts` and
`planning-budget-write-public.module.ts` exactly as specified in the design:

```typescript
export const PLANNING_BUDGET_WRITE_IMPLEMENTATION = Symbol(
  'PLANNING_BUDGET_WRITE_IMPLEMENTATION',
);
```

The internal module registers `WeddingPlanBudgetWriter` once and aliases the
implementation token with `useExisting`. The public module imports the internal
module, aliases `PLANNING_BUDGET_WRITE_PORT` to the implementation token with
`useExisting`, and exports only the public token.

- [x] **Step 5: Wire owner and consumer modules**

Add `PlanningBudgetWritePublicModule` to `PlanningModule.imports` and
`FinanceServicesInternalModule.imports`. Do not import the internal module or
writer from Finance. Do not add a provider registration in either full module.

- [x] **Step 6: Inject and call the port from MoneyBudgetService**

Add the exact constructor member:

```typescript
@Inject(PLANNING_BUDGET_WRITE_PORT)
private readonly planningBudgetWriter: PlanningBudgetWritePort,
```

Replace only the direct delegate call with:

```typescript
await this.planningBudgetWriter.updateBudgetInTransaction(tx, {
  weddingPlanId,
  estimatedBudget: totalBudget,
  currency,
});
```

Keep it in the same location: after category mutations and before
`buildMoneySummaryInTransaction(...)`.

- [x] **Step 7: Update deterministic constructor fixtures only**

In `financial-integrity.test.ts`, pass a third constructor argument everywhere:

```typescript
const planningBudgetWriter = {
  updateBudgetInTransaction: async (
    receivedTx: Prisma.TransactionClient,
    input: {
      weddingPlanId: string;
      estimatedBudget: Prisma.Decimal | null;
      currency: string;
    },
  ) => {
    assert.equal(receivedTx, tx);
    assert.equal(input.weddingPlanId, 'plan-1');
    assert.equal(input.estimatedBudget?.toString() ?? null, '1000');
    assert.equal(input.currency, 'YER');
    transactionEvents.push('budget-update');
  },
};
```

For validation-only constructors, use a stub that throws if called. Preserve all
existing assertions, DTO values, errors, transaction counts, and event-order
assertions.

- [x] **Step 8: Extend canonical R3 metadata and R4 laws**

Add the exact provider contract to `r3-context-boundaries.json`:

```json
{
  "token": "PLANNING_BUDGET_WRITE_PORT",
  "methods": ["updateBudgetInTransaction"],
  "implementations": ["WeddingPlanBudgetWriter"],
  "consumers": [
    {
      "source": "backend/src/money/money-budget.service.ts",
      "kind": "constructor-injection"
    }
  ]
}
```

Update only the three affected module metadata records and allowed changed-path
inventory. Add R4 near-misses proving rejection of a fake same-name token/type,
wrong internal module, duplicate provider, `useClass`, Finance import of the
writer/internal module, writer `PrismaService` injection, writer `$transaction`,
and a decoy canonical injection in another class/parameter.

- [x] **Step 9: Prove focused GREEN**

Run:

```powershell
node --test -r ts-node/register `
  test/architecture-r4-planning-finance-boundary.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r3-context-modules-a.test.ts `
  test/financial-integrity.test.ts
npm run architecture:r3
npm run architecture:r4
npm run check
```

Expected: all PASS. Confirm source search returns no
`tx.weddingPlan` in `money-budget.service.ts` and no Planning internal/full
import under Finance or `money/`.

- [x] **Step 10: Independent code review checkpoint**

Review contract narrowness, exact TypeChecker identity, singleton registration,
module acyclicity, transaction-object identity, error parity, test-policy
compliance, and absence of a compatibility facade. Fix findings RED-first.

- [ ] **Step 11: Optional local checkpoint commit**

Only with explicit Git authorization:

```powershell
git add backend/src/modules/planning backend/src/modules/finance/internal/finance-services.internal.module.ts `
  backend/src/money/money-budget.service.ts backend/architecture/r3-context-boundaries.json `
  backend/architecture/r4-planning-finance-boundary.json `
  backend/test/architecture-r3-context-modules-a.test.ts `
  backend/test/architecture-r4-planning-finance-boundary.test.ts `
  backend/test/financial-integrity.test.ts
git commit -m "refactor: route finance budget writes through planning"
```

---

### Task 3: Remove Exactly One Ownership Debt

**Files:**
- Modify: `backend/architecture/ownership-baseline.json`
- Modify: `backend/test/architecture-r4-planning-finance-boundary.test.ts`

**Interfaces:**
- Consumes: strict live source from Task 2 and the pre-R4 386/782 baseline.
- Produces: a tracked 385/781 baseline equal to the old baseline minus one exact
  key, with no other semantic change.

- [x] **Step 1: Generate a unique OS-temp candidate**

Run from `backend` without writing the tracked baseline:

```powershell
$r4AuditRoot = Join-Path ([IO.Path]::GetTempPath()) `
  ("aarast-r4-ownership-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $r4AuditRoot | Out-Null
$candidate = Join-Path $r4AuditRoot "ownership-candidate.json"
node .\scripts\architecture\ownership-scan.cjs --output $candidate
```

Expected: candidate written, and its JSON reparses successfully.

- [x] **Step 2: Prove the candidate is exactly baseline minus the R4 key**

Run this comparison with the exact candidate path:

```powershell
node -e "const fs=require('fs');const assert=require('assert/strict');const base=require('./architecture/ownership-baseline.json');const candidate=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));const key='backend/src/money/money-budget.service.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model';const expected=base.violations.filter((r)=>r.key!==key);assert.equal(base.violations.filter((r)=>r.key===key).length,1);assert.deepEqual(candidate.violations,expected);assert.equal(candidate.violations.length,385);assert.equal(candidate.violations.reduce((n,r)=>n+r.count,0),781);" $candidate
```

Expected: exit `0`. Any other removed, added, reordered, renamed, count-changed,
or payload-changed record is a blocker.

- [x] **Step 3: Write the verified baseline**

Only after Step 2 passes:

```powershell
node .\scripts\architecture\ownership-scan.cjs --write-baseline
npm run architecture:ownership
```

Expected: tracked baseline equals the verified candidate and the ownership gate
passes.

- [x] **Step 4: Make exact decrease permanent**

Extend the R4 test to compare the base blob at `R4_BASE` with the live tracked
baseline, requiring:

```typescript
assert.deepEqual(
  current.violations,
  base.violations.filter((record) => record.key !== debtKey),
);
assert.equal(current.violations.length, 385);
assert.equal(
  current.violations.reduce((sum, record) => sum + record.count, 0),
  781,
);
```

Add a same-count substitution near-miss that must fail.

- [x] **Step 5: Run the architecture closure**

```powershell
npm run architecture
npm run check
npm run build
git diff --check
```

Expected: PASS, with zero forward refs, two frozen globals, zero cycles/illegal
edges, and the ownership counts 385/781.

- [x] **Step 6: Clean the unique candidate directory**

Verify `$candidate` and `$r4AuditRoot` resolve inside the OS temp root, then
remove only that exact directory. Confirm it no longer exists.

- [x] **Step 7: Independent ownership review checkpoint**

The reviewer independently regenerates a candidate and compares complete
records, not only counts/hashes. No baseline change is accepted without a PASS.

- [ ] **Step 8: Optional local checkpoint commit**

Only with explicit Git authorization:

```powershell
git add backend/architecture/ownership-baseline.json `
  backend/test/architecture-r4-planning-finance-boundary.test.ts
git commit -m "test: retire finance planning ownership debt"
```

---

### Task 4: Exhaustive Verification and Production-Shaped Runtime

**Files:**
- Create ignored: `.superpowers/sdd/2026-08-16-modular-monolith-r4-planning-finance-ownership/task-4-report.md`
- No product source change is allowed in this task unless a reproduced failure
  requires a separately reviewed root fix.

**Interfaces:**
- Consumes: reviewed Task 1-3 candidate.
- Produces: exhaustive static/runtime evidence, an immutable backend image, and
  preserved R3/R2 rollback artifacts.

- [x] **Step 1: Run fresh focused and full Backend gates**

From `backend`:

```powershell
npm run architecture:r4
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npm audit --omit=dev
npm audit
```

Expected: all exit `0`; only the existing intentional Windows permission skip
is allowed. Record exact test/count outputs without environment values.

- [x] **Step 2: Run managed affected smokes**

```powershell
npm run smoke:money-budget
npm run smoke:money-apis
npm run smoke:phase2-money-authorization-concurrency
npm run smoke:health
```

Expected: PASS with 76 migrations, live/ready green, and exact money behavior.
After each run, prove zero managed database, Redis DB15, MinIO bucket,
container, volume, network, listener, process, and current-run temp residue.

- [x] **Step 3: Run the final aggregate smoke**

```powershell
npm run smoke:all
```

Expected: every package PASS, followed by the same zero-residue audit.

- [x] **Step 4: Recheck frozen surfaces**

Compare `R4_BASE..candidate` and require zero diff for:

```text
backend/prisma/schema/
backend/prisma/migrations/
backend/prisma/seed.ts
mobile/
admin/
deploy/
.github/workflows/
docker-compose*.yml
package-lock.json and every non-script package field
```

Run docs sync/verify and `git diff --check`. Confirm 14 schema files, 52 models,
41 enums, and 76 migrations.

- [ ] **Step 5: Obtain Git authorization before immutable candidate work**

The current authorization forbids Git mutation. Stop here unless the owner
explicitly authorizes local staging/commits. If authorized, commit only reviewed
paths and resolve the candidate with `git rev-parse HEAD`.

- [ ] **Step 6: Build the immutable R4 image**

With an authorized immutable candidate:

```powershell
$revision = git rev-parse HEAD
$tag = "aarast-backend:r4-final-$($revision.Substring(0,8))"
docker build --label "org.opencontainers.image.revision=$revision" `
  -t $tag -f backend/Dockerfile backend
```

Expected: build PASS; both image-time Prisma generate invocations find the
native schema folder. Inspect only safe metadata and prove the image label is
the full revision, exact schema/config files exist, and the retired single-file
schema is absent.

- [ ] **Step 7: Probe and cut over without exposing secrets**

Clone the accepted R3 container's environment, mounts, network, and restart
policy in memory through structured `docker inspect`; do not print its `Env` or
raw command. Start a unique probe on `127.0.0.1:3121`, require migration
discovery plus `/live` and `/ready` HTTP 200, revision match, restart `0`, and no
fatal/unhandled/TypeError/Prisma-schema marker. Remove the probe and prove zero
probe/temp residue.

Stop but preserve the accepted R3 container, start the R4 phone container on
`aarast_default` and host port `3120`, then require local and assigned-LAN
`/live` and `/ready` HTTP 200, DB/Redis/media up, restart `0`, OOM false, and
exact image/revision identity. Preserve R3 and R2 rollback images/containers.

- [ ] **Step 8: Owner phone checkpoint**

On the existing R3Local application package, test exactly:

1. login or local WhatsApp OTP;
2. Home loads;
3. open Money;
4. replace the optional general budget and at least one category;
5. reopen Money and confirm the saved values;
6. force-stop/reopen the app and confirm authenticated context plus saved values;
7. confirm no unexpected logout, duplicate category, stale summary, or error.

Do not send OTP, passwords, tokens, phone numbers, or financial values in the
report. On failure, preserve safe method/path/status evidence and roll back to
the verified R3 container before debugging.

---

### Task 5: Final Review, Truthful Receipts, and R4 Closeout

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`
- Update ignored: `.superpowers/sdd/2026-08-16-modular-monolith-r4-planning-finance-ownership/task-4-report.md`

**Interfaces:**
- Consumes: immutable source, scanner/baseline, runtime, and phone evidence.
- Produces: independently reviewed truthful local R4 receipt and an explicit R5
  stop boundary.

- [ ] **Step 1: Request independent read-only final review**

The reviewer must independently verify:

- exact commit/path scope and clean candidate;
- singleton token/implementation identity and no duplicate registration;
- exact same transaction object and update input;
- no Finance `WeddingPlan` delegate/relation/raw-SQL write;
- ownership baseline equals base minus one exact record;
- routes, behavior, errors, schema, Mobile/Admin/deploy surfaces are frozen;
- full gates, managed smokes, runtime identity/health, rollback, and sanitized
  phone evidence;
- docs contain no remote-CI/push/merge/R5 overclaim.

Any finding returns to the owning task with RED-first correction and fresh
proportional/full gates.

- [ ] **Step 2: Write final active receipts only after PASS**

Update the eight named Markdown files to state:

- immutable R4 base and candidate identity;
- one Planning write port and one Finance consumer;
- exact ownership decrease 386/782 to 385/781 with the removed key named;
- unchanged API/schema/Mobile/Admin/deployment behavior;
- exact automated/runtime/phone results and known warnings;
- preserved R3/R2 rollback;
- local-only truth: no push, merge, PR mutation, or remote CI;
- R4 complete and R5 not started.

- [ ] **Step 3: Run final docs and scope gates**

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
cd backend
npm run architecture:r4
npm run architecture
```

Expected: drift `0`, docs errors/warnings `0`, whitespace PASS, R4 exact scope
PASS, ownership 385/781, and all architecture laws green.

- [ ] **Step 4: Optional final local receipt commit**

Only with explicit Git authorization:

```powershell
git add ARCHITECTURE.md CHANGELOG.md docs/README.md docs/backend/README.md `
  docs/project/DECISIONS.md docs/project/EXECUTION_PLAN.md `
  docs/project/STATUS.md docs/qa/README.md
git commit -m "docs: close modular monolith R4 locally"
```

Verify the commit contains exactly the eight approved Markdown files, worktree
is clean, runtime still matches the reviewed application candidate, and local
plus LAN live/ready remain HTTP 200.

- [ ] **Step 5: Stop at the R4 boundary**

Report the final evidence, exact files/commits if authorized, runtime/rollback
state, owner phone result, and residual limitations. Do not push, merge, update
PR #76, claim remote CI, or begin R5.

## Plan Self-Review Receipt

- Every design requirement maps to Task 1-5.
- The only physical ownership debt removed is the exact Finance-to-Planning
  `WeddingPlan.update` key.
- Public/implementation token names, class name, method name, input fields, and
  transaction type are consistent across all tasks.
- No task contains a speculative read port, generic repository, new transaction,
  schema/API/UI/deployment behavior, compatibility layer, or future-phase work.
- Git commands are explicitly conditional because the current request does not
  authorize Git-state mutation.
- No `TBD`, `TODO`, skipped test, weakened assertion, hidden fallback, or
  unbounded path is part of the plan.
