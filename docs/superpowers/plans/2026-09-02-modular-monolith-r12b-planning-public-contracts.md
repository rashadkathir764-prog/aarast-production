# Modular Monolith R12B Planning Public Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire exactly R12B dependency records `7-9`, `11`, `18`, and
`21-22` by publishing the existing Planning location contract and owning the
local-import task/guest DTO shapes inside Onboarding, reducing dependency debt
from 16 to 9 while ownership stays 385/781.

**Architecture:** Relocate `wedding-location.ts` one-to-one into
`modules/planning/public`, rewrite only the declared import paths, and create two
Onboarding-local DTO classes that are exact class-name transformations of the
current Tasks and Guests DTOs. A new R12B manifest/scanner/test layer consumes
the validated R12A composite predecessor and extends the cumulative
R3/R5/R6/R7/R8/R12A and Prisma-security gates without changing historical
phase results.

**Tech Stack:** Node.js, TypeScript, NestJS, Prisma 6.19.3, class-transformer,
class-validator, dependency-cruiser, Node test runner, PowerShell.

**Spec:**
`docs/superpowers/specs/2026-09-02-modular-monolith-r12b-planning-public-contracts-design.md`

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch
  `modular-monolith` and HEAD
  `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- Preserve the exact pre-plan R11/R12A 65-path overlay fingerprint
  `30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c`.
- Preserve the R12A manifest fingerprint
  `b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd`.
- Enter at dependency 16 and ownership 385/781; exit at dependency 9 and
  ownership 385/781.
- Delete only dependency IDs `7-9`, `11`, `18`, `21-22`; never regenerate the
  dependency baseline.
- Keep `backend/architecture/ownership-baseline.json` byte-identical with
  SHA-256 `5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496`.
- Keep `backend/package-lock.json` protected and admit only the exact
  owner-approved qs security prerequisite receipt below. Keep
  `backend/prisma/**`, Mobile, Admin Web, Docker, Compose, Dokploy, production,
  routes, payloads, validation, errors, permissions, transactions, locks,
  responses, and Arabic behavior unchanged.
- Do not add a facade, barrel re-export, fallback, alias, duplicate runtime
  implementation, shared DTO, or public Tasks/Guests API DTO.
- Existing tests may change only for manifest-declared path literals; do not
  delete, skip, weaken, or rewrite behavior assertions.
- Do not stage, commit, push, merge, branch, checkout, reset, create a worktree,
  deploy, mutate production, run remote CI, deliver to a provider, release, or
  begin R12C.
- Because Git work is not authorized, each task ends with an independent review
  checkpoint instead of a commit step.

---

### Task 1: Freeze The Composite Entry And Add The Design-Stage R12B Authority

**Files:**

- Create: `backend/architecture/r12b-planning-public-contracts.json`
- Create: `backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs`
- Create: `backend/scripts/architecture/r12b-documentation-transition.cjs`
- Create: `backend/test/architecture-r12b-planning-public-contracts.test.ts`
- Create: `backend/test/architecture-r12b-documentation-transition.test.ts`
- Read only: `backend/architecture/r12a-backoffice-catalog-public-contracts.json`
- Read only: `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
- Read only: `backend/.dependency-cruiser-known-violations.json`
- Read only: `backend/architecture/ownership-baseline.json`

**Interfaces:**

- Consumes: R12A exports `validateR12aManifest`,
  `expectedR12aDependencyRecords`, `expectedR12aOwnershipBaseline`, and
  `readR12aImmutableEntry`.
- Produces: `validateR12bManifest`, `expectedR12bDependencyRecords`,
  `validateR12bPredecessorOverlay`,
  `projectR12bWorkingTreeToPredecessor`,
  `validateR12bDocumentationTransitions`,
  `verifyR12bLocationSourceParity`, `verifyR12bConsumerParity`,
  `verifyR12bDtoParity`, `scanR12bPlanningPublicContracts`, and `runCli`.
- Produces transition-runner exports `planDocumentationTransition`,
  `runDocumentationTransition`, `recoverDocumentationTransition`, and `runCli`.
- Produces manifest stages `design`, `planning-public`, and `strict` with counts
  16, 11, and 9.

- [ ] **Step 1: Reconfirm the exact composite entry before creating files**

Run from the repository root:

```powershell
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git diff --cached --name-only
git status --porcelain=v1 --untracked-files=all
npm --prefix backend run architecture:r12a
```

Expected: root `D:/projects/aarast-modular-monolith`, branch
`modular-monolith`, immutable HEAD above, staged output empty, and R12A reports
`stage=strict, dependency=16, ownership=385/781`. Before creating any R12B
governance file, a read-only helper must also reproduce all 65 ordered
`status|path|sha256-or-DELETED` rows from the design's **Complete 65-path
predecessor preimage**, plus aggregate SHA-256
`30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c`.
The canonical aggregate is the SHA-256 of the 65 serialized rows in table order,
joined with UTF-8 LF separators and no final newline.
Stop on a missing, additional, duplicate, reordered, status-mismatched, or
hash-mismatched row.

- [ ] **Step 2: Write RED tests for the exact manifest schema and predecessor**

Create the test file first. It must assert these constants and reject every
single-field mutation:

```ts
const repository = {
  rootName: 'aarast-modular-monolith',
  branch: 'modular-monolith',
  baseCommit: '4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1',
};

const predecessor = {
  phase: 'R12A',
  manifestSha256:
    'b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd',
  dependencyRecords: 16,
  dependencySha256:
    '4dd61610c6583e369b836b3b0fe80ffc63153e70a0fbe86a089509962b35c71e',
  ownershipRecords: 385,
  ownershipOccurrences: 781,
  ownershipSha256:
    '5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496',
  overlayPaths: 65,
  overlaySha256:
    '30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c',
  overlayLedger: completePredecessorOverlayLedger,
};

const stages = {
  design: { retiredDependencyIds: [], dependencyRecords: 16 },
  'planning-public': {
    retiredDependencyIds: [7, 8, 9, 11, 18],
    dependencyRecords: 11,
  },
  strict: {
    retiredDependencyIds: [7, 8, 9, 11, 18, 21, 22],
    dependencyRecords: 9,
  },
};
```

Also assert that unknown keys, sparse arrays, duplicate IDs, extra retirements,
wrong order, unsafe paths, unsafe numbers, wrong hashes, and changed ownership
totals fail closed. `completePredecessorOverlayLedger` is the exact 65-row
ordered ledger in the design appendix; it is not a count-only or hash-only
substitute. Tests must independently mutate status, path, and content hash in
every ledger category (` M`, ` D`, and untracked `??`) and in each shared
predecessor file that R12B later edits.

Add RED state-machine tests for `documentationStage`: `entry`,
`candidate-prepared`, `candidate`, `activation-prepared`, and `activated`.
At `entry`, all seven documentation transforms require their ledger
`entrySha256` plus explicit null `candidateSha256` and `activatedSha256`. The
prepared/candidate/activated states require both later hashes and reject a
missing, post-publication, mismatched, reordered, or skipped transition.

The tests must pin the documentation genesis SHA-256
`e60fbd3d8820a9bfa00199937e0ce44025a32a73f41454786a3d53aef1adf4ad`
and require an append-only four-receipt prefix. Each receipt uses fixed fields
`sequence`, `from`, `to`, `previousReceiptSha256`, `beforeDocuments`,
`afterDocuments`, `candidateDocuments`, `activatedDocuments`, and
`receiptSha256`. Add RED cases for a direct jump, wrong previous hash, missing,
duplicate, reordered, or rewritten receipt, changed document order, stale
manifest SHA, post-publication registration, and a forged current stage without
the required receipt prefix.

Canonicalization is not locale-derived. Copy the complete one-line genesis JSON
from the design and assert that `SHA256(UTF8(genesisLiteral))`—with no BOM or
final newline—is exactly the pinned value. Every document array uses the design's
literal seven-path order, and every element key order is exactly `path`, then
`sha256`. Receipt hashes use `JSON.stringify` without replacer/spacing in the
declared top-level field order. Add a negative test that swaps two adjacent
document elements and proves both genesis/receipt validation fail.

- [ ] **Step 3: Run the focused test and observe the expected RED result**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/architecture-r12b-documentation-transition.test.ts
```

Expected: FAIL because the R12B scanner and manifest do not exist. A syntax or
dependency error unrelated to the missing R12B authority is not an acceptable
RED state.

- [ ] **Step 4: Create the complete design-stage manifest**

The manifest must use this identity and exact debt inventory:

```json
{
  "schemaVersion": 2,
  "phase": "R12B",
  "stage": "design",
  "documentationStage": "entry",
  "documentationTransitionGenesisSha256": "e60fbd3d8820a9bfa00199937e0ce44025a32a73f41454786a3d53aef1adf4ad",
  "documentationTransitions": [],
  "repository": {
    "rootName": "aarast-modular-monolith",
    "branch": "modular-monolith",
    "baseCommit": "4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1"
  },
  "predecessor": {
    "phase": "R12A",
    "manifestSha256": "b2904ef15dd104da8cc27315d89880b75042a6175df3a756897b0b45e4a269fd",
    "dependencyRecords": 16,
    "dependencySha256": "4dd61610c6583e369b836b3b0fe80ffc63153e70a0fbe86a089509962b35c71e",
    "ownershipRecords": 385,
    "ownershipOccurrences": 781,
    "ownershipSha256": "5f42f33300a9727f587e62327c5261a88a6ce5928437241c9e7c20f726906496",
    "overlayPaths": 65,
    "overlaySha256": "30e2de6928edd7ac1b44598fae4ad18dbcd452b34f7e9a6fb792e1936ce8561c"
  }
}
```

Add `predecessor.overlayLedger` as structured data containing all 65 literal
rows from the design section **Complete 65-path predecessor preimage**, in the
same order. Each object has exactly `status`, `path`, and `sha256`; deletion rows
use the literal `DELETED`. Validation recomputes both the row count and aggregate
fingerprint from those literal rows. The design table is normative and no row
may be abbreviated, inferred, or generated from the live state.

Add exact non-empty `stages`, `dependencyRecords`, `locationMove`,
`locationConsumers`, `dtoReexpressions`, `behavioralTests`, and
`protectedPaths` collections, plus the complete `inverseTransforms` registry
needed by the declared R12B shared-file edits. The seven dependency records must
copy the full objects from the original R11 ledger and retain IDs `7`, `8`, `9`,
`11`, `18`, `21`, and `22`; do not infer IDs from current array indexes.

The inverse-transform registry contains exactly the 25 paths in the design
section **Complete 65-path predecessor preimage** under the bounded mutation
list. Register each entry SHA, transform kind, exact transform payload, and
intended final SHA before editing that target. The remaining 40 ledger rows are
byte/status immutable. Any 26th shared-overlay mutation requires a reviewed
design revision before the file is touched.

For the seven documentation paths, the design-stage registry is complete but
uses the explicit state `entry`: `entrySha256` equals the ledger row while
`candidateSha256` and `activatedSha256` are null. Task 6 must replace both nulls
with hashes prepared outside the repository and validate `candidate-prepared`
before publishing the first documentation byte.

The design manifest starts with `documentationStage: "entry"` and
`documentationTransitions: []`. The scanner derives every later stage from the
validated receipt chain; a stage value without its exact prefix is invalid.

Record these immutable source hashes:

```text
7836f0cf91b07f970e947684e1c382fca97b42d8edeed57ee1563fbe556ac764  wedding-location.ts
43cee77072074d9227ae3359488b8d6c21b74d6f5c4db1039fe0c7966ce0a777  wedding-plans.service.ts
f637cbeac2027fc735233a15f2df36f91a7c61d861893ba2960235ac2cf9dbb6  dashboard.contracts.ts
c865b51880d1060bb1b84095f12aeaa50e41cd1636da267253c34a9b24414e97  dashboard.service.ts
c67f930f50bbac4524616aa9a1981a8d13a8854f1e1ce531f80bf8975c48dc85  marketplace.presenter.ts
51d5f6412c10763bd11b60540203d59fac77e594edaf9de24b376f48e22721a1  marketplace.service.ts after R12A
44ce4ac70168b49bfe8f49b8c047d1ea888d74b8078a49f46d13b85cf56a46e8  provider-dashboard.service.ts
cd669f1813c50de61f3580d26d29474583a60d158fc5180bffef57b0bbdf579d  import-local-plan.dto.ts
9960bc6d618a5f3cb03a7491375842ab73e4fe2e9c4db884b3f24743b0745e6a  create-task.dto.ts
3efce4297de98e74a80e0158d5b005172728a32def420bc7de3a3ed4ee1068a6  create-guest.dto.ts
8dc46754c9d8982372d9f4bcd6a62a9427cf49e519a994c9bd6dd63eb5b6e834  backend-support.test.ts
```

- [ ] **Step 5: Implement the fail-closed design-stage scanner**

Use CommonJS and export exactly:

```js
module.exports = {
  validateR12bManifest,
  expectedR12bDependencyRecords,
  validateR12bPredecessorOverlay,
  projectR12bWorkingTreeToPredecessor,
  validateR12bDocumentationTransitions,
  verifyR12bLocationSourceParity,
  verifyR12bConsumerParity,
  verifyR12bDtoParity,
  scanR12bPlanningPublicContracts,
  runCli,
};
```

Implement the separate transition runner with exports:

```js
module.exports = {
  planDocumentationTransition,
  runDocumentationTransition,
  recoverDocumentationTransition,
  runCli,
};
```

The runner accepts only the next legal `--to` state, the exact
`--expected-manifest-sha256`, and the required prepared roots. It validates
bounded plain files, rejects symlinks/reparse points and paths outside the seven
declared targets, appends exactly one hash-linked receipt, and atomically replaces
the manifest. For publication transitions it writes a fail-closed journal,
hash-verifies seven backups and sibling temporary files, atomically publishes,
then commits the manifest receipt and removes journal/backups. A failure restores
all prior bytes. A process interruption requires `--recover`; the scanner must
reject any remaining journal, backup, temporary file, or partial publication.
There is no force, skip, direct stage setter, or history rewrite.

The design-stage scan algorithm is:

```js
const r12aEntry = r12a.readR12aImmutableEntry({
  repositoryRoot,
  manifest: r12aManifest,
  readImmutableFile,
});
const r12aDependency = r12a.expectedR12aDependencyRecords(
  r12aEntry.dependency,
  r12aManifest,
);
const expectedDependency = expectedR12bDependencyRecords(
  r12aDependency,
  r12bManifest,
);
const expectedOwnership = r12a.expectedR12aOwnershipBaseline(
  r12aEntry.ownership,
  r12aManifest,
);
```

At `design`, compare live dependency and ownership files to those expected
values, verify every declared source hash, verify no target/local DTO exists,
and verify the legacy location path still exists. `runCli()` accepts only
`--check`; all other arguments return exit code 2 with one generic error unless
`R12B_DEBUG=1`.

`validateR12bPredecessorOverlay` must verify the complete literal 65-row ledger
before any Task 2-6 write. `projectR12bWorkingTreeToPredecessor` must then map
the later R12B state back to that exact ledger. Every predecessor path changed
by R12B requires a manifest-declared inverse transform registered and
hash-pinned before the edit. Allowed transform kinds are only exact text
rewrite, one-to-one move, dependency-subtraction reinsertion, package-script
projection, bounded scanner/test hunk replay (schema-version-2 correction in
Task 4 Step 0), or explicit documentation
entry/candidate/activated hashes plus the receipt chain. Unknown transforms,
missing or duplicate registrations,
post-hoc widening, status drift, or projected hash drift fail closed.
For documentation, expected live bytes are selected only by
`documentationStage`: entry bytes for `entry`/`candidate-prepared`, candidate
bytes for `candidate`/`activation-prepared`, and activated bytes for
`activated`. Projection must reconstruct the entry ledger in all five states.
The scanner validates the complete receipt prefix first and derives the stage
from its final `to`; current hashes and bytes alone are insufficient.

- [ ] **Step 6: Run design-stage GREEN and adversarial tests**

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r12b-planning-public-contracts.test.ts
node --test -r ts-node/register test/architecture-r12b-documentation-transition.test.ts
node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check
```

Expected: tests PASS and CLI reports `stage=design, dependency=16,
documentation=entry, receipts=0, ownership=385/781`. Tests must include malformed
JSON data, wrong predecessor,
path traversal, duplicate record, extra retirement, and symlink/reparse-point
fixtures. They must also prove all 65 preimage rows, exercise status/path/hash
mutation per ledger category, mutate every shared predecessor file, and reject
an undeclared or post-hoc inverse transform.
The transition suite must run all four transitions end to end, exercise
publication failure and recovery after each file boundary, and reject a final
candidate/activated snapshot without the exact receipt chain.

- [ ] **Step 7: Independent Task 1 review checkpoint**

The reviewer reads the design, manifest, scanner, tests, live debt files, and
Git identity. Required verdict: Critical `0`, Important `0`, Minor `0`. Stop and
remediate findings before Task 2. Do not stage or commit.

---

### Task 2: Relocate The Planning Location Contract One-To-One

**Files:**

- Create: `backend/src/modules/planning/public/wedding-location.ts`
- Delete: `backend/src/wedding-plans/wedding-location.ts`
- Modify: `backend/src/wedding-plans/wedding-plans.service.ts`
- Modify: `backend/src/dashboard/dashboard.contracts.ts`
- Modify: `backend/src/dashboard/dashboard.service.ts`
- Modify: `backend/src/marketplace/marketplace.presenter.ts`
- Modify: `backend/src/marketplace/marketplace.service.ts`
- Modify: `backend/src/provider-dashboard/provider-dashboard.service.ts`
- Modify: `backend/test/backend-support.test.ts`
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/architecture/r12b-planning-public-contracts.json`
- Modify: `backend/test/architecture-r12b-planning-public-contracts.test.ts`

**Interfaces:**

- Consumes: the four existing location exports with unchanged signatures.
- Produces: the same exports only from
  `modules/planning/public/wedding-location`.
- Produces stage `planning-public` at dependency 11 and ownership 385/781.

- [ ] **Step 1: Add RED move-layout, source-parity, and consumer-parity tests**

Add tests that require:

```ts
const move = {
  from: 'backend/src/wedding-plans/wedding-location.ts',
  to: 'backend/src/modules/planning/public/wedding-location.ts',
  runtimeExports: [
    'cityFromWeddingLocation',
    'normalizeWeddingLocationInput',
    'weddingLocationResponse',
  ],
  typeExports: ['WeddingLocationResponse'],
  entrySha256:
    '7836f0cf91b07f970e947684e1c382fca97b42d8edeed57ee1563fbe556ac764',
};
```

The RED test must reject legacy/target coexistence, target absence, facade
content, changed exports, changed exceptions/limits, undeclared consumers, and
any consumer edit beyond its module specifier.

- [ ] **Step 2: Run the focused test and confirm RED**

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r12b-planning-public-contracts.test.ts
```

Expected: FAIL because the manifest is moved to `planning-public` while the
target file and rewritten consumers do not yet exist.

- [ ] **Step 3: Add the public file and delete the legacy file using one patch**

Use `apply_patch` so the target content is exactly the complete current content
of `backend/src/wedding-plans/wedding-location.ts`, then delete the old file in
the same logical change. Do not edit its imports, quote style, limits,
exceptions, functions, or exports. Verify:

```powershell
(Get-FileHash -Algorithm SHA256 backend/src/modules/planning/public/wedding-location.ts).Hash.ToLower()
Test-Path backend/src/wedding-plans/wedding-location.ts
```

Expected hash:
`7836f0cf91b07f970e947684e1c382fca97b42d8edeed57ee1563fbe556ac764`;
legacy result `False`.

- [ ] **Step 4: Rewrite exactly the declared source import specifiers**

Use these replacements and no others:

```text
dashboard/dashboard.contracts.ts:
  ../wedding-plans/wedding-location
  -> ../modules/planning/public/wedding-location

dashboard/dashboard.service.ts:
  ../wedding-plans/wedding-location
  -> ../modules/planning/public/wedding-location

marketplace/marketplace.presenter.ts:
  ../wedding-plans/wedding-location
  -> ../modules/planning/public/wedding-location

marketplace/marketplace.service.ts:
  ../wedding-plans/wedding-location
  -> ../modules/planning/public/wedding-location

provider-dashboard/provider-dashboard.service.ts:
  ../wedding-plans/wedding-location
  -> ../modules/planning/public/wedding-location

wedding-plans/wedding-plans.service.ts:
  ./wedding-location
  -> ../modules/planning/public/wedding-location

test/backend-support.test.ts:
  ../src/wedding-plans/wedding-location
  -> ../src/modules/planning/public/wedding-location
```

The `marketplace.service.ts` verifier must normalize its already-approved R12A
provider-rating import first, then the R12B location import, before comparing
with immutable HEAD.

- [ ] **Step 5: Subtract only the five location records**

Remove exact IDs `7`, `8`, `9`, `11`, and `18` from the baseline by matching
`rule.name`, `from`, `to`, and `unresolvedTo`. Do not run
`architecture:imports:baseline`. Set manifest stage to `planning-public`.

Verify with a script that reports:

```text
entry=16 retired=5 live=11 added=0 unexpectedRemoved=0
```

- [ ] **Step 6: Run focused location and architecture GREEN gates**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/backend-support.test.ts
node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check
npx tsc --noEmit
```

Expected: all tests and typecheck PASS; R12B reports
`stage=planning-public, dependency=11, ownership=385/781`.

- [ ] **Step 7: Independent Task 2 review checkpoint**

Reviewer verifies exact source bytes, one location target, zero legacy path,
seven path-only consumer/test rewrites, exact five-row subtraction, unchanged
ownership, and preserved R12A marketplace rewrite. Required verdict `0/0/0`.

---

### Task 3: Re-Express The Onboarding Local-Import DTOs

**Files:**

- Create: `backend/src/onboarding/dto/import-local-task.dto.ts`
- Create: `backend/src/onboarding/dto/import-local-guest.dto.ts`
- Create: `backend/test/import-local-plan-dto-contract.test.ts`
- Modify: `backend/src/onboarding/dto/import-local-plan.dto.ts`
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/architecture/r12b-planning-public-contracts.json`
- Modify: `backend/test/architecture-r12b-planning-public-contracts.test.ts`

**Interfaces:**

- Produces: `ImportLocalTaskDto` with the same JSON/validation contract as
  `CreateTaskDto`.
- Produces: `ImportLocalGuestDto` with the same JSON/validation contract as
  `CreateGuestDto`.
- Produces: `ImportLocalPlanDto.tasks?: ImportLocalTaskDto[]` and
  `guests?: ImportLocalGuestDto[]`.
- Produces strict dependency count 9 and unchanged ownership 385/781.

- [ ] **Step 1: Write RED structural and behavioral parity tests**

The architecture test records these exact transformations:

```ts
const dtoReexpressions = [
  {
    from: 'backend/src/tasks/dto/create-task.dto.ts',
    to: 'backend/src/onboarding/dto/import-local-task.dto.ts',
    oldClass: 'CreateTaskDto',
    newClass: 'ImportLocalTaskDto',
    sourceSha256:
      '9960bc6d618a5f3cb03a7491375842ab73e4fe2e9c4db884b3f24743b0745e6a',
    targetSha256:
      'e7a74a721f87e17a08ecf2a0210fb5f14874e9f371f3a16ea1c862402098b189',
  },
  {
    from: 'backend/src/guests/dto/create-guest.dto.ts',
    to: 'backend/src/onboarding/dto/import-local-guest.dto.ts',
    oldClass: 'CreateGuestDto',
    newClass: 'ImportLocalGuestDto',
    sourceSha256:
      '3efce4297de98e74a80e0158d5b005172728a32def420bc7de3a3ed4ee1068a6',
    targetSha256:
      'cfeab752387affdb8c55f61431ad3e08a8016258877f83c619c71bac22e43582',
  },
];
```

The behavior test compares normalized validation errors for these task cases:

```ts
[
  { title: 'مهمة' },
  { title: '', status: 'INVALID', priority: 'INVALID' },
  { title: 'مهمة', responsibleSource: 'deviceContact' },
  { title: 'مهمة', responsibleSource: 'unknown' },
]
```

and these guest cases:

```ts
[
  { name: 'ضيف' },
  { name: '', seatsCount: 0, companionsCount: -1 },
  { name: 'ضيف', seatsCount: 20, companionsCount: 20 },
  { name: 'ضيف', phone: '1'.repeat(41), side: 'INVALID' },
]
```

Normalize errors recursively to `{ property, constraints, children }` before
comparison so class names do not mask a validation difference.

- [ ] **Step 2: Run tests and confirm RED because local DTOs are absent**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/import-local-plan-dto-contract.test.ts
```

Expected: FAIL only because the two local DTO modules do not exist.

- [ ] **Step 3: Create `ImportLocalTaskDto` by one exact class rename**

The file content is the complete current `CreateTaskDto` source with only this
declaration changed:

```ts
export class ImportLocalTaskDto {
```

All imports and properties remain:

```ts
title!: string;
description?: string | null;
dueDate?: string | null;
taskCategory?: string | null;
responsibleName?: string | null;
responsiblePhone?: string | null;
responsibleSource?: string | null;
reminderAt?: string | null;
status?: WeddingTaskStatus;
priority?: WeddingTaskPriority;
```

with the original decorators in their original order. Verify the target hash is
`e7a74a721f87e17a08ecf2a0210fb5f14874e9f371f3a16ea1c862402098b189`.

- [ ] **Step 4: Create `ImportLocalGuestDto` by one exact class rename**

The file content is the complete current `CreateGuestDto` source with only:

```ts
export class ImportLocalGuestDto {
```

All original decorators and these properties remain unchanged:

```ts
name!: string;
phone?: string | null;
groupId?: string | null;
side?: GuestSide;
status?: GuestStatus;
invitationStatus?: GuestInvitationStatus;
attendanceStatus?: GuestAttendanceStatus;
seatsCount?: number;
companionsCount?: number;
notes?: string | null;
```

Verify the target hash is
`cfeab752387affdb8c55f61431ad3e08a8016258877f83c619c71bac22e43582`.

- [ ] **Step 5: Rewire `ImportLocalPlanDto` to its local constructors**

Replace only the two imports and four constructor/type references:

```ts
import { ImportLocalGuestDto } from './import-local-guest.dto';
import { ImportLocalTaskDto } from './import-local-task.dto';

@Type(() => ImportLocalTaskDto)
tasks?: ImportLocalTaskDto[];

@Type(() => ImportLocalGuestDto)
guests?: ImportLocalGuestDto[];
```

Do not change cost/payment DTOs, array limits, decorators, comments, or the
external property names `tasks` and `guests`.

- [ ] **Step 6: Subtract only the two DTO-reuse records and activate strict**

Remove exact IDs `21` and `22` from the 11-record stage baseline. Set R12B
manifest stage to `strict`. Verify:

```text
entry=16 retired=7 live=9 added=0 unexpectedRemoved=0
ownership=385/781 unchanged=true
```

- [ ] **Step 7: Run focused DTO, Planning, and architecture GREEN gates**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/import-local-plan-dto-contract.test.ts `
  test/backend-support.test.ts `
  test/financial-ledger.test.ts
node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check
npx tsc --noEmit
```

Expected: PASS with R12B `stage=strict, dependency=9,
ownership=385/781`; no Onboarding source import contains `/guests/dto/` or
`/tasks/dto/`.

- [ ] **Step 8: Independent Task 3 review checkpoint**

Reviewer verifies exact transformed hashes, decorator/type parity, nested
constructor behavior, external payload parity, exact two-row subtraction, and
no shared/public DTO workaround. Required verdict `0/0/0`.

---

### Task 4: Integrate The Cumulative Architecture And Prisma-Security Handoff

**Files:**

- Modify: `backend/package.json`
- Modify: `backend/scripts/security/prisma-config-merge-security.cjs`
- Modify: `backend/test/prisma-config-merge-security.test.ts`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Modify: `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r3-scope.test.ts`
- Read only: `backend/test/architecture-r4-planning-finance-boundary.test.ts`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/test/architecture-r6-sharing-otp-transport.test.ts`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify: `backend/test/architecture-r8-global-module-removal.test.ts`
- Modify: `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
- Never modify: `backend/package-lock.json`

**Interfaces:**

- Produces package script `architecture:r12b` and appends it once to
  `architecture`.
- Produces `projectR12BArchitectureScripts` in the Prisma security checker.
- Produces a successor projection that historical fixtures use only when the
  exact R12B manifest is present.
- Preserves every historical stage count and negative selection.


- [ ] **Step 0: Complete the owner-approved inverse-contract correction checkpoint**

This is a Task 4 prerequisite, not a new product phase. The owner approved the
two-findings correction on 2026-09-03. Read the corresponding design revision.
Independent plan review must approve this step before implementation; independent
code review must approve it before Step 1. Keep Tasks 1-3 implementation intact.

Correction-only file ownership:
- Modify this existing plan and its existing design to specify the correction.
- Modify `backend/architecture/r12b-planning-public-contracts.json`.
- Modify `backend/scripts/architecture/r12b-planning-public-contracts-scan.cjs`.
- Modify `backend/test/architecture-r12b-planning-public-contracts.test.ts`.
- Modify only schema fixture construction in
  `backend/test/architecture-r12b-documentation-transition.test.ts` if required.
- Reports/snapshots/briefs remain in this plan's ignored SDD directory.
- Do not edit historical scanner/security/package targets during this checkpoint.

**0.1 — Preserve the pre-correction state and review the written amendment.**

Use `task-4-correction-entry-snapshot.json` (six exact path/hash/base64 rows) and
the prior `task-4-entry-snapshot.json` (19 paths) as comparison evidence; neither
is permission to overwrite user changes. Current stage remains strict/9,
ownership 385/781, documentation entry/0. The 65-row predecessor ledger and
original R12A manifest stay unchanged. Review the corrected design and this plan
at Critical 0 / Important 0 / Minor 0 before changing the schema or scanner.

**0.2 — Write two independent RED contracts before implementation.**

Use the existing `projectFixture`, `forwardSharedTransforms`, and
`finalizeR12bPathContracts` test I/O helpers. First capture the missing final-hash
check on the old schema with this real projection test:

```ts
test('R12B rejects a changed file with the wrong registered final hash', () => {
  const api = scanner();
  const manifest = strictProjection(loadManifest());
  const fixture = projectFixture(manifest);
  forwardSharedTransforms(manifest, fixture.files);
  const inverse = manifest.inverseTransforms.find(
    (item: any) => item.path === 'backend/scripts/architecture/r5-identity-scan.cjs',
  );
  inverse.intendedFinalSha256 = 'f'.repeat(64);
  assert.notEqual(hashBytes(fixture.files.get(inverse.path)!), inverse.intendedFinalSha256);
  finalizeR12bPathContracts(manifest, fixture.files);
  assert.throws(() => api.projectR12bWorkingTreeToPredecessor({
    repositoryRoot, manifest, statusRows: fixture.statusRows,
    readWorkingFile: (relative: string) => fixture.files.get(relative),
    pathExists: (relative: string) => fixture.files.has(relative),
  }), /final.*hash|hash.*final/i);
});
```

Record the expected missing-exception failure. Then add hand-derived replay
tests using the production helper (not the fixture forward builder):

```ts
test('R12B replays separated insertion, replacement and deletion with byte offsets', () => {
  const entry = Buffer.from('a=1;\r\nb=2;\r\n', 'utf8');
  const final = Buffer.from('أ\na=7;\r\n', 'utf8');
  const inverse = {
    path: 'backend/scripts/architecture/r5-identity-scan.cjs',
    entrySha256: hashBytes(entry),
    kind: 'bounded-hunk-replay',
    payload: {
      entryByteLength: 12,
      hunks: [
        { offset: 0, before: '', after: 'أ\n' },
        { offset: 2, before: '1', after: '7' },
        { offset: 6, before: 'b=2;\r\n', after: '' },
      ],
    },
    intendedFinalSha256: hashBytes(final),
  };
  assert.deepEqual(scanner().applyR12bHunkTransform({
    bytes: entry, inverse, direction: 'forward',
  }), final);
  assert.deepEqual(scanner().applyR12bHunkTransform({
    bytes: final, inverse, direction: 'inverse',
  }), entry);
});
```

Add table-driven negative mutations to this literal fixture, preserving an
independently specified expected reject result: offsets -1, 0.5, unsafe integer,
duplicate 0, reversed hunks, overlap at 2, before past entry end, entry length
2097153, empty/sparse/129-element hunks, unknown payload/hunk keys, no-op text,
unpaired surrogate, wrong input/final/entry hash, wrong replacement bytes,
unregistered payload with changed bytes, partial registration, and kind on a
non-handoff path. Include adjacent deletion hunks, unequal replacement lengths,
CRLF, Arabic UTF-8, and insertion inside a UTF-8 sequence (reject malformed
result). Test same-hash declaration with tampered removable/replacement content
at the full projection boundary.

New schema tests require version 2, reject version 1 and the removed kind, and
verify unchanged entry bytes are accepted while pending. Register real hunks and
final hash against an untouched fixture path: forward preregistration must pass,
then exact published final bytes must pass, while unknown edits before or after
publication must fail. No expected value may be generated by the replay helper
under test.

After approved plan/spec changes and test edits, refresh only existing raw
`r12bPaths` hashes and normalized self hash for RED bookkeeping on schema 1.
This is not a baseline regeneration or schema implementation. No architecture
PASS is claimed during doc/hash drift. Run from `backend`:

```powershell
node --test -r ts-node/register test/architecture-r12b-planning-public-contracts.test.ts
```

Record actual RED totals and failures attributable to missing hash enforcement,
new schema or replay behavior, not stale bookkeeping, syntax or dependencies.

**0.3 — Implement the bounded schema and replay, then bind both hashes.**

Keep the existing plain-data, exact-key, duplicate-JSON and safe-path validation.
Require `schemaVersion:2` and exact path-to-kind mapping for all 25 rows.
Migrate only the 15 former insertion-only records to
`kind:'bounded-hunk-replay'`, pending
`payload:{entryByteLength:null,hunks:null}`, and final hash null. Remove the old
kind and its implementation entirely. Add this bounded validator:

```js
function validateR12bHunkPayload(inverse) {
  if (!INVERSE_PATHS.slice(3, 18).includes(inverse.path)
      || inverse.kind !== 'bounded-hunk-replay') {
    throw new Error('R12B hunk path/kind changed');
  }
  exactKeys(inverse.payload, ['entryByteLength', 'hunks'], 'R12B hunk payload');
  const { entryByteLength, hunks } = inverse.payload;
  if (entryByteLength === null || hunks === null) {
    if (entryByteLength !== null || hunks !== null
        || inverse.intendedFinalSha256 !== null) {
      throw new Error('R12B hunk registration is partial');
    }
    return null;
  }
  safeInteger(entryByteLength, 'R12B entry byte length');
  if (entryByteLength > 2097152 || !HASH.test(inverse.entrySha256)
      || !HASH.test(inverse.intendedFinalSha256)) {
    throw new Error('R12B hunk file bounds/hash changed');
  }
  denseArray(hunks, 'R12B hunks', 128);
  if (!hunks.length) throw new Error('R12B hunks are empty');
  let previousOffset = -1;
  let previousEnd = 0;
  let textBytes = 0;
  let finalLength = entryByteLength;
  for (const hunk of hunks) {
    exactKeys(hunk, ['offset', 'before', 'after'], 'R12B hunk');
    safeInteger(hunk.offset, 'R12B hunk offset');
    for (const text of [hunk.before, hunk.after]) {
      if (typeof text !== 'string' || Buffer.from(text, 'utf8').toString('utf8') !== text) {
        throw new Error('R12B hunk text is not exact UTF-8');
      }
    }
    const beforeLength = Buffer.byteLength(hunk.before, 'utf8');
    const afterLength = Buffer.byteLength(hunk.after, 'utf8');
    textBytes += beforeLength + afterLength;
    finalLength += afterLength - beforeLength;
    if (hunk.offset <= previousOffset || hunk.offset < previousEnd
        || hunk.offset > entryByteLength
        || beforeLength > entryByteLength - hunk.offset
        || hunk.before === hunk.after || textBytes > 1048576) {
      throw new Error('R12B hunk ordering/range/text changed');
    }
    previousOffset = hunk.offset;
    previousEnd = hunk.offset + beforeLength;
  }
  if (finalLength < 0 || finalLength > 2097152) {
    throw new Error('R12B hunk final byte length changed');
  }
  return inverse.payload;
}
```

Use this one production helper, consumed by forward preregistration and inverse
reconstruction. Append `applyR12bHunkTransform` immediately after `runCli` in
`module.exports` and in the existing exact ordered `Object.keys(api)` assertion;
retain all previous export names/order and strict equality. This named addition
is the only permitted export-inventory assertion change:

```js
function applyR12bHunkTransform({ bytes, inverse, direction }) {
  // validateR12bHunkPayload is the manifest validator described below.
  const payload = validateR12bHunkPayload(inverse);
  if (!payload || !Buffer.isBuffer(bytes)
      || !['forward', 'inverse'].includes(direction)) {
    throw new Error('R12B hunk replay input is invalid');
  }
  const utf8 = (value) => {
    if (!Buffer.from(value.toString('utf8'), 'utf8').equals(value)) {
      throw new Error('R12B hunk replay requires exact UTF-8');
    }
    return value;
  };
  utf8(bytes);
  let delta = 0;
  const operations = payload.hunks.map((hunk) => {
    const before = Buffer.from(hunk.before, 'utf8');
    const after = Buffer.from(hunk.after, 'utf8');
    const liveOffset = hunk.offset + delta;
    delta += after.length - before.length;
    return direction === 'forward'
      ? { offset: hunk.offset, expected: before, replacement: after }
      : { offset: liveOffset, expected: after, replacement: before };
  });
  const expectedLength = direction === 'forward'
    ? payload.entryByteLength : payload.entryByteLength + delta;
  const expectedHash = direction === 'forward'
    ? inverse.entrySha256 : inverse.intendedFinalSha256;
  if (bytes.length !== expectedLength || sha256(bytes) !== expectedHash) {
    throw new Error('R12B hunk replay input hash or length changed');
  }
  for (const op of operations) {
    if (!bytes.subarray(op.offset, op.offset + op.expected.length)
        .equals(op.expected)) throw new Error('R12B hunk slice changed');
  }
  let result = bytes;
  for (const op of [...operations].reverse()) {
    result = Buffer.concat([
      result.subarray(0, op.offset), op.replacement,
      result.subarray(op.offset + op.expected.length),
    ]);
  }
  utf8(result);
  const resultHash = direction === 'forward'
    ? inverse.intendedFinalSha256 : inverse.entrySha256;
  if (sha256(result) !== resultHash) throw new Error('R12B hunk replay result hash changed');
  return result;
}
```

At the unchanged-entry branch in `projectR12bWorkingTreeToPredecessor`, call
forward replay when a handoff record is registered; leave a pending record
valid only when its live bytes equal the ledger entry. Before every changed
non-documentation inverse (not only hunks), add:

```js
if (currentHash !== inverse.intendedFinalSha256) {
  throw new Error(`R12B predecessor final hash drifted: ${row.path}`);
}
```

Route hunk inverse execution through `applyR12bHunkTransform` and retain the
independent reconstructed entry hash check. Reject old kind/schema inputs; do
not carry both implementations or repurpose package-script transforms.

**0.4 — Keep fixture construction honest and refresh only declared bindings.**

Update schema/kind expectation literals for version 2 and append only the named
helper after `runCli` in the exact export assertion as specified in 0.3. For registered fixture
hunks, construct synthetic final bytes independently from the production replay
helper and set their actual final hashes; a fixture may append simple known
content at an entry byte offset, but must not use a marker parser or mock the
projector. Preserve every existing assertion and negative selection. If the
documentation fixture forces placeholder final hashes on pending records,
remove only that obsolete setup so it uses the real pending null registration;
do not change transition assertions or runner behavior.

Before replacing scanner/test/manifest bytes, prepare intended bytes in ignored
scratch, compute the existing raw path hashes, and refresh the single normalized
self hash. Spec/plan digests now bind this owner-approved revision; their prior
bytes/hashes remain in the correction snapshot and revision note. Do not change
the 11-path registry, the 65-row predecessor, package lock, baseline, product
source, or seven live docs.

**0.5 — Run correction GREEN gates and independent review.**

```powershell
node --test -r ts-node/register test/architecture-r12b-planning-public-contracts.test.ts test/architecture-r12b-documentation-transition.test.ts test/import-local-plan-dto-contract.test.ts test/backend-support.test.ts test/financial-ledger.test.ts
node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check
npx tsc --noEmit
```

Expected: no failure or skip; strict dependency 9, ownership 385/781,
documentation entry with zero receipts. Record exact totals rather than an
expected fixed count. Hash-check the 16 historical/package/security targets against
the Task 4 entry snapshot: zero drift. Exclude only its three R12B governance
rows intentionally changed by this correction. Review the correction implementation and
the reproduced negative case at 0/0/0 before resuming Step 1.

**0.6 — Resume the original Task 4 with preregistered ordinary edits.**

The allowed handoff implementation uses normal import/input/callsite/export
changes represented by the approved hunks. Before initial publication, require
a passing forward/preregistration check while the target is still entry bytes.
For a later RED/GREEN or review revision: verify the previous live file against
the previous registered final hash, prepare and validate the new candidate
against the same immutable entry, register the new hunks/final hash before
publishing those candidate bytes, then rerun the affected gates. A transient
old-file/new-registration mismatch is a closed gate, never a PASS, waiver, or
retroactive hash update. If interrupted, read both hashes and prepared bytes;
publish only a previously prepared and validated candidate or restore only this
task's verified prior registration. Never overwrite unrecognized bytes.

The R12B manifest and its planning-contract test remain allowed bookkeeping and
fixture-support paths during original Task 4, because all changed shared targets
must be preregistered and test fixtures must reconstruct the same immutable
predecessor. No new kinds, paths, assertions waived, or product behavior changes
are authorized beyond this written correction.


- [ ] **Step 1: Add RED tests for package wiring and security projection**

Require exactly:

```ts
const r12bStandaloneScript =
  'node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check';
const r12bArchitectureScript =
  r12aArchitectureScript + ' && npm run architecture:r12b';
```

Tests must reject missing, duplicated, renamed, prefixed, attacker, or wrong
aggregate R12B script keys, including raw and Unicode-escaped duplicate JSON
members. Projecting R12B away must reproduce the exact valid R12A package graph
and then the pinned R6 package fingerprint. The normalized Prisma security lock
fingerprint remains
`46ba2e49c063229aa498112f735f09f7538d6b1e01a0986fec57643d02b586bf`.

- [ ] **Step 2: Add RED historical/live successor tests**

For R3/R5/R6/R7/R8/R12A, test both cases:

```text
fixture without R12B manifest -> historical R12A strict dependency 16
fixture with exact R12B strict manifest -> live dependency 9
```

Reject wrong predecessor SHA, eighth retirement, count 8/10, ownership drift,
invalid default-root resolution, and a copied/fallback `.git` fixture.

- [ ] **Step 3: Run the focused governance tests and confirm RED**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/prisma-config-merge-security.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r3-scope.test.ts `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r6-sharing-otp-transport.test.ts `
  test/architecture-r7-collaboration-relocation.test.ts `
  test/architecture-r8-global-module-removal.test.ts `
  test/architecture-r12a-backoffice-catalog-public-contracts.test.ts `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/architecture-r12b-documentation-transition.test.ts
```

Expected: new successor/package assertions fail while existing historical tests
remain green.

- [ ] **Step 4: Wire the exact package scripts**

Add to `backend/package.json`:

```json
"architecture:r12b": "node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check"
```

Set aggregate `architecture` to the current command followed by exactly:

```text
 && npm run architecture:r12b
```

Do not run an install and do not change `package-lock.json`.

- [ ] **Step 5: Add the fail-closed Prisma security projector**

Implement and export:

```js
const R12B_ARCHITECTURE_SCRIPT =
  R12A_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12b';
const R12B_STANDALONE_SCRIPT =
  'node scripts/architecture/r12b-planning-public-contracts-scan.cjs --check';

function projectR12BArchitectureScripts(value) {
  assertDeepPlainData(value);
  const packageJson = plainRecord(value);
  const scripts = plainRecord(ownValue(packageJson, 'scripts'));
  const keys = Object.keys(scripts).filter((key) =>
    key.startsWith('architecture:r12b'));
  if (keys.length !== 1
      || keys[0] !== 'architecture:r12b'
      || ownValue(scripts, 'architecture:r12b') !== R12B_STANDALONE_SCRIPT
      || ownValue(scripts, 'architecture') !== R12B_ARCHITECTURE_SCRIPT) fail();
  const projectedScripts = { ...scripts };
  delete projectedScripts['architecture:r12b'];
  projectedScripts.architecture = R12A_ARCHITECTURE_SCRIPT;
  return projectR12AArchitectureScripts({
    ...packageJson,
    scripts: projectedScripts,
  });
}
```

Make `checkPrismaConfigMergeSecurity` project R12B first. Earlier projectors
must detect a validated R12B layer and delegate upward rather than treat it as
an unknown package mutation.

- [ ] **Step 6: Add the optional exact successor projection to historical scanners**

Use one named helper in the R12A scanner:

```js
function expectedR12aSuccessorDependencyRecords({
  repositoryRoot,
  r12aEntryRecords,
  r12aManifest,
  readImmutableFile,
}) {
  const r12aRecords = expectedR12aDependencyRecords(
    r12aEntryRecords,
    r12aManifest,
  );
  const r12bPath = path.join(
    repositoryRoot,
    'backend',
    'architecture',
    'r12b-planning-public-contracts.json',
  );
  if (!fs.existsSync(r12bPath)) return r12aRecords;
  const r12b = require('./r12b-planning-public-contracts-scan.cjs');
  const manifest = r12b.validateR12bManifest(
    JSON.parse(fs.readFileSync(r12bPath, 'utf8')),
  );
  return r12b.expectedR12bDependencyRecords(r12aRecords, manifest);
}
```

The production implementation must also use the existing bounded JSON reader,
safe-path checks, exact predecessor SHA, and injected immutable reader; the
snippet defines control flow, not permission to use unbounded `JSON.parse`.
R3/R5/R6/R7/R8 live baseline checks call this helper. Their historical fixtures
without R12B continue to receive 16.

- [ ] **Step 7: Run cumulative architecture and security GREEN gates**

```powershell
Set-Location backend
node --test -r ts-node/register `
  test/prisma-config-merge-security.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/architecture-r3-scope.test.ts `
  test/architecture-r4-planning-finance-boundary.test.ts `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r6-sharing-otp-transport.test.ts `
  test/architecture-r7-collaboration-relocation.test.ts `
  test/architecture-r8-global-module-removal.test.ts `
  test/architecture-r12a-backoffice-catalog-public-contracts.test.ts `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/architecture-r12b-documentation-transition.test.ts
npm run security:prisma-config-merge
npm run architecture
```

Expected: all tests PASS; R12B strict reports dependency 9 and ownership
385/781; all historical negative selections remain green; security preserves
the pinned package/lock graph.

- [ ] **Step 8: Verify the lock and protected surfaces are byte-identical**

```powershell
Set-Location D:\projects\aarast-modular-monolith
$protectedPatterns = @(
  'backend/package-lock.json',
  'backend/prisma/**',
  'mobile/**',
  'admin-web/**',
  'deploy/**',
  'Dockerfile',
  'Dockerfile.*',
  'docker-compose.yml',
  'docker-compose.yaml',
  'compose.yml',
  'compose.yaml',
  '**/Dockerfile',
  '**/Dockerfile.*',
  '**/docker-compose.yml',
  '**/docker-compose.yaml',
  '**/compose.yml',
  '**/compose.yaml',
  '**/*dokploy*'
)
$trackedProtected = @(
  git diff --name-only -- $protectedPatterns
  git diff --cached --name-only -- $protectedPatterns
) | Sort-Object -Unique
$untracked = git ls-files --others --exclude-standard
$untrackedProtected = $untracked | Where-Object {
  $_ -eq 'backend/package-lock.json' -or
  $_ -like 'backend/prisma/*' -or
  $_ -like 'mobile/*' -or
  $_ -like 'admin-web/*' -or
  $_ -like 'deploy/*' -or
  $_ -match '(^|/)(Dockerfile(?:\..*)?|docker-compose\.ya?ml|compose\.ya?ml)$' -or
  $_ -match '(?i)dokploy'
}
if ($trackedProtected -or $untrackedProtected) { throw 'Protected surface drift' }
(Get-FileHash -Algorithm SHA256 backend/package-lock.json).Hash.ToLower()
```

Expected tracked and untracked protected sets empty and raw lock hash
`30bd3b228b763b3bbe895554a71623465e9717409c71266dbdff41e4c079cf0b`.
The separate normalized security fingerprint remains
`46ba2e49c063229aa498112f735f09f7538d6b1e01a0986fec57643d02b586bf`.

- [ ] **Step 9: Independent Task 4 review checkpoint**

Reviewer attacks duplicate keys, package projection, predecessor identity,
historical fixture selection, and current live projection. Required verdict
Critical `0`, Important `0`, Minor `0` before the full test phase.

---

### Task 5: Run Full Behavior, Architecture, Build, Security, And Smoke Gates

Before restarting Task 5 from Step 1, the sole approved security prerequisite
changes `backend/package-lock.json` raw SHA-256 from
`30bd3b228b763b3bbe895554a71623465e9717409c71266dbdff41e4c079cf0b` to
`650bc45c00cd3cdf8298e33570481bb969fdbae78a63167cca9f8ff243b25f60`.
Its only semantic lock delta is the existing `node_modules/qs` entry from
`6.15.3` to `6.16.0`; `package.json`, Nest, Express, body-parser, dependency
debt, ownership, and Product Logic remain unchanged. The lock remains a
protected path. Task 4's lock-freeze hashes and checks above are historical
pre-prerequisite evidence and are not rewritten or reused as current Task 5
evidence. Every Task 5/6 scope receipt must report
`approvedSecurityPrerequisite=1 unapprovedProtected=0`; a second protected
change remains a failure.

**Files:**

- Read only: all existing `backend/test/**` and `backend/scripts/smoke/**` files
  not explicitly listed for modification in Tasks 1-4.
- Modify only: the exact R12B governance/test files already declared in Tasks
  1-4, and only when Task 5 proves an R12B implementation defect.
- Create: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-5-report.md`
- Create: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-5-review-package.md`
- Create after review: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-5-review.md`

**Interfaces:**

- Consumes: strict R12B source and cumulative governance from Tasks 1-4.
- Produces: one exact-state verification receipt with command, exit code,
  pass/fail/skip count, and remaining uncertainty for every gate.
- Any failure in an existing test or smoke that is not a declared path-only
  rewrite stops R12B and requires a separate owner-approved remediation plan;
  Task 5 must not edit the failing historical test or smoke to obtain green.

- [ ] **Step 1: Run focused behavior and architecture tests from `backend`**

```powershell
node --test -r ts-node/register `
  test/architecture-r12b-planning-public-contracts.test.ts `
  test/architecture-r12b-documentation-transition.test.ts `
  test/import-local-plan-dto-contract.test.ts `
  test/backend-support.test.ts `
  test/financial-ledger.test.ts
```

Expected: PASS with no skip. Record exact totals.

- [ ] **Step 2: Run cumulative architecture, check, and build**

```powershell
npm run architecture
npm run check
npm run build
```

Expected: all exit 0; dependency 9; ownership 385/781; cycles, illegal edges,
`forwardRef()`, and project-owned globals remain zero.

- [ ] **Step 3: Run Prisma security and both dependency audits**

```powershell
npm run security:prisma-config-merge
npm audit --audit-level=high
npm audit --omit=dev --audit-level=high
```

Expected: security PASS, vulnerabilities 0, and no package or lock mutation
during this gate; the lock already matches the exact approved prerequisite
receipt above.

- [ ] **Step 4: Run the complete Backend test suite**

```powershell
npm test
```

Expected: exit 0, failures 0, no new skip. The known pre-existing Windows skip
may remain one; any additional skip stops the phase.

- [ ] **Step 5: Run the affected managed smokes**

Run serially from `backend`:

```powershell
npm run smoke:wedding-plan
npm run smoke:onboarding-active-plan
npm run smoke:dashboard-summary
npm run smoke:marketplace
npm run smoke:providers-quotes
npm run smoke:provider-dashboard
npm run smoke:phase2-marketplace-write-concurrency
npm run smoke:phase2-provider-dashboard-concurrency
npm run smoke:phase2-task-guest-permission-concurrency
```

Expected: every package PASS. These cover the location read/normalization paths,
Onboarding/Planning, Marketplace, Provider Dashboard, and task/guest contract
surfaces touched by the refactor.

- [ ] **Step 6: Run all managed smokes**

```powershell
npm run smoke:all
```

Expected: every managed smoke package PASS. Record the exact package count from
the command rather than copying the previous R12A count.

- [ ] **Step 7: Re-prove exact debt, ownership, scope, and protected surfaces**

The receipt must include:

```text
dependency entry=16 retired=7 live=9 added=0 unexpectedRemoved=0
ownership entry=385/781 live=385/781 byteIdentical=true
location legacy=0 public=1 declaredConsumers=7
onboarding taskGuestDeepImports=0 localDtos=2
documentation stage=entry receipts=0 transitionArtifacts=0
staged=0 approvedSecurityPrerequisite=1 unapprovedProtected=0 unexpectedPaths=0
```

Use `git diff --cached --name-only`, `git diff --name-only`, and
`git ls-files --others --exclude-standard`; do not infer scope from `git status`
directory summaries.

- [ ] **Step 8: Write the exact Task 5 report and review package**

Record every command, exit code, exact test/smoke totals, hashes, identity,
changed-path classification, protected output, known skip, and remaining risks.
State explicitly that no phone, Git integration, deployment, production,
provider, or release activity occurred.

- [ ] **Step 9: Independent Task 5 review and remediation loop**

Reviewer independently reruns the strict scanner, focused tests, security gate,
historical negative selections, exact scope/debt/ownership checks, and samples
the affected smokes. Any finding is reproduced and fixed at its earliest source,
then all affected gates restart. Exit only at Critical `0`, Important `0`,
Minor `0`.

---

### Task 6: Synchronize Documentation And Close R12B Locally

#### Owner-approved final-report contract correction — 2026-09-07

Before receipt 3, execute the separately reviewed correction plan at
`.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-6-final-report-contract-correction-plan.md`
from the exact live `candidate` / two-receipt state. Its implementation surface
is limited to the R12B scanner, both R12B architecture tests, the active spec,
this active plan, and the manifest's five corresponding raw registrations plus
normalized self. Prepare the exact final report outside the repository but do
not publish it during correction.

The tests own, literally and independently from scanner output, the stage
mapping `entry/0`, `candidate-prepared/1`, `candidate/2`,
`activation-prepared/3`, and `activated/4`. Each test file independently embeds
or deterministically reconstructs the exact registered seven entry, seven
candidate, and seven activated documentation byte sets, proving path order,
length, UTF-8 round-trip, and every SHA-256 before use. Every case gets a clean
temporary root and receipt prefix. The transition fixture and standalone
`docs/SCRIPTS.md` generator oracle must not consume live candidate documentation
as entry authority.

The exact final report path is:

```text
docs/superpowers/reports/2026-09-02-modular-monolith-r12b-planning-public-contracts-report.md
```

It is absent in all four pre-activated stages. At `activated` it is required as
one real plain file with exactly one Git status row `{ status: '??', path:
<exact literal> }`. It remains outside all R12B path registries. Missing,
duplicate, wrong-status, similar, suffixed, alternate-directory, nested,
renamed, directory, symlink, and supported reparse-point variants fail closed.
All five documentation stages must project exactly seven documentation records
with seven unique paths.

Prepare final bytes and hashes for scanner, both tests, spec, and plan before
any publication. Publish the manifest first with changes to exactly those five
raw hashes plus normalized self, preserving stage `candidate`, both receipts,
all fourteen document hashes, 25 inverse transforms, 11 path contracts, and all
other values. Then publish spec, plan, and both tests while the old scanner
remains live. Accept RED only when the exact activated report is rejected as
undeclared, the directory/link/reparse diagnostic is not reached because the
old classifier rejects first, and non-entry projection exposes 14 details.

GREEN changes only the preregistered scanner: add one exact literal constant;
enforce zero report rows before activation and exactly one `??` row plus the
existing `inspectPlainFile` boundary at activation; bypass the general
undeclared loop only for exact path equality after those checks; and remove only
the earlier duplicate documentation append. Run both complete test files
separately and combined, `architecture:r12b`, aggregate `architecture`,
`check`, `build`, exact scope/state, and six independent scratch mutations with
fail `0` and skip `0`.

Write the ignored correction entry state, report, review package, and progress
evidence, but do not write the independent correction review. Stop for fresh
implementation review at Critical `0`, Important `0`, Minor `0`; then require a
separate candidate re-review before receipt 3. No correction implementation may
append receipt 3/4, publish the report, start R12C, change Product Logic,
packages, generator, baselines, other tests, Git state, deployment, production,
provider, phone, remote CI, or release state.

#### Owner-approved generated `docs/SCRIPTS.md` correction — 2026-09-06

Candidate registration uses one path-specific relationship. For each of the
six narrative targets, candidate bytes must differ from entry and activated
bytes must differ from candidate. For generated `docs/SCRIPTS.md` alone,
candidate bytes must differ from entry and activated bytes must equal candidate
bytes. Equality is forbidden for every other path.

Before invoking the live runner, both outside-repository mirrors must run
`node scripts/docs-sync.mjs --check` successfully with unchanged Backend and
Admin package metadata. The two canonical `docs/SCRIPTS.md` byte sequences and
SHA-256 hashes must be equal to each other and different from the registered
entry hash. No hand edit of the generated file, package churn, skipped docs
gate, general exception, new CLI option, receipt change, Product Logic,
baseline/debt change, R12C work, or Git/deployment activity is authorized.

**Files:**

- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Generate: `docs/SCRIPTS.md`
- Create: `docs/superpowers/reports/2026-09-02-modular-monolith-r12b-planning-public-contracts-report.md`
- Create: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-6-report.md`
- Create: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-6-review-package.md`
- Create after review: `.superpowers/sdd/2026-09-02-modular-monolith-r12b-planning-public-contracts/task-6-review.md`

**Interfaces:**

- Consumes: approved Task 5 exact-state evidence only.
- Produces: a truthful local-completion receipt at dependency 9 and ownership
  385/781.
- Produces: the stop boundary allowing only separate R12C design/planning after
  owner approval.

- [ ] **Step 1: Prepare and register both documentation states before writing**

Create a task-specific temporary mirror outside the repository from existing
tracked/untracked files (`git ls-files -co --exclude-standard`), excluding `.git`
and ignored dependencies. Do not edit the seven live documentation targets yet.
In that mirror, prepare candidate versions and run its
`node scripts/docs-sync.mjs`. Preserve the exact candidate bytes for:

```text
ARCHITECTURE.md
CHANGELOG.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/README.md
docs/SCRIPTS.md
```

Create a second temporary rendering from those candidate bytes, change only the
bounded completion wording to the activated wording defined in Step 5, run its
`docs-sync.mjs` again, and preserve the exact activated bytes. Compute SHA-256
for both versions of all seven paths.

Before publishing any of those bytes, invoke the transition runner. It computes
and registers the exact `entrySha256`, `candidateSha256`, and
`activatedSha256`, verifies the empty entry chain, appends receipt 1, and derives
`documentationStage=candidate-prepared`:

```powershell
$manifestSha = (Get-FileHash -Algorithm SHA256 `
  backend/architecture/r12b-planning-public-contracts.json).Hash.ToLower()
node backend/scripts/architecture/r12b-documentation-transition.cjs `
  --to candidate-prepared `
  --expected-manifest-sha256 $manifestSha `
  --candidate-root $candidateRoot `
  --activated-root $activatedRoot
npm --prefix backend run architecture:r12b
```

Expected: PASS while live documentation still matches the entry hashes. Tests
must reject missing hashes, hashes registered after live-byte drift, an illegal
state jump, and candidate/activated fixture bytes that do not match the
registered values.

The prepared candidate bytes must say:

```text
R12B is a verified local-completion candidate.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation has not begun.
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.
```

Before the independent review, label the receipt `Verified Candidate`; the
sentence `R12B is complete locally.` is forbidden until Step 5 activates it.

- [ ] **Step 2: Publish the exact candidate bytes and verify reconstruction**

Use the runner to publish exactly the seven already-hashed candidate files from
the temporary rendering, append receipt 2, and derive
`documentationStage=candidate`. Do not regenerate or edit live files directly:

```powershell
$manifestSha = (Get-FileHash -Algorithm SHA256 `
  backend/architecture/r12b-planning-public-contracts.json).Hash.ToLower()
node backend/scripts/architecture/r12b-documentation-transition.cjs `
  --to candidate `
  --expected-manifest-sha256 $manifestSha `
  --prepared-root $candidateRoot
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
npm --prefix backend run architecture:r12b
git diff --check
```

Expected: drift 0, errors 0, warnings 0, diff check PASS. `docs/SCRIPTS.md` is
generator-owned and must list `architecture:r12b`. The R12B scanner must prove
all seven candidate hashes, the exact two-receipt prefix, no transition
journal/backups/temporaries, and reconstruction of the complete 65-row
predecessor.

If a runner invocation fails or the process is interrupted, do not edit the
manifest, receipts, journal, backups, or live docs manually. Invoke only the
runner's `--recover` mode; it must either restore the previous verified state or
finish the already-recorded publication, then remove all transaction artifacts.
Restart the affected step and its tests after recovery.

- [ ] **Step 3: Run the exact final scope and identity classifier**

Classify every tracked/untracked/deleted path against:

```text
preserved R11 paths
preserved R12A paths
approved R12B design/plan/report paths
approved R12B Backend implementation/governance/test paths
approved active narrative/generated docs
```

Require missing 0, unexpected 0, staged 0,
`approvedSecurityPrerequisite=1`, `unapprovedProtected=0`, and exact
root/branch/HEAD.
Require documentation receipt count 2 and no transition artifacts. Record exact
path counts from the live state; do not predetermine the final total.

- [ ] **Step 4: Independent candidate review**

The reviewer reads the spec, plan, all task reports/reviews, live diff,
dependency/ownership ledgers, scanners, behavior tests, full verification, docs,
scope, and identity. Required verdict Critical `0`, Important `0`, Minor `0`.

- [ ] **Step 5: Activate bounded local-completion wording**

Only after approval, re-render the seven activated files outside the repository
and require every SHA-256 to equal the already-registered `activatedSha256`.
While live files still contain candidate bytes, use the runner to append receipt
3 and derive `documentationStage=activation-prepared`. On PASS, use the runner
again to publish the exact activated bytes, append receipt 4, and derive
`documentationStage=activated`. The runner does not publish the final report.
Immediately after receipt 4, publish with `apply_patch` the exact report bytes
prepared and hash-recorded before the correction preregistration. Require one
real plain file and exactly one `??` status row at the literal report path before
the first activated strict scan:

```powershell
$manifestSha = (Get-FileHash -Algorithm SHA256 `
  backend/architecture/r12b-planning-public-contracts.json).Hash.ToLower()
node backend/scripts/architecture/r12b-documentation-transition.cjs `
  --to activation-prepared `
  --expected-manifest-sha256 $manifestSha `
  --prepared-root $activatedRoot
npm --prefix backend run architecture:r12b
$manifestSha = (Get-FileHash -Algorithm SHA256 `
  backend/architecture/r12b-planning-public-contracts.json).Hash.ToLower()
node backend/scripts/architecture/r12b-documentation-transition.cjs `
  --to activated `
  --expected-manifest-sha256 $manifestSha `
  --prepared-root $activatedRoot
# Publish the preregistered exact final-report bytes here using apply_patch.
# Verify its prepared SHA-256, plain-file type, and sole ?? status row.
npm --prefix backend run architecture:r12b
```

Expected: receipt 4 exists before report publication; then the exact report is
published once and the strict scanner PASSes at `documentationStage=activated`
before any later final gate. An activated strict scan before the report exists,
or a pre-activated scan with the report present, must fail closed.

The activated wording changes `Verified Candidate` to `Local Completion` and
states that R12B—not the architecture target—is complete locally. Do not add a
Git, deployment, phone, or release claim. Any reviewer-driven documentation
change invalidates the prepared hashes and restarts Step 1 before publication;
post-hoc hash registration is forbidden.

- [ ] **Step 6: Rerun exact-state docs, scope, identity, and diff gates**

```powershell
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
npm --prefix backend run architecture:r12b
git diff --check
git diff --cached --name-only
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
```

Expected: all gates unchanged and staging empty. The activated scanner pass must
prove all seven activated hashes, the exact four-receipt chain, absence of every
transition artifact, and reconstruction of the complete 65-row predecessor.

- [ ] **Step 7: Independent activated exact-state re-review**

The same or another independent reviewer verifies the activated wording and
repeats docs/scope/identity/protected/debt/ownership checks. Close R12B only at
Critical `0`, Important `0`, Minor `0`, textual contradictions `0`.

- [ ] **Step 8: Stop at the R12B boundary**

Do not stage or commit. Do not begin R12C. Report that the next permitted work
is R12C design/planning only after separate owner approval.

---

## Plan Self-Review Receipt

- Spec coverage: Tasks 1-6 cover composite entry, seven exact debts, one-to-one
  location move, seven consumers/tests, two local DTOs, cumulative/history and
  security handoff, full behavior/smoke gates, docs, scope, and independent
  exact-state review.
- Completeness scan: every task has concrete files, interfaces, commands,
  expected outcomes, failure boundaries, and a review checkpoint; no unfinished
  marker or unnamed test step is permitted.
- Type consistency: `ImportLocalTaskDto`, `ImportLocalGuestDto`,
  `validateR12bManifest`, `expectedR12bDependencyRecords`,
  `validateR12bDocumentationTransitions`,
  `verifyR12bLocationSourceParity`, `verifyR12bConsumerParity`,
  `verifyR12bDtoParity`, `scanR12bPlanningPublicContracts`, and the transition
  runner exports use the same names in all producing and consuming tasks.
- Scope decomposition: R12B is one testable dependency-removal phase. R12C and
  ownership phases remain separate and are not absorbed.
- Git exception: commit steps required by the generic skill are intentionally
  omitted because repository and owner instructions forbid Git mutation in this
  planning/implementation line until separately authorized.

## Execution Handoff

Recommended execution is **Subagent-Driven Development**: one fresh implementer
per task, a specification-compliance review, then a code-quality review before
the next task. Inline execution remains possible only if the owner explicitly
chooses it. Neither mode begins until this plan receives independent review and
the owner separately authorizes R12B source implementation.
