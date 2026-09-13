# Aarast Modular Monolith Architecture

Snapshot date: 2026-09-13

This is the canonical human contract for Aarast's modular-monolith migration.
It defines the target bounded contexts, dependency direction, physical data
ownership, Mobile boundaries, test-change policy, and phase gates. R0 is a
governance phase: it moves no application source and changes no runtime
behavior, route, database schema, migration, or deployment artifact.

## Modular Monolith R12C — Local Completion — 2026-09-13

R12C is complete locally.
Dependency debt is 0; the dependency baseline is deleted and the import gate
is strict and unbaselined.
Ownership remains 385/781.
The architecture target remains incomplete; R13–R18 remain.
Commits exist only on the local recovery branch
`recovery/r12c-t5-takeover-20260913`. No push, merge, deployment, production
mutation, remote CI, provider delivery, phone acceptance, or release is
claimed.

The Finance wedding-cost response projection, the transaction-bound Messaging
conversation-lifecycle port, and the pure Marketplace provider-access policy
now exist once each under their owner public boundaries, and every declared
consumer (3, 5, 7) uses those contracts. The nine R11 dependency records
`10`, `12-17`, `19-20` are retired; `depcruise --config .dependency-cruiser.cjs src`
reports 353 modules, 1,420 dependencies, 0 violations without any allowance;
ownership bytes are unchanged. Governance identity is repository identity
(Git top level extending the immutable base commit `4d0d3ee9`), no longer an
absolute path, branch or dirty working tree, so every gate runs from any
checkout; fixtures never touch the live dependency installation; the
`multer`/`sharp` advisories are remediated as a registered security
prerequisite. Task 6 passed focused `133/133`, full Backend `1499` with
`1498` passing and one declared Windows skip, aggregate smokes `30/30`, six
phase-2 concurrency smokes, and both audits at zero. See
`docs/superpowers/reports/2026-09-08-modular-monolith-r12c-zero-cross-context-dependencies-report.md`.

The byte-lineage governance is closed (spec section 19). The tracked record
`backend/architecture/modular-monolith-closure.json` freezes the R12A/R12B/R12C
manifests by hash and names the lineage commit `4bae5c6d` at which the
complete lineage gates last passed; the scanners read it and verify live
invariants from then on (`stage=strict (closed)`), failing closed on any
deviation of the record, the manifests or the ancestry. The
governance-portability suite re-runs the lineage gates at the lineage commit
on every run. Governed files are ordinary reviewed code after the closure.

## Modular Monolith R12B — Local Completion — 2026-09-06

R12B is complete locally.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation followed on 2026-09-13 (see above).
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.

The Planning wedding-location implementation now exists once under its owner
public boundary, and all seven declared consumers use that path. Onboarding
owns exact local task and guest DTO re-expressions instead of importing API DTOs
from Tasks or Guests. The strict R12B projection retires only dependency IDs
`7-9`, `11`, `18`, and `21-22`; ownership bytes remain unchanged. Task 5 and
the independent candidate review passed, and the four-receipt documentation
transition is activated. The activated exact-state re-review remains the final
Task 6 close gate.

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
- R6 is locally complete from immutable completed-R5 base
  `ce0c0d19824bff79d91417e2fe4617914c6bcd70` at application candidate
  `cefe07a76b0e615d4fecbb666514d9a2b87a7d37`. Identity owns one
  provider-neutral public transient-delivery port and one private adapter over
  the unchanged platform OpenWA sender. Collaboration consumes only the public
  Identity module and Symbol; R6 is strict with zero concrete protected
  imports. Dependency evidence remains 31 records and ownership remains 385
  records / 781 occurrences. Full local gates, immutable runtime cutover, and
  the authenticated phone sharing journey passed with OpenWA truthfully
  disabled and the stopped R5 runtime preserved for rollback. R7 design and
  implementation plan are approved; application relocation has not started.
  No push, merge, deployment, or remote-CI result is claimed.
- R7 is locally complete from immutable R6 closeout
  `31ea5324007fc71fa4b3590fbb98a454ee1deaa7` at application candidate
  `aafb47ea1742c278f6a5ed24799ada7bc23721b0`. All 18 Collaboration files moved
  one-to-one into the existing API/internal/public boundary; the two legacy
  roots are absent and no compatibility facade remains. The public snapshot
  builder keeps four runtime exports, the exact dependency debt is 22 records,
  and ownership remains 385 records / 781 occurrences. Full local gates,
  immutable runtime cutover, independent cumulative review, and the
  authenticated phone create/reissue/read/cancel/restore journey passed.
  OpenWA remained disabled; R6 is stopped and preserved for rollback. R8 has
  not started. No push, merge, deployment, or remote-CI result is claimed.
- R8 is locally complete from immutable R7 closeout
  `c2b728bfe54304562923facfb6094e0de04c0b27` at application candidate
  `464d785a0440b8494768a26a70ac1de73a4bff2c`. Project-owned globals are zero;
  all 21 Prisma and both Realtime consumers import their owner modules
  explicitly; singleton provider identity and the Realtime `useExisting` chain
  remain exact. The only global runtime behavior left is dependency-owned and
  frozen to `@nestjs/schedule@6.1.3` through `ScheduleModule.forRoot()` and
  `@nestjs/throttler@6.5.0` through
  `ThrottlerModule.forRootAsync(...)`. Architecture/check/build/tests, Prisma
  equivalence, audits, 12 focused smokes, all 30 aggregate smokes, independent
  reviews, immutable runtime, and the authorized 26-phone task/chat/restore
  journey passed. R7 is stopped and preserved for rollback. No push, merge,
  deployment, remote CI, or R9 work is claimed by the R8 receipt.
- R9 is locally complete in the working tree from immutable base
  `833a4f1d31781b45cd0a68ecee1b969ac85f237f` with strict-CI HEAD
  `6b1602decd09a266634e2a98debc7fcf650e12cd` plus the reviewed C5 diff. All 19
  feature owners expose controlled public APIs; feature/root debt is zero and
  the legal projection is 159. `SafeUser` is canonical under `core/session`,
  Push binding consumes immutable nullable identity, and the only approved
  behavior correction preserves an installation-owned unimported guest plan
  across ordinary logout, restore rejection, and confirmed session expiry.
  Confirmed account deletion may clear that plan; successful migration and
  explicit double-confirmed discard retain their existing deletion contracts.
  Governance 230/230, Flutter 1164/1164, focused session and Push proofs,
  Backend/Admin gates, isolated runtime, the owner-selected `SM-S938B` journey,
  and independent review passed. Live Firebase Push remains unverified.
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

## R10 Admin Local Completion Contract

R10 Admin phase is locally complete from immutable R9 closeout
`e560e5784278907dd6bf565327c3abfa0c9b8cab`. Its reviewed design, execution
plan, and final evidence report are under `docs/superpowers/`. The relocation
changed no Backend product source, Mobile, Prisma, database, dependency,
lockfile, deployment, route, API, permission, Arabic copy, OTP, session, or
observable Admin behavior.

The eight Admin feature owners are exactly `auth`, `dashboard`, `users`,
`providers`, `catalog`, `moderation`, `notifications`, and `audit`. Their only
allowed cross-feature edges are:

```text
dashboard     -> auth, providers
users         -> auth
providers     -> auth
catalog       -> auth, providers
moderation    -> auth, providers
notifications -> auth
audit         -> (none)
auth          -> (none)
```

Cross-feature production imports must target the owner's exact
`features/<owner>/api.ts` public surface. Platform imports neither Features nor
Design System; Design System imports neither Features nor Layout. The only
production composition roots are `App.tsx`, `main.tsx`, and `layout/**`.
`src/test/contracts/**` is a test-only composition exception and may never be
imported by production code.

The public APIs are owner-controlled: Auth owns session/permission symbols;
Dashboard owns statistics and report overview; Users owns user projections and
lifecycle; Providers owns provider/application projections and lifecycle;
Catalog owns services, categories, cities, reference catalogs, and geography;
Moderation owns reviews and conversation reports; Notifications owns Admin
notification operations; Audit owns the read-only audit log. The exact symbol
sets are machine-enforced by
`admin-web/architecture/r10-admin-boundaries.json`; no owner may forward a
foreign public API as its own.

`App.tsx` alone may directly import these exact 18 feature screens plus the
Platform NotFound screen:

```text
features/auth/LoginPage.tsx
features/dashboard/DashboardPage.tsx
features/dashboard/ReportsPage.tsx
features/users/UsersPage.tsx
features/users/UserDetailsPage.tsx
features/providers/ProviderApplicationsPage.tsx
features/providers/ProviderApplicationDetailsPage.tsx
features/providers/ProvidersPage.tsx
features/providers/ProviderDetailsPage.tsx
features/catalog/CategoriesPage.tsx
features/catalog/CitiesPage.tsx
features/catalog/ServicesPage.tsx
features/catalog/ReferenceCatalogsPage.tsx
features/catalog/AdministrativeAreasPage.tsx
features/moderation/ReviewsPage.tsx
features/moderation/ConversationReportsPage.tsx
features/notifications/NotificationsPage.tsx
features/audit/AuditLogsPage.tsx
platform/routing/NotFoundPage.tsx
```

Strict R10 closeout requires the old `src/api`, `src/auth`, `src/components`,
and `src/pages` roots to be absent. A moved implementation is deleted in its
own checkpoint; no facade, re-export alias, duplicate, fallback, symlink,
junction, compatibility layer, or permanent Admin boundary baseline is
allowed.

The permanent local/CI gates are:

```powershell
Set-Location admin-web
npm run test:architecture
npm run architecture
```

The R10 task scope fence (`scripts/check-r10-scope.mjs`) was a phase-time
changed-path check against the R9 base revision; it was removed with the
other phase scope fences at the 2026-09-13 architecture exit audit, after the
phases it fenced were closed.

The TypeScript-AST scanner resolves real locations and rejects deep or
undeclared feature imports, foreign public-API forwarding, graph cycles,
absolute/traversal paths, symlink/junction escapes, dynamic bypasses, and any
return of the four legacy roots.

All 18 existing Admin test files and 96 existing tests remain selected. Their
assertions, expected values, fixtures, Arabic/error literals, timeouts, and
behavior are frozen except for two reviewed mechanical transformations:

- `DashboardPage.test.tsx` may split the existing Admin API mock target into
  exact Dashboard `getStats` and Providers `getProviderApplications` targets;
  mock implementations, fixtures, setup, test names, assertions, and expected
  values stay unchanged.
- `AdminPaginationContract.test.ts` may add one expected Pagination import to
  each of its existing seven ordered page records, bind that third value in the
  loop, and use it as the sole assertion operand. The value is exactly
  `../design_system/Pagination` while a page remains in `src/pages` and exactly
  `../../design_system/Pagination` after that page moves under its feature.
  Every value must match the raw page import and resolve to the same
  `src/design_system/Pagination.tsx`; no other assertion edit is allowed.

The independently reviewed local gates passed: old roots `5/9/27/24 ->
0/0/0/0`, boundary contracts 35/35, Admin tests 101/101, Mobile 1164/1164,
Backend 1351 pass / 0 fail / 1 intentional skip, all managed smokes, Prisma
52 models / 41 enums / 76 migrations, docs, audits, and protected surfaces.
Therefore `R10 Admin phase complete` and `R0-R10 execution wave locally closed
with declared Backend gaps` are accurate. `Modular-monolith architecture
target complete` remains forbidden while Backend dependency debt is 22 records
and physical-ownership debt is 385 records / 781 occurrences. R10 does not
retire or hide that debt.

## Post-R10 Target Completion Contract

The original 2026-08-04 final target remains binding. The tracked
[remaining-target design](docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md)
and [R11 plan](docs/superpowers/plans/2026-09-01-modular-monolith-r11-target-reconciliation.md)
reconcile that target with the locally closed R0-R10 wave; they do not weaken
or redefine it. R10 was subsequently committed locally at
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. Push, merge, deployment,
remote CI, real provider delivery, and store release remain outside the proven
state.

R11 documentation reconciliation is locally complete after its exact
nine-Markdown scope, debt-truth, documentation, cumulative architecture, and
independent-review gates passed. This activates the authority model below; it
does not start or authorize R12A.

The post-R10 sequence is:

| Phase | Exact boundary |
| --- | --- |
| R11 | Align active documentation with the original target and live debt 22 and 385/781 |
| R12A-R12C | Retire the 22 named dependency records to zero and delete the dependency baseline only after strict proof |
| R13-R17 | Retire all 385 ownership records / 781 occurrences once, by their exact context allocations; R14A Identity must exit before R14B Collaboration starts |
| R18 | Enter at ownership 0/0, prove strict zero without the baseline, then delete the zero-valued baseline |
| R19 | Audit the unproven Mobile fate-map remainder and implement only confirmed gaps under separate plans |
| R20 | Re-prove every original invariant in one all-surface final closeout |

Every phase requires a separate design, implementation plan, fixed scope fence,
independent review, affected tests, architecture gates, documentation gates,
and real-phone QA when Mobile behavior is in scope. A phase may not widen after
its plan is approved. Baselines are immutable debt ledgers: subtract exact
reviewed entries only; never regenerate, widen, or delete them early.

R13-R17 own the entire non-overlapping ownership retirement. Their exact totals
are 44/85, R14A Identity 60/78, R14B Collaboration 28/80, 10/19, 140/288,
and 103/231, summing to 385/781. R14B cannot start before R14A exits because
the owner-side invite OTP port must exist first. The reason
projection 301/563 plus 84/218 classifies those same records and is not a second
backlog. Any nonzero record at R18 entry returns to its R13-R17 owner.

The phrase `architecture target complete` remains reserved for R20 after
dependency zero, ownership 0/0, both baselines removed, and all binding local
and phone gates pass. Phase completion alone never authorizes push, merge,
deployment, remote CI, provider delivery, or release claims.

### R12A Backoffice/Catalog Public Contracts — Local Completion

R12A was executed locally from immutable R10/R11 entry
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. Four Backoffice authority and
mutation contracts now live only under `modules/backoffice/public`, and the
provider-rating mutation helper now lives only under
`modules/marketplace/public`. Nine fixed consumers import those owner-public
locations; all five legacy implementations are absent without facade,
duplicate, fallback, or compatibility layer.

The dependency ledger was subtracted exactly by IDs 1-6: `22 -> 17 -> 16`,
with no addition or unrelated removal. Ownership changed one approved path only
and remains `385/781`. The exact Identity-to-Marketplace runtime-public helper
edge remains declared for R16, and the R1 Backoffice permission-contract
pre-port exception remains declared for R17. R12A therefore does not claim the
architecture target complete.

Task 5 and Task 6 are independently APPROVED with no Critical, Important, or Minor finding
after a fail-closed duplicate-JSON-member security correction. Focused behavior
passed `31/31`, focused architecture `522/522`, full Backend tests passed
`1407/1408` with zero failures and one pre-existing skip, and all 30 managed
smoke packages passed. Documentation, exact scope, immutable identity, and the
final independent review also passed. R12A is complete locally. No commit, push, merge, deployment,
production mutation, remote CI, provider delivery, or release is implied.

## R9 Historical Stop Boundary

R9 is locally complete at application candidate
`0f61bf283b455c4404182f5028ab78d2448053d3`. The exact completion specification
and checked plan are under `docs/superpowers/`; the docs-only checkpoint is the
commit containing those receipts. Its stop before R10 was honored until the
owner separately approved the R10 design and plan. R10 changes none of the R9
Mobile contract. Push, merge, deployment, remote CI, store release, and S10
remain outside this local architecture wave.
