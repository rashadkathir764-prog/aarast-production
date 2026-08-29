# Modular Monolith R9 Mobile Strict Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce zero Mobile strict-boundary violations through 19 minimal
owner public APIs, neutral Core session ownership, and immutable Push identity
projection without changing product behavior.

**Architecture:** Freeze the R9 debt and root-composition inventories first,
then make the scanner understand Dart directive structure and legal public
edges. Move `SafeUser` to Core and pass Push only a nullable user ID, create all
19 owner APIs, and migrate consumer sources in reviewed batches before moving
the three exact composition roots and enabling strict CI.

**Tech Stack:** Windows/PowerShell, Node.js 22 and `node:test`, Dart 3.11.5,
Flutter, GitHub Actions, Android SDK/ADB, the unchanged R8 NestJS runtime.

**Spec:**
`docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-design.md`

**Status:** Owner-approved design; implementation plan awaiting execution-mode
selection

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on the existing
  `modular-monolith` branch.
- Immutable R9 base is `833a4f1d31781b45cd0a68ecee1b969ac85f237f`.
- The approved design checkpoint is
  `2ea231b03f1eb7b56e6e8643e9ce90b4733a262c` and its file SHA-256 is
  `45f732498afda4fd0ba7861eb0aff75c31580cc14d20c810a655f3857174c5f5`.
- Local checkpoint commits are authorized. Do not create or switch branches,
  create worktrees, push, merge, mutate a PR, deploy, run remote CI, publish a
  store artifact, or begin R10.
- R9 is Mobile architecture work only. Do not change Backend, Admin Web, API,
  database, Prisma, migrations, seeds, dependencies, lockfiles, Docker,
  Compose, Dokploy, deployment, product copy, UI, routes, or product behavior.
- Keep `scripts/architecture/mobile-boundaries-baseline.json` byte-identical.
  Its source revision is
  `feafe3db0053d6c66d5f46b56ff9a512861dfbad`, record count is 269, and
  SHA-256 is
  `f9939fa25b7e3e3b7e3563c4dce30aa9a2cb0781cdf2ed8bbf9448477644cf1f`.
- Freeze the omitted root inventory at 34 directives with canonical JSON
  SHA-256
  `1cf2239bdf339b12fa76abfa3dd90ef9bbf2dd39a0778f2af9385f2e4e28848b`.
- Each feature has exactly one root API at
  `mobile/lib/features/<feature>/<feature>_api.dart`. It contains comments and
  same-feature direct exports only; every export has a non-empty `show` list.
- Every cross-area consumer has one import of the exact target owner API with a
  non-empty `show` list. Reject `hide`, mixed internal/API imports, duplicate
  API directives, conditional directives, API-to-API exports, declarations,
  `part`, and `part of`.
- Only `mobile/lib/main.dart`, `mobile/lib/app.dart`, and
  `mobile/lib/core/routing/app_router.dart` may compose features. The routing
  exception is for the exact router file, not its directory.
- Move `SafeUser` unchanged to `mobile/lib/core/session/safe_user.dart`; delete
  the old Auth file in the same checkpoint and leave no alias, duplicate,
  compatibility export, or fallback.
- `AarastPushLifecycleBridge` receives only `String? authenticatedUserId`; it
  must not import or read Auth state.
- Preserve routes, route extras, provider identities, secure storage keys,
  JSON codecs, SQLCipher/offline behavior, Socket.IO, notifications, Arabic
  text, errors, permissions, timeouts, retries, and session transitions.
- Do not delete, skip, weaken, or rewrite an existing behavioral assertion to
  obtain a pass. Stop at the earliest incorrect source boundary.
- Every source-changing task runs scanner tests, transitional debt, exact scope,
  Flutter analysis, focused tests, diff review, and a local reviewed commit.
- Directed phone work uses only the owner-authorized A26 phone labeled `26`.
  S10 is forbidden; device serials, credentials, OTPs, tokens, user data, and
  raw business content are never printed or retained.

## Planned File Responsibilities

| Path or group | Responsibility |
| --- | --- |
| `scripts/architecture/r9-mobile-strict-manifest.json` | Immutable base, hashes, 269/34 inventories, 19 APIs, exact composition roots, debt milestones, and 151-path fence |
| `scripts/check-mobile-boundaries.mjs` | Directive-aware R9 scan, legal-edge inventory, structural errors, transitional debt, and strict CLI |
| `scripts/check-mobile-boundaries.test.mjs` | Positive, adversarial, historical-compatibility, and final-zero scanner proofs |
| `scripts/check-r9-scope.mjs` | Fixed-base changed-path, hash, protected-surface, and per-task debt enforcement |
| `scripts/check-r9-scope.test.mjs` | Manifest/path/hash/task/near-miss/traversal rejection tests |
| `mobile/lib/core/session/safe_user.dart` | One unchanged persisted session-principal implementation |
| `mobile/lib/core/push/push_lifecycle_bridge.dart` | Push lifecycle driven by immutable nullable identity data |
| `mobile/lib/features/*/*_api.dart` | Nineteen minimal owner-controlled public surfaces listed in Appendix A |
| Consumer files in Tasks 4-8 | One source-to-owner directive per target feature with exact `show` symbols |
| `.github/workflows/ci.yml` | Switch Mobile boundary acceptance to `--strict` only after local zero |
| Active R9 documentation | Truthful design, execution, QA, candidate, legal-edge, phone, risk, and stop receipts |

---

### Task 1: Govern The Exact R9 Boundary Contract

**Files:**

- Create: `scripts/architecture/r9-mobile-strict-manifest.json`
- Create: `scripts/check-r9-scope.mjs`
- Create: `scripts/check-r9-scope.test.mjs`
- Modify: `scripts/check-mobile-boundaries.mjs`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: immutable R9 base, historical baseline, root inventory in Appendix
  C, API map in Appendix A, and exact fence in Appendix D.
- Produces:

```js
parseR9DartDirectives(sourceText)
validateR9Manifest(value)
scanR9MobileBoundaries({ mobileLib, manifest })
// => { errors, legacyRecords, rootRecords, legalRecords, strictViolations }
compareR9MobileDebt({ scan, baseline, manifest })
// => { ok, additions, legacyViolationCount, rootViolationCount }
checkR9Scope({ repoRoot, task })
// task is one of task-1 through task-11
```

All returned record arrays are repository-relative, canonical, unique, and
sorted. Error output is sanitized and never contains an absolute path, file
content, environment value, or secret.

- [ ] **Step 1: Write the directive and transitional-debt RED tests**

Add named fixtures that prove all of these exact outcomes:

```js
const requiredR9Cases = [
  'accepts internal import redirected to exact owner API as debt reduction',
  'rejects a new or increased internal cross-feature edge',
  'rejects a non-routing Core import of a feature API',
  'rejects owner export without a non-empty show list',
  'rejects owner API import declaration part part-of conditional hide cross-owner and API-to-API export',
  'rejects cross-area owner import without a non-empty show list',
  'rejects mixed internal and API imports for one target owner',
  'rejects multiple owner API directives for one source-target owner pair',
  'accepts exact main app and app_router owner API imports',
  'rejects any other root or core-routing feature importer',
  'permits legal records when final strict violations are zero',
];
```

Keep the existing 192 scanner proofs unchanged. Add direct parser assertions
for directive kind, URI, `show`, `hide`, conditional flag, line, source area,
and resolved target area.

- [ ] **Step 2: Write the scope and manifest RED tests**

The new scope suite loads the manifest and rejects wrong base/hash/count/order,
duplicate paths, absolute paths, `..`, separator near-misses, case near-misses,
symlink/junction escape, unknown tasks, a changed historical baseline, an
unapproved changed path, and every wrong milestone. Encode the milestone map
exactly:

```js
const expectedDebt = Object.freeze({
  'task-1': { legacy: 269, root: 34 },
  'task-2': { legacy: 265, root: 34 },
  'task-3': { legacy: 265, root: 34 },
  'task-4': { legacy: 255, root: 34 },
  'task-5': { legacy: 198, root: 34 },
  'task-6': { legacy: 119, root: 34 },
  'task-7': { legacy: 59, root: 34 },
  'task-8': { legacy: 0, root: 0 },
  'task-9': { legacy: 0, root: 0 },
  'task-10': { legacy: 0, root: 0 },
  'task-11': { legacy: 0, root: 0 },
});
```

- [ ] **Step 3: Run RED and preserve the failure reason**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
```

Expected: the new tests fail because the R9 parser, manifest, debt comparator,
scope checker, and structural rules do not exist; the pre-existing scanner
tests remain green.

- [ ] **Step 4: Implement the manifest and strict record model**

Create a canonical JSON object with these literal identities:

```json
{
  "schemaVersion": 1,
  "baseRevision": "833a4f1d31781b45cd0a68ecee1b969ac85f237f",
  "historicalBaseline": {
    "path": "scripts/architecture/mobile-boundaries-baseline.json",
    "sourceRevision": "feafe3db0053d6c66d5f46b56ff9a512861dfbad",
    "sha256": "f9939fa25b7e3e3b7e3563c4dce30aa9a2cb0781cdf2ed8bbf9448477644cf1f",
    "recordCount": 269
  },
  "rootInventory": {
    "recordCount": 34,
    "canonicalSha256": "1cf2239bdf339b12fa76abfa3dd90ef9bbf2dd39a0778f2af9385f2e4e28848b"
  },
  "finalLegalRecordCount": 159,
  "compositionSources": [
    "mobile/lib/app.dart",
    "mobile/lib/core/routing/app_router.dart",
    "mobile/lib/main.dart"
  ]
}
```

Add the 19 sorted feature/API pairs from Appendix A, the exact 34 root records
from Appendix C, the exact debt map above, the two document paths and lowercase
SHA-256 values, and the sorted 151 paths from Appendix D. Hash the plan only
after this committed plan is final; never write secrets or absolute paths.

- [ ] **Step 5: Implement directive-aware scanning and debt comparison**

Preserve `parseDartDirectives`, `scanMobileBoundaries`, and
`compareMobileBaseline` as the historical projection. Implement the R9
functions as a stricter projection over the same files. `--write-baseline`
retains historical behavior. `--check-baseline` validates manifest and baseline
hash, excludes legal exact owner imports from debt additions, and still fails
new internal/Core/root/structural violations. `--strict` requires
`strictViolations.length === 0` but does not require
`legalRecords.length === 0`.

Use one stable record shape:

```js
{
  source: 'mobile/lib/features/home/screens/home_screen.dart',
  target: 'mobile/lib/features/auth/auth_api.dart',
  sourceArea: 'features/home',
  targetArea: 'features/auth',
  directiveKind: 'import',
  show: ['AuthController'],
  hide: [],
  conditional: false,
  count: 1,
}
```

- [ ] **Step 6: Implement the fail-closed scope checker**

`check-r9-scope.mjs --check task-N` compares tracked and untracked changes from
the immutable base, checks both document hashes and baseline bytes, rejects
paths outside Appendix D, imports the R9 scan instead of parsing CLI text, and
requires the exact task milestone. It prints only counts, repository-relative
paths, and sanitized error categories.

- [ ] **Step 7: Run the governance checkpoint**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-1
node .\scripts\check-mobile-boundaries.mjs --strict
git diff --check
```

Expected: both test files pass with zero failures; baseline passes at legacy
269/root 34; scope passes Task 1; strict deliberately exits 1 at the verified
269 legacy violations; whitespace passes. Any other result stops Task 1.

- [ ] **Step 8: Review and create the local governance checkpoint**

Review `git diff --name-status`, `git diff --stat`, the manifest hashes, and all
scanner/scope error paths. Stage only the five Task 1 files, run
`git diff --cached --check`, then commit:

```powershell
git commit -m "test: govern R9 mobile strict boundaries"
```

Expected: one reviewed local commit and a clean worktree. Do not push.

---

> **Owner-approved corrective checkpoint (2026-08-29):** The pre-existing
> base blob of `mobile/lib/core/network/api_client.dart` fails the mandatory
> Dart formatter only at line 53. The owner approved this formal correction on
> 2026-08-29, and governance is amended before the source edit. The source
> correction is formatter-only and behavior-neutral. No waiver, narrowed format
> command, compatibility layer, or silent exception is allowed. Final history
> must contain this reviewed governance checkpoint before one clean Task 2
> checkpoint.

### Task 2: Move The Session Principal And Decouple Push

**Files:**

- Create: `mobile/lib/core/session/safe_user.dart`
- Delete: `mobile/lib/features/auth/models/safe_user.dart`
- Create: `mobile/test/core/session/safe_user_persistence_contract_test.dart`
- Create: `mobile/test/core/push/push_lifecycle_bridge_test.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/core/network/api_client.dart`
- Modify: `mobile/lib/core/offline/offline_sync_service.dart`
- Modify: `mobile/lib/core/push/push_lifecycle_bridge.dart`
- Modify: `mobile/lib/core/storage/auth_storage.dart`
- Modify: `mobile/lib/features/auth/data/auth_repository.dart`
- Modify: `mobile/lib/features/auth/models/auth_otp.dart`
- Modify: `mobile/lib/features/auth/models/auth_response.dart`
- Modify: `mobile/lib/features/auth/providers/auth_controller.dart`
- Modify: `mobile/lib/features/wedding_plans/models/onboarding_complete.dart`
- Modify: `mobile/integration_test/account_context_runtime_smoke_test.dart`
- Modify the exact import-only test consumers listed in Appendix E.

**Interfaces:**

- Consumes: R9 governance from Task 1.
- Produces the unchanged `SafeUser` type at its neutral path and this exact Push
  constructor:

```dart
const AarastPushLifecycleBridge({
  required this.router,
  required this.authenticatedUserId,
  required this.child,
  super.key,
});

final GoRouter router;
final String? authenticatedUserId;
final Widget child;
```

- [ ] **Step 1: Write the persisted-principal RED test**

Construct a `SafeUser` with every nullable and non-nullable field populated,
assert the exact JSON keys and values, restore it, and assert equality field by
field. Also restore the minimal pre-R9 map and assert `appRole ==
'WEDDING_USER'`, `locale == 'ar'`, nullable dates remain null, provider/account
role getters preserve their current truth, and `toJson()` uses the existing
date serialization. Import only `core/session/safe_user.dart` so RED is a
missing-library failure.

- [ ] **Step 2: Write Push transition RED tests**

Cover these exact state transitions with fakes for the unchanged Push client
and router:

```text
null -> null: no duplicate bind or navigation
null -> user-A: bind user-A once
user-A -> null: unregister/unbind once
user-A -> user-B: replace binding once
pending tap before auth -> user-A: claim and open inbox once
resume while user-A: existing refresh behavior once
dispose: existing subscription cleanup once
```

The test imports no Auth feature. It fails first because
`authenticatedUserId` is not yet a constructor argument and the bridge still
reads `AuthController`.

- [ ] **Step 3: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
flutter test --no-pub test/core/session/safe_user_persistence_contract_test.dart test/core/push/push_lifecycle_bridge_test.dart
```

Expected: fail for the missing neutral principal and old Push constructor, not
for unrelated product behavior.

- [ ] **Step 4: Move `SafeUser` byte-for-byte and update imports**

Move the existing class body without field, type, default, codec, date, role,
or getter edits. Delete the old file in the same diff. Replace every
`safe_user.dart` import in the production, integration, and Appendix E files
with the canonical Core path. Do not re-export it from `auth_api.dart`.

- [ ] **Step 5: Project nullable identity into Push**

Remove the Auth import/provider read from the bridge. In `app.dart`, compute:

```dart
final authenticatedUserId = auth.status == AuthStatus.authenticated
    ? auth.user?.id
    : null;
```

Pass that value to `AarastPushLifecycleBridge`. Preserve the existing
bind/unbind, permission, pending-open, one-time inbox navigation, foreground,
resume, and disposal code paths.

- [ ] **Step 6: Run focused GREEN and architecture gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub test/core/session test/core/storage test/core/offline test/core/push
flutter test --no-pub test/features/auth test/features/wedding_plans
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-2
git diff --check
```

Expected: all commands pass; debt is exactly legacy 265/root 34; the old
`SafeUser` path is absent; no Core file imports a feature except the approved
router debt. The only diff for `mobile/lib/core/network/api_client.dart` must
be Dart's line wrap of the assignment at former line 53, with no token or logic
change. The full formatter gate above must pass without narrowing its command
or adding an exception.

- [ ] **Step 7: Review and commit**

Review the moved class with `git diff --no-index` against the base blob after
normalizing only its library path, confirm all import changes are mechanical,
stage only Task 2 files, and commit:

```powershell
git commit -m "refactor(mobile): decouple session and push boundaries"
```

Expected: one reviewed local commit and clean worktree. Do not push.

---

### Task 3: Define All Nineteen Owner Public APIs

**Files:**

- Create the exact 19 files in Appendix A.
- Test: `scripts/check-mobile-boundaries.test.mjs`
- Test: `scripts/check-r9-scope.test.mjs`

**Interfaces:**

- Consumes: Task 1 structural validator and Task 2 neutral session ownership.
- Produces: the exact export directives in Appendix A. No other symbols or
  files are public through an owner API.

- [ ] **Step 1: Add the API-existence RED fixture**

Extend the tracked-repository scanner test to assert the manifest's 19 API
paths exist and match the exact export path plus sorted non-empty `show` lists
in Appendix A. It must reject an absent API and one additional public symbol.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail because all 19 owner API files are absent.

- [ ] **Step 3: Create the 19 minimal owner APIs**

Create exactly the Appendix A contents. `wedding_plans_api.dart` exports the
concrete `screens/plan_management_screen.dart show PlanCenterScreen`; it does
not export the compatibility wrapper `screens/plan_center_screen.dart`.
`finance_api.dart` does not export the shared formatter library or symbols.
`auth_api.dart` does not export `SafeUser`.

- [ ] **Step 4: Run GREEN and preserve debt**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib
flutter analyze --no-pub
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-3
git diff --check
```

Expected: all pass; all APIs are structurally valid; debt remains exactly
legacy 265/root 34 because no consumer moved in this task.

- [ ] **Step 5: Review and commit**

Compare every export against Appendix A, stage only the 19 owner APIs, and
commit:

```powershell
git commit -m "refactor(mobile): define feature public APIs"
```

Expected: reviewed local API checkpoint and clean worktree. Do not push.

---

### Task 4: Migrate Identity Context And Onboarding Consumers

**Files:**

- Modify: `mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart`
- Modify: `mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart`
- Modify: `mobile/lib/features/auth/providers/auth_controller.dart`
- Modify: `mobile/lib/features/auth/screens/otp_screen.dart`
- Modify: `mobile/lib/features/auth/screens/register_screen.dart`
- Modify: `mobile/lib/features/auth/screens/splash_screen.dart`
- Modify: `mobile/lib/features/onboarding/data/local_plan_migration.dart`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: the owner APIs from Task 3.
- Produces: the exact source-to-owner imports in Appendix B, Identity batch;
  no internal target import remains in these seven sources.

- [ ] **Step 1: Add the Identity-batch RED assertion**

Add a scanner repository fixture that expects each Appendix B Identity source
to have exactly one API directive per target owner and no internal directive.
Run the scope command before editing to record legacy 265/root 34.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test --test-name-pattern="Identity batch" .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail on the seven existing internal-import sources.

- [ ] **Step 3: Replace imports atomically by source-target relationship**

For each Appendix B Identity line, remove every internal import to that target
feature and add one owner API import with the exact sorted `show` list. Do not
change identifiers, constructor calls, control flow, text, or test fixtures.

- [ ] **Step 4: Run focused GREEN and debt gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib/features/account_contexts lib/features/auth lib/features/onboarding
flutter analyze --no-pub
flutter test --no-pub test/features/account_contexts test/features/auth test/features/onboarding
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-4
git diff --check
```

Expected: all pass; debt is exactly legacy 255/root 34, a reduction of 10;
no mixed import exists in the batch.

- [ ] **Step 5: Review and commit**

Inspect imports and `git diff --word-diff=porcelain` to prove only directives
changed, stage the seven files plus the test assertion if it was added to the
tracked scanner test, and commit:

```powershell
git commit -m "refactor(mobile): route identity imports through public APIs"
```

Expected: reviewed local checkpoint and clean worktree. Do not push.

---

### Task 5: Migrate Collaboration And Provider Consumers

**Files:**

- Modify the 12 Marketplace source files in Appendix B, Collaboration batch.
- Modify: `mobile/lib/features/more/screens/more_screen.dart`
- Modify: `mobile/lib/features/more/widgets/more_screen_components.dart`
- Modify: `mobile/lib/features/notifications/screens/notifications_screen.dart`
- Modify: `mobile/lib/features/settings/screens/settings_screen.dart`
- Modify: `mobile/lib/features/sharing/screens/add_shared_member_screen.dart`
- Modify: `mobile/lib/features/sharing/screens/edit_shared_member_screen.dart`
- Modify: `mobile/lib/features/sharing/screens/invite_decision_screen.dart`
- Modify: `mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart`
- Modify: `mobile/lib/features/sharing/screens/sharing_screen.dart`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: all Task 3 owner APIs and the Task 4 migrated Identity surface.
- Produces: Appendix B Collaboration imports; no internal cross-feature import
  remains from Marketplace, More, Notifications, Settings, or Sharing sources.

- [ ] **Step 1: Add the Collaboration-batch RED assertion**

Assert the exact 21 source paths and source-target owner `show` lists from
Appendix B. Reject one unchanged internal import, one duplicate owner import,
and one missing symbol.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test --test-name-pattern="Collaboration batch" .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail on the current Marketplace/More/Notifications/Settings/Sharing
internal imports.

- [ ] **Step 3: Migrate the exact source-target relationships**

Apply the Appendix B Collaboration map mechanically. Consolidate all imports
from one source to one target feature into one exact owner API directive. Keep
provider lookup, auth guards, account-context decisions, quote-scoped chat,
sharing permissions, and UI behavior unchanged.

- [ ] **Step 4: Run focused GREEN and debt gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib/features/marketplace lib/features/more lib/features/notifications lib/features/settings lib/features/sharing
flutter analyze --no-pub
flutter test --no-pub test/features/marketplace test/features/more test/features/notifications test/features/settings test/features/sharing
flutter test --no-pub test/features/chat test/features/account_contexts
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-5
git diff --check
```

Expected: all pass; debt is exactly legacy 198/root 34, a reduction of 57;
no behavior assertion changes.

- [ ] **Step 5: Review and commit**

Review every source-target consolidation and focused test receipt, stage only
Task 5 paths plus its scanner assertion, and commit:

```powershell
git commit -m "refactor(mobile): route collaboration imports through public APIs"
```

Expected: reviewed local checkpoint and clean worktree. Do not push.

---

> **Owner/controller-approved corrective checkpoint C2 (2026-08-29):** Task
> 6's unused-import premise was false. `aarast_dashboard_view.dart` owns five
> `part` files, `aarast_dashboard_sections.dart:616` calls
> `compactMoneyParts`, and Dart parts share the root library's imports. The
> stateless formatter depends only on Core `currency_label.dart`, so C2 moves
> its declarations byte-for-byte from
> `mobile/lib/features/finance/models/money_formatters.dart` to
> `mobile/lib/core/utils/money_formatters.dart`, normalizing only the import
> from `../../../core/utils/currency_label.dart` to `currency_label.dart`.
> The existing formatter SHA-256 is
> `a9998b46f98f28f3d1bf52643459fa97a23accb685fd684569150d04446b7133`;
> the normalized Core SHA-256 must be
> `34515407d93a1733b80253561d22d3751deeac6321f85b2bf737304b10a4c37d`.
> Behavior and every existing contract assertion remain unchanged. This does
> not authorize a Finance API export, duplication, inlining, callback or
> injection redesign, renaming, refactoring, a final legal-count change, or a
> general permission to relocate utilities into Core. This C2 governance
> checkpoint must precede the corrected Task 6 application commit.

### Task 6: Migrate Planning And Operations Consumers

**Files:**

- Modify the five Finance sources in Appendix B, Planning batch.
- Modify: `mobile/lib/features/guests/screens/guest_list_screen.dart`
- Modify: `mobile/lib/features/tasks/screens/create_task_screen.dart`
- Modify: `mobile/lib/features/tasks/screens/task_timeline_screen.dart`
- Modify: `mobile/lib/features/tasks/widgets/create_task_components.dart`
- Modify: `mobile/lib/features/wedding_day/models/wedding_day_mode.dart`
- Modify: `mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart`
- Modify: `mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart`
- Modify the 12 Wedding Plans sources in Appendix B, Planning batch.
- Create: `mobile/lib/core/utils/money_formatters.dart`
- Delete: `mobile/lib/features/finance/models/money_formatters.dart`
- Modify: `mobile/lib/features/finance/widgets/money_widgets.dart`
- Modify: `mobile/test/features/finance/money_summary_contract_test.dart`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: Task 3 public surfaces and Task 2 Core `SafeUser`.
- Produces: Appendix B Planning imports; no internal cross-feature import
  remains from Finance, Guests, Tasks, Wedding Day, or Wedding Plans.

- [ ] **Step 1: Add the Planning-batch RED assertion**

Assert the exact source-target owner map from Appendix B. Require the formatter
implementation at the exact Core path with the approved normalized hash, the
old Finance formatter path absent, and exactly four mechanically changed
consumer import URIs in `money_overview_screen.dart`, `money_widgets.dart`,
`aarast_dashboard_view.dart`, and `money_summary_contract_test.dart`. Require
the dashboard root library to import the exact Core formatter. Require
`finance_api.dart` still not to export the formatter library or formatter
symbols, and preserve every existing assertion in
`money_summary_contract_test.dart`.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test --test-name-pattern="Planning batch" .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail on current internal imports and the pre-C2 Finance formatter
ownership/import URIs.

- [ ] **Step 3: Migrate Planning relationships and move the shared formatter**

Apply Appendix B mechanically. Move the formatter implementation declarations
byte-for-byte to Core, normalizing only the one relative
`currency_label.dart` import, then update exactly the four consumer import URIs
mechanically. The dashboard must import the exact Core formatter, the old
Finance formatter path must be absent, and `finance_api.dart` must still not
export the formatter library or symbols. Preserve every existing assertion in
`money_summary_contract_test.dart`. Keep finance permissions, private data,
task responsibility semantics, guest persistence, wedding-stage rules,
pulses, quick-add behavior, dashboard state, and formatter behavior unchanged.

- [ ] **Step 4: Run focused GREEN and debt gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib/core/utils/money_formatters.dart lib/features/finance lib/features/guests lib/features/tasks lib/features/wedding_day lib/features/wedding_plans test/features/finance/money_summary_contract_test.dart
flutter analyze --no-pub
flutter test --no-pub test/features/finance/money_summary_contract_test.dart
flutter test --no-pub test/features/finance test/features/guests test/features/tasks test/features/wedding_day test/features/wedding_plans
flutter test --no-pub test/core/offline test/core/storage
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-6
git diff --check
```

Expected: all pass; debt is exactly legacy 119/root 34, a reduction of 79
after the Task 2 `SafeUser` correction; final legal records remain 159;
private finance and formatter behavior are unchanged.

- [ ] **Step 5: Review and commit**

Review exactly 28 authorized Dart paths: the original 24 Planning paths plus
the Core formatter creation, old Finance formatter deletion, Finance widget
consumer, and Finance contract-test consumer. Stage only those Task 6 paths
plus its scanner assertion, and commit:

```powershell
git commit -m "refactor(mobile): route planning imports through public APIs"
```

Expected: reviewed local checkpoint and clean worktree. Do not push.

---

### Task 7: Migrate Home Shell And Welcome Consumers

**Files:**

- Modify: `mobile/lib/features/home/data/dashboard_summary_sources.dart`
- Modify: `mobile/lib/features/home/providers/home_dashboard_provider.dart`
- Modify: `mobile/lib/features/home/screens/dashboard_entry_screen.dart`
- Modify: `mobile/lib/features/home/screens/home_screen.dart`
- Modify: `mobile/lib/features/home/screens/local_guest_dashboard_screen.dart`
- Modify: `mobile/lib/features/shell/main_shell.dart`
- Modify: `mobile/lib/features/shell/screens/wedding_plan_shell.dart`
- Modify: `mobile/lib/features/shell/widgets/plan_shell_chrome.dart`
- Modify: `mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: all 19 owner APIs and the previously migrated source batches.
- Produces: Appendix B Shell/Entry imports; all direct cross-feature legacy debt
  is gone and only router/root composition debt remains.

- [ ] **Step 1: Add the Shell/Entry RED assertion**

Assert every Appendix B Shell/Entry source-target owner `show` list and require
that no internal cross-feature import remains outside the exact three
composition roots.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test --test-name-pattern="Shell Entry batch" .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail on Home 26, Shell 26, and Welcome 8 legacy records.

- [ ] **Step 3: Migrate the nine sources**

Apply Appendix B exactly. Preserve `MainShell`, tab navigation, selected plan,
guest dashboard, route decisions, quick actions, onboarding draft, session
restore, provider identities, Arabic/RTL, and loading/error/offline states.

- [ ] **Step 4: Run focused GREEN and debt gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib/features/home lib/features/shell lib/features/welcome_gateway
flutter analyze --no-pub
flutter test --no-pub test/features/home test/features/shell test/features/welcome_gateway
flutter test --no-pub test/features/account_contexts test/features/onboarding test/features/wedding_plans
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-r9-scope.mjs --check task-7
git diff --check
```

Expected: all pass; debt is exactly legacy 59/root 34; direct cross-feature
legacy debt is zero.

- [ ] **Step 5: Review and commit**

Review navigation/provider construction call sites for textual identity, stage
only Task 7 files plus its scanner assertion, and commit:

```powershell
git commit -m "refactor(mobile): route shell imports through public APIs"
```

Expected: reviewed local checkpoint and clean worktree. Do not push.

---

### Task 8: Migrate The Three Exact Composition Roots

**Files:**

- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/core/routing/app_router.dart`
- Modify: `scripts/check-mobile-boundaries.test.mjs`

**Interfaces:**

- Consumes: all Task 3 owner APIs and zero direct cross-feature debt from Task
  7.
- Produces: exact owner imports in Appendix C; `strictViolations == 0`,
  `legacyRecords == 0`, `rootRecords == 0`, and `legalRecords == 159`.

- [ ] **Step 1: Add the final composition RED assertion**

Require one owner API import per source-target feature with the exact `show`
list in Appendix C. Reject an internal feature import, missing `show`, root
export, a fourth composition source, a second API import for one owner, and any
`core/routing` file other than exact `app_router.dart`.

- [ ] **Step 2: Run RED**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test --test-name-pattern="composition roots" .\scripts\check-mobile-boundaries.test.mjs
```

Expected: fail on 59 router records and 34 omitted `main.dart`/`app.dart`
directives.

- [ ] **Step 3: Migrate `main.dart` and `app.dart`**

Consolidate current imports into the Appendix C `main.dart` and `app.dart`
owner imports. Preserve object creation order, provider constructors, proxy
updates, Auth status projection, and root widget shape.

- [ ] **Step 4: Migrate `app_router.dart`**

Replace all 59 internal route-facing imports with 17 owner API imports from
Appendix C. Preserve every route path, name, parent navigator, redirect,
`pageKey`, shell nesting, provider lookup, extra type/cast, and page builder.
Use the concrete `PlanCenterScreen` exported from
`plan_management_screen.dart`, not its wrapper file.

- [ ] **Step 5: Run zero-strict and focused routing GREEN**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
dart format --output=none --set-exit-if-changed lib/main.dart lib/app.dart lib/core/routing/app_router.dart
flutter analyze --no-pub
flutter test --no-pub test/core/routing test/core/session test/core/push
flutter test --no-pub test/features/account_contexts test/features/shell test/features/welcome_gateway
Set-Location ..
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\check-r9-scope.mjs --check task-8
git diff --check
```

Expected: all pass; legacy 0/root 0/strict 0; legal public records exactly 159;
historical baseline hash unchanged.

- [ ] **Step 6: Review and commit**

Compare the route table and provider construction before/after, stage only the
three composition roots plus the scanner assertion, and commit:

```powershell
git commit -m "refactor(mobile): migrate composition roots to public APIs"
```

Expected: reviewed local application candidate and clean worktree. Do not push.

---

> **Owner/controller-approved corrective checkpoint C3 (2026-08-29):** The
> Mobile CI job keeps `working-directory: mobile`, so its repository-level
> boundary command must keep the relative parent path
> `node ../scripts/check-mobile-boundaries.mjs`. Task 9 changes only the mode
> from `--check-baseline` to `--strict`; it does not change the Mobile working
> directory or the script path. Repository-root PowerShell commands continue
> to use `.\scripts`. This governance checkpoint must precede the Task 9 CI
> commit.

### Task 9: Activate Strict CI And Run Exhaustive Local Gates

**Files:**

- Modify: `.github/workflows/ci.yml`

**Interfaces:**

- Consumes: locally verified Task 8 candidate at strict zero.
- Produces: CI Mobile boundary command
  `node ../scripts/check-mobile-boundaries.mjs --strict`; historical write/check
  modes remain available locally.

- [ ] **Step 1: Prove the candidate is zero before editing CI**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\check-r9-scope.mjs --check task-8
```

Expected: both pass. Do not edit CI if either fails.

- [ ] **Step 2: Switch only the Mobile boundary CI command**

In `.github/workflows/ci.yml`, replace the exact
`node ../scripts/check-mobile-boundaries.mjs --check-baseline` invocation with
`node ../scripts/check-mobile-boundaries.mjs --strict`. Do not change triggers,
permissions, runners, dependency installation, Backend/Admin jobs, or secrets.

- [ ] **Step 3: Run full Mobile and repository architecture gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\check-r9-scope.mjs --check task-9
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
Set-Location .\mobile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

Expected: all checks pass; full Flutter suite includes existing Windows golden
tests; debug APK builds without tracked changes.

- [ ] **Step 4: Run proportional unchanged Backend and Admin gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npm audit --audit-level=high
npm audit --omit=dev
Set-Location ..\admin-web
npm run typecheck
npm test -- --run
npm run build
npm run smoke:honesty
npm run test:container-config
```

Expected: all pass with only previously documented intentional platform skips;
audits report zero High-or-higher findings; no Backend/Admin tracked file
changes. A runtime/environment failure is reported separately and never
reclassified as an R9 source pass.

- [ ] **Step 5: Review and commit CI**

Confirm `.github/workflows/ci.yml` has exactly one command-line replacement,
stage only that file, run `git diff --cached --check`, and commit:

```powershell
git commit -m "ci: enforce strict mobile boundaries"
```

Expected: strict CI local checkpoint and clean worktree. Do not push or run
remote CI.

---

### Task 10: Build The Local QA APK And Verify Phone 26

**Files:**

- No tracked source or documentation file changes.
- Local ignored output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Local rollback archive outside the repository:
  `D:\projects\aarast-local-artifacts\rollback\phone26-pre-r9-base.apk`

**Interfaces:**

- Consumes: Task 9 strict candidate, unchanged R8 Backend at port 3120, and
  owner-authorized A26 phone.
- Produces: sanitized build/install/runtime/phone receipt; real Firebase Push
  is either observed or labeled `UNVERIFIED`.

- [ ] **Step 1: Preserve the installed rollback APK and select one allowed phone without printing a serial**

Parse `adb devices` into memory, query models silently, require exactly one
online model matching `A26` or `SM-A26`, and reject every model matching `S10`
or `SM-G97`. Store the selected serial only in `$r9PhoneSerial`; never echo or
write it. Query the installed `com.aarast.aarast_mobile` package path, pull its
base APK to the exact rollback path, verify it with `apksigner`, record only its
SHA-256/version/signer fingerprint, and stop before installation if the pull or
verification fails. The APK contains application code only; do not pull app
data.

- [ ] **Step 2: Resolve and health-check the LAN API**

Select the active private IPv4 interface in memory, build
`$r9ApiBaseUrl = "http://<selected-ip>:3120"`, and request only `/live` and
`/ready`. Require HTTP 200 from both; do not log bodies, headers, or environment
values. Stop if more than one viable interface remains ambiguous.

- [ ] **Step 3: Build the same-lineage local debug APK**

```powershell
Set-Location D:\projects\aarast-modular-monolith\mobile
flutter build apk --debug --dart-define=AARAST_API_BASE_URL=$r9ApiBaseUrl
```

Expected: debug APK exists, uses the unchanged
`com.aarast.aarast_mobile` application ID, and no tracked file changes. Verify
the installed package signer and APK signer match before `install -r`; stop on
mismatch. Do not uninstall or clear application data.

- [ ] **Step 4: Upgrade and run the authenticated preservation journey**

Use `adb -s $r9PhoneSerial install -r` and direct every later ADB command with
the same in-memory serial. Verify with owner interaction:

```text
upgrade preserves application data
authenticated session and selected account context restore
dashboard opens
task, finance, marketplace, sharing, and wedding-plan route-extra journeys open
online force-stop/reopen restores session/context/dashboard
offline force-stop/reopen shows truthful offline state and no previous-account leak
network restore recovers without duplicate navigation
logout unregisters Push identity and returns to the accepted auth/welcome path
relogin isolates the new session and previous-account private data is absent
pending notification tap after auth opens Notifications exactly once
```

Use synthetic disposable data only where a write journey is required, then
delete it and verify absence. Never retain raw task/message/financial content.

- [ ] **Step 5: Classify Push and runtime evidence truthfully**

Verify unit/widget bind/unbind/pending-tap coverage from Task 2. If the local
environment can deliver a real Firebase notification, observe registration,
delivery, tap, and one inbox navigation. If it cannot, record exactly
`Live Firebase Push: UNVERIFIED`; do not infer it from inbox or unit tests.
Sanitize logcat/server evidence and require zero fatal, provider, route,
storage, overflow, connection, configured-key, configured-value, or secret
markers.

- [ ] **Step 6: Re-run exact candidate gates after phone QA**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\check-r9-scope.mjs --check task-10
git status --short
git diff --check
```

Expected: strict and scope pass, worktree is clean, S10 remains untouched, and
no phone-derived artifact is tracked.

- [ ] **Step 7: Obtain independent read-only review**

The reviewer compares the design, plan, immutable base, complete diff, API
surfaces, scanner rules, session codec, Push transitions, composition roots,
CI change, full gate outputs, phone receipt, and protected surfaces. Approval
requires no unresolved Critical or Important finding. The reviewer makes no
file or Git changes.

---

### Task 11: Close R9 With Truthful Documentation

**Files:**

- Modify: `ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/README.md`
- Modify: `docs/mobile/README.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/qa/README.md`
- Create: `docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md`
- Create: `docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md`

**Interfaces:**

- Consumes: exact Task 8 application candidate, Task 9 CI candidate, Task 10
  sanitized phone evidence, and independent review verdict.
- Produces: R9 design/completion receipts with application SHA, final legal
  record count 159, zero strict debt, exact PASS/FAIL/UNVERIFIED results, and
  the stop boundary.

- [ ] **Step 1: Freeze the application candidate before docs edits**

Record `git rev-parse HEAD` as the R9 application candidate and verify it is a
descendant of both immutable base and design commit. Rerun strict, scope Task
10, full Mobile analysis/tests, and `git status --short`. Do not use a prior
output after any source change.

- [ ] **Step 2: Write observed completion receipts**

Record only observed values: changed files, commit sequence, scanner test
count, legacy/root/strict counts, legal public records 159, all 19 API paths,
baseline hash, SafeUser codec proof, Push transition proof, full Flutter and
proportional Backend/Admin results, APK hash/package/signer comparison, phone
26 flows, live-Push classification, independent review, and remaining risks.

Update active docs consistently. State explicitly: no API/database/dependency/
UI/product behavior change; R8 Backend candidate
`464d785a0440b8494768a26a70ac1de73a4bff2c` remained the server; no S10, push,
merge, deploy, remote CI, store release, or R10.

- [ ] **Step 3: Verify docs and the exact final fence**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
node --test .\scripts\check-mobile-boundaries.test.mjs .\scripts\check-r9-scope.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\check-r9-scope.mjs --check task-11
git diff --check
git diff --name-status 833a4f1d31781b45cd0a68ecee1b969ac85f237f..HEAD
```

Expected: all gates pass; only Appendix D paths changed from the immutable
base; completion docs contain no secret or device serial; no generated-doc
drift.

- [ ] **Step 4: Create the local docs-only closeout checkpoint**

Stage only the 10 Task 11 documentation paths, inspect cached name/status and
whitespace, then commit:

```powershell
git commit -m "docs: close R9 mobile strict boundaries"
```

Expected: docs-only local closeout and clean worktree.

- [ ] **Step 5: Stop before external integration**

Report the local design, plan, application, CI, and closeout SHAs; final strict
and legal counts; all PASS/FAIL/UNVERIFIED gates; phone 26 result; remaining
risk; and exact changed-file inventory. Do not push, merge, deploy, run remote
CI, publish, use S10, or begin R10.

---

## Appendix A: Exact Owner Public API Contents

Every file starts with this comment and then the listed exports only:

```dart
// Owner-controlled public API. Cross-feature consumers import this library.
```

```dart
// mobile/lib/features/account_contexts/account_contexts_api.dart
export 'data/account_contexts_api.dart' show AccountContextsApi;
export 'models/account_context.dart'
    show AccountContext, AccountContextPermissions, AccountContextRole;
export 'providers/account_context_controller.dart'
    show AccountContextController;
export 'widgets/account_context_entry_gate.dart'
    show AccountContextEntryGate;
export 'widgets/wedding_plan_context_gate.dart'
    show SelectedWeddingPlanContextGate, WeddingPlanContextGate,
    WeddingPlanRouteAccess;

// mobile/lib/features/auth/auth_api.dart
export 'data/auth_repository.dart' show AuthRepository;
export 'providers/auth_controller.dart' show AuthController, AuthStatus;
export 'screens/login_screen.dart' show LoginScreen;
export 'screens/otp_screen.dart' show OtpScreen, OtpScreenArgs;
export 'screens/register_screen.dart' show RegisterScreen;
export 'screens/reset_password_screen.dart' show ResetPasswordScreen;
export 'screens/splash_screen.dart' show SplashScreen;
export 'utils/auth_action_guard.dart' show AuthActionGuard, AuthGatePanel;
export 'widgets/account_deletion_flow.dart' show confirmAccountDeletion;
export 'widgets/auth_wedding_widgets.dart'
    show AuthObscureToggle, AuthTextField;

// mobile/lib/features/catalogs/catalogs_api.dart
export 'data/reference_catalog_api.dart' show ReferenceCatalogApi;
export 'models/reference_catalog.dart'
    show ManagedReferenceCatalog, ManagedReferenceCatalogItem;
export 'providers/reference_catalog_provider.dart'
    show ReferenceCatalogProvider;

// mobile/lib/features/chat/chat_api.dart
export 'data/chat_api.dart' show ChatApi;
export 'data/chat_realtime_client.dart' show ChatRealtimeClient;
export 'providers/chat_provider.dart' show ChatProvider;
export 'screens/chat_screen.dart' show ChatScreen;
export 'screens/quote_conversation_entry_screen.dart'
    show QuoteConversationEntryScreen;
export 'widgets/conversation_list_view.dart' show ConversationListView;

// mobile/lib/features/finance/finance_api.dart
export 'data/finance_api.dart' show FinanceApi, LocalFinancePlanContext;
export 'models/budget_category.dart' show BudgetCategory;
export 'models/cost_draft_intent.dart' show CostDraftIntent;
export 'models/wedding_cost.dart' show WeddingCost;
export 'providers/finance_provider.dart' show FinanceProvider;
export 'screens/budget_category_details_screen.dart'
    show BudgetCategoryDetailsScreen;
export 'screens/budget_category_form_screen.dart'
    show BudgetCategoryFormScreen;
export 'screens/cost_details_screen.dart' show CostDetailsScreen;
export 'screens/cost_form_screen.dart' show CostFormScreen;
export 'screens/cost_payment_screens.dart'
    show CostPaymentDetailsScreen, RecordCostPaymentScreen;
export 'screens/costs_screen.dart' show CostsScreen;
export 'screens/money_budget_screen.dart' show MoneyBudgetScreen;
export 'screens/money_overview_screen.dart'
    show MoneyOverviewScreen, shouldShowMoneyStarter;
export 'screens/payment_schedule_screens.dart'
    show PayPaymentScheduleScreen, PaymentScheduleDetailsScreen,
    PaymentScheduleFormScreen, PaymentSchedulesScreen;
export 'widgets/money_cost_action_picker.dart'
    show MoneyCostActionIntent, showMoneyCostActionPicker;

// mobile/lib/features/guests/guests_api.dart
export 'data/guests_api.dart' show GuestsApi;
export 'models/guest.dart' show GuestSummary;
export 'providers/guests_provider.dart' show GuestsProvider;
export 'screens/guest_list_screen.dart' show GuestListScreen;

// mobile/lib/features/home/home_api.dart
export 'data/dashboard_summary_sources.dart'
    show LocalGuestDashboardSummary, LocalGuestDashboardSummarySource;
export 'providers/home_dashboard_provider.dart' show HomeDashboardProvider;
export 'screens/dashboard_entry_screen.dart' show DashboardEntryScreen;

// mobile/lib/features/marketplace/marketplace_api.dart
export 'data/marketplace_api.dart' show MarketplaceApi, ProviderDashboardApi;
export 'models/marketplace_models.dart' show MarketplaceProvider;
export 'models/provider_budget_match_intent.dart'
    show ProviderBudgetMatchIntent, ProviderQuoteInitialContext;
export 'providers/marketplace_provider.dart'
    show ProviderDashboardProvider, ProviderMarketplaceProvider,
    providerDirectoryErrorMessage, providerReferenceDataErrorMessage;
export 'screens/add_provider_package_screen.dart'
    show AddProviderPackageScreen;
export 'screens/add_provider_service_screen.dart'
    show AddProviderServiceScreen;
export 'screens/edit_provider_profile_screen.dart'
    show EditProviderProfileScreen;
export 'screens/favorite_providers_screen.dart' show FavoriteProvidersScreen;
export 'screens/provider_apply_screen.dart'
    show ProviderApplyScreen, ProviderApplyStatusScreen;
export 'screens/provider_details_screen.dart' show ProviderDetailsScreen;
export 'screens/provider_marketplace_screen.dart'
    show ProviderMarketplaceScreen;
export 'screens/provider_portal_screen.dart' show ProviderPortalScreen;
export 'screens/quote_request_screen.dart' show QuoteRequestScreen;
export 'widgets/provider_auth_gate.dart' show ProviderAuthGate;

// mobile/lib/features/more/more_api.dart
export 'screens/more_screen.dart' show MoreScreen;

// mobile/lib/features/notifications/notifications_api.dart
export 'data/notifications_api.dart' show NotificationsApi;
export 'providers/notifications_provider.dart' show NotificationsProvider;
export 'screens/notifications_screen.dart' show NotificationsScreen;

// mobile/lib/features/onboarding/onboarding_api.dart
export 'data/guest_onboarding_storage.dart' show GuestOnboardingStorage;
export 'data/local_plan_migration.dart'
    show LocalPlanMigrationService, LocalPlanSnapshot;
export 'data/yemen_administrative_api.dart' show YemenAdministrativeApi;
export 'models/generated_dashboard_seed.dart' show GeneratedDashboardSeed;
export 'models/guest_onboarding_draft.dart'
    show GuestOnboardingDraft, GuestOnboardingPath, GuestPersona;
export 'models/persona_copy.dart' show appRoleLabel, personaCopyForGuest;
export 'models/wedding_location_draft.dart' show WeddingLocationDraft;
export 'providers/guest_onboarding_provider.dart'
    show GuestOnboardingProvider;
export 'providers/yemen_administrative_provider.dart'
    show YemenAdministrativeProvider;
export 'screens/local_plan_migration_screen.dart'
    show LocalPlanMigrationScreen;
export 'widgets/location_picker_section.dart' show LocationPickerSection;

// mobile/lib/features/settings/settings_api.dart
export 'data/settings_api.dart' show SettingsApi;
export 'providers/settings_provider.dart' show SettingsProvider;
export 'screens/settings_screen.dart' show SettingsScreen;

// mobile/lib/features/sharing/sharing_api.dart
export 'data/sharing_api.dart' show SharingApi;
export 'models/plan_access_permissions.dart' show PlanAccessPermissions;
export 'models/shared_member.dart' show SharedMember, sharedMemberRoleLabel;
export 'models/shared_wedding_plan.dart' show SharedWeddingPlan;
export 'providers/contribution_history_provider.dart'
    show ContributionHistoryProvider;
export 'providers/sharing_provider.dart' show SharingProvider;
export 'screens/add_shared_member_screen.dart' show AddSharedMemberScreen;
export 'screens/contribution_history_screen.dart'
    show ContributionHistoryScreen;
export 'screens/edit_shared_member_screen.dart' show EditSharedMemberScreen;
export 'screens/invite_decision_screen.dart' show InviteDecisionScreen;
export 'screens/shared_wedding_plans_screen.dart'
    show SharedWeddingPlansScreen;
export 'screens/sharing_screen.dart' show SharingScreen;
export 'services/plan_leave_coordinator.dart' show PlanLeaveCoordinator;

// mobile/lib/features/shell/shell_api.dart
export 'main_shell.dart' show MainShell;
export 'screens/wedding_plan_shell.dart' show WeddingPlanShell;
export 'widgets/aarast_plan_chrome.dart'
    show AarastNavigationItem, AarastPlanNavigationBar, AarastQuickAction,
    showAarastQuickActionSheet;
export 'widgets/plan_shell_chrome.dart' show PlanShellChrome;

// mobile/lib/features/support/support_api.dart
export 'screens/support_screen.dart' show SupportScreen;

// mobile/lib/features/tasks/tasks_api.dart
export 'data/task_timeline_api.dart' show TaskTimelineApi;
export 'models/task_summary.dart' show TaskSummary;
export 'models/wedding_task.dart' show WeddingTask;
export 'providers/task_timeline_provider.dart' show TaskTimelineProvider;
export 'screens/create_task_screen.dart' show CreateTaskScreen;
export 'screens/task_timeline_screen.dart' show TaskTimelineScreen;

// mobile/lib/features/wedding_day/wedding_day_api.dart
export 'models/wedding_day_mode.dart'
    show WeddingDayModeStatus, WeddingDayPhase, resolveWeddingDayMode;
export 'screens/wedding_day_mode_screen.dart' show WeddingDayModeScreen;

// mobile/lib/features/wedding_plans/wedding_plans_api.dart
export 'data/wedding_plans_api.dart' show WeddingPlansApi;
export 'models/dashboard_summary.dart'
    show DashboardFinancialWarning, DashboardImportantItem,
    DashboardMoneySummary, DashboardNextPaymentSchedule,
    DashboardPermissionSummary, DashboardProviderPreview, DashboardSummary;
export 'models/onboarding_complete.dart'
    show OnboardingCompleteRequest, OnboardingCompleteResponse;
export 'models/wedding_plan_stage.dart'
    show WeddingPlanStage, WeddingPlanStageState, resolveWeddingPlanStage;
export 'models/wedding_plan.dart' show WeddingPlan;
export 'models/wedding_stage_domain_guidance.dart' show WeddingStageDomain;
export 'providers/dashboard_summary_provider.dart'
    show DashboardSummaryProvider;
export 'providers/wedding_plans_provider.dart' show WeddingPlansProvider;
export 'screens/create_wedding_plan_screen.dart'
    show CreateWeddingPlanScreen;
export 'screens/my_wedding_plans_screen.dart' show MyWeddingPlansScreen;
export 'screens/plan_management_screen.dart' show PlanCenterScreen;
export 'screens/wedding_plan_dashboard_screen.dart'
    show WeddingPlanDashboardScreen;
export 'utils/plan_pulse_sync.dart'
    show publishGuestPlanPulse, publishTaskPlanPulse;
export 'widgets/dashboard/aarast_dashboard_view.dart' show AarastDashboardView;
export 'widgets/quick_add_actions.dart'
    show QuickAddContext, QuickAddSignals, buildCanonicalQuickAddActions,
    lastCanonicalQuickAddAction, lastCanonicalQuickAddActionId,
    planQuickAddIconForTab, planQuickAddLabelForTab,
    rememberCanonicalQuickAddAction, shouldShowPlanQuickAdd;
export 'widgets/wedding_plan_creation_form.dart'
    show WeddingPlanCreationFields, WeddingPlanCreationScope;
export 'widgets/wedding_stage_context_line.dart'
    show WeddingStageContextLine;

// mobile/lib/features/welcome_gateway/welcome_gateway_api.dart
export 'screens/smart_welcome_screen.dart' show SmartWelcomeScreen;
```

## Appendix B: Exact Consumer-Source Migration Map

Each line means: replace all internal imports from the source to the named
target feature with one target root API import and the exact `show` list.

### Identity batch — Task 4

```text
account_contexts/widgets/account_context_entry_gate.dart -> shell_api.dart show MainShell
account_contexts/widgets/account_context_entry_gate.dart -> welcome_gateway_api.dart show SmartWelcomeScreen
account_contexts/widgets/wedding_plan_context_gate.dart -> auth_api.dart show AuthActionGuard, AuthController, AuthStatus
auth/providers/auth_controller.dart -> onboarding_api.dart show GuestOnboardingStorage
auth/screens/otp_screen.dart -> marketplace_api.dart show ProviderDashboardProvider
auth/screens/register_screen.dart -> marketplace_api.dart show ProviderMarketplaceProvider, providerReferenceDataErrorMessage
auth/screens/splash_screen.dart -> onboarding_api.dart show GuestOnboardingStorage
onboarding/data/local_plan_migration.dart -> wedding_plans_api.dart show OnboardingCompleteResponse, WeddingPlansApi
```

### Collaboration batch — Task 5

```text
marketplace/models/marketplace_models.dart -> onboarding_api.dart show WeddingLocationDraft
marketplace/screens/edit_provider_profile_screen.dart -> auth_api.dart show AuthActionGuard
marketplace/screens/favorite_providers_screen.dart -> auth_api.dart show AuthActionGuard
marketplace/screens/provider_apply_screen.dart -> account_contexts_api.dart show AccountContextController
marketplace/screens/provider_apply_screen.dart -> auth_api.dart show AuthActionGuard, AuthController, AuthStatus
marketplace/screens/provider_details_screen.dart -> account_contexts_api.dart show AccountContext, AccountContextController
marketplace/screens/provider_details_screen.dart -> auth_api.dart show AuthActionGuard
marketplace/screens/provider_marketplace_screen.dart -> account_contexts_api.dart show AccountContextController
marketplace/screens/provider_marketplace_screen.dart -> auth_api.dart show AuthActionGuard
marketplace/screens/provider_marketplace_screen.dart -> finance_api.dart show FinanceProvider
marketplace/screens/provider_marketplace_screen.dart -> onboarding_api.dart show GuestOnboardingStorage, GuestPersona, WeddingLocationDraft
marketplace/screens/provider_marketplace_screen.dart -> wedding_plans_api.dart show DashboardSummaryProvider, WeddingPlanStage, WeddingPlansProvider, WeddingStageContextLine, WeddingStageDomain, resolveWeddingPlanStage
marketplace/screens/provider_portal_screen.dart -> chat_api.dart show ChatProvider, ConversationListView
marketplace/screens/provider_profile_tab.dart -> account_contexts_api.dart show AccountContextController
marketplace/screens/provider_profile_tab.dart -> auth_api.dart show AuthController
marketplace/screens/provider_profile_tab.dart -> chat_api.dart show ChatProvider
marketplace/screens/quote_request_screen.dart -> account_contexts_api.dart show AccountContextController
marketplace/screens/quote_request_screen.dart -> auth_api.dart show AuthActionGuard, AuthController, AuthStatus
marketplace/screens/quote_request_screen.dart -> onboarding_api.dart show GuestOnboardingStorage, WeddingLocationDraft
marketplace/screens/quote_request_screen.dart -> wedding_plans_api.dart show WeddingPlansProvider
marketplace/widgets/provider_account_actions.dart -> auth_api.dart show confirmAccountDeletion
marketplace/widgets/provider_auth_gate.dart -> account_contexts_api.dart show AccountContextController
marketplace/widgets/provider_auth_gate.dart -> auth_api.dart show AuthController, AuthStatus
marketplace/widgets/provider_portal_bottom_nav.dart -> shell_api.dart show AarastNavigationItem, AarastPlanNavigationBar
more/screens/more_screen.dart -> account_contexts_api.dart show AccountContextController
more/screens/more_screen.dart -> auth_api.dart show AuthActionGuard, AuthController, AuthStatus, confirmAccountDeletion
more/screens/more_screen.dart -> onboarding_api.dart show GuestOnboardingDraft, GuestOnboardingStorage
more/widgets/more_screen_components.dart -> account_contexts_api.dart show AccountContext, AccountContextRole
more/widgets/more_screen_components.dart -> onboarding_api.dart show GuestOnboardingDraft, appRoleLabel, personaCopyForGuest
notifications/screens/notifications_screen.dart -> account_contexts_api.dart show AccountContextController
notifications/screens/notifications_screen.dart -> auth_api.dart show AuthActionGuard, AuthGatePanel
settings/screens/settings_screen.dart -> auth_api.dart show AuthActionGuard, AuthController, AuthGatePanel
sharing/screens/add_shared_member_screen.dart -> auth_api.dart show AuthActionGuard, AuthGatePanel
sharing/screens/edit_shared_member_screen.dart -> auth_api.dart show AuthActionGuard, AuthGatePanel
sharing/screens/invite_decision_screen.dart -> account_contexts_api.dart show AccountContextController
sharing/screens/invite_decision_screen.dart -> auth_api.dart show AuthController, AuthObscureToggle, AuthStatus, AuthTextField
sharing/screens/shared_wedding_plans_screen.dart -> account_contexts_api.dart show AccountContextController, AccountContextRole
sharing/screens/shared_wedding_plans_screen.dart -> auth_api.dart show AuthActionGuard, AuthGatePanel
sharing/screens/sharing_screen.dart -> auth_api.dart show AuthActionGuard, AuthGatePanel
```

### Planning batch — Task 6

```text
finance/models/money_starter_catalog.dart -> catalogs_api.dart show ManagedReferenceCatalog, ManagedReferenceCatalogItem
finance/providers/finance_provider.dart -> sharing_api.dart show PlanAccessPermissions, SharingApi
finance/screens/cost_form_screen.dart -> marketplace_api.dart show MarketplaceProvider, ProviderMarketplaceProvider, providerDirectoryErrorMessage
finance/screens/money_overview_screen.dart -> account_contexts_api.dart show AccountContextController
finance/screens/money_overview_screen.dart -> catalogs_api.dart show ReferenceCatalogProvider
finance/screens/money_overview_screen.dart -> onboarding_api.dart show GuestOnboardingProvider, GuestPersona
finance/screens/money_overview_screen.dart -> sharing_api.dart show SharedMember
finance/screens/money_overview_screen.dart -> wedding_plans_api.dart show DashboardSummaryProvider, WeddingPlansProvider, WeddingStageContextLine, WeddingStageDomain, resolveWeddingPlanStage
finance/widgets/finance_write_access_block.dart -> auth_api.dart show AuthActionGuard
guests/screens/guest_list_screen.dart -> auth_api.dart show AuthActionGuard
guests/screens/guest_list_screen.dart -> wedding_plans_api.dart show DashboardSummaryProvider, WeddingPlanStageState, WeddingStageContextLine, WeddingStageDomain, publishGuestPlanPulse, resolveWeddingPlanStage
tasks/screens/create_task_screen.dart -> auth_api.dart show AuthActionGuard, AuthController
tasks/screens/create_task_screen.dart -> sharing_api.dart show SharedMember, SharingProvider
tasks/screens/create_task_screen.dart -> wedding_plans_api.dart show publishTaskPlanPulse
tasks/screens/task_timeline_screen.dart -> auth_api.dart show AuthActionGuard
tasks/screens/task_timeline_screen.dart -> sharing_api.dart show SharedMember, SharingProvider
tasks/screens/task_timeline_screen.dart -> wedding_plans_api.dart show DashboardSummaryProvider, WeddingPlanStageState, WeddingStageContextLine, WeddingStageDomain, publishTaskPlanPulse, resolveWeddingPlanStage
tasks/widgets/create_task_components.dart -> sharing_api.dart show SharedMember, sharedMemberRoleLabel
wedding_day/models/wedding_day_mode.dart -> tasks_api.dart show WeddingTask
wedding_day/screens/wedding_day_mode_screen.dart -> auth_api.dart show AuthActionGuard
wedding_day/screens/wedding_day_mode_screen.dart -> home_api.dart show LocalGuestDashboardSummarySource
wedding_day/screens/wedding_day_mode_screen.dart -> onboarding_api.dart show GuestOnboardingStorage
wedding_day/screens/wedding_day_mode_screen.dart -> tasks_api.dart show TaskTimelineProvider, WeddingTask
wedding_day/screens/wedding_day_mode_screen.dart -> wedding_plans_api.dart show DashboardSummary, DashboardSummaryProvider, publishTaskPlanPulse
wedding_day/widgets/wedding_day_mode_view.dart -> tasks_api.dart show WeddingTask
wedding_day/widgets/wedding_day_mode_view.dart -> wedding_plans_api.dart show DashboardProviderPreview, DashboardSummary
wedding_plans/models/active_wedding_plan.dart -> onboarding_api.dart show WeddingLocationDraft
wedding_plans/models/onboarding_complete.dart -> finance_api.dart show BudgetCategory
wedding_plans/models/wedding_plan.dart -> onboarding_api.dart show WeddingLocationDraft
wedding_plans/providers/dashboard_summary_provider.dart -> sharing_api.dart show SharedMember
wedding_plans/screens/create_wedding_plan_screen.dart -> account_contexts_api.dart show AccountContextController, AccountContextRole
wedding_plans/screens/create_wedding_plan_screen.dart -> onboarding_api.dart show WeddingLocationDraft
wedding_plans/screens/my_wedding_plans_screen.dart -> account_contexts_api.dart show AccountContextController, AccountContextRole
wedding_plans/screens/plan_management_screen.dart -> account_contexts_api.dart show AccountContextController, AccountContextPermissions, AccountContextRole
wedding_plans/screens/plan_management_screen.dart -> auth_api.dart show AuthActionGuard, AuthController, confirmAccountDeletion
wedding_plans/screens/plan_management_screen.dart -> onboarding_api.dart show GuestOnboardingDraft, GuestOnboardingStorage, WeddingLocationDraft
wedding_plans/screens/plan_management_screen.dart -> sharing_api.dart show PlanLeaveCoordinator, SharedMember
wedding_plans/screens/plan_management_screen.dart -> shell_api.dart show AarastPlanNavigationBar
wedding_plans/screens/wedding_plan_dashboard_screen.dart -> account_contexts_api.dart show AccountContextController
wedding_plans/screens/wedding_plan_dashboard_screen.dart -> auth_api.dart show AuthActionGuard, AuthController
wedding_plans/screens/wedding_plan_dashboard_screen.dart -> home_api.dart show LocalGuestDashboardSummary, LocalGuestDashboardSummarySource
wedding_plans/screens/wedding_plan_dashboard_screen.dart -> onboarding_api.dart show GuestOnboardingStorage
wedding_plans/screens/wedding_plan_dashboard_screen.dart -> sharing_api.dart show SharedMember
wedding_plans/utils/plan_pulse_sync.dart -> guests_api.dart show GuestSummary
wedding_plans/utils/plan_pulse_sync.dart -> tasks_api.dart show TaskSummary
wedding_plans/widgets/dashboard/aarast_dashboard_view.dart -> core/utils/money_formatters.dart show compactMoneyParts
wedding_plans/widgets/dashboard/aarast_dashboard_view.dart -> wedding_day_api.dart show WeddingDayModeStatus, WeddingDayPhase, resolveWeddingDayMode
wedding_plans/widgets/quick_add_actions.dart -> shell_api.dart show AarastQuickAction
wedding_plans/widgets/wedding_plan_creation_form.dart -> onboarding_api.dart show LocationPickerSection
```

### Shell/Entry batch — Task 7

```text
home/data/dashboard_summary_sources.dart -> onboarding_api.dart show GeneratedDashboardSeed, GuestOnboardingDraft, GuestOnboardingStorage
home/data/dashboard_summary_sources.dart -> wedding_plans_api.dart show DashboardFinancialWarning, DashboardImportantItem, DashboardMoneySummary, DashboardNextPaymentSchedule, DashboardPermissionSummary, DashboardSummary
home/providers/home_dashboard_provider.dart -> sharing_api.dart show SharedWeddingPlan, SharingApi
home/providers/home_dashboard_provider.dart -> wedding_plans_api.dart show WeddingPlan, WeddingPlansApi
home/screens/dashboard_entry_screen.dart -> account_contexts_api.dart show AccountContextController, AccountContextEntryGate
home/screens/dashboard_entry_screen.dart -> auth_api.dart show AuthController, AuthStatus
home/screens/dashboard_entry_screen.dart -> onboarding_api.dart show GuestOnboardingStorage, LocalPlanMigrationScreen, LocalPlanMigrationService, LocalPlanSnapshot
home/screens/dashboard_entry_screen.dart -> wedding_plans_api.dart show WeddingPlansApi
home/screens/home_screen.dart -> auth_api.dart show AuthController
home/screens/home_screen.dart -> notifications_api.dart show NotificationsProvider
home/screens/local_guest_dashboard_screen.dart -> auth_api.dart show AuthActionGuard
home/screens/local_guest_dashboard_screen.dart -> onboarding_api.dart show personaCopyForGuest
home/screens/local_guest_dashboard_screen.dart -> shell_api.dart show PlanShellChrome, showAarastQuickActionSheet
home/screens/local_guest_dashboard_screen.dart -> wedding_plans_api.dart show AarastDashboardView, DashboardImportantItem, DashboardSummary, DashboardSummaryProvider, QuickAddSignals, buildCanonicalQuickAddActions, resolveWeddingPlanStage
shell/main_shell.dart -> account_contexts_api.dart show AccountContext, AccountContextController, AccountContextRole
shell/main_shell.dart -> finance_api.dart show FinanceProvider, MoneyCostActionIntent, MoneyOverviewScreen, shouldShowMoneyStarter, showMoneyCostActionPicker
shell/main_shell.dart -> guests_api.dart show GuestListScreen
shell/main_shell.dart -> marketplace_api.dart show ProviderMarketplaceScreen
shell/main_shell.dart -> tasks_api.dart show TaskTimelineScreen
shell/main_shell.dart -> wedding_plans_api.dart show DashboardSummaryProvider, PlanCenterScreen, QuickAddContext, QuickAddSignals, WeddingPlanDashboardScreen, buildCanonicalQuickAddActions, lastCanonicalQuickAddAction, lastCanonicalQuickAddActionId, rememberCanonicalQuickAddAction, resolveWeddingPlanStage, shouldShowPlanQuickAdd
shell/screens/wedding_plan_shell.dart -> account_contexts_api.dart show AccountContextController, AccountContextRole
shell/screens/wedding_plan_shell.dart -> auth_api.dart show AuthActionGuard
shell/screens/wedding_plan_shell.dart -> finance_api.dart show FinanceProvider, MoneyCostActionIntent, shouldShowMoneyStarter, showMoneyCostActionPicker
shell/screens/wedding_plan_shell.dart -> home_api.dart show LocalGuestDashboardSummarySource
shell/screens/wedding_plan_shell.dart -> onboarding_api.dart show GuestOnboardingStorage
shell/screens/wedding_plan_shell.dart -> wedding_plans_api.dart show DashboardSummary, DashboardSummaryProvider, QuickAddContext, QuickAddSignals, buildCanonicalQuickAddActions, lastCanonicalQuickAddAction, lastCanonicalQuickAddActionId, rememberCanonicalQuickAddAction, resolveWeddingPlanStage, shouldShowPlanQuickAdd
shell/widgets/plan_shell_chrome.dart -> wedding_plans_api.dart show planQuickAddIconForTab, planQuickAddLabelForTab
welcome_gateway/screens/smart_welcome_screen.dart -> account_contexts_api.dart show AccountContextController
welcome_gateway/screens/smart_welcome_screen.dart -> auth_api.dart show AuthController, AuthStatus
welcome_gateway/screens/smart_welcome_screen.dart -> onboarding_api.dart show GuestOnboardingDraft, GuestOnboardingPath, GuestOnboardingStorage, GuestPersona, WeddingLocationDraft
welcome_gateway/screens/smart_welcome_screen.dart -> wedding_plans_api.dart show OnboardingCompleteRequest, WeddingPlanCreationFields, WeddingPlanCreationScope, WeddingPlansProvider
```

## Appendix C: Exact Root Inventories And Final Composition Imports

### Immutable 34-directive root inventory

Every record has `directiveKind: "import"` and `count: 1`.

```text
mobile/lib/app.dart -> mobile/lib/features/account_contexts/providers/account_context_controller.dart
mobile/lib/app.dart -> mobile/lib/features/auth/providers/auth_controller.dart
mobile/lib/main.dart -> mobile/lib/features/account_contexts/data/account_contexts_api.dart
mobile/lib/main.dart -> mobile/lib/features/account_contexts/providers/account_context_controller.dart
mobile/lib/main.dart -> mobile/lib/features/auth/data/auth_repository.dart
mobile/lib/main.dart -> mobile/lib/features/auth/providers/auth_controller.dart
mobile/lib/main.dart -> mobile/lib/features/catalogs/data/reference_catalog_api.dart
mobile/lib/main.dart -> mobile/lib/features/catalogs/providers/reference_catalog_provider.dart
mobile/lib/main.dart -> mobile/lib/features/chat/data/chat_api.dart
mobile/lib/main.dart -> mobile/lib/features/chat/data/chat_realtime_client.dart
mobile/lib/main.dart -> mobile/lib/features/chat/providers/chat_provider.dart
mobile/lib/main.dart -> mobile/lib/features/finance/data/finance_api.dart
mobile/lib/main.dart -> mobile/lib/features/finance/providers/finance_provider.dart
mobile/lib/main.dart -> mobile/lib/features/guests/data/guests_api.dart
mobile/lib/main.dart -> mobile/lib/features/guests/providers/guests_provider.dart
mobile/lib/main.dart -> mobile/lib/features/home/providers/home_dashboard_provider.dart
mobile/lib/main.dart -> mobile/lib/features/marketplace/data/marketplace_api.dart
mobile/lib/main.dart -> mobile/lib/features/marketplace/providers/marketplace_provider.dart
mobile/lib/main.dart -> mobile/lib/features/notifications/data/notifications_api.dart
mobile/lib/main.dart -> mobile/lib/features/notifications/providers/notifications_provider.dart
mobile/lib/main.dart -> mobile/lib/features/onboarding/data/guest_onboarding_storage.dart
mobile/lib/main.dart -> mobile/lib/features/onboarding/data/yemen_administrative_api.dart
mobile/lib/main.dart -> mobile/lib/features/onboarding/providers/yemen_administrative_provider.dart
mobile/lib/main.dart -> mobile/lib/features/settings/data/settings_api.dart
mobile/lib/main.dart -> mobile/lib/features/settings/providers/settings_provider.dart
mobile/lib/main.dart -> mobile/lib/features/sharing/data/sharing_api.dart
mobile/lib/main.dart -> mobile/lib/features/sharing/providers/contribution_history_provider.dart
mobile/lib/main.dart -> mobile/lib/features/sharing/providers/sharing_provider.dart
mobile/lib/main.dart -> mobile/lib/features/sharing/services/plan_leave_coordinator.dart
mobile/lib/main.dart -> mobile/lib/features/tasks/data/task_timeline_api.dart
mobile/lib/main.dart -> mobile/lib/features/tasks/providers/task_timeline_provider.dart
mobile/lib/main.dart -> mobile/lib/features/wedding_plans/data/wedding_plans_api.dart
mobile/lib/main.dart -> mobile/lib/features/wedding_plans/providers/dashboard_summary_provider.dart
mobile/lib/main.dart -> mobile/lib/features/wedding_plans/providers/wedding_plans_provider.dart
```

### Final `main.dart` owner imports

```text
account_contexts_api.dart show AccountContextsApi, AccountContextController
auth_api.dart show AuthController, AuthRepository
catalogs_api.dart show ReferenceCatalogApi, ReferenceCatalogProvider
chat_api.dart show ChatApi, ChatProvider, ChatRealtimeClient
finance_api.dart show FinanceApi, FinanceProvider, LocalFinancePlanContext
guests_api.dart show GuestsApi, GuestsProvider
home_api.dart show HomeDashboardProvider
marketplace_api.dart show MarketplaceApi, ProviderDashboardApi, ProviderDashboardProvider, ProviderMarketplaceProvider
notifications_api.dart show NotificationsApi, NotificationsProvider
onboarding_api.dart show GuestOnboardingStorage, YemenAdministrativeApi, YemenAdministrativeProvider
settings_api.dart show SettingsApi, SettingsProvider
sharing_api.dart show ContributionHistoryProvider, PlanLeaveCoordinator, SharingApi, SharingProvider
tasks_api.dart show TaskTimelineApi, TaskTimelineProvider
wedding_plans_api.dart show DashboardSummaryProvider, WeddingPlansApi, WeddingPlansProvider
```

### Final `app.dart` owner imports

```text
account_contexts_api.dart show AccountContextController
auth_api.dart show AuthController, AuthStatus
```

### Final `app_router.dart` owner imports

```text
account_contexts_api.dart show AccountContextController, AccountContextRole, SelectedWeddingPlanContextGate, WeddingPlanContextGate, WeddingPlanRouteAccess
auth_api.dart show LoginScreen, OtpScreen, OtpScreenArgs, RegisterScreen, ResetPasswordScreen, SplashScreen
chat_api.dart show ChatScreen, ConversationListView, QuoteConversationEntryScreen
finance_api.dart show BudgetCategory, BudgetCategoryDetailsScreen, BudgetCategoryFormScreen, CostDetailsScreen, CostDraftIntent, CostFormScreen, CostPaymentDetailsScreen, CostsScreen, FinanceProvider, MoneyBudgetScreen, MoneyOverviewScreen, PayPaymentScheduleScreen, PaymentScheduleDetailsScreen, PaymentScheduleFormScreen, PaymentSchedulesScreen, RecordCostPaymentScreen, WeddingCost
guests_api.dart show GuestListScreen
home_api.dart show DashboardEntryScreen
marketplace_api.dart show AddProviderPackageScreen, AddProviderServiceScreen, EditProviderProfileScreen, FavoriteProvidersScreen, ProviderApplyScreen, ProviderApplyStatusScreen, ProviderAuthGate, ProviderBudgetMatchIntent, ProviderDetailsScreen, ProviderMarketplaceScreen, ProviderPortalScreen, ProviderQuoteInitialContext, QuoteRequestScreen
more_api.dart show MoreScreen
notifications_api.dart show NotificationsScreen
settings_api.dart show SettingsScreen
sharing_api.dart show AddSharedMemberScreen, ContributionHistoryScreen, EditSharedMemberScreen, InviteDecisionScreen, SharedMember, SharedWeddingPlansScreen, SharingScreen
shell_api.dart show WeddingPlanShell
support_api.dart show SupportScreen
tasks_api.dart show CreateTaskScreen, TaskTimelineScreen, WeddingTask
wedding_day_api.dart show WeddingDayModeScreen
wedding_plans_api.dart show CreateWeddingPlanScreen, DashboardSummary, MyWeddingPlansScreen, PlanCenterScreen, WeddingPlanDashboardScreen
welcome_gateway_api.dart show SmartWelcomeScreen
```

## Appendix D: Exact R9 Allowed Changed-Path Fence

The manifest contains this sorted 151-path array exactly. The historical
baseline is intentionally absent because it is immutable.

```text
.github/workflows/ci.yml
ARCHITECTURE.md
CHANGELOG.md
docs/README.md
docs/mobile/README.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/qa/README.md
docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md
docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries.md
docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-completion.md
docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-design.md
mobile/integration_test/account_context_runtime_smoke_test.dart
mobile/lib/app.dart
mobile/lib/core/network/api_client.dart
mobile/lib/core/offline/offline_sync_service.dart
mobile/lib/core/push/push_lifecycle_bridge.dart
mobile/lib/core/routing/app_router.dart
mobile/lib/core/session/safe_user.dart
mobile/lib/core/storage/auth_storage.dart
mobile/lib/core/utils/money_formatters.dart
mobile/lib/features/account_contexts/account_contexts_api.dart
mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart
mobile/lib/features/account_contexts/widgets/wedding_plan_context_gate.dart
mobile/lib/features/auth/auth_api.dart
mobile/lib/features/auth/data/auth_repository.dart
mobile/lib/features/auth/models/auth_otp.dart
mobile/lib/features/auth/models/auth_response.dart
mobile/lib/features/auth/models/safe_user.dart
mobile/lib/features/auth/providers/auth_controller.dart
mobile/lib/features/auth/screens/otp_screen.dart
mobile/lib/features/auth/screens/register_screen.dart
mobile/lib/features/auth/screens/splash_screen.dart
mobile/lib/features/catalogs/catalogs_api.dart
mobile/lib/features/chat/chat_api.dart
mobile/lib/features/finance/finance_api.dart
mobile/lib/features/finance/models/money_formatters.dart
mobile/lib/features/finance/models/money_starter_catalog.dart
mobile/lib/features/finance/providers/finance_provider.dart
mobile/lib/features/finance/screens/cost_form_screen.dart
mobile/lib/features/finance/screens/money_overview_screen.dart
mobile/lib/features/finance/widgets/finance_write_access_block.dart
mobile/lib/features/finance/widgets/money_widgets.dart
mobile/lib/features/guests/guests_api.dart
mobile/lib/features/guests/screens/guest_list_screen.dart
mobile/lib/features/home/data/dashboard_summary_sources.dart
mobile/lib/features/home/home_api.dart
mobile/lib/features/home/providers/home_dashboard_provider.dart
mobile/lib/features/home/screens/dashboard_entry_screen.dart
mobile/lib/features/home/screens/home_screen.dart
mobile/lib/features/home/screens/local_guest_dashboard_screen.dart
mobile/lib/features/marketplace/marketplace_api.dart
mobile/lib/features/marketplace/models/marketplace_models.dart
mobile/lib/features/marketplace/screens/edit_provider_profile_screen.dart
mobile/lib/features/marketplace/screens/favorite_providers_screen.dart
mobile/lib/features/marketplace/screens/provider_apply_screen.dart
mobile/lib/features/marketplace/screens/provider_details_screen.dart
mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart
mobile/lib/features/marketplace/screens/provider_portal_screen.dart
mobile/lib/features/marketplace/screens/provider_profile_tab.dart
mobile/lib/features/marketplace/screens/quote_request_screen.dart
mobile/lib/features/marketplace/widgets/provider_account_actions.dart
mobile/lib/features/marketplace/widgets/provider_auth_gate.dart
mobile/lib/features/marketplace/widgets/provider_portal_bottom_nav.dart
mobile/lib/features/more/more_api.dart
mobile/lib/features/more/screens/more_screen.dart
mobile/lib/features/more/widgets/more_screen_components.dart
mobile/lib/features/notifications/notifications_api.dart
mobile/lib/features/notifications/screens/notifications_screen.dart
mobile/lib/features/onboarding/data/local_plan_migration.dart
mobile/lib/features/onboarding/onboarding_api.dart
mobile/lib/features/settings/screens/settings_screen.dart
mobile/lib/features/settings/settings_api.dart
mobile/lib/features/sharing/screens/add_shared_member_screen.dart
mobile/lib/features/sharing/screens/edit_shared_member_screen.dart
mobile/lib/features/sharing/screens/invite_decision_screen.dart
mobile/lib/features/sharing/screens/shared_wedding_plans_screen.dart
mobile/lib/features/sharing/screens/sharing_screen.dart
mobile/lib/features/sharing/sharing_api.dart
mobile/lib/features/shell/main_shell.dart
mobile/lib/features/shell/screens/wedding_plan_shell.dart
mobile/lib/features/shell/shell_api.dart
mobile/lib/features/shell/widgets/plan_shell_chrome.dart
mobile/lib/features/support/support_api.dart
mobile/lib/features/tasks/screens/create_task_screen.dart
mobile/lib/features/tasks/screens/task_timeline_screen.dart
mobile/lib/features/tasks/tasks_api.dart
mobile/lib/features/tasks/widgets/create_task_components.dart
mobile/lib/features/wedding_day/models/wedding_day_mode.dart
mobile/lib/features/wedding_day/screens/wedding_day_mode_screen.dart
mobile/lib/features/wedding_day/wedding_day_api.dart
mobile/lib/features/wedding_day/widgets/wedding_day_mode_view.dart
mobile/lib/features/wedding_plans/models/active_wedding_plan.dart
mobile/lib/features/wedding_plans/models/onboarding_complete.dart
mobile/lib/features/wedding_plans/models/wedding_plan.dart
mobile/lib/features/wedding_plans/providers/dashboard_summary_provider.dart
mobile/lib/features/wedding_plans/screens/create_wedding_plan_screen.dart
mobile/lib/features/wedding_plans/screens/my_wedding_plans_screen.dart
mobile/lib/features/wedding_plans/screens/plan_management_screen.dart
mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart
mobile/lib/features/wedding_plans/utils/plan_pulse_sync.dart
mobile/lib/features/wedding_plans/wedding_plans_api.dart
mobile/lib/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart
mobile/lib/features/wedding_plans/widgets/quick_add_actions.dart
mobile/lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart
mobile/lib/features/welcome_gateway/screens/smart_welcome_screen.dart
mobile/lib/features/welcome_gateway/welcome_gateway_api.dart
mobile/lib/main.dart
mobile/test/core/forms/aarast_form_draft_store_test.dart
mobile/test/core/push/push_lifecycle_bridge_test.dart
mobile/test/core/session/safe_user_persistence_contract_test.dart
mobile/test/core/session/session_teardown_push_authorization_test.dart
mobile/test/core/storage/account_context_storage_test.dart
mobile/test/core/storage/auth_session_privacy_test.dart
mobile/test/favorite_providers_preview_test.dart
mobile/test/features/auth/auth_controller_session_guard_test.dart
mobile/test/features/auth/legacy_unverified_login_flow_test.dart
mobile/test/features/auth/otp_account_recovery_actions_test.dart
mobile/test/features/auth/profile_avatar_upload_test.dart
mobile/test/features/auth/provider_to_groom_session_flow_test.dart
mobile/test/features/auth/session_transition_gate_test.dart
mobile/test/features/chat/chat_provider_reliability_test.dart
mobile/test/features/chat/chat_realtime_client_test.dart
mobile/test/features/finance/money_summary_contract_test.dart
mobile/test/features/marketplace/city_filter_picker_test.dart
mobile/test/features/marketplace/marketplace_context_isolation_test.dart
mobile/test/features/marketplace/offers_inbox_card_test.dart
mobile/test/features/marketplace/phase_b_provider_screens_test.dart
mobile/test/features/marketplace/provider_auth_gate_test.dart
mobile/test/features/marketplace/provider_marketplace_shell_navigation_regression_test.dart
mobile/test/features/marketplace/provider_portal_chat_test.dart
mobile/test/features/marketplace/super5_providers_contract_test.dart
mobile/test/features/more/profile_menu_destinations_test.dart
mobile/test/features/notifications/notification_context_isolation_test.dart
mobile/test/features/settings/settings_account_gate_test.dart
mobile/test/features/sharing/invite_access_screen_test.dart
mobile/test/features/sharing/invite_share_success_test.dart
mobile/test/features/sharing/phase_c_sharing_screens_test.dart
mobile/test/features/sharing/sharing_auth_gate_test.dart
mobile/test/features/tasks/super3_tasks_contract_test.dart
mobile/test/features/wedding_plans/contributor_account_actions_test.dart
mobile/test/features/wedding_plans/owner_dashboard_sharing_refresh_test.dart
mobile/test/more_preview_test.dart
mobile/test/notifications_preview_test.dart
mobile/test/sharing_preview_test.dart
scripts/architecture/r9-mobile-strict-manifest.json
scripts/check-mobile-boundaries.mjs
scripts/check-mobile-boundaries.test.mjs
scripts/check-r9-scope.mjs
scripts/check-r9-scope.test.mjs
```

## Appendix E: Existing SafeUser Import-Only Test Consumers

Task 2 mechanically updates these existing tests; assertions and fixtures stay
unchanged:

```text
mobile/test/core/forms/aarast_form_draft_store_test.dart
mobile/test/core/session/session_teardown_push_authorization_test.dart
mobile/test/core/storage/account_context_storage_test.dart
mobile/test/core/storage/auth_session_privacy_test.dart
mobile/test/favorite_providers_preview_test.dart
mobile/test/features/auth/auth_controller_session_guard_test.dart
mobile/test/features/auth/legacy_unverified_login_flow_test.dart
mobile/test/features/auth/otp_account_recovery_actions_test.dart
mobile/test/features/auth/profile_avatar_upload_test.dart
mobile/test/features/auth/provider_to_groom_session_flow_test.dart
mobile/test/features/auth/session_transition_gate_test.dart
mobile/test/features/chat/chat_provider_reliability_test.dart
mobile/test/features/chat/chat_realtime_client_test.dart
mobile/test/features/marketplace/city_filter_picker_test.dart
mobile/test/features/marketplace/marketplace_context_isolation_test.dart
mobile/test/features/marketplace/offers_inbox_card_test.dart
mobile/test/features/marketplace/phase_b_provider_screens_test.dart
mobile/test/features/marketplace/provider_auth_gate_test.dart
mobile/test/features/marketplace/provider_marketplace_shell_navigation_regression_test.dart
mobile/test/features/marketplace/provider_portal_chat_test.dart
mobile/test/features/marketplace/super5_providers_contract_test.dart
mobile/test/features/more/profile_menu_destinations_test.dart
mobile/test/features/notifications/notification_context_isolation_test.dart
mobile/test/features/settings/settings_account_gate_test.dart
mobile/test/features/sharing/invite_access_screen_test.dart
mobile/test/features/sharing/invite_share_success_test.dart
mobile/test/features/sharing/phase_c_sharing_screens_test.dart
mobile/test/features/sharing/sharing_auth_gate_test.dart
mobile/test/features/tasks/super3_tasks_contract_test.dart
mobile/test/features/wedding_plans/contributor_account_actions_test.dart
mobile/test/features/wedding_plans/owner_dashboard_sharing_refresh_test.dart
mobile/test/more_preview_test.dart
mobile/test/notifications_preview_test.dart
mobile/test/sharing_preview_test.dart
```

## Final Review Checklist

- [ ] Every design requirement maps to a numbered task.
- [ ] Every source change is inside Appendix D and assigned to one task.
- [ ] The 19 API paths and export symbols match Appendix A consistently.
- [ ] Debt milestones are monotonic: `269, 265, 265, 255, 198, 119, 59, 0`.
- [ ] Final strict violations are zero while legal public records are 159.
- [ ] Historical baseline and R8 Backend candidate remain unchanged.
- [ ] Push and `SafeUser` preserve behavior through explicit tests and phone QA.
- [ ] CI moves to strict only after the same local candidate passes strict.
- [ ] Completion stops before push, merge, deployment, remote CI, store release,
  S10, or R10.
