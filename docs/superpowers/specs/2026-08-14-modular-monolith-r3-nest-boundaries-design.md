# Modular Monolith R3 Nest Boundaries Design

**Status:** Approved for staged local execution after independent review

**Date:** 2026-08-14

**Immutable planning base:**
`6b06eb096aca8cc6684d365d16e05d4cd8529898`

**Execution branch:** `modular-monolith`

## Objective

R3 replaces the legacy Nest composition graph with explicit bounded-context
composition and demand-driven public provider contracts. It removes the six
frozen platform-to-business dependencies without changing application behavior,
routes, payloads, errors, permissions, transactions, schedules, schema,
migrations, Admin Web, or deployment topology. The sole Mobile exception is the
physical-device session-restore race discovered at the final phone gate: an
account-context generation change must not invalidate a successful
`GET /api/v1/auth/me` response. The correction is limited to
`mobile/lib/core/network/api_client.dart` and its focused regression test.

R3 is complete only when:

- `AppModule` composes the 13 exhaustive business contexts through one full
  module per context;
- every cross-context provider dependency covered by an R3 contract injects a
  public Symbol token and public type rather than a concrete foreign class;
- each public token resolves to the exact single legacy implementation instance;
- provider ownership is unique and the Nest module graph is acyclic with zero
  `forwardRef()` calls;
- the six frozen platform-to-business dependency records and the exact
  manifest-listed legacy provider-debt records retired by R3 are absent from
  source and the dependency baseline;
- the current two approved `@Global()` declarations remain exactly unchanged
  until R8;
- all local automated, managed-runtime, independent-review, and owner phone
  checkpoints pass on immutable local commits.

## Source-of-Truth Corrections

R0 and R1 describe the `InternalModule` + `PublicModule` + full-module pattern,
but the live graph requires these R3 clarifications:

1. R3 does **not** create hollow public tokens for all 13 contexts. It creates
   full context composition for all 13 contexts and only the public provider
   contracts that have a real current consumer. Later R4-R8 work adds new
   owner read/write ports when those phases need them.
2. One coarse internal module per context is unsafe. The live graph has
   reciprocal provider use between identity and collaboration and between
   collaboration and notifications. Public aliases therefore bind to small
   provider-leaf internal modules whose dependency graphs remain acyclic.
3. A provider alias registered in `AppModule` is not visible to a provider
   owned by an imported child module. Composition-owned aliases and the
   providers that consume them must be registered in the same composition
   module.
4. The current graph registers `PermissionService` twice and registers both
   `AdminGuard` and `AdminPermissionGuard` twice in explicit module provider
   arrays. R3 treats those registrations as frozen debt and removes them; Nest's
   controller-local enhancer wrappers are classified separately and are not
   provider-owner registrations.
5. Catalog controllers require the concrete Backoffice guards at runtime.
   Symbol-only injection cannot replace `@UseGuards(AdminGuard)` metadata.
   Nest already owns those enhancer wrappers in each controller module, so R3
   freezes the exact decorator metadata and removes the redundant explicit
   provider registrations instead of adding an export module or wrappers.
6. The final physical-device gate reproduced a pre-existing client race: the
   account-context bootstrap shared one request generation with account-session
   restoration, so a successful `/auth/me` response could be discarded and the
   local session torn down. R3 separates those generations at the network
   boundary while preserving account-change and context-change stale-request
   rejection. This is a reviewed runtime-blocker correction, not R9 Mobile
   restructuring.

## Non-Goals

R3 does not:

- move controllers or service implementation files out of their current
  legacy roots;
- introduce new product endpoints, DTOs, response fields, errors, Arabic text,
  permissions, transactions, locks, retries, scheduler intervals, or event
  semantics;
- create speculative public ports for planning, finance, tasks, guests,
  marketplace, catalog, insights, or Backoffice application services;
- change Prisma model ownership, relation traversal, raw SQL ownership, schema
  files, seed, migrations, generated client semantics, or the 52-model and
  41-enum sets;
- remove either approved `@Global()` declaration; that remains R8;
- migrate sharing's direct OpenWA transient-text consumption; that remains R6;
- perform R4-R8 source/model-ownership moves, R9 Mobile boundaries, or R10
  Admin Web restructuring;
- create compatibility facades, old/new duplicate implementations, fallback
  imports, or permanent baseline exceptions.

Public contract types and existing pure policy declarations may be extracted
from legacy implementation files when a real current R3 consumer requires
them. That extraction is contract work, not a move of the provider
implementation.

## Exhaustive Context Composition

R3 creates these full modules and no additional business context:

| Context | Full module | Current roots composed |
| --- | --- | --- |
| identity | `src/modules/identity/identity.module.ts` | auth, users, me, contexts |
| planning | `src/modules/planning/planning.module.ts` | wedding-plans, onboarding |
| finance | `src/modules/finance/finance.module.ts` | money, budget-categories, wedding-costs |
| collaboration | `src/modules/collaboration/collaboration.module.ts` | sharing, contribution-history |
| tasks | `src/modules/tasks/tasks.module.ts` | tasks |
| guests | `src/modules/guests/guests.module.ts` | guests |
| marketplace | `src/modules/marketplace/marketplace.module.ts` | marketplace, provider-dashboard |
| messaging | `src/modules/messaging/messaging.module.ts` | conversations |
| notifications | `src/modules/notifications/notifications.module.ts` | notifications, push |
| catalog | `src/modules/catalog/catalog.module.ts` | catalogs |
| media | `src/modules/media/media.module.ts` | media |
| insights | `src/modules/insights/insights.module.ts` | dashboard, timeline |
| backoffice | `src/modules/backoffice/backoffice.module.ts` | admin |

The implementation files remain in their current roots. The new modules own
their Nest metadata. Once metadata parity and boot tests pass, the superseded
legacy `*.module.ts` metadata files are deleted. The one exception is the
existing canonical `conversations/conversation-realtime.module.ts` global leaf:
its declaration path and global behavior remain frozen until R8, while all new
cross-context consumers use its public Symbol alias.

## Provider-Leaf Binding Law

For each real public provider, R3 uses an internal implementation token so the
PublicModule never imports the legacy implementation class:

```typescript
export const EXAMPLE_PORT = Symbol('EXAMPLE_PORT');
export const EXAMPLE_IMPLEMENTATION = Symbol('EXAMPLE_IMPLEMENTATION');

export interface ExamplePort {
  execute(input: ExampleInput): Promise<ExampleOutput>;
}

@Module({
  imports: [/* only the leaf's real dependencies */],
  providers: [
    LegacyExampleService,
    { provide: EXAMPLE_IMPLEMENTATION, useExisting: LegacyExampleService },
  ],
  exports: [LegacyExampleService, EXAMPLE_IMPLEMENTATION],
})
export class ExampleInternalModule {}

@Module({
  imports: [ExampleInternalModule],
  providers: [{ provide: EXAMPLE_PORT, useExisting: EXAMPLE_IMPLEMENTATION }],
  exports: [EXAMPLE_PORT],
})
export class ExamplePublicModule {}
```

The full owner module imports the same static internal and public module tokens.
It never registers `LegacyExampleService` again. Exporting the concrete token
from the internal leaf is owner-private: it exists so owner controllers,
schedulers, and provider leaves can resolve their unchanged concrete injection.
The scanner rejects every foreign import of the InternalModule or concrete
class. A paired PublicModule may import only its declared internal module and
internal implementation token; it may not import a legacy concrete class. The
implementation token is not public API and may not be consumed outside that
paired PublicModule and the owner's singleton-identity test. Tests must prove:

```typescript
expect(context.get(EXAMPLE_PORT)).toBe(
  context.get(LegacyExampleService),
);
```

The frozen global `ConversationRealtimeModule` remains byte-for-byte unchanged.
A small same-context internal bridge imports that global module, aliases the
existing publisher class to a messaging implementation token, and exports only
that internal token. `MessagingRealtimePublicModule` aliases the internal token
to `MESSAGING_REALTIME_PORT`; it never imports the publisher class. This keeps
the global declaration frozen while preserving the exact singleton.

Nest PublicModule metadata and public-slice runtime code may not import another
context's PublicModule, full, internal, or legacy runtime source. Public contract
files may use an exact cross-owner `import type` recorded by the manifest. An
internal provider leaf may import another context's PublicModule only when its
owned provider actually injects that public contract.

## Demand-Driven Public Contracts

R3 introduces exactly these provider contracts because they have current
consumers:

| Owner | Public contract | Current consumer purpose |
| --- | --- | --- |
| identity | `IDENTITY_AUTH_PORT` | invite OTP request and verification |
| identity | `IDENTITY_ACCESS_TOKEN_VERIFIER` | messaging WebSocket JWT verification |
| collaboration | `COLLABORATION_PERMISSION_PORT` | plan/member/task/guest/money/provider authorization |
| collaboration | `COLLABORATION_HISTORY_PORT` | contribution event/tenure recording and the current dashboard summary read |
| collaboration | `COLLABORATION_SCOPE_PORT` | contribution visibility scopes |
| messaging | `MESSAGING_REALTIME_PORT` | session/user/conversation invalidation and realtime outbox sink |
| notifications | `NOTIFICATIONS_PORT` | notification creation, visibility, purge, and task-due behavior |
| notifications | `PUSH_DELIVERY_PORT` | outbox push dispatch |
| notifications | `PUSH_CAPABILITY_PORT` | identity account response capability flag |
| media | `MEDIA_STORAGE_PORT` | upload/download/consumption/deletion and readiness |

Every token has an exact consumer list in the R3 manifest. A token with no live
consumer fails the architecture gate. Planning, finance, tasks, guests,
marketplace, catalog, insights, and Backoffice application services receive no
invented public token in R3.

Public interfaces expose only methods already used by foreign consumers. The
legacy class implements the interface structurally; no adapter class is added.
Types needed by those signatures move into the owner's public slice and retain
their exact TypeScript shape.

`AuthenticatedUser` and `JwtSessionScope` move to the Identity public slice at
the start of Task 2 because Media's public upload/consume signatures already
depend on them. All old type consumers move mechanically and the retired type
path is deleted without a re-export facade. Type-only imports between public
slices are allowed and recorded; runtime imports and Nest PublicModule metadata
imports between foreign public slices remain forbidden.

## Decorator Runtime Metadata Law

The existing pure Backoffice permission-domain exception remains exact:
`auth/**` and `catalogs/**` may import only
`modules/backoffice/domain/admin-permissions.ts`; unauthorized sources and
sibling targets remain forbidden.

`@UseGuards(Class)` is not normal imported-provider ownership. Nest registers an
enhancer wrapper for the guard class in each host controller module and resolves
it from that host; importing a module that exports the guard would create an
extra unused instance rather than a shared singleton. R3 therefore creates no
guard PublicModule and no concrete public export.

Task 1 freezes exact `decorator-runtime` references: 23 foreign controllers,
20 using `JwtAuthGuard` and 3 using `JwtSessionGuard`, plus the current Admin and
Catalog controller uses of `AdminGuard` and `AdminPermissionGuard`. These class
imports and route metadata remain exact in R3 and are deferred to later source
move phases. They are not DI-token consumers, provider owners, hollow ports, or
singleton candidates. R3 removes the redundant explicit Admin/Catalog provider
array registrations; it excludes only the exact framework-created enhancer
wrappers from duplicate-owner assertions. No service, repository, Prisma, or
additional decorator exception is permitted.

## Application Composition Seam

### Runtime Environment and JWT

Platform keeps generic environment validation. Identity keeps JWT-secret
policy. The function becomes:

```typescript
export type IdentitySecretValidator = (
  environment: NodeJS.ProcessEnv,
) => void;

export function validateRuntimeEnvironment(
  environment: NodeJS.ProcessEnv,
  validateIdentitySecret: IdentitySecretValidator,
): void;
```

`main.ts`, as the application composition root, calls
`validateRuntimeEnvironment(process.env, getJwtSecret)`. The callback executes
after the existing missing-required-variable check and before the unchanged
sequence: OTP mode, OTP throttle pepper, global OTP limit, push, media, and
transport-specific validation. There is no default callback or platform
fallback that duplicates identity policy. Tests freeze the full error
precedence and one invocation.

### Readiness and Media

Platform defines `MEDIA_READINESS_PORT` with only `checkReadiness():
Promise<void>`. `ReadinessService` injects that token. `AppModule` imports the
Media storage public module and binds:

```typescript
{ provide: MEDIA_READINESS_PORT, useExisting: MEDIA_STORAGE_PORT }
```

`ReadinessService` remains registered in `AppModule`, so the alias and consumer
share one module scope. `AppModule` is therefore an explicit root-composition
point for readiness; `ApplicationOutboxRuntimeModule` is the separate dedicated
composition module for Outbox. Its response, timeouts, required/disabled
semantics, and error swallowing remain unchanged.

### Outbox

The current `OutboxModule` is split without changing dispatch behavior:

- `OutboxCoreModule` remains platform-only and owns `OutboxService` plus
  `OutboxCleanupScheduler`;
- platform defines `OUTBOX_REALTIME_SINK` and `OUTBOX_PUSH_SINK` interfaces;
- `ApplicationOutboxRuntimeModule`, under `src/application-composition/`,
  imports `OutboxCoreModule`, Messaging Realtime Public, and Notifications Push
  Delivery Public;
- that composition module binds the two platform sink tokens with
  `useExisting` and registers exactly one `OutboxDispatcher` and one
  `OutboxWorker`;
- business modules that enqueue events import only `OutboxCoreModule`.

Deleting the old Outbox import would otherwise make the legacy `PushModule`
unreachable after Users switches to Push Capability Public. From Task 2 through
Task 7, same-context `NotificationsModule` imports a refactored PushModule that
owns only `PushController` and `PushInstallationsService`; transport providers
live only in the Push internal leaf. Task 8 removes that temporary import and
module atomically when Notifications full composition takes over the same route
and installation provider. Controller/route reachability parity is mandatory at
both boundaries.

Platform source imports no business module or application-composition source.
The dispatcher keeps all event names, validation, optional push semantics,
retries, locks, and errors unchanged.

## Dependency-Debt Removal Contract

R3 removes exactly these six frozen platform dependency records:

1. `platform/config/runtime-environment.ts -> auth/jwt-secret.ts`;
2. `platform/health/readiness.service.ts -> media/media-storage.service.ts`;
3. `platform/outbox/outbox.dispatcher.ts -> conversations/conversation-realtime.publisher.ts`;
4. `platform/outbox/outbox.dispatcher.ts -> push/push-delivery.service.ts`;
5. `platform/outbox/outbox.module.ts -> conversations/conversation-realtime.module.ts`;
6. `platform/outbox/outbox.module.ts -> push/push.module.ts`.

Task 1 freezes immutable authorization ledgers named `initialPlatformDebts` and
`initialRetiredLegacyProviderEdges`; every legacy-edge record includes its exact
dependency key and `retirementTask`. Separate `remainingPlatformDebts` and
`remainingRetiredLegacyProviderEdges` begin as exact copies and may only shrink
at their declared task. The initial arrays never change, including at strict
closeout. The dependency baseline may delete only their immutable union, plus
the two Task-3 type-only contract reclassifications from
`dashboard/dashboard.contracts.ts` and `dashboard/dashboard.service.ts` to
`contribution-history/contribution-history.contracts.ts`, and only after the
matching source import is absent. Those two records moved to the typed
Collaboration public contract and ceased to be violations; they are not
provider-edge debts. It may not add, rename, or increase any record; no other
record may disappear.
Ownership baseline records, Mobile baseline records, and the two global
declarations are byte-frozen in R3 unless an independently reproduced R3 defect
requires a separately reviewed correction.

## Machine-Enforced Inventory

Before production changes, R3 records:

- all 13 contexts and their current roots;
- all current legacy Nest modules and exact imports/controllers/providers/
  exports;
- all current cross-context constructor/provider dependencies;
- each public token, exact implementation, exact consumer files, and required
  method surface;
- every R3 provider-contract reference classified as constructor injection,
  function parameter, type-only import, or pure-function import;
- frozen non-port references classified separately as `decorator-runtime` or
  `runtime-decorator/value`, including exact `CurrentUser`,
  `RequireAdminPermission`, and guard metadata; all other legacy baseline edges
  remain frozen rather than being misrepresented as R3 ports;
- the three current duplicate-provider classes and their owning metadata paths;
- the six platform debts;
- the exact legacy provider-debt records retired by public-contract migration;
- lifecycle providers whose instance count must remain one;
- the exact R3 changed-path allowlist anchored to `R3_BASE`.

The scanner resolves TypeScript symbols and Nest metadata. It rejects unknown
metadata, dynamic/spread/conditional arrays it cannot prove, duplicate provider
ownership, foreign full/internal imports, public concrete exports, hollow
tokens, token/implementation mismatches, cycles, new globals, and `forwardRef`.
It permits only the frozen decorator-runtime enhancer set and type-only
public-slice edges. The initial duplicate/platform/retired-legacy ledgers are
immutable authorization; additions fail immediately and each matching remaining
set must reach zero before R3 closeout.

## Existing-Test Change Policy

Existing behavioral assertions, expected values, fixtures, Arabic/error text,
timeouts, skips, and setup semantics remain frozen. R3 permits only:

- mechanical import/type path changes caused by public contract extraction;
- constructor parameter type and `@Inject(PUBLIC_TOKEN)` wiring changes;
- Nest testing-module import/provider wiring needed to supply the same instance;
- exact addition of the required runtime identity-secret callback to existing
  test calls, using only the real validator or a deterministic callback and
  without changing assertions or fixtures;
- exact moved/deleted module-path literals in architecture tests;
- additive R3 architecture, singleton, boot, parity, and composition tests.

Any behavioral assertion, mock behavior, fixture data, timeout, route, payload,
or error change stops the task for explicit review. Tests are never weakened,
deleted, renamed, or skipped to make R3 pass.

## Verification and Checkpoints

Every R3 task is an independently reviewed checkpoint:

1. write permanent failing tests and capture the expected RED;
2. make the smallest production change that closes that boundary;
3. run focused tests, architecture, type-check, build, and the exact managed
   smoke package scripts declared by that task, requiring exit 0 and an
   independent zero-residue audit;
4. verify the R3 fixed-base scope and protected surfaces;
5. obtain independent source/contract review and fix findings at the root;
6. create one local checkpoint commit and leave the worktree clean;
7. stop for the owner's application test/continuation approval.

R3 closeout additionally runs the full Backend suite, `smoke:all`, Prisma
validation and semantic fingerprints, both npm audits, Admin gates, Mobile
boundary/analyze/tests, docs gates, immutable Docker probe/cutover, safe runtime
log audit, independent final review, and owner phone testing. R2 remains the
verified rollback until R3 phone acceptance.

## Acceptance Summary

R3 is accepted only when all of the following are true:

- `AppModule` imports exactly 13 full context modules, the dedicated Outbox
  runtime composition module, Media Storage Public for the root readiness
  composition point, and existing platform/root infrastructure;
- no superseded legacy full-module metadata remains active or duplicated;
- no provider class is registered by more than one owner module;
- every public Symbol token resolves to the exact legacy class instance;
- no PublicModule is empty and no token lacks a current manifest consumer;
- public modules export no concrete service or guard class; owner-private
  internal leaves alone may export their concrete class to owner modules;
- the exact decorator-runtime guard reference/route metadata set is unchanged,
  redundant explicit Admin/Catalog guard providers are absent, and framework
  enhancer wrappers are not misclassified as provider owners;
- migrated cross-context DI imports only owner public tokens/types;
- no foreign full/internal/legacy module import, unresolved Nest metadata,
  `forwardRef`, or Nest cycle exists;
- exactly two approved globals remain at their current paths;
- both remaining debt arrays are empty while both immutable initial ledgers stay
  byte-exact; their authorized union and the exact two documented Task-3
  type-only reclassifications are absent from the dependency baseline, with no
  other deletion and no new platform-to-business or baseline debt;
- controller, route, and OpenAPI metadata are exact; provider/lifecycle
  ownership is semantically equivalent without duplication; each old concrete
  export is replaced by a manifest-listed public token or proved unused; old
  imports are replaced by declared public dependencies; error-order and
  singleton parity tests pass;
- the schema remains 14 files, 52 models, 41 enums, and 76 migrations, with
  unchanged seed and normalized DMMF;
- API, Admin Web, Compose/deploy, and product behavior remain unchanged; Mobile
  remains unchanged except for the exact session-restore race correction above;
- all exhaustive local, runtime, independent-review, and owner application
  gates pass;
- no push, merge, PR mutation, remote-CI claim, or R4+ work occurs without a
  separate owner instruction.

## Rejected Alternatives

- **Thirteen hollow PublicModules:** rejected because unused tokens are not a
  real contract and would expand the architecture without a consumer.
- **One InternalModule per context:** rejected because reciprocal provider use
  creates real Nest cycles even when `forwardRef()` stays zero.
- **Root-only aliases for child platform providers:** rejected because Nest
  provider visibility does not flow from a parent module into imported modules.
- **Adapter/wrapper service per token:** rejected because `useExisting` can bind
  the exact implementation and wrappers would create identity/lifecycle risk.
- **Duplicate Backoffice guards:** rejected because current duplication is debt,
  not a pattern; controller-local Nest enhancer wrappers remain, while redundant
  explicit provider-array registrations and any extra guard module are removed.
- **Move all legacy source in R3:** rejected because source/model ownership moves
  belong to R4-R8 and would make route/behavior parity unreviewable.
- **Blind baseline regeneration:** rejected because it can convert new debt into
  apparent permission.
