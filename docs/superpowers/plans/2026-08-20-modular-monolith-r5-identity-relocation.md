# Modular Monolith R5 Identity Source Relocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all Identity source under `backend/src/modules/identity` with exact path-only baseline reconciliation and no application behavior change.

**Architecture:** Preserve the R3 full/internal/public Nest boundary and physically move 44 files into `api`, `internal`, and `public` slices. An exact fixed-base manifest and TypeScript-aware gates prove one-to-one moves, public-runtime identity, provider/controller parity, stale-root removal, and dependency/ownership path equivalence.

**Tech Stack:** Node.js 22, TypeScript, NestJS 11, Prisma 6, dependency-cruiser, Node test runner, Docker, Flutter/ADB verification.

**Spec:** `docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md`

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on branch `modular-monolith`.
- Immutable R5 base is `9dab73acdc187a4a18d8a675713d8ded40a16d02`.
- Local commits are allowed; branch creation, worktrees, push, merge, PR mutation, deployment, and remote-CI claims are forbidden.
- Preserve all routes, payloads, status codes, DTO rules, auth/OTP/session behavior, errors, scheduler timing, locks, transactions, and provider identity.
- Do not modify Prisma schema, migrations, seed, Mobile, Admin Web, workflows, deployment, Compose, or package-lock files.
- Existing behavioral tests may change only for exact import/path-literal relocation.
- Do not create compatibility barrels, re-exports, duplicate implementations, symlinks, junctions, or fallback imports.
- Do not begin R6 before R5 final local review and owner approval.

## File Structure And Responsibilities

| Path | Responsibility |
| --- | --- |
| `backend/architecture/r5-identity-relocation.json` | Fixed-base 44-move, stage, public-runtime, baseline, and scope contract |
| `backend/scripts/architecture/r5-identity-scan.cjs` | Manifest validation, move parity, stale-root, public-surface, and baseline path-equivalence gate |
| `backend/test/architecture-r5-identity-relocation.test.ts` | Permanent positive and adversarial R5 contract tests |
| `backend/src/modules/identity/public/*` | Existing Identity tokens/types and exact frozen runtime/pure cross-context contracts |
| `backend/src/modules/identity/internal/auth/*` | Auth/OTP/session concrete services, policies, strategies, and schedulers |
| `backend/src/modules/identity/internal/profile/*` | Users and Contexts concrete services |
| `backend/src/modules/identity/api/*` | Identity controllers and DTOs |
| `backend/architecture/r3-context-boundaries.json` | Path-mapped strict Nest inventory with Identity legacy roots empty |
| `backend/.dependency-cruiser-known-violations.json` | Same 89 semantic records after exact path mapping |
| `backend/architecture/ownership-baseline.json` | Same 385 records / 781 occurrences after exact path mapping |
| `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-*-report.md` | Ignored human checkpoint evidence |

---

### Task 0: Approve And Checkpoint The R5 Contract

**Files:**
- Create: `docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md`
- Create: `docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`

**Interfaces:**
- Consumes: completed local R4 receipts at `9dab73acdc187a4a18d8a675713d8ded40a16d02`.
- Produces: approved R5 design, executable task order, and explicit no-R6 boundary.

- [ ] **Step 1: Verify immutable preflight**

Run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
git branch --show-current
git rev-parse HEAD
git status --short
git merge-base --is-ancestor 9dab73acdc187a4a18d8a675713d8ded40a16d02 HEAD
```

Expected: `modular-monolith`, exact R5 base, empty status, and ancestor exit 0.

- [ ] **Step 2: Record the live inventory in active docs**

State exactly: R4 locally complete; R5 design approved; implementation not
started; 44 Identity files in four legacy roots; API/schema/Mobile/Admin/deploy
frozen; no push/merge/deployment/remote CI; R6 not started.

- [ ] **Step 3: Self-review the spec and plan**

Run:

```powershell
$redFlags = @('T' + 'BD', 'T' + 'ODO', 'implement ' + 'later', `
  'fill in ' + 'details', 'similar ' + 'to') -join '|'
rg -n $redFlags `
  docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md `
  docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: placeholder search has no matches; documentation gates and whitespace
pass.

- [ ] **Step 4: Create the local planning checkpoint**

```powershell
git add ARCHITECTURE.md docs/README.md docs/project/DECISIONS.md `
  docs/project/EXECUTION_PLAN.md docs/project/STATUS.md docs/qa/README.md `
  docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md `
  docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md
git commit -m "docs: approve modular monolith R5 plan"
```

Verify the commit contains exactly these eight Markdown files and do not push.

---

### Task 1: Freeze The R5 Move, Scope, And Baseline Contract

**Files:**
- Create: `backend/architecture/r5-identity-relocation.json`
- Create: `backend/scripts/architecture/r5-identity-scan.cjs`
- Create: `backend/test/architecture-r5-identity-relocation.test.ts`
- Modify: `backend/scripts/architecture/r3-scope.cjs`
- Modify: `backend/test/architecture-r3-scope.test.ts`
- Modify: `backend/package.json`
- Modify: `docs/SCRIPTS.md`
- Create ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-1-report.md`

**Interfaces:**
- Consumes: R5 base Git blobs, current R3 manifest, dependency baseline, and ownership baseline.
- Produces: `validateR5Manifest`, `scanR5Identity`, and `architecture:r5`.

- [ ] **Step 1: Write the manifest validation RED**

Add a test with this shape:

```typescript
test('R5 manifest pins the exact 44 one-to-one moves', () => {
  const manifest = readR5Manifest();
  assert.equal(manifest.baseRevision, R5_BASE);
  assert.equal(manifest.moves.length, 44);
  assert.deepEqual(manifest.moves, [...manifest.moves].sort(bySource));
  assert.equal(new Set(manifest.moves.map((move) => move.from)).size, 44);
  assert.equal(new Set(manifest.moves.map((move) => move.to)).size, 44);
  assert.deepEqual(manifest.retiredRoots, ['auth', 'contexts', 'me', 'users']);
});
```

Add adversarial fixtures for duplicate targets, prefix overlap, missing move,
same-count substitution, absolute path, traversal, symlink/junction source, and
an added public-runtime contract.

- [ ] **Step 2: Run the RED**

```powershell
Set-Location backend
node --test -r ts-node/register test/architecture-r5-identity-relocation.test.ts
```

Expected: FAIL because the manifest/scanner do not exist.

- [ ] **Step 3: Implement strict plain-data manifest parsing**

Implement and export:

```javascript
const R5_BASE = '9dab73acdc187a4a18d8a675713d8ded40a16d02';

function validateR5Manifest(value) {
  assertDeepPlainData(value, 'R5 identity manifest');
  const manifest = exactObject(value, [
    'schemaVersion', 'baseRevision', 'stage', 'moves',
    'publicRuntimeContracts', 'retiredRoots', 'expectedBaselines',
    'allowedChangedPaths',
  ], 'R5 identity manifest');
  // Validate exact values, canonical order, one-to-one paths, stage prefix,
  // bounded strings, and the fixed base before filesystem access.
  return manifest;
}
```

The exact move list is the 44 source files documented in the design, targeting
the declared `public`, `internal/auth`, `internal/profile`, and `api` paths.

- [ ] **Step 4: Add fixed-base scope integration**

Extend `r3-scope.cjs` with `validateR5IdentityManifest` and the exact cumulative
R5 allowlist. Use `git diff --no-renames --name-only` so a forbidden deletion
cannot hide inside rename detection. Add reorder, substitution, and hidden-
deletion tests.

- [ ] **Step 5: Wire the architecture command and generated script docs**

Add:

```json
"architecture:r5": "node scripts/architecture/r5-identity-scan.cjs --check",
"architecture": "npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5"
```

Regenerate `docs/SCRIPTS.md` with the existing docs-sync command; do not hand
edit generated rows.

- [ ] **Step 6: Run GREEN and checkpoint**

```powershell
node --test -r ts-node/register `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r3-scope.test.ts
npm run architecture:r5
npm run architecture
npm run check
Set-Location ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
```

Expected: all PASS while stage is `inventory`; no production source moved.

Commit locally:

```powershell
git add backend/architecture/r5-identity-relocation.json `
  backend/scripts/architecture/r5-identity-scan.cjs `
  backend/scripts/architecture/r3-scope.cjs `
  backend/test/architecture-r5-identity-relocation.test.ts `
  backend/test/architecture-r3-scope.test.ts backend/package.json docs/SCRIPTS.md
git commit -m "test: freeze R5 identity relocation contract"
```

---

### Task 2: Move Identity Public Runtime Contracts

**Files:**
- Move the ten public files listed in the design to `backend/src/modules/identity/public/`
- Modify: every exact source/test/smoke consumer of those ten old paths
- Modify: `backend/scripts/architecture/r3-context-scan.cjs`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/architecture/r5-identity-relocation.json`
- Modify: `backend/test/architecture-r3-contexts.test.ts`
- Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Create ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-2-report.md`

**Interfaces:**
- Produces: canonical public declarations for guards, decorators, session types,
  safe-user conversion, auth errors, context keys, lifecycle locks, and UTF-8 validation.
- Consumes: existing `identity-auth.port.ts` and `identity-session.types.ts`.

- [ ] **Step 1: Write path and declaration identity RED tests**

Assert all ten targets are missing before the move, each source still exists,
and external imports resolve to the exact old declarations. Add near-misses for
a local same-name guard/decorator/helper and a copied body at two paths.

- [ ] **Step 2: Run the RED**

```powershell
Set-Location backend
node --test -r ts-node/register --test-name-pattern="R5 public" `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r3-contexts.test.ts
```

Expected: target/source assertions fail for the intended ten moves.

- [ ] **Step 3: Move the ten files with Git-aware moves**

Use `git mv` for each declared source and target. Update imports mechanically.
Move the single `OtpDispatchContext` declaration to
`identity-auth.port.ts`; make the quota service and InviteAccess consumer use
that exact type. Do not change emitted JavaScript or runtime values.

- [ ] **Step 4: Update R3 runtime/decorator identities**

Change exact path constants for `JwtAuthGuard`, `JwtSessionGuard`, and
`CurrentUser`; preserve the same TypeChecker declaration identity checks and
the exact 23 decorator-runtime, 4 admin-guard-metadata, and 26 runtime-value
reference records. Set the R5 stage to `task-2`.

- [ ] **Step 5: Verify behavior and checkpoint**

```powershell
node --test -r ts-node/register `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r3-contexts.test.ts `
  test/admin-auth-session-security.test.ts `
  test/auth-registration-security.test.ts `
  test/invite-delivery.test.ts `
  test/media-url-ownership.test.ts
npm run architecture:r5
npm run architecture
npm run check
npm run build
```

Expected: all PASS; provider/module/route counts unchanged.

Commit all ten moves and exact consumers:

```powershell
git add -A
git commit -m "refactor: move identity public runtime contracts"
```

Before committing, verify `git diff --cached --name-only` is a subset of the R5
manifest and contains no protected surface.

---

### Task 3: Move Auth API And Internal Implementation

**Files:**
- Move: `backend/src/auth/auth.controller.ts` to `backend/src/modules/identity/api/auth.controller.ts`
- Move: twelve Auth DTO files to `backend/src/modules/identity/api/auth-dto/`
- Move: ten Auth implementation files to `backend/src/modules/identity/internal/auth/`
- Modify: `backend/src/modules/identity/identity.module.ts`
- Modify: `backend/src/modules/identity/internal/identity-auth.internal.module.ts`
- Modify: `backend/src/main.ts`
- Modify: exact tests/smokes/path-indexed architecture consumers
- Modify: R3/R5 manifests and tests
- Create ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-3-report.md`

**Interfaces:**
- Preserves: `IDENTITY_AUTH_PORT`, `IDENTITY_ACCESS_TOKEN_VERIFIER`, one
  `AuthService`, one `JwtStrategy`, and exact scheduler/provider ownership.

- [ ] **Step 1: Write RED provider/controller parity tests**

Capture base metadata and assert after relocation:

```typescript
assert.deepEqual(after.routes, before.routes);
assert.deepEqual(after.dtoDecorators, before.dtoDecorators);
assert.equal(after.providers.AuthService, 1);
assert.equal(after.providers.JwtStrategy, 1);
assert.equal(after.schedulers.AuthChallengeCleanupScheduler, 1);
assert.strictEqual(after.identityAuthPort, after.authService);
```

Add near-misses for duplicate provider registration, `useClass`, missing
scheduler, changed DTO decorator, altered error literal, and old-path facade.

- [ ] **Step 2: Run RED**

```powershell
node --test -r ts-node/register --test-name-pattern="R5 auth" `
  test/architecture-r5-identity-relocation.test.ts
```

Expected: target paths and strict stage subset fail.

- [ ] **Step 3: Move Auth files and update imports only**

Use the exact map. Preserve source bodies except relative imports and the
already-approved `OtpDispatchContext` type unification. Update `main.ts`, the
internal module, controller registration, tests, and smokes to canonical paths.
Set stage `task-3`.

- [ ] **Step 4: Run focused Auth/OTP/session gates**

```powershell
node --test -r ts-node/register `
  test/auth-otp-mode.test.ts `
  test/auth-refresh-wiring.test.ts `
  test/auth-registration-security.test.ts `
  test/auth-password-policy.test.ts `
  test/password-reset-logic.test.ts `
  test/login-throttle.test.ts `
  test/otp-dispatch-quota.test.ts `
  test/otp-controller-context.test.ts `
  test/architecture-r3-identity-port.test.ts `
  test/websocket-session-hardening.test.ts `
  test/architecture-r5-identity-relocation.test.ts
npm run architecture
npm run check
npm run build
```

Expected: PASS with exact errors, DTO rules, provider identities, and route
metadata.

- [ ] **Step 5: Commit local checkpoint**

```powershell
git add -A
git commit -m "refactor: move identity authentication internals"
```

Verify no file outside the manifest is staged and do not push.

---

### Task 4: Move Users, Me, And Contexts Then Retire Legacy Roots

**Files:**
- Move: `contexts/contexts.service.ts` and `users/users.service.ts` to `internal/profile/`
- Move: four controllers to `modules/identity/api/`
- Move: one Context DTO to `api/context-dto/`
- Move: four User DTOs to `api/user-dto/`
- Modify: `identity.module.ts` and `identity-profile.internal.module.ts`
- Modify: exact source/test/smoke/path-indexed consumers
- Modify: R3/R5 manifests, scanners, and tests
- Delete by completed moves: `backend/src/auth`, `backend/src/users`, `backend/src/me`, `backend/src/contexts`
- Create ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-4-report.md`

**Interfaces:**
- Preserves: Users/Contexts concrete singleton providers, controller routes,
  profile/context behavior, account-deletion lifecycle, and public helper identity.

- [ ] **Step 1: Write strict-root RED**

```typescript
for (const root of ['auth', 'contexts', 'me', 'users']) {
  assert.equal(existsSync(join(backendRoot, 'src', root)), false);
}
assert.equal(scanActiveImports().filter(isRetiredIdentityPath).length, 0);
```

Add fixtures proving an arbitrary new file, symlink/junction, old-path re-export,
test import, smoke import, or script literal under a retired root is rejected.

- [ ] **Step 2: Run RED**

```powershell
node --test -r ts-node/register --test-name-pattern="R5 strict roots" `
  test/architecture-r5-identity-relocation.test.ts
```

Expected: FAIL while profile/context files remain in legacy roots.

- [ ] **Step 3: Move profile/API files and update all consumers**

Use exact `git mv` targets, update imports, and set R3 Identity legacy roots to
an empty array only after every active file is gone. Set R5 stage `strict`.

- [ ] **Step 4: Run focused profile/context/account-deletion gates**

```powershell
node --test -r ts-node/register `
  test/contexts.test.ts `
  test/account-deletion.test.ts `
  test/account-deletion-recovery.test.ts `
  test/admin-app-identity.test.ts `
  test/privacy-contract.test.ts `
  test/notification-settings-truth.test.ts `
  test/push-notifications.test.ts `
  test/architecture-r5-identity-relocation.test.ts `
  test/architecture-r3-contexts.test.ts
npm run architecture
npm run check
npm run build
```

Expected: PASS and all four retired roots absent.

- [ ] **Step 5: Commit local checkpoint**

```powershell
git add -A
git commit -m "refactor: consolidate identity source layout"
```

---

### Task 5: Reconcile Baselines And Prove Mechanical Equivalence

**Files:**
- Modify: `backend/.dependency-cruiser-known-violations.json`
- Modify: `backend/architecture/ownership-baseline.json`
- Modify: `backend/architecture/r3-context-boundaries.json`
- Modify: `backend/architecture/r5-identity-relocation.json`
- Modify: architecture relocation tests/tools only as required by RED evidence
- Create ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-5-report.md`

**Interfaces:**
- Produces: dependency 89-record and ownership 385/781 path-equivalent baselines.

- [ ] **Step 1: Generate candidates outside the repository**

```powershell
$audit = Join-Path ([IO.Path]::GetTempPath()) ("aarast-r5-baseline-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $audit | Out-Null
try {
  npx depcruise --config .dependency-cruiser.cjs --output-type baseline `
    --output-to (Join-Path $audit 'dependency.json') src
  node scripts/architecture/ownership-scan.cjs --output (Join-Path $audit 'ownership.json')
  node scripts/architecture/r5-identity-scan.cjs --check `
    --dependency-candidate (Join-Path $audit 'dependency.json') `
    --ownership-candidate (Join-Path $audit 'ownership.json')
} finally {
  Remove-Item -LiteralPath $audit -Recurse -Force
}
```

Expected: verifier reports only exact move-map relocation, 89 dependency
records, and 385 ownership records / 781 occurrences.

- [ ] **Step 2: Prove semantic-drift RED fixtures**

Mutate one dependency `dependencyTypes`, one ownership `operation`, converge two
base paths into one target, and add one foreign model access. Each fixture must
fail with a fixed sanitized diagnostic.

- [ ] **Step 3: Replace tracked baselines only after verifier PASS**

Copy the verified candidate bytes into the two tracked baseline files. Rerun
the verifier against tracked bytes and require byte equality with freshly
generated candidates.

- [ ] **Step 4: Run complete static and behavior gates**

```powershell
npm run architecture:r5
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npx prisma generate
npm audit --omit=dev
npm audit
```

Expected: zero failures; full test artifact guard passes; 14 schema files, 52
models, 41 enums, and 76 migrations unchanged.

- [ ] **Step 5: Run managed smoke matrix and residue audits**

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
npm run smoke:all
```

After each group, require zero managed databases, Redis DB15 keys, smoke media
buckets, containers, volumes, networks, listeners, repository Node processes,
and current-run temp artifacts.

- [ ] **Step 6: Verify frozen surfaces and checkpoint**

Compare R5 base to candidate and require zero diff in Prisma schema/migrations/
seed, Mobile, Admin, workflows, deployment, Compose, and package locks. Run docs
sync/verify and `git diff --check`.

Commit:

```powershell
git add backend/.dependency-cruiser-known-violations.json `
  backend/architecture/ownership-baseline.json `
  backend/architecture/r3-context-boundaries.json `
  backend/architecture/r5-identity-relocation.json
git commit -m "test: reconcile R5 identity relocation baselines"
```

---

### Task 6: Final Source Review And Immutable Application Candidate

**Files:**
- Update ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-6-report.md`
- No tracked source change unless review produces a RED-first correction

**Interfaces:**
- Produces: independently reviewable immutable application candidate.

- [ ] **Step 1: Perform findings-first review**

Review exact move/body equivalence, import graph, public surface, provider and
controller metadata, baseline mapping, tests, security, error handling,
concurrency, transaction/lock behavior, frozen surfaces, and secret hygiene.
Every finding returns to its owning task with a permanent RED regression.

- [ ] **Step 2: Re-run final candidate gates**

Run R5/R3/R4/full architecture, check, build, full tests, required smokes,
docs, audits, Prisma equivalence, protected-surface, and residue checks on
unchanged bytes.

- [ ] **Step 3: Record immutable candidate identity**

```powershell
$candidate = git rev-parse HEAD
$candidate
git status --short
git log -1 --format="%H %P %s"
```

Expected: clean tree, one-parent local commit chain, no merge commit.

---

### Task 7: Build, Probe, Cut Over, And Test On Phone

**Files:**
- Update ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-7-report.md`
- No tracked source change

**Interfaces:**
- Produces: immutable R5 runtime and owner phone acceptance; preserves R4 rollback.

- [ ] **Step 1: Build the immutable local image**

```powershell
$candidate = git rev-parse HEAD
$tag = "aarast-backend:r5-final-$($candidate.Substring(0,8))"
docker build --label "org.opencontainers.image.revision=$candidate" -t $tag backend
```

Inspect only safe image metadata. Do not print image environment variables.

- [ ] **Step 2: Run protected probe**

Start a unique probe container on an unused loopback port using the existing
private runtime inputs without printing them. Require all 76 migrations,
`/live` and `/ready` HTTP 200, exact OCI revision, restart 0, OOM false, and no
fatal/unhandled/TypeError/Prisma/schema-missing marker. Remove probe resources.

- [ ] **Step 3: Cut over while preserving R4**

Stop but preserve the accepted R4 container/image. Start exactly one R5 phone
container on `aarast_default` and host port 3120. Verify local and assigned-LAN
live/ready 200, exact image/revision, restart 0, OOM false, and required
dependencies up. On failure, stop R5 and restore the exact preserved R4
container before debugging.

- [ ] **Step 4: Owner phone checkpoint**

The owner tests:

1. login or local WhatsApp OTP;
2. Home loads;
3. profile/context reads correctly;
4. one safe core read/write succeeds;
5. force-stop/reopen restores the same authenticated context;
6. no unexpected logout, stale context, duplicate action, or error appears.

Retain only sanitized method/route-template/status counts and artifact identity.
Never retain OTP, phone, password, token, request body, or private values.

- [ ] **Step 5: Recheck runtime after owner PASS**

Require exact image/revision, restart 0, OOM false, local/LAN health 200, safe
logs, R4 stopped/preserved, and zero probe/temp residue.

---

### Task 8: Truthful Receipts And Local R5 Closeout

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`
- Update ignored: `.superpowers/sdd/2026-08-20-modular-monolith-r5-identity-relocation/task-8-report.md`

**Interfaces:**
- Consumes: immutable source, gates, runtime, phone, rollback, and review evidence.
- Produces: truthful local R5 completion receipt and explicit R6 stop.

- [ ] **Step 1: Complete final independent review**

Require no unresolved Critical, Important, or Minor finding across source,
architecture, baseline, runtime, phone evidence, and receipt truth.

- [ ] **Step 2: Update the eight active receipts**

Record exact base/candidate/receipt identities, 44 moves, retired roots, baseline
counts, unchanged surfaces, exact checks, runtime/image/rollback, sanitized
phone result, known limits, and local-only truth. State explicitly: no push,
merge, PR mutation, deployment, remote CI, or R6 start.

- [ ] **Step 3: Run final receipt gates**

```powershell
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
git diff --check
Set-Location backend
npm run architecture:r5
npm run architecture
Set-Location ..
```

Expected: documentation drift/errors/warnings 0, R5 strict PASS, architecture
green, dependency 89, ownership 385/781, four legacy roots absent.

- [ ] **Step 4: Create optional local docs receipt commit**

With the existing local-commit authorization:

```powershell
git add ARCHITECTURE.md CHANGELOG.md docs/README.md docs/backend/README.md `
  docs/project/DECISIONS.md docs/project/EXECUTION_PLAN.md `
  docs/project/STATUS.md docs/qa/README.md
git commit -m "docs: close modular monolith R5 locally"
```

Verify exactly eight Markdown files, clean worktree, unchanged application image
revision, live/ready 200, and R4 rollback preserved.

- [ ] **Step 5: Stop before R6**

Report local commits, changed paths, all PASS/FAIL/BLOCKED evidence, runtime,
rollback, phone result, and remaining limits. Do not push, merge, deploy, mutate
PR #76, claim remote CI, or begin R6.

## Plan Self-Review Receipt

- Every design requirement maps to Task 0-8.
- The 44-file move is one-to-one and divided into public, Auth, and profile/API
  checkpoints with an independent RED/GREEN cycle.
- Cross-context runtime/type/pure helpers are exact pre-existing consumers, not
  speculative ports.
- R3 provider/controller/route/decorator/lifecycle laws remain live.
- Dependency and ownership baselines allow path relocation only and keep
  89 records and 385/781 respectively.
- Schema, behavior, Mobile, Admin, deployment, workflows, locks, and packages
  remain frozen.
- Runtime and phone acceptance are tied to one immutable local candidate with
  R4 preserved for rollback.
- No compatibility layer, placeholder, weakened test, blind baseline update,
  future-phase work, push, merge, deployment, or remote-CI claim is authorized.
