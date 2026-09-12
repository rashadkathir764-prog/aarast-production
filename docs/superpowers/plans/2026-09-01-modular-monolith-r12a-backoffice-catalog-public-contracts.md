# R12A Backoffice/Catalog Public Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire dependency records 1-6 by moving five executable Backoffice and Marketplace contracts to their owner-public slices, reducing the dependency baseline from 22 to 16 while preserving ownership at 385/781 and changing no behavior.

**Architecture:** Move each implementation once, delete its legacy path, and update every consumer to the owner-public path. A new R12A manifest/scanner enforces ordered `design -> backoffice -> strict` projections, while additive handoffs let R3-R8 preserve their immutable historical evidence and validate the exact live projection. No DI port, facade, re-export, duplicate, fallback, compatibility layer, constructor change, or Nest module change is introduced.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6, Node.js architecture scanners/tests, dependency-cruiser, PowerShell on Windows.

**Spec:** `docs/superpowers/specs/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-design.md`

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch `modular-monolith`.
- Immutable R10/application base is `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`.
- Preserve the existing R11 nine-Markdown overlay; it is not R12A application work.
- Entry dependency baseline is exactly 22 records with SHA-256 `cdb119fd3670913a6ad61940ecc811ddb257e5c23790ce43f345062a23128990`.
- Entry ownership baseline is exactly 385 records / 781 occurrences with SHA-256 `56e48f6a5fbe7c50cccef7568de52e999585e35f937e45a229d86305e6d2edb5`.
- R12A retires dependency records 1-6 only: `22 -> 17 -> 16`; never regenerate the dependency baseline.
- Ownership never decreases in R12A. Project only the one approved `admin-mutation-gate.ts` path and keep `385/781`.
- Preserve route paths/methods, guards and their order, permissions, DTOs, responses, exact errors, transactions, row-lock order, Arabic, schema, migrations, seed, packages, and lock files.
- Existing behavioral tests may change only import declarations or exact moved-path literals. Do not change names, setup, fixtures, mocks, assertions, expected values, Arabic/error literals, or timeouts.
- Architecture tests may add exact handoff assertions; never delete or weaken a historical R3-R8 assertion.
- Do not add a PublicModule, Symbol/DI provider, constructor argument, `forwardRef()`, `@Global()`, facade, re-export, duplicate implementation, fallback, alias, or compatibility layer.
- Do not change Mobile, Admin Web, Docker, Compose, Dokploy, runtime configuration, provider delivery, deployment, remote CI, or store release.
- This plan does not authorize Git changes. Do not commit, push, merge, branch, checkout, reset, or create a worktree without separate owner authorization.
- Stop on any unlisted diff, count drift, new dependency/ownership record, behavioral test edit beyond path/import, or need for R12B/R12C/R16/R17 source work.

---

## File Structure And Responsibilities

### New R12A governance

- `backend/architecture/r12a-backoffice-catalog-public-contracts.json`
  - immutable entry identity, ordered stages, six dependency keys, five moves,
    export inventories, consumer inventory, one ownership projection, exact
    exception retirement, and expected counts.
- `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
  - validates manifest schema, stage projection, files/exports/imports,
    dependency and ownership identity, exception state, guard order, and scope;
    exports handoff helpers consumed by historical scanners.
- `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
  - positive stage fixtures and negative mutation cases for all R12A laws.

### Moved runtime contracts

- `backend/src/modules/backoffice/public/admin.guard.ts`
- `backend/src/modules/backoffice/public/admin-permission.decorator.ts`
- `backend/src/modules/backoffice/public/admin-permission.guard.ts`
- `backend/src/modules/backoffice/public/admin-mutation-gate.ts`
- `backend/src/modules/marketplace/public/provider-review-rating.ts`

Each has one responsibility and retains the corresponding legacy file's body.
The five source paths under `backend/src/admin/` or
`backend/src/marketplace/` are deleted.

### Historical handoff surfaces

- `backend/scripts/architecture/r3-context-scan.cjs`
- `backend/architecture/r3-context-boundaries.json`
- `backend/test/architecture-r3-contexts.test.ts`
- `backend/test/architecture-r3-scope.test.ts`
- `backend/scripts/architecture/r5-identity-scan.cjs`
- `backend/test/architecture-r5-identity-relocation.test.ts`
- `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- `backend/test/architecture-r6-sharing-otp-transport.test.ts`
- `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- `backend/test/architecture-r7-collaboration-relocation.test.ts`
- `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- `backend/test/architecture-r8-global-module-removal.test.ts`
- `backend/test/architecture-dependencies.test.ts`
- `backend/test/architecture-ports.test.ts`

Historical constants and evidence remain. Only the validated R12A live
projection is added.

### Fixed application consumers

- `backend/src/admin/admin-audit.controller.ts`
- `backend/src/admin/admin.controller.ts`
- `backend/src/admin/admin-user-status.ts`
- `backend/src/admin/admin-mutation-executor.ts`
- `backend/src/catalogs/catalogs.controller.ts`
- `backend/src/catalogs/administrative-catalog.service.ts`
- `backend/src/catalogs/reference-catalog.service.ts`
- `backend/src/marketplace/marketplace.service.ts`
- `backend/src/modules/identity/internal/profile/users.service.ts`

### Exact ledgers and exceptions

- `backend/.dependency-cruiser-known-violations.json`
- `backend/architecture/ownership-baseline.json`
- `backend/.dependency-cruiser.cjs`
- `backend/scripts/architecture/ports-scan.cjs`
- `backend/package.json`

### Direct behavioral test path updates

- `backend/test/admin-auth-session-security.test.ts`
- `backend/test/admin-rbac-audit.test.ts`
- `backend/test/admin-mutation-authorization.test.ts`
- `backend/test/provider-rating-atomicity.test.ts`

Run-only regression tests that must not be edited:

- `backend/test/admin-mutation-gate-runtime.test.ts`
- `backend/test/reference-catalogs.test.ts`

### Completion documentation

- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `docs/README.md`
- `docs/SCRIPTS.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md`
- Create:
  `docs/superpowers/reports/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-report.md`

---

### Task 1: Freeze Entry Truth And Add The R12A Design-Stage Gate

**Files:**

- Create: `backend/architecture/r12a-backoffice-catalog-public-contracts.json`
- Create: `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`
- Create: `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/package.json`
- Modify: `docs/SCRIPTS.md` (generator-owned output only)

**Interfaces:**

- Consumes: immutable application base `4d0d3ee...`, dependency entry
  `22`, ownership entry `385/781`, and the six keys from the spec.
- Produces:
  - `validateR12aManifest(value)`;
  - `dependencyKey(record)`;
  - `expectedR12aDependencyRecords(entryRecords, manifest)`;
  - `expectedR12aOwnershipBaseline(entryBaseline, manifest)`;
  - `normalizeR12aIdentityProviderRatingImport(source, manifest)`;
  - `verifyR12aSourceParity({ historicalSource, liveSource, move })`;
  - `verifyR12aLiteralParity({ historicalSource, liveSource, contract })` for
    every declared consumer and behavioral test, including zero-rewrite
    `run-only` contracts whose raw hash must remain identical;
  - `isAllowedR12aRuntimePublicEdge({ sourcePath, targetPath, importedNames, stage }, manifest)`;
  - `scanR12aBackofficeCatalogPublicContracts({ repositoryRoot, manifest })`;
  - CLI `node scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs --check`;
  - exact R5 security package-script projection for one R12A command before
    the unchanged R8-to-R6 historical projection.

- [ ] **Step 1: Reconfirm the exact dirty-tree entry without editing**

Run from repository root:

```powershell
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git status --short
Get-FileHash backend/.dependency-cruiser-known-violations.json -Algorithm SHA256
Get-FileHash backend/architecture/ownership-baseline.json -Algorithm SHA256
```

Expected:

- root is `D:\projects\aarast-modular-monolith`;
- branch is `modular-monolith`;
- HEAD is `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`;
- existing R11 changes are the six modified and three untracked Markdown paths;
- this approved spec and plan are the only additional untracked paths;
- baseline hashes match Global Constraints.

Stop on any other path or identity.

- [ ] **Step 2: Write failing R12A manifest and scanner contract tests**

Create the test with these exact positive stage counts:

```ts
const expectedStages = {
  design: { dependencyRecords: 22, ownershipRecords: 385, ownershipOccurrences: 781 },
  backoffice: { dependencyRecords: 17, ownershipRecords: 385, ownershipOccurrences: 781 },
  strict: { dependencyRecords: 16, ownershipRecords: 385, ownershipOccurrences: 781 },
} as const;
```

Add tests that reject:

```ts
[
  'unknown manifest key',
  'stage skipped from design to strict input state',
  'duplicate or seventh retired dependency key',
  'dependency count other than 22, 17, or 16',
  'ownership count or occurrence change',
  'second ownership projection',
  'changed ownership record semantics or count',
  'legacy and public target both present',
  'legacy facade or re-export',
  'wrong public export inventory',
  'moved implementation body or undeclared import changed',
  'runtime Backoffice-public to Identity-public import',
  'Identity-to-Marketplace runtime edge with wrong source, target, name, or stage',
  'guard order change',
  'unapproved source consumer',
  'consumer executable bytes changed beyond the declared import rewrite',
  'behavioral test changed beyond the declared path or import rewrite',
  'run-only behavioral test raw hash changed by any byte',
  'consumer or test rewrite references an unknown move id',
  'inactive-stage rewrite applied early or active-stage rewrite left stale',
  'old behavioral literal is only a substring of the active new literal',
  'removed sibling provider-access-policy exception',
]
```

Use fixture files under an OS temporary directory. Do not write fixtures into
the repository and do not follow symlinks/reparse points.

Also extend the R5 security test with a cloned proposed package object that
contains the exact `architecture:r12a` standalone and aggregate commands.
Require it to reach the immutable R5 package fingerprint only after the exact
R12A pre-projection. Add failures for a changed standalone command, aggregate
order drift, missing standalone/aggregate counterpart, any
`architecture:r12a:*` sibling, duplicate, or change to R3-R8.

- [ ] **Step 3: Run the new test and verify RED**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts test/architecture-r5-identity-relocation.test.ts
```

Expected: FAIL because the R12A manifest/scanner and exact R5 R12A package
projection do not exist. Pre-existing R5 cases remain green; only the new
proposed-package case is RED.

- [ ] **Step 4: Create the strict-schema manifest in `design` stage**

Write this complete manifest contract verbatim. The only value changed by later
tasks is top-level `stage`; no executor invents a nested key or value:

```json
{
  "schemaVersion": 1,
  "phase": "R12A",
  "stage": "design",
  "repository": {
    "rootName": "aarast-modular-monolith",
    "branch": "modular-monolith",
    "baseCommit": "4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1"
  },
  "entry": {
    "dependencyRecords": 22,
    "dependencySha256": "cdb119fd3670913a6ad61940ecc811ddb257e5c23790ce43f345062a23128990",
    "ownershipRecords": 385,
    "ownershipOccurrences": 781,
    "ownershipSha256": "56e48f6a5fbe7c50cccef7568de52e999585e35f937e45a229d86305e6d2edb5"
  },
  "stages": {
    "design": {
      "activeMoveIds": [],
      "retiredDependencyIds": [],
      "dependencyRecords": 22,
      "ownershipProjectionActive": false,
      "runtimePublicEdgeActive": false
    },
    "backoffice": {
      "activeMoveIds": ["B1", "B2", "B3", "B4"],
      "retiredDependencyIds": [2, 3, 4, 5, 6],
      "dependencyRecords": 17,
      "ownershipProjectionActive": true,
      "runtimePublicEdgeActive": false
    },
    "strict": {
      "activeMoveIds": ["B1", "B2", "B3", "B4", "M1"],
      "retiredDependencyIds": [1, 2, 3, 4, 5, 6],
      "dependencyRecords": 16,
      "ownershipProjectionActive": true,
      "runtimePublicEdgeActive": true
    }
  },
  "dependencyRecords": [
    {
      "id": 1,
      "type": "dependency",
      "from": "src/admin/admin-mutation-executor.ts",
      "to": "src/marketplace/provider-review-rating.ts",
      "unresolvedTo": "../marketplace/provider-review-rating",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-backoffice-cross-context" }
    },
    {
      "id": 2,
      "type": "dependency",
      "from": "src/catalogs/administrative-catalog.service.ts",
      "to": "src/admin/admin-mutation-gate.ts",
      "unresolvedTo": "../admin/admin-mutation-gate",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-catalog-cross-context" }
    },
    {
      "id": 3,
      "type": "dependency",
      "from": "src/catalogs/catalogs.controller.ts",
      "to": "src/admin/admin-permission.decorator.ts",
      "unresolvedTo": "../admin/admin-permission.decorator",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-catalog-cross-context" }
    },
    {
      "id": 4,
      "type": "dependency",
      "from": "src/catalogs/catalogs.controller.ts",
      "to": "src/admin/admin-permission.guard.ts",
      "unresolvedTo": "../admin/admin-permission.guard",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-catalog-cross-context" }
    },
    {
      "id": 5,
      "type": "dependency",
      "from": "src/catalogs/catalogs.controller.ts",
      "to": "src/admin/admin.guard.ts",
      "unresolvedTo": "../admin/admin.guard",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-catalog-cross-context" }
    },
    {
      "id": 6,
      "type": "dependency",
      "from": "src/catalogs/reference-catalog.service.ts",
      "to": "src/admin/admin-mutation-gate.ts",
      "unresolvedTo": "../admin/admin-mutation-gate",
      "dependencyTypes": ["local", "import"],
      "rule": { "severity": "error", "name": "context-catalog-cross-context" }
    }
  ],
  "moves": [
    {
      "id": "B1",
      "owner": "backoffice",
      "from": "backend/src/admin/admin.guard.ts",
      "to": "backend/src/modules/backoffice/public/admin.guard.ts",
      "entrySha256": "7b0af6a63c11d68ac8322083146a8e6df034a4244574707f4ed34dac0e115420",
      "runtimeExports": ["AdminGuard"],
      "typeExports": [],
      "importRewrites": [
        { "importedNames": ["AuthenticatedUser"], "oldModule": "../modules/identity/public/identity-session.types", "newModule": "../../identity/public/identity-session.types", "oldTypeOnly": false, "newTypeOnly": true }
      ]
    },
    {
      "id": "B2",
      "owner": "backoffice",
      "from": "backend/src/admin/admin-permission.decorator.ts",
      "to": "backend/src/modules/backoffice/public/admin-permission.decorator.ts",
      "entrySha256": "ace0cee2b39428563e465f85419edef4810ebbfa7e2ecf6f6ca17a0a26a60d18",
      "runtimeExports": ["ADMIN_PERMISSIONS_KEY", "RequireAdminPermission"],
      "typeExports": [],
      "importRewrites": [
        { "importedNames": ["AdminPermission"], "oldModule": "../modules/backoffice/domain/admin-permissions", "newModule": "../domain/admin-permissions", "oldTypeOnly": false, "newTypeOnly": false }
      ]
    },
    {
      "id": "B3",
      "owner": "backoffice",
      "from": "backend/src/admin/admin-permission.guard.ts",
      "to": "backend/src/modules/backoffice/public/admin-permission.guard.ts",
      "entrySha256": "85eb85348cd5acdff9766122b2983f1ba67e24caebf2721ddb6aa31d37717628",
      "runtimeExports": ["AdminPermissionGuard"],
      "typeExports": [],
      "importRewrites": [
        { "importedNames": ["AuthenticatedUser"], "oldModule": "../modules/identity/public/identity-session.types", "newModule": "../../identity/public/identity-session.types", "oldTypeOnly": false, "newTypeOnly": true },
        { "importedNames": ["AdminPermission", "hasAdminPermission"], "oldModule": "../modules/backoffice/domain/admin-permissions", "newModule": "../domain/admin-permissions", "oldTypeOnly": false, "newTypeOnly": false }
      ]
    },
    {
      "id": "B4",
      "owner": "backoffice",
      "from": "backend/src/admin/admin-mutation-gate.ts",
      "to": "backend/src/modules/backoffice/public/admin-mutation-gate.ts",
      "entrySha256": "aeb7f07cfdc5e62949ff16e59705c5652fe6e5ea5d28c789f6bd8425c3072c47",
      "runtimeExports": ["authorizeAdminMutationActor", "runAuthorizedAdminMutation"],
      "typeExports": ["AuthorizedAdminMutationActor"],
      "importRewrites": [
        { "importedNames": ["AuthenticatedUser"], "oldModule": "../modules/identity/public/identity-session.types", "newModule": "../../identity/public/identity-session.types", "oldTypeOnly": false, "newTypeOnly": true },
        { "importedNames": ["AdminPermission", "hasAdminPermission"], "oldModule": "../modules/backoffice/domain/admin-permissions", "newModule": "../domain/admin-permissions", "oldTypeOnly": false, "newTypeOnly": false },
        { "importedNames": ["runSerializableTransaction"], "oldModule": "../platform/database/serializable-transaction", "newModule": "../../../platform/database/serializable-transaction", "oldTypeOnly": false, "newTypeOnly": false },
        { "importedNames": ["PrismaService"], "oldModule": "../platform/database/prisma.service", "newModule": "../../../platform/database/prisma.service", "oldTypeOnly": false, "newTypeOnly": false }
      ]
    },
    {
      "id": "M1",
      "owner": "marketplace",
      "from": "backend/src/marketplace/provider-review-rating.ts",
      "to": "backend/src/modules/marketplace/public/provider-review-rating.ts",
      "entrySha256": "870c5c1d5f14b60c67a1b8c7a4f6e4a1689fb196b86754f190cc861d0644e8d1",
      "runtimeExports": ["lockProviderRatingRows", "refreshProviderRating", "runProviderReviewMutation"],
      "typeExports": [],
      "importRewrites": [
        { "importedNames": ["runSerializableTransaction"], "oldModule": "../platform/database/serializable-transaction", "newModule": "../../../platform/database/serializable-transaction", "oldTypeOnly": false, "newTypeOnly": false },
        { "importedNames": ["PrismaService"], "oldModule": "../platform/database/prisma.service", "newModule": "../../../platform/database/prisma.service", "oldTypeOnly": false, "newTypeOnly": false }
      ]
    }
  ],
  "consumers": [
    {
      "path": "backend/src/admin/admin-audit.controller.ts",
      "entrySha256": "d27c162c9a35073d5ad30d14c2f3b76bdacf9cd2a773a541ddbb88f5fec2ce72",
      "importRewrites": [
        { "moveId": "B1", "oldModule": "./admin.guard", "newModule": "../modules/backoffice/public/admin.guard" },
        { "moveId": "B2", "oldModule": "./admin-permission.decorator", "newModule": "../modules/backoffice/public/admin-permission.decorator" },
        { "moveId": "B3", "oldModule": "./admin-permission.guard", "newModule": "../modules/backoffice/public/admin-permission.guard" }
      ]
    },
    {
      "path": "backend/src/admin/admin.controller.ts",
      "entrySha256": "d87439a17d17cf7ab41b8c2c2fb255afa738d2204089a1efe0199f11a33a1756",
      "importRewrites": [
        { "moveId": "B1", "oldModule": "./admin.guard", "newModule": "../modules/backoffice/public/admin.guard" },
        { "moveId": "B2", "oldModule": "./admin-permission.decorator", "newModule": "../modules/backoffice/public/admin-permission.decorator" },
        { "moveId": "B3", "oldModule": "./admin-permission.guard", "newModule": "../modules/backoffice/public/admin-permission.guard" }
      ]
    },
    {
      "path": "backend/src/admin/admin-user-status.ts",
      "entrySha256": "92823daa1f18f7622649245b4bd6edd34f636611b28ae1be6be2eb83abde5554",
      "importRewrites": [
        { "moveId": "B4", "oldModule": "./admin-mutation-gate", "newModule": "../modules/backoffice/public/admin-mutation-gate" }
      ]
    },
    {
      "path": "backend/src/admin/admin-mutation-executor.ts",
      "entrySha256": "05e2b7953e655e38d3eeb9e11ed27270e48ea4d69d23e8dcfbdbb6f81b34385b",
      "importRewrites": [
        { "moveId": "M1", "oldModule": "../marketplace/provider-review-rating", "newModule": "../modules/marketplace/public/provider-review-rating" },
        { "moveId": "B4", "oldModule": "./admin-mutation-gate", "newModule": "../modules/backoffice/public/admin-mutation-gate" }
      ]
    },
    {
      "path": "backend/src/catalogs/catalogs.controller.ts",
      "entrySha256": "ecda61063b728c971973b8faaf612646b0c98e69a6802b6570fc4655e9b2a5b5",
      "importRewrites": [
        { "moveId": "B1", "oldModule": "../admin/admin.guard", "newModule": "../modules/backoffice/public/admin.guard" },
        { "moveId": "B3", "oldModule": "../admin/admin-permission.guard", "newModule": "../modules/backoffice/public/admin-permission.guard" },
        { "moveId": "B2", "oldModule": "../admin/admin-permission.decorator", "newModule": "../modules/backoffice/public/admin-permission.decorator" }
      ]
    },
    {
      "path": "backend/src/catalogs/administrative-catalog.service.ts",
      "entrySha256": "218a2cc4d31b979f7c98e3539fdd5b7f44e859a0264f85ad2a5e8d176ec26341",
      "importRewrites": [
        { "moveId": "B4", "oldModule": "../admin/admin-mutation-gate", "newModule": "../modules/backoffice/public/admin-mutation-gate" }
      ]
    },
    {
      "path": "backend/src/catalogs/reference-catalog.service.ts",
      "entrySha256": "55964faf680975e27a2c09218ea1563107f43a9820f30809927c9c7244f31db0",
      "importRewrites": [
        { "moveId": "B4", "oldModule": "../admin/admin-mutation-gate", "newModule": "../modules/backoffice/public/admin-mutation-gate" }
      ]
    },
    {
      "path": "backend/src/marketplace/marketplace.service.ts",
      "entrySha256": "3f5240cbcebf85fb347abc30169a18ed30830b6ae94f3f8c01bde35d7918dadd",
      "importRewrites": [
        { "moveId": "M1", "oldModule": "./provider-review-rating", "newModule": "../modules/marketplace/public/provider-review-rating" }
      ]
    },
    {
      "path": "backend/src/modules/identity/internal/profile/users.service.ts",
      "entrySha256": "a8edc6ce6264010098842d7a6b7a806eb0a6cf76c2e6e4a5d45a3bf81cfb109c",
      "importRewrites": [
        { "moveId": "M1", "oldModule": "../../../../marketplace/provider-review-rating", "newModule": "../../../marketplace/public/provider-review-rating" }
      ]
    }
  ],
  "behavioralTests": [
    {
      "path": "backend/test/admin-auth-session-security.test.ts",
      "mode": "rewrite",
      "entrySha256": "f05ae5d2d2181ed6964538c5b17348a1d86976e74a2873fe5b4608cd6df9600a",
      "literalRewrites": [
        { "moveId": "B1", "old": "../src/admin/admin.guard", "new": "../src/modules/backoffice/public/admin.guard" },
        { "moveId": "B1", "old": "src/admin/admin.guard.ts", "new": "src/modules/backoffice/public/admin.guard.ts" }
      ]
    },
    {
      "path": "backend/test/admin-rbac-audit.test.ts",
      "mode": "rewrite",
      "entrySha256": "d2f755535cf19aa6a536758266a376d426d376d1933029b69969ed7b37d7c674",
      "literalRewrites": [
        { "moveId": "B3", "old": "../src/admin/admin-permission.guard", "new": "../src/modules/backoffice/public/admin-permission.guard" }
      ]
    },
    {
      "path": "backend/test/admin-mutation-authorization.test.ts",
      "mode": "rewrite",
      "entrySha256": "297ed996333ba54a83370517752669db5a9e5399b3c539f02b6956cd41dadff7",
      "literalRewrites": [
        { "moveId": "B4", "old": "admin-mutation-gate.ts", "new": "../modules/backoffice/public/admin-mutation-gate.ts" }
      ]
    },
    {
      "path": "backend/test/provider-rating-atomicity.test.ts",
      "mode": "rewrite",
      "entrySha256": "e6f1d14dca51e83f94d3d859ada54f5dc638aa74cd521f7e9b32fa8c131b9a35",
      "literalRewrites": [
        { "moveId": "M1", "old": "marketplace/provider-review-rating.ts", "new": "modules/marketplace/public/provider-review-rating.ts" }
      ]
    },
    { "path": "backend/test/admin-mutation-gate-runtime.test.ts", "mode": "run-only", "entrySha256": "b8f0efffea00f0b10b4987ec3beab6e4120268866b0f5f2ace19794dcaaba23d", "literalRewrites": [] },
    { "path": "backend/test/reference-catalogs.test.ts", "mode": "run-only", "entrySha256": "b5c23663064fdff7f4b047ea680cdd95242c5a0def639d110600ae722864c657", "literalRewrites": [] }
  ],
  "runtimePublicEdges": [
    {
      "stage": "strict",
      "source": "backend/src/modules/identity/internal/profile/users.service.ts",
      "target": "backend/src/modules/marketplace/public/provider-review-rating.ts",
      "importedNames": ["lockProviderRatingRows", "refreshProviderRating"],
      "ownerPhase": "R16"
    }
  ],
  "ownershipProjection": {
    "oldKey": "backend/src/admin/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model",
    "newKey": "backend/src/modules/backoffice/public/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model",
    "oldFile": "backend/src/admin/admin-mutation-gate.ts",
    "newFile": "backend/src/modules/backoffice/public/admin-mutation-gate.ts",
    "unchanged": { "context": "backoffice", "owner": "identity", "model": "User", "operation": "select", "mode": "read", "source": "sql", "reason": "foreign-model", "count": 1 }
  },
  "exceptionRetirement": [
    {
      "path": "backend/.dependency-cruiser.cjs",
      "collection": "contextRules",
      "identity": "context-identity-relocated-users-helper-cross-context|src/modules/identity/internal/profile/users.service.ts|src/marketplace/provider-review-rating.ts"
    },
    {
      "path": "backend/scripts/architecture/ports-scan.cjs",
      "collection": "R5_RELOCATED_IDENTITY_PURE_HELPER_EDGES",
      "identity": "backend/src/modules/identity/internal/profile/users.service.ts|backend/src/marketplace/provider-review-rating.ts"
    },
    {
      "path": "backend/scripts/architecture/r3-context-scan.cjs",
      "collection": "relocatedIdentityPureHelpers",
      "identity": "backend/src/modules/identity/internal/profile/users.service.ts->backend/src/marketplace/provider-review-rating.ts"
    }
  ],
  "guardOrder": ["JwtSessionGuard", "AdminGuard", "AdminPermissionGuard"],
  "futureHandoffs": [
    { "phase": "R16", "obligation": "replace the exact Identity-to-Marketplace runtime-public helper edge with the final Marketplace infrastructure/public-port shape" },
    { "phase": "R17", "obligation": "publish the pure Backoffice admin-permissions contract from public, update remaining Auth/Catalog/Identity consumers, and delete the exact R1 pre-port exception before R18" }
  ]
}
```

- [ ] **Step 5: Implement the scanner's pure projection core**

The dependency projection must be equivalent to:

```js
function dependencyKey(record) {
  return [record.rule.name, record.from, record.to].join('|');
}

function expectedR12aDependencyRecords(entryRecords, manifest) {
  const active = manifest.stages[manifest.stage];
  const retired = new Set(active.retiredDependencyIds);
  const byId = new Map(manifest.dependencyRecords.map((record) => [record.id, record]));
  const expectedByKey = new Map(
    [...retired].map((id) => {
      const manifestRecord = byId.get(id);
      if (!manifestRecord) throw new Error(`Unknown R12A dependency id: ${id}`);
      const { id: _id, ...exactEntryRecord } = manifestRecord;
      return [dependencyKey(exactEntryRecord), exactEntryRecord];
    }),
  );
  const seen = new Set();
  const projected = entryRecords.filter((record) => {
    const key = dependencyKey(record);
    if (!expectedByKey.has(key)) return true;
    assert.deepStrictEqual(record, expectedByKey.get(key));
    seen.add(key);
    return false;
  });
  if (seen.size !== expectedByKey.size || projected.length !== active.dependencyRecords) {
    throw new Error('R12A dependency projection is invalid');
  }
  return Object.freeze(projected.map((record) => Object.freeze({ ...record })));
}
```

The strict schema requires each manifest dependency row, after removing only
its R12A `id`, to contain exactly the immutable baseline record keys and nested
values shown above. A matching `rule/from/to` identity with changed
`type`, `unresolvedTo`, `dependencyTypes` membership/order, severity, or extra field
must fail rather than be retired.

The ownership projection must clone the immutable baseline and replace exactly
one record's `key` and `file`, then assert canonical equality with the live
baseline and totals `385/781`. Read immutable entry JSON with:

```js
execFileSync('git', ['show', `${manifest.repository.baseCommit}:${relativePath}`], {
  cwd: repositoryRoot,
  encoding: 'utf8',
  maxBuffer: 16 * 1024 * 1024,
});
```

Use AST parsing for imports/exports, guard arrays, exact import module
specifiers, and exact behavioral-test string-literal nodes. Reject symlinks,
reparse points, duplicate paths, unknown JSON keys, unsafe integers,
non-canonical arrays, and any path escaping the repository.

For source parity, read the historical source with `git show`, verify its raw
hash, and parse historical/live import declarations. Require the live imports
to equal the manifest-declared rewrite set. Replace those declarations with
their exact historical forms, normalize only `CRLF`/`LF`, and compare the
entire normalized source. Do not normalize statements, strings, whitespace,
decorators, SQL, or function/class bodies.

For consumer/test literal parity, every rewrite carries one valid `moveId`.
Resolve the current stage's `activeMoveIds` first. Count consumers by exact
`ImportDeclaration.moduleSpecifier.text` equality and behavioral tests by
exact string-literal node value, never by substring search. An active rewrite
must have the exact historical node count at its `newModule`/`new` value and
zero exact nodes at its old value; an inactive rewrite must retain the exact
historical old-node count and have zero exact new nodes. Normalize only active
AST node ranges back to their exact historical raw text, normalize line
endings, and compare the entire file to the immutable hashed source. This
makes the two rewrites in `admin-mutation-executor.ts` independently
stage-aware: `B4` is active at `backoffice`, while `M1` remains historical
until `strict`. It also treats `admin-mutation-gate.ts` and
`../modules/backoffice/public/admin-mutation-gate.ts` as distinct exact string
literals even though one text is a suffix of the other.
For a `run-only` contract, do not normalize or rewrite anything: require the
live raw SHA-256 to equal its immutable `entrySha256` exactly.

- [ ] **Step 6: Make `design` stage prove the untouched entry**

At `design`, require:

- all five legacy files exist and targets do not;
- every legacy file raw hash equals its manifest `entrySha256`;
- dependency baseline canonical-equals immutable entry 22;
- ownership baseline canonical-equals immutable entry 385/781;
- the six dependency identities match manifest rows;
- the provider-rating exception exists in all three approved locations;
- no R12A source consumer already imports a target path.

- [ ] **Step 7: Add the exact R5 package handoff and wire the additive command**

Keep `R5_SECURITY_PACKAGE_JSON_SHA256`, `R5_ARCHITECTURE_SCRIPT`, and every
existing R6-R8 constant/projection unchanged. Add only:

```js
const R12A_ARCHITECTURE_SCRIPT =
  R8_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12a';
const R12A_STANDALONE_SCRIPT =
  'node scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs --check';
```

At the start of `projectR6ArchitectureScriptsForR5Security`, after cloning
`projectedScripts` and before the existing R8 logic, accept and remove only the
exact R12A standalone/aggregate pair:

```js
const r12aScriptKeys = Object.keys(projectedScripts)
  .filter((scriptName) => scriptName.startsWith('architecture:r12a'));
const hasR12aAggregateIdentity = typeof projectedScripts.architecture === 'string'
  && projectedScripts.architecture.includes('architecture:r12a');
if (r12aScriptKeys.length > 0 || hasR12aAggregateIdentity) {
  if (r12aScriptKeys.length !== 1
      || r12aScriptKeys[0] !== 'architecture:r12a'
      || projectedScripts['architecture:r12a'] !== R12A_STANDALONE_SCRIPT
      || projectedScripts.architecture !== R12A_ARCHITECTURE_SCRIPT) {
    throw new Error('R5 security R12A architecture delegation is invalid');
  }
  delete projectedScripts['architecture:r12a'];
  projectedScripts.architecture = R8_ARCHITECTURE_SCRIPT;
}
```

Then execute the unchanged R8, R7, and R6 projections and compare the same
historical package hash. Do not replace that hash with an R12A-era hash.

Add:

```json
"architecture:r12a": "node scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs --check"
```

Append `&& npm run architecture:r12a` after `architecture:r8` in the existing
`architecture` script. Do not reorder or remove earlier gates.

From the repository root run `node scripts/docs-sync.mjs` immediately after
the package edit. Require its only generated diff to be `docs/SCRIPTS.md` with
the exact standalone/aggregate script inventory above; do not hand-edit it.

- [ ] **Step 8: Run Task 1 tests and design-stage gate**

Run:

```powershell
node scripts/docs-sync.mjs --check
Set-Location backend
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts test/architecture-r5-identity-relocation.test.ts
npm run architecture:r5
npm run architecture:r12a
```

Expected: PASS with `stage=design, dependency=22, ownership=385/781`.

- [ ] **Step 9: Review Task 1 before continuing**

Verify the diff contains governance files, package script wiring, and only the
generator-owned `docs/SCRIPTS.md` update. No application source, baseline,
exception, behavioral test, package-lock, or other documentation file change
belongs to Task 1. `docs-sync --check` must already be green before Task 2.

---

### Task 2: Add Exact R12A Handoffs To Historical R3-R8 Gates

**Files:**

- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r3-scope.test.ts`
- Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs`
- Modify: `backend/test/architecture-r6-sharing-otp-transport.test.ts`
- Modify: `backend/scripts/architecture/r7-collaboration-relocation-scan.cjs`
- Modify: `backend/test/architecture-r7-collaboration-relocation.test.ts`
- Modify: `backend/scripts/architecture/r8-global-module-removal-scan.cjs`
- Modify: `backend/test/architecture-r8-global-module-removal.test.ts`

**Interfaces:**

- Consumes: validated R12A manifest and pure helpers from Task 1.
- Produces: R3-R8 gates that retain immutable historical checks and accept only
  the manifest-declared live 22/17/16 projection.

- [ ] **Step 1: Write RED tests for cumulative handoff behavior**

Add these assertions before scanner edits:

```ts
assert.equal(historicalDependencyRecords, 22);
assert.equal(liveDependencyRecordsAtBackoffice, 17);
assert.equal(liveDependencyRecordsAtStrict, 16);
assert.equal(liveOwnershipRecords, 385);
assert.equal(liveOwnershipOccurrences, 781);
```

For every historical suite, add a mutation test proving a seventh retirement
or a changed historical constant fails. For R5, add two sources:

```ts
const importOnly = historicalUsersService.replace(
  '../../../../marketplace/provider-review-rating',
  '../../../marketplace/public/provider-review-rating',
);
const behaviorChanged = importOnly.replace('await refreshProviderRating', 'return refreshProviderRating');
```

Require import-only normalization to pass and `behaviorChanged` to fail.

Add R5/R7 ownership fixtures that begin from the immutable R7 ownership
projection, apply the one manifest `ownershipProjection`, sort by `key`, and
require `385/781`. Add failures for an in-place unsorted edit, a second path
projection, changed semantic field/count, and removal of the original R7
handoff.

- [ ] **Step 2: Run the historical suites and verify RED**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r3-contexts.test.ts test/architecture-r3-scope.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts
```

Expected: new R12A handoff tests FAIL while all pre-existing cases still pass.

- [ ] **Step 3: Add R3 move-aware path projection**

Keep R3 immutable path evidence. Add a validated live projection that maps
only these four paths when stage is `backoffice` or `strict`:

```js
const backofficeMoves = new Map([
  ['backend/src/admin/admin.guard.ts', 'backend/src/modules/backoffice/public/admin.guard.ts'],
  ['backend/src/admin/admin-permission.decorator.ts', 'backend/src/modules/backoffice/public/admin-permission.decorator.ts'],
  ['backend/src/admin/admin-permission.guard.ts', 'backend/src/modules/backoffice/public/admin-permission.guard.ts'],
  ['backend/src/admin/admin-mutation-gate.ts', 'backend/src/modules/backoffice/public/admin-mutation-gate.ts'],
]);
```

Update the live R3 manifest inventory by exact 1:1 path projection; do not
delete an expected provider, controller, permission, or context assertion.

Add one separate manifest-driven law for the strict-stage runtime-public edge:

```js
const legalR12aRuntimePublicEdge = isAllowedR12aRuntimePublicEdge({
  sourcePath: repositoryPath,
  targetPath,
  importedNames: [...importedNames].sort(),
  stage: r12aManifest.stage,
}, r12aManifest);
```

Include it in the existing cross-context decision without weakening any other
branch. It may return true only for
`modules/identity/internal/profile/users.service.ts` to
`modules/marketplace/public/provider-review-rating.ts`, only for the two exact
imported names, and only at `strict`. Add near-miss tests for an extra imported
name, another Identity source, another Marketplace target, and `design` or
`backoffice` stage.

- [ ] **Step 4: Add R5 import-only source normalization**

Import `normalizeR12aIdentityProviderRatingImport` from the R12A scanner. Keep
the historical SHA-256 constant. At `strict`, normalize only this literal:

```text
../../../../marketplace/provider-review-rating
```

from live source back to the historical literal after first proving the live
source contains the exact new literal once and the old literal zero times. Hash
the normalized source and require the existing historical hash. Any other byte
change must fail.

- [ ] **Step 5: Add exact 22/17/16 projection to R6 and R7**

Replace direct live `length === 22` assumptions with:

```js
const expected = expectedR12aDependencyRecords(historicalR7Live22, r12aManifest);
assertCanonicalEqual(liveDependency, expected, 'R12A live dependency handoff');
```

Do not change R6/R7 historical base counts, retired R7 keys, or immutable
hashes. The R12A manifest must be strict-schema validated before its stage is
trusted.

- [ ] **Step 6: Add the canonical R12A ownership handoff to R5/R7**

Keep `expectedOwnershipBaseline()` and every original R7 historical projection.
After R7 has produced its expected live baseline, apply the R12A projection
only when `ownershipProjectionActive` is true:

```js
function applyR12aOwnershipProjection(ownership, manifest) {
  if (!manifest.stages[manifest.stage].ownershipProjectionActive) return ownership;
  const expected = structuredClone(ownership);
  const projection = manifest.ownershipProjection;
  const index = expected.violations.findIndex((record) => record.key === projection.oldKey);
  if (index < 0 || expected.violations.some((record) => record.key === projection.newKey)) {
    throw new Error('R12A ownership projection source identity is invalid');
  }
  expected.violations[index] = {
    ...expected.violations[index],
    key: projection.newKey,
    file: projection.newFile,
  };
  expected.violations.sort((left, right) => (
    left.key < right.key ? -1 : left.key > right.key ? 1 : 0
  ));
  return expected;
}
```

Validate all fields against `projection.unchanged` before replacement. Require
the complete live ownership JSON to equal this result, not merely its counts.
R5 historical tests continue to prove the original R7 handoff; an additive
R12A test proves the second projection and canonical sort. Do not change an R7
semantic hash or historical move.

- [ ] **Step 7: Add exact live projection to R8 without changing its phase evidence**

Split R8 counts into historical and live fields:

```js
const EXPECTED_HISTORICAL_COUNTS = Object.freeze({
  dependencyRecords: 22,
  ownershipRecords: 385,
  ownershipOccurrences: 781,
});
```

The live dependency count comes from the validated R12A stage projection.
Ownership remains exactly `385/781`; globals, cycles, providers, and
`forwardRef()` retain current exact values. R8 consumes the same canonical
ownership result from Step 6 and compares the complete baseline before
reducing it to counts. A manifest claiming 16 without the six exact retired
keys or 385/781 without the exact sorted path projection must fail.

- [ ] **Step 8: Run historical and R12A suites**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r3-contexts.test.ts test/architecture-r3-scope.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
npm run architecture:r3
npm run architecture:r5
npm run architecture:r6
npm run architecture:r7
npm run architecture:r8
npm run architecture:r12a
```

Expected at untouched source: every command PASS; R12A remains `design/22`.

- [ ] **Step 9: Review Task 2 before application moves**

Confirm every original historical constant is still present and tested. Reject
any diff that merely changes a hard-coded `22` to `16`, replaces an old hash,
removes a negative test, or bypasses a scanner.

---

### Task 3: Move Backoffice Public Contracts And Reach Dependency 17

**Files:**

- Create: `backend/src/modules/backoffice/public/admin.guard.ts`
- Create: `backend/src/modules/backoffice/public/admin-permission.decorator.ts`
- Create: `backend/src/modules/backoffice/public/admin-permission.guard.ts`
- Create: `backend/src/modules/backoffice/public/admin-mutation-gate.ts`
- Delete: `backend/src/admin/admin.guard.ts`
- Delete: `backend/src/admin/admin-permission.decorator.ts`
- Delete: `backend/src/admin/admin-permission.guard.ts`
- Delete: `backend/src/admin/admin-mutation-gate.ts`
- Modify: `backend/src/admin/admin-audit.controller.ts`
- Modify: `backend/src/admin/admin.controller.ts`
- Modify: `backend/src/admin/admin-user-status.ts`
- Modify: `backend/src/admin/admin-mutation-executor.ts`
- Modify: `backend/src/catalogs/catalogs.controller.ts`
- Modify: `backend/src/catalogs/administrative-catalog.service.ts`
- Modify: `backend/src/catalogs/reference-catalog.service.ts`
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/architecture/ownership-baseline.json`
- Modify: `backend/architecture/r12a-backoffice-catalog-public-contracts.json`
- Modify: `backend/test/admin-auth-session-security.test.ts`
- Modify: `backend/test/admin-rbac-audit.test.ts`
- Modify: `backend/test/admin-mutation-authorization.test.ts`
- Test only (do not modify): `backend/test/admin-mutation-gate-runtime.test.ts`
- Test only (do not modify): `backend/test/reference-catalogs.test.ts`

**Interfaces:**

- Consumes: Task 1 scanner and Task 2 handoffs in `design` state.
- Produces: four real Backoffice public runtime contracts, seven updated source
  consumers, dependency 17, ownership 385/781 with one path projection, and
  R12A `backoffice` stage.

- [ ] **Step 1: Write/extend RED assertions for the Backoffice state**

Require:

```ts
assert.equal(result.stage, 'backoffice');
assert.equal(result.dependencyRecords, 17);
assert.equal(result.ownershipRecords, 385);
assert.equal(result.ownershipOccurrences, 781);
assert.deepEqual(result.legacyPaths, []);
```

Add exact export inventory assertions and negative fixtures for a facade,
duplicate class/function, wrong guard order, runtime Identity public import,
and ownership deletion.

- [ ] **Step 2: Run the Backoffice-stage tests and verify RED**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
```

Expected: Backoffice-stage fixture tests FAIL before the moves.

- [ ] **Step 3: Move the decorator and guards with unchanged bodies**

Create the target files using the old file bodies. Adjust only relative import
paths and make Identity types syntactically type-only:

```ts
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';
```

The permission decorator/guard continues to import
`../domain/admin-permissions` from the Backoffice context. The exact exports
remain:

```ts
export class AdminGuard {}
export const ADMIN_PERMISSIONS_KEY = 'admin_permissions';
export const RequireAdminPermission = (...permissions: AdminPermission[]) =>
  SetMetadata(ADMIN_PERMISSIONS_KEY, permissions);
export class AdminPermissionGuard {}
```

Delete all three old files in the same patch. Do not leave forwarding files.

- [ ] **Step 4: Move the mutation gate with unchanged transaction logic**

Move the complete implementation and adjust only imports. Require:

```ts
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';
```

Preserve the signatures exactly:

```ts
export async function authorizeAdminMutationActor(
  tx: Prisma.TransactionClient,
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
): Promise<AuthorizedAdminMutationActor>;

export async function runAuthorizedAdminMutation<T>(
  prisma: PrismaService,
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
  mutation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T>;
```

Preserve the SQL, `FOR UPDATE`, serializable transaction, check ordering, and
exact forbidden error. Delete the old file in the same patch.

For all four Backoffice moves, run `verifyR12aSourceParity` and require full
source equality after only their manifest-declared import rewrites and EOL
normalization. A changed executable or declarative byte is a hard failure.

- [ ] **Step 5: Update all seven Backoffice/Catalog consumers**

Use owner-local public paths for Backoffice consumers and owner-public paths
for Catalog. Do not change decorator placement, `@UseGuards` ordering, method
bodies, constructor arguments, or module imports.

After editing, run:

```powershell
rg -n -F -e './admin.guard' -e './admin-permission.decorator' -e './admin-permission.guard' -e './admin-mutation-gate' -e '../admin/admin.guard' -e '../admin/admin-permission.decorator' -e '../admin/admin-permission.guard' -e '../admin/admin-mutation-gate' backend/src/admin backend/src/catalogs
```

Expected: zero retired runtime import literals in the seven legacy consumer
locations. The R12A AST scanner still searches all `backend/src` and rejects
any undeclared consumer globally; this focused command intentionally excludes
the valid owner-local `./admin-permission.decorator` import inside the new
Backoffice public slice.

- [ ] **Step 6: Update behavioral tests by import/path literal only**

Change direct imports and source-file literals in
`admin-auth-session-security.test.ts`, `admin-rbac-audit.test.ts`, and
`admin-mutation-authorization.test.ts` to the Backoffice public paths. Do not
edit `admin-mutation-gate-runtime.test.ts` or `reference-catalogs.test.ts`;
they are run-only regression suites. Use `git diff --word-diff` to verify no
test name, fixture, assertion, expected value, error string, setup, mock, or
timeout changed. Run the manifest parity check over all seven Task 3
consumers and the three rewritten behavioral tests. Require the two run-only
test hashes to remain byte-identical.

- [ ] **Step 7: Apply exact dependency and ownership projections**

From the dependency baseline remove records 2-6 only. Keep order and every
other byte semantically unchanged. From the ownership baseline replace:

```text
backend/src/admin/admin-mutation-gate.ts
```

with:

```text
backend/src/modules/backoffice/public/admin-mutation-gate.ts
```

in exactly the `key` and `file` fields of the approved record. Do not change
its remaining fields or any other record. Re-sort the complete `violations`
array lexicographically by `key`; do not leave the replacement at the old
index. R7 and R12A must canonical-compare the complete result and require
exactly `385/781`.

Set manifest stage to `backoffice`.

- [ ] **Step 8: Run focused Backoffice/Catalog verification**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/admin-auth-session-security.test.ts test/admin-rbac-audit.test.ts test/admin-mutation-authorization.test.ts test/admin-mutation-gate-runtime.test.ts test/reference-catalogs.test.ts
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
npm run architecture:imports
npm run architecture:ownership
npm run architecture:ports
npm run architecture:r3
npm run architecture:r5
npm run architecture:r6
npm run architecture:r7
npm run architecture:r8
npm run architecture:r12a
npm run check
```

Expected: PASS; R12A reports `backoffice/17/385/781`.

- [ ] **Step 9: Review Task 3**

Reject the task if any old file exists, any new PublicModule/provider appears,
the baseline is not exact 17, ownership is not exact 385/781, or a behavioral
test changed beyond imports/path literals.

---

### Task 4: Move Marketplace Provider Rating Contract And Reach Strict 16

**Files:**

- Create: `backend/src/modules/marketplace/public/provider-review-rating.ts`
- Delete: `backend/src/marketplace/provider-review-rating.ts`
- Modify: `backend/src/admin/admin-mutation-executor.ts`
- Modify: `backend/src/marketplace/marketplace.service.ts`
- Modify: `backend/src/modules/identity/internal/profile/users.service.ts`
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/.dependency-cruiser.cjs`
- Modify: `backend/scripts/architecture/ports-scan.cjs`
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/architecture/r12a-backoffice-catalog-public-contracts.json`
- Modify: `backend/test/provider-rating-atomicity.test.ts`
- Modify: `backend/test/architecture-dependencies.test.ts`
- Modify: `backend/test/architecture-ports.test.ts`

**Interfaces:**

- Consumes: Task 3 `backoffice/17/385/781` state.
- Produces: Marketplace owner-public rating runtime contract, all three live
  consumers on its public path, exact exception retirement, dependency 16,
  ownership 385/781, and R12A `strict` stage.

- [ ] **Step 1: Write RED strict-state and exception tests**

Require:

```ts
assert.equal(result.stage, 'strict');
assert.equal(result.dependencyRecords, 16);
assert.equal(result.ownershipRecords, 385);
assert.equal(result.ownershipOccurrences, 781);
assert.equal(result.retiredDependencyRecords, 6);
```

Add negative cases for a legacy provider-rating facade, duplicate helper,
stale Identity exception, missing sibling provider-access-policy exception,
wrong function export, changed lock order, and dependency 15/17.

- [ ] **Step 2: Run strict tests and verify RED**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r12a-backoffice-catalog-public-contracts.test.ts test/architecture-dependencies.test.ts test/architecture-ports.test.ts
```

Expected: strict-state tests FAIL before the move.

- [ ] **Step 3: Move provider review rating implementation once**

Create the target with the complete old body and update only relative Platform
imports. Preserve exact signatures:

```ts
export async function lockProviderRatingRows(
  tx: Prisma.TransactionClient,
  providerIds: readonly string[],
): Promise<string[]>;

export async function refreshProviderRating(
  tx: Prisma.TransactionClient,
  providerId: string,
): Promise<boolean>;

export async function runProviderReviewMutation<T>(
  prisma: PrismaService,
  providerId: string,
  mutation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T>;
```

Preserve sorting/deduplication, SQL and `FOR UPDATE`, aggregate filter,
two-decimal average, count, update behavior, serializable transaction,
lock/mutate/refresh ordering, and exact not-found error. Delete the legacy
file in the same patch.

Run `verifyR12aSourceParity` for the Marketplace move and require full source
equality after only manifest-declared import rewrites and EOL normalization.

- [ ] **Step 4: Update all three live consumers**

Update imports in:

- `admin-mutation-executor.ts`;
- `marketplace.service.ts`;
- `modules/identity/internal/profile/users.service.ts`.

Do not change any method body or constructor. The Identity file change must be
the one exact import literal that Task 2's R5 normalization proves.
R3 must also prove that the resulting runtime-public edge matches the exact
manifest source, target, and two imported names; no generic public-helper
exception is permitted.

- [ ] **Step 5: Retire only the provider-rating transitional exceptions**

Remove the exact edge ending in `provider-review-rating.ts` from:

- `.dependency-cruiser.cjs`;
- `ports-scan.cjs`;
- `r3-context-scan.cjs`.

Keep the provider-access-policy sibling unchanged and covered by negative
tests.

- [ ] **Step 6: Remove dependency record 1 and enter strict stage**

Remove only record 1 from the current 17-record dependency baseline. Set the
R12A manifest stage to `strict`. Do not edit the ownership baseline in Task 4.

- [ ] **Step 7: Update provider-rating test path literals only**

Change `provider-rating-atomicity.test.ts` source path/import references. Keep
all assertions proving lock/aggregate/update/transaction ordering unchanged.
Run manifest parity for all three Task 4 consumers and this test after its one
declared literal rewrite; require complete normalized source equality.

- [ ] **Step 8: Run focused Marketplace/Identity and architecture verification**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/provider-rating-atomicity.test.ts test/admin-mutation-gate-runtime.test.ts test/architecture-dependencies.test.ts test/architecture-ports.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
npm run architecture
npm run check
npm run build
```

Expected: all PASS; cumulative architecture ends with
`stage=strict, dependency=16, ownership=385/781`.

- [ ] **Step 9: Search for forbidden residue**

Run:

```powershell
rg -n -F -e './provider-review-rating' -e '../marketplace/provider-review-rating' -e '../../../../marketplace/provider-review-rating' -e 'src/marketplace/provider-review-rating.ts' -e 'backend/src/marketplace/provider-review-rating.ts' backend/src backend/test backend/scripts backend/architecture
rg -n 'forwardRef\(|@Global\(' backend/src
```

Classify intentional historical fixture literals explicitly. Runtime source
must have zero legacy literals; `forwardRef()` and project-owned `@Global()`
remain zero.

---

### Task 5: Run Full R12A Quality Gates

**Files:**

- Test only; no planned source changes.
- If the full test gate exposes a pre-existing harness or security-projection
  consumer made stale by the exact Task 1 package wiring, use the bounded
  remediation plan at
  `docs/superpowers/plans/2026-09-02-modular-monolith-r12a-task5-full-test-remediation.md`.
- If a gate fails, fix only the earliest incorrect file already inside Tasks
  1-4, then rerun the affected gate and this full task from the beginning.

**Interfaces:**

- Consumes: strict R12A candidate at dependency 16 and ownership 385/781.
- Produces: fresh evidence for documentation; no cached or pre-edit result.

- [ ] **Step 1: Prove exact dependency subtraction against immutable base**

Use a read-only Node or PowerShell assertion that loads immutable entry JSON
with `git show`, removes the six manifest keys, and canonical-compares the
result to the live baseline. Expected:

```text
entry=22 retired=6 live=16 added=0 unexpectedRemoved=0
```

- [ ] **Step 2: Prove exact ownership path projection**

Load immutable ownership JSON, replace the one approved key/file path, and
canonical-compare to live. Expected:

```text
entry=385/781 projected=1 live=385/781 added=0 removed=0
```

- [ ] **Step 3: Run every focused behavioral and architecture suite fresh**

Run:

```powershell
Set-Location backend
node --test -r ts-node/register test/admin-auth-session-security.test.ts test/admin-rbac-audit.test.ts test/admin-mutation-authorization.test.ts test/admin-mutation-gate-runtime.test.ts test/provider-rating-atomicity.test.ts test/reference-catalogs.test.ts
node --test -r ts-node/register test/architecture-dependencies.test.ts test/architecture-ports.test.ts test/architecture-r3-contexts.test.ts test/architecture-r3-scope.test.ts test/architecture-r5-identity-relocation.test.ts test/architecture-r6-sharing-otp-transport.test.ts test/architecture-r7-collaboration-relocation.test.ts test/architecture-r8-global-module-removal.test.ts test/architecture-r12a-backoffice-catalog-public-contracts.test.ts
```

Expected: all selected tests PASS with no skipped/filtered test introduced by
R12A.

- [ ] **Step 4: Run complete Backend gates**

Run:

```powershell
Set-Location backend
npm run architecture
npm run check
npm run build
npm test
```

Run the four affected managed smoke suites first, against the same configured
local database and runtime:

```powershell
npm run smoke:reference-catalog
npm run smoke:phase2-admin-mutation-authorization
npm run smoke:phase2-marketplace-write-concurrency
npm run smoke:phase2-provider-rating-concurrency
```

Then run the aggregate managed smoke package:

```powershell
npm run smoke:all
```

Expected: PASS. If the database/runtime prerequisite is unavailable, stop and
report the environmental blocker; do not call R12A complete and do not replace
the smoke with mocks.

- [ ] **Step 5: Verify frozen schema, migrations, seed, packages, and non-Backend surfaces**

Compare against immutable base:

```powershell
git diff --name-only 4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1 -- backend/prisma backend/package-lock.json mobile admin-web docker-compose.yml
```

Expected: no R12A changes. Existing pre-R12A differences must be classified
from the approved overlay; no new difference is allowed.

---

### Task 6: Write The R12A Receipt And Close Locally Without Git Integration

**Files:**

- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/SCRIPTS.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Create: `docs/superpowers/reports/2026-09-01-modular-monolith-r12a-backoffice-catalog-public-contracts-report.md`

**Interfaces:**

- Consumes: Task 5 fresh evidence.
- Produces: truthful R12A local completion receipt and one next permitted
  action after final independent approval: separate R12B design/planning after
  owner approval.

- [ ] **Step 1: Write observed facts only**

Record:

- immutable base and working-tree status;
- exact five moves and nine consumers;
- dependency `22 -> 17 -> 16` with six IDs;
- ownership path projection and unchanged `385/781`;
- exact exception removals;
- generated `docs/SCRIPTS.md` entry for the exact `architecture:r12a` command;
- focused/full test counts and commands exactly as observed;
- smoke result or explicit blocker;
- independent review verdict;
- no API/schema/migration/route/DTO/error/permission/transaction/Arabic/Mobile/
  Admin Web/deployment behavior change;
- no commit, push, merge, deployment, remote CI, provider delivery, or store
  release unless separately performed and proven.

- [ ] **Step 2: Keep future-phase truth explicit**

State:

- dependency baseline remains at 16 for R12B;
- ownership remains 385/781;
- Marketplace Prisma helper remains R16 work;
- Backoffice mutation ownership/layout remains R17 work;
- the exact Identity-to-Marketplace runtime-public helper edge is removed by
  R16 when Marketplace reaches its final infrastructure/public-port shape;
- the R1 `backoffice/domain/admin-permissions.ts` pre-port exception remains
  unchanged in R12A and is owned by R17: R17 publishes the pure contract under
  Backoffice `public/`, updates remaining Auth/Catalog/Identity consumers, and
  deletes the exception before R18;
- R12A does not claim architecture-target completion;
- next action is R12B design/planning only after separate approval.

- [ ] **Step 3: Run documentation and whitespace gates**

Run from repository root:

```powershell
node scripts/docs-sync.mjs
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: the first command is idempotent because Task 1 already generated the
exact `architecture:r12a` inventory; it creates no additional diff. All
following checks PASS. Do not hand-edit the generated table.

- [ ] **Step 4: Run the final scope classifier**

Classify, without renames:

1. immutable R10 application base;
2. the approved R11 nine-Markdown overlay;
3. this R12A spec and plan;
4. exact R12A application/governance/test/docs paths from this plan, including
   the generator-owned `docs/SCRIPTS.md` change caused by `backend/package.json`.

Reject any path outside those sets. Require `git status --short` to show no
staged files and no unrelated modifications.

- [ ] **Step 5: Reconfirm immutable repository identity at final state**

Run:

```powershell
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git diff --cached --name-only
git status --short
```

Expected: root and branch match Global Constraints, HEAD is still
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`, staged output is empty, and
status contains only the classified R11/R12A paths. Stop on drift.

- [ ] **Step 6: Run the final independent review after docs and scope**

Provide the reviewer:

- final spec, plan, completion report, and active documentation;
- immutable base and final identity output;
- complete classified changed-path list;
- exact dependency and canonical ownership projection evidence;
- consumer/test/source parity evidence;
- focused/full test and smoke outputs;
- docs, whitespace, and scope outputs;
- explicit rules against behavior changes, facades, fallbacks, and weakened
  historical gates.

Require review of final source, architecture, transactions, locks,
permissions, all reports/docs, tests, scanner non-bypassability, final scope,
and R16/R17 handoffs. Verdict must be `APPROVED` with no Critical or Important
issue. Resolve valid findings in the earliest owning task, then rerun Tasks 5
and 6 completely before requesting another final review.

- [ ] **Step 7: Stop for owner review**

Report every changed file and PASS/FAIL result. Do not commit, push, merge,
deploy, start R12B, or mutate production. A local R12A commit requires an
explicit separate Git request from the owner.

---

## Final Definition Of Done

R12A may be called locally complete only when all are true:

1. Five implementations exist only under owner `public/` paths and all five
   legacy files are absent.
2. Every fixed consumer imports the owner-public path.
3. Dependency baseline is the immutable entry baseline minus exactly IDs 1-6:
   16 records, no additions, no regeneration.
4. Ownership baseline is the immutable entry baseline after only the one path
   projection: 385 records / 781 occurrences.
5. The provider-rating transitional exception is gone from exactly three
   locations and the provider-access-policy sibling remains.
6. R3-R8 historical evidence remains and their live handoffs accept only the
   exact R12A stage projection.
7. R12A strict scanner proves exact exports, imports, paths, guard order,
   source parity, ownership, exceptions, the one exact runtime-public edge,
   scope, and absence of facades/duplicates/fallbacks.
8. Behavioral tests changed only by import/path literal and all focused tests
   pass unchanged.
9. Full architecture, check, build, tests, four focused managed smokes,
   aggregate managed smoke, docs, scope, identity, and whitespace gates pass
   fresh.
10. Final independent review after completion docs and scope is `APPROVED`
    with no Critical or Important issue.
11. No commit, push, merge, deployment, remote CI, provider delivery, store
    release, R12B, R16, or R17 work occurred without separate authorization.

## Execution Handoff

Plan creation and review do not start implementation. After owner approval,
the recommended execution mode is **Subagent-Driven** using
`superpowers:subagent-driven-development`, one task at a time with
spec-compliance and code-quality review after each task. Inline execution with
`superpowers:executing-plans` is the alternative. In both modes, the plan's no
Git/no deployment boundaries remain binding until separately authorized.
