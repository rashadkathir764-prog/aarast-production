# R5 Prisma Config Merge Security Checkpoint Design

**Status:** Approved for planning; implementation has not started.

**Date:** 2026-08-21

**Repository:** `D:\projects\aarast-modular-monolith`

**Branch:** `modular-monolith`

**Current application checkpoint:** `3a62b257819de0530dd1737934773e2e5fc7fca1`

**Parent phase:** R5 Identity Source Relocation, immediately before Task 5 can be
accepted and checkpointed.

## Problem

The Backend dependency graph currently resolves:

```text
prisma@6.19.3
└─ @prisma/config@6.19.3
   └─ deepmerge-ts@7.1.5
```

`deepmerge-ts` versions earlier than `8.0.0` are affected by
`GHSA-ggr8-5vv4-36mx` / `CVE-2026-40345`. Two recursive object graphs supplied
to the public merge API can exhaust the Node.js stack. The advisory is High
severity and the first patched line is `8.0.0`.

This finding appeared after the previous zero-finding audit receipts because
the advisory was published on 2026-08-16. The R5 application code did not
introduce it, but R5 cannot truthfully close while both required npm audits are
red.

The current Prisma 6 line cannot solve the finding by an ordinary patch upgrade:

- `6.19.3` is the final Prisma 6 release available to this project;
- Prisma 7 is a broad breaking migration involving ESM, driver adapters,
  generated-client output/imports, CLI behavior, and runtime connection rules;
- current Prisma 7.9.1 metadata still declares `deepmerge-ts@7.1.5`, so a Prisma
  major upgrade alone does not remove this advisory;
- `npm audit fix --force` proposes a Prisma downgrade and is therefore not an
  acceptable root fix.

## Decision

Keep `prisma` and `@prisma/client` at `6.19.3`. Add one exact npm override:

```json
{
  "overrides": {
    "deepmerge-ts": "8.0.1"
  }
}
```

Regenerate the lockfile using normal npm resolution and add a permanent
security gate that proves all of the following:

1. the declared override is exactly `8.0.1`;
2. every installed/locked `deepmerge-ts` copy is patched and Prisma Config
   resolves the same canonical installed package;
3. the public recursive-graph proof no longer reaches stack exhaustion;
4. Prisma Config can load the repository's real `prisma.config.ts` contract;
5. Prisma validation, generation, DMMF, schema counts, migrations, Backend
   behavior, managed smokes, and container startup remain equivalent;
6. both required npm audits return zero findings.

This is a dependency-resolution correction, not a Prisma major upgrade and not
a vendor patch. No source under `backend/src`, Prisma schema, migration, seed,
Mobile, Admin, workflow, deployment, Compose, or public API surface changes.

## Why `8.0.1`

The patched major begins at `8.0.0`; the checkpoint pins `8.0.1` exactly to use
the latest available patch in that corrected line while keeping the resolution
deterministic. The pin is not a range and is not delegated to future npm
resolution.

Version 8 has documented behavior changes around Map merging,
`deepmergeInto`, and some exported types. Prisma Config uses the public
`deepmerge` function through `c12`, not the changed `deepmergeInto` API, but
that observation is not accepted as sufficient. The checkpoint must prove the
actual Prisma path and the full project gates before it can be retained.

## Alternatives Rejected

### Ignore or suppress the audit

Rejected. The finding affects availability, the audits are explicit R5 gates,
and a receipt claiming success would be false.

### Run `npm audit fix --force`

Rejected. The proposed dependency movement is uncontrolled and includes a
Prisma downgrade. It does not preserve the approved dependency or runtime
contract.

### Upgrade the application to Prisma 7 inside R5

Rejected. It is a separate major migration with broad code, build, and runtime
effects, while the current Prisma 7 dependency metadata still does not remove
the vulnerable transitive version. Such a migration requires its own future
specification and phase.

### Patch files under `node_modules`

Rejected. The result would be non-reproducible, absent from clean installs and
containers, and impossible to prove from the lockfile.

### Add a silent catch, timeout, or input filter around Prisma Config

Rejected. That treats one possible symptom while leaving the vulnerable
dependency installed and the audit red.

## Scope

### Implementation files

- Modify `backend/package.json` with the exact override and one permanent
  `security:prisma-config-merge` script.
- Modify `backend/package-lock.json` only through deterministic npm resolution.
- Create `backend/scripts/security/prisma-config-merge-security.cjs`.
- Create `backend/test/prisma-config-merge-security.test.ts`.
- Modify `backend/architecture/r5-identity-relocation.json` only to authorize
  the exact checkpoint paths and to preserve the existing R5 fixed-base fence.
- Modify `backend/test/architecture-r5-identity-relocation.test.ts` with exact
  package/lock scope near-misses.
- Modify `docs/SCRIPTS.md` only through the repository docs generator.

### Contract and receipt files

- Modify the active R5 design and plan with this narrow package-lock exception.
- Modify `docs/project/DECISIONS.md`, `docs/project/STATUS.md`, and
  `docs/qa/README.md` only after the implementation evidence is complete.
- Modify `CHANGELOG.md` only in the final local receipt.
- Create ignored evidence under
  `.superpowers/sdd/2026-08-21-r5-prisma-config-merge-security-checkpoint/`.

### Frozen surfaces

- `backend/src/**`
- `backend/prisma/schema/**`
- `backend/prisma/migrations/**`
- `backend/prisma/seed.ts`
- `backend/prisma.config.ts`
- `Mobile/**`
- `Admin/**`
- `.github/workflows/**`
- Compose, Dockerfile, deployment, and Dokploy files
- API, Arabic product copy, OTP/session behavior, routes, DTOs, database data,
  and public provider contracts

The Dockerfile itself remains byte-identical. A fresh image build is required
because its existing `npm ci`, Prisma generation, and startup migration path
must consume the corrected lockfile successfully.

## Security Gate Architecture

Create a CommonJS checker with a fixed, sanitized CLI:

```text
node scripts/security/prisma-config-merge-security.cjs --check
```

Success output is one fixed line:

```text
PASS - Prisma config merge security
```

Any package graph, filesystem, module-resolution, recursive-merge, or Prisma
Config failure returns a fixed non-zero result without absolute paths, stack
traces, environment values, or package-registry credentials.

The checker has four internal proofs.

### 1. Declared and locked graph proof

Parse `package.json` and `package-lock.json` as plain JSON. Require:

- `overrides['deepmerge-ts'] === '8.0.1'`;
- root `prisma` and `@prisma/client` remain on the approved `6.19.3` line;
- every lockfile key ending in `node_modules/deepmerge-ts` has version `8.0.1`;
- exactly one canonical root installed entry exists;
- no locked copy resolves a version earlier than 8;
- the canonical lock entry has the registry integrity recorded by npm;
- no URL, file, git, workspace, or local-path dependency substitutes for the
  registry artifact.

The checker must not rewrite either file.

### 2. Canonical installed-resolution proof

Use Node resolution from the installed `@prisma/config` package context, not a
name or path substring. Resolve `deepmerge-ts/package.json` and its public
entrypoint through a `createRequire` anchored at the canonical Prisma Config
package. Require the resolved package's real identity and version to equal the
single root lock entry and the package imported for the runtime proof.

This prevents a nested stale copy, same-name package, local alias, or path
spoof from satisfying the gate.

### 3. Recursive-graph runtime proof

Load the canonical public `deepmerge` function. Merge two objects that each
contain a self-reference at the same property path. Require completion without
`RangeError`, and require the returned graph to preserve a finite circular
relationship. Also merge an ordinary Prisma-config-shaped pair and assert the
expected schema, migrations, and datasource fields without mutating either
input.

The RED run occurs before changing the package graph and must demonstrate the
current `7.1.5` failure. The GREEN run occurs only after the override and clean
install.

### 4. Real Prisma Config proof

Invoke the installed Prisma Config loader against the repository's actual
`prisma.config.ts` under a process-scoped placeholder `DATABASE_URL`. Assert
the existing schema folder and migrations folder only. Do not print or persist
the placeholder. Follow with the normal `prisma validate` and `prisma generate`
commands.

## Compatibility Proof

The override is accepted only if all compatibility layers pass.

### Prisma structure and semantics

- exactly 14 schema files;
- exactly 52 models and 41 enums;
- exactly 76 migration directories;
- candidate DMMF projection is byte-identical to the pre-override projection;
- `prisma migrate diff --exit-code` reports `No difference detected`;
- `prisma validate` and `prisma generate` pass from a clean dependency install.

The pre-override DMMF is captured in a unique OS-temp directory before the
package change. Only hashes/counts enter the ignored report; no generated
fingerprint or temporary path enters Git.

### Application and architecture

- focused security tests pass;
- `npm run architecture:r5`, full architecture, TypeScript checks, build, and
  the full Backend test suite pass;
- dependency and ownership evidence remain exactly the already verified R5
  Task 5 values;
- no application source or behavioral test is weakened to accommodate the
  package.

### Managed runtime

Run the existing R5 smoke matrix and `smoke:all` from an isolated environment.
Then build a temporary immutable Backend image using the candidate lockfile,
run it on a non-phone probe port, prove migration discovery plus `/live` and
`/ready`, and remove the probe. Do not cut over the preserved phone runtime in
this checkpoint.

### Audit

Both commands must report zero vulnerabilities:

```powershell
npm audit --audit-level=high
npm audit --omit=dev
```

An audit exception, allowlist, severity reduction, or omitted production graph
does not satisfy this criterion.

## Failure and Rollback

If any RED fixture is not reproduced, the package graph is not changed until
the test is corrected.

If any GREEN compatibility proof fails:

1. do not commit the override or lockfile;
2. restore only the checkpoint-owned package, lock, checker, and test changes;
3. retain the audit as an explicit blocker in the R5 report;
4. wait for an upstream Prisma package that resolves `deepmerge-ts >= 8.0.0`,
   or create a separately approved Prisma-major migration;
5. do not weaken or skip the failing gate.

No automatic downgrade, force fix, vendor edit, compatibility facade, or
runtime fallback is permitted.

## Override Removal Condition

The override is intentionally temporary but has no calendar deadline. Remove
it only when an adopted Prisma release declares and installs
`deepmerge-ts >= 8.0.0` without the override and the same security,
Prisma-equivalence, full-test, smoke, image-probe, and audit gates pass.

The removal must be a reviewed local checkpoint. Merely seeing a newer Prisma
version on the registry is not sufficient.

## Dirty Candidate and Checkpoint Discipline

The current R5 Task 5 worktree is already dirty with verified baseline and test
reconciliation. The executor must first capture a path-and-hash receipt for
that candidate and must not rewrite, stash, reset, or discard it.

The security checkpoint is implemented on the same approved branch and
worktree. Because the R5 manifest and active R5 plan/design already contain
uncommitted Task 5 evidence, the final local checkpoint is one atomic reviewed
R5 Task 5A commit containing:

- the existing Task 5 reconciliation;
- the exact security package/lock/checker/tests;
- the narrow R5 scope amendment;
- generated and truthful receipts.

This avoids producing an intermediate commit whose checked-out tree has either
a red audit or an invalid R5 scope. The ignored reports remain logically
separate and state which evidence belongs to baseline reconciliation versus
the security checkpoint.

No commit is created during planning. The future local commit requires the
implementation gates and independent review. Push, merge, PR, deployment,
remote CI claims, and R6 remain forbidden.

## Acceptance Criteria

- The current recursive-graph proof is RED on `deepmerge-ts@7.1.5` before the
  package change.
- `backend/package.json` pins exactly `deepmerge-ts@8.0.1` through `overrides`.
- A clean npm install resolves one canonical patched copy and no vulnerable
  copy.
- The checker rejects missing/wrong/ranged overrides, stale/nested lock
  entries, local/file/git substitutions, path-spoofed resolution, an incorrect
  Prisma Config merger, and recursive stack exhaustion.
- Prisma Config loads the real repository config through the corrected package.
- DMMF is byte-identical, migration diff is empty, and 14/52/41/76 counts remain.
- Architecture, check, build, all tests, targeted smokes, `smoke:all`, cleanup,
  and the immutable image probe pass.
- Both Backend npm audits return zero findings.
- Frozen surfaces are byte-identical.
- Independent review returns no Critical, Important, or Minor finding.
- The final receipt says no push, merge, PR, deployment, remote CI, phone
  cutover, or R6 occurred.

## Authoritative References

- GitHub Advisory Database:
  `https://github.com/advisories/GHSA-ggr8-5vv4-36mx`
- `deepmerge-ts` 8.0.0 release notes:
  `https://github.com/RebeccaStevens/deepmerge-ts/releases/tag/v8.0.0`
- Prisma 7 upgrade guide:
  `https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7`

## Amendment 2026-09-13: the package fingerprint covers the security surface

The checker pinned the SHA-256 of the whole `backend/package.json` (after the
architecture-script projections of R6–R12C). That made every npm script
outside the architecture chain a checkpoint failure: adding
`smoke:schema-equivalence` at the 2026-09-13 product audit failed the
security gate, R5 and R12B without any dependency change. The checkpoint
guards the `deepmerge-ts`/Prisma dependency graph, so from this change the
fingerprint covers the package security surface — every `package.json`
member except `scripts` (`name`, `version`, `private`, `description`,
`license`, `dependencies`, `devDependencies`, `overrides`) — of the projected
package, and the lock fingerprint lineage is unchanged. The architecture
chain keeps its exact projections (an aggregate that names a gate without
its standalone script is rejected, a gap the whole-file fingerprint had
masked). Regression test: an unrelated script never fails the checkpoint; a
dependency, override, engine or name change still does.
