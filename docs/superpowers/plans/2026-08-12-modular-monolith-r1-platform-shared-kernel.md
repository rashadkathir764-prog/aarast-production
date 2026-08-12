# Modular Monolith R1 Platform and Shared Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete R1 by dissolving the legacy Backend infrastructure roots into `platform/`, establishing the dependency-safe `shared-kernel/`, and updating every consumer without changing application behavior, API contracts, database structure, deployment artifacts, Mobile, or Admin Web.

**Architecture:** R1 is one ordered migration with six green checkpoints. Files are moved to their final platform/shared-kernel homes with no old-path facades. Existing platform-to-business debt is path-relocated only when it maps one-to-one to R0 debt; shared-kernel violations are fixed at the source. Architecture registries, global-module provenance, package runtime paths, and docs are updated in the same checkpoint that changes the corresponding source.

**Tech Stack:** NestJS 11, TypeScript 5.9, Prisma 6.19.3 with `Prisma.Decimal`, Node.js 22 in CI, dependency-cruiser 18.1.0, Node's built-in test runner, Flutter 3.41.7, GitHub Actions, Markdown documentation.

**Design Source:** `docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md`

## Global Constraints

- Owner decision on 2026-08-12 authorizes R1 and later modular-monolith phases
  to continue locally on the same `modular-monolith` branch without merging
  between phases. Immutable R0 candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456` is `R1_BASE` for every R1 audit.
- Do not create another execution branch/worktree and do not merge. Do not push
  `modular-monolith` during staged R1 execution unless the owner separately
  authorizes it, because PR #76 currently points at that branch and a push
  would expand the reviewed R0 candidate.
- The owner authorizes local checkpoint commits required by this plan. Push,
  pull-request mutation, and merge remain separately gated Git actions.
- Preserve all HTTP methods/paths/auth flags, response shapes, error codes/messages, Arabic text, permission decisions, privacy behavior, transaction isolation levels, lock order, advisory locks, retry/backoff, scheduler cadence, environment validation, and health readiness semantics.
- Do not change `backend/prisma/schema.prisma`, `backend/prisma/migrations/**`, `mobile/lib/**`, `mobile/test/**`, `mobile/integration_test/**`, `admin-web/src/**`, `deploy/**`, Dockerfiles, or Compose files.
- Keep exactly 52 Prisma models and 76 committed migrations. Derive both counts from source at verification time.
- Keep `PrismaModule` global in R1. Exactly two approved `@Global()` modules must remain, and `forwardRef()` must remain zero.
- Do not create business ports, business Nest module slices, repositories, schema folders, migrations, route handlers, DTOs, compatibility barrels, old-path re-exports, fallback imports, or duplicate old/new implementations.
- Existing behavioral tests may receive only mechanical import/export/require
  path edits and moved-source path-literal edits required by R1. The sole
  reviewed exception is the exact two-file QA precondition below: strengthen
  one stale outbox event assertion and wire the current real sharing-history
  dependency. Do not make any other assertion, expected-value, fixture,
  Arabic/error string, setup, timeout, skip, or test-selection change.
- Additive R1 tests are allowed and required. Protect every pre-existing test edit with the test-change audit in Task 6.
- A dependency or ownership baseline is a debt ledger, not permission. Never regenerate a baseline without the exact before/after semantic audit specified below.
- Never place an absolute local path, environment value, token, credential, URL secret, database identifier, admin identifier, or production identifier in a baseline, plan receipt, test fixture, or diagnostic.
- Any discovered behavior contradiction stops the current task. Update the design and this plan in the same reviewed change before continuing; do not improvise around it.

## Per-Task Checkpoint Protocol

Every Task 1-6 is executed and accepted separately, using the same discipline
as R0:

1. finish only the current task and its exact focused/full gates;
2. run the applicable managed quick server smoke (`smoke:health` at minimum,
   plus a task-specific smoke when runtime behavior moved);
3. request an independent read-only review and fix every validated finding at
   its root before acceptance;
4. create one clean local checkpoint commit with an evidence report outside
   tracked source;
5. stop and wait for the owner's application test and explicit `continue`
   before starting the next task.

The owner's application test is a continuation gate, not a substitute for
automated checks. Task 1 has no runtime source change, but still establishes a
green baseline server smoke before the first relocation task. The same
checkpoint protocol applies to later modular-monolith phases unless the owner
explicitly changes it.

## R1 Completion Contract

R1 is complete only when all conditions are true on one immutable candidate:

1. `backend/src/common/`, `backend/src/prisma/`, `backend/src/outbox/`, root `backend/src/health.controller.ts`, and legacy `backend/src/health/` are absent.
2. The target file map in the R1 design exists with no compatibility files at old paths.
3. `platform/otp-transport` contains delivery-only production OpenWA/WhatsApp
   adapters; `auth/otp-channel.ts` contains the identity delivery contract,
   development echo channel, and production six-digit code generator.
4. `shared-kernel` imports no `platform` or business source, and contains Money, phone, privacy/application identity, and time helpers.
5. `modules/backoffice/domain/admin-permissions.ts` preserves the exact permission matrix without creating a Backoffice module.
6. Backend architecture passes with zero new semantic dependency/ownership debt, zero cycles, zero `forwardRef`, and exactly two approved globals.
7. R0's phase-specific `r0-scope` CI job is removed; every other CI job and gate remains present and unweakened.
8. Existing generated route/API/database docs are byte-identical. `docs/SCRIPTS.md` may change only for the relocated `prod:reconcile-idempotency` command and any explicitly added R1 architecture-test command.
9. Backend checks, build, full tests, full managed smokes, Prisma validation, audits, Admin gates, Mobile gates, docs gates, and protected-surface audits all pass.
10. The receipt reports local evidence only; remote CI truth remains in immutable PR/workflow metadata.

## Target File Map

### Existing Planning Artifacts

- `docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md`
- `docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md`

### Create During R1

- `backend/test/architecture-r1-layout.test.ts`
- `backend/test/architecture-r1-baseline-relocation.test.ts`
- `backend/test/shared-kernel-money.test.ts`
- `backend/architecture/r1-relocation-map.json`
- `backend/scripts/architecture/r1-baseline-relocation.cjs`
- `backend/src/platform/otp-transport/otp-delivery.ts`
- `backend/src/platform/otp-transport/openwa-otp.channel.ts`
- `backend/src/platform/otp-transport/whatsapp-otp.channel.ts`

### Move to `backend/src/platform/`

- `common/config/{cors-options,cors-origins,runtime-environment}.ts` -> `platform/config/`
- `common/filters/global-exception.filter.ts` -> `platform/http/global-exception.filter.ts`
- `common/http/bounded-json-response.ts` -> `platform/http/bounded-json-response.ts`
- `common/pagination/list-query.dto.ts` -> `platform/http/list-query.dto.ts`
- `common/redis/{redis-io.adapter,resilient-throttler-storage}.ts` -> `platform/redis/`
- `common/observability/{metrics.controller,metrics,request-observability.middleware,sanitize-request-target}.ts` -> `platform/observability/`
- `common/prisma/serializable-transaction.ts` -> `platform/database/serializable-transaction.ts`
- `prisma/{prisma.module,prisma.service}.ts` -> `platform/database/`
- `health.controller.ts` -> `platform/health/health.controller.ts`
- `health/readiness.service.ts` -> `platform/health/readiness.service.ts`
- `common/idempotency/*` -> `platform/idempotency/`
- `outbox/*` -> `platform/outbox/`
- `auth/{openwa-otp-config,openwa-transient-text,whatsapp-otp-config}.ts` -> `platform/otp-transport/`

### Move to `backend/src/shared-kernel/`

- `common/validation/money.ts` -> `shared-kernel/money/money.ts`, then implement the approved value object in place
- `common/phone/phone-normalizer.ts` -> `shared-kernel/phone/phone-normalizer.ts`
- `common/privacy/review-identity.ts` -> `shared-kernel/privacy/review-identity.ts`
- `users/application-user-identity.ts` -> `shared-kernel/privacy/application-user-identity.ts`
- `admin/admin-privacy.ts` -> `shared-kernel/privacy/admin-notification-privacy.ts`
- `common/time/business-day.ts` -> `shared-kernel/time/business-day.ts`

### Move to Business Target

- `common/admin/admin-permissions.ts` -> `modules/backoffice/domain/admin-permissions.ts`

### Modify

- `docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md`
- `docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md`
- `backend/scripts/smoke/phase2-notification-preferences-smoke.ts` only through the exact QA precondition
- `backend/scripts/smoke/phase2-conversation-revocation-smoke.ts` only through the exact QA precondition
- `backend/src/auth/otp-channel.ts`
- every live source/test/smoke import or moved-source path literal returned by the exact inventories in Task 1
- `backend/src/app.module.ts`
- `backend/src/main.ts`
- `backend/package.json`
- `backend/.dependency-cruiser.cjs`
- `backend/.dependency-cruiser-known-violations.json`
- `backend/architecture/ownership-registry.json`
- `backend/architecture/ownership-baseline.json` only when the audited current scan requires a path relocation
- `backend/scripts/architecture/ownership-scan.cjs`
- `backend/scripts/architecture/ports-scan.cjs`
- `backend/test/architecture-dependencies.test.ts`
- `backend/test/architecture-ownership.test.ts`
- `backend/test/architecture-ports.test.ts`
- `.github/workflows/ci.yml`
- `ARCHITECTURE.md`
- `AGENTS.md` only if the short guard needs an R1 path/status correction
- `docs/README.md`
- `docs/backend/README.md`
- `docs/qa/README.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md` only after all gates pass
- `CHANGELOG.md` only after all gates pass
- `docs/SCRIPTS.md` only through `node scripts/docs-sync.mjs`

### Explicitly Untouched

- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/**`
- business logic inside legacy business services except mechanical import paths
- `mobile/lib/**`, `mobile/test/**`, `mobile/integration_test/**`
- `admin-web/src/**`
- `deploy/**`, Dockerfiles, `docker-compose.yml`
- the R0 planning/spec artifacts except links/status that explicitly transition to R1

---

### Task 1: Freeze the R1 Base, Manifests, and Change Policy

**Files:**
- Modify: the R1 design and this plan to record the owner-approved same-branch
  checkpoint protocol
- Modify: `docs/README.md`, `ARCHITECTURE.md`,
  `docs/project/DECISIONS.md`, `docs/project/EXECUTION_PLAN.md`,
  `docs/project/STATUS.md`, and `CHANGELOG.md` only to transition active phase
  truth from closed R0 governance to R1 Task 1

**Interfaces:**
- Consumes: owner-approved R0 candidate metadata, live Git tree, R0 architecture baselines, R1 design.
- Produces: immutable `R1_BASE`, exact relocation/import inventories, protected hashes, and a fully green preflight receipt.

- [ ] **Step 1: Prove the owner-approved R0 candidate and resolve `R1_BASE`**

Run from the existing `modular-monolith` worktree. PR inspection is read-only;
do not fetch, push, merge, or rewrite the remote PR. Stop if the branch or
candidate revision differs from the owner's approved R0 checkpoint.

```powershell
$r1Base = '94b677b7b8e2219e0db2cbc553fa3d26b4876456'
$pr = gh pr view 76 --json state,headRefName,headRefOid,url | ConvertFrom-Json
if ($pr.state -ne 'OPEN' -or $pr.headRefName -ne 'modular-monolith') {
  throw 'PR #76 no longer represents the approved modular-monolith branch'
}
if ($pr.headRefOid -ne $r1Base) {
  throw 'Remote R0 candidate changed; stop before R1 implementation'
}
git cat-file -e "$r1Base^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'R1_BASE commit is unavailable locally' }
git merge-base --is-ancestor $r1Base HEAD
if ($LASTEXITCODE -ne 0) { throw 'R1_BASE is not an ancestor of current HEAD' }
$r1Base
```

Record `$r1Base`, the owner decision, and PR #76's unchanged remote head in the
Task 1 execution report/brief. Do not claim the open PR contains R1 commits.

- [ ] **Step 2: Verify execution workspace identity and cleanliness**

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --untracked-files=all
git diff --name-only $r1Base..HEAD
```

Expected:

- branch is exactly the owner-authorized `modular-monolith` branch;
- the R1 design/plan commits are the only intentional diff before implementation;
- worktree/index are clean;
- no application, schema, Mobile, Admin, or deployment path differs from `$r1Base`.

- [ ] **Step 3: Capture immutable source facts and protected hashes**

```powershell
$models = (Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+').Count
$migrations = (Get-ChildItem .\backend\prisma\migrations -Directory).Count
if ($models -ne 52) { throw "Expected 52 models, found $models" }
if ($migrations -ne 76) { throw "Expected 76 migrations, found $migrations" }
rg -n 'forwardRef\s*\(' .\backend\src
rg -n '@Global\(' .\backend\src
git diff --exit-code $r1Base -- backend/prisma mobile admin-web/src deploy docker-compose.yml
```

Expected: 52/76, zero `forwardRef`, exactly two globals, protected diff empty.

Capture SHA-256 hashes of generated docs and frozen route/schema/deployment files in the task report:

```powershell
$generatedDocs = @(
  'docs/backend/API_CONTRACT.md',
  'docs/backend/DATABASE.md',
  'docs/frontend/MOBILE_ROUTES.md',
  'docs/frontend/ADMIN_ROUTES.md',
  'docs/SCRIPTS.md'
)
Get-FileHash -Algorithm SHA256 $generatedDocs | Format-Table Path,Hash
```

- [ ] **Step 4: Capture exact old-path consumer inventories**

Run and save all raw matches plus the derived target/non-target sets in the
Task 1 report. Do not manually exclude a consumer. The only lexical false
positives are the exact Nest package controls asserted below; every other raw
match is a target legacy Aarast path.

```powershell
$oldImportPattern = 'common/|prisma/prisma\.(?:module|service)|outbox/|health\.controller|health/readiness|auth/(?:openwa-otp-config|openwa-transient-text|whatsapp-otp-config)|users/application-user-identity|admin/admin-privacy'
$rawOldImportMatches = @(
  rg -n --glob '*.{ts,js,cjs,mjs}' $oldImportPattern backend/src backend/test backend/scripts |
    Sort-Object
)
$nonTargetNestMatches = @(
  $rawOldImportMatches | Where-Object {
    $_.Contains('@nestjs/common') -or $_.Contains('@nestjs\/common')
  }
)
$expectedNonTargetNestMatches = @(
  'backend/test\architecture-ports.test.ts:113:',
  'backend/test\architecture-ports.test.ts:165:',
  'backend/test\sharing-self-leave.test.ts:6:'
)
if ($nonTargetNestMatches.Count -ne 3) {
  throw "Unexpected Nest lexical-match count: $($nonTargetNestMatches.Count)"
}
foreach ($prefix in $expectedNonTargetNestMatches) {
  if (-not ($nonTargetNestMatches | Where-Object { $_.StartsWith($prefix) })) {
    throw "Missing expected non-target Nest control: $prefix"
  }
}
$oldImportInventory = @(
  $rawOldImportMatches | Where-Object { $nonTargetNestMatches -notcontains $_ }
)
if ($rawOldImportMatches.Count -ne 251 -or $oldImportInventory.Count -ne 248) {
  throw 'R1 old-import inventory count drift'
}
$rawOldImportMatches
$oldImportInventory
$nonTargetNestMatches
rg -n 'dist/common/idempotency|src/common/|src/prisma/|src/outbox/|src/health/' backend backend/package.json docs .github scripts | Sort-Object
```

Every line must be classified as one of:

- production import;
- test/smoke import;
- moved-source path literal;
- architecture fixture intentionally representing a legacy path;
- historical documentation text that must remain historical.

The three `nonTargetNestMatches` are classified as **non-target lexical match
— preserve unchanged**. They cover Nest package declarations/diagnostics and
the real `@nestjs/common/constants` behavioral import; no R1 task may rewrite
them as Aarast legacy `common/` consumers.

Unclassified output is a stop signal.

- [ ] **Step 5: Capture the R0 semantic debt manifests**

Record:

```powershell
Push-Location .\backend
npm run architecture
node .\scripts\architecture\ownership-scan.cjs --check
Pop-Location
```

Extract and store in the orchestrator's execution report outside the tracked
repository:

- dependency baseline unique `rule|from|to` keys;
- the ten R0 `current-platform-no-business-contexts` edges;
- ownership 386 keys/782 occurrences and its reason/source counts;
- Mobile 269 records;
- global paths/count and `forwardRef` count.

The six platform-to-business debts expected to survive R1 are:

```text
platform/config/runtime-environment.ts -> auth/jwt-secret.ts
platform/health/readiness.service.ts -> media/media-storage.service.ts
platform/outbox/outbox.dispatcher.ts -> conversations/conversation-realtime.publisher.ts
platform/outbox/outbox.dispatcher.ts -> push/push-delivery.service.ts
platform/outbox/outbox.module.ts -> conversations/conversation-realtime.module.ts
platform/outbox/outbox.module.ts -> push/push.module.ts
```

The other four current platform edges must disappear through internal platform moves or the shared-kernel root fix.

- [ ] **Step 6: Run the green preflight gates**

```powershell
Push-Location .\backend
npm run check
npm run build
Pop-Location
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: PASS.

- [ ] **Step 7: Establish the baseline server and owner checkpoint**

Run the repository-managed health smoke without changing tracked environment
or test data:

```powershell
Push-Location .\backend
npm run smoke:health
Pop-Location
```

Expected: the managed isolated Backend starts, readiness/liveness assertions
pass, and the runner cleans up its process and temporary resources. Then:

- request independent Task 1 review;
- fix and re-review every validated finding;
- commit only the R1 contract correction and Task 1 evidence-bearing docs;
- stop for the owner's application baseline test and explicit continuation
  approval before Task 2.

---

### Task 2: Move the Platform Foundation and Health

**Files:**
- Create: `backend/test/architecture-r1-layout.test.ts`
- Create: `backend/test/architecture-r1-baseline-relocation.test.ts`
- Create: `backend/architecture/r1-relocation-map.json`
- Create: `backend/scripts/architecture/r1-baseline-relocation.cjs`
- Move: config, HTTP, Redis, observability, database, and health paths listed in Target File Map
- Modify: every exact source/test/smoke consumer from Task 1 for these groups
- Modify: `backend/src/app.module.ts`, `backend/src/main.ts`
- Modify: `backend/.dependency-cruiser.cjs`, known baseline, ownership registry/baseline when required
- Modify: ports/ownership scanners and architecture tests for canonical Prisma/global paths
- Modify: `backend/test/architecture-r1-layout.test.ts`

**Interfaces:**
- Preserves: health routes/responses, environment validation, metrics, exception mapping, Redis behavior, Prisma lifecycle/global wiring, serializable transaction behavior.
- Produces: green mixed-layout checkpoint with `platform/` active and only `common/idempotency`, shared-kernel candidates, and legacy `outbox` remaining.

- [ ] **Step 1: Create the R1 layout contract and prove RED before moving files**

Create `backend/test/architecture-r1-layout.test.ts` with helpers that resolve
paths from `backend/`, read UTF-8 source, and recursively collect TypeScript
files. Add tests for:

- exact Task 2 target and absent legacy paths;
- `PrismaModule` still decorated with the real Nest `@Global()`;
- `PrismaService` lifecycle methods still call `$connect`/`$disconnect`;
- no Task 2 consumer import contains an old path;
- the current mixed ownership roots are exactly `common`, `outbox`, and `platform` after the task;
- the ports scanner's required global set contains the new Prisma path and no old path.

Run the focused test and confirm the added assertions fail before any move.

- [ ] **Step 2: Specify the baseline relocation verifier and prove RED**

Create `backend/test/architecture-r1-baseline-relocation.test.ts` first. Its OS
temporary fixtures must prove:

- dependency keys compare as exact `rule|from|to` records;
- the one declared dependency rule rename maps
  `current-platform-no-business-contexts` to
  `platform-no-business-contexts`, while any other rule-name change fails;
- ownership records compare every semantic field plus `count`;
- exact source/target prefix relocation passes;
- removed keys and decreased counts pass;
- a new rule/target/cycle, unmatched addition, semantic-field change, or count
  increase fails;
- duplicate, malformed, absolute, traversal, secret-bearing, accessor, sparse,
  or oversized map/baseline/report data fails atomically with fixed exit 2;
- the deterministic JSON report contains only the base revision, candidate
  hashes, and mapped/removal/decrease totals, with no reflected untrusted data.

Import the future verifier and run RED:

```powershell
Push-Location .\backend
node --test -r ts-node/register test/architecture-r1-baseline-relocation.test.ts
Pop-Location
```

Expected: module-not-found failure.

Create `backend/architecture/r1-relocation-map.json` with exact schema:

```json
{
  "schemaVersion": 1,
  "dependencyRuleRenames": [
    {
      "from": "current-platform-no-business-contexts",
      "to": "platform-no-business-contexts"
    }
  ],
  "dependencyPrefixes": [
    { "from": "src/common/config/", "to": "src/platform/config/" },
    { "from": "src/common/filters/", "to": "src/platform/http/" },
    { "from": "src/common/http/", "to": "src/platform/http/" },
    { "from": "src/common/pagination/", "to": "src/platform/http/" },
    { "from": "src/common/redis/", "to": "src/platform/redis/" },
    { "from": "src/common/observability/", "to": "src/platform/observability/" },
    { "from": "src/common/prisma/", "to": "src/platform/database/" },
    { "from": "src/common/idempotency/", "to": "src/platform/idempotency/" },
    { "from": "src/common/validation/money.ts", "to": "src/shared-kernel/money/money.ts" },
    { "from": "src/common/phone/", "to": "src/shared-kernel/phone/" },
    { "from": "src/common/privacy/", "to": "src/shared-kernel/privacy/" },
    { "from": "src/common/time/", "to": "src/shared-kernel/time/" },
    { "from": "src/common/admin/admin-permissions.ts", "to": "src/modules/backoffice/domain/admin-permissions.ts" },
    { "from": "src/prisma/", "to": "src/platform/database/" },
    { "from": "src/outbox/", "to": "src/platform/outbox/" },
    { "from": "src/health.controller.ts", "to": "src/platform/health/health.controller.ts" },
    { "from": "src/health/", "to": "src/platform/health/" },
    { "from": "src/auth/openwa-otp-config.ts", "to": "src/platform/otp-transport/openwa-otp-config.ts" },
    { "from": "src/auth/openwa-transient-text.ts", "to": "src/platform/otp-transport/openwa-transient-text.ts" },
    { "from": "src/auth/whatsapp-otp-config.ts", "to": "src/platform/otp-transport/whatsapp-otp-config.ts" },
    { "from": "src/users/application-user-identity.ts", "to": "src/shared-kernel/privacy/application-user-identity.ts" },
    { "from": "src/admin/admin-privacy.ts", "to": "src/shared-kernel/privacy/admin-notification-privacy.ts" }
  ],
  "ownershipFilePrefixes": [
    { "from": "backend/src/common/config/", "to": "backend/src/platform/config/" },
    { "from": "backend/src/common/filters/", "to": "backend/src/platform/http/" },
    { "from": "backend/src/common/http/", "to": "backend/src/platform/http/" },
    { "from": "backend/src/common/pagination/", "to": "backend/src/platform/http/" },
    { "from": "backend/src/common/redis/", "to": "backend/src/platform/redis/" },
    { "from": "backend/src/common/observability/", "to": "backend/src/platform/observability/" },
    { "from": "backend/src/common/prisma/", "to": "backend/src/platform/database/" },
    { "from": "backend/src/common/idempotency/", "to": "backend/src/platform/idempotency/" },
    { "from": "backend/src/prisma/", "to": "backend/src/platform/database/" },
    { "from": "backend/src/outbox/", "to": "backend/src/platform/outbox/" },
    { "from": "backend/src/health.controller.ts", "to": "backend/src/platform/health/health.controller.ts" },
    { "from": "backend/src/health/", "to": "backend/src/platform/health/" }
  ]
}
```

The map contains no mutable revision placeholder. The verifier binds it to the
exact immutable `--base-ref` and records that SHA in the deterministic report.
Before invocation, the controller must compare the argument to the `$r1Base`
captured in the Task 1 execution brief and stop on mismatch.

Implement `backend/scripts/architecture/r1-baseline-relocation.cjs` with this
exact interface:

```text
--verify
--base-ref <immutable R1_BASE>
--dependency-candidate <absolute OS-temp JSON path>
--ownership-candidate <absolute OS-temp JSON path>
--map backend/architecture/r1-relocation-map.json
--report <absolute OS-temp JSON path>
```

It reads base baselines through `git show <base-ref>:<repository path>`, validates
the exact map/candidate schemas, compares atomically, and writes the report only
on PASS. It never edits a tracked baseline. Add `--output <absolute OS-temp JSON
path>` to `ownership-scan.cjs` so validated current records can be emitted
without `--write-baseline`. The output is the same canonical
`{schemaVersion,sourceRevision,violations}` shape as a baseline, but is written
only to the caller's OS-temp path. Test this mode before implementation,
require a fixed sanitized exit 2 for invalid args/path/write failure, then rerun
the relocation suite and require GREEN before any source move.

- [ ] **Step 3: Move foundation files with Git-aware moves**

Create destination directories, then use `git mv` for every existing file:

```powershell
$task2Directories = @(
  'backend/src/platform/config',
  'backend/src/platform/database',
  'backend/src/platform/health',
  'backend/src/platform/http',
  'backend/src/platform/observability',
  'backend/src/platform/redis'
)
New-Item -ItemType Directory -Force $task2Directories | Out-Null
```

Move each source to the exact target in the file map. Do not bulk-copy and delete; Git must show moves where similarity permits.

- [ ] **Step 4: Update every production consumer mechanically**

Use only Task 1's 248-entry `$oldImportInventory`, never the raw 251 lexical
matches. Update imports in `backend/src/**`, including but not limited to
`app.module.ts`, `main.ts`, auth, admin, catalogs, contexts, conversations,
dashboard/timeline, guests, marketplace/provider dashboard, media,
money/finance roots, notifications/push, sharing, tasks, users, wedding
plans/costs, and remaining idempotency/outbox files.

Do not change constructor order, provider arrays, controller arrays, function bodies, or strings. Review each production diff with:

```powershell
git diff --word-diff=porcelain -- backend/src
```

Expected: moves plus import/path changes only.

- [ ] **Step 5: Update test and smoke paths without changing behavior**

Update only import/require and moved-source path literals in the exact 248-entry
target inventory. Preserve the three Nest negative controls byte-identically.
Required examples include health, CORS, environment, exception-filter,
request-target, scheduler-lock, financial-ledger, and PrismaService tests.

Run a semantic diff audit:

```powershell
git diff -U0 -- backend/test backend/scripts | rg --pcre2 '^[+-](?![+-])'
```

Manually classify every changed line. Any assertion/fixture/expected-value/setup change stops the task.

- [ ] **Step 6: Retarget architecture provenance and mixed roots**

Make these exact contract changes:

- ports approved global path: `backend/src/platform/database/prisma.module.ts`;
- PrismaService declaration provenance: `/src/platform/database/prisma.service.ts`;
- rename R0-specific identifiers/messages such as `R0_GLOBAL_MODULES` and `missing-r0-global` to phase-neutral approved-global names; tests must prove unknown/old paths fail;
- dependency-cruiser legacy platform roots become `common|outbox`; `platform-no-business-contexts` remains active;
- ownership registry platform current roots become `['common', 'outbox', 'platform']` during this checkpoint;
- ownership context validation accepts the canonical platform root and rejects stale/forged paths.

Use TDD for scanner changes: modify/add architecture fixture assertions first, run RED, then update the scanner/config and run GREEN.

- [ ] **Step 7: Reconcile dependency and ownership debt with the tested verifier**

Generate candidates without modifying tracked baselines:

```powershell
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'aarast-r1-baseline-audit'
New-Item -ItemType Directory -Force $tempRoot | Out-Null
$dependencyCandidate = Join-Path $tempRoot 'dependency-candidate.json'
$ownershipCandidate = Join-Path $tempRoot 'ownership-candidate.json'
$relocationReport = Join-Path $tempRoot 'r1-baseline-relocation-report.json'
Push-Location .\backend
npm exec -- depcruise --config .dependency-cruiser.cjs --output-type baseline --output-to $dependencyCandidate src
node .\scripts\architecture\ownership-scan.cjs --output $ownershipCandidate
node .\scripts\architecture\r1-baseline-relocation.cjs `
  --verify `
  --base-ref $r1Base `
  --dependency-candidate $dependencyCandidate `
  --ownership-candidate $ownershipCandidate `
  --map architecture/r1-relocation-map.json `
  --report $relocationReport
Pop-Location
```

Required result:

- runtime config -> auth OTP config edges map by source move and remain temporarily;
- runtime config -> auth JWT maps by source move;
- health -> OpenWA config maps by source/target moves;
- health -> media maps by source move;
- no new target, cycle, or extra key;
- all unrelated known keys are identical or removed.
- every ownership addition maps from one removed base record with identical
  model, operation, mode, reason, owner, context, source kind, and equal or
  lower count.

Only after the JSON report says PASS may the implementer copy a changed
candidate over its tracked baseline. Do not rewrite a byte-identical baseline.
Run the normal architecture checks immediately after copying. The JSON report
remains an OS-temp artifact and is not staged; record its SHA-256 and aggregate
mapped/removal/decrease totals in the checkpoint report and final receipt.

- [ ] **Step 8: Run focused and checkpoint gates**

```powershell
Push-Location .\backend
node --test -r ts-node/register `
  test/architecture-r1-layout.test.ts `
  test/architecture-r1-baseline-relocation.test.ts `
  test/architecture-dependencies.test.ts `
  test/architecture-ownership.test.ts `
  test/architecture-ports.test.ts `
  test/health-readiness.test.ts `
  test/cors-preflight.test.ts `
  test/global-exception-filter.test.ts `
  test/request-target-redaction.test.ts `
  test/financial-ledger.test.ts
npm run architecture
npm run check
npm run build
Pop-Location
git diff --check
```

Expected: all PASS; exact globals 2, `forwardRef` 0, no cycle, no new debt.

- [ ] **Step 9: Review scope and commit only with Git authorization**

Expected checkpoint scope is Task 2 moves/consumers plus architecture files and the additive R1 test. No product contract file outside this scope may change.

```powershell
git add -A -- `
  backend/src `
  backend/test `
  backend/scripts/architecture `
  backend/.dependency-cruiser.cjs `
  backend/.dependency-cruiser-known-violations.json `
  backend/architecture
git commit -m "refactor: move backend platform foundations"
```

---

### Task 3: Move Idempotency and Outbox Runtime

**Files:**
- Move: `common/idempotency/*` -> `platform/idempotency/`
- Move: `outbox/*` -> `platform/outbox/`
- Modify: all exact source/test/smoke imports and moved-source literals
- Modify: `backend/package.json`
- Regenerate in this checkpoint: `docs/SCRIPTS.md`
- Modify: dependency/ownership config and baselines only through audited relocation
- Modify: `backend/test/architecture-r1-layout.test.ts`

**Interfaces:**
- Preserves: idempotency request/reconciliation semantics, database locks, scheduler behavior, outbox enqueue/claim/dispatch/retry/push/realtime behavior.
- Produces: no `backend/src/outbox/`; correct production CLI output path; only shared-kernel candidates remain under `common/`.

- [ ] **Step 1: Add Task 3 layout/runtime assertions and prove RED**

Append tests that require:

- all four idempotency files and all seven outbox files at target paths;
- old folders absent;
- package script exactly `node dist/platform/idempotency/idempotency-reconcile.cli.js`;
- outbox scheduler constants, retry cap, and module exports still detectable at moved paths;
- no stale idempotency/outbox import or source-path literal outside intentional legacy architecture fixtures.

Run focused RED before moving files.

- [ ] **Step 2: Move files and update production consumers**

Use `git mv` into exact targets. Update every source import from Task 1, including remaining platform files and all business consumers. Preserve all file bodies except relative import paths.

Change only this package command:

```json
"prod:reconcile-idempotency": "node dist/platform/idempotency/idempotency-reconcile.cli.js"
```

Do not add an old dist shim.

- [ ] **Step 3: Update behavioral tests/smokes mechanically**

Update imports and source-path literals in idempotency, scheduler, outbox, notification, sharing, and Phase 2 smoke tests. Run the same changed-line policy audit used in Task 2.

- [ ] **Step 4: Update mixed roots and reconcile baselines**

- ownership registry platform roots become exactly `['common', 'platform']`;
- dependency-cruiser no longer treats `outbox` as a live legacy platform root;
- the four current outbox-to-messaging/push edges map exactly to their moved source paths under `platform-no-business-contexts`;
- any ownership key path moves from `common/idempotency` or `outbox` must preserve every semantic field/count or decrease;
- no new outbox model/table access is allowed.

Repeat the exact candidate-generation and
`r1-baseline-relocation.cjs --verify` command from Task 2 Step 7. The OS-temp
JSON report is rewritten only by a PASS result for the current candidate. Only
then may a changed tracked baseline be replaced; byte-identical baselines stay
untouched.

- [ ] **Step 5: Regenerate the script catalog and keep this checkpoint green**

```powershell
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: `docs/SCRIPTS.md` changes only in the
`prod:reconcile-idempotency` row, from `dist/common/...` to
`dist/platform/idempotency/...`; drift=0 and docs verification PASS.

- [ ] **Step 6: Run focused behavior gates**

```powershell
Push-Location .\backend
node --test -r ts-node/register `
  test/architecture-r1-layout.test.ts `
  test/architecture-r1-baseline-relocation.test.ts `
  test/idempotency-interceptor.test.ts `
  test/idempotency-reconciliation.test.ts `
  test/scheduler-lock.test.ts `
  test/outbox-logic.test.ts `
  test/notification-logic.test.ts `
  test/notification-mutation-atomicity.test.ts
npm run architecture
npm run check
npm run build
Pop-Location
git diff --check
```

Expected: all PASS; dependency debt maps only by path; ownership debt does not increase.

- [ ] **Step 7: Commit checkpoint only with Git authorization**

```powershell
git add -A -- `
  backend/src `
  backend/test `
  backend/scripts `
  backend/package.json `
  backend/.dependency-cruiser.cjs `
  backend/.dependency-cruiser-known-violations.json `
  backend/architecture `
  docs/SCRIPTS.md
git commit -m "refactor: move idempotency and outbox platform runtime"
```

---

### QA Precondition: Repair Two Stale Managed-Smoke Harnesses

This bounded checkpoint is required before Task 4 because independent Task 3
review reproduced two pre-existing harness failures that would otherwise make
Task 6 `smoke:all` structurally red. It may modify only:

- `backend/scripts/smoke/phase2-notification-preferences-smoke.ts`;
- `backend/scripts/smoke/phase2-conversation-revocation-smoke.ts`;
- this plan contract;
- `docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md`;
- `ARCHITECTURE.md`.

No production source, fixture factory, route, schema, migration, product
behavior, timeout, retry, or environment contract may change.

- [ ] **Step Q1: Prove both current failures before editing**

Run each managed smoke independently. Record the exact existing failures:

- notification preferences persists three notifications but four legitimate
  outbox events because every notification emits `NOTIFICATION_CREATED` and the
  existing `TASK_DUE_SOON` push policy also emits
  `PUSH_NOTIFICATION_REQUESTED`;
- conversation revocation constructs `SharingService` with its pre-history
  dependency signature and fails when the current service calls
  `ContributionHistoryService.ensureTenureInTransaction()`.

- [ ] **Step Q2: Strengthen the notification outbox assertion**

Replace the stale count-only assertion with exact per-notification event-type
assertions. Require one `NOTIFICATION_CREATED` event for every persisted
notification, require exactly one additional `PUSH_NOTIFICATION_REQUESTED`
event only for the existing `TASK_DUE_SOON` notification, and reject duplicate
or unexpected event types. Do not change notification production behavior.

- [ ] **Step Q3: Wire the current sharing dependency in the smoke harness**

Import and instantiate the real `ContributionHistoryService` with the managed
smoke Prisma client. Pass it as constructor argument five and realtime as
argument six at both existing `SharingService` construction sites. Do not stub
history behavior and do not change the shared fixture factory.

- [ ] **Step Q4: Verify, review, and checkpoint separately**

No other managed or ad-hoc smoke may run concurrently with this checkpoint.
The environment must be clean before the first command and again after the
last command. Define and run this read-only audit; it intentionally fails on
any pre-existing smoke resource instead of deleting it:

```powershell
function Assert-R1ManagedSmokeEnvironmentClean {
  $smokeDatabases = @(docker exec aarast-db sh -lc `
    'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT datname FROM pg_database WHERE datname LIKE ''aarast_smoke_%'' ORDER BY datname;"')
  if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL smoke audit failed' }
  if ($smokeDatabases.Count -ne 0) { throw 'Managed smoke database present' }

  $redisDb15 = docker exec aarast-redis redis-cli -n 15 DBSIZE
  if ($LASTEXITCODE -ne 0) { throw 'Redis smoke audit failed' }
  if ([int]$redisDb15 -ne 0) { throw 'Managed smoke Redis DB 15 is not empty' }

  $backendRootPattern = [regex]::Escape(
    'D:\projects\aarast-modular-monolith\backend'
  )
  $smokeProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'node.exe' -and
    $_.CommandLine -match $backendRootPattern -and
    $_.CommandLine -match `
      'run-isolated-smoke|smoke-isolation-hook|scripts[\\/]smoke|src[\\/]main\.ts'
  })
  $smokeProcessIds = @($smokeProcesses | ForEach-Object { $_.ProcessId })
  $smokeListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $smokeProcessIds -contains $_.OwningProcess })
  if ($smokeProcesses.Count -ne 0 -or $smokeListeners.Count -ne 0) {
    throw 'Managed smoke process or listener present'
  }

  $smokeBuckets = @(docker compose exec -T media sh -lc `
    'set -eu; [ -d /data ]; [ -r /data ]; for path in /data/aarast-smoke-*; do [ -d "$path" ] && echo "${path##*/}"; done; exit 0')
  if ($LASTEXITCODE -ne 0) { throw 'MinIO smoke audit failed' }
  if ($smokeBuckets.Count -ne 0) { throw 'Managed smoke MinIO bucket present' }

  $tempMatches = @(Get-ChildItem ([IO.Path]::GetTempPath()) -Force |
    Where-Object { $_.Name -like 'smoke_*' -or $_.Name -like 'aarast-smoke-*' })
  if ($tempMatches.Count -ne 0) { throw 'Managed smoke OS-temp artifact present' }
}

Assert-R1ManagedSmokeEnvironmentClean

Push-Location .\backend
npm run smoke:phase2-notification-preferences
npm run smoke:phase2-conversation-revocation
npm run smoke:health
node --test -r ts-node/register `
  test/notification-logic.test.ts `
  test/push-notifications.test.ts `
  test/contribution-history-freeze.test.ts `
  test/smoke-isolation.test.ts
npm run check
Pop-Location
git diff --check

Assert-R1ManagedSmokeEnvironmentClean
```

Request independent read-only review before the checkpoint commit:

```powershell
git add -- `
  ARCHITECTURE.md `
  docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md `
  docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md `
  backend/scripts/smoke/phase2-notification-preferences-smoke.ts `
  backend/scripts/smoke/phase2-conversation-revocation-smoke.ts
git commit -m "test: repair R1 managed smoke harnesses"
```

---

### Task 4: Split and Move Production OTP Transport

**Files:**
- Move: the three auth transport/config files to `platform/otp-transport/`
- Create: `otp-delivery.ts`, `openwa-otp.channel.ts`, `whatsapp-otp.channel.ts`
- Modify: `backend/src/auth/otp-channel.ts`, `auth.service.ts`, runtime config, health, sharing invitation delivery
- Modify: exact OTP/health/invite tests and smoke imports only mechanically
- Modify: dependency baseline to remove eliminated platform-to-auth transport edges
- Modify: `backend/test/architecture-r1-layout.test.ts`

**Interfaces:**
- Identity keeps: delivery-channel selection, the six-digit cryptographic code
  generator, and `DevEchoOtpChannel`.
- Platform owns: delivery result/error contract, delivery-only concrete
  production channels, config loaders, and transient OpenWA sender.
- Preserves: code generation, provider payloads, acknowledgement/uncertain/rejected classification, secret-safe errors, credential rotation, timeouts, invite delivery behavior.

- [ ] **Step 1: Add OTP boundary tests and prove RED**

Append layout tests that require:

- exact OTP target files;
- no legacy auth transport/config files;
- `auth/otp-channel.ts` contains `OtpChannel` and `DevEchoOtpChannel` but not `WhatsAppOtpChannel`, `OpenWaOtpChannel`, provider URLs, fetch bodies, or config loaders;
- no file under `platform/otp-transport` imports `auth/`, another business root, or `modules/`;
- no file under `platform/otp-transport` imports `randomInt`, declares
  `generateCode`, or creates an OTP code;
- the identity file owns `generateProductionOtpCode()` and tests prove it
  returns the same zero-padded six-digit range as the current production
  channels;
- `AuthService` imports the development contract from auth and production adapters/delivery uncertainty from platform;
- sharing's current direct transient sender import resolves to platform and is called out by a named test as temporary pre-R6 debt, not an allowed reverse dependency.

Run focused test and confirm RED.

- [ ] **Step 2: Introduce the platform delivery contract test-first**

Create `platform/otp-transport/otp-delivery.ts` with:

```typescript
export interface OtpDeliveryResult {
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
  deliveryStatus: 'LOCAL_DEV' | 'DELIVERED' | 'PENDING';
  echoCode?: string;
  message?: string;
}

export class OtpDeliveryUncertainError extends Error {
  constructor() {
    super('OTP delivery outcome is uncertain');
    this.name = 'OtpDeliveryUncertainError';
  }
}
```

Add focused tests before implementation that prove the exact name/message and no secret reflection.

- [ ] **Step 3: Move config/transient files and split concrete adapters**

Use `git mv` for the three whole files, then extract concrete channel classes from `auth/otp-channel.ts` into the exact adapter files. Move the private WhatsApp rejection error with the WhatsApp adapter. Keep OpenWA transport-specific errors with transient transport.

`auth/otp-channel.ts` imports `OtpDeliveryResult`, exposes a delivery-only
`OtpChannel` interface, `DevEchoOtpChannel`, and
`generateProductionOtpCode()`. `AuthService.resolveOtpChannel()` remains the
identity-owned selection point and returns the chosen delivery channel paired
with its identity-owned generator: the fixed development code for `dev`, and
`generateProductionOtpCode` for `whatsapp`/`openwa`. `issueOtp()` calls that
pair's generator before delivery. Concrete platform adapters implement only
`deliver(...)`; they contain no `generateCode()` or `randomInt` call. Do not
re-export platform adapters from the old file.

- [ ] **Step 4: Update consumers and tests mechanically**

Update:

- `AuthService` imports and structural assignments;
- platform runtime validation and health imports;
- sharing invitation delivery import;
- OpenWA/WhatsApp credential/channel, auth mode, health, invite, and smoke imports.

Do not change any existing OTP/invite assertion, payload, message, timeout, error classification, or environment fixture.

- [ ] **Step 5: Remove eliminated dependency debt**

Generate a temporary dependency baseline. The three old platform-to-auth edges for OpenWA/WhatsApp config must be absent because source and target now share platform. The only surviving Task 2 platform config debt is runtime environment -> auth JWT secret. No replacement edge from OTP transport to auth is permitted.

Run the tested Task 2 relocation verifier over fresh dependency and ownership
candidates. The three eliminated edges must be reported as removals, not mapped
permissions. Do not update either tracked baseline unless the verifier passes.

- [ ] **Step 6: Run OTP/invite focused gates**

```powershell
Push-Location .\backend
node --test -r ts-node/register `
  test/architecture-r1-layout.test.ts `
  test/architecture-r1-baseline-relocation.test.ts `
  test/auth-otp-mode.test.ts `
  test/openwa-credential-file.test.ts `
  test/openwa-otp-channel.test.ts `
  test/whatsapp-otp-channel.test.ts `
  test/otp-controller-context.test.ts `
  test/otp-dispatch-quota.test.ts `
  test/invite-delivery.test.ts `
  test/health-readiness.test.ts
npm run architecture
npm run check
npm run build
Pop-Location
git diff --check
```

Expected: all PASS; no new dependency/ownership entry.

- [ ] **Step 7: Commit checkpoint only with Git authorization**

```powershell
git add -A -- `
  backend/src `
  backend/test `
  backend/scripts `
  backend/.dependency-cruiser.cjs `
  backend/.dependency-cruiser-known-violations.json `
  backend/architecture
git commit -m "refactor: separate OTP transport from identity"
```

---

### Task 5: Establish Shared Kernel and Dissolve `common/`

**Files:**
- Create: `backend/test/shared-kernel-money.test.ts`
- Move/rewrite: Money file
- Move: phone, review identity, application identity, admin notification privacy, business day
- Move: admin permissions to `modules/backoffice/domain/`
- Modify: all exact source/test imports and moved-source path literals
- Modify: architecture configuration/registry/baselines for final R1 roots
- Modify: `backend/test/architecture-r1-layout.test.ts`

**Interfaces:**
- Preserves: existing money validation functions and errors, phone behavior, identity display/redaction, notification privacy, Riyadh day behavior, Admin permission matrix.
- Produces: no `common/` folder; shared-kernel with no platform/business source import; platform roots exactly `platform`.

- [ ] **Step 1: Write Money value-object tests before implementation**

Create `backend/test/shared-kernel-money.test.ts` with independent tests for:

1. all current valid/invalid `requiredMoneyAmount` and `optionalMoneyAmount` cases;
2. exact `BadRequestException` message for invalid type, blank, negative, exponent, comma, >12 integer digits, and >2 decimal places;
3. input representation preservation (`' 1.20 '` -> `'1.20'`);
4. `Money.toDecimal()` returns a `Prisma.Decimal` equal to the input;
5. comparison returns exactly `-1|0|1` and equality is decimal equality;
6. addition/subtraction with exact decimal arithmetic and a required explicit
   field name;
7. negative subtraction and numeric(14,2) overflow fail with the same field-specific bounded non-negative message;
8. optional blank/null/undefined returns null without constructing Money.

Import only the future canonical path and run RED:

```powershell
Push-Location .\backend
node --test -r ts-node/register test/shared-kernel-money.test.ts
Pop-Location
```

Expected: module-not-found failure before the move.

- [ ] **Step 2: Move and implement Money at the canonical path**

Move the current validator file, preserve its regex and exact error construction, then add:

```typescript
export class Money {
  static required(value: unknown, field: string): Money;
  static optional(value: unknown, field: string): Money | null;
  compare(other: Money): -1 | 0 | 1;
  equals(other: Money): boolean;
  add(other: Money, field: string): Money;
  subtract(other: Money, field: string): Money;
  toDecimal(): Prisma.Decimal;
  toString(): string;
}
```

Implementation requirements:

- store a `Prisma.Decimal` plus the validated serialized string;
- construction keeps the current trimmed string;
- arithmetic uses Decimal methods, serializes the result, and passes it back through the same numeric(14,2)/non-negative validator;
- `requiredMoneyAmount` and `optionalMoneyAmount` call Money and preserve exact current outputs;
- no floating-point number arithmetic;
- no second validator or permissive fallback.

Run Money tests GREEN before updating consumers.

- [ ] **Step 3: Move privacy/application identity at the dependency root**

Use `git mv` for:

- review identity;
- `users/application-user-identity.ts`;
- `admin/admin-privacy.ts` renamed to `admin-notification-privacy.ts`.

Update sibling imports so `review-identity.ts` imports application identity only from shared-kernel. Update users, sharing, and admin presenters/tests mechanically. Preserve all enums, allowlists, Arabic fallback/copy, masking, and redaction logic.

Add layout tests proving no file under `shared-kernel/` imports `platform/`, a legacy business root, or `modules/`.

- [ ] **Step 4: Move phone, time, and Admin permissions**

Use `git mv` to exact targets. Update all consumers and test imports. Do not create a backoffice Nest module or barrel.

Append layout assertions for exact paths and identical Admin permission enum/role mappings.

- [ ] **Step 5: Prove `common/` is dissolved and no stale path survives**

Append final R1 layout assertions:

```typescript
assert.equal(existsSync(path.join(backendRoot, 'src', 'common')), false);
assert.deepEqual(findStaleImports(), []);
```

The stale scan must inspect source, tests, and scripts while excluding only named architecture fixtures that deliberately test rejection of legacy paths. It must also reject `dist/common/idempotency` and moved-source string literals.

- [ ] **Step 6: Finalize architecture roots and baseline semantics**

Make final R1 architecture state exact:

- ownership registry `currentRoots.platform` is exactly `['platform']`;
- owners and 52-model membership are byte-identical to R0;
- dependency-cruiser removes the legacy current-platform rule/root set and enforces `platform-no-business-contexts` plus `shared-kernel-is-foundational`;
- the review-identity -> users debt disappears completely;
- the dependency baseline contains only the six declared surviving platform-to-business path-relocated edges plus unrelated R0 debt/decreases;
- ownership baseline current keys are path-relocated only with semantic equality/decrease;
- ports global paths are exact and `PrismaService` provenance recognizes only the canonical platform declaration.

Run the exact Task 2 candidate generation and tested relocation verifier. The
final report must prove the review-identity -> users edge is removed and exactly
the declared six platform-to-business edges survive by mapped identity. Update
tracked baselines only after PASS; do not rewrite byte-identical files.

- [ ] **Step 7: Run shared-kernel and R1 layout gates**

```powershell
Push-Location .\backend
node --test -r ts-node/register `
  test/shared-kernel-money.test.ts `
  test/architecture-r1-layout.test.ts `
  test/architecture-r1-baseline-relocation.test.ts `
  test/backend-support.test.ts `
  test/financial-integrity.test.ts `
  test/provider-price-validation.test.ts `
  test/privacy-contract.test.ts `
  test/admin-rbac-audit.test.ts
npm run architecture
npm run check
npm run build
Pop-Location
git diff --check
```

Also run:

```powershell
if (Test-Path .\backend\src\common) { throw 'common directory still exists' }
rg -n --glob '*.{ts,js,cjs,mjs}' 'src/common|/common/|src/prisma/|src/outbox/|src/health/' backend/src backend/test backend/scripts
```

Expected: only intentional negative architecture-fixture strings; each must be individually reviewed.

- [ ] **Step 8: Commit checkpoint only with Git authorization**

```powershell
git add -A -- `
  backend/src `
  backend/test `
  backend/scripts/architecture `
  backend/.dependency-cruiser.cjs `
  backend/.dependency-cruiser-known-violations.json `
  backend/architecture
git commit -m "refactor: establish backend shared kernel"
```

---

### Task 6: Transition CI, Run Full Verification, and Record R1

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: architecture and active docs listed in Target File Map
- Regenerate: `docs/SCRIPTS.md`
- Modify after every gate passes: `docs/project/STATUS.md`, `CHANGELOG.md`
- Keep: `scripts/check-r0-scope.mjs` and its tests as historical local evidence

**Interfaces:**
- Consumes: every R1 checkpoint and immutable `R1_BASE`.
- Produces: final verified R1 candidate and local receipt without self-referential CI claims.

- [ ] **Step 1: Remove only the phase-specific R0 CI job**

Delete the complete `r0-scope` job from `.github/workflows/ci.yml`. Do not delete or weaken any step in:

- Backend;
- Backend image;
- Backend E2E;
- Admin Web;
- Mobile;
- Docs;
- Secrets scan;
- Dependency audit.

Keep Backend `npm run architecture` and Mobile boundary tests/baseline gate. Do not retarget the R0 fixed-base script to R1.

Verify the YAML diff is exactly one job removal plus no unrelated formatting:

```powershell
git diff -- .github/workflows/ci.yml
```

- [ ] **Step 2: Update architecture and active phase documentation**

Update `ARCHITECTURE.md`, active docs map, Backend commands, QA commands/test policy, decisions, and execution plan with:

- R1 target layout completed locally;
- exact six remaining platform-to-business debts and their R3 removal obligation;
- sharing -> OTP transport direct consumption remains migration debt until R6;
- `@Global()` remains until R8;
- R2 is next and may not start until R1 local gates, independent review,
  managed smoke, and owner application checkpoint close;
- R0 `r0-scope` job was intentionally removed at R1 closeout because any
  future push of this same branch represents a combined post-R0 candidate;
- 52 models/76 migrations remain live truth;
- no schema, route, product, Mobile, Admin source, or deployment change.

Do not mark R1 complete or write STATUS/CHANGELOG receipt yet.

- [ ] **Step 3: Regenerate docs once and enforce exact generated-doc deltas**

```powershell
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
```

Compare hashes from Task 1:

- `API_CONTRACT.md`, `DATABASE.md`, `MOBILE_ROUTES.md`, and `ADMIN_ROUTES.md` must be byte-identical;
- `docs/SCRIPTS.md` may differ only in the exact `prod:reconcile-idempotency` path row and explicitly documented new R1 test command, if one was added to `package.json`.

Any route/model/mobile/admin generated-doc delta is a blocker.

- [ ] **Step 4: Run the preflight protected-surface audit**

```powershell
git diff --exit-code $r1Base -- `
  backend/prisma/schema.prisma `
  backend/prisma/migrations `
  mobile/lib mobile/test mobile/integration_test `
  admin-web/src `
  deploy docker-compose.yml
if ($LASTEXITCODE -ne 0) { throw 'Protected R1 surface changed' }

$protectedStatus = @(git status --porcelain=v1 --untracked-files=all -- `
  backend/prisma mobile admin-web/src deploy docker-compose.yml)
if ($protectedStatus.Count -ne 0) {
  throw "Protected worktree is dirty: $($protectedStatus -join '; ')"
}
```

- [ ] **Step 5: Run complete Backend local gates**

```powershell
Push-Location .\backend
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npm audit --audit-level=high
npm audit --omit=dev
Pop-Location
```

If `DATABASE_URL` is absent, document the first Prisma P1012 result and rerun only `prisma validate` with a process-scoped non-secret local PostgreSQL placeholder. Do not write `.env` or connect to a database for validation.

Expected: all PASS, full audit has no high/critical issue, production audit has zero findings.

- [ ] **Step 6: Run all managed smoke packages**

```powershell
Push-Location .\backend
npm run smoke:all
Pop-Location
```

This gate requires the repository's managed smoke environment and database. If infrastructure is unavailable, R1 local closure is blocked; do not waive, mock, skip, or replace the smoke suite with unit tests.

- [ ] **Step 7: Run unchanged Admin and Mobile gates**

```powershell
Push-Location .\admin-web
npm run typecheck
npm test -- --run
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
Pop-Location

node --test .\scripts\check-mobile-boundaries.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
Push-Location .\mobile
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
```

Expected: all PASS; Mobile baseline remains exactly 269 current records and no generated plugin file remains dirty.

- [ ] **Step 8: Audit pre-existing test changes mechanically**

Separate behavioral tests from the three existing architecture-governance
tests whose assertions must change to encode R1:

```powershell
$removedOrRenamedTests = @(
  git diff --name-status --find-renames --diff-filter=DR $r1Base -- backend/test backend/scripts/smoke
)
if ($removedOrRenamedTests.Count -gt 0) {
  throw "R1 may not delete or rename existing test/smoke files: $($removedOrRenamedTests -join '; ')"
}

$architectureGovernanceTests = @(
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-ports.test.ts'
)
$changedExistingTests = @(
  git diff --name-only --diff-filter=M $r1Base -- backend/test backend/scripts/smoke |
    ForEach-Object { $_ -replace '\\','/' } |
    Sort-Object -Unique
)
$changedBehavioralTests = @(
  $changedExistingTests | Where-Object { $architectureGovernanceTests -notcontains $_ }
)
$changedArchitectureTests = @(
  $changedExistingTests | Where-Object { $architectureGovernanceTests -contains $_ }
)
if ($changedBehavioralTests.Count -gt 0) {
  git diff -U0 $r1Base -- $changedBehavioralTests
}
if ($changedArchitectureTests.Count -gt 0) {
  git diff -U0 $r1Base -- $changedArchitectureTests
}

$allowedAdditiveTests = @(
  'backend/test/architecture-r1-baseline-relocation.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/shared-kernel-money.test.ts'
)
$addedTests = @(
  @(
    git diff --name-only --diff-filter=A $r1Base -- backend/test backend/scripts/smoke
    git ls-files --others --exclude-standard -- backend/test backend/scripts/smoke
  ) | ForEach-Object { $_ -replace '\\','/' } | Sort-Object -Unique
)
$additiveDelta = @(Compare-Object $allowedAdditiveTests $addedTests)
if ($additiveDelta.Count -ne 0) {
  throw "Additive R1 test set mismatch: $($additiveDelta.InputObject -join '; ')"
}
```

For every changed **behavioral** test/smoke hunk, prove it is only:

- import/export/require path;
- moved-source path literal;
- the exact reviewed QA-precondition changes in
  `phase2-notification-preferences-smoke.ts` and
  `phase2-conversation-revocation-smoke.ts` described above.

For the two QA-precondition files, the only additional allowed hunks are the
exact per-notification outbox event-type assertions and the real
`ContributionHistoryService` constructor wiring. Any other assertion, fixture,
timeout, selection, or setup/teardown change remains a blocker.

Outside that exact exception, any changed assertion, fixture, expected value,
setup/teardown, timeout, skip, or test selection blocks R1.

Review the three architecture-governance diffs separately. Their only allowed
non-path changes are:

- dependency test: the exact
  `current-platform-no-business-contexts` -> `platform-no-business-contexts`
  transition and mixed/final-root rejection fixtures;
- ownership test: canonical platform/currentRoots fixtures and the tested
  `--output` OS-temp CLI mode;
- ports test: canonical Prisma/global declaration path, phase-neutral approved-
  global diagnostic names/messages, and rejection of stale global/provenance
  paths.

No test may be deleted, skipped, weakened, or have unrelated scanner-security,
atomicity, sanitization, ownership, cycle, or symbol-provenance assertions
changed. Any architecture assertion outside this exact allowlist blocks R1.

- [ ] **Step 9: Audit final baselines and invariants**

Require:

```powershell
$models = (Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+').Count
$migrations = (Get-ChildItem .\backend\prisma\migrations -Directory).Count
if ($models -ne 52 -or $migrations -ne 76) { throw 'Schema inventory drift' }
if (Test-Path .\backend\src\common) { throw 'common still exists' }
if (Test-Path .\backend\src\prisma) { throw 'legacy Prisma source still exists' }
if (Test-Path .\backend\src\outbox) { throw 'legacy outbox source still exists' }
(rg -n 'forwardRef\s*\(' .\backend\src | Measure-Object).Count
rg -n '@Global\(' .\backend\src
```

Expected: 52/76, old roots absent, zero forwardRef, exactly two globals at canonical approved paths.

Also prove:

- a fresh final dependency/ownership candidate pair passes the tested
  `r1-baseline-relocation.cjs --verify` command against immutable `R1_BASE` and
  rewrites the OS-temp JSON report with final hashes/totals, which are copied
  into the receipt;
- the dependency candidate contains no new semantic key and only six declared
  relocated platform-to-business debts;
- ownership remains 386 keys/782 occurrences or a verifier-approved decrease;
  no reason/source/model/mode/operation/owner/context count increases;
- ownership registry has no exception and `currentRoots.platform=['platform']`;
- Mobile baseline is byte-identical;
- baselines are canonical, sorted, unique, positive-count, repository-relative, and secret/path safe.

- [ ] **Step 10: Re-run docs, diff, and protected postflight**

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git diff --exit-code $r1Base -- `
  backend/prisma/schema.prisma `
  backend/prisma/migrations `
  mobile/lib mobile/test mobile/integration_test `
  admin-web/src `
  deploy docker-compose.yml
git status --short --untracked-files=all
```

Expected: all PASS and no test-generated tracked side effects.

- [ ] **Step 11: Record the R1 receipt only after every gate passes**

Update `docs/project/STATUS.md` and `CHANGELOG.md` with:

- `R1_BASE`, execution branch, and exact changed paths;
- exact move map and statement that no old-path facade remains;
- exact dependency, ownership, globals, forwardRef, Mobile, model, and migration counts;
- exact commands and PASS/FAIL results, including first Prisma env-only failure if observed;
- exact full Backend/Admin/Mobile/smoke test counts from the run;
- explicit no-change statements for API/routes/errors/Arabic/permissions/transactions/schema/migrations/Mobile/Admin source/deployment;
- six remaining platform debt edges and their R3 removal phase;
- sharing OTP transport debt and R6 removal phase;
- warning/noise classification without hiding warnings;
- statement that remote CI is not claimed by the tracked receipt.

- [ ] **Step 12: Verify the receipt and commit only with Git authorization**

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git add -A -- `
  .github/workflows/ci.yml `
  ARCHITECTURE.md `
  AGENTS.md `
  CHANGELOG.md `
  docs `
  backend/package.json
git commit -m "docs: record modular monolith R1 verification"
```

- [ ] **Step 13: Close the local R1 checkpoint without mutating PR #76**

Do not push or merge as part of the staged R1 execution. Record that remote CI
is unobserved for the local R1 commits and that PR #76 still points at immutable
R0 candidate `94b677b7b8e2219e0db2cbc553fa3d26b4876456`.

After local gates, managed smokes, independent review, and the owner's
application test pass, the owner may authorize the next phase on the same
branch. If a future push is authorized, treat the updated PR/workflow run as a
new combined candidate and require every remaining CI job to pass. Never claim
those remote results before they exist and never merge automatically.

---

## Plan Self-Review Checklist

- [ ] Spec coverage: every R1 fate-map row for common, Prisma client, outbox, health, and OTP transport maps to one task.
- [ ] Live correction coverage: 52/76, planning ownership of WeddingPlan, mixed OTP file, shared identity dependency, six path-relocated platform debts, and sharing transport debt are explicit.
- [ ] Phase discipline: no R2 schema split, R3 ports, R4-R8 business restructuring, R8 global removal, R9 Mobile work, or R10 Admin restructure is pulled forward.
- [ ] No compatibility layer: old paths are deleted; no re-export, barrel, symlink, duplicate implementation, fallback require, or dist shim remains.
- [ ] Runtime equivalence: routes, error/Arabic text, DI behavior, transaction/lock/retry/scheduler semantics, OTP/provider payloads, and privacy behavior are named invariants with focused tests.
- [ ] Money exactness: serialized input preservation, required field names,
  Decimal arithmetic, comparison, non-negativity, numeric(14,2), overflow, and
  exact existing validation errors are all tested.
- [ ] Baseline verifier: a tested machine-readable relocation map, immutable
  base ref, OS-temp candidate outputs, deterministic OS-temp JSON report, and atomic failure
  replace every manual or blind regeneration step.
- [ ] Dependency debt: candidate comparison is one-to-one by semantic edge and
  the single declared rule rename; new targets/cycles/keys fail and removed
  debt stays removed.
- [ ] Ownership debt: source relocation is accepted only when every semantic
  field and count is equal/decreased; registry owners/model set remain exact.
- [ ] Shared-kernel direction: application identity moves with privacy so no business import is baselined under shared-kernel.
- [ ] OTP direction: identity retains code generation and selection; platform
  adapters are delivery-only, never import auth, and no early identity port or
  old-path facade is introduced.
- [ ] Global provenance: Prisma canonical declaration path changes, exact global set remains two, and R0-specific diagnostic names are retired.
- [ ] Test protection: existing test changes are audited from base through the
  full committed/index/worktree state, and the exact additive test set is
  allowlisted separately.
- [ ] Green checkpoints: Task 1 ends with a green preflight; Tasks 2-5 contain
  their own RED/GREEN cycles and finish with architecture/check/build/docs as
  applicable; Task 6 closes the full suite.
- [ ] Generated docs: API/database/Mobile/Admin route docs remain byte-identical; SCRIPTS has only exact justified command deltas.
- [ ] Protected surfaces: pre/post fixed-base checks cover schema/migrations/Mobile/Admin source/deploy and test-generated side effects.
- [ ] Full local gates: architecture, check, build, full tests, full managed
  smokes, Prisma, audits, Admin, Mobile, and docs are required; remote CI is
  explicitly recorded as pending until a separately authorized push.
- [ ] Closure honesty: tracked receipt does not claim mutable HEAD or remote CI; no merge is authorized by this plan.
- [ ] Completeness scan: every file, error policy, test, command, and decision is named and executable.

## Execution Handoff

After owner approval, execute on the authorized `modular-monolith` branch in
one of these modes:

1. **Subagent-Driven (recommended):** use `superpowers:subagent-driven-development`; dispatch a fresh implementer per task, then independent specification and quality reviewers before the next task.
2. **Inline Execution:** use `superpowers:executing-plans`; execute tasks in order with an explicit review checkpoint after each task.

Do not execute R1 merely because this plan exists. The execution session must
resolve `R1_BASE`, reconfirm the same-branch Git authorization, re-read the
design/plan, and stop on any source or gate drift. After every task, stop again
for independent review and the owner's application checkpoint before
continuing.
