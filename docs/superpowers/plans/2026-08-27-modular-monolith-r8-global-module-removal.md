# Modular Monolith R8 Global Module Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the final two project-owned Nest global modules, add the one
missing explicit Prisma import, and prove that provider identity and all
application behavior remain unchanged.

**Architecture:** Keep `PrismaModule` and `ConversationRealtimeModule` as
ordinary exported modules. First delegate the exact R8 scope and build a
design-stage AST gate, then atomically remove both decorators, add
`PrismaModule` to `ApplicationOutboxRuntimeModule`, and promote every live gate
to a zero-project-global strict state. Preserve the immutable R3 inventory by
applying exactly three validated R8 projections.

**Tech Stack:** Windows/PowerShell, Node.js 22, TypeScript, NestJS 11, Prisma
6.19.3, Node test runner, dependency-cruiser, Docker, Flutter/ADB phone QA.

**Spec:**
`docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md`

**Status:** Owner-approved execution plan; Task 0 documentation checkpoint in progress

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch
  `modular-monolith`.
- Immutable R8 base is `c2b728bfe54304562923facfb6094e0de04c0b27`.
- Owner-reviewed design checkpoint is
  `0bdc1e88d327960ab0cc5cc6dc040f1fdb75b825`.
- Local checkpoint commits are authorized. Do not create or switch branches or
  worktrees.
- Do not push, merge, mutate PR #76, deploy, run remote CI, or start R9.
- Remove project-owned global activation only from
  `PrismaModule` and `ConversationRealtimeModule`. Preserve their paths,
  classes, providers, exports, and lifecycle identities.
- Add exactly one production dependency edge:
  `ApplicationOutboxRuntimeModule -> PrismaModule`.
- Preserve one `PrismaService` and one `ConversationRealtimePublisher` per
  application context. Preserve the exact two-step Messaging `useExisting`
  chain and `MESSAGING_REALTIME_PORT` Symbol identity.
- The strict direct Prisma importer inventory is exactly the 21 module paths in
  the design specification. Both concrete Realtime owners keep their explicit
  `ConversationRealtimeModule` imports.
- Preserve the immutable `r3-context-boundaries.json`. Apply only the two
  `global: true -> false` projections and the one Outbox `PrismaModule` import
  projection.
- Preserve `@nestjs/schedule@6.1.3` and `@nestjs/throttler@6.5.0` external
  global behavior through exact package declaration, lock, import, and call
  identities. Do not add a generic dependency exception.
- Reject project-owned DynamicModule global activation and project-source
  `global: true` or `isGlobal: true` options supplied to external module
  factories.
- Preserve dependency baseline 22, ownership 385 records / 781 occurrences,
  Prisma 52 models / 41 enums / 76 migrations, and every historical R0-R7
  behavior contract.
- Preserve routes, WebSocket events, DTOs, responses, Arabic/error text,
  permissions, privacy, sessions, OTP, transactions, locks, retries,
  idempotency, Outbox attempts, scheduling, metrics, and logs.
- Preserve `package-lock.json`, dependencies, schema, migrations, seed, Mobile,
  Admin Web, workflows, Dockerfiles, Compose, Dokploy, domains, ports, and
  secrets.
- Existing behavioral tests remain frozen. Only exact architecture/source-
  shape assertions required by the R8 handoff may change.
- Every application/scanner code-changing task ends with focused tests,
  `npm run architecture`, `npm run check`, diff review,
  `git diff --check`, and a reviewed local checkpoint.
- No result inherited from R7 is valid after an R8 source edit. Rerun every
  claimed gate on the exact R8 candidate.

## Planned File Responsibilities

| Path | Responsibility |
| --- | --- |
| `backend/architecture/r8-global-module-removal.json` | Fixed base, stages, exact scope, document hashes, provider/import closure, R3 projections, external-global locks, and protected surfaces |
| `backend/scripts/architecture/r8-global-module-removal-scan.cjs` | Manifest validation, semantic global detection, explicit DI closure, provider identity, R3 projection, protected-surface, and CLI |
| `backend/test/architecture-r8-global-module-removal.test.ts` | Positive and adversarial R8 design/strict fixtures, singleton tests, and external-global evidence |
| `backend/scripts/architecture/r3-scope.cjs` | Exact fixed-base R8 delegation only |
| `backend/test/architecture-r3-scope.test.ts` | R8 scope identity, stage, hash, path, traversal, and near-miss rejection |
| `backend/scripts/architecture/ports-scan.cjs` | Empty project-owned Global allowlist and zero-global live count |
| `backend/scripts/architecture/r3-context-scan.cjs` | Apply exactly the validated three-field R8 projection before live comparison |
| `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs` | Preserve R7 relocation while delegating only its live global count to strict R8 |
| `backend/scripts/security/prisma-config-merge-security.cjs` | Project only the exact R8 architecture scripts back to the already pinned R7/R6 package graph |
| `backend/test/prisma-config-merge-security.test.ts` | Reject missing, altered, reordered, or attacker R8 package-script projections |
| `backend/src/platform/database/prisma.module.ts` | Ordinary Prisma provider/export module without `Global` |
| `backend/src/conversations/conversation-realtime.module.ts` | Ordinary Realtime publisher/export module without `Global` |
| `backend/src/application-composition/application-outbox-runtime.module.ts` | Explicitly import `PrismaModule` for `OutboxWorker` |
| R1/R3/R7 architecture tests | Mechanical active-source handoff from two project globals to zero |
| `backend/package.json` and `docs/SCRIPTS.md` | Add `architecture:r8` and include it in aggregate architecture |
| Active project/architecture/QA docs | Record approved scope, exact candidate, verification, runtime, phone, and stop boundary |

---

### Task 0: Approve The R8 Execution Contract

**Files:**

- Modify: `docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md`
- Modify: `docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`

**Interfaces:**

- Consumes: owner-reviewed design checkpoint `0bdc1e88` and this plan.
- Produces: one owner-approved execution order and an explicit
  pre-governance documentation checkpoint.

- [ ] **Step 1: Verify the planning preflight**

Run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
git branch --show-current
git merge-base --is-ancestor c2b728bfe54304562923facfb6094e0de04c0b27 HEAD
git merge-base --is-ancestor 0bdc1e88d327960ab0cc5cc6dc040f1fdb75b825 HEAD
git status --short
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: branch `modular-monolith`, both ancestor checks exit 0, only the
approved documentation files are changed if the planning checkpoint is not yet
committed, and all documentation/whitespace checks pass.

- [ ] **Step 2: Record the approved plan without claiming implementation**

Update the design status to `Owner-approved design; implementation plan
approved separately` and this plan status to `Owner-approved execution plan;
Task 0 documentation checkpoint in progress`. Add a compact R8 section to each
active document above that records:

```text
R8 base: c2b728bfe54304562923facfb6094e0de04c0b27
Objective: zero project-owned globals with explicit Prisma/Realtime imports
State: design and plan approved; application source unchanged
Stop: no push, merge, deployment, remote CI, or R9
```

Do not report architecture, test, runtime, or phone PASS at this checkpoint.

- [ ] **Step 3: Verify the documentation checkpoint**

Run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git diff --name-status
```

Expected: generated references remain in sync, zero documentation errors, and
the diff contains only the nine Task 0 documentation paths.

- [ ] **Step 4: Create the local planning checkpoint**

Stage only the nine Task 0 paths, inspect `git diff --cached --name-status` and
`git diff --cached --check`, then commit:

```powershell
git commit -m "docs: approve modular monolith R8 plan"
```

Expected: docs-only local checkpoint and clean worktree. Do not push.

---

### Task 1: Delegate The Exact R8 Scope Before Production Edits

**Files:**

- Create: `backend/architecture/r8-global-module-removal.json`
- Create: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Create: `backend/test/architecture-r8-global-module-removal.test.ts`
- Modify: `backend/scripts/architecture/r3-scope.cjs`
- Modify: `backend/test/architecture-r3-scope.test.ts`

**Interfaces:**

- Consumes: fixed base `c2b728b`, final design/plan blobs, and the exact R8
  changed-path fence.
- Produces: `validateR8Manifest(value)`, `R8_BASE`,
  `EXPECTED_ALLOWED_PATHS`, design-stage manifest validation, and exact R3
  scope delegation.

- [ ] **Step 1: Write the R8 scope RED tests**

Extend the R3 scope test module interface with:

```ts
R8_ALLOWED_PATHS: readonly string[];
validateR8GlobalRemovalManifest(value: unknown): {
  baseRevision: string;
  stage: 'design' | 'strict';
  allowedChangedPaths: readonly string[];
};
```

Add a test named `R8 delegates only its fixed-base hash-bound path fence`. It
must load `backend/architecture/r8-global-module-removal.json`, assert the base,
stage, exact design/plan paths, and exact sorted path array, then reject:

```ts
const invalidMutations = [
  ['wrong base', (value: any) => { value.baseRevision = '0'.repeat(40); }],
  ['wrong stage', (value: any) => { value.stage = 'relocated'; }],
  ['extra path', (value: any) => { value.allowedChangedPaths.push('docs/attacker.md'); }],
  ['traversal', (value: any) => { value.allowedChangedPaths[0] = '../escape.md'; }],
  ['absolute path', (value: any) => { value.allowedChangedPaths[0] = 'C:/escape.md'; }],
  ['wrong design hash', (value: any) => { value.documents.design.sha256 = '0'.repeat(64); }],
  ['wrong plan hash', (value: any) => { value.documents.plan.sha256 = '0'.repeat(64); }],
] as const;
```

Add separate reorder, duplicate, manifest-path near-miss, reparse/junction, and
missing-required-path cases.

- [ ] **Step 2: Run RED and preserve the evidence**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-scope.test.ts test/architecture-r8-global-module-removal.test.ts
```

Expected: FAIL because the R8 manifest, validator, and R3 delegation do not
exist. The existing four `changed path is outside R3 scope` failures remain
visible until the delegation is implemented.

- [ ] **Step 3: Create the exact design-stage manifest and validator**

Create a plain JSON object with `schemaVersion: 1`, fixed `baseRevision`,
`stage: "design"`, `documents`, and `allowedChangedPaths`. The `documents`
object has exactly `design` and `plan`; each contains its canonical path plus a
lower-case 64-hex `sha256`. Obtain the two literal hash values from:

```powershell
Get-FileHash -Algorithm SHA256 `
  .\docs\superpowers\specs\2026-08-27-modular-monolith-r8-global-module-removal-design.md, `
  .\docs\superpowers\plans\2026-08-27-modular-monolith-r8-global-module-removal.md
```

Set `allowedChangedPaths` to the exact sorted paths from the design: the R8
manifest/scanner/test, R3 scope/scanner tests, ports and R7 live gates, the
three production modules, package scripts/generated script reference, the R1/
R3/R7 active tests, the Prisma config merge-security checker/test,
`ARCHITECTURE.md`, `CHANGELOG.md`, the six active project/backend/QA documents,
design/plan, and both completion receipts. Use this exact sorted fence:

```js
const expectedAllowedChangedPaths = [
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/architecture/r8-global-module-removal.json',
  'backend/package.json',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/architecture/r8-global-module-removal-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/application-composition/application-outbox-runtime.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/database/prisma.module.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/architecture-r8-global-module-removal.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
];
```

Do not use a directory, glob, or prefix allowance.

The initial scanner exports:

```js
module.exports = {
  R8_BASE,
  EXPECTED_ALLOWED_PATHS,
  validateR8Manifest,
};
```

`validateR8Manifest` accepts plain dense JSON only, validates the exact key
set, fixed base, `design|strict` stage, document paths/hashes, sorted unique
repository-relative paths, and required path membership. Freeze the returned
arrays and objects.

- [ ] **Step 4: Add the R3 fixed-base delegation**

Import the R8 exports into `r3-scope.cjs`, define the canonical manifest path,
and add:

```js
function validateR8GlobalRemovalManifest(value) {
  const manifest = validateR8Manifest(value);
  if (manifest.baseRevision !== R8_BASE) {
    throw new Error('R8 global removal manifest identity is invalid');
  }
  assertAllowedPathsMatch(
    manifest.allowedChangedPaths,
    R8_ALLOWED_PATHS,
  );
  return Object.freeze({
    baseRevision: manifest.baseRevision,
    stage: manifest.stage,
    allowedChangedPaths: Object.freeze(Array.from(manifest.allowedChangedPaths)),
  });
}
```

Load the canonical R8 manifest beside R4-R7, append only its validated paths to
`effectiveAllowedPaths`, and export `R8_ALLOWED_PATHS` plus the validator.

- [ ] **Step 5: Run GREEN and the full focused gate**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r3-scope.test.ts test/architecture-r8-global-module-removal.test.ts
npm run architecture:r3
npm run check
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: every R3 scope test passes, R8 manifest tests pass, R3 architecture
passes with the current two project globals, TypeScript check passes, and no
production source file is changed.

- [ ] **Step 6: Review and checkpoint the scope handoff**

Inspect the exact diff and confirm the three production modules, package files,
and historical R3 inventory are untouched. Commit:

```powershell
git commit -m "test: govern modular monolith R8 scope"
```

---

### Task 2: Build The Permanent Project-Global And DI Gate

**Files:**

- Modify: `backend/architecture/r8-global-module-removal.json`
- Modify: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Modify: `backend/test/architecture-r8-global-module-removal.test.ts`
- Modify: `backend/package.json`
- Modify: `backend/scripts/security/prisma-config-merge-security.cjs`
- Modify: `backend/test/prisma-config-merge-security.test.ts`
- Modify generated: `docs/SCRIPTS.md`

**Interfaces:**

- Consumes: Task 1 manifest validation and fixed path fence.
- Produces: `scanR8GlobalRemoval(options)`,
  `projectR3InventoryForR8(inventory, manifest)`, `runCli`, design-stage live
  evidence, and `architecture:r8`.

- [ ] **Step 1: Write design-stage RED assertions**

Load the canonical manifest and repository root in one local `scan()` helper,
then add the exact live result:

```ts
assert.deepEqual(scan(), {
  ok: true,
  stage: 'design',
  projectOwnedGlobals: 2,
  prismaImporters: 20,
  missingPrismaImporters: [
    'backend/src/application-composition/application-outbox-runtime.module.ts',
  ],
  realtimeImporters: 2,
  duplicateProviders: 0,
  forwardRef: 0,
  nestModuleCycles: 0,
  dependencyRecords: 22,
  ownershipRecords: 385,
  ownershipOccurrences: 781,
});
```

Prove `PrismaModule` is the only `PrismaService` provider/export owner,
`ConversationRealtimeModule` is the only publisher provider/export owner, and
the strict importer projection is the exact 21-path design inventory.

- [ ] **Step 2: Write semantic-global and external-identity RED fixtures**

Add positive fixtures for the current `ScheduleModule.forRoot()` and
`ThrottlerModule.forRootAsync({ useFactory })` calls with exact lock evidence.
Add negative fixtures for:

- direct, aliased, namespace, re-exported, and computed Nest `Global`;
- project-owned `DynamicModule` returning `global: true` through a literal,
  local alias, cross-file alias, object spread, or computed key;
- unresolved project-owned DynamicModule metadata;
- external factory options resolving `global: true` or `isGlobal: true`;
- a changed Schedule/Throttler package name, range, version, tarball, integrity,
  imported class, method, source path, or call count;
- a third external exception or generic `node_modules` allowance;
- direct consumer without its provider-module import, transitive-only import,
  wrong-package same-name module, provider duplication, manual construction,
  `useClass`, factory, value, subclass, wrapper, or token lookalike;
- changed or duplicated Messaging `useExisting` bindings and new cross-context
  concrete publisher imports.

- [ ] **Step 3: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r8-global-module-removal.test.ts
```

Expected: FAIL because Task 1 validates only the manifest and does not scan
semantic globals, DI closure, provider identity, external locks, or R3
projection.

- [ ] **Step 4: Implement the smallest semantic scanner**

Use the TypeScript compiler AST and real module resolution. Implement
`collectProjectGlobalActivations(program, checker, repositoryRoot)`,
`collectDirectPrismaConsumers(program, checker, repositoryRoot)`,
`collectRealtimeComposition(program, checker, repositoryRoot)`,
`verifyExternalGlobalIdentities(repositoryRoot, manifest)`, and
`projectR3InventoryForR8(inventory, manifest)` as separate pure inspectors.
Add `createProgram(repositoryRoot)` to load the live Backend tsconfig and return
the exact TypeScript `program` plus `checker`, and `validateR8ScanResult(value)`
to accept only the bounded plain result schema below.
Compose them with this exact result shape:

```js
function scanR8GlobalRemoval({ repositoryRoot, manifest: manifestValue }) {
  const manifest = validateR8Manifest(manifestValue);
  const { program, checker } = createProgram(repositoryRoot);
  const globals = collectProjectGlobalActivations(program, checker, repositoryRoot);
  const prisma = collectDirectPrismaConsumers(program, checker, repositoryRoot);
  const realtime = collectRealtimeComposition(program, checker, repositoryRoot);
  const external = verifyExternalGlobalIdentities(repositoryRoot, manifest);
  return validateR8ScanResult({
    stage: manifest.stage,
    globals,
    prisma,
    realtime,
    external,
    dependencyRecords: 22,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
}
```

The global evaluator resolves bindings back to the real `@nestjs/common`,
evaluates finite local/cross-file constants, and fails closed on unresolved
project-owned DynamicModule or source-supplied external option metadata. It
does not recursively trust arbitrary dependency source. External behavior is
accepted only when both exact manifest identities match `package.json`,
`package-lock.json`, `app.module.ts`, and the installed locked entrypoint.

The DI scanner maps registered providers/controllers/gateways/schedulers/
interceptors and factory `inject` arrays to their owning `@Module`. A pure
helper parameter typed `PrismaService` is not a Nest consumer. Every registered
direct consumer requires a direct `PrismaModule` import.

- [ ] **Step 5: Add the architecture script**

Add these exact package scripts:

```json
"architecture:r8": "node scripts/architecture/r8-global-module-removal-scan.cjs --check",
"architecture": "npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5 && npm run architecture:r6 && npm run architecture:r7 && npm run architecture:r8"
```

Run `node .\scripts\docs-sync.mjs` from the repository root so
`docs/SCRIPTS.md` records the new script.

Extend the security checker with exact constants
`R8_ARCHITECTURE_SCRIPT` and `R8_STANDALONE_SCRIPT`, then add
`projectR8ArchitectureScripts(value)`. It must require the exact standalone and
aggregate strings, delete only `architecture:r8`, restore the aggregate string
to `R7_ARCHITECTURE_SCRIPT`, and pass the result through
`projectR7ArchitectureScripts`. The live checker must validate:

```js
validatePackageGraph(
  projectR8ArchitectureScripts(packageJson),
  packageLock,
);
```

Focused tests must prove the valid R8 package projects to the pinned graph and
reject a missing standalone script, attacker command, reordered aggregate,
extra R8-like key, changed R7 projection, or any `package-lock.json` mutation.

- [ ] **Step 6: Run GREEN and design-stage cumulative gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/architecture-r8-global-module-removal.test.ts test/architecture-r3-scope.test.ts
node --test -r ts-node/register test/prisma-config-merge-security.test.ts
npm run architecture:r8
npm run architecture
npm run check
npm run security:prisma-config-merge
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: design stage PASS with two current project globals, exactly one
missing Outbox Prisma import, 20 current/21 strict importers, two exact external
identities, and all cumulative architecture gates green.

- [ ] **Step 7: Review and checkpoint the permanent gate**

Confirm no production source, historical inventory, package dependency, or
lock file changed. Commit:

```powershell
git commit -m "test: govern project-owned Nest globals"
```

---

### Task 3: Atomically Remove Both Project-Owned Globals

**Files:**

- Modify: `backend/src/platform/database/prisma.module.ts`
- Modify: `backend/src/conversations/conversation-realtime.module.ts`
- Modify: `backend/src/application-composition/application-outbox-runtime.module.ts`
- Modify: `backend/architecture/r8-global-module-removal.json`
- Modify: `backend/scripts/architecture/ports-scan.cjs`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Modify: `backend/test/architecture-ports.test.ts`
- Modify: `backend/test/architecture-r1-layout.test.ts`
- Modify: `backend/test/architecture-r3-composition.test.ts`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify: `backend/test/architecture-r8-global-module-removal.test.ts`

**Interfaces:**

- Consumes: design-stage R8 scanner, exact 21-module closure, immutable R3
  inventory, and current provider/token identities.
- Produces: strict zero-project-global source, exact R3 projection, and one
  immutable application candidate checkpoint.

- [ ] **Step 1: Write the strict RED**

Clone the manifest fixture to `stage: 'strict'` against unchanged source and
require failures for the two remaining decorators and missing Outbox import.
Add R3 projection tests with this exact result:

```ts
const projected = projectR3InventoryForR8(historicalInventory, strictManifest);
const modules = new Map(projected.legacyModules.map((entry: any) => [entry.path, entry]));
assert.equal((modules.get(prismaModulePath) as any).global, false);
assert.equal((modules.get(realtimeModulePath) as any).global, false);
assert.deepEqual(
  (modules.get(outboxRuntimePath) as any).imports,
  [
    'MessagingRealtimePublicModule',
    'OutboxCoreModule',
    'PrismaModule',
    'PushDeliveryPublicModule',
  ],
);
```

Reject a wrong before-value, wrong path, fourth projection, duplicate/unsorted
import, changed provider/export/controller, or design-stage projection.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register `
  test/architecture-r8-global-module-removal.test.ts `
  test/architecture-ports.test.ts `
  test/architecture-r1-layout.test.ts `
  test/architecture-r3-composition.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r7-collaboration-relocation.test.ts
```

Expected: strict R8 and projection assertions FAIL on the current two globals
and missing Outbox direct import. Existing behavioral tests are untouched.

- [ ] **Step 3: Apply the three production changes only**

Set `prisma.module.ts` to:

```ts
import { Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

Set `conversation-realtime.module.ts` to:

```ts
import { Module } from '@nestjs/common';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

@Module({
  providers: [ConversationRealtimePublisher],
  exports: [ConversationRealtimePublisher],
})
export class ConversationRealtimeModule {}
```

Add this import to `application-outbox-runtime.module.ts`:

```ts
import { PrismaModule } from '../platform/database/prisma.module';
```

and add `PrismaModule` to its `imports` array after `OutboxCoreModule`.

- [ ] **Step 4: Promote every live gate through exact R8 handoffs**

Set the R8 manifest stage to `strict`. In the ports scanner, make the approved
project-owned global set empty, remove the obsolete required-global loop, and
keep all semantic direct/alias/namespace Global rejection tests.

Update only active-source assertions:

- R1 keeps Prisma `$connect()`/`$disconnect()` lifecycle checks and expects the
  ordinary module source;
- R3 composition expects the ordinary Realtime module and preserves both
  `useExisting` aliases and exact runtime instance equality;
- R3 context scanning validates the strict R8 manifest and compares live source
  with `projectR3InventoryForR8` output, never a rewritten R3 manifest;
- R7 validates its complete relocation contract and delegates only current
  project-global state to strict R8;
- all reported project-owned global counts become zero.

Do not change dependency/ownership baselines or historical completion docs.

- [ ] **Step 5: Prove singleton identity with real Nest contexts**

In the R8 test, define two small test modules that each import `PrismaModule`
and own a consumer injecting `PrismaService`. Temporarily replace only
`PrismaService.prototype.onModuleInit/onModuleDestroy` with no-op functions,
create one Nest application context, and assert both consumers hold the exact
same object. Restore prototypes in `finally` and close the context.

Reuse the real `MessagingRealtimePublicModule` test context and assert:

```ts
assert.equal(
  context.get(MESSAGING_REALTIME_PORT, { strict: false }),
  context.get(ConversationRealtimePublisher, { strict: false }),
);
```

Also resolve `MESSAGING_REALTIME_IMPLEMENTATION` and require the same identity.

- [ ] **Step 6: Run focused GREEN**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register `
  test/architecture-r8-global-module-removal.test.ts `
  test/architecture-ports.test.ts `
  test/architecture-r1-layout.test.ts `
  test/architecture-r3-composition.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r3-scope.test.ts `
  test/architecture-r7-collaboration-relocation.test.ts
npm run architecture
npm run check
npm run build
npm test
Set-Location D:\projects\aarast-modular-monolith
git diff --check
```

Expected: strict R8 reports project globals 0, Prisma importers 21, missing 0,
Realtime importers 2, duplicates/cycles/`forwardRef()` 0, dependency 22,
ownership 385/781; all architecture/check/build/tests pass with only the
intentional Windows permission skip.

- [ ] **Step 7: Review and create the application checkpoint**

Inspect `git diff --name-status`, `git diff --check`, and every existing-test
hunk. Reject any behavior assertion change. Commit:

```powershell
git commit -m "refactor: remove project-owned Nest globals"
```

Record the full commit as the R8 application candidate. Do not push.

---

### Task 4: Exhaustively Verify And Independently Review The Candidate

**Files:** No planned product changes. Any correction requires a reproduced
failure, an in-scope root cause, a failing regression test, and a separate
reviewed checkpoint.

**Interfaces:**

- Consumes: exact clean application candidate from Task 3.
- Produces: one verified candidate approved for immutable local runtime or a
  truthful blocked result.

- [ ] **Step 1: Run dependency, security, and Prisma gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm audit --audit-level=high
npm audit --omit=dev
npm run security:prisma-config-merge
npx prisma validate
npx prisma generate
```

Expected: zero qualifying audit findings, patched Prisma merge identity PASS,
and Prisma 6.19.3 validation/generation PASS.

Prove schema equivalence with a unique OS-temporary directory:

```powershell
$proof = Join-Path ([IO.Path]::GetTempPath()) `
  ('aarast-r8-prisma-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proof | Out-Null
try {
  git archive c2b728bfe54304562923facfb6094e0de04c0b27 backend/prisma/schema | tar -xf - -C $proof
  node scripts/prisma/dmmf-fingerprint.cjs --output (Join-Path $proof 'candidate-dmmf.json')
  npx prisma migrate diff --exit-code `
    --from-schema-datamodel (Join-Path $proof 'backend/prisma/schema') `
    --to-schema-datamodel prisma/schema
  git diff --exit-code c2b728bfe54304562923facfb6094e0de04c0b27 -- `
    prisma/schema prisma/migrations prisma/seed.ts prisma.config.ts package-lock.json
} finally {
  $resolvedProof = (Resolve-Path -LiteralPath $proof -ErrorAction SilentlyContinue).Path
  $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
  if ($resolvedProof -and $resolvedProof.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedProof -Recurse -Force
  }
}
```

Expected: fingerprint 52 models / 41 enums, 76 migrations unchanged, migrate
diff exit 0, protected diff empty, and temporary proof directory removed.

- [ ] **Step 2: Run focused managed smokes**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run smoke:health
npm run smoke:auth
npm run smoke:tasks-apis
npm run smoke:conversation-unification
npm run smoke:notifications
npm run smoke:sharing
npm run smoke:phase2-auth-lifecycle-concurrency
npm run smoke:phase2-conversation-revocation
npm run smoke:phase2-idempotency-reconciliation
npm run smoke:phase2-notification-preferences
npm run smoke:phase2-task-guest-permission-concurrency
npm run smoke:phase3-context-transition
```

Expected: all twelve packages pass with successful cleanup and no retained managed
database/container/media residue.

- [ ] **Step 3: Run the aggregate managed suite**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run smoke:all
```

Expected: all 30 managed packages PASS. The conversation package must exercise
its real Socket.IO path. Do not run a real-recipient WhatsApp mutation.

- [ ] **Step 4: Rerun all static/full gates on the same commit**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
npm run build
npm test
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git status --short
```

Expected: every command PASS and status empty. Record observed test totals;
require zero failures and only the intentional Windows permission skip.

- [ ] **Step 5: Run an independent exact-diff review**

Use `superpowers:requesting-code-review`. Give the reviewer the design, plan,
immutable base, candidate SHA, complete diff, R8 manifest, architecture output,
test/audit/Prisma/smoke receipts, and protected-surface evidence. Require
Critical, Important, and Minor classification plus an explicit readiness
verdict.

Resolve every Critical or Important finding test-first in a separate local
checkpoint, then rerun Tasks 3 Step 6 and 4 Steps 1-4. Do not hide or silently
reclassify a finding.

---

### Task 5: Bind Immutable Runtime And Physical-Phone Evidence

**Files:** No tracked source changes expected. Sanitized working reports remain
ignored under `.superpowers/sdd/2026-08-27-modular-monolith-r8-global-removal/`.

**Interfaces:**

- Consumes: exact clean candidate approved by Task 4 and accepted local runtime
  configuration without printing secrets.
- Produces: immutable image identity, isolated probe, protected local cutover,
  preserved R7 rollback, and physical-phone PASS/FAIL evidence.

- [ ] **Step 1: Build and inspect the immutable R8 image**

```powershell
Set-Location D:\projects\aarast-modular-monolith
$candidate = git rev-parse HEAD
$short = $candidate.Substring(0,8)
docker build --build-arg AARAST_GIT_REVISION=$candidate `
  -t aarast-backend:r8-candidate-$short `
  -f backend/Dockerfile backend
docker image inspect aarast-backend:r8-candidate-$short `
  --format '{{index .Config.Labels "org.opencontainers.image.revision"}} {{.Id}}'
```

Expected: label equals the full candidate SHA and one immutable image ID. Run
the production dependency audit inside the image and require zero qualifying
findings.

- [ ] **Step 2: Run and remove an isolated loopback probe**

Use the accepted R7 runtime configuration through process-local Docker
arguments without echoing or persisting environment values. Start
`aarast-backend-r8-probe` on loopback port `3121`, then verify:

```powershell
Invoke-WebRequest http://127.0.0.1:3121/live -UseBasicParsing
Invoke-WebRequest http://127.0.0.1:3121/ready -UseBasicParsing
docker inspect aarast-backend-r8-probe `
  --format '{{.RestartCount}} {{.State.OOMKilled}} {{.State.Health.Status}}'
```

Expected: both HTTP status 200, required database/Redis/media readiness up,
restart 0, OOM false, healthy, exact revision, and zero sanitized fatal or
secret-name markers. Remove the probe in a `finally` path on PASS or FAIL;
cleanup failure fails the probe.

- [ ] **Step 3: Cut over locally and preserve R7 rollback**

Confirm `aarast-backend-r7-phone` and its immutable image exist. Stop but do not
delete them. Start `aarast-backend-r8-phone` from the accepted R8 image on the
existing local network and host port `3120`. Verify local and LAN `/live` and
`/ready` 200, revision identity, dependencies up, restart 0, OOM false, and
sanitized logs.

On any failure, stop/remove the failed R8 container, restart the preserved R7
container, verify local/LAN health, and record rollback PASS/FAIL. Successful
rollback does not convert the R8 result to PASS.

- [ ] **Step 4: Prove the authorized phone and candidate endpoint**

Use `adb devices -l` or the installed Android SDK `adb.exe`. Require exactly one
authorized device, confirm the Aarast package is installed, confirm the app is
using the LAN endpoint on port `3120`, and confirm server revision R8. Do not
retain the device serial, phone, token, OTP, or credential.

- [ ] **Step 5: Exercise the exact phone journey**

On the phone:

1. log in through the existing local OTP path or restore the authenticated
   session;
2. verify selected context and dashboard;
3. create one clearly synthetic task, read it, update it, and delete it;
4. if an eligible existing quote-scoped conversation is available, send/read
   one synthetic realtime message and verify the timeline; do not invent open
   messaging when no eligible conversation exists;
5. force-stop the application and reopen it;
6. verify session, context, dashboard, and post-cleanup task state restore.

The deterministic Socket.IO smoke remains mandatory even when no routed phone
conversation is eligible. Retain no message text, raw body, business value,
phone, OTP, or token.

- [ ] **Step 6: Record sanitized runtime evidence**

Record only candidate/image/container identity, route names, status codes,
counts, timestamps, restart/OOM/health state, rollback availability, and owner
PASS/FAIL. Keep R7 stopped and preserved after successful R8 cutover.

---

### Task 6: Close R8 Locally And Stop Before R9

**Files:**

- Create: `docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`
- Create: `docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`
- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`

**Interfaces:**

- Consumes: exact application candidate, verification review, immutable runtime,
  phone evidence, and preserved R7 rollback.
- Produces: truthful local R8 completion receipts and a clean stop before R9.

- [ ] **Step 1: Write exact completion receipts**

The completion specification records:

- immutable base, design/plan checkpoints, application candidate, final docs
  checkpoint, image ID, container identity, and preserved R7 rollback;
- final project-owned global count, Prisma/Realtime importer counts, singleton
  identities, R3 projection, dependency 22, ownership 385/781, cycles and
  `forwardRef()` zero;
- observed architecture/check/build/test totals, audits, Prisma equivalence,
  ten focused smokes, all 30 aggregate smokes, independent-review verdict,
  runtime health, and phone outcome;
- exact protected surfaces and explicit unclaimed push/merge/deploy/remote-CI/
  R9 results;
- sanitized data-retention statement.

The completion plan is a concise checked execution receipt; do not rewrite the
approved implementation plan into a post-hoc narrative.

- [ ] **Step 2: Update active status documents**

Record R8 as locally complete only if every required gate passed. Update the
architecture phase contract from two approved project globals to zero, retain
the two exact frozen external package behaviors, name R7 as rollback, and stop
before R9. Do not rewrite R0-R7 historical documents.

- [ ] **Step 3: Run final closeout gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture:r8
npm run architecture
npm run check
npm run build
npm test
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: every command PASS on the exact application source plus completion
docs; no source, package-lock, schema, migration, Mobile, Admin, workflow, or
deployment drift.

- [ ] **Step 4: Review and commit the docs-only closeout**

Inspect `git diff --name-status`, `git diff --check`, receipt values, and every
claim against raw evidence. Stage exactly the ten Task 6 paths and commit:

```powershell
git commit -m "docs: close R8 project global removal"
```

- [ ] **Step 5: Prove the final stop boundary**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git status --short
git log -1 --oneline
docker inspect aarast-backend-r8-phone `
  --format '{{index .Config.Labels "org.opencontainers.image.revision"}} {{.RestartCount}} {{.State.OOMKilled}} {{.State.Health.Status}}'
docker inspect aarast-backend-r7-phone `
  --format '{{.State.Status}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
```

Expected: clean worktree, HEAD is the R8 docs-only closeout, R8 healthy with
the exact application candidate/restart 0/OOM false, R7 stopped and preserved.
Stop. Do not push, merge, deploy, run remote CI, or begin R9.

## R8 Execution Contract — Task 0

R8 base: `c2b728bfe54304562923facfb6094e0de04c0b27`
Objective: zero project-owned globals with explicit Prisma/Realtime imports
State: design and plan approved; application source unchanged
Stop: no push, merge, deployment, remote CI, or R9
