# Aarast Modular Monolith Architecture

Snapshot date: 2026-08-12

This is the canonical human contract for Aarast's modular-monolith migration.
It defines the target bounded contexts, dependency direction, physical data
ownership, Mobile boundaries, test-change policy, and phase gates. R0 is a
governance phase: it moves no application source and changes no runtime
behavior, route, database schema, migration, or deployment artifact.

## Business Module Map

The following list is exhaustive: Aarast has these 13 business modules and no
additional business module.

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

Platform owns `IdempotencyKey` and `OutboxEvent`. Platform is infrastructure,
not one of the 13 business modules. `shared-kernel` is likewise an architectural
layer rather than a business module.

During migration, a context is the union of its legacy roots and
`src/modules/<context>`. This preserves one context identity while source moves
incrementally behind the public contract.

## Dependency Direction

The dependency direction is:

```text
business modules -> platform -> shared-kernel
```

Business modules may also import `shared-kernel` directly. `platform` may not
import business modules, and `shared-kernel` may import neither `platform` nor
business modules.

Any edge involving a future module may cross context only into the target's
`public/` slice. Legacy-to-legacy debt remains frozen by the R0 dependency
baseline: a baseline records debt, not permission, and its counted set may only
shrink.

The Nest class/import graph must remain acyclic and `forwardRef()` remains
forbidden. Reciprocal business consumption is legal only when the two public
provider slices do not import one another.

## Nest Module Binding Pattern

R3 facades cannot import full legacy modules because that would expose
controllers, private providers, and transitive internals instead of the owned
public contract. The naming and binding contract is:

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

The binding laws are:

- `InternalModule` is private to its owning bounded context.
- `PublicModule` exports Symbol tokens and public types only.
- A full module may import another context's `PublicModule`, never its full or
  internal module.
- Cross-context consumers depend on the owner's public token and types, not on
  its legacy service or repository implementation.

## Physical Data Ownership

Every Prisma model has one physical owner. Physical ownership applies to root
delegates, Prisma relation traversal (`include`, `select`, relation
filters/orderings), nested relation writes, and every physical table referenced
by raw SQL. An unresolved relation/query shape is architecture debt, not
implicit permission.

`WeddingPlan` has one physical owner: planning. Finance's current direct write
to `WeddingPlan.estimatedBudget` is a temporary R0 baseline violation, not a
permanent architecture exception. R4 must replace it with a planning public
write port that accepts the caller's explicit transaction client.

The old E1 treatment is not a target exception. A transaction that spans
contexts must preserve the caller's transaction boundary through an explicit
owner public port; it does not transfer physical ownership to the caller.

## Mobile Boundary Contract

- R0 baseline mode: existing direct imports may remain but their counted set
  may only shrink.
- R9 strict mode: cross-feature imports target `<feature>_api.dart`; all
  `core/** -> features/**` imports are forbidden except route assembly under
  `core/routing/**`, which may import feature public route/screen barrels.

The routing exception is a composition-root exception, not a general permission
for core to consume feature state or models.

Dart `part`/`part of` is a compilation-unit relationship, not a boundary
escape: both files must resolve, declare each other through URI-style
directives, and remain inside the same feature/core area. Cross-area parts and
unresolved local directives fail immediately in every phase.

## Existing-Test Change Policy

Existing behavioral assertions, expected values, fixtures, Arabic/error
contracts, and setup semantics are frozen. A later move phase may make only
reviewed mechanical import/export/require edits, moved-source path-literal
edits, test-file moves, and DI token wiring edits required by that move. Any
other existing-test change is a stop signal and requires explicit review.

R0 adds architecture tests and does not edit existing behavioral tests.

## Phase Contract

- Completed P2 checkpoints remain accepted; further P2 implementation is
  paused by owner direction.
- P3 R0 Governance is locally and remotely green at immutable candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. By owner decision, R1 continues
  locally on the same `modular-monolith` branch without merging R0 first.
- R1 is active. Each R1 task must pass focused gates, architecture/check/build,
  an applicable managed server smoke, independent review, and the owner's
  application checkpoint before the next task begins.
- PR #76 remains pinned remotely to the R0 candidate while local R1 checkpoint
  commits accumulate. Do not push or merge without separate owner approval.
  R1 removes the phase-specific `r0-scope` CI job only at R1 closeout.
- The tracked R0 receipt records local checks only. The immutable candidate SHA
  and CI status are resolved from pull-request and workflow metadata and are
  never back-written into a self-referential tracked document.
- R3+ creates the documented Nest public/internal/full module pattern. R4
  removes Finance's current direct `WeddingPlan.estimatedBudget` write. R9
  activates the strict Mobile boundary mode.

The current working plan is
`docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md`. It is a
working execution artifact, not a replacement for this contract or the active
product, API, database, QA, and deployment sources listed in `docs/README.md`.
