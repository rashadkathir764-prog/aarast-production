# Modular Monolith R0 Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the complete, machine-enforced R0 governance baseline for Aarast's modular-monolith migration without moving application source, changing runtime behavior, changing routes, or changing the database schema.

**Architecture:** R0 introduces one tracked architecture contract, incremental dependency and ownership gates, a report/baseline Mobile boundary gate, and explicit CI wiring. Existing violations are recorded in deterministic baselines, counted by key for ownership and Mobile: new violations fail immediately, removed violations are allowed, and strict rules are activated phase-by-phase in R3-R9. Backend modules will later use the documented `InternalModule` + `PublicModule` + full module pattern; R0 documents and tests the pattern but creates none of the 13 target modules.

**Tech Stack:** NestJS 11, TypeScript 5.9, Prisma 6.19.3, Node.js 22 in CI, dependency-cruiser 18.1.0, Node's built-in test runner, Flutter 3.41.7, GitHub Actions, Markdown documentation.

## Global Constraints

- Work only on branch `modular-monolith`, created from `feafe3db0053d6c66d5f46b56ff9a512861dfbad`.
- R0 is the first authorized P3 slice. Preserve completed P2 checkpoints; mark further P2 implementation paused while R0 is active.
- R0 MUST NOT modify anything under `backend/src/**`, `mobile/lib/**`, `admin-web/src/**`, `backend/prisma/schema.prisma`, `backend/prisma/migrations/**`, `deploy/**`, any Dockerfile, or `docker-compose.yml`.
- R0 MUST NOT create Nest feature modules, ports, repositories, Flutter barrels, provider-portal files, Admin feature folders, migrations, endpoints, routes, or product behavior.
- Preserve every HTTP method/path/auth flag, response/error/Arabic contract, transaction isolation level, lock order, permission decision, mobile route, Admin route, offline ownership rule, and deployment artifact.
- The live Prisma registry contains exactly 52 models and 76 committed migrations at the baseline revision. Derive counts from source during checks; do not use a stale hard-coded test-count invariant.
- The final physical table-ownership rule has no exception: `WeddingPlan` remains physically owned by planning. Finance's current writes to `WeddingPlan.estimatedBudget` are a temporary baselined violation that R4 must replace with a planning public write port.
- Existing test assertions, expected values, fixtures, Arabic messages, and setup behavior are frozen. Later phases may make reviewed mechanical import/export/require edits, source-path literal edits, test moves, and DI wiring edits only when required by a source move; R0 changes none of those existing tests except additive architecture tests.
- A baseline records violations, not permissions. Current entries may disappear without regenerating the baseline. Ownership and Mobile baselines are counted by canonical key, so a new key or increased count fails; dependency-cruiser freezes unique `rule|from|to` graph violations, so a new edge or cycle fails.
- Never write an absolute local path, environment value, credential, URL secret, token, database credential, admin credential, or production identifier into a baseline.
- Planned commit steps are checkpoints only. Do not commit, push, merge, or open a PR during execution unless the owner explicitly authorizes that Git action in the execution session.

---

## Live-Review Corrections Binding This Plan

These decisions supersede stale details in the 2026-08-04 external design while preserving its R0 intent:

1. Source-derived baseline facts are 52 Prisma models, 76 migrations, and 92 top-level Backend test files at the R0 base revision; do not use the older 48/75/90 counts.
2. dependency-cruiser configuration and baseline live under `backend/`, beside the only relevant `package.json`, lockfile, TypeScript configuration, and CI working directory. Do not create a root Node package or root dependency-cruiser file.
3. New Backend architecture tests remain directly under `backend/test/`. The current test orchestrator discovers top-level `*.test.ts` files only, so a nested `backend/test/architecture/` directory would silently miss the gate.
4. `WeddingPlan` has one physical owner, planning. Finance's current direct access is recorded as R0 debt and removed in R4; it is not encoded as a permanent ownership exception.
5. Ownership and Mobile checks are counted baseline gates in R0. They allow debt removal, reject additions/increases, and become strict only in the later phase assigned by the architecture roadmap.
6. Existing behavioral tests are semantically frozen, not textually import-only. Later move phases may perform the narrow mechanical path/import/DI/test-file moves listed in Global Constraints; R0 edits no existing behavioral test.

---

## R0 Completion Contract

R0 is complete only when all of the following are true:

1. `ARCHITECTURE.md` is the tracked human source of truth and is linked from the active documentation map.
2. The 52-model ownership registry is machine-readable and matches the live Prisma schema exactly.
3. dependency-cruiser fails on any new cross-context dependency or import cycle while ignoring only the committed known-violation baseline.
4. The ownership scanner covers root delegates, relation traversal/nested writes, direct and nested Prisma SQL forms, and fails on any new foreign-model access, increased violation count, unclassified database access, unknown operation/relation shape, or unresolved table identifier; new owner-local access remains legal.
5. The ports scanner resolves Nest symbols rather than matching spellings, keeps `forwardRef()` at zero, requires the observed `@Global()` path set to equal the two-file R0 allowlist, rejects future cross-module internal imports, and verifies the current Nest module-import graph remains acyclic.
6. The Mobile checker tokenizes all Dart library directives, rejects unresolved/cross-area `part` relationships immediately, and fails when current `core -> features` or direct cross-feature imports increase, while strict barrel enforcement remains deferred to R9.
7. CI runs every new architecture gate with the repository-pinned dependency and no network-time `npx` installation; the `r0-scope` PR-head job enforces the fixed-base exact file allowlist automatically.
8. Existing Backend, Admin, Mobile, docs, image, audit, secret, and managed E2E CI jobs remain green.
9. The protected application/schema/deployment paths listed in Global Constraints have an empty diff from the R0 base revision.

## Target File Map

### Existing Working Artifact

- `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md` — this approved execution plan; keep its contents unchanged during implementation unless a discovered fact requires a reviewed plan correction.

### Create

- `ARCHITECTURE.md` — canonical laws, target module map, ownership registry, lifecycle, and phase-enforcement matrix.
- `backend/.dependency-cruiser.cjs` — current-context and future-module import rules.
- `backend/.dependency-cruiser-known-violations.json` — dependency-cruiser's committed R0 baseline.
- `backend/architecture/ownership-registry.json` — machine-readable 52-model ownership and current-folder map.
- `backend/architecture/ownership-baseline.json` — counted current foreign-model accesses and unresolved database-access baseline.
- `backend/scripts/architecture/ownership-scan.cjs` — symbol-resolved root/relation Prisma and tokenized SQL ownership scanner.
- `backend/scripts/architecture/ports-scan.cjs` — symbol-resolved Nest/ports/global/forwardRef/dynamic-module graph scanner.
- `backend/test/architecture-ownership.test.ts` — additive scanner and live-registry tests discovered by the current top-level runner.
- `backend/test/architecture-ports.test.ts` — additive ports/global/graph tests discovered by the current top-level runner.
- `backend/test/architecture-dependencies.test.ts` — additive temporary-fixture regression tests proving known dependency edges are ignored while new edges and cycles fail.
- `scripts/check-mobile-boundaries.mjs` — deterministic Dart-directive/part-aware Mobile boundary scanner and CLI.
- `scripts/check-mobile-boundaries.test.mjs` — Node tests for resolution, baselines, and strict-mode rules.
- `scripts/architecture/mobile-boundaries-baseline.json` — counted R0 Mobile legacy boundary baseline.
- `scripts/check-r0-scope.mjs` — fixed-base, exact-allowlist R0 change-surface gate used locally and in CI.
- `scripts/check-r0-scope.test.mjs` — unit and live CLI tests for the R0 scope gate.

### Modify

- `AGENTS.md` — short mandatory architecture guard section.
- `backend/package.json` — exact dependency and architecture scripts.
- `backend/package-lock.json` — lock dependency-cruiser 18.1.0 and transitive dependencies.
- `.github/workflows/ci.yml` — run Backend and Mobile architecture gates.
- `docs/README.md` — link the canonical architecture and the one current R0 working plan.
- `docs/project/DECISIONS.md` — record R0 authorization and corrected ownership/test policies.
- `docs/project/EXECUTION_PLAN.md` — pause further P2 work and mark P3/R0 active.
- `docs/backend/README.md` — link Backend architecture gates.
- `docs/frontend/MOBILE_ARCHITECTURE.md` — document baseline mode and the routing composition exception.
- `docs/qa/README.md` — document the R0 commands and protected-test policy.
- `docs/SCRIPTS.md` — regenerate after package-script changes; never hand-edit its generated block.
- `docs/project/STATUS.md` — record observed R0 results only after the full gate passes.
- `CHANGELOG.md` — record the completed governance slice only after verification.

### Explicitly Untouched

- `backend/src/**`
- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/**`
- `mobile/lib/**`
- `mobile/test/**`
- `mobile/integration_test/**`
- `admin-web/src/**`
- `deploy/**`, Dockerfiles, and Compose files

---

### Task 1: Establish the Canonical Architecture and Phase Contract

**Files:**
- Create: `ARCHITECTURE.md`
- Modify: `AGENTS.md`
- Modify: `docs/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/frontend/MOBILE_ARCHITECTURE.md`
- Modify: `docs/qa/README.md`

**Interfaces:**
- Consumes: the live schema at `backend/prisma/schema.prisma`, the active documentation map, and the approved external modular-monolith design.
- Produces: one human contract whose module names and model ownership exactly match `backend/architecture/ownership-registry.json` created in Task 3.

- [ ] **Step 1: Capture the immutable R0 source facts before editing docs**

Run from the repository root:

```powershell
$r0Base = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad'
git branch --show-current
git rev-parse HEAD
git status --short --untracked-files=all
(Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+').Count
(Get-ChildItem .\backend\prisma\migrations -Directory).Count
(Get-ChildItem .\backend\test -File -Filter '*.test.ts').Count
rg -n 'forwardRef\s*\(' .\backend\src
rg -n '@Global\(' .\backend\src
```

Expected:

- branch: `modular-monolith`
- HEAD: `$r0Base`
- status contains only `?? docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md` before implementation; any other path is a stop signal
- models: `52`
- migrations: `76`
- top-level Backend test files: `92` before additive R0 tests
- zero `forwardRef()` calls
- exactly two `@Global()` matches

- [ ] **Step 2: Write `ARCHITECTURE.md` with the exact target module map**

The document must name these 13 business modules and no additional business module:

```markdown
| Module | Current roots | Owns |
| --- | --- | --- |
| identity | auth, users, me, contexts | identity/session models |
| planning | wedding-plans, onboarding | WeddingPlan |
| finance | money, budget-categories, wedding-costs | budget/cost/payment/schedule models |
| collaboration | sharing, contribution-history | sharing and contribution-history models |
| tasks | tasks | task and checklist models |
| guests | guests | guest and guest-group models |
| marketplace | marketplace, provider-dashboard | provider, review, quote, favorite, and plan-provider models |
| messaging | conversations | conversation, event, message, attachment, and report models |
| notifications | notifications, push | notification, preference, and push-installation models |
| catalog | catalogs plus current catalog reads in marketplace | geography, provider category, and reference-catalog models |
| media | media | MediaUploadTicket |
| insights | dashboard, timeline | no models; read composition only |
| backoffice | admin | AdminAuditLog |
```

Also define platform ownership of `IdempotencyKey` and `OutboxEvent`; platform is not one of the 13 business modules.

- [ ] **Step 3: Define the exact Nest module pattern**

Add this binding rule, including the reason that R3 facades cannot import full legacy modules:

```typescript
// Naming contract documented by R0; these files are created in R3+, not R0.
@Module({ providers: [LegacyNameService], exports: [LegacyNameService] })
export class NameInternalModule {}

@Module({
  imports: [NameInternalModule],
  providers: [{ provide: NAME_PORT, useExisting: LegacyNameService }],
  exports: [NAME_PORT],
})
export class NamePublicModule {}

@Module({
  imports: [NameInternalModule, NamePublicModule],
  controllers: [NameController],
})
export class NameModule {}
```

Document these laws:

- `InternalModule` is private to its owning bounded context.
- `PublicModule` exports Symbol tokens and public types only.
- A full module may import another context's `PublicModule`, never its full or internal module.
- During migration, a context is the union of its legacy roots and `src/modules/<context>`; any edge involving a future module may cross context only into the target's `public/` slice, while legacy-to-legacy debt remains frozen by the R0 dependency baseline.
- The Nest class/import graph must remain acyclic and `forwardRef()` remains forbidden.
- Reciprocal business consumption is legal only when the two public provider slices do not import one another.
- Dependency direction is `business modules -> platform -> shared-kernel`; business modules may also import `shared-kernel` directly, while `platform` may not import business modules and `shared-kernel` may import neither `platform` nor business modules.

- [ ] **Step 4: Correct the physical ownership contract**

State explicitly:

```markdown
`WeddingPlan` has one physical owner: planning. Finance's current direct write
to `WeddingPlan.estimatedBudget` is a temporary R0 baseline violation, not a
permanent architecture exception. R4 must replace it with a planning public
write port that accepts the caller's explicit transaction client.
```

Do not preserve the old E1 exception as a target rule.

Also state that physical ownership applies to root delegates, Prisma relation traversal (`include`, `select`, relation filters/orderings), nested relation writes, and every physical table referenced by raw SQL. An unresolved relation/query shape is architecture debt, not implicit permission.

- [ ] **Step 5: Correct the Mobile architecture contract**

Document two different modes:

```markdown
- R0 baseline mode: existing direct imports may remain but their counted set
  may only shrink.
- R9 strict mode: cross-feature imports target `<feature>_api.dart`; all
  `core/** -> features/**` imports are forbidden except route assembly under
  `core/routing/**`, which may import feature public route/screen barrels.
```

The routing exception is a composition-root exception, not a general permission for core to consume feature state or models.

Document that Dart `part`/`part of` is a compilation-unit relationship, not a boundary escape: both files must resolve, declare each other through URI-style directives, and remain inside the same feature/core area. Cross-area parts and unresolved local directives fail immediately in every phase.

- [ ] **Step 6: Record the corrected test-change policy**

Add the following policy to `ARCHITECTURE.md`, `docs/qa/README.md`, and the decision log:

```markdown
Existing behavioral assertions, expected values, fixtures, Arabic/error
contracts, and setup semantics are frozen. A later move phase may make only
reviewed mechanical import/export/require edits, moved-source path-literal
edits, test-file moves, and DI token wiring edits required by that move. Any
other existing-test change is a stop signal and requires explicit review.
```

R0 itself adds tests and does not edit existing behavioral tests.

- [ ] **Step 7: Record the phase transition**

Update `docs/project/EXECUTION_PLAN.md` so it states:

- completed P2 checkpoints remain accepted;
- further P2 implementation is paused by owner direction;
- P3 R0 Governance is active on `modular-monolith`;
- R0 has zero application-source moves;
- R0's pull request requires the `r0-scope` fixed-base allowlist job; R1 must remove or retarget that phase-specific job after R0 closes;
- the tracked R0 receipt records local checks only; immutable candidate SHA and CI status are resolved from PR/workflow metadata and never back-written into a self-referential tracked document;
- R1 cannot start until every R0 exit gate is green.

Update `docs/project/DECISIONS.md` with the same decision and rationale. Do not mark R0 complete.

- [ ] **Step 8: Link only the current working plan**

Add `ARCHITECTURE.md` to the root active-doc list in `docs/README.md`. Add this R0 plan under a clearly labelled `Current Working Plan` entry. Do not restore archived `docs/superpowers` files or treat them as active truth.

- [ ] **Step 9: Add the short mandatory guard to `AGENTS.md`**

The guard must say:

```markdown
## Modular Monolith Guard

- Read `ARCHITECTURE.md` before architecture work.
- Cross-context Backend code consumes only the owner's public contract.
- No new foreign Prisma root/relation/SQL access, `forwardRef()`, or `@Global()` use.
- No new Mobile boundary-baseline entry, unresolved local directive, or cross-area `part` relationship.
- A phase cannot start until the prior phase gate is green.
```

- [ ] **Step 10: Verify documentation before continuing**

Run:

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: all PASS. If `docs-sync --check` reports only script-catalog drift caused by later package changes, do not update it in this task; Task 6 owns regeneration.

- [ ] **Step 11: Review the documentation diff**

Run:

```powershell
git diff -- ARCHITECTURE.md AGENTS.md docs/README.md docs/project/DECISIONS.md docs/project/EXECUTION_PLAN.md docs/backend/README.md docs/frontend/MOBILE_ARCHITECTURE.md docs/qa/README.md
```

Expected: architecture/phase/test-policy changes only; no claim that R0 tooling already exists or passes.

- [ ] **Step 12: Commit checkpoint only when Git authorization is present**

```powershell
git add ARCHITECTURE.md AGENTS.md docs/README.md docs/project/DECISIONS.md docs/project/EXECUTION_PLAN.md docs/backend/README.md docs/frontend/MOBILE_ARCHITECTURE.md docs/qa/README.md
git commit -m "docs: establish modular monolith R0 contract"
```

---

### Task 2: Add the Incremental Dependency-Cruiser Gate

**Files:**
- Create: `backend/.dependency-cruiser.cjs`
- Create: `backend/.dependency-cruiser-known-violations.json`
- Create: `backend/test/architecture-dependencies.test.ts`
- Modify: `backend/package.json`
- Modify: `backend/package-lock.json`

**Interfaces:**
- Consumes: current folder-to-context mappings from `ARCHITECTURE.md`.
- Produces: `npm run architecture:imports`, which returns zero only when no unbaselined unique `rule|from|to` violation or import cycle exists, plus a discovered top-level regression test that proves baseline behavior against temporary source graphs.

- [ ] **Step 1: Install the exact CI-compatible dependency**

Run from `backend/`:

```powershell
npm install --save-dev --save-exact dependency-cruiser@18.1.0
```

Expected changes: `backend/package.json` and `backend/package-lock.json` only. Do not use a root `package.json`; the repository has no root Node package.

- [ ] **Step 2: Write the failing dependency-baseline regression tests**

Create `backend/test/architecture-dependencies.test.ts`. Use only temporary directories; never write a fixture below `backend/src`. The test body is:

```typescript
import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const backendRoot = path.resolve(__dirname, '..');
const configPath = path.join(backendRoot, '.dependency-cruiser.cjs');
const cliPath = path.join(
  backendRoot,
  'node_modules',
  '.bin',
  process.platform === 'win32' ? 'depcruise.cmd' : 'depcruise',
);
const temporaryRoots: string[] = [];

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureRoot() {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-depcruise-'));
  temporaryRoots.push(root);
  write(root, 'tsconfig.json', JSON.stringify({
    compilerOptions: { module: 'commonjs', target: 'ES2022' },
    include: ['src/**/*.ts'],
  }));
  return root;
}

function cruise(root: string, args: string[]) {
  return spawnSync(cliPath, args, {
    cwd: root,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('known edge is ignored and a new cross-context edge fails', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/auth/known.ts', "import '../guests/public';\n");
  write(root, 'src/guests/public.ts', 'export const guest = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  const known = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.equal(known.status, 0, known.stderr || known.stdout);
  write(root, 'src/tasks/new.ts', "import '../guests/public';\n");
  const added = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(added.status, 0);
  assert.match(`${added.stdout}\n${added.stderr}`, /context-tasks-cross-context/);
});

test('a new cycle fails even when the known baseline is enabled', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/planning/a.ts', "import '../finance/b';\n");
  write(root, 'src/finance/b.ts', "import '../planning/a';\n");
  const added = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(added.status, 0);
  assert.match(`${added.stdout}\n${added.stderr}`, /no-circular/);
});

test('legacy code may consume only a future context public slice', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/modules/guests/public/index.ts', 'export const guestsPort = true;\n');
  write(root, 'src/tasks/allowed.ts', "import '../modules/guests/public/index';\n");
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('mixed legacy/future internal edges and platform-to-future edges fail', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/planning/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/guests/legacy.ts', 'export const legacyGuest = true;\n');
  write(root, 'src/modules/guests/internal/secret.ts', 'export const secret = true;\n');
  write(root, 'src/modules/tasks/public/index.ts', 'export const taskPort = true;\n');
  write(root, 'src/modules/tasks/application/use.ts', "import '../../../guests/legacy';\n");
  write(root, 'src/tasks/bad.ts', "import '../modules/guests/internal/secret';\n");
  write(root, 'src/common/platform.ts', "import '../modules/tasks/public/index';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /context-tasks-cross-context/);
  assert.match(output, /current-platform-no-business-contexts/);
});

test('shared kernel cannot import a legacy business context', () => {
  const root = fixtureRoot();
  const baseline = path.join(root, 'known.json');
  write(root, 'src/shared-kernel/seed.ts', 'export const seed = true;\n');
  const generated = cruise(root, [
    '--config', configPath, '--output-type', 'baseline', '--output-to', baseline, 'src',
  ]);
  assert.equal(generated.status, 0, generated.stderr || generated.stdout);
  write(root, 'src/auth/legacy.ts', 'export const legacyAuth = true;\n');
  write(root, 'src/shared-kernel/bad.ts', "import '../auth/legacy';\n");
  const result = cruise(root, ['--config', configPath, '--ignore-known', baseline, 'src']);
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /shared-kernel-is-foundational/);
});
```

- [ ] **Step 3: Run the focused regression test and verify failure**

```powershell
node --test -r ts-node/register test/architecture-dependencies.test.ts
```

Expected: FAIL because `.dependency-cruiser.cjs` does not exist yet. A missing CLI binary means Step 1 was not completed and is also a failure.

- [ ] **Step 4: Add the package scripts**

Add these exact scripts:

```json
{
  "architecture:imports": "depcruise --config .dependency-cruiser.cjs --ignore-known .dependency-cruiser-known-violations.json src",
  "architecture:imports:baseline": "depcruise --config .dependency-cruiser.cjs --output-type baseline --output-to .dependency-cruiser-known-violations.json src",
  "architecture:ownership": "node scripts/architecture/ownership-scan.cjs --check",
  "architecture:ports": "node scripts/architecture/ports-scan.cjs --check",
  "architecture": "npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports"
}
```

Keep every existing script name and command string unchanged; add only the five entries above.

- [ ] **Step 5: Write the dependency rules**

Create `backend/.dependency-cruiser.cjs` with data-driven current and target contexts. Use this structure rather than hand-copying nearly identical rules:

```javascript
'use strict';

const businessContexts = [
  ['identity', ['auth', 'users', 'me', 'contexts']],
  ['planning', ['wedding-plans', 'onboarding']],
  ['finance', ['money', 'budget-categories', 'wedding-costs']],
  ['collaboration', ['sharing', 'contribution-history']],
  ['tasks', ['tasks']],
  ['guests', ['guests']],
  ['marketplace', ['marketplace', 'provider-dashboard']],
  ['messaging', ['conversations']],
  ['notifications', ['notifications', 'push']],
  ['catalog', ['catalogs']],
  ['media', ['media']],
  ['insights', ['dashboard', 'timeline']],
  ['backoffice', ['admin']],
];

const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const contextPattern = ([name, roots]) =>
  `(?:${roots.map(escape).join('|')}|modules/${escape(name)})`;
const allBusinessPaths = businessContexts.map(contextPattern).join('|');
const contextRules = businessContexts.map(([name, ownRoots]) => {
  const ownPaths = contextPattern([name, ownRoots]);
  return {
    name: `context-${name}-cross-context`,
    comment: `Only the same context or another context's public slice is importable from ${name}`,
    severity: 'error',
    from: { path: `^src/${ownPaths}(?:/|$)` },
    to: {
      path: `^src/(?:${allBusinessPaths})(?:/|$)`,
      pathNot: `^src/${ownPaths}(?:/|$)|^src/modules/[^/]+/public(?:/|$)`,
    },
  };
});

const currentPlatformRule = {
  name: 'current-platform-no-business-contexts',
  comment: 'R0 baseline freezes current imports from platform roots into business contexts',
  severity: 'error',
  from: { path: '^src/(?:common|prisma|outbox|health)(?:/|$)' },
  to: { path: `^src/(?:${allBusinessPaths})(?:/|$)` },
};

module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    currentPlatformRule,
    ...contextRules,
    {
      name: 'domain-no-nest-runtime',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain(?:/|$)' },
      to: { path: '^(?:node_modules/)?@nestjs/' },
    },
    {
      name: 'platform-no-business-contexts',
      severity: 'error',
      from: { path: '^src/platform(?:/|$)' },
      to: { path: `^src/(?:${allBusinessPaths})(?:/|$)` },
    },
    {
      name: 'shared-kernel-is-foundational',
      severity: 'error',
      from: { path: '^src/shared-kernel(?:/|$)' },
      to: { path: `^src/(?:platform|${allBusinessPaths})(?:/|$)` },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
    tsPreCompilationDeps: true,
    reporterOptions: { dot: { collapsePattern: 'node_modules/[^/]+' } },
  },
};
```

- [ ] **Step 6: Run the dependency-baseline regression tests**

```powershell
node --test -r ts-node/register test/architecture-dependencies.test.ts
```

Expected: all five fixture tests PASS: known/new edge behavior, new cycle rejection, allowed legacy-to-future-public consumption, rejection of future-to-legacy, legacy-to-future-internal, and platform-to-future edges, and rejection of shared-kernel imports from legacy business roots.

- [ ] **Step 7: Prove the strict rules see current violations**

Run before creating the baseline:

```powershell
.\node_modules\.bin\depcruise.cmd --config .dependency-cruiser.cjs --no-ignore-known src
```

Expected: non-zero with current cross-context violations. If it returns zero, stop: the current rules are not scanning the real graph.

- [ ] **Step 8: Generate the deterministic known-violation baseline**

Run:

```powershell
npm run architecture:imports:baseline
```

Inspect the JSON and confirm dependency-cruiser's tool-owned entries use only Backend-working-directory-relative `src/...` paths and rule names. Reject any absolute path or path outside `src/`. Custom ownership and Mobile baselines use repository-root-relative paths instead.

- [ ] **Step 9: Prove live-repository baseline behavior**

Run:

```powershell
npm run architecture:imports
```

Expected: PASS with known violations reported as ignored.

Immediately re-run the exact strict command with the baseline disabled:

```powershell
.\node_modules\.bin\depcruise.cmd --config .dependency-cruiser.cjs --no-ignore-known src
```

Expected: non-zero with the same current cross-context violations. The paired results prove that the normal gate passes only because the checked-in baseline suppresses already-known violations. Do not modify `backend/src` to manufacture another violation.

- [ ] **Step 10: Verify package integrity**

```powershell
npm run check
npm audit --audit-level=high
npm audit --omit=dev
```

Expected: `npm run check` PASS, full audit has no high/critical findings including dev dependencies, and the production-only audit has zero findings.

- [ ] **Step 11: Commit checkpoint only when Git authorization is present**

```powershell
git add backend/.dependency-cruiser.cjs backend/.dependency-cruiser-known-violations.json backend/test/architecture-dependencies.test.ts backend/package.json backend/package-lock.json
git commit -m "build: add incremental backend dependency gate"
```

---

### Task 3: Add the Prisma Ownership Registry, Scanner, and Baseline

**Files:**
- Create: `backend/architecture/ownership-registry.json`
- Create: `backend/architecture/ownership-baseline.json`
- Create: `backend/scripts/architecture/ownership-scan.cjs`
- Create: `backend/test/architecture-ownership.test.ts`

**Interfaces:**
- Consumes: `backend/prisma/schema.prisma`, `backend/tsconfig.json`, every `backend/src/**/*.ts` file, and the machine registry.
- Produces: `extractSchemaMetadata(schemaText)`, `toRepositoryPath(file, repoRoot, pathApi)`, `contextForRepositoryPath(file, registry)`, `classifyOwnershipAccesses(options)`, `scanOwnershipViolations(options)`, `compareWithBaseline(scan, baseline)`, `runCli(dependencies)`, and `node scripts/architecture/ownership-scan.cjs --check`.

All persisted paths use one canonical form: `/`-separated paths relative to the repository root, for example `backend/src/marketplace/marketplace.service.ts`. Never persist Backend-root-relative `src/...` paths or absolute paths.

```typescript
type AccessMode = 'read' | 'write' | 'unknown';
type OwnershipViolationReason =
  | 'foreign-model'
  | 'unclassified-context'
  | 'unknown-model'
  | 'unknown-operation'
  | 'unknown-relation-shape'
  | 'unknown-sql-composition';
type OwnershipViolation = {
  file: string;
  context: string;
  owner: string | null;
  model: string;
  operation: string;
  mode: AccessMode;
  source: 'delegate' | 'relation' | 'sql';
  reason: OwnershipViolationReason;
  count: number;
};
```

Use `<dynamic>` when a table or relation shape cannot be resolved. The key is `file|context|owner|model|operation|mode|source|reason`; line/column are diagnostics only.

`classifyOwnershipAccesses` and `scanOwnershipViolations` accept `{ repoRoot, backendRoot }`; they derive schema, tsconfig, registry, and source paths below those roots. In the live test, set `repoRoot = path.resolve(__dirname, '../..')`, `backendRoot = path.resolve(__dirname, '..')`, and `liveOptions = { repoRoot, backendRoot }`.

- [ ] **Step 1: Write failing registry, path, relation, SQL, baseline, and CLI tests**

Create `backend/test/architecture-ownership.test.ts`. The permanent registry test is dynamic and must not assert `52`:

```typescript
test('registry and schema contain the same models exactly once', () => {
  const metadata = extractSchemaMetadata(schemaText);
  const registered = Object.values(registry.owners).flat();
  assert.deepEqual([...registered].sort(), [...metadata.models].sort());
  assert.equal(new Set(registered).size, registered.length);
});

test('current roots are complete, unique, and use the owner contexts', () => {
  assert.deepEqual(
    Object.keys(registry.currentRoots).sort(),
    Object.keys(registry.owners).sort(),
  );
  const roots = Object.values(registry.currentRoots).flat();
  assert.equal(new Set(roots).size, roots.length);
  const unclassified = classifyOwnershipAccesses(liveOptions)
    .filter((access) => access.context === 'unclassified')
    .map((access) => access.file);
  assert.deepEqual([...new Set(unclassified)].sort(), []);
});

test('repository paths classify identically on Windows and Linux', () => {
  assert.equal(
    toRepositoryPath('D:\\repo\\backend\\src\\auth\\auth.service.ts', 'D:\\repo', path.win32),
    'backend/src/auth/auth.service.ts',
  );
  assert.equal(
    toRepositoryPath('/repo/backend/src/auth/auth.service.ts', '/repo', path.posix),
    'backend/src/auth/auth.service.ts',
  );
});
```

Add temporary-program fixtures that prove every row below. Each expected violation asserts `file`, `model`, `owner`, `mode`, `source`, and `reason`:

| Fixture | Expected |
| --- | --- |
| identity `user.findUnique` | owner-local root read; no violation |
| finance `weddingCost.create` | owner-local root write; no violation |
| finance `weddingPlan.update` | planning `foreign-model` write |
| marketplace `provider.findMany({ include: { city: true, primaryCategory: true } })` | two catalog relation-read violations |
| marketplace nested `services.select.category` | catalog relation-read violation reached through marketplace relation |
| planning nested `weddingCosts.create` | finance relation-write violation |
| relation filter/orderBy on `city` | catalog relation-read violation |
| finance `budgetCategory.findMany({ include: { _count: { select: { weddingCosts: true } } } })` | owner-local finance relation count; no violation |
| backoffice `providerCategory.findMany({ include: { _count: { select: { providers: true, services: true } } } })` | two marketplace relation-read violations |
| same-file `const args = { include: { city: true } }` | resolves identically to inline object |
| call/import/computed spread whose relation shape cannot be resolved | `unknown-relation-shape` |
| direct ``tx.$queryRaw`SELECT * FROM "WeddingPlan" WHERE id = ${planId}``` | planning SQL read; value interpolation is not dynamic-table debt |
| a `$queryRaw` call whose first argument is a `Prisma.sql` tagged template joining `"Conversation"` and `"ChatMessage"` | one record per physical table |
| a `Prisma.join` whose array initializer contains two resolvable `Prisma.sql` fragments reading `WeddingPlan` and `User` | both physical tables detected from resolvable fragments |
| `Prisma.join(planIds)` where checker proves a scalar array | value placeholders; no hidden-table debt |
| mutable/computed `Prisma.Sql[]` passed to `Prisma.join` | `unknown-sql-composition` |
| a ``const predicate = condition ? Prisma.sql`...` : Prisma.sql`...``` interpolated directly into an outer `Prisma.sql` template | recursively resolve and scan both conditional branches |
| a direct interpolation whose checker type includes `Prisma.Sql` but whose initializer is mutable, imported dynamically, or otherwise unresolved | `unknown-sql-composition` |
| `WITH recent AS (SELECT * FROM "ChatMessage") SELECT * FROM recent` | `ChatMessage` recorded; CTE alias ignored |
| interpolated table identifier after `FROM` | `unknown-model` with `<dynamic>` |
| `$queryRaw` containing `UPDATE` and `$executeRaw` containing `DELETE` | write mode |
| `TRUNCATE "ChatMessage"` | messaging SQL write |
| unsupported first statement keyword with SQL content | `unknown-sql-composition`; never treated as tableless |
| `SELECT 1`, `pg_advisory_*`, and `set_config` | tableless; no record |

Also export a dependency-injected `runCli({ argv, scan, readBaseline, stdout, stderr })` and unit-test exits `0`, `1`, and `2` without modifying live source/baselines. Spawn the real wrapper once with an unknown argument to prove wrapper wiring and assert stderr contains no repository absolute path or stack trace.

- [ ] **Step 2: Run the focused test and verify failure**

```powershell
node --test -r ts-node/register test/architecture-ownership.test.ts
```

Expected: FAIL because registry/scanner exports do not exist.

- [ ] **Step 3: Create the exact R0 ownership registry**

Create `backend/architecture/ownership-registry.json` with this complete content. The source-derived R0 count is 52, but the permanent test remains schema-driven:

```json
{
  "schemaVersion": 1,
  "sourceRevision": "feafe3db0053d6c66d5f46b56ff9a512861dfbad",
  "owners": {
    "platform": ["IdempotencyKey", "OutboxEvent"],
    "identity": ["User", "RefreshToken", "OtpCode", "LoginThrottle", "OtpDispatchQuota", "AdminLoginChallenge", "AdminPasswordResetChallenge", "AccountDeletionReceipt"],
    "planning": ["WeddingPlan"],
    "finance": ["BudgetCategory", "WeddingCost", "CostPayment", "PaymentSchedule"],
    "collaboration": ["SharedMember", "PlanInvite", "ContributorHistoryScope", "ContributorTenure", "ContributionEvent"],
    "tasks": ["WeddingTask", "WeddingTaskChecklistItem"],
    "guests": ["Guest", "GuestGroup"],
    "marketplace": ["Provider", "ProviderService", "ProviderServiceImage", "ProviderPackage", "FavoriteProvider", "ProviderReview", "QuoteRequest", "QuoteOffer", "PlanProviderLink"],
    "messaging": ["Conversation", "ConversationParticipant", "ConversationEvent", "ChatMessage", "ChatAttachment", "ConversationReport"],
    "notifications": ["Notification", "NotificationPreference", "PushInstallation"],
    "catalog": ["City", "Governorate", "District", "AdministrativeLocality", "ReferenceCatalog", "ReferenceCatalogItem", "ReferenceCatalogItemRevision", "ProviderCategory"],
    "media": ["MediaUploadTicket"],
    "insights": [],
    "backoffice": ["AdminAuditLog"]
  },
  "currentRoots": {
    "platform": ["common", "prisma", "outbox", "health"],
    "identity": ["auth", "users", "me", "contexts"],
    "planning": ["wedding-plans", "onboarding"],
    "finance": ["money", "budget-categories", "wedding-costs"],
    "collaboration": ["sharing", "contribution-history"],
    "tasks": ["tasks"],
    "guests": ["guests"],
    "marketplace": ["marketplace", "provider-dashboard"],
    "messaging": ["conversations"],
    "notifications": ["notifications", "push"],
    "catalog": ["catalogs"],
    "media": ["media"],
    "insights": ["dashboard", "timeline"],
    "backoffice": ["admin"]
  }
}
```

- [ ] **Step 4: Implement schema metadata and canonical path resolution**

Parse every Prisma `model` block and field line. A field whose base type equals a model name is a relation; record target model, list/optional flags, and relation name. Build reverse `model -> owner` and `lowerCamelDelegate -> model` maps. Fail registry validation for a missing/duplicate model, context-key mismatch, duplicate current root, or unknown context.

Use these path contracts:

```javascript
function toRepositoryPath(file, repoRoot, pathApi = path) {
  const relative = pathApi.relative(repoRoot, file);
  if (!relative || pathApi.isAbsolute(relative) || relative === '..' || relative.startsWith(`..${pathApi.sep}`)) {
    throw new Error('architecture path is outside the repository');
  }
  return relative.split(pathApi.sep).join('/');
}

function contextForRepositoryPath(repositoryPath, registry) {
  const prefix = 'backend/src/';
  if (!repositoryPath.startsWith(prefix)) return 'unclassified';
  const segments = repositoryPath.slice(prefix.length).split('/');
  if (segments[0] === 'modules') {
    return Object.hasOwn(registry.owners, segments[1]) ? segments[1] : 'unclassified';
  }
  if (segments[0] === 'platform') return 'platform';
  const matches = Object.entries(registry.currentRoots)
    .filter(([, roots]) => roots.includes(segments[0]))
    .map(([context]) => context);
  return matches.length === 1 ? matches[0] : 'unclassified';
}
```

- [ ] **Step 5: Implement root-delegate detection with TypeScript symbol resolution**

Load `backend/tsconfig.json` through `ts.readConfigFile`/`ts.parseJsonConfigFileContent`, then create one `ts.Program` and `TypeChecker`. Visit non-declaration files below `backend/src`. A call is a Prisma delegate call only when the checker resolves the method declaration under generated Prisma client declarations, the preceding property maps to one registered model, and the receiver type is a generated delegate. Variable spelling (`prisma`, `tx`, `transaction`, or a typed alias) is irrelevant.

Use fixed read/write sets. A resolved generated delegate method outside the sets emits `unknown-operation`; it is never silently ignored. Classify the root model first, then pass its argument to Step 6.

- [ ] **Step 6: Implement relation traversal and nested-write classification**

Implement `resolveStaticObject(node, checker, visitedSymbols)` for object/array literals, `const` identifiers, parentheses, `as`/`satisfies`, property assignments, shorthand properties, and statically resolvable spreads. Follow symbol declarations across project source files. A call result, mutable binding, computed property, unresolved import, or recursive symbol marks only that subtree `unknown-relation-shape`; continue walking resolvable sibling properties so an unresolved `where` does not hide an inline `include`.

Walk Prisma argument keys with the schema relation map:

- relation fields under `include`, `select`, `where`, `having`, `orderBy`, `cursor`, or relation filters (`is`, `isNot`, `some`, `none`, `every`) are reads;
- `_count` is a Prisma pseudo-field, not a model switch: preserve the current model through `_count.select`, then classify every selected relation field as a read of its target model;
- relation fields below `data` using `create`, `createMany`, `connect`, `connectOrCreate`, `set`, `disconnect`, `update`, `updateMany`, `upsert`, `delete`, or `deleteMany` are writes;
- recursively switch the current model to each relation target so `services.select.category` reaches `ProviderCategory`;
- emit one relation access per relation occurrence, then apply the same owner/context decision as a root delegate;
- an unresolved argument emits one `unknown-relation-shape` record for that call and file, even when the root model is owner-local.

- [ ] **Step 7: Implement complete Prisma SQL extraction and tokenization**

Resolve Prisma symbols and handle both AST forms:

1. `TaggedTemplateExpression`: direct tagged `$queryRaw`/`$executeRaw`; the fixture uses `SELECT * FROM "WeddingPlan" WHERE "id" = ${planId}`.
2. `CallExpression`: a `Prisma.sql` tagged template or unsafe string passed as the first argument to `$queryRaw`, `$executeRaw`, `$queryRawUnsafe`, or `$executeRawUnsafe`.

Flatten nested `Prisma.sql` templates recursively. For every interpolation, ask the checker whether its type includes `Prisma.Sql`: if so, resolve its initializer recursively through `const` identifiers, parentheses, `as`/`satisfies`, and conditional expressions, scan every statically possible branch, and splice the resolved SQL fragments into the outer token stream. A mutable binding, call result, unresolved import, or any `Prisma.Sql`-typed branch that cannot be resolved emits `unknown-sql-composition`; it must never be replaced with an ordinary value placeholder. Replace only checker-proven ordinary value interpolations with `?`; treat an interpolation as a dynamic identifier when it occupies a table/identifier position. Resolve `Prisma.join` by checker type and initializer: a scalar-only iterable becomes value placeholders; an array/readonly tuple of statically resolvable `Prisma.sql` fragments is recursively flattened with its static separator; a mutable array, call result, conditional collection, or value whose type includes `Prisma.Sql` but whose fragments cannot all be resolved emits `unknown-sql-composition`. Continue scanning resolvable sibling fragments. Tokenize comments, quoted identifiers, string literals, punctuation, keywords, and parentheses; do not apply one regex to the whole statement.

Recognize PostgreSQL table-bearing forms: `SELECT` with `FROM`/`JOIN`, `INSERT INTO`, `UPDATE`, `DELETE FROM/USING`, `LOCK TABLE`, `TRUNCATE [TABLE]`, `ALTER TABLE`, `DROP TABLE`, `CREATE TABLE`, `MERGE INTO`, and `COPY`. Parse concrete CTE names such as `WITH recent AS (SELECT * FROM "ChatMessage")` first and ignore later references to `recent`, while still scanning physical tables inside the CTE body and terminal statement. Emit one access per physical table occurrence. Read clauses are read mode; mutation/DDL targets are write mode regardless of `$queryRaw` versus `$executeRaw`. Allow only explicitly tested tableless forms (`SELECT 1`, `pg_advisory_*`, `set_config`); an unrecognized first statement/fragment shape emits `unknown-sql-composition`. Unknown extracted tables and dynamic table identifiers emit `unknown-model`.

- [ ] **Step 8: Implement violation aggregation, baseline validation, and CLI contracts**

Emit no violation for a classified owner-local access. For all others, choose one reason in this order: `unknown-model`, `unknown-operation`, `unknown-relation-shape`, `unknown-sql-composition`, `unclassified-context`, `foreign-model`. Aggregate identical keys and compare counted subsets:

```javascript
function compareWithBaseline(currentRecords, baselineRecords) {
  const allowed = new Map(baselineRecords.map((record) => [record.key, record.count]));
  const additions = currentRecords.filter(
    (record) => !allowed.has(record.key) || record.count > allowed.get(record.key),
  );
  return { ok: additions.length === 0, additions };
}
```

Validate baseline `schemaVersion === 1`, `sourceRevision === 'feafe3db0053d6c66d5f46b56ff9a512861dfbad'`, sorted unique keys, positive integer counts, canonical repository paths, and absence of absolute paths/secrets. The CLI accepts exactly one of `--check`/`--write-baseline`: configuration/input error exits 2, violation exits 1, success exits 0. Sanitize output to repository-relative diagnostics and never print an absolute path or stack trace.

- [ ] **Step 9: Run focused tests until green**

```powershell
node --test -r ts-node/register test/architecture-ownership.test.ts
```

Expected: PASS, including registry roots, Windows/Linux paths, relations, every SQL form, baseline metadata, and subprocess exits.

- [ ] **Step 10: Generate and inspect the live baseline**

`--write-baseline` writes violations sorted by full key:

```json
{
  "schemaVersion": 1,
  "sourceRevision": "feafe3db0053d6c66d5f46b56ff9a512861dfbad",
  "violations": []
}
```

Replace the example array with the live scan:

```powershell
node scripts/architecture/ownership-scan.cjs --write-baseline
node scripts/architecture/ownership-scan.cjs --check
```

Expected: first command writes sorted canonical records; second PASS. Review every `unknown-*` entry rather than treating it as permission, and reject any absolute path or secret.

- [ ] **Step 11: Prove the final physical ownership rule has no exception**

Confirm the baseline records finance's current root or relation access to `WeddingPlan` as planning-owned debt. The registry must list `WeddingPlan` only under planning and contain no `exceptions` property.

- [ ] **Step 12: Commit checkpoint only when Git authorization is present**

```powershell
git add backend/architecture/ownership-registry.json backend/architecture/ownership-baseline.json backend/scripts/architecture/ownership-scan.cjs backend/test/architecture-ownership.test.ts
git commit -m "test: freeze backend model ownership baseline"
```

---

### Task 4: Add Ports, Global, and Nest Graph Enforcement

**Files:**
- Create: `backend/scripts/architecture/ports-scan.cjs`
- Create: `backend/test/architecture-ports.test.ts`

**Interfaces:**
- Consumes: `backend/src/**/*.ts` and the target laws in `ARCHITECTURE.md`.
- Produces: `scanPorts(options)`, `runCli(dependencies)`, and CLI command `node scripts/architecture/ports-scan.cjs --check`.

- [ ] **Step 1: Write failing focused tests**

Test all of these cases:

- `forwardRef is forbidden`: direct `forwardRef`, `forwardRef as nestForwardRef`, and `Nest.forwardRef` fixtures each return one `forward-ref` diagnostic resolved to `@nestjs/common`.
- `the R0 global set is exact`: the two repository-relative allowlisted paths pass; adding `backend/src/auth/rogue-global.module.ts` returns `unapproved-global`, while omitting either allowlisted decorator returns `missing-r0-global`. Repeat with direct, aliased, and `Nest.Global()` spellings.
- `future modules import another context through public only`: `backend/src/modules/tasks/application/use-case.ts` importing `backend/src/modules/guests/internal/guest.service.ts` returns one `non-public-cross-module-import` diagnostic, while importing `backend/src/modules/guests/public/guest.port.ts` passes.
- `mixed legacy/future boundaries are closed`: future tasks importing legacy guests fails; legacy tasks importing future guests internal fails; legacy tasks importing future guests public passes; legacy/future platform importing a future business module fails; future platform importing legacy business fails. Legacy-platform-to-legacy-business debt remains in dependency-cruiser's R0 baseline.
- `future domain code cannot import Nest runtime or PrismaService`: two separate domain fixtures importing `@nestjs/common` and `backend/src/prisma/prisma.service.ts` each return one `domain-runtime-import` diagnostic.
- `the live Nest module import graph is acyclic`: the current repository graph passes; a three-module fixture `A -> B -> C -> A` reports the normalized cycle `A -> B -> C -> A`.
- `external dynamic modules are leaves`: package imports such as `ScheduleModule.forRoot()` and `JwtModule.registerAsync()` add no internal edge.
- `internal dynamic modules remain edges`: a locally declared `BModule.register()` referenced by `AModule` creates `A -> B`; a reciprocal `B -> A` reports a cycle.
- a spread, identifier, conditional, or helper call in a Nest `imports` array that cannot be resolved to internal/external module symbols returns `unresolved-module-import`.
- an exported dependency-injected `runCli` is unit-tested for exits `0/1/2`; one real-process unknown-argument test rejects absolute-path or stack-trace output.

Use temporary fixture directories created with `mkdtempSync`; do not write fixtures into `backend/src`.

- [ ] **Step 2: Run the focused test and verify failure**

```powershell
node --test -r ts-node/register test/architecture-ports.test.ts
```

Expected: FAIL because `ports-scan.cjs` is absent.

- [ ] **Step 3: Implement the exact R0 allowlist**

```javascript
const R0_GLOBAL_MODULES = new Set([
  'backend/src/prisma/prisma.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
]);
```

Create a TypeScript `Program`/`TypeChecker`. For every call/decorator, follow alias symbols with `checker.getAliasedSymbol` and require the resolved declaration to come from `@nestjs/common`; never match the local spelling. Any resolved `forwardRef` call fails. Collect canonical repository-relative paths for resolved `Global` decorators and require set equality with `R0_GLOBAL_MODULES`: additions and removals both fail during R0. R8 may change the architecture contract, allowlist, and tests together when it removes these globals.

- [ ] **Step 4: Implement future import-law checks**

Classify canonical repository-relative imports with the same context union used by dependency-cruiser: each context owns its current roots plus `backend/src/modules/<context>`. For a cross-context edge where either endpoint is under `backend/src/modules/`, require the target to be `backend/src/modules/<target-context>/public/**`. Therefore future-to-legacy and legacy-to-future-internal edges fail, while legacy-to-future-public and future-to-future-public edges pass. Do not re-report legacy-to-legacy debt here; dependency-cruiser's counted R0 graph baseline owns that case.

Classify both `backend/src/{common,prisma,outbox,health}/**` and `backend/src/platform/**` as platform. Any platform-to-business edge involving a future module fails immediately; current legacy-only platform debt remains owned by the dependency baseline.

Also enforce:

- `backend/src/modules/*/domain/**` cannot import `@nestjs/*`, `PrismaService`, or another module.
- `backend/src/modules/*/public/**` cannot import another module's full/internal path.
- no external module may import `backend/src/modules/*/internal/**`.
- imports from `shared-kernel` and `platform` are legal subject to their direction rules.

- [ ] **Step 5: Implement the Nest module graph check**

Resolve each `@Module` decorator symbol to `@nestjs/common`, then evaluate its `imports` array. Resolve identifiers, arrays, and statically resolvable spreads/const aliases. For a direct class identifier, create an edge when its declaration is a repository class decorated with `@Module`.

For `Receiver.method()` dynamic-module expressions, resolve `Receiver`: if its declaration is under `node_modules`, treat it as an external leaf; if it resolves to a repository `@Module` class, create an edge to that class regardless of method name. A conditional, call result, mutable binding, helper-computed array, or unresolved expression emits `unresolved-module-import`; it is never silently dropped. Run deterministic depth-first cycle detection over class-level internal edges and normalize a cycle by rotating it to the lexicographically smallest class name.

- [ ] **Step 6: Implement deterministic CLI output**

The CLI accepts only `--check`. A missing/unknown/additional argument or TypeScript configuration/program failure prints sanitized usage/error text and exits 2; an architecture or unresolved-module violation exits 1; success exits 0. All diagnostics use canonical repository-relative paths.

On PASS, print:

```text
PASS - architecture ports: forwardRef=0, globals=2, illegal future imports=0, Nest module cycles=0
```

On failure, sort diagnostics by path and line and exit 1.

- [ ] **Step 7: Run focused and live gates**

```powershell
node --test -r ts-node/register test/architecture-ports.test.ts
node scripts/architecture/ports-scan.cjs --check
npm run architecture:ports
```

Expected: all PASS.

- [ ] **Step 8: Run all Backend unit tests**

```powershell
npm test
```

Expected: every existing test plus all three additive Backend architecture tests PASS; the protected-artifact cleanliness gate PASS.

- [ ] **Step 9: Commit checkpoint only when Git authorization is present**

```powershell
git add backend/scripts/architecture/ports-scan.cjs backend/test/architecture-ports.test.ts
git commit -m "test: enforce modular port and Nest graph laws"
```

---

### Task 5: Add the Incremental Mobile Boundary Gate

**Files:**
- Owner-approved precondition repair, committed separately:
  - Modify: `mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`
  - Modify: this Task 5 section in
    `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md`
- Task 5 scanner checkpoint:
- Create: `scripts/check-mobile-boundaries.mjs`
- Create: `scripts/check-mobile-boundaries.test.mjs`
- Create: `scripts/architecture/mobile-boundaries-baseline.json`

**Owner-approved precondition repair:**

The first live scanner run correctly exposed one pre-existing unresolved local
import at the fixed R0 base:
`mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart` used
`../../../../core/experience_v3/aarast_v3_foundations.dart`, which resolves to
the nonexistent `mobile/core/**` path. The owner approved correcting only that
URI to `../../../core/experience_v3/aarast_v3_foundations.dart`, which resolves
to the existing file under `mobile/lib/core/**`. This repair and this Task 5
plan amendment form one separate precondition commit. They do not weaken the
unresolved-target or `part` contracts, do not authorize any other Mobile edit,
and do not change the fixed baseline `sourceRevision`. The Task 5 scanner
checkpoint remains exactly the three script artifacts listed above.

**Interfaces:**
- Consumes: `mobile/lib/**/*.dart`.
- Produces: `parseDartDirectives(sourceText)`, `scanMobileBoundaries({ mobileLib })`, `compareMobileBaseline(current, baseline)`, `runCli(dependencies)`, and CLI modes `--write-baseline`, `--check-baseline`, and `--strict`.

The record shape is exact:

```typescript
type MobileBoundaryRecord = {
  source: string;
  target: string;
  sourceArea: string;
  targetArea: string;
  kind: 'core-to-feature' | 'direct-cross-feature';
  count: number;
};
type MobileBoundaryError = {
  source: string;
  target: string;
  kind: 'unresolved-local-target' | 'cross-area-part' | 'invalid-part-contract';
};
type MobileBoundaryScan = {
  records: MobileBoundaryRecord[];
  errors: MobileBoundaryError[];
};
```

- [ ] **Step 1: Write failing Node tests**

Tests must prove:

- bare (`child.dart`), dot-relative (`./child.dart`, `../child.dart`), and `package:aarast_mobile/...` URIs resolve to the same normalized local-target rules for import/export/part/part-of;
- single/double-quoted, multiline, and conditional import/export directives return every local URI alternative;
- line/block comments and string contents do not create false directives;
- same-feature and feature-to-core imports are not violations;
- `core/** -> features/**` is a baseline violation;
- direct `features/A/** -> features/B/internal.dart` is a baseline violation;
- reciprocal same-feature `part`/URI-style `part of` pairs pass;
- a missing local import/export/part target returns `unresolved-local-target` and fails in all modes;
- a cross-feature or core/feature `part` pair returns `cross-area-part` and fails in all modes;
- a missing reciprocal declaration or name-style `part of some.library` returns `invalid-part-contract` and fails in all modes;
- a removed/decreased record passes baseline comparison;
- a new record or increased count fails;
- strict mode permits only `core/routing/** -> features/<f>/<f>_api.dart` as the core composition exception;
- strict mode requires cross-feature targets to be `<feature>_api.dart`.
- valid/malformed baseline metadata and dependency-injected `runCli` exits `0/1/2` are covered; one real-process invalid-argument test proves diagnostics contain repository-relative paths only.

- [ ] **Step 2: Run tests and verify failure**

```powershell
node --test .\scripts\check-mobile-boundaries.test.mjs
```

Expected: FAIL because the scanner is absent.

- [ ] **Step 3: Implement deterministic Dart directive tokenization and resolution**

Derive paths from the script location, never from `process.cwd()`: `repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')`, `mobileLib = path.join(repoRoot, 'mobile', 'lib')`, and `baselinePath = path.join(repoRoot, 'scripts', 'architecture', 'mobile-boundaries-baseline.json')`. This makes the same CLI work from the repository root and from the CI Mobile job's `mobile/` working directory.

Walk only `.dart` files below `mobile/lib`. Implement a character scanner that preserves quoted strings while skipping `//` and nested `/* ... */` comments, tracks top-level lexical state, and collects complete directives through their terminating semicolon. Parse `import`, `export`, `part`, and `part of`; do not use one line-oriented regular expression. For conditional imports/exports, return the primary URI and every `if (...) '<uri>'` alternative. Accept both quote styles and arbitrary whitespace/newlines.

Normalize separators to `/` and resolve every repository-local URI:

```javascript
function resolveDartTarget(sourceFile, specifier, mobileLib) {
  if (specifier.startsWith('package:aarast_mobile/')) {
    return path.resolve(mobileLib, specifier.slice('package:aarast_mobile/'.length));
  }
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(specifier)) return null;
  return path.resolve(path.dirname(sourceFile), specifier);
}
```

Ignore only URI schemes outside this project, including `dart:` and third-party `package:`. Every URI without a scheme is file-relative even when it does not begin with `.`, so live forms such as `import 'app.dart'`, `part 'child.dart'`, and `part of 'library.dart'` are scanned. A local target that does not resolve to an existing file is an immediate `unresolved-local-target` error, not a baselined record.

For `part` contracts, require URI-style reciprocity: library file `part 'child.dart';` and child file `part of 'library.dart';` must resolve to each other. Reject name-style `part of` because it cannot be resolved to a file boundary. Define area as `core`, `features/<feature>`, or the first other `mobile/lib` segment; both sides of a part contract must have the same area. Part errors fail `--write-baseline`, `--check-baseline`, and `--strict`, so no existing/future cross-area part becomes accepted debt.

- [ ] **Step 4: Implement counted subset comparison**

Use the same key/count rule as Backend ownership: current keys and counts must be less than or equal to the committed baseline. Line numbers are diagnostics only.

- [ ] **Step 5: Implement the three CLI modes**

- `--write-baseline`: write sorted repository-relative records plus `sourceRevision`.
- `--check-baseline`: compare current records and fail only on additions/increased counts.
- `--strict`: ignore the legacy baseline and apply the R9 barrel/composition rules.
- any scan error: print sorted canonical diagnostics and exit 1 before baseline comparison.
- missing/multiple/unknown mode or malformed baseline metadata: sanitized message and exit 2.
- success: exit 0; never print an absolute path or stack trace.

R0 CI invokes only `--check-baseline`; R9 replaces it with `--strict` after the boundary migration.

- [ ] **Step 6: Run the tests until green**

```powershell
node --test .\scripts\check-mobile-boundaries.test.mjs
```

Expected: PASS.

- [ ] **Step 7: Generate and inspect the live Mobile baseline**

Write this top-level shape with `records` sorted by `source|target|sourceArea|targetArea|kind`, replacing the empty example with the live scan:

```json
{
  "schemaVersion": 1,
  "sourceRevision": "feafe3db0053d6c66d5f46b56ff9a512861dfbad",
  "records": []
}
```

```powershell
node .\scripts\check-mobile-boundaries.mjs --write-baseline
node .\scripts\check-mobile-boundaries.mjs --check-baseline
```

Expected: PASS. Inspect that records are repository-relative and correspond to current imports. Do not encode current feature edges as permanent strict permissions.

The tests must validate `schemaVersion === 1`, the exact R0 `sourceRevision`, sorted unique keys, positive integer counts, canonical repository paths, and absence of absolute paths/secrets before this baseline is accepted.

- [ ] **Step 8: Prove strict mode is not accidentally enabled**

```powershell
node .\scripts\check-mobile-boundaries.mjs --strict
```

Expected in R0: non-zero with current direct imports. If strict mode passes, stop because the strict rules are incomplete.

- [ ] **Step 9: Prove the exact owner-approved Mobile precondition allowlist**

```powershell
$r0Base = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad'
$expectedMobile = @(
  'mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart'
)
$changedMobile = @(
  git diff --name-only --no-renames --diff-filter=ACMRDTUXB $r0Base -- mobile/lib mobile/test mobile/integration_test |
    ForEach-Object { $_ -replace '\\', '/' } |
    Sort-Object -Unique
)
$mobileDelta = @(Compare-Object $expectedMobile $changedMobile)
if ($mobileDelta.Count -ne 0) {
  throw "Unexpected Mobile diff from fixed R0 base: $($mobileDelta -join '; ')"
}
$mobileProtected = @(git status --porcelain=v1 --untracked-files=all -- mobile/lib mobile/test mobile/integration_test)
if ($mobileProtected.Count -ne 0) { throw "Protected Mobile worktree is dirty: $($mobileProtected -join '; ')" }
```

Expected: the fixed-base Mobile diff contains exactly the one owner-approved
welcome-gateway import repair, and the protected Mobile worktree is clean. Any
other Mobile path remains a stop signal.

- [ ] **Step 10: Commit checkpoint only when Git authorization is present**

```powershell
git add scripts/check-mobile-boundaries.mjs scripts/check-mobile-boundaries.test.mjs scripts/architecture/mobile-boundaries-baseline.json
git commit -m "test: freeze mobile architecture boundary baseline"
```

This checkpoint contains exactly the three scanner artifacts. The Mobile
precondition repair and this Task 5 plan amendment must already exist in the
separate `fix(mobile): correct welcome gateway core import` commit.

---

### Task 6: Wire R0 Gates into CI and Generated Documentation

**Files:**
- Create: `scripts/check-r0-scope.mjs`
- Create: `scripts/check-r0-scope.test.mjs`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/SCRIPTS.md` through `scripts/docs-sync.mjs`

**Interfaces:**
- Consumes: package scripts from Task 2, Backend scanners from Tasks 3-4, and Mobile scanner from Task 5.
- Produces: mandatory architecture gates on every pull request and an automated fixed-base scope job for pull requests whose head branch is `modular-monolith`.

- [ ] **Step 1: Write failing tests for the exact R0 scope allowlist**

Create `scripts/check-r0-scope.test.mjs`. Import `R0_BASE`, `R0_ALLOWED_PATHS`, `findUnexpectedPaths`, and `collectChangedPaths` from the scanner and test:

```javascript
test('the R0 base is immutable', () => {
  assert.equal(R0_BASE, 'feafe3db0053d6c66d5f46b56ff9a512861dfbad');
});

test('allowed paths pass regardless of input order or duplicates', () => {
  assert.deepEqual(findUnexpectedPaths([
    'ARCHITECTURE.md',
    'backend/package.json',
    'ARCHITECTURE.md',
  ]), []);
});

test('application, schema, migration, deployment, and unknown paths fail', () => {
  assert.deepEqual(findUnexpectedPaths([
    'backend/src/auth/auth.service.ts',
    'backend/prisma/schema.prisma',
    'backend/prisma/migrations/not-a-real-migration/migration.sql',
    'mobile/lib/main.dart',
    'admin-web/src/App.tsx',
    'deploy/compose.yml',
    'unexpected.txt',
  ]), [
    'admin-web/src/App.tsx',
    'backend/prisma/migrations/not-a-real-migration/migration.sql',
    'backend/prisma/schema.prisma',
    'backend/src/auth/auth.service.ts',
    'deploy/compose.yml',
    'mobile/lib/main.dart',
    'unexpected.txt',
  ]);
});
```

Inject a fake `runGit(args)` into `collectChangedPaths` and prove it combines `git diff --name-only --no-renames --diff-filter=ACMRDTUXB feafe3db0053d6c66d5f46b56ff9a512861dfbad --` with `git ls-files --others --exclude-standard`, normalizes `/`, sorts/deduplicates, and propagates a missing-base Git failure as configuration exit 2. The no-range diff form is required because it includes committed, staged, and unstaged tracked changes relative to the base; `--no-renames` is required so a protected source renamed into an allowed destination appears as a deletion plus an addition instead of hiding the source path.

Make `collectChangedPaths({ runGit, base = R0_BASE })` accept the base only as a dependency-injected test seam. In a temporary Git repository, commit `backend/src/protected.ts`, record that commit as `base`, rename the file to the otherwise allowed `ARCHITECTURE.md`, and assert that collection returns both paths and `findUnexpectedPaths` rejects `backend/src/protected.ts`. This is a real Git fixture, not a mocked rename result. Export `runCli({ argv, collect, stdout, stderr })` and unit-test exits `0/1/2`; spawn the real wrapper once with an unknown argument to verify sanitized output without creating an out-of-scope workspace fixture.

- [ ] **Step 2: Run the scope tests and verify failure**

```powershell
node --test .\scripts\check-r0-scope.test.mjs
```

Expected: FAIL because `check-r0-scope.mjs` does not exist.

- [ ] **Step 3: Implement the fixed-base scope scanner**

Create `scripts/check-r0-scope.mjs` with these exported constants and no additional allowed path:

```javascript
export const R0_BASE = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
export const R0_ALLOWED_PATHS = new Set([
  '.github/workflows/ci.yml',
  'AGENTS.md',
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/.dependency-cruiser-known-violations.json',
  'backend/.dependency-cruiser.cjs',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/ownership-registry.json',
  'backend/package-lock.json',
  'backend/package.json',
  'backend/scripts/architecture/ownership-scan.cjs',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/test/architecture-dependencies.test.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-ports.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/frontend/MOBILE_ARCHITECTURE.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md',
  'scripts/architecture/mobile-boundaries-baseline.json',
  'scripts/check-mobile-boundaries.mjs',
  'scripts/check-mobile-boundaries.test.mjs',
  'scripts/check-r0-scope.mjs',
  'scripts/check-r0-scope.test.mjs',
]);
```

`collectChangedPaths` first verifies `R0_BASE^{commit}` with `git cat-file -e`, then collects every tracked working-tree/index/committed change through `git diff --name-only --no-renames --diff-filter=ACMRDTUXB R0_BASE --` and untracked files through `git ls-files --others --exclude-standard`. Production CLI wiring never overrides `base`; only the injected temporary-repository test does. Normalize separators, reject absolute/parent-traversal output, sort, and deduplicate. `findUnexpectedPaths` returns sorted paths absent from the exact set. CLI accepts only `--check`: Git/config error exits 2, unexpected path exits 1 and prints each path, clean scope exits 0. Never print an absolute local path or stack trace.

- [ ] **Step 4: Run scope tests and the live local gate**

```powershell
node --test .\scripts\check-r0-scope.test.mjs
node .\scripts\check-r0-scope.mjs --check
```

Expected: tests PASS and live gate PASS with only the current R0 plan/deliverables in the changed set.

- [ ] **Step 5: Add the required R0 scope job to CI**

Add this independent job. Checking out the PR head SHA avoids validating GitHub's synthetic merge commit; `fetch-depth: 0` guarantees the fixed base is present:

```yaml
  r0-scope:
    if: github.event_name == 'pull_request' && github.head_ref == 'modular-monolith'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4
        with:
          node-version: 22
      - run: node --test scripts/check-r0-scope.test.mjs
      - run: node scripts/check-r0-scope.mjs --check
```

The PR cannot close R0 unless `r0-scope` is present and green on the exact candidate revision. R1's plan must remove or retarget this phase-specific fixed-base job after R0 is externally closed; do not leave it active for another head branch.

- [ ] **Step 6: Add the Backend architecture command to CI**

In the existing `backend` job, preserve all current steps and insert this after `npm run check` and before `npm test`:

```yaml
      - run: npm run architecture
```

Do not add an `npm install` or network-time `npx` command; `npm ci` installs the lockfile-pinned tool.

- [ ] **Step 7: Add Node 22 to the Mobile job**

After checkout and before the Flutter action, add the same pinned `actions/setup-node` action used by other jobs:

```yaml
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4
        with:
          node-version: 22
```

- [ ] **Step 8: Add Mobile checker tests and baseline gate**

Before `flutter pub get`, add:

```yaml
      - run: node --test ../scripts/check-mobile-boundaries.test.mjs
      - run: node ../scripts/check-mobile-boundaries.mjs --check-baseline
```

The Mobile job's working directory is `mobile`, so the `../scripts` paths are required.

- [ ] **Step 9: Keep Admin and all existing CI jobs unchanged**

Verify no step was removed or weakened from:

- `backend-image`
- `backend-e2e`
- `admin-web`
- `docs`
- `secrets-scan`
- `dependency-audit`

R0 adds no Admin boundary gate and does not change Admin source.

- [ ] **Step 10: Regenerate the script catalog once**

Run from the repository root:

```powershell
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
```

Expected: `docs/SCRIPTS.md` changes only for the new Backend architecture scripts; the second command reports drift=0.

- [ ] **Step 11: Run local CI-equivalent architecture gates**

```powershell
Push-Location .\backend
npm run architecture
npm run check
npm test
Pop-Location
node --test .\scripts\check-mobile-boundaries.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node --test .\scripts\check-r0-scope.test.mjs
node .\scripts\check-r0-scope.mjs --check
```

Expected: all PASS.

- [ ] **Step 12: Review CI and generated-doc diffs**

```powershell
git diff -- .github/workflows/ci.yml docs/SCRIPTS.md backend/package.json backend/package-lock.json scripts/check-r0-scope.mjs scripts/check-r0-scope.test.mjs
```

Expected: additive Backend/Mobile steps, one isolated `r0-scope` job with full history and PR-head checkout, exact dependency lock, and generated script rows only.

- [ ] **Step 13: Commit checkpoint only when Git authorization is present**

```powershell
git add .github/workflows/ci.yml docs/SCRIPTS.md scripts/check-r0-scope.mjs scripts/check-r0-scope.test.mjs
git commit -m "ci: enforce modular monolith R0 gates"
```

---

### Task 7: Execute the Complete R0 Verification and Record the Receipt

**Files:**
- Modify after all checks pass: `docs/project/STATUS.md`
- Modify after all checks pass: `CHANGELOG.md`

**Interfaces:**
- Consumes: every deliverable from Tasks 1-6.
- Produces: a tracked local-verification receipt that deliberately avoids claiming its own mutable HEAD, plus an external PR/CI closure gate for the immutable candidate revision.

- [ ] **Step 1: Verify the protected change surface before tests**

```powershell
$r0Base = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad'
git diff --exit-code $r0Base -- backend/src backend/prisma/schema.prisma backend/prisma/migrations mobile/lib mobile/test mobile/integration_test admin-web/src deploy docker-compose.yml
$protectedStatus = @(git status --porcelain=v1 --untracked-files=all -- backend/src backend/prisma/schema.prisma backend/prisma/migrations mobile/lib mobile/test mobile/integration_test admin-web/src deploy docker-compose.yml)
if ($protectedStatus.Count -ne 0) { throw "Protected R0 paths changed: $($protectedStatus -join '; ')" }
node .\scripts\check-r0-scope.mjs --check
```

Expected: empty diff. Any output is a stop signal; do not explain it away as mechanical R0 work.

- [ ] **Step 2: Run Backend architecture and quality gates**

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

Expected: all PASS; full audit has no high/critical findings (including the new dev tool), and production audit has zero findings. Record actual test counts from output without making them a future hard-coded invariant.

- [ ] **Step 3: Run Admin unchanged-surface gates**

```powershell
Push-Location .\admin-web
npm run typecheck
npm test -- --run
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
Pop-Location
```

Expected: all PASS.

- [ ] **Step 4: Run Mobile architecture and existing quality gates**

```powershell
node --test .\scripts\check-mobile-boundaries.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
Push-Location .\mobile
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
```

Expected: all PASS, including existing Golden behavior under the repository's current local test command.

- [ ] **Step 5: Run documentation and whitespace gates**

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: drift=0, errors=0, warnings=0, and no whitespace errors.

- [ ] **Step 6: Confirm schema and migration counts from source**

```powershell
$models = (Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+').Count
$migrations = (Get-ChildItem .\backend\prisma\migrations -Directory).Count
if ($models -ne 52) { throw "Expected 52 models, found $models" }
if ($migrations -ne 76) { throw "Expected 76 migrations, found $migrations" }
```

Expected: no exception.

- [ ] **Step 7: Re-run the protected change-surface gate after all tests**

```powershell
$r0Base = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad'
git diff --exit-code $r0Base -- backend/src backend/prisma/schema.prisma backend/prisma/migrations mobile/lib mobile/test mobile/integration_test admin-web/src deploy docker-compose.yml
$protectedStatus = @(git status --porcelain=v1 --untracked-files=all -- backend/src backend/prisma/schema.prisma backend/prisma/migrations mobile/lib mobile/test mobile/integration_test admin-web/src deploy docker-compose.yml)
if ($protectedStatus.Count -ne 0) { throw "Protected R0 paths changed: $($protectedStatus -join '; ')" }
node .\scripts\check-r0-scope.mjs --check
git status --short --untracked-files=all
```

Expected: only the R0 files listed in Target File Map are changed/untracked.

- [ ] **Step 8: Record the completion receipt only after every local gate passes**

Update `docs/project/STATUS.md` and `CHANGELOG.md` with:

- base revision and branch;
- exact files changed;
- dependency-cruiser version;
- observed baseline totals by category;
- exact commands and PASS results;
- explicit statement that application source, schema, migrations, routes, and deployment files were untouched;
- local smoke status: not required because R0 changed no runtime source/schema;
- statement that the authoritative candidate revision and remote CI result come from immutable PR/workflow metadata;
- statement that the tracked receipt intentionally makes no claim about its own mutable branch tip or current remote CI state.

The receipt records local evidence only. Do not write `CI pending`, `CI passed`, a mutable branch-tip SHA, or any text that must be edited after CI.

- [ ] **Step 9: Run docs checks again after writing the receipt**

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: all PASS.

- [ ] **Step 10: Commit the receipt only when Git authorization is present**

```powershell
git add docs/project/STATUS.md CHANGELOG.md
git commit -m "docs: record modular monolith R0 verification"
```

- [ ] **Step 11: Require remote CI before closing R0**

After an explicitly authorized push/PR, require the automated `r0-scope` job to validate the exact PR-head candidate against fixed base `feafe3db0053d6c66d5f46b56ff9a512861dfbad`, and require all existing and new jobs to pass on that same candidate revision:

- Backend
- Backend image
- Backend E2E with all managed smoke packages
- Admin Web
- Mobile
- Docs
- Secret scan
- Dependency audit
- R0 scope

When those external checks are green, close R0 in the PR/review workflow without another documentation edit. This avoids creating a new unverified revision. R1 planning may begin from the externally verified candidate/merge revision; R1 implementation remains a separate plan.

---

## Plan Self-Review Checklist

- [ ] Spec coverage: R0 governance, ownership registry, dependency baseline, architecture tests, Mobile baseline, CI, docs, and zero source moves each map to a task.
- [ ] Placeholder scan: no unfinished marker, deferred-implementation phrase, unspecified error handling, or unnamed test remains.
- [ ] Type consistency: ownership and Mobile baseline keys use repository-relative paths and counted records; removal is allowed and addition/increase fails.
- [ ] Dependency-baseline semantics: dependency-cruiser freezes unique `rule|from|to` edges, and temporary fixtures prove a known edge is ignored while a new edge/cycle fails.
- [ ] Mixed-layout dependency coverage: legacy/future edges in both directions and platform-to-future edges are tested; only another context's future `public/` target is allowed, and shared-kernel cannot import any legacy or future business context.
- [ ] Ownership completeness: live registry roots are unique/complete; root delegates, relation reads/writes including `_count`, direct/nested/joined SQL, CTEs, value interpolation, dynamic identifiers, and unknown SQL statements each have named tests.
- [ ] Symbol integrity: Nest decorators/functions and dynamic-module receivers are resolved to declarations; alias/namespace spelling cannot bypass the gate.
- [ ] Mobile grammar: bare/dot/package URIs, import/export/conditional/part directives, unresolved local targets, reciprocity, and cross-area parts each have named tests.
- [ ] Baseline integrity: ownership/Mobile metadata, sorting, unique keys, positive counts, source revision, canonical paths, and secret/absolute-path rejection are tested.
- [ ] Closure consistency: the tracked receipt contains local evidence only; immutable SHA and CI state remain in external PR/workflow metadata, so no self-invalidating follow-up edit exists.
- [ ] Phase consistency: R0 creates no module, port, repository, barrel, migration, route, endpoint, or product behavior.
- [ ] Test discovery: Backend architecture tests are top-level under `backend/test/` and are therefore discovered by the current runner.
- [ ] Source protection: pre/post local gates and the required PR-head `r0-scope` CI job compare the fixed base against the exact allowlist, covering tracked, staged, unstaged, and untracked changes.
- [ ] Documentation consistency: `ARCHITECTURE.md` is canonical; this plan is a working execution artifact; archived superpowers files remain historical.

## Execution Handoff

Plan execution must use one of these modes after owner approval:

1. **Subagent-Driven (recommended):** use `superpowers:subagent-driven-development`; dispatch a fresh implementation agent per task and perform specification and quality review after each task.
2. **Inline Execution:** use `superpowers:executing-plans`; execute tasks in ordered batches with review checkpoints.

Do not execute R0 merely because this plan exists. The execution session must reconfirm the branch, clean change surface, Git permissions, and selected execution mode.
