# Modular Monolith R8 Global Module Removal Design

Date: 2026-08-27

Status: Owner-approved design sections; pending document review and implementation plan

Branch: `modular-monolith`

Immutable R8 base: `c2b728bfe54304562923facfb6094e0de04c0b27`

## Objective

Remove the final two project-owned Nest `@Global()` declarations from the
Backend and make every affected provider dependency explicit without changing
product behavior. The final application has zero project-owned global modules,
one `PrismaService` instance, one `ConversationRealtimePublisher` instance,
the existing Messaging public port identity, and the same routes, data,
errors, transactions, events, and runtime behavior.

R8 is an explicit Nest-composition phase. It is not a service decomposition,
source relocation, new public-port, database, client, or deployment phase.

## Verified Starting State

The R7 closeout is clean at
`c2b728bfe54304562923facfb6094e0de04c0b27`. The accepted R7 application
candidate is `aafb47ea1742c278f6a5ed24799ada7bc23721b0`; its stopped R6 predecessor
remains the older rollback artifact. R8 does not inherit any unrerun pass from
either candidate.

The existing architecture scanner counts exactly two project-owned global
modules under `backend/src`:

| Module | Provider | Current global path |
| --- | --- | --- |
| `PrismaModule` | `PrismaService` | `backend/src/platform/database/prisma.module.ts` |
| `ConversationRealtimeModule` | `ConversationRealtimePublisher` | `backend/src/conversations/conversation-realtime.module.ts` |

Two existing pinned dependencies also provide global Nest behavior outside
project-owned source and are frozen external runtime contracts:

| Package | Locked version | Current application call | Dependency-owned global mechanism |
| --- | --- | --- | --- |
| `@nestjs/schedule` | `6.1.3` | `ScheduleModule.forRoot()` | returned `DynamicModule.global: true` |
| `@nestjs/throttler` | `6.5.0` | `ThrottlerModule.forRootAsync(...)` | package module decorated with Nest `Global` |

Their exact `package.json` declarations and `package-lock.json` package entries
are unchanged by R8. The lock entries pin version, resolved tarball, and SHA-512
integrity. R8 removes project-owned implicit visibility; it does not fork,
replace, or alter Scheduler or request-throttling behavior.

`PrismaModule` already has 20 direct module importers. They cover the App
composition root, Platform Outbox core, and the current Backoffice, Catalog,
Collaboration, Finance, Guests, Identity, Insights, Marketplace, Media,
Messaging, Notifications, Planning, and Tasks provider owners.

One verified direct DI consumer still relies on Prisma's global visibility:
`ApplicationOutboxRuntimeModule` registers `OutboxWorker`, whose constructor
injects `PrismaService`. Its only database-related import is
`OutboxCoreModule`; it does not directly import `PrismaModule`.
`OutboxCoreModule` imports Prisma for its own providers and exports only
`OutboxService`; it is not an approved database-provider proxy. R8 must add the
missing direct import at the real owning module.

Realtime composition is already structurally explicit:

| Importer | Reason |
| --- | --- |
| `MessagingConversationsInternalModule` | owns `ConversationsService` and `ConversationsGateway`, which inject the concrete publisher |
| `MessagingRealtimeInternalModule` | binds `MESSAGING_REALTIME_IMPLEMENTATION` to the publisher with `useExisting` |

`MessagingRealtimePublicModule` then binds `MESSAGING_REALTIME_PORT` to that
implementation token with `useExisting`. Cross-context consumers use the
public Symbol port and must not begin importing the concrete publisher.

The current architecture gates intentionally require exactly two globals:
the phase-neutral ports scanner, the R3 scanner, the R7 scanner, and their
focused tests. The R1 layout and R3 composition tests also pin the old global
source shapes. Those live assertions must move to the R8 zero-global contract
through an exact, reviewed handoff; historical completion documents remain
immutable.

## Root-Cause Standard

R8 fixes implicit container visibility at the module boundary where each
consumer is registered. Completion requires:

- zero Nest `Global` decorator applications anywhere under `backend/src`;
- zero project-owned `DynamicModule` returns that activate `global: true`;
- zero source-supplied external module-factory options that activate
  `global: true` or `isGlobal: true`;
- no import or alias of Nest `Global` in either former global module;
- every module registering a direct `PrismaService` consumer imports
  `PrismaModule` itself;
- both direct concrete realtime owner modules import
  `ConversationRealtimeModule` themselves;
- `PrismaService` remains registered and exported only by `PrismaModule`;
- `ConversationRealtimePublisher` remains registered and exported only by
  `ConversationRealtimeModule`;
- repeated imports resolve to one provider instance per application context;
- the Messaging implementation token and public port resolve to the exact same
  publisher instance;
- all prior cycle, `forwardRef()`, boundary, dependency, and ownership gates
  remain green.

R8 forbids:

- a replacement global module or decorator alias;
- a central aggregation module that re-exports Prisma or Realtime as a proxy;
- duplicate provider registration, `useClass`, factory, value, subclass, or
  wrapper registrations for either provider;
- fallback injection, optional injection, default constructor values, service
  locators, or manual `new` construction added to survive a missing import;
- new public ports or changes to existing Symbol identities;
- compatibility layers that preserve both implicit and explicit composition;
- count-only acceptance that does not prove the dependency closure;
- blind updates of historical assertions or architecture baselines;
- deleting, skipping, weakening, or rewriting a behavioral test to make R8
  pass.

## Chosen Architecture

Keep both existing modules as ordinary exported Nest modules:

```typescript
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

```typescript
@Module({
  providers: [ConversationRealtimePublisher],
  exports: [ConversationRealtimePublisher],
})
export class ConversationRealtimeModule {}
```

Only the `Global` named import and `@Global()` decorator are removed. Provider,
export, class, token, and file identities remain unchanged.

Each module that owns a direct consumer imports the ordinary provider module.
R8 adds exactly one currently missing application import:

```text
ApplicationOutboxRuntimeModule
  -> PrismaModule
  -> PrismaService
  -> OutboxWorker
```

The existing 20 direct Prisma importers remain explicit. No importer is removed
merely because another imported module also imports Prisma. This avoids
transitive DI assumptions and makes future missing-import failures local and
diagnosable.

Realtime remains:

```text
MessagingConversationsInternalModule -> ConversationRealtimeModule
MessagingRealtimeInternalModule      -> ConversationRealtimeModule
                                      -> useExisting publisher
MessagingRealtimePublicModule        -> useExisting implementation token
cross-context consumers              -> MESSAGING_REALTIME_PORT
```

Nest caches the same static module token within an application graph, so
repeated imports of either ordinary module must resolve to one provider
instance. R8 treats that as a tested invariant rather than an assumption.

## Explicit Prisma Import Closure

At strict R8, the direct Prisma import set is the following 21 consumer modules:

1. `backend/src/app.module.ts`
2. `backend/src/application-composition/application-outbox-runtime.module.ts`
3. `backend/src/modules/backoffice/internal/backoffice-services.internal.module.ts`
4. `backend/src/modules/catalog/internal/catalog-services.internal.module.ts`
5. `backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts`
6. `backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts`
7. `backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts`
8. `backend/src/modules/finance/internal/finance-services.internal.module.ts`
9. `backend/src/modules/guests/internal/guests-service.internal.module.ts`
10. `backend/src/modules/identity/internal/identity-auth.internal.module.ts`
11. `backend/src/modules/identity/internal/identity-profile.internal.module.ts`
12. `backend/src/modules/insights/internal/insights-services.internal.module.ts`
13. `backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts`
14. `backend/src/modules/media/internal/media-storage.internal.module.ts`
15. `backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts`
16. `backend/src/modules/notifications/internal/notifications-service.internal.module.ts`
17. `backend/src/modules/notifications/internal/push-installations.internal.module.ts`
18. `backend/src/modules/notifications/internal/push-transport.internal.module.ts`
19. `backend/src/modules/planning/internal/planning-services.internal.module.ts`
20. `backend/src/modules/tasks/internal/tasks-service.internal.module.ts`
21. `backend/src/platform/outbox/outbox-core.module.ts`

This inventory is not a permanent hand-maintained allowlist for arbitrary
future consumers. The R8 scanner derives direct constructor/factory injection
and owning-module registration from the TypeScript AST, then proves the direct
module import. The manifest pins the current expected closure so an addition,
deletion, reassignment, unresolved owner, or hidden transitive dependency is a
reviewable architecture change rather than silent drift.

Pure helper functions that accept `PrismaService` as a caller-supplied
parameter are not Nest DI consumers and do not create a module import
requirement. The scanner must distinguish them from registered providers,
controllers, schedulers, interceptors, gateways, and provider factories.

## Permanent R8 Contract

R8 adds:

- `backend/architecture/r8-global-module-removal.json`;
- `backend/scripts/architecture/r8-global-module-removal-scan.cjs`;
- `backend/test/architecture-r8-global-module-removal.test.ts`;
- an `architecture:r8` package script included in aggregate `architecture`.

The manifest binds the immutable base, stage, exact former-global modules,
provider identities, strict Prisma and Realtime importer inventories, exact
`useExisting` chain, allowed R8 change surface, protected surfaces, frozen R7
dependency/ownership counts, the exact R3 scope/inventory projections, and the
two frozen external-global dependency identities. Each external identity pins
the package name, declared range, locked version, resolved tarball, integrity,
imported class, factory call, application source path, and dependency-owned
global mechanism.

The scanner uses the TypeScript compiler AST and module resolution. It must
reject at minimum:

- direct, aliased, namespace, re-exported, computed, or cross-file Nest
  `Global` decorator bindings;
- project-owned Nest `DynamicModule` metadata whose `global` property resolves
  to `true`, including local aliases, object spreads, computed property names,
  and cross-file re-exports;
- project source that supplies `global: true` or `isGlobal: true` to an
  external module-factory call, including aliases, spreads, computed keys, and
  calls such as `JwtModule.registerAsync({ global: true })`;
- unresolved spread/computed metadata in a project-owned `DynamicModule`
  return or a source-supplied external module-factory option object when the
  scanner cannot prove that global activation is absent;
- drift in either exact frozen Schedule/Throttler package-lock identity or its
  exact current application import/factory-call identity;
- a new dependency-owned global exception or a generic `node_modules`
  exemption;
- a missing explicit provider-module import for a registered direct consumer;
- a transitive-only, unresolved, non-relative, wrong-package, shadowed, or
  same-name decoy import;
- duplicate provider/controller ownership or duplicate provider registration;
- `useClass`, `useFactory`, `useValue`, manual construction, or a new token
  lookalike replacing either exact provider identity;
- broken, duplicated, or redirected Realtime `useExisting` bindings;
- a new cross-context concrete Realtime import;
- source traversal, symlink, junction, reparse-point, or out-of-repository
  manifest paths;
- new cycles, `forwardRef()`, baseline increases, or protected-surface drift.

The semantic global check resolves a project-owned Nest `DynamicModule` type
from the real `@nestjs/common` package rather than trusting a same-name local
interface. Its finite evaluator accepts only statically provable
local/cross-file constants, aliases, spreads, and computed keys. An unresolved
project-owned candidate or source-supplied external option fails closed; it
does not become an implicit allowlist.

Dependency internals are not treated as project-owned source. The two existing
external behaviors pass only through exact manifest and lock evidence:
`@nestjs/schedule@6.1.3` at `ScheduleModule.forRoot()` and
`@nestjs/throttler@6.5.0` at `ThrottlerModule.forRootAsync(...)`. Tests must
prove these two current calls pass, a changed package/lock/call fails, a new
explicit external `global: true` or `isGlobal: true` fails, and an unresolved
project-owned DynamicModule or explicit external option fails closed. This is
not permission for an arbitrary dependency global.

The scanner has a design stage that proves the approved future change surface
while the immutable base still has two project-owned globals, and a strict
stage that accepts only zero project-owned globals and the final explicit
closure. The design stage is removed from live acceptance when implementation
reaches strict; it is not a runtime compatibility mode.

## R3 Scope Delegation

The design-document commit is a pre-governance documentation checkpoint and
does not claim the complete Backend test gate. At that commit, the existing R3
scope test truthfully rejects the new R8 path. The first R8 governance
checkpoint must restore the focused R3 scope suite to green before any
production-source edit.

`backend/scripts/architecture/r3-scope.cjs` must load and validate the R8
manifest exactly as the later-phase R5-R7 delegations are validated. Delegation
is accepted only when all of these match:

- fixed base `c2b728bfe54304562923facfb6094e0de04c0b27`;
- the canonical repository-relative R8 manifest path;
- a sorted, unique, traversal-safe `allowedChangedPaths` array;
- exact SHA-256 evidence for the approved design and plan documents;
- exact design-stage governance paths;
- exact strict-stage production, active-gate, package-script, active-receipt,
  and generated-document paths;
- a stage value whose permitted paths are a subset of the final R8 fence.

The R8 scope fence includes only the approved design/plan, new R8
manifest/scanner/test, the exact two former-global module sources, the Outbox
runtime module, package scripts/generated script reference, the exact R1/R3/R7
live gate and scope-handoff files, and active R8 receipt documents. The
manifest contains the concrete path list; generic directories, globs, arbitrary
future tests, archived documents, Mobile, Admin, schema, migrations,
dependency/ownership baselines, workflows, Docker, Compose, and deployment
paths are forbidden.

Focused R3 scope tests must prove the exact R8 delegation passes and reject an
incorrect base, manifest path, document hash, stage, missing path, extra path,
duplicate, traversal, absolute path, reparse escape, and high-similarity
near-miss. Only after those tests pass may R8 change production source.

## R3 Live-Inventory Projection

`backend/architecture/r3-context-boundaries.json` remains the immutable R3
inventory and is not rewritten to pretend R3 originally had zero globals. At
strict R8 only, `r3-context-scan.cjs` validates the R8 manifest and applies one
finite projection to a copy of the historical inventory before comparing it
with live source:

1. set `PrismaModule.global` from `true` to `false`;
2. set `ConversationRealtimeModule.global` from `true` to `false`;
3. add `PrismaModule` to the sorted import inventory of
   `ApplicationOutboxRuntimeModule`.

No other module path, class, import, controller, provider, export, lifecycle,
token, or metadata field may change through this projection. R3 continues to
own and compare the full live inventory after those exact three transforms.
R8 does not replace R3 with a count-only check.

The R3 scanner rejects a projection unless the historical before-values match
exactly, the R8 base/stage/hashes are valid, and the resulting three fields
match strict live source. Focused fixtures must prove both global-flag
transitions and the Outbox import, plus reject a wrong module, wrong prior
value, extra import, missing import, unsorted imports, changed provider/export,
or any fourth projection.

## Historical Gate Handoff And Test-Change Law

Historical R0-R7 documents remain unchanged. The R3 inventory manifest also
remains immutable. Live architecture code and tests that assert the active
source must move from two globals to zero through the validated R8 scope and
inventory projections. Exact expected changes are limited to:

- ports scanner global policy and focused tests;
- R1 Prisma module source-shape/lifecycle assertion;
- R3 live global-count and Realtime module source-shape assertions;
- R7 strict live global-count assertions;
- R3 scope delegation and focused delegation/projection tests;
- scope hashes or exact protected-path lists mechanically affected by those
  files;
- the new R8 scanner, manifest, tests, and package script.

No behavioral assertion, expected response, Arabic/error text, fixture
semantics, timeout, skip, cleanup order, test selection, route inventory,
provider token, or ownership/dependency baseline may change.

The R1 lifecycle assertion continues proving `$connect()` on module init and
`$disconnect()` on module destroy. The R3 composition assertion continues
proving that both Messaging aliases use `useExisting` and resolve to the exact
publisher instance; it changes only the former module's non-global source
shape. R7 continues proving its relocation contract while delegating only the
exact live global-state handoff to R8.

## Runtime And Data-Flow Invariants

The runtime flow remains:

1. the same controller, gateway, scheduler, worker, or interceptor is created;
2. Nest resolves the same exported provider from an explicitly imported
   ordinary module;
3. the same singleton instance performs the call;
4. the same Prisma query/transaction or realtime publication executes;
5. the same result, event, error, metric, and privacy-safe log propagates.

R8 freezes:

- all HTTP and WebSocket routes, guards, DTOs, validation, payloads, status
  codes, response ordering, and event names;
- authentication, OTP, session, context, permission, privacy, and Arabic/error
  contracts;
- transaction boundaries, isolation levels, locks, retries, idempotency,
  scheduler timing, Outbox attempt policy, and event ordering;
- Prisma lifecycle and database connection count per application context;
- Realtime publisher, implementation token, public token, gateway, and socket
  behavior;
- dependency baseline 22 and ownership 385 records / 781 occurrences;
- Prisma 52 models, 41 enums, 76 migrations, seed, and generated semantics;
- Mobile, Admin Web, workflows, Docker, Compose, Dokploy, domains, ports, and
  production configuration.

Missing explicit imports fail closed in the R8 scanner and focused Nest
composition test. R8 does not catch the failure and continue through a fallback
provider.

## Staged Execution Model

Implementation uses reviewed local checkpoints on the same branch:

1. commit the approved design and implementation plan from the immutable R7
   closeout; these pre-governance documentation commits run documentation
   guards and do not claim the complete Backend test gate;
2. add the exact R3 scope delegation plus the R8 manifest/scanner/tests in
   design stage, prove adversarial RED cases without changing production
   source, and require the complete focused R3 scope suite to return green;
3. atomically remove both global decorators, add the one missing Outbox runtime
   Prisma import, apply the exact three-field R3 live-inventory projection,
   move the live cumulative gates to zero, and promote R8 to strict;
4. prove provider singleton identity, exact Realtime `useExisting` identity,
   explicit-import closure, zero project-owned globals, exact frozen external
   identities, zero cycles, and zero `forwardRef()`;
5. run focused and exhaustive candidate verification plus independent review,
   correcting only proved root causes inside the approved scope;
6. build and probe one immutable local image, cut over locally while preserving
   R7 as rollback, and exercise the physical-phone gate;
7. write exact completion receipts, run final gates, create a docs-only local
   closeout checkpoint, and stop before R9.

The production-source transition is atomic because an intermediate one-global
state has no accepted architectural meaning. The R8 design test may model RED
fixtures, but no committed runtime checkpoint may preserve one global, a
transitive fallback, or duplicate providers.

## Verification And Acceptance

The exact R8 candidate must pass:

- R8 zero-global, explicit-import, provider-registration, singleton, and token
  identity tests;
- full R1-R8 architecture, dependency, ownership, ports, and Nest graph gates;
- Backend TypeScript check, clean build, and complete test suite;
- Prisma 6.19.3 validate/generate, 52-model/41-enum fingerprint, and
  DMMF/migration no-difference equivalence;
- full and production-only npm audits with zero qualifying findings;
- focused health, auth/session, Outbox, Messaging/Realtime, notifications,
  sharing, tasks, and context-transition managed smokes;
- all 30 aggregate `smoke:all` packages;
- documentation sync/verify, protected-surface diff, whitespace, artifact, and
  managed-residue checks;
- independent exact-diff, architecture, runtime, and receipt review with no
  unresolved Critical or Important finding.

No pass result is inherited from R7 after an R8 source edit. Every claimed gate
is rerun on the exact immutable R8 application candidate.

## Immutable Runtime And Phone Gate

Package the exact committed application candidate into a new immutable local
Backend image carrying the full revision. Before cutover, an isolated loopback
probe must pass migration discovery, dependency audit, `/live`, `/ready`,
restart/OOM state, and sanitized fatal/secret-marker checks. Remove the probe
after acceptance.

Protected local cutover reuses accepted configuration without printing or
persisting secrets. The R8 candidate must pass local and LAN `/live` and
`/ready`, required database/Redis/media readiness, zero restarts, no OOM, and
sanitized logs. Stop but preserve R7 as rollback; do not delete or overwrite it.

The phone gate exercises only existing product paths:

1. login or restored authenticated session and current context;
2. dashboard read;
3. one local synthetic Prisma-backed task create/update/read/delete journey;
4. an existing quote-scoped conversation and realtime message/read journey
   when such a conversation is available; absence of a routed eligible
   conversation is reported truthfully and does not authorize open messaging;
5. full force-close and reopen;
6. restored session, context, dashboard, and persisted post-cleanup state.

Existing local OTP behavior may be used, but no OTP, phone number, token,
credential, raw request body, message text, or business value is retained in
the receipts. Physical-phone acceptance complements, and does not replace,
the deterministic Realtime composition and managed smoke gates.

## Non-Goals And Frozen Surfaces

R8 does not:

- move, split, rewrite, optimize, or rename a service or module;
- add a public port, repository, facade, event, route, or product feature;
- change Prisma schema, migrations, seed, data, ownership, or generated client;
- change package versions, dependencies, or `package-lock.json`;
- edit Mobile, Admin Web, workflows, Dockerfiles, Compose, Dokploy, deployment,
  domains, ports, production secrets, or remote infrastructure;
- activate R9 Mobile strict mode or begin later modular-monolith work;
- push, merge, mutate PR #76, deploy, or claim remote CI.

## Rejected Alternatives

- **Keep Prisma global and remove only Realtime:** rejected because R8's fixed
  architectural objective is zero project-owned implicit global visibility for
  these provider modules.
- **Central database/realtime aggregation module:** rejected because it hides
  the same transitive dependency behind another composition proxy.
- **Re-export Prisma from every internal module:** rejected because consumers
  would again depend on accidental transitive visibility.
- **Register the providers in every consumer module:** rejected because it
  creates multiple lifecycle instances and can duplicate database connections
  or realtime delivery.
- **Introduce new public ports for Prisma or the concrete publisher:** rejected
  as an unrelated abstraction and broader boundary change. Cross-context
  Realtime already has the correct public port; Prisma is Platform
  infrastructure imported explicitly.
- **Use optional injection or a fallback factory:** rejected as a silent
  compatibility patch that hides missing composition.
- **Change counts from two to zero without dependency-closure tests:** rejected
  because a green count cannot prove the application still resolves providers
  correctly.
- **Combine R8 with service decomposition, source relocation, R9, or
  deployment:** rejected because those changes have separate risks and gates.

## Completion Boundary

R8 is locally complete only when `backend/src` has zero project-owned
`@Global()` declarations or global DynamicModule activation, all direct
consumers have explicit owner-module imports, both frozen external identities
are unchanged, both provider singletons and the Realtime `useExisting` chain
are proved, every focused/full/smoke/runtime/phone gate passes on one immutable
candidate, independent review is approved, exact receipts are committed
locally, and the worktree is clean.

No push, merge, PR mutation, deployment, remote CI, store release, or R9 start
is implied by local R8 completion.
