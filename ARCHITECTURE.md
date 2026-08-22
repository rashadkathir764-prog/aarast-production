# Aarast Modular Monolith Architecture

Snapshot date: 2026-08-22

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

R1 has one exact pre-port exception for the existing Backoffice permission
contract: current `auth/**` and `catalogs/**` consumers may import only
`modules/backoffice/domain/admin-permissions.ts`; `admin/**` is the owning
Backoffice context and needs no exception. The file is a pure enum and
role-matrix helper that uses only the generated `AdminRole` enum: it creates no
Nest, PrismaService, model access, query, or repository dependency, and replaces
the former `common/admin` location. No other
`modules/backoffice/domain/**` import is allowed across contexts. This exact
contract is enforced by a near-miss test plus an unauthorized-source test, and
is not dependency-baseline debt; a later module phase may expose it through a
public slice. Its import surface is exact: one named `AdminRole` import from
`@prisma/client` and no other import.

## Physical Data Ownership

Every Prisma model has one physical owner. Physical ownership applies to root
delegates, Prisma relation traversal (`include`, `select`, relation
filters/orderings), nested relation writes, and every physical table referenced
by raw SQL. An unresolved relation/query shape is architecture debt, not
implicit permission.

`WeddingPlan` has one physical owner: planning. R4 removed Finance's former
direct write to `WeddingPlan.estimatedBudget`. Finance now calls the exact
Planning-owned `PLANNING_BUDGET_WRITE_PORT`, passing the caller's existing
transaction client; the Planning writer owns the physical update. The former
R0 baseline violation is retired and is not a permanent exception.

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

R1 has one reviewed pre-Task-4 QA exception for two stale managed-smoke
harnesses and the shared test cleanup they exercise:
`phase2-notification-preferences-smoke.ts` verifies the exact existing
per-notification outbox event types; `phase2-conversation-revocation-smoke.ts`
constructs `SharingService` with the current real `ContributionHistoryService`;
and the PostgreSQL fixture cleanup closes active contributor tenures and marks
their history scopes deleted before removing shared-member/plan fixtures;
`test/phase0-guards.test.ts` provides the sole allowed cleanup-order/lifecycle
assertion for that support change. This exception changes no production
behavior, preserves contribution history, and authorizes no other assertion,
fixture creation, timeout, or setup change.

R1 closeout has one additional runtime-safety exception discovered by the
final phone-server review: `ConversationsGateway` must keep the access-token
expiry `NodeJS.Timeout` in a process-local `WeakMap`, never in `socket.data`
that the Redis Socket.IO adapter serializes for remote fetches. The only
corresponding behavioral-test hunk is the focused Redis remote-fetch
serializability regression in `test/websocket-session-hardening.test.ts`.
This exception changes no route, payload, token lifetime, permission, or
disconnect contract; it prevents the existing cross-replica fetch path from
crashing the Node process.

R2 has one exact existing-test migration exception for the native Prisma
schema-folder split. These tests may replace only their direct
retired single-file schema read with the shared live-schema helper:
`admin-auth-session-security.test.ts`, `admin-rbac-audit.test.ts`,
`auth-refresh-wiring.test.ts`, `contribution-history-migration.test.ts`,
`financial-ledger.test.ts`, `legacy-finance-removal.test.ts`,
`marketplace-presenter.test.ts`, `outbox-logic.test.ts`,
`provider-chat-logic.test.ts`, and `reference-catalogs.test.ts`.
`architecture-ownership.test.ts` may additionally replace its single-file
fixture with the exact schema folder plus manifest. No assertion, expected
value, behavioral fixture, product/error/Arabic literal, timeout, skip, or test
selection may change. R2 used this exception only for the reviewed mechanical
reader migration; the frozen assertion and behavior contract remained green.

R0 adds architecture tests and does not edit existing behavioral tests.

## Phase Contract

- Completed P2 checkpoints remain accepted; further P2 implementation is
  paused by owner direction.
- P3 R0 Governance is locally and remotely green at immutable candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. By owner decision, R1 continues
  locally on the same `modular-monolith` branch without merging R0 first.
- R1 is locally complete: infrastructure lives under
  `platform/`, foundational helpers live under `shared-kernel/`, and no
  `src/common`, `src/prisma`, `src/outbox`, or root health source remains. The
  complete local gates, managed `smoke:all`, independent final source/runtime
  review, and owner phone application checkpoint all passed on 2026-08-13.
- PR #76 remains pinned remotely to the R0 candidate while local R1 checkpoint
  commits accumulate. Do not push or merge without separate owner approval.
  The phase-specific `r0-scope` CI job is intentionally removed at local R1
  closeout because any future push is a combined post-R0 candidate; all other
  CI jobs remain unchanged and remote results are not claimed locally.
- R3 is locally complete from immutable base
  `6b06eb096aca8cc6684d365d16e05d4cd8529898`: all 13 business contexts have
  reviewed full/internal/public Nest boundaries, the initial 3 duplicate
  registrations, 6 platform-to-business debts, and 163 retired provider edges
  are all closed, and the live graph has zero `forwardRef()`, zero cycles, and
  zero illegal boundary edges. The two approved `@Global()` declarations remain
  scheduled for R8; sharing's direct OTP transport migration remains assigned
  to R6.
- R2 local implementation, production-shaped runtime, and owner application
  checkpoint passed on 2026-08-14 from immutable base
  `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`. The live Prisma source is the
  native folder with `_base.prisma` plus 13 current model-owner files: exactly
  52 models, 41 enums, and 76 unchanged migrations. Normalized DMMF and migrate
  diff prove semantic equivalence; seed, migrations, generated contracts,
  application behavior, Mobile/Admin source, and deployment topology remain
  unchanged. Independent R2 source/contract/runtime/receipt review passed and
  the accepted R2 runtime remains preserved as rollback evidence.
- The R3 phone checkpoint found and corrected one pre-existing Mobile restore
  race: account-context bootstrap no longer invalidates a successful
  `/api/v1/auth/me` response. The corrected R3Local APK force-stop/relaunch gate
  restored the authenticated dashboard, emitted `SESSION_RESTORED`, and emitted
  neither restore failure nor logout. The immutable R3 runtime and prior R3/R2
  rollback artifacts remain local; no push, merge, or remote CI is claimed.
- R4 is locally complete from immutable base
  `502b181a2ce624458fd7eae064f194497ec0151e`. Finance consumes one singleton
  Planning public write port and no longer writes `WeddingPlan` directly. The
  ownership baseline decreased by exactly the frozen debt from 386 records / 782
  occurrences to 385 / 781. Full Backend gates, affected and aggregate managed
  smokes, immutable Docker cutover, independent review, and the owner phone
  money-budget checkpoint passed. API, schema, migrations, Mobile, Admin, and
  deployment behavior remain unchanged.
- R5 is locally complete from immutable base
  `9dab73acdc187a4a18d8a675713d8ded40a16d02` at application candidate
  `8cfee451a76bb17e20d278a1646dde4387bf7b18`. All 44 Identity files moved
  one-to-one from `auth`, `users`, `me`, and `contexts` into the existing
  `modules/identity` public/internal/full boundary, and the four legacy roots
  are absent. The dependency baseline is exactly 31 records after retiring the
  58 authorized relocation debts; ownership remains 385 records / 781
  occurrences. Routes, auth/OTP/session behavior, schema, migrations, model
  ownership semantics, Mobile, Admin, and deployment remain frozen. Full local
  gates, immutable runtime cutover, and the owner phone checkpoint passed. No
  push, merge, deployment, or remote CI is claimed.
- R6 planning is owner-approved from immutable completed-R5 base
  `ce0c0d19824bff79d91417e2fe4617914c6bcd70`. The one named scope is
  Collaboration's direct import of the concrete OpenWA transient sender in
  `InvitationDeliveryService`. Identity will own a provider-neutral public
  transient-delivery port and a private adapter over the unchanged platform
  sender; Collaboration will consume only that public port. Dependency evidence
  remains 31 records and ownership remains 385 records / 781 occurrences.
  Application implementation has not started, R7 is not authorized, and no
  push, merge, deployment, or remote-CI result is claimed.
- The tracked R0 receipt records local checks only. The immutable candidate SHA
  and CI status are resolved from pull-request and workflow metadata and are
  never back-written into a self-referential tracked document.
- R3+ creates the documented Nest public/internal/full module pattern. R4 has
  removed Finance's direct `WeddingPlan.estimatedBudget` write. R9 activates
  the strict Mobile boundary mode.

The immutable R4 pre-runtime/application-candidate execution snapshot is
`docs/superpowers/plans/2026-08-16-modular-monolith-r4-planning-finance-ownership.md`.
Its in-progress status records the application candidate before authorized
runtime, phone, and receipt closeout; the active receipts above record the
later completed local state. It is not a replacement for this contract or the active
product, API, database, QA, and deployment sources listed in `docs/README.md`.
