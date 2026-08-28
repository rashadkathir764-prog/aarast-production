# Modular Monolith R9 Mobile Strict Boundaries Design

Date: 2026-08-28

Status: Owner-approved design direction; implementation plan pending separate
owner review

Branch: `modular-monolith`

Immutable R9 base: `833a4f1d31781b45cd0a68ecee1b969ac85f237f`

## Objective

Activate the existing R9 strict Mobile boundary contract without changing
product behavior. Every cross-feature Dart dependency must enter the owning
feature through one reviewed root public API, every non-composition
`core -> feature` dependency must be removed at its ownership boundary, and
the three approved composition roots must depend only on owner public APIs.

R9 is a Mobile architecture phase. It does not add a product feature, change
Arabic copy or routed behavior, alter Backend/Admin/API/database/deployment
contracts, upgrade dependencies, or redesign the UI.

## Decision Summary

R9 uses owner-controlled public APIs and root-cause dependency correction. It
does not create broad compatibility barrels merely to satisfy the scanner.

The chosen sequence is:

1. freeze the live R9 inventories and correct transitional scanner semantics;
2. enforce the public-API contract before any public API is created;
3. move the persisted session principal to neutral Core ownership and project
   authenticated user identity into Push as immutable data;
4. create and validate all 19 owner public APIs;
5. migrate consumers in source-oriented reviewed batches;
6. migrate the exact composition roots last;
7. prove strict violations are zero, then replace the CI baseline command with
   strict mode;
8. run exhaustive static, behavioral, build, runtime, phone, documentation,
   scope, and independent-review gates before local closeout.

## Verified Starting State

The R8 docs closeout is clean at the immutable R9 base. The R8 Backend
application candidate remains
`464d785a0440b8494768a26a70ac1de73a4bff2c`; R9 does not rebuild or change its
Backend source.

The live Mobile boundary scanner has three modes:

- `--write-baseline` writes the historical counted baseline;
- `--check-baseline` prevents an existing violating key/count from increasing;
- `--strict` applies the deferred R9 public-API and composition rules.

At the R9 base:

| Evidence | Verified value |
| --- | --- |
| Historical baseline source revision | `feafe3db0053d6c66d5f46b56ff9a512861dfbad` |
| Historical baseline SHA-256 | `f9939fa25b7e3e3b7e3563c4dce30aa9a2cb0781cdf2ed8bbf9448477644cf1f` |
| Live counted records | 269 |
| Direct cross-feature records | 207 |
| `core -> feature` records | 62 |
| `app_router.dart -> feature` records | 59 |
| Non-routing `core -> auth` records | 3 |
| Root composition imports omitted by the current scanner | 34: 32 from `main.dart`, 2 from `app.dart` |
| Feature directories / required owner APIs | 19 |
| Existing root owner APIs | 0 |
| Scanner tests | 192/192 PASS |
| Baseline mode | PASS with 269 current records |
| Strict mode | Expected FAIL with 269 strict violations |
| Focused session/storage/offline/push/routing tests from design review | 67 PASS |

The 19 current features are:

```text
account_contexts
auth
catalogs
chat
finance
guests
home
marketplace
more
notifications
onboarding
settings
sharing
shell
support
tasks
wedding_day
wedding_plans
welcome_gateway
```

Independent graph review found one strongly connected component containing 14
features. The migration therefore cannot truthfully describe those features as
a topological foundation-to-leaf sequence.

## Root-Cause Standard

R9 succeeds only when ownership is explicit in both source and governance:

- a feature owns its internal models, providers, data clients, widgets,
  screens, services, and public API;
- a cross-feature consumer imports the exact owner root API rather than an
  internal owner path;
- Core does not import a feature except at an exact approved composition root;
- neutral session persistence contracts belong to Core, not Auth UI/state;
- Push receives the immutable identity value it needs and never reads an Auth
  provider itself;
- a legal public edge remains visible in the final inventory even though it is
  not a strict violation;
- a scanner pass is insufficient if a public API exposes internals broadly,
  re-exports another feature, or preserves old and new paths together.

R9 forbids:

- bare or wildcard-style owner exports;
- `hide` combinators on public exports or cross-area imports;
- a public API importing another library;
- declarations, `part`, `part of`, conditional exports, or runtime logic in a
  public API file;
- cross-feature, Core, or API-to-API re-exports;
- direct cross-feature imports that bypass the exact owner API;
- mixed internal and owner-API imports for the same target feature;
- a compatibility file, old-path re-export, facade, duplicate model,
  symlink, fallback import, or temporary second implementation;
- rewriting the historical R0 Mobile baseline;
- weakening, deleting, skipping, or changing behavioral assertions merely to
  make R9 pass;
- changing UI, Arabic/error contracts, API payloads, offline semantics,
  permissions, route decisions, or session behavior.

## Owner Public API Contract

Each feature receives exactly one root public file:

```text
mobile/lib/features/<feature>/<feature>_api.dart
```

The root path distinguishes this owner API from existing internal transport
clients such as `features/finance/data/finance_api.dart`. R9 does not rename
those internal clients merely because their basename is similar.

An owner API contains comments and direct `export` directives only. Every
export:

- resolves to a Dart file inside the same feature directory;
- uses a non-empty explicit `show` list;
- names only symbols required by a verified external consumer;
- is non-conditional;
- is not another `<feature>_api.dart` file.

For example, the target shape is:

```dart
export 'screens/example_screen.dart' show ExampleScreen;
export 'models/example_intent.dart' show ExampleIntent;
```

It is not:

```dart
export 'screens/example_screen.dart';
export '../other_feature/other_feature_api.dart';
```

A cross-area consumer imports one exact owner API per target feature and uses a
non-empty `show` list. If one source needs multiple symbols from the same
feature, one import lists those symbols; multiple parallel owner imports and
mixed internal/API imports are rejected.

Imports within one feature remain direct. R9 does not force a feature to import
its own public API and does not turn the public API into an internal service
locator.

## Scanner And Transitional Baseline Design

The current record key includes the exact target path. Replacing an internal
target with a root owner API therefore removes an old key and creates a new
key. Current baseline comparison would reject that correct migration as an
addition. R9 must fix this contradiction before changing any consumer import.

The historical file
`scripts/architecture/mobile-boundaries-baseline.json` remains byte-identical
at its verified SHA-256. The new governance artifact
`scripts/architecture/r9-mobile-strict-manifest.json` freezes:

- the immutable R9 base;
- the historical baseline SHA-256;
- the 269 live violating-record inventory;
- the separate 34-edge root composition inventory;
- the 19 feature names and exact owner API paths;
- the exact root composition sources `mobile/lib/main.dart` and
  `mobile/lib/app.dart`;
- the exact routing composition source
  `mobile/lib/core/routing/app_router.dart`;
- the plan-approved path fence.

During migration, `--check-baseline` compares only records that remain strict
violations. A legal import redirected to the exact owner API is excluded from
the debt comparison but retained in the legal-edge inventory. A new or
increased internal edge, a non-routing Core import of a feature API, an
unapproved root importer, or any malformed public API still fails.

The scanner must preserve directive metadata instead of discarding it:

- directive kind: `import`, `export`, `part`, or `part of`;
- resolved source and target;
- `show` and `hide` combinators;
- conditional-directive status;
- source and target ownership areas.

Public-API structural violations and invalid cross-area exports are immediate
errors in baseline and strict modes. They are never accepted as counted debt.

Required adversarial scanner proofs include:

- internal import changed to an exact owner API is accepted as debt reduction;
- a new or increased internal cross-feature edge is rejected;
- a non-routing Core import of a feature API is rejected;
- an API without a non-empty `show` export is rejected;
- an API import, declaration, `part`, conditional export, `hide`, cross-owner
  export, and API-to-API export are each rejected;
- a cross-area consumer import without `show` is rejected;
- mixed internal/API imports and multiple API directives to one target owner
  are rejected;
- legal `main.dart`, `app.dart`, and `app_router.dart` imports of exact owner
  APIs are accepted;
- any other root or `core/routing` source importing a feature is rejected;
- final zero strict violations permits the CI transition.

## Composition Roots

R9 recognizes exactly three source files that compose features:

| Source | Responsibility | Strict permission |
| --- | --- | --- |
| `mobile/lib/main.dart` | dependency/provider construction | import exact owner APIs with `show` |
| `mobile/lib/app.dart` | application/session shell composition | import exact owner APIs with `show` |
| `mobile/lib/core/routing/app_router.dart` | route assembly | import exact owner APIs with `show` |

The routing exception applies only to `app_router.dart`, not every future file
under `core/routing/**`.

The router's reviewed public surface may include screens, route argument/result
types, route-access guards, and narrowly required providers used for DI lookup.
R9 does not require route-factory extraction or a rewrite of the existing
`GoRouter` tree; that would expand behavior risk without being required by the
strict contract.

Root composition files may import feature public APIs but may not export them.
Any new root Dart file that imports a feature is a strict violation.

## Neutral Session Principal

`SafeUser` is already serialized and restored by Core secure storage and is
cached by the Core offline layer. It is therefore the canonical persisted
session-principal snapshot, not an Auth-screen implementation detail.

R9 moves the existing class unchanged from:

```text
mobile/lib/features/auth/models/safe_user.dart
```

to:

```text
mobile/lib/core/session/safe_user.dart
```

The old file is deleted in the same reviewed change. No re-export, duplicate,
alias, or map-based replacement remains.

The move freezes:

- field names and types;
- `fromJson` and `toJson` keys;
- missing-field defaults;
- date parsing/serialization behavior;
- verification, provider, and account-role projections;
- secure-storage compatibility with sessions written before R9;
- offline cached-user serialization.

All consumers update imports mechanically. Product behavior and serialized
bytes are not deliberately changed.

## Push Identity Projection

`AarastPushLifecycleBridge` currently reads `AuthController` only to derive an
authenticated user ID. An interface would preserve an unnecessary lifecycle
dependency, while a callback could observe changing provider state at an
uncontrolled time.

R9 changes the bridge input to immutable composition data:

```dart
const AarastPushLifecycleBridge({
  required this.router,
  required this.authenticatedUserId,
  required this.child,
  super.key,
});

final String? authenticatedUserId;
```

`app.dart` computes the value at composition time:

```dart
auth.status == AuthStatus.authenticated ? auth.user?.id : null
```

The bridge retains its existing bind/unbind, permission request, pending-open,
one-time notification navigation, resume refresh, foreground notification, and
disposal behavior. It no longer imports Auth state.

Required transition behavior is exact:

- checking or unauthenticated state projects `null`;
- checking to authenticated binds once to the user ID;
- authenticated to terminating/unauthenticated projects `null` and unbinds;
- user A to user B replaces the binding once;
- a notification tap received before authentication stays pending;
- after authentication, a claimed pending tap navigates once to the inbox;
- app resume refresh remains unchanged.

## Migration Strategy

All 19 owner APIs are created and structurally validated before any consumer is
migrated. This prevents a consumer batch from depending on an API that does not
exist and avoids falsely treating the 14-feature strongly connected component
as a topological hierarchy.

Consumer migration proceeds in reviewed source batches:

1. Core session and Push boundary correction.
2. Identity/context consumer sources: `auth`, `account_contexts`, `onboarding`,
   and `catalogs`.
3. Collaboration/provider consumer sources: `chat`, `sharing`, `marketplace`,
   `notifications`, `settings`, `support`, and `more`.
4. Planning/operations consumer sources: `wedding_plans`, `finance`, `tasks`,
   `guests`, and `wedding_day`.
5. Shell/entry consumer sources: `home`, `shell`, and `welcome_gateway`.
6. Composition sources: `main.dart`, `app.dart`, then `app_router.dart`.

These are consumer-source batches, not dependency layers. Within a batch, each
source-to-target-feature relationship moves atomically: add the reviewed symbol
to the owner API if needed, replace all internal imports from that source to the
same target feature with one owner-API import, run focused gates, and confirm no
mixed edge remains.

Every batch must reduce strict debt monotonically. A batch may retain legal
public edges; it may not increase strict violations, modify the historical
baseline, or weaken the scanner.

## Data And Behavior Preservation

R9 changes library visibility, not application data flow:

- Backend responses still enter the same data clients and repositories;
- providers retain their existing object identity and lifecycle;
- secure tokens and session snapshots remain in the same storage namespaces;
- SQLCipher tables, offline queues, cache ownership, retry rules, and data
  isolation remain unchanged;
- route paths, route extras, guards, redirects, selected context, and shell
  behavior remain unchanged;
- Socket.IO, notification inbox, Push registration, and message behavior remain
  unchanged;
- Arabic labels, errors, empty/loading/offline states, and RTL behavior remain
  unchanged.

No API, Prisma, migration, seed, Backend, Admin, Docker, Compose, Dokploy, or
deployment file is part of the application migration.

## Failure And Stop Rules

Stop the active batch and diagnose the earliest incorrect boundary when:

- scanner tests fail;
- historical baseline hash changes;
- transitional debt increases or a new key appears;
- an owner API requires a cross-feature re-export;
- the analyzer exposes an ambiguous, duplicate, or hidden symbol;
- moving `SafeUser` changes serialized output or legacy restore behavior;
- Push binds, unbinds, or navigates more than once for one state transition;
- route construction, route-extra typing, provider lookup, or auth/context
  restoration changes;
- a behavioral test requires a non-mechanical assertion or fixture change;
- a protected Backend/Admin/database/deployment path changes;
- the phone journey cannot reproduce the accepted session or routing behavior.

Do not add a fallback import, compatibility layer, duplicate type, optional
service locator, or silent error suppression after a stop signal.

## Verification Contract

### Governance checkpoint

- scanner unit/adversarial tests pass;
- existing 269 and new 34 inventories match the immutable base;
- historical baseline SHA-256 matches exactly;
- R9 manifest and scope fence are deterministic and repository-relative;
- `--check-baseline` passes with no consumer migration;
- `--strict` still fails for the verified starting debt.

### Per-batch checkpoint

- scanner tests pass;
- transitional baseline/debt check passes and strict debt decreases;
- no mixed internal/API or duplicate owner import remains in the batch;
- `flutter analyze --no-pub` passes;
- focused tests for every touched behavior pass;
- formatting, diff, scope, protected-surface, and secret scans pass;
- independent source/requirements review approves the checkpoint before the
  next batch.

### Final static and behavioral checkpoint

- scanner tests pass;
- `--check-baseline` passes;
- `--strict` passes with `strictViolations = 0`;
- the final receipt records the actual legal public-edge inventory separately;
- historical baseline hash remains exact;
- every one of the 19 owner APIs passes structural governance;
- only the three exact composition roots import feature APIs from outside a
  feature;
- full `flutter analyze --no-pub` passes;
- full `flutter test --no-pub` passes, including Windows golden coverage;
- focused session/storage/offline/push/routing tests pass;
- Android APK build passes;
- repository architecture, documentation, diff, protected-surface, and secret
  gates pass;
- Backend/Admin/application contracts remain unchanged and their proportional
  regression gates pass;
- independent exhaustive review finds no unresolved Critical or Important
  issue.

CI changes from:

```text
node ../scripts/check-mobile-boundaries.mjs --check-baseline
```

to:

```text
node ../scripts/check-mobile-boundaries.mjs --strict
```

only after the same application candidate already passes the final strict
checkpoint. The historical baseline and check mode remain local historical and
diagnostic evidence; CI no longer accepts legacy Mobile boundary debt.

## Phone And Runtime Acceptance

R9 uses the owner-authorized non-S10 phone identified as `26`. Directed ADB
interaction must target only that device after a read-only uniqueness/model
assertion. Device serials, phone numbers, tokens, OTPs, user data, and raw
message/task contents are never printed or retained in reports.

The R9 QA APK must preserve the accepted package/signing lineage and existing
application data. Do not uninstall the accepted app or clear its data before
the upgrade journey. Preserve the prior accepted APK as local rollback.

The phone journey verifies:

- upgrade with data preserved;
- authenticated session and account-context restoration;
- dashboard and routed feature entry;
- online force-stop/reopen;
- offline force-stop/reopen and truthful offline state;
- route-extra journeys used by task, finance, marketplace, sharing, and wedding
  planning screens;
- logout/relogin isolation with no previous-account data exposure;
- Push registration on authentication and unregistration on logout;
- pending notification tap opens the notifications inbox once after auth;
- no fatal, connection, routing, overflow, provider, or storage marker.

If the local environment cannot deliver a real Firebase Push notification,
that exact live-Push step is reported as unverified. Unit/widget transition
coverage and ordinary notification-inbox behavior do not get relabeled as a
successful live-Push test.

The accepted R8 Backend remains the server runtime for R9 Mobile QA. R9 does
not claim a new Backend image or deployment.

## Documentation And Git Discipline

The implementation plan must enumerate exact files per task, exact focused
tests, allowed path fences, review gates, and local commit messages before code
work begins.

R9 uses local reviewed checkpoints on the existing `modular-monolith` branch.
No branch, worktree, push, merge, PR mutation, production deployment, remote CI,
store release, or R10 work is authorized by this design.

Historical R0-R8 plans, completion receipts, baselines, and assertions remain
historical evidence. Active architecture, Mobile, QA, status, execution,
decision, and changelog documents are updated only at R9 closeout with observed
results.

## Rejected Alternatives

### Broad compatibility barrels

Rejected. Bare exports could make the current strict filename check pass while
exposing internals and preserving feature coupling. This is the scanner-passing
patch R9 exists to prevent.

### Keep baseline comparison unchanged until final cutover

Rejected. The first correct target-path change becomes a new baseline key and
fails CI. Transitional semantics must be corrected before consumer migration.

### Migrate one target feature at a time

Rejected. Fourteen features participate in one strongly connected component.
All owner APIs must exist first; subsequent waves are consumer-source batches.

### Split Mobile into independent Dart packages

Rejected for R9. Package isolation could be a later decision, but it introduces
dependency, build, testing, and source-relocation work beyond the existing
strict contract.

### Inject an Auth interface or callback into Push

Rejected. Push requires one immutable nullable user ID, not Auth lifecycle
behavior. Passing data removes the dependency with less abstraction and fewer
timing hazards.

### Extract route factories during boundary migration

Rejected. The accepted contract permits the exact router composition root to
consume reviewed route-facing public symbols. Rebuilding the route tree would
add behavior risk without being required for strict completion.

## Risks And Controls

| Risk | Control |
| --- | --- |
| Broad APIs recreate hidden coupling | mandatory non-empty `show`, same-owner exports, scanner adversarial tests |
| Transitional gate blocks correct work | strict-violation-only debt comparison before first consumer migration |
| New root file bypasses scanner | record all root-to-feature directives; allowlist only `main.dart` and `app.dart` |
| Router exception expands silently | allowlist exact `app_router.dart`, not the directory |
| Cached sessions become unreadable | unchanged `SafeUser` codec plus legacy secure-storage round-trip tests |
| Push races or duplicate navigation | immutable authenticated-user-ID projection plus transition tests |
| Cyclic graph makes a wave incomplete | create all 19 APIs first; migrate by source-to-target relationship |
| Import consolidation creates name collisions | explicit consumer `show` lists plus analyzer at every batch |
| Compilation passes while behavior drifts | focused and full Flutter tests plus real-phone journey |
| Live Push is unavailable locally | report the step unverified; do not infer success |
| Scope grows into product/refactor work | hash-bound design/plan, exact path fence, per-task independent review |

## Definition Of Done

R9 is locally complete only when all of the following are true:

1. The historical Mobile baseline is byte-identical at its frozen SHA-256.
2. The live 269-debt and 34-root inventories are traceable from the immutable
   R9 base.
3. All 19 root owner APIs satisfy the enforced minimal export contract.
4. `SafeUser` has one unchanged implementation under `core/session`; the old
   Auth path is absent.
5. Push imports no Auth feature and receives only nullable authenticated user
   identity from composition.
6. No direct cross-feature internal import remains.
7. No non-composition Core or unapproved root import of a feature remains.
8. The exact three composition roots import only exact owner APIs with
   non-empty `show` lists.
9. Strict mode passes with zero violations and the actual legal public-edge
   inventory is recorded truthfully.
10. CI uses strict mode only after the final candidate passed it locally.
11. All static, test, build, scope, documentation, protected-surface, secret,
    independent-review, runtime, and phone gates pass or an explicitly
    non-substitutable live-Push step is labeled unverified.
12. Git closes at a reviewed local R9 completion checkpoint and stops before
    push, merge, deployment, remote CI, store release, or R10.

## Independent Design Review Receipt

An independent read-only reviewer validated the live counts, scanner behavior,
composition imports, session/storage ownership, Push data need, feature graph,
tests, and clean Git state at the immutable base. The initial direction was
`APPROVE WITH CHANGES`. This design incorporates every Critical and Important
correction:

- transitional baseline semantics precede consumer migration;
- owner API structure and combinators are governed;
- the omitted 34 root composition imports are frozen and migrated;
- all 19 APIs precede source-oriented migration batches;
- routing is allowlisted to one exact source;
- Push receives immutable nullable identity rather than Auth behavior;
- persisted `SafeUser` semantics are frozen explicitly;
- final receipts distinguish legal records from strict violations.

No application or Git file was modified by the reviewer.

Stop: do not write the implementation plan until the owner reviews this
committed design. Do not implement R9, push, merge, deploy, run remote CI, or
begin R10.
