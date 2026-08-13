# Modular Monolith R2 Prisma Schema Folder Implementation Plan

**Execution status:** Independently reviewed and approved; implementation has not started

> **For agentic workers:** Execute one task at a time with an implementer and a
> separate read-only reviewer. Prove RED before production edits, fix validated
> findings at their root, and do not begin the next task until the current
> checkpoint is committed cleanly.

**Goal:** Replace the single Prisma schema with a native, ownership-aligned
14-file schema folder while proving zero database, migration, generated-client,
seed, application, and deployment-topology change.

**Architecture:** A machine-readable manifest is the exact schema file and
ownership contract. A fail-closed canonical loader serves every repository
tool/test that needs combined schema text. The split is validated against the
immutable R1-closeout schema with manifest checks, normalized DMMF equality,
an empty Prisma migrate diff, frozen seed/migrations/docs, and Docker runtime
evidence.

**Tech stack:** NestJS 11, TypeScript 5.9, Prisma/Prisma Client 6.19.3,
PostgreSQL, Node.js 22 in CI, dependency-cruiser 18.1.0, Node test runner,
Flutter 3.41.7, Docker multi-stage Alpine image, Markdown documentation.

**Design source:**
`docs/superpowers/specs/2026-08-13-modular-monolith-r2-prisma-schema-design.md`

## Global Constraints

- Work only on branch `modular-monolith` from immutable `R2_BASE`
  `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`.
- The owner authorizes local checkpoint commits on this branch. Do not create
  a branch/worktree, push, mutate a pull request, merge, reset, or rewrite
  history.
- Keep the R1 phone-test container available during planning and Task 1. Task 3
  may replace it only after an immutable R2 image is built and the previous
  image/tag remains available for rollback.
- Preserve exactly 52 models, 41 enums, and 76 committed migration
  directories. Derive each count from source; do not trust stale prose.
- No schema semantic change is authorized. A non-empty migrate diff, changed
  DMMF projection, changed seed/migration byte, generated-table delta, or any
  generated-doc delta other than the exact database source-path sentence is a
  blocker, not an expected baseline update.
- Do not modify `backend/src/**`, package manifests/lockfiles, Mobile/Admin
  source/tests, Compose/Dokploy files, workflows, or any Dockerfile except the
  two exact config-copy lines in `backend/Dockerfile`.
- Do not split `backend/prisma/seed.ts`; do not create per-module seeds before
  their owning business modules exist.
- Do not retain `backend/prisma/schema.prisma`, create an aggregator, add a
  compatibility copy/re-export, use a symlink/junction, add
  `package.json#prisma`, or scatter new `--schema` flags outside the isolated
  equivalence and migration-rehearsal commands specified here.
- Existing behavioral tests may change only by importing the shared live-schema
  helper and replacing their direct single-file read. Assertions, fixtures,
  expected values, product/error/Arabic literals, timeouts, skips, and test
  selection are frozen.
- Never write absolute local paths, environment values, connection strings,
  database identifiers, tokens, secrets, or production identifiers to tracked
  files, baselines, diagnostics, or reports.
- Any contradiction discovered during execution stops the current task. Update
  the design and plan through an independently reviewed contract correction
  before resuming.

## Checkpoint Protocol

Each task is independently accepted:

1. confirm branch, base ancestry, clean tracked state, and exact allowed scope;
2. prove required tests RED before production changes;
3. implement only the current task and run its focused/full gates;
4. create a detailed ignored report under
   `.superpowers/sdd/2026-08-13-modular-monolith-r2/`;
5. stop all edits and request an independent read-only review;
6. fix every validated finding with a new RED/GREEN cycle and re-review;
7. create one clean local checkpoint commit and verify its exact scope.

Task 3 additionally builds/runs the immutable server image and waits for the
owner's phone application test before R2 is marked locally complete. Remote CI
is not claimed without an authorized push.

## R2 Completion Contract

R2 is complete only when all of the following are true on one immutable local
candidate:

1. `backend/prisma/schema.prisma` is absent and the exact 14-file target folder
   exists with no extra `.prisma` file.
2. `_base.prisma` contains only the original generator and datasource; the 13
   owner files contain exactly the manifest's 52 models and 41 enums.
3. Manifest model ownership equals `ownership-registry.json`; enum ownership,
   file set, model order, and `R2_BASE` are exact.
4. `prisma.config.ts`, Docker build/runtime stages, ownership scanning, docs
   sync, migration rehearsal, and all live schema-reading tests use the folder.
5. No active tool/test/source references `prisma/schema.prisma`; only named
   historical/negative-control files retain the literal.
6. Migrate diff and normalized DMMF comparison are empty/equal; Prisma validate
   and generate pass.
7. All 76 migrations and `seed.ts` are byte-identical to `R2_BASE`; no migration
   directory is added.
8. Ownership remains 386 records/782 occurrences; dependency baseline remains
   260 known records; ports remain forwardRef=0, globals=2, illegal=0, cycles=0.
9. API, Mobile route, Admin route, script inventory, and the generated database
   model table are byte-identical. The sole database-doc delta is the exact
   source-of-truth path sentence.
10. Backend, migration smokes, full managed smoke, audits, unchanged Admin and
    Mobile gates, docs, Docker runtime, independent review, and owner phone test
    pass with clean resource cleanup.
11. The final fixed-base diff matches the reviewed R2 allowlist and protected
    surfaces are unchanged.

## Exact Target and Consumer Map

### Create

- `backend/architecture/prisma-schema-layout.json`
- `backend/scripts/prisma/schema-files.cjs`
- `backend/scripts/prisma/dmmf-fingerprint.cjs`
- `backend/scripts/prisma/r2-schema-scope.cjs`
- `backend/test/prisma-schema-files.test.ts`
- `backend/test/prisma-dmmf-fingerprint.test.ts`
- `backend/test/prisma-r2-manifest.test.ts`
- `backend/test/prisma-r2-schema-scope.test.ts`
- `backend/test/support/live-prisma-schema.ts`
- `backend/test/architecture-r2-schema-layout.test.ts`
- `backend/prisma/schema/_base.prisma`
- `backend/prisma/schema/backoffice.prisma`
- `backend/prisma/schema/catalog.prisma`
- `backend/prisma/schema/collaboration.prisma`
- `backend/prisma/schema/finance.prisma`
- `backend/prisma/schema/guests.prisma`
- `backend/prisma/schema/identity.prisma`
- `backend/prisma/schema/marketplace.prisma`
- `backend/prisma/schema/media.prisma`
- `backend/prisma/schema/messaging.prisma`
- `backend/prisma/schema/notifications.prisma`
- `backend/prisma/schema/planning.prisma`
- `backend/prisma/schema/platform.prisma`
- `backend/prisma/schema/tasks.prisma`

### Delete

- `backend/prisma/schema.prisma`

### Modify During Implementation

- `backend/prisma.config.ts`
- `backend/Dockerfile` — only the two approved config-copy lines
- `backend/scripts/architecture/ownership-scan.cjs`
- `backend/scripts/smoke/contributor-history-migration-smoke.js`
- `scripts/docs-sync.mjs`
- `backend/test/architecture-ownership.test.ts`
- `backend/test/admin-auth-session-security.test.ts`
- `backend/test/admin-rbac-audit.test.ts`
- `backend/test/auth-refresh-wiring.test.ts`
- `backend/test/contribution-history-migration.test.ts`
- `backend/test/financial-ledger.test.ts`
- `backend/test/legacy-finance-removal.test.ts`
- `backend/test/marketplace-presenter.test.ts`
- `backend/test/outbox-logic.test.ts`
- `backend/test/provider-chat-logic.test.ts`
- `backend/test/reference-catalogs.test.ts`
- `docs/backend/DATABASE.md` — exact source-of-truth path sentence only

### Modify During Planning/Receipt

- `ARCHITECTURE.md`
- `docs/README.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md`
- `docs/qa/README.md` only to record the active R2 verification contract
- `CHANGELOG.md` only at R2 closeout
- this design and plan

### Explicitly Protected

- `backend/src/**`
- `backend/prisma/migrations/**`
- `backend/prisma/seed.ts`
- `backend/package.json`, `backend/package-lock.json`
- `.github/workflows/**`
- `docker-compose*.yml`, `deploy/**`, all other Dockerfiles
- `mobile/lib/**`, `mobile/test/**`, `mobile/integration_test/**`
- `admin-web/src/**`, `admin-web/test/**`, `admin-web/tests/**`
- dependency and ownership baselines unless a candidate is byte-identical
  (no R2 debt relocation is expected)

### Exact Retired-Path Literal Allowlist

After Task 2, executable files may name `prisma/schema.prisma` only in:

- `scripts/check-r0-scope.test.mjs` R0 historical fixtures;
- `backend/test/architecture-r2-schema-layout.test.ts` negative assertions;
- `backend/test/prisma-schema-files.test.ts` explicit negative fixtures.

Documentation may retain it only in `CHANGELOG.md`, historical sections of
`docs/project/STATUS.md`, `docs/archive/**/*.md.txt`, the completed R0/R1 plans,
and this R2 design/plan. `docs/backend/DATABASE.md` is not allowlisted. Match
case-insensitively across `/` and `\` separators and all `.ts`, `.js`, `.cjs`,
`.mjs`, `.json`, and `.md` active files so an alternate spelling cannot evade
the gate.

## Task 1: Freeze the Base and Green Equivalence Contract

**Purpose:** Establish durable immutable facts and green verification tooling
before any schema/config/reader change. Task 1 never commits a failing test.

**Allowed tracked files:**

- `backend/architecture/prisma-schema-layout.json`
- `backend/scripts/prisma/dmmf-fingerprint.cjs`
- `backend/scripts/prisma/r2-schema-scope.cjs`
- `backend/test/prisma-dmmf-fingerprint.test.ts`
- `backend/test/prisma-r2-manifest.test.ts`
- `backend/test/prisma-r2-schema-scope.test.ts`
- active R2 planning/QA Markdown only if a verified contradiction is found

No schema loader/layout test, Prisma file, config, Dockerfile, existing test,
or RED artifact is committed in Task 1.

- [ ] **Step 1: Prove immutable execution identity and clean scope**

```powershell
$R2_BASE = '8ba0db78ac669bd6d17de878b77a4d1e6c5e542d'
$R2_PLAN = git rev-parse HEAD
if ((git branch --show-current) -ne 'modular-monolith') { throw 'wrong branch' }
git merge-base --is-ancestor $R2_BASE $R2_PLAN
if ($LASTEXITCODE -ne 0) { throw 'R2_BASE is not an ancestor' }
if (git status --porcelain) { throw 'worktree is not clean' }
```

Require that `R2_BASE..R2_PLAN` is the independently approved docs-only
planning checkpoint and both R2 statuses say approved. Keep every schema and
protected comparison anchored to `R2_BASE`. Confirm the current R1 phone image
is healthy and rollback-identifiable; do not stop it.

- [ ] **Step 2: Capture exact base evidence**

Use a unique OS-temp directory plus ignored
`.superpowers/sdd/2026-08-13-modular-monolith-r2/task-1-report.md`. Record only
relative paths, counts, and hashes:

- full base/plan SHAs and branch;
- Prisma/Client/Node/TypeScript versions;
- ordered 52 models, ordered 41 enums;
- 76 sorted migration directories and canonical recursive digest;
- schema, generator/datasource, comment-lines, seed hashes;
- dependency baseline count/hash 260; ownership 386/782/hash; ports 0/2/0/0;
- exact 15 executable single-schema consumers and historical literal set;
- protected-surface status/hashes;
- whole-file hashes for API, Mobile routes, Admin routes, and scripts docs;
- for `DATABASE.md`, whole-file hash plus a second hash after normalizing only
  its source-of-truth sentence, and a hash of its generated model-table block.

No schema, secret, connection string, temp absolute path, or environment value
is copied into the report.

- [ ] **Step 3: Build and test the DMMF fingerprint tool GREEN**

Add `prisma-dmmf-fingerprint.test.ts` first and prove RED for the missing tool.
Cover deterministic projection, key ordering, model/enum normalization,
preserved field/enum-value/compound-key order, plain-data validation,
OS-temp-only atomic output, path aliases/junctions, hostile objects, and fixed
non-reflective failure. Implement `dmmf-fingerprint.cjs` with Node built-ins and
the installed `@prisma/client` only, then make the full focused suite GREEN.

Do not persist a base DMMF JSON between checkpoints. This tool is durable, but
the actual before/after comparison is one atomic Task 2 operation.

- [ ] **Step 4: Add and test the exact manifest GREEN**

Create `prisma-schema-layout.json` with the exact design file/model/enum lists,
52-entry `modelOrder`, `_base.prisma`, and hard-coded full
`splitBaseRevision`. Do not put DMMF, seed, migration, comment, or whole-schema
hashes in the permanent manifest; they are R2-only scope evidence and must not
block a legitimate later schema/migration phase.

Add `prisma-r2-manifest.test.ts`. It validates the manifest as plain exact data,
52/41 uniqueness, registry equality, model order, exact owners/file names,
`insights` absence, hard-coded provenance SHA, and deterministic algorithms.
The test reads the still-live single schema and is GREEN in Task 1; Task 2
changes it mechanically to use the folder loader.

- [ ] **Step 5: Build the R2-only scope verifier GREEN**

Add `r2-schema-scope.cjs` plus `prisma-r2-schema-scope.test.ts`. The CLI is not
an automatic fixed-base assertion; its tests exercise injected/OS-temp repos.
When explicitly invoked with `--base-ref <exact R2_BASE>`, it validates the full
committed/index/worktree change set against the plan's allowlist, exact
Dockerfile delta, protected surfaces, seed/migration/test-hunk policy, and
report output. It also parses generator/datasource/enum/model top-level blocks
with their immediately leading comment groups and requires every candidate
block body to equal its R2-base block after line-ending normalization only;
missing, duplicate, renamed, or changed blocks/comments fail. Pin the one
authorized base internally. Require full Git history only for this explicitly
invoked local verifier; CI's ordinary `npm test` must not need the historical
object. Apply the same atomic, realpath, alias, plain-data, and non-reflective
output discipline as the existing R1 verifier.

- [ ] **Step 6: Run the fully green Task 1 gates**

```powershell
cd backend
node --test -r ts-node/register test/prisma-dmmf-fingerprint.test.ts `
  test/prisma-r2-manifest.test.ts `
  test/prisma-r2-schema-scope.test.ts
npm run architecture
npm run check
npm run build
npm test
npm run smoke:health
```

Then docs-sync check, docs-verify, diff-check, cleanup audit, exact scope audit,
and independent read-only review. Fix findings and re-review. Commit only a
fully green Task 1 candidate:

```text
test: freeze modular monolith R2 schema contract
```

Do not begin Task 2 until status is clean and the ignored report records the
commit/scope. No failing loader/layout test is present at this checkpoint.

## Task 2: Split the Schema and Migrate Every Live Consumer

**Purpose:** Atomically create the native schema folder, delete the old source,
and update every legitimate reader while proving semantic equivalence.

**Allowed tracked files:** Task 2 entries in the Exact Target and Consumer Map.
No Backend application source, seed, migration, package, Mobile/Admin, workflow,
Compose, or deployment file may change.

- [ ] **Step 1: Reconfirm Task 1 checkpoint and protected hashes**

Require the Task 1 commit, clean status, `R2_BASE` ancestry, unchanged source
facts, 52/41/76 counts, unchanged seed/migration/doc hashes, and all Task 1
tests/gates still GREEN.

- [ ] **Step 2: Add the loader/layout contracts, prove RED, then close loader GREEN**

Create `prisma-schema-files.test.ts` and
`architecture-r2-schema-layout.test.ts` before production edits. The loader
suite covers deterministic order, combined text/metadata, complete-batch
validation, malformed/plain-data limits, path containment, junction/symlink/
reparse escapes, aliases, unexpected files/extensions, and fixed
non-reflective failure. The layout test is a permanent current-state invariant
only: exact 14 files, manifest/registry agreement, base contents, unique
model/enum coverage, config/Docker discovery, active-reader absence, and no
deprecated package fallback. It must not inspect Git history, `R2_BASE`,
protected paths, seed/migration history, or pre-existing test hunks.

Run both test files before creating the loader/folder. Require genuine RED:
loader `MODULE_NOT_FOUND` plus layout failures for the old file and missing
folder/config/Docker contract. Do not run `npm test` or commit while RED.

Create `backend/scripts/prisma/schema-files.cjs` with the fail-closed behavior
in the design. It may use Node built-ins only. Validate the full manifest and
complete file batch before returning any text. Resolve real paths and reject
reparse/symlink escape; never reflect attacker-controlled values from failures.

Run syntax and focused tests:

```powershell
node --check scripts/prisma/schema-files.cjs
node --test -r ts-node/register test/prisma-schema-files.test.ts
```

All tests must pass. Do not weaken containment tests on Windows.
The layout suite remains intentionally RED until Steps 3-6 finish; no
checkpoint or broad gate is allowed in that intermediate state.

- [ ] **Step 3: Perform the mechanical split**

Extract the immutable base schema to a unique OS-temp file with `git show`.
Create the 14 exact target files. Move every generator, datasource, enum,
model, doc comment, line comment, attribute, relation, index, and whitespace
inside its block without semantic editing. Delete `schema.prisma` in the same
working change.

Use the manifest as the only assignment source. Do not alphabetize fields,
rewrite comments, change quote style, reformat blocks, or add schema syntax.

- [ ] **Step 4: Update discovery and Docker packaging**

Change only:

```typescript
schema: "prisma/schema"
```

in `prisma.config.ts`.

In `backend/Dockerfile`, add only:

```dockerfile
COPY prisma.config.ts ./
```

beside the build-stage Prisma copy, and:

```dockerfile
COPY --from=build /app/prisma.config.ts ./
```

beside the runtime Prisma copy. Assert the remaining Dockerfile is byte-equal
to Task 1 evidence after removing those two lines.

- [ ] **Step 5: Migrate repository tooling to the loader**

- Update ownership scan's two live schema reads to the canonical loader.
- Update docs sync to use combined schema text and manifest `modelOrder`; do not
  change any renderer output contract.
- Update contributor-history migration smoke to copy the schema directory
  recursively and pass the directory as `schemaPath`.
- Update the architecture ownership fixture to copy the exact folder and
  manifest or inject the loader through its existing test boundary. It must not
  recreate `schema.prisma`.

Add focused tests for each changed path and prove RED/GREEN when practical.

- [ ] **Step 6: Migrate existing test readers mechanically**

Create `backend/test/support/live-prisma-schema.ts`, a typed adapter over the
canonical loader. Replace direct single-file reads in the 10 listed behavioral
tests with `readLivePrismaSchema()`. Make the analogous fixture change in
`architecture-ownership.test.ts`.

Audit the diff from the Task 1 checkpoint. For every pre-existing test, allow
only the helper import, removal of filesystem/path imports that became unused,
and direct-read replacement. Fail if any assertion, expected value, fixture,
literal, timeout, skip, or test selection changes.

- [ ] **Step 7: Prove layout and schema equivalence before any closeout gate**

Run focused suites:

```powershell
node --test -r ts-node/register test/prisma-schema-files.test.ts
node --test -r ts-node/register test/prisma-dmmf-fingerprint.test.ts
node --test -r ts-node/register test/architecture-r2-schema-layout.test.ts
node --test -r ts-node/register test/architecture-ownership.test.ts `
  test/admin-auth-session-security.test.ts `
  test/admin-rbac-audit.test.ts `
  test/auth-refresh-wiring.test.ts `
  test/contribution-history-migration.test.ts `
  test/financial-ledger.test.ts `
  test/legacy-finance-removal.test.ts `
  test/marketplace-presenter.test.ts `
  test/outbox-logic.test.ts `
  test/provider-chat-logic.test.ts `
  test/reference-catalogs.test.ts
```

With a process-scoped non-secret local placeholder `DATABASE_URL`, perform one
atomic before/after equivalence operation in a unique OS-temp directory:

```powershell
# Extract the base schema binary-safely from R2_BASE to OS temp.
npx prisma generate --schema <unique-temp-base-schema>
node scripts/prisma/dmmf-fingerprint.cjs --output <unique-temp-base-dmmf>

npx prisma validate
npx prisma generate
node scripts/prisma/dmmf-fingerprint.cjs --output <unique-temp-candidate-dmmf>

npx prisma migrate diff --exit-code `
  --from-schema-datamodel <unique-temp-base-schema> `
  --to-schema-datamodel prisma/schema
```

Require base and candidate DMMF JSON/hashes/counts byte-identical and migrate
diff exit 0 with `No difference detected`. The projection covers public
generated-client model/enum metadata, primary/unique metadata, relations,
defaults, native types, documentation, and flags. Ordinary `@@index` semantics
are proved by migrate diff and block/hash checks, not DMMF. Leave the candidate
client generated, delete both temp DMMF files/base schema in `finally`, verify
the unique temp directory is gone, and remove the placeholder immediately.

- [ ] **Step 8: Prove frozen artifacts and active-reader completion**

- Seed hash equals Task 1/R2 base.
- Migration directory list and recursive content hash equal Task 1/R2 base.
- No migration path was added/deleted/modified.
- `rg` finds no active single-file read outside the exact historical/negative
  allowlist.
- Dependency and ownership baseline files are byte-identical to Task 1.
- Fresh ownership candidate is exactly 386 records/782 occurrences.
- Update the database source-of-truth sentence to
  `backend/prisma/schema/`. Then `node scripts/docs-sync.mjs` must produce no
  additional generated-doc byte change; follow with `--check` and
  `docs-verify`.
- API/Mobile-route/Admin-route/SCRIPTS whole-file hashes equal Task 1.
- `DATABASE.md` equals Task 1 after normalizing only the exact source-path
  sentence, and its generated model-table block hash is identical.

If docs sync changes any generated file, stop and diagnose ordering/parser
semantics; do not accept or manually restore unexplained drift.

- [ ] **Step 9: Run Task 2 gates**

```powershell
npm run architecture
npm run check
npm run build
npm test
npm run smoke:contributor-history-migration
npm run smoke:guest-phone-migration
npm run smoke:health
npm audit --audit-level=high
npm audit --omit=dev --audit-level=high
```

From the repository root:

```powershell
node --test scripts/check-r0-scope.test.mjs
node backend/scripts/prisma/r2-schema-scope.cjs --check `
  --base-ref 8ba0db78ac669bd6d17de878b77a4d1e6c5e542d
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

The R0 scope unit tests remain historical and must stay green, but its live
fixed-base check is not an R2 gate and must not be widened. For R2 scope, use
the explicit `R2_BASE` allowlist audit from this plan.

Audit cleanup independently after each managed smoke.

- [ ] **Step 10: Independent review and checkpoint commit**

Freeze file hashes/status and request a read-only review covering:

- every schema block and comment against R2 base;
- manifest/registry/enum ownership;
- loader security and deterministic behavior;
- config and Docker discovery;
- migrate diff/DMMF/docs/seed/migration equality;
- mechanical test changes and protected scope;
- migration-smoke folder behavior.

Fix findings with explicit RED/GREEN rounds and re-review. Then commit the
stable implementation:

```text
refactor: split Prisma schema by model ownership
```

The commit must include only the reviewed Task 2 files. Verify clean status and
append the commit SHA to the ignored report.

## Task 3: Full Runtime Verification and R2 Receipt

**Purpose:** Prove the committed schema folder works across every project
surface and in the production-shaped container, then record local R2 closure.

**Allowed tracked files:** active R2 receipt/navigation Markdown only. Any code
fix requires reopening Task 2 scope through a reviewed contract amendment.

- [ ] **Step 1: Protected preflight from the committed Task 2 candidate**

Require clean status and audit `R2_BASE..HEAD`:

- diff equals the reviewed R2 allowlist;
- no `backend/src`, migration, seed, package/lock, Mobile/Admin source/test,
  workflow, Compose/deploy change;
- Dockerfile delta is exactly the two config-copy lines;
- 52 models, 41 enums, 76 migrations;
- seed/migration hashes match Task 1; generated docs match except the reviewed
  one-line database source-path update;
- dependency 260, ownership 386/782, ports 0/2/0/0.

Run the explicit R2-only scope verifier against full `R2_BASE`; do not invoke
the R0 live scope check or place fixed-base assertions in the permanent layout
test.

- [ ] **Step 2: Run exhaustive Backend and Prisma gates**

```powershell
cd backend
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npx prisma generate
npm run smoke:contributor-history-migration
npm run smoke:guest-phone-migration
npm run smoke:all
npm audit --audit-level=high
npm audit --omit=dev --audit-level=high
```

Use a process-scoped local placeholder only if bare Prisma validation needs an
unset `DATABASE_URL`; document the bare result and successful non-connecting
validation, then remove it. Managed smoke owns its isolated databases and must
clean every DB/process/listener/Redis/bucket/temp resource.

- [ ] **Step 3: Run unchanged Admin and Mobile gates**

Admin Web:

```powershell
cd admin-web
npm run typecheck
npm test
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
```

Mobile:

```powershell
cd mobile
node ..\scripts\check-mobile-boundaries.test.mjs
node ..\scripts\check-mobile-boundaries.mjs --check-baseline
flutter analyze --no-pub
flutter test --no-pub
```

Record plugin warnings honestly and restore only exact test-generated desktop
registrants if Flutter changes them. Do not edit application code to silence an
environment warning.

- [ ] **Step 4: Run docs and source-of-truth gates**

```powershell
cd <repository-root>
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Recompute and report exact counts/hashes. API/Mobile-route/Admin-route/SCRIPTS
must equal Task 1 byte-for-byte. `DATABASE.md` must equal Task 1 after
normalizing only the exact source-path sentence, and its generated model-table
block hash must be identical.

- [ ] **Step 5: Commit an immutable runtime candidate**

Before Docker build, update only the preliminary active receipt Markdown with
the implementation checkpoint and truthful local results, review docs, and
create a docs-only candidate commit. Its full 40-character SHA becomes the
image revision. Do not claim phone PASS yet.

- [ ] **Step 6: Build and run the production-shaped Docker image**

Build from the clean immutable commit using its full SHA:

```powershell
docker build --build-arg AARAST_GIT_REVISION=<full-candidate-sha> `
  -t aarast-backend:r2-final-<short-sha> backend
```

Verify inside the image:

- OCI revision label equals the full candidate SHA;
- `/app/prisma.config.ts` exists;
- `/app/prisma/schema/` contains the exact 14 files;
- `/app/prisma/schema.prisma` is absent;
- `npx prisma validate` and startup `migrate deploy` discover the folder;
- no old config fallback exists.

Use this exact local phone cutover contract:

1. Require container `aarast-backend-r1-phone` to be running image
   `aarast-backend:r1-final-d2530c5c` on network `aarast_default`, host port
   3120, with `/live` and `/ready` green. Stop on drift.
2. Reuse that container's existing database/environment and already-provisioned
   owner phone account. R2 has an empty migrate diff, and creating a new phone
   account/fixture would add unrelated state. The owner enters credentials only
   in the phone application; no command/report prints or persists them.
3. In PowerShell, read `.Config.Env` from `docker inspect` into memory without
   printing it. Reject any entry containing CR/LF. Write it to a unique OS-temp
   env file with inheritance removed and access granted only to the current
   Windows identity. Delete it in `finally` and assert absence.
4. Run `aarast-backend-r2-phone-probe` from the immutable R2 image on
   `aarast_default` with that env file and
   `127.0.0.1:3121:3000`. Leave the R1 container running on 3120. Require
   startup `migrate deploy`, `/live`, `/ready`, revision label, zero restarts,
   and no Prisma-discovery/fatal/unhandled/circular/TypeError log match. Do not
   submit credentials to the probe or mutate phone data.
5. Stop and remove only the successful probe. Stop—but do not remove—the R1
   phone container. Start `aarast-backend-r2-phone` from the same immutable
   image on `aarast_default` with `0.0.0.0:3120:3000` and the same in-memory/
   temp environment. Re-run health/readiness/revision/restart/log checks through
   both localhost and the owner-confirmed LAN URL. The last accepted R1 phone
   URL was `http://10.185.93.102:3120`; before cutover require that IPv4 still
   belongs to a local non-loopback interface and is reachable. If DHCP changed
   it, stop and obtain the owner's current phone-facing LAN IPv4 before
   continuing; do not silently guess a different interface.
6. On any final-start or health failure, remove only
   `aarast-backend-r2-phone`, restart `aarast-backend-r1-phone`, prove its two
   health endpoints on 3120, delete the temp env file, and report the blocker.
7. After R2 owner PASS, keep the stopped R1 container and image as rollback
   until the owner separately authorizes their removal.
8. If the owner phone checkpoint fails for any behavior attributable to the R2
   candidate, immediately remove only `aarast-backend-r2-phone`, restart
   `aarast-backend-r1-phone`, prove R1 `/live` and `/ready` through the same LAN
   URL, keep both images, and mark R2 blocked. Do not wait for receipt review to
   roll back a failed phone candidate.

The exact non-secret command skeleton is:

```powershell
$oldName = 'aarast-backend-r1-phone'
$probeName = "aarast-backend-r2-phone-probe-$([guid]::NewGuid().ToString('N'))"
$newName = 'aarast-backend-r2-phone'
$network = 'aarast_default'
$image = 'aarast-backend:r2-final-<short-sha>'
$candidateSha = '<full-candidate-sha>'
$phoneBaseUrl = 'http://10.185.93.102:3120'
$phoneEnv = Join-Path ([IO.Path]::GetTempPath()) `
  ("aarast-r2-phone-{0}.env" -f ([guid]::NewGuid().ToString('N')))
$probeId = $null
$newId = $null
$oldStopped = $false
$newValidated = $false
$cutoverFailed = $false
$cleanupFailed = $false

function Wait-AarastHealth([string]$baseUrl) {
  $deadline = [DateTime]::UtcNow.AddSeconds(90)
  do {
    try {
      $live = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 `
        -Uri "$baseUrl/live"
      $ready = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 `
        -Uri "$baseUrl/ready"
      if ($live.StatusCode -eq 200 -and $ready.StatusCode -eq 200) { return }
    } catch { }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  throw 'ERROR - phone candidate health check failed'
}

function Assert-AarastContainer([string]$name, [string]$expectedImage) {
  $data = @((docker inspect $name | ConvertFrom-Json))
  if ($LASTEXITCODE -ne 0 -or $data.Count -ne 1) {
    throw 'ERROR - phone container inspection failed'
  }
  if ($data[0].Config.Image -ne $expectedImage -or
      $data[0].RestartCount -ne 0 -or
      $data[0].State.Running -ne $true -or
      $data[0].Config.Labels.'org.opencontainers.image.revision' -ne $candidateSha) {
    throw 'ERROR - phone container identity mismatch'
  }
  $logs = (docker logs --since 10m $name 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or
      $logs -match '(?i)(prisma.*schema.*not found|fatal|unhandled|circular|TypeError)') {
    throw 'ERROR - phone container log gate failed'
  }
}

# Inspect and validate old image/network/port/health without rendering Env.
try {
$phoneHost = ([uri]$phoneBaseUrl).Host
$localV4 = @(Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' } |
  ForEach-Object IPAddress)
if ($localV4 -notcontains $phoneHost) {
  throw 'ERROR - owner-confirmed phone LAN address is no longer local'
}
foreach ($reservedName in @($probeName, $newName)) {
  $null = docker container inspect $reservedName 2>$null
  if ($LASTEXITCODE -eq 0) {
    throw 'ERROR - reserved phone container name already exists'
  }
}
$old = @((docker inspect $oldName | ConvertFrom-Json))
if ($old.Count -ne 1 -or $old[0].Config.Image -ne 'aarast-backend:r1-final-d2530c5c') {
  throw 'ERROR - R1 phone rollback identity mismatch'
}
if ($null -eq $old[0].NetworkSettings.Networks.$network -or
    $old[0].HostConfig.PortBindings.'3000/tcp'[0].HostPort -ne '3120') {
  throw 'ERROR - R1 phone network or port mismatch'
}
Wait-AarastHealth $phoneBaseUrl
if ($old[0].Config.Env.Where({ $_ -match "[\r\n]" }).Count -ne 0) {
  throw 'ERROR - phone environment is not line-safe'
}
[IO.File]::WriteAllLines(
  $phoneEnv,
  [string[]]$old[0].Config.Env,
  [Text.UTF8Encoding]::new($false)
)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl = [Security.AccessControl.FileSecurity]::new()
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
  $identity,
  [Security.AccessControl.FileSystemRights]::FullControl,
  [Security.AccessControl.AccessControlType]::Allow
))
Set-Acl -LiteralPath $phoneEnv -AclObject $acl

$probeId = ([string](docker run -d --name $probeName --network $network `
  --env-file $phoneEnv -p 127.0.0.1:3121:3000 $image)).Trim()
if ($LASTEXITCODE -ne 0 -or $probeId -notmatch '^[0-9a-f]{64}$') {
  $probeId = $null
  throw 'ERROR - phone probe start failed'
}
Wait-AarastHealth 'http://127.0.0.1:3121'
Assert-AarastContainer $probeId $image
$null = docker rm -f $probeId
if ($LASTEXITCODE -ne 0) { throw 'ERROR - phone probe cleanup failed' }
$probeId = $null

$null = docker stop $oldName
if ($LASTEXITCODE -ne 0) { throw 'ERROR - R1 phone stop failed' }
$oldStopped = $true
$newId = ([string](docker run -d --name $newName --network $network `
  --env-file $phoneEnv -p 0.0.0.0:3120:3000 $image)).Trim()
if ($LASTEXITCODE -ne 0 -or $newId -notmatch '^[0-9a-f]{64}$') {
  $newId = $null
  throw 'ERROR - R2 phone start failed'
}
Wait-AarastHealth 'http://127.0.0.1:3120'
Wait-AarastHealth $phoneBaseUrl
Assert-AarastContainer $newId $image
$newValidated = $true
} catch {
  $cutoverFailed = $true
} finally {
  if ($null -ne $probeId) {
    $null = docker rm -f $probeId 2>$null
    if ($LASTEXITCODE -ne 0) { $cleanupFailed = $true }
    $probeId = $null
  }
  if (-not $newValidated -and $null -ne $newId) {
    $null = docker rm -f $newId 2>$null
    if ($LASTEXITCODE -ne 0) { $cleanupFailed = $true }
    $newId = $null
  }
  if ($oldStopped -and -not $newValidated) {
    $null = docker start $oldName
    if ($LASTEXITCODE -ne 0) {
      $cleanupFailed = $true
    } else {
      try { Wait-AarastHealth $phoneBaseUrl } catch { $cleanupFailed = $true }
    }
    $oldStopped = $false
  }
  if (Test-Path -LiteralPath $phoneEnv) {
    Remove-Item -LiteralPath $phoneEnv -Force
  }
  if (Test-Path -LiteralPath $phoneEnv) {
    $cleanupFailed = $true
  }
}
if ($cleanupFailed) { throw 'ERROR - phone cutover cleanup failed' }
if ($cutoverFailed -or -not $newValidated) {
  throw 'ERROR - R2 phone cutover failed and R1 was restored'
}
```

Never include the generated env file, inspect payload, database URL, phone,
OTP, password, JWT, media key, or Redis URL in a report/tool output. Require:

- `/live` HTTP 200 and expected service status;
- `/ready` HTTP 200 with database/dependencies healthy;
- the owner's login/OTP plus authenticated home/core-flow checkpoint in Step 7,
  followed by a sanitized method/path/status-only log audit proving login and
  authenticated requests succeeded;
- zero fatal, Prisma discovery, migration, circular, or unhandled errors;
- restart count zero.

- [ ] **Step 7: Owner phone checkpoint**

Ask the owner to test the running R2 candidate from the phone: login/OTP, home,
one core read/write flow, notifications, and messaging if available. Record only
PASS/FAIL and the image/candidate identity; never record credentials or tokens.

Do not mark R2 complete or start R3 before explicit owner PASS.

On owner FAIL, inspect `aarast-backend-r2-phone` without rendering environment,
require its image and full revision label equal the Task 3 candidate, capture
its 64-hex container ID, and remove only that ID. Then start the preserved R1
container and run `Wait-AarastHealth` on the owner-confirmed LAN URL. If identity
does not match, stop instead of deleting by name. Report R2 blocked and never
leave a failed candidate serving port 3120.

- [ ] **Step 8: Final receipt and independent sign-off**

After owner PASS, update only:

- `docs/project/STATUS.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `ARCHITECTURE.md`
- `docs/README.md`
- `docs/backend/DATABASE.md`
- `docs/qa/README.md`
- `CHANGELOG.md`
- R2 design/plan status fields

Record exact base/candidate/branch, changed path manifest, 52/41/76, equivalence
hashes, exact commands/results, Docker image/runtime evidence, owner checkpoint,
known warnings, and explicit `remote CI not run/no push/no merge`. Mark R3 as
next/not started.

Run docs/protected/diff gates, then request a final independent source,
contract, runtime, and receipt review. Fix any finding through the proper task
scope and rerun proportional/full gates. Commit the final docs-only receipt:

```text
docs: close modular monolith R2 locally
```

Verify clean worktree. Leave the R2 server available for the owner unless they
ask to stop it. Do not push or merge.

## Failure and Stop Rules

Stop immediately and do not regenerate/accept evidence when any of these occur:

- current HEAD/base/branch differs from the contract;
- model/enum/migration counts differ from 52/41/76 before implementation;
- manifest conflicts with the ownership registry or contains an unapproved
  empty owner;
- Prisma folder support differs under the locked 6.19.3 toolchain;
- migrate diff is non-empty or DMMF canonical JSON differs;
- seed, migration, dependency/ownership baseline, generated database table, or
  generated-doc hash changes outside the exact database source-path sentence;
- an active reader still requires `schema.prisma`;
- Docker does not discover the folder from copied `prisma.config.ts`;
- a behavioral test needs more than a mechanical read-helper change;
- any Backend application, route, API, Mobile/Admin, workflow, Compose, or
  deployment behavior change appears;
- a managed smoke or container leaves resources behind;
- an independent reviewer or owner phone test reports a blocker.

Do not fix a blocker with a compatibility file, duplicated config, blind
baseline regeneration, ignored test, widened allowlist, or undocumented scope
expansion.

## Plan Self-Review Checklist

- [ ] Base is pinned to full `8ba0db78...` SHA and same-branch/no-push policy.
- [ ] Live truth is 52 models, 41 enums, 76 migrations.
- [ ] Target count is unambiguous: 13 owner files + `_base` = 14.
- [ ] Every model and enum has exactly one named owner file.
- [ ] `insights` absence is intentional and tested.
- [ ] Manifest and loader are deterministic, fail-closed, and containment-safe.
- [ ] Old schema file and all compatibility/fallback strategies are forbidden.
- [ ] Docker config discovery is fixed in both stages with exact lines only.
- [ ] Seed split is explicitly deferred and seed remains byte-identical.
- [ ] Existing test changes are mechanical and machine-audited.
- [ ] Migrate diff and normalized DMMF equivalence are both required.
- [ ] Comments, generator, datasource, migrations, seed, baselines, and
  generated docs are independently frozen; the database source-path sentence
  is the sole exact documentation exception.
- [ ] Migration rehearsal uses the folder recursively.
- [ ] R0 scope tool is not widened or misrepresented as an R2 gate.
- [ ] Full Backend/Admin/Mobile/docs/audit/smoke gates are executable.
- [ ] Docker build is bound to an immutable full-SHA commit.
- [ ] Owner phone test and independent final review gate R2 completion.
- [ ] No R3 ports/modules, R4-R8 business moves, R9 Mobile, or R10 Admin work is
  pulled forward.
- [ ] Receipts distinguish local evidence from unrun remote CI.

## Execution Handoff

After this plan is independently reviewed and committed, the implementation
session must re-read the design, plan, AGENTS instructions, and relevant active
docs; verify `R2_BASE` ancestry and planning-checkpoint HEAD; then execute Task
1 only. Use a fresh implementer and a separate read-only reviewer for every
task. Do not infer authorization to push or merge from authorization to create
local checkpoint commits. Do not begin R3 merely because R2 code gates pass;
R2 closes only after immutable Docker runtime evidence, independent sign-off,
and the owner's phone checkpoint.
