# R5 Prisma Config Merge Security Checkpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for Tasks 1–2,
> `superpowers:systematic-debugging` for any unexpected failure,
> `superpowers:verification-before-completion` before any readiness claim, and
> `superpowers:requesting-code-review` before the local checkpoint. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `GHSA-ggr8-5vv4-36mx` from the Backend dependency graph without
upgrading or downgrading Prisma, while proving Prisma Config, schema, generated
client, migrations, application behavior, and runtime compatibility.

**Architecture:** Keep Prisma 6.19.3 and force its transitive
`deepmerge-ts` resolution to exact `8.0.1` with an npm override. A permanent
checker proves the declared/locked/installed graph, canonical Prisma resolution,
recursive-graph safety, and real config loading. Existing DMMF, migrations,
architecture, full tests, smokes, audits, and a temporary image probe prove the
major transitive override is safe before one atomic R5 Task 5A checkpoint.

**Tech Stack:** Node.js 22, npm lockfile v3, TypeScript 5.9, NestJS 11, Prisma
6.19.3, `deepmerge-ts` 8.0.1, Node test runner, Docker, PowerShell.

**Spec:**
`docs/superpowers/specs/2026-08-21-r5-prisma-config-merge-security-checkpoint-design.md`

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch
  `modular-monolith`.
- Preserve the current dirty R5 Task 5 candidate on HEAD
  `3a62b257819de0530dd1737934773e2e5fc7fca1`; do not stash, reset, checkout,
  discard, or overwrite it.
- This plan is the sole narrow exception to the R5 package-lock freeze.
- Package changes are limited to exact `deepmerge-ts@8.0.1` resolution and one
  permanent security script. Keep `prisma` and `@prisma/client` on 6.19.3.
- Never run `npm audit fix`, `npm audit fix --force`, or edit `node_modules`.
- Do not modify Backend application source, Prisma schema/config/migrations/
  seed, Mobile, Admin, workflows, Dockerfile, Compose, deployment, or Dokploy.
- Preserve API/DTO/routes/errors/Arabic/OTP/session/transaction behavior.
- No compatibility facade, vendor patch, audit suppression, fallback, or
  skipped/weakened test.
- Do not print environment values, registry credentials, absolute temp paths,
  stack traces, raw Prisma config, or raw container environment/logs.
- Do not cut over the phone runtime. A candidate image may run only on a unique
  probe port and must be removed after verification.
- Planning itself creates no commit. During execution, create the local
  checkpoint only after all gates and independent review, and only under the
  already-approved local Git discipline. No push, merge, PR, deployment,
  remote-CI claim, or R6.

## Expected Final Change Surface

| Action | Path | Responsibility |
| --- | --- | --- |
| Create | `backend/scripts/security/prisma-config-merge-security.cjs` | Permanent declared/locked/installed/runtime security gate |
| Create | `backend/test/prisma-config-merge-security.test.ts` | Unit, adversarial, and live graph regressions |
| Modify | `backend/package.json` | Exact override and permanent npm script |
| Modify | `backend/package-lock.json` | npm-resolved `deepmerge-ts@8.0.1` graph only |
| Modify | `backend/architecture/r5-identity-relocation.json` | Exact Task 5A scope authorization |
| Modify | `backend/test/architecture-r5-identity-relocation.test.ts` | Scope and frozen-package near-misses |
| Modify | `docs/SCRIPTS.md` | Generated script catalog only |
| Modify | `docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md` | Narrow lockfile exception and security gate |
| Modify | `docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md` | Insert Task 5A before Task 5 acceptance |
| Modify | `docs/project/DECISIONS.md` | Accepted temporary override decision and removal condition |
| Modify | `docs/project/STATUS.md` | Evidence-based local result only after PASS |
| Modify | `docs/qa/README.md` | Permanent command and acceptance expectation |
| Modify | `CHANGELOG.md` | Final local security receipt |
| Create ignored | `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-*.md` | RED/GREEN/gates/review evidence |

No other path is authorized. If a required correction needs another path, stop,
document the evidence, amend this design/plan first, and obtain approval before
continuing.

---

### Task 0: Freeze the Existing R5 Candidate and Authorize Task 5A

**Files:**
- Already created by planning:
  `docs/superpowers/specs/2026-08-21-r5-prisma-config-merge-security-checkpoint-design.md`
- Already created by planning:
  `docs/superpowers/plans/2026-08-21-r5-prisma-config-merge-security-checkpoint.md`
- Modify: `backend/architecture/r5-identity-relocation.json`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md`
- Modify: `docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md`
- Create ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-0-report.md`

**Interfaces:**
- Consumes: the exact current dirty Task 5 candidate and its already-passing
  baseline/smoke evidence.
- Produces: an immutable path-and-hash receipt plus a machine-enforced narrow
  exception for this checkpoint.

- [ ] **Step 1: Reconfirm identity and current candidate without mutation**

Run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
git branch --show-current
git rev-parse HEAD
git merge-base --is-ancestor 9dab73acdc187a4a18d8a675713d8ded40a16d02 HEAD
git status --short
git diff --check
```

Expected: branch `modular-monolith`, HEAD
`3a62b257819de0530dd1737934773e2e5fc7fca1`, ancestor exit 0, the known R5
Task 5 paths plus these two planning documents only, and clean whitespace.

- [ ] **Step 2: Capture a before-security path-and-hash receipt**

Use `git status --porcelain=v1 -z` and SHA-256 of every non-ignored candidate
file. Store only repository-relative paths and hashes in the ignored Task 0
report. Record separately:

- current Task 5 path count and aggregate hash;
- current `backend/package.json` hash;
- current `backend/package-lock.json` hash;
- installed `prisma`, `@prisma/client`, `@prisma/config`, and `deepmerge-ts`
  versions;
- current npm audit advisory ID and severity, without copying registry tokens or
  raw npm configuration.

Expected live graph before the fix: Prisma packages 6.19.3 and
`deepmerge-ts@7.1.5` through `@prisma/config`.

- [ ] **Step 3: Add scope-contract RED assertions**

In `backend/test/architecture-r5-identity-relocation.test.ts`, add fixtures that
require the manifest to reject:

```text
backend/package-lock.json changed without the approved security paths
an arbitrary package dependency change
a ranged deepmerge override
a Prisma version change
an extra new implementation path outside the exact checker/test pair
```

Run only the new scope tests before updating the manifest:

```powershell
Set-Location backend
node --test -r ts-node/register `
  --test-name-pattern="R5 Task 5A package security scope" `
  test/architecture-r5-identity-relocation.test.ts
```

Expected: RED because the current manifest does not authorize the exact Task 5A
surface. No product/package edit exists yet.

- [ ] **Step 4: Add the minimal manifest and active-plan exception**

Add exactly these changed paths to `allowedChangedPaths`:

```text
backend/package-lock.json
backend/scripts/security/prisma-config-merge-security.cjs
backend/test/prisma-config-merge-security.test.ts
docs/superpowers/specs/2026-08-21-r5-prisma-config-merge-security-checkpoint-design.md
docs/superpowers/plans/2026-08-21-r5-prisma-config-merge-security-checkpoint.md
```

The other receipt/script paths are already in the R5 allowlist; assert that
fact rather than adding duplicates. Update the active R5 design/plan only to:

- name this Task 5A before Task 5 acceptance;
- replace the absolute package-lock freeze with this exact exception;
- keep every other package/source/deploy surface frozen;
- state the override removal condition;
- keep R6 blocked.

Run the focused scope test again. Expected: GREEN for the exact path set and RED
for every near-miss.

- [ ] **Step 5: Verify planning/docs state**

```powershell
Set-Location ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

At this point `docs-sync --check` may report only the expected future
`docs/SCRIPTS.md` change if the security npm script has already been introduced;
before Task 2 it must be fully green.

Do not commit.

---

### Task 1: Build the Permanent Security Gate and Record the Real RED

**Files:**
- Create: `backend/scripts/security/prisma-config-merge-security.cjs`
- Create: `backend/test/prisma-config-merge-security.test.ts`
- Create ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-1-report.md`

**Interfaces:**
- `validatePackageGraph(packageJson, packageLock)` returns a frozen normalized
  proof or throws one fixed security error.
- `resolveInstalledGraph(options)` proves canonical package identity from the
  `@prisma/config` resolution context.
- `assertMergeBehavior(deepmerge)` proves recursive and ordinary merge behavior.
- `loadRealPrismaConfig(options)` proves actual config loading without exposing
  configuration values.
- `checkPrismaConfigMergeSecurity(options)` combines all four proofs.
- `runCli(options)` supports only `--check`, returns 0/1/2, and emits fixed
  sanitized lines.

- [ ] **Step 1: Write pure graph fixture tests first**

Add table-driven tests for:

```typescript
const patchedPackage = {
  dependencies: {
    prisma: '^6.19.3',
    '@prisma/client': '^6.19.3',
  },
  overrides: { 'deepmerge-ts': '8.0.1' },
};

const patchedLock = {
  lockfileVersion: 3,
  packages: {
    '': { dependencies: patchedPackage.dependencies },
    'node_modules/@prisma/config': {
      version: '6.19.3',
      dependencies: { 'deepmerge-ts': '7.1.5' },
    },
    'node_modules/deepmerge-ts': {
      version: '8.0.1',
      resolved: 'https://registry.npmjs.org/deepmerge-ts/-/deepmerge-ts-8.0.1.tgz',
      integrity: 'sha512-szCXE7YLCvLKR9bFPJcvsezOShdalctSvrgN/LM/QGUEPZQajwjmsMObZ6/DuANT5lxzM/wtO8Feubwdkz8myA==',
    },
  },
};
```

The production validator must accept an injected expected integrity in fixtures;
the live CLI pins the real npm integrity recorded in the generated lockfile.

Reject independently:

- missing, ranged, wrong, or accessor-backed override;
- Prisma/client versions outside 6.19.3;
- lockfile version mismatch;
- vulnerable root or nested copy;
- multiple installed copies;
- missing/changed integrity;
- `file:`, git, URL alias, workspace, or local package substitution;
- proxy/accessor/sparse/cyclic non-plain injected test data;
- unknown keys where the checker requires an exact record.

- [ ] **Step 2: Write canonical installed-resolution tests**

Use injected fake resolver/realpath functions to prove the checker rejects:

- `@prisma/config` resolving a nested 7.x package;
- a same-name fake package;
- a declaration/path substring spoof;
- version 8.0.1 loaded from a path different from the locked canonical package;
- runtime import and package metadata resolving different identities.

The positive fixture resolves one exact package identity from the actual
`@prisma/config`-anchored `createRequire`.

- [ ] **Step 3: Write recursive and ordinary merge behavior tests**

The runtime proof should be equivalent to:

```javascript
const left = { schema: 'prisma/schema' };
left.self = left;
const right = { migrations: { path: 'prisma/migrations' } };
right.self = right;
const merged = deepmerge(left, right);

assert.equal(merged.schema, 'prisma/schema');
assert.equal(merged.migrations.path, 'prisma/migrations');
assert.equal(merged.self, merged);
assert.equal(left.self, left);
assert.equal(right.self, right);
```

Reject `RangeError`, non-termination, a broken cycle, input mutation, missing
fields, or a non-function public API. Run the proof in a child process with a
hard timeout so a regression cannot hang the full test runner.

- [ ] **Step 4: Write the live-tree test and CLI test**

The permanent live test calls the checker against the real Backend package,
lock, installed modules, and Prisma config. The CLI test requires exactly:

```text
PASS - Prisma config merge security
```

and verifies failures reveal no absolute paths, stacks, environment values, or
raw config.

- [ ] **Step 5: Run the accepted RED before changing packages**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
node --test -r ts-node/register test/prisma-config-merge-security.test.ts
```

Expected: all synthetic law tests pass; the live installed-graph/recursive proof
fails because the tree still resolves `7.1.5`. Record exact counts and the fixed
sanitized failure. If the live proof unexpectedly passes, stop and investigate;
do not edit packages without a valid RED.

- [ ] **Step 6: Implement only enough checker code to make fixture laws pass**

Keep the live graph RED. Run filtered fixture tests until all non-live tests pass.
Do not add an audit allowlist or version coercion.

Do not commit.

---

### Task 2: Apply the Exact Override and Reach Focused GREEN

**Files:**
- Modify: `backend/package.json`
- Modify: `backend/package-lock.json`
- Modify: `backend/scripts/security/prisma-config-merge-security.cjs`
- Modify: `backend/test/prisma-config-merge-security.test.ts`
- Modify generated: `docs/SCRIPTS.md`
- Create ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-2-report.md`

**Interfaces:**
- Adds npm script:
  `security:prisma-config-merge` →
  `node scripts/security/prisma-config-merge-security.cjs --check`.
- Adds exact override `deepmerge-ts: 8.0.1`.
- Leaves all other dependency ranges and npm scripts byte-equivalent except the
  one intentional script addition.

- [ ] **Step 1: Capture pre-override semantic artifacts outside Git**

```powershell
$proof = Join-Path ([IO.Path]::GetTempPath()) `
  ("aarast-r5-prisma-security-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proof | Out-Null
$env:PRISMA_HIDE_UPDATE_MESSAGE = '1'
try {
  node scripts/prisma/dmmf-fingerprint.cjs --output `
    (Join-Path $proof 'before-dmmf.json')
  npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema --script |
    Set-Content -LiteralPath (Join-Path $proof 'before-schema.sql') `
      -Encoding utf8NoBOM
} finally {
  Remove-Item Env:PRISMA_HIDE_UPDATE_MESSAGE -ErrorAction SilentlyContinue
}
```

Do not delete `$proof` until Task 3 completes. Store only hashes and counts in
the ignored report.

- [ ] **Step 2: Edit `package.json` narrowly**

Add the script and exact override. Do not reorder or alter any other dependency,
override, script, metadata, or version.

- [ ] **Step 3: Regenerate lockfile and install from it**

```powershell
npm install --package-lock-only --ignore-scripts --no-audit --no-fund
npm ci --ignore-scripts --no-audit --no-fund
npx prisma generate
```

Expected:

- package-lock v3 remains;
- Prisma packages remain 6.19.3;
- `node_modules/deepmerge-ts` is 8.0.1;
- no nested vulnerable copy exists;
- `npm ls deepmerge-ts --all` exits 0 and reports the override;
- Prisma client generation passes.

If npm changes any dependency unrelated to exact transitive resolution, stop
and classify the lock diff before continuing.

- [ ] **Step 4: Inspect the exact package/lock diff**

```powershell
git diff -- backend/package.json backend/package-lock.json
npm ls prisma @prisma/client @prisma/config deepmerge-ts --all
```

Require only:

- one new npm script;
- one new exact override;
- lock resolution/integrity changes needed to replace 7.1.5 with 8.0.1;
- no Prisma, engine, platform, or unrelated transitive movement.

- [ ] **Step 5: Run focused GREEN**

```powershell
node --test -r ts-node/register test/prisma-config-merge-security.test.ts
npm run security:prisma-config-merge
npm audit --audit-level=high
npm audit --omit=dev
```

Expected: every test passes, fixed CLI PASS, and both audits report zero
vulnerabilities.

- [ ] **Step 6: Regenerate script docs**

```powershell
Set-Location ..
node scripts/docs-sync.mjs
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
```

Require the generated `docs/SCRIPTS.md` delta to be exactly the new script row.

Do not commit.

---

### Task 3: Prove Prisma Config and Schema Equivalence

**Files:**
- No new tracked files expected.
- Append ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-3-report.md`

**Interfaces:**
- Compares pre/post DMMF and migration SQL artifacts in one unique OS-temp root.
- Proves live schema/config without persisting secrets or artifacts.

- [ ] **Step 1: Run the real Prisma Config loader proof**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run security:prisma-config-merge
```

Require the checker to confirm only the existing schema folder
`prisma/schema` and migration folder `prisma/migrations`. It must not print the
loaded config object.

- [ ] **Step 2: Validate and regenerate using a process-scoped database URL**

Use the existing managed-test placeholder convention. Set it only for the child
process and remove it immediately afterward.

```powershell
$previousDatabaseUrl = $env:DATABASE_URL
try {
  $env:DATABASE_URL = 'postgresql://placeholder:placeholder@127.0.0.1:1/placeholder'
  npx prisma validate
  npx prisma generate
} finally {
  if ($null -eq $previousDatabaseUrl) {
    Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
  } else {
    $env:DATABASE_URL = $previousDatabaseUrl
  }
}
```

Never record the placeholder or any pre-existing value in the report.

- [ ] **Step 3: Capture post-override semantic artifacts**

```powershell
$env:PRISMA_HIDE_UPDATE_MESSAGE = '1'
try {
  node scripts/prisma/dmmf-fingerprint.cjs --output `
    (Join-Path $proof 'after-dmmf.json')
  npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema --script |
    Set-Content -LiteralPath (Join-Path $proof 'after-schema.sql') `
      -Encoding utf8NoBOM
} finally {
  Remove-Item Env:PRISMA_HIDE_UPDATE_MESSAGE -ErrorAction SilentlyContinue
}
```

- [ ] **Step 4: Compare before/after bytes and live counts**

Use byte comparison, not parsed-object equivalence, for both artifacts. Require:

- DMMF files byte-identical;
- generated migration SQL byte-identical;
- DMMF reports 52 models and 41 enums;
- schema loader reports exactly 14 schema files;
- filesystem reports exactly 76 migration directories;
- fixed-base diff for config/schema/migrations/seed is empty.

Run:

```powershell
node scripts/prisma/schema-files.cjs
git diff --exit-code 9dab73acdc187a4a18d8a675713d8ded40a16d02 -- `
  prisma.config.ts prisma/schema prisma/migrations prisma/seed.ts
```

- [ ] **Step 5: Clean proof artifacts in `finally`**

Delete the exact unique `$proof` directory and verify it no longer exists. Do
not use a broad temp glob. Record only artifact SHA-256 values and counts.

If any equivalence check fails, execute the rollback in the design and stop.

Do not commit.

---

### Task 4: Run the Full R5 Application and Managed-Smoke Gates

**Files:**
- No new tracked files expected.
- Append ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-4-report.md`

**Interfaces:**
- Revalidates the entire dirty R5 Task 5A candidate after dependency installation.
- Produces exact PASS/FAIL counts and cleanup evidence.

- [ ] **Step 1: Run focused security and R5 gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run security:prisma-config-merge
node --test -r ts-node/register `
  test/prisma-config-merge-security.test.ts `
  test/architecture-r5-identity-relocation.test.ts
npm run architecture:r5
```

- [ ] **Step 2: Run complete static and Backend tests**

```powershell
npm run architecture
npm run check
npm run build
npm test
npm audit --audit-level=high
npm audit --omit=dev
```

Expected: no failure, artifact cleanliness PASS, and audits zero. Do not copy an
old test count; record the fresh aggregate including the new security tests.

- [ ] **Step 3: Run the targeted R5 managed smokes**

```powershell
npm run smoke:health
npm run smoke:auth
npm run smoke:auth-verification
npm run smoke:otp-profile
npm run smoke:phase1-identity
npm run smoke:phase2-auth-retention
npm run smoke:phase2-auth-lifecycle-concurrency
npm run smoke:phase3-context-transition
npm run smoke:account-deletion
```

Require every package to pass after all 76 migrations.

- [ ] **Step 4: Run the aggregate managed smoke**

```powershell
npm run smoke:all
```

Require all 30 packages to pass. Do not omit this because individual smokes are
green.

- [ ] **Step 5: Prove cleanup**

After each group and once at the end, require zero:

- managed PostgreSQL smoke databases;
- Redis DB15 keys;
- smoke media buckets;
- managed smoke containers, volumes, and networks;
- repository Node processes and smoke listeners;
- current-run temp artifacts.

Inspect exact run IDs first. Never delete an unresolved broad path or a user
database.

- [ ] **Step 6: Run repository docs and frozen-surface gates**

```powershell
Set-Location ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Compare the fixed R5 base to the candidate and require zero changes in all
frozen surfaces named by the design. The package diff must match Task 2 exactly.

Do not commit.

---

### Task 5: Build and Remove an Immutable Compatibility Probe

**Files:**
- No tracked files.
- Append ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-5-report.md`

**Interfaces:**
- Builds from the candidate package-lock through the existing Dockerfile.
- Proves clean install, both Prisma generations, startup migration, and health.
- Does not replace the current phone runtime.

- [ ] **Step 1: Record the preserved runtime identity read-only**

Capture only container name, image ID/tag, OCI revision, network, published port,
running state, restart count, and local `/live`/`/ready` status. Do not inspect or
print environment values or raw command lines.

- [ ] **Step 2: Build a uniquely tagged candidate image**

The reviewed candidate is deliberately still uncommitted at this point, so it
does not have a truthful candidate Git SHA. Freeze the exact sorted
`path|SHA-256` manifest first and use its full aggregate SHA-256 in the probe
tag plus `-prisma-security-probe`. Pass the current full `HEAD` SHA as
`AARAST_GIT_REVISION`, but record it only as the source checkpoint beneath the
reviewed dirty overlay—not as the identity of the candidate bytes. The
aggregate receipt, immutable image ID, in-image security checker, and installed
package graph jointly identify what was actually built. The Dockerfile must
remain byte-identical.

Expected build evidence:

- `npm ci` consumes the corrected lockfile;
- both existing `npx prisma generate` steps pass;
- build passes;
- image label contains the exact full source-checkpoint `HEAD` SHA;
- the tag contains the exact full reviewed candidate aggregate SHA-256.

- [ ] **Step 3: Run on a unique loopback probe port**

Attach the probe to the existing approved network without touching the phone
container. Use a free loopback-only port, then require:

- migration discovery and all 76 migrations recognized;
- `/live` HTTP 200;
- `/ready` HTTP 200 with required dependencies up;
- restart count 0 and OOM false;
- installed Prisma packages 6.19.3;
- installed `deepmerge-ts` 8.0.1;
- security checker PASS inside the image;
- no fatal, unhandled, TypeError, Prisma-config, schema-not-found, or migration
  error marker in a sanitized scan.

- [ ] **Step 4: Remove only the probe**

Remove the exact probe container and any exact probe-only network/volume/temp
artifact. Preserve the candidate image until independent review, then remove it
if the review rejects the candidate. Reconfirm the phone runtime identity and
health are unchanged.

Do not cut over or ask for phone QA; no application behavior changed.

---

### Task 6: Independent Review, Truthful Receipts, and Atomic Local Checkpoint

**Files:**
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`
- Modify: `CHANGELOG.md`
- Append ignored:
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/task-6-report.md`

**Interfaces:**
- Consumes: stable bytes, exact hashes, all Task 0–5 evidence.
- Produces: independent findings-first verdict and one atomic local R5 Task 5A
  checkpoint only if no findings remain.

- [ ] **Step 1: Freeze a review package**

Create an ignored package containing:

- design and implementation plan;
- exact changed-path manifest;
- SHA-256 for every candidate file;
- RED/GREEN counts;
- package/lock diff summary;
- installed-resolution proof;
- DMMF/migration/count hashes;
- full gate/smoke/audit/probe results;
- frozen-surface and cleanup receipts;
- known constraints and override removal condition.

Do not include `.env`, registry configuration, raw logs, absolute temp paths, or
credentials.

- [ ] **Step 2: Request an independent read-only review**

The reviewer must independently attempt at least:

- missing/wrong/ranged override;
- vulnerable nested lock entry and multiple-copy graph;
- local/file/git/path-spoofed package resolution;
- cyclic public merge;
- Prisma Config ordinary merge semantics;
- tampered package/lock unrelated dependency;
- DMMF/config/schema/frozen-surface drift;
- partial or stale audit evidence;
- probe identity mismatch and residue.

Verdict must be findings-first and classify Critical, Important, and Minor.

- [ ] **Step 3: Address findings with RED→GREEN or stop**

For each confirmed finding, add a permanent failing regression before production
changes, implement the root fix, rerun proportional and required full gates, and
obtain a fresh independent verdict. Never edit while the reviewer reads a
supposedly frozen candidate.

- [ ] **Step 4: Write truthful active receipts only after PASS**

Record:

- advisory ID, affected/patched versions, and publication timing;
- why Prisma major/downgrade/force-fix were rejected;
- exact 8.0.1 override and removal condition;
- exact tests, audits, semantic hashes, smokes, probe, and cleanup;
- unchanged Prisma 6.19.3 and frozen application surfaces;
- no phone cutover, push, merge, PR, deployment, or remote CI;
- R5 Task 5A locally complete, R5 final closeout still pending later tasks.

Run docs sync/verify and diff-check again after the final wording.

- [ ] **Step 5: Confirm exact atomic commit scope**

Because the pre-existing Task 5 manifest/plan changes and this checkpoint are
interdependent, stage the complete reviewed R5 Task 5A path manifest, not
`git add -A`. Inspect staged name-status and diff. Require zero unrelated,
protected, ignored-report, generated temp, or secret path.

- [ ] **Step 6: Create one local checkpoint only after explicit Git authority**

Recommended message:

```powershell
git commit -m "fix: secure Prisma config merge resolution"
```

The commit is local only. Do not push, merge, open/update a PR, deploy, claim
remote CI, or begin R6.

- [ ] **Step 7: Post-commit verification**

Re-run from committed bytes:

```powershell
npm run security:prisma-config-merge
npm run architecture:r5
npm run architecture
npm run check
npm run build
node --test -r ts-node/register test/prisma-config-merge-security.test.ts
npm audit --audit-level=high
npm audit --omit=dev
node ..\scripts\docs-sync.mjs --check
node ..\scripts\docs-verify.mjs
git diff HEAD^ HEAD --check
git status --short
```

Expected: all PASS and clean status. Retain the ignored reports locally. R5 may
then resume at the next approved task; it is not yet globally complete.

---

## Plan Self-Review Checklist

- [ ] No task upgrades/downgrades Prisma or edits application source.
- [ ] The real vulnerable path is reproduced before package changes.
- [ ] The gate proves manifest, lock, installed identity, runtime behavior, and
  real Prisma Config—not merely an audit string.
- [ ] Every failure has a permanent regression and fixed sanitized diagnostic.
- [ ] Pre/post DMMF and migration artifacts are outside Git and cleaned exactly.
- [ ] Both audits must be zero; no exception or suppression is allowed.
- [ ] The Dockerfile remains byte-identical while a fresh lock-consuming image
  is built and probed.
- [ ] The current R5 Task 5 dirty candidate is preserved and hash-receipted.
- [ ] The final commit is atomic because no intermediate red-audit/red-scope
  checkpoint is acceptable.
- [ ] No push, merge, PR, deployment, phone cutover, remote CI claim, or R6.
- [ ] Every task, expected result, version, command, and path is concrete.
