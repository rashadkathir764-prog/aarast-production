# Modular Monolith Architecture Design

**Status:** Approved architecture target, written 2026-08-04. Implementation
must not start from this file alone; each phase in the Execution Order section
requires its own plan file under `docs/superpowers/plans/` before any code
change.

This is a specification, not a plan. It defines the final state, the fate of
every current file and table, the contracts between modules, the enforcement
mechanisms, and the phase ordering. Plan files define step-by-step execution
inside one phase.

## Objective

Convert the backend, mobile app, and admin web from feature-foldered
monoliths with unrestricted cross-module access into a modular monolith with:

1. Exactly one owning module per database table.
2. Cross-module access only through declared public contracts.
3. A pure domain layer for financial invariants.
4. Machine-enforced boundaries in CI (not human discipline).
5. Zero change to external behavior: HTTP contract, database schema, mobile
   route paths, admin route paths, and all existing test expectations.

The measure of success for the whole mission: after the final phase, every
existing verification gate passes with test logic untouched, and no runtime
behavior difference is observable by the mobile app, the admin web, the smoke
suites, or a production deployment.

## Non-Goals (Explicitly Out Of Scope)

- Microservices, service extraction, or network boundaries between modules.
- PostgreSQL `multiSchema` separation (documented as possible future work).
- Materialized read models / event-sourced projections for the dashboard
  (future work; this mission composes reads over ports).
- Any new product feature, endpoint, or schema migration.
- Any change to route paths, response shapes, error codes, Arabic copy,
  permission semantics, or transaction isolation levels.
- Performance optimization beyond what the restructure preserves.
- Renaming `mobile/lib/core/` (see Review Corrections, item C1).

## Review Corrections Applied

The pre-spec discussion contained flaws. This spec is authoritative where it
differs from that discussion:

- **C1 — Mobile `core/` keeps its name and location.** Renaming to
  `platform/` and extracting a top-level `design_system/` would churn ~200
  test files and break `scripts/docs-sync.mjs` and `scripts/docs-verify.mjs`,
  which walk `mobile/lib/core/routing` by literal path. The mobile mission is
  boundaries, layering inside features, and god-file splits — not cosmetic
  renames.
- **C2 — Notification reminders stay query-based, not event-based.** The
  hourly reminder scan is a time-based repair pattern ("what is due before
  T?"). Converting it to outbox-event consumption would lose the repair
  property and change behavior. Notifications will query
  `tasks.public.listTasksDueBefore` and `finance.public.listSchedulesDueBefore`
  ports instead of raw tables.
- **C3 — `tasks` and `guests` are two separate modules.** The previously
  proposed `execution/` grouping was aesthetic, not a bounded context. Both
  are small (2 tables each) and independent.
- **C4 — Module cycles are prevented by the Public/Full NestJS module split**
  (defined below), not by `forwardRef`. `forwardRef` count must remain 0.
- **C5 — `WeddingPlan.estimatedBudget` is the single column-ownership
  exception.** Moving it to a finance table would require a schema migration
  and ripple through the mobile offline cache; the exception is declared and
  enforced instead. `User.activeWeddingPlanId` is NOT an exception: identity
  owns the `User` table and exposes a port method for it.
- **C6 — OTP is split correctly:** transport adapters (OpenWA/WhatsApp
  config, transient text, channel selection) move to `platform/otp-transport/`;
  OTP codes, dispatch quota, and verification policy remain identity domain.
  `sharing` already consumes `AuthService` for invite OTP (verified in
  `sharing/invite-access.service.ts`); it will consume
  `identity.public.InviteOtpPort` instead.
- **C7 — `@Global()` removal is deferred to the final hardening phase.**
  Boundary enforcement is primarily dependency-cruiser; removing `@Global()`
  from `PrismaModule` mid-migration would break modules not yet converted.
- **C8 — Table-ownership enforcement is staged.** Import boundaries become
  strict early (phase R3). The one-table-one-writer rule becomes strict per
  module as that module's internal phase lands, and repo-wide strict in R8.
- **C9 — `wedding_plans` mobile feature stays one feature.** The previously
  proposed three-way split (management/dashboard/contributor) has no persona
  boundary and high routing entanglement. Only the provider persona is split
  out (`provider_portal`), because it is a genuinely separate account role.

## Binding External Invariants

Every phase must preserve, and every plan file must re-verify:

| Invariant | Proof mechanism |
| --- | --- |
| HTTP routes, methods, auth flags identical | `node scripts/docs-sync.mjs --check` produces zero drift; the generated controller inventory in `docs/backend/API_CONTRACT.md` stays byte-identical (controller filenames are preserved through moves) |
| Database schema identical, zero new migrations | `npx prisma migrate diff` between the pre-split single schema and the post-split schema folder reports no difference; `prisma/migrations/` (75 directories) untouched |
| Response shapes, error codes, Arabic messages identical | existing 90 backend test files + 70 smoke scripts pass with logic untouched |
| Mobile route paths identical | `docs/frontend/MOBILE_ROUTES.md` regenerates identically; all 200 mobile test files pass |
| Admin route paths identical | `docs/frontend/ADMIN_ROUTES.md` regenerates identically; all admin tests pass |
| Transaction boundaries and isolation levels identical | serializable/row-lock call sites are moved, never re-authored; concurrency smoke suites pass |
| Deployment artifacts identical | `deploy/`, `docker-compose.yml`, Dockerfiles, ports, domains untouched |

**Test-change policy (strict):** existing test files may receive
import-path-line edits only. Any change to an assertion, fixture, setup, or
expected value is a stop signal: it means behavior changed, and the phase must
halt and be reviewed. New tests (architecture tests, new unit tests for
extracted domain code) are always additive files.

## Target Architecture

### Backend layout

```
backend/src/
├── main.ts
├── app.module.ts            (imports platform + 13 full modules only)
├── platform/                (infrastructure; zero business rules)
├── shared-kernel/           (small stable concepts shared by modules)
└── modules/
    ├── identity/
    ├── planning/
    ├── finance/
    ├── collaboration/
    ├── tasks/
    ├── guests/
    ├── marketplace/
    ├── messaging/
    ├── notifications/
    ├── catalog/
    ├── media/
    ├── insights/            (owns no tables; read composition only)
    └── backoffice/
```

### Module anatomy (uniform template)

```
modules/<name>/
├── <name>.module.ts             full NestJS module: controllers + everything
├── public/
│   ├── <name>.public-module.ts  NestJS module exporting ONLY port providers
│   ├── <name>.ports.ts          interfaces + Symbol injection tokens
│   ├── <name>.readmodels.ts     DTO types returned by ports (no internals)
│   └── <name>.events.ts         outbox event type constants (where relevant)
├── api/                         controllers, dto/, presenters (thin)
├── application/                 use cases and queries; transaction scripts
├── domain/                      pure TS policies/entities/errors
└── infrastructure/              repositories: the ONLY Prisma access
```

### The four dependency laws

1. **Import law.** Code in `modules/A/` may import from: itself,
   `modules/B/public/` (any B), `shared-kernel/`, and `platform/`. Importing
   any non-`public` path of another module is a violation.
2. **Ownership law.** Each Prisma model has exactly one owning module (see
   registry). Only the owner's `infrastructure/` may execute reads or writes
   against that model. One declared exception exists (Data Ownership
   Registry, note E1).
3. **Purity law.** `domain/` must not import `@nestjs/*` or any runtime
   Prisma service. Type-only imports of generated Prisma enums and
   `Prisma.Decimal` are permitted.
4. **Acyclicity law.** The module dependency graph (via public slices) must
   be acyclic and `forwardRef` count must remain 0.

### The Public/Full module pattern (cycle prevention)

Each module registers two NestJS modules:

- `<Name>PublicModule` provides and exports only the port implementations and
  imports only what those implementations need (typically
  `PlatformDatabaseModule`, possibly other modules' public modules — but
  never a full module).
- `<Name>Module` (full) contains controllers/schedulers/gateways and imports
  other modules' **public** modules only.

This makes bidirectional business relationships legal without cycles.
Example: `CollaborationModule` imports `NotificationsPublicModule` (to purge
money notifications inside the leave transaction) while
`NotificationsModule` imports `CollaborationPublicModule` (to check
`canViewMoney` before creating financial notifications). The two public
slices do not import each other, so the NestJS graph stays acyclic.

### Transaction propagation (UnitOfWork decision)

No AsyncLocalStorage magic. The existing pattern is kept and formalized:

- `platform/database/` exports `type Tx = Prisma.TransactionClient` and the
  existing `runRetryableTransaction` helper (moved from
  `common/prisma/serializable-transaction.ts`).
- Every port method that must participate in a caller's transaction takes an
  explicit trailing `tx: Tx` parameter. Port methods without `tx` open their
  own transaction internally when needed.
- Row-lock ordering rules that exist today (request-first lock order in quote
  flows, member-row locks in permission rechecks) are preserved verbatim by
  moving the code, never rewriting it.

## Data Ownership Registry

48 Prisma models, one owner each. "Owner" = only module whose
`infrastructure/` may query the model.

| Owner | Models |
| --- | --- |
| identity | `User`, `RefreshToken`, `OtpCode`, `LoginThrottle`, `OtpDispatchQuota`, `AdminLoginChallenge`, `AdminPasswordResetChallenge`, `AccountDeletionReceipt` |
| planning | `WeddingPlan` |
| finance | `BudgetCategory`, `WeddingCost`, `CostPayment`, `PaymentSchedule` |
| collaboration | `SharedMember`, `PlanInvite`, `ContributorHistoryScope`, `ContributorTenure`, `ContributionEvent` |
| tasks | `WeddingTask`, `WeddingTaskChecklistItem` |
| guests | `Guest`, `GuestGroup` |
| marketplace | `Provider`, `ProviderService`, `ProviderServiceImage`, `ProviderPackage`, `FavoriteProvider`, `ProviderReview`, `QuoteRequest`, `QuoteOffer`, `PlanProviderLink` |
| messaging | `Conversation`, `ConversationParticipant`, `ConversationEvent`, `ChatMessage`, `ChatAttachment`, `ConversationReport` |
| notifications | `Notification`, `NotificationPreference`, `PushInstallation` |
| catalog | `Governorate`, `District`, `City`, `ProviderCategory` |
| media | `MediaUploadTicket` |
| backoffice | `AdminAuditLog` |
| platform | `OutboxEvent`, `IdempotencyKey` |
| insights | (none — read composition over ports only) |

Registry rules:

- **E1 (single declared exception):** `WeddingPlan.estimatedBudget` is
  written only by `finance/infrastructure/`. `planning` never writes this
  column; `planning` read models may include it (it lives on planning's row).
  The ownership architecture test encodes exactly this one exception.
- **Foreign keys across contexts are allowed** (they are schema-level
  integrity, unchanged). The writer rule applies to query execution, not to
  FK declarations.
- **Cross-module reads** go through the owner's port or read models. A module
  never `include`s another module's relation in a Prisma query; it queries
  its own tables and asks ports for the rest. (Existing `include` chains are
  replaced during each module's internal phase; until then the staged
  enforcement of C8 applies.)
- `User.activeWeddingPlanId` is identity-owned; identity exposes
  `setActivePlanPointer(userId, planId | null, tx)` for planning (onboarding)
  and collaboration (self-leave clears it).

## Module Contracts

Port names below are binding. Method lists are the minimum complete set
discovered from current cross-module usage; plan files may add methods only
if a previously undiscovered call site requires it, and must record the
addition in the phase report.

### platform (not a module; no business rules)

- `database/`: PrismaService, PrismaModule, `Tx`, `runRetryableTransaction`.
- `outbox/`: existing outbox service/worker/dispatcher/constants, unchanged
  semantics; modules enqueue via `OutboxService` within their transactions.
- `otp-transport/`: OpenWA/WhatsApp channel adapters and transient text
  building. Consumed only by identity. No quota or verification logic here.
- `idempotency/`, `observability/`, `redis/`, `http/` (filters, pagination,
  bounded JSON), `config/`, `health/`.
- `health/` merges root `health.controller.ts` + `health/readiness.service.ts`
  keeping `/health`, `/live`, `/ready` byte-identical.

### shared-kernel

- `money/`: `Money` value object built around the existing bounded
  `numeric(14,2)` validator from `common/validation/money.ts` (construction,
  comparison, addition, subtraction, non-negativity; `Prisma.Decimal`-backed).
  The validator's current error behavior is preserved exactly.
- `phone/`: phone normalizer (moved from `common/phone/`).
- `privacy/`: review-identity masking + admin privacy redaction helpers.
- `time/`: business-day helper.
- Shared-kernel code depends on nothing outside itself and never touches the
  database.

### identity

- Owns auth (app + admin MFA), sessions, throttling, OTP lifecycle, profile,
  settings, account contexts resolution, and the account-deletion saga.
- `public/identity.ports.ts`:
  - `SessionAssertPort.assertLiveSession(token) ` — used by messaging socket
    auth and backoffice session revocation checks.
  - `UserReadPort.getSafeUser(userId)`, `getAppIdentities(userIds)` — the
    safe-user projection used across modules today.
  - `InviteOtpPort.dispatchInviteOtp(...)`, `verifyInviteOtp(...)` — wraps
    what `sharing/invite-access.service.ts` currently calls on `AuthService`.
  - `ActivePlanPort.setActivePlanPointer(userId, planId | null, tx)`.
  - `SessionRevocationPort.revokeUserSessions(userId, tx)` — used by
    backoffice user-status actions.
- Exports (deliberately, from `public/`): `JwtAuthGuard`, `JwtSessionGuard`,
  `CurrentUser` decorator, `AuthenticatedUser` type, access-token scope
  helpers. These are cross-cutting API-layer concerns every module consumes.
- **Account deletion saga:** identity's `delete-account.usecase` opens the
  single retryable serializable transaction (exactly as today), then invokes
  `AccountErasurePort.eraseForUser(userId, tx)` implemented by every
  table-owning module, in a fixed order lifted verbatim from the current
  `users.service.ts` delete sequence (the current deleteMany order is the
  specification of FK-safe order). Identity itself erases its own tables and
  writes the `AccountDeletionReceipt` last, unchanged. The public deletion
  status endpoint stays in identity's api layer.

### planning

- Owns `WeddingPlan` lifecycle: create, update, archive, delete; onboarding
  completion; local-plan import; wedding location rules.
- `public/planning.ports.ts`:
  - `PlanAccessPort.getPlanOwnership(planId)`, `assertPlanExists(planId)`.
  - `PlanReadPort.getPlanCore(planId)`, `listOwnedPlanIds(userId)`.
  - `PlanCascadePort.deletePlanGraphHooks` is NOT created — plan deletion is
    a planning use case that calls other modules' erasure/cleanup ports
    (mirror of the account saga, order lifted from current code).
- Plan archive keeps its current atomic side effect (revoking live pending
  invitations) by calling `collaboration.public.revokeLivePlanInvites(planId,
  tx)`.

### finance

- Owns the money domain: general budget (E1 column), categories, costs,
  payments, schedules, money summary.
- Absorbs `money/`, `budget-categories/`, `wedding-costs/` and
  `marketplace/quote-cost-category.ts` (category matching including the
  normalized-alias logic and the `أخرى` fallback).
- `domain/` (pure): `WeddingCostAggregate` invariants (positive amounts,
  `paidAmount ≤ totalAmount`, mandatory category, one reversal per payment),
  `PaymentSchedulePolicy` (non-reserving reminders, independent cap against
  row-locked outstanding, full payment cancels pending schedules),
  `BudgetAllocationPolicy` (allocations never substitute the general budget),
  `CostCategoryMatching`.
- `public/finance.ports.ts`:
  - `FinancePort.createCostFromAcceptedOffer(input, tx)` — the atomic seam
    for quote acceptance; validates all invariants inside; idempotent per
    accepted offer exactly as today.
  - `FinancePort.getPlanMoneySummary(planId)` — for insights.
  - `FinancePort.listSchedulesDueBefore(instant)` — for the notifications
    reminder scan (C2).
  - `AccountErasurePort` implementation.
- `public/finance.events.ts`: existing outbox event types that finance emits
  today (none are added; constants relocate with their emitters).

### collaboration

- Owns sharing, invites, permissions, contributor tenures, and the
  append-only contribution history.
- `domain/`: permission model (`plan-permissions.ts`), invite lifecycle
  policy, snapshot allowlists (`contribution-snapshot.builder` logic).
- `public/collaboration.ports.ts`:
  - `PermissionReadPort.getMemberPermissions(planId, userId)`,
    `assertSection(planId, userId, section)` — the single authority every
    module consults; replaces today's direct imports of
    `sharing/permission.service.ts`.
  - `PermissionLockPort.lockMemberAndAssertPermissions(planId, userId,
    flags, tx)` — preserves the locked shared-member recheck inside quote
    acceptance and money mutations.
  - `ContributionRecorderPort.recordEvent(input, tx)` — for tasks, guests,
    finance, marketplace action-time snapshots.
  - `ContributorScopePort.getScope(planId, userId)` — the assignment/own-
    actions filter used by tasks/guests/money/marketplace/dashboard reads.
  - `revokeLivePlanInvites(planId, tx)`, `revokeInvitesForRemovedUser(...)`.
  - `AccountErasurePort` implementation.
- Consumes: `identity.public` (invite OTP, active-plan pointer, safe users),
  `messaging.public` (revoke conversation participation on leave/removal),
  `notifications.public` (purge plan money notifications in the leave
  transaction), `platform/outbox`.

### tasks

- Owns `WeddingTask`, `WeddingTaskChecklistItem`. Task CRUD, assignment,
  checklist, due handling.
- `public/tasks.ports.ts`: `listTasksDueBefore(instant)` (C2),
  `TaskReadPort.getPlanTaskCounters(planId, scope)` (insights),
  `AccountErasurePort`.
- Consumes: `collaboration.public` (permissions + contributor scope +
  contribution events), `notifications.public.NotificationWriterPort`
  (assignment/due notifications created in-transaction, exactly as today).
- The stable denial contract (`403` / `TASK_PERMISSION_REVOKED` / Arabic
  message) is owned here and must not change.

### guests

- Owns `Guest`, `GuestGroup`. Same consumption pattern as tasks.
- `public/guests.ports.ts`: `GuestReadPort.getPlanGuestCounters(planId,
  scope)`, `AccountErasurePort`.

### marketplace

- Owns provider catalog entities, favorites, reviews (including the
  rating-cache recompute under ordered provider-row lock), quote requests,
  quote offers, plan-provider links, and the provider portal operations
  (absorbs `provider-dashboard/`).
- Internal submodule folders: `api/` splits customer-facing
  (`marketplace.controller`) and provider-facing (`provider-dashboard`
  controllers) but they share one module, one `public/`, one repository
  layer.
- The seven `quote-*.ts` transaction scripts move intact into
  `application/quotes/` — they are already well-factored; only their
  cross-module calls change: cost creation via
  `finance.public.createCostFromAcceptedOffer(tx)`, permission rechecks via
  `collaboration.public.PermissionLockPort`, notifications via
  `notifications.public`, conversation timeline events via
  `messaging.public`.
- `public/marketplace.ports.ts`: `ProviderReadPort.getProviderContext(userId)`
  (used by identity contexts + notifications), `getPublicProviderCards(ids)`
  (insights favorites), `QuoteReadPort` (insights + messaging entry checks),
  `AccountErasurePort` (includes review purge + rating recompute currently in
  `users.service.ts`).

### messaging

- Owns conversations, participants, events, chat messages/attachments,
  reports. Socket gateway and rooms.
- `conversation-realtime.module.ts` loses `@Global()` in R8; its publisher is
  exported through `messaging.public` (and consumed by platform/outbox worker
  for recovery events, as today).
- `public/messaging.ports.ts`: `ConversationLifecyclePort.ensureQuoteConversation(...,
  tx)`, `appendSystemEvent(..., tx)` (quote/offer events),
  `revokeParticipation(userId, planId | null, tx)`,
  `ModerationPort` (backoffice report actions), `AccountErasurePort`.
- Socket authentication uses `identity.public.SessionAssertPort` instead of
  querying `refreshToken`/`user` directly.

### notifications

- Owns notification rows, preferences, push installations; absorbs `push/`
  as `infrastructure/push/` (Firebase client is an adapter).
- `public/notifications.ports.ts`:
  - `NotificationWriterPort.create(input, tx)`,
    `purgePlanMoneyNotifications(userId, planId, tx)` — transactional, used
    by tasks/marketplace/collaboration exactly where notifications are
    created/purged today.
  - `AccountErasurePort` (notifications + preferences + push bindings).
- The reminder scheduler consumes `tasks.public.listTasksDueBefore` and
  `finance.public.listSchedulesDueBefore`, and
  `collaboration.public.PermissionReadPort` for `canViewMoney` audience
  filtering (C2). Server-side redaction of financial admin notifications
  stays inside this module using `shared-kernel/privacy`.

### catalog

- Owns Yemen administrative references and provider categories. Public read
  API (current routes move unchanged), encrypted-cache contract untouched.
- `public/catalog.ports.ts`: `CatalogReadPort.getCities/Governorates/
  Districts/Categories`, `CatalogAdminPort` (backoffice CRUD; slug
  reconciliation rules move here).

### media

- Owns upload tickets, verification/sanitization pipeline, signed URLs,
  cleanup scheduler.
- `public/media.ports.ts`: `MediaVerifyPort.assertOwnedVerifiedImage(...)` —
  the re-verification used by avatar/provider/chat persistence paths,
  `issueSignedDownload(...)`, `AccountErasurePort` (ticket cleanup).

### insights

- Owns no tables. Absorbs `dashboard/` and `timeline/`.
- Every query the dashboard service makes today against the 12 foreign tables
  is re-expressed as a port call to the owning module. Response shapes and
  the priority/presenter logic move unchanged.
- This module is the sanctioned high-fan-in consumer; its dependency list
  (most public modules) is expected and legal.

### backoffice

- Owns `AdminAuditLog`, admin guard/permission decorators, mutation gate and
  executor, admin presenters.
- All domain mutations (provider lifecycle, review moderation, conversation
  reports, catalog CRUD, user status, notifications admin) become port calls
  to the owning modules. `common/admin/admin-permissions.ts` moves to
  `backoffice/domain/`.
- Admin auth challenges/MFA remain identity; backoffice consumes
  `identity.public`.

## Backend File Fate Map

Verbs: **MOVE** (content unchanged, path/imports updated), **MERGE** (absorbed
into another unit), **SPLIT** (divided by layer/use case), **REWRITE**
(logic redistributed across layers; behavior identical), **PORT** (its
cross-module queries become port calls), **DISSOLVE** (file/folder ceases to
exist; contents redistributed), **NEW**.

Root files: `main.ts` MOVE-nothing (stays); `app.module.ts` REWRITE (imports
platform + 13 modules); `health.controller.ts` + `health/` MERGE →
`platform/health/`.

| Current path | Fate → Destination |
| --- | --- |
| `common/config/*` (3) | MOVE → `platform/config/` |
| `common/filters/*`, `common/http/*`, `common/pagination/*` | MOVE → `platform/http/` |
| `common/idempotency/*` (4) | MOVE → `platform/idempotency/` |
| `common/observability/*` (4) | MOVE → `platform/observability/` |
| `common/redis/*` (2) | MOVE → `platform/redis/` |
| `common/prisma/serializable-transaction.ts` | MOVE → `platform/database/` |
| `common/validation/money.ts` | REWRITE → `shared-kernel/money/` (validator preserved verbatim inside the VO) |
| `common/phone/phone-normalizer.ts` | MOVE → `shared-kernel/phone/` |
| `common/privacy/review-identity.ts` | MOVE → `shared-kernel/privacy/` |
| `common/time/business-day.ts` | MOVE → `shared-kernel/time/` |
| `common/admin/admin-permissions.ts` | MOVE → `modules/backoffice/domain/` |
| `common/` (folder) | DISSOLVE |
| `prisma/prisma.{module,service}.ts` | MOVE → `platform/database/` (`@Global()` removed only in R8) |
| `outbox/*` (7) | MOVE → `platform/outbox/` |
| `auth/auth.service.ts` (2,504) | SPLIT → `identity/application/` use cases: register, login, verify-otp, refresh-session, password-reset, admin-mfa-login, logout; OTP dispatch/verify code consumed by `InviteOtpPort` |
| `auth/auth.controller.ts` + `auth/dto/*` (14) | MOVE → `identity/api/` |
| `auth/jwt-*.ts`, `*.guard.ts`, `jwt.strategy.ts`, `current-user.decorator.ts`, `authenticated-user.interface.ts`, `access-token-scope.ts`, `safe-user.ts` | MOVE → `identity/public/` |
| `auth/login-throttle.service.ts` + scheduler, `auth/otp-dispatch-quota.service.ts` + scheduler, `auth/auth-challenge-cleanup.scheduler.ts` | REWRITE → `identity/{domain,infrastructure}/` (policy vs persistence) |
| `auth/auth-error.ts`, `refresh-token-policy.ts`, `jwt-secret.ts`, `otp-channel.ts` | MOVE → `identity/domain/` (channel selection interface; adapters below) |
| `auth/openwa-otp-config.ts`, `openwa-transient-text.ts`, `whatsapp-otp-config.ts` | MOVE → `platform/otp-transport/` |
| `users/users.service.ts` (827) | REWRITE → `identity/application/` (profile, settings, lookup) + deletion saga; per-module erasure logic emigrates to each owner's `AccountErasurePort` impl, order preserved verbatim |
| `users/*` (rest) | MOVE → `identity/api/` + `identity/domain/` (`user-lifecycle-lock`, `application-user-identity`) |
| `me/me.controller.ts` | MERGE → `identity/api/me.controller.ts`; `me/` DISSOLVE |
| `contexts/*` (5) | PORT → `identity/application/resolve-contexts.usecase.ts` (+ api dto); queries provider/sharedMember/weddingPlan via ports |
| `wedding-plans/wedding-plans.service.ts` (999) | SPLIT+PORT → `planning/application/`; plan-graph deletion becomes ordered erasure-port calls |
| `wedding-plans/*` (rest) | MOVE → `planning/{api,domain}/` |
| `onboarding/*` | MERGE → `planning/application/complete-onboarding.usecase.ts` + `planning/api/`; `onboarding/` DISSOLVE |
| `money/*`, `budget-categories/*`, `wedding-costs/*` (folders) | DISSOLVE → `modules/finance/` per the finance contract above; `wedding-costs.service.ts` (1,855) SPLIT into ≤6 use cases + repository; presenters → `finance/api/presenters/` |
| `sharing/sharing.service.ts` (3,087) | SPLIT → `collaboration/application/invites/` (create, reissue, deliver-result, verify, accept, decline, revoke) + `collaboration/application/members/` (add, update+revocation-atomicity, remove, self-leave) |
| `sharing/permission.service.ts` (644), `plan-permissions.ts` | REWRITE → `collaboration/domain/permissions/` + port impl in `public/` |
| `sharing/invitation-delivery.service.ts` | PORT → `collaboration/infrastructure/` consuming `identity.public.InviteOtpPort` |
| `sharing/invite-access.service.ts`, dto (6) | MOVE → `collaboration/{application,api}/` |
| `contribution-history/*` (7) | MOVE → `collaboration/contributions/` (builder → domain; append-only store → infrastructure; controller → api) |
| `tasks/*` | REWRITE → `modules/tasks/` 4-layer; `tasks.service.ts` (1,056) SPLIT |
| `guests/*` | REWRITE → `modules/guests/` 4-layer; `guests.service.ts` (1,183) SPLIT |
| `marketplace/quote-*.ts` (7) | MOVE+PORT → `marketplace/application/quotes/` |
| `marketplace/quote-cost-category.ts` | MOVE → `finance/domain/cost-category-matching.ts` |
| `marketplace/yemen-administrative.presenter.ts` | MOVE → `catalog/api/` |
| `marketplace/marketplace.service.ts` (948), presenter (576), rating, locks, contributor scope, dto (6) | SPLIT+PORT → `marketplace/{api,application,domain,infrastructure}/` |
| `provider-dashboard/*` (14) | MERGE → `marketplace/` (`api/provider/`, `application/provider/`, `domain/provider-access-policy`, locks → infrastructure); folder DISSOLVE |
| `conversations/*` (11) | REWRITE → `modules/messaging/` 4-layer; gateway+rooms → `api/realtime/`; `conversations.service.ts` (1,384) SPLIT; socket auth via identity port |
| `notifications/*` (4) | REWRITE → `modules/notifications/`; `notifications.service.ts` (2,194) SPLIT (creation policy / queries / preferences); reminder scheduler per C2 |
| `push/*` (7) | MERGE → `notifications/infrastructure/push/` + `notifications/api/push.controller.ts`; folder DISSOLVE |
| `media/*` (9) | MOVE → `modules/media/` 4-layer (sanitizer → domain-adjacent infrastructure; policy → domain) |
| `dashboard/*` (8) | PORT → `modules/insights/` (contracts/presenter/priority MOVE; service+queries re-expressed over ports) |
| `timeline/*` (3) | MERGE → `insights/application/timeline.query.ts` + api; folder DISSOLVE |
| `admin/*` (25) | REWRITE → `modules/backoffice/`; audit trio MOVE (owned tables); guard/decorators → `api/security/`; mutation gate/executor → `application/`; all domain touches become port calls |
| `prisma/seed.ts` | SPLIT → thin entry calling per-module seed functions (entry path unchanged for `prisma.config.ts`) |

Files not listed above (dto folders already mapped with their modules,
`app.module.ts`, `main.ts`) follow their parent's row.

## Prisma Fate Map

- `prisma/schema.prisma` (1,356 lines) DISSOLVE → `prisma/schema/` folder,
  one file per owner exactly matching the Data Ownership Registry (13 files:
  12 owners + `platform.prisma`), plus `_base.prisma` holding
  `generator`/`datasource` blocks.
- `prisma.config.ts` updated: `schema: "prisma/schema"`. Prisma 6.19.3
  supports multi-file schema natively (GA).
- Gate: `prisma migrate diff --from-schema-datamodel <old> --to-schema-datamodel <new>`
  must report no difference; `prisma generate` output must be functionally
  identical; `prisma/migrations/` (75) and migration history untouched; zero
  new migrations in the entire mission.
- `seed.ts` split is content-mechanical; seeded data byte-identical.

## Mobile File Fate Map (`mobile/lib/`)

Scope corrected per C1/C9 — no top-level renames; `core/` stays.

| Item | Fate |
| --- | --- |
| `core/**` (all folders) | UNCHANGED in place. Internal exception: `core/utils/phone_normalizer.dart` (5-line wrapper) DISSOLVE — callers import `core/phone/` directly |
| `features/auth/utils/yemeni_phone_normalizer.dart` (1-line re-export) | DISSOLVE — callers import `core/phone/yemeni_phone_normalizer.dart` |
| `shared/models/quote_finance_context.dart` | MOVE → owning feature (`features/finance/models/`); `shared/models/contact_phone_draft.dart` + `shared/widgets/contact_phone_field.dart` stay (genuinely shared) |
| Every `features/<f>/` | NEW `features/<f>/<f>_api.dart` barrel exporting the feature's cross-feature surface (models, providers, screens actually consumed externally). Cross-feature imports must target the barrel only; intra-feature imports unchanged |
| `features/marketplace/` | SPLIT → `features/marketplace/` (customer discovery: marketplace screens, provider details, favorites, quote request) + `features/provider_portal/` NEW (provider persona: portal screen/tabs, apply, profile/services/packages management, requests tab, portal nav). `marketplace_provider.dart` (1,514) SPLIT along the same line. Route paths and names in `app_router.dart` unchanged (imports only) |
| God files | SPLIT keeping public class names: `invite_decision_screen.dart` (1,835), `finance_api.dart` (1,727), `plan_management_screen.dart` (1,497), `contributor_workspace_view.dart` (1,178), `task_timeline_screen.dart` (1,114), `auth_controller.dart` (1,068), `app_router.dart` (1,064 → split route trees per area file, single router assembled). Touched files target ≤ 700 lines |
| `mobile/test/**`, `integration_test/**` | Import-path edits only (per the test-change policy) |
| Platform folders (`android/ ios/ web/ ...`), `pubspec.yaml` deps | UNCHANGED |

Mobile boundary enforcement: NEW `scripts/check-mobile-boundaries.mjs`
(node, consistent with existing repo scripts) verifying: (a) cross-feature
imports go through `<f>_api.dart` barrels; (b) `core/` never imports
`features/`; (c) declared feature dependency list (recorded in
`ARCHITECTURE.md`) is respected. Wired into CI mobile job.

## Admin Web File Fate Map (`admin-web/src/`)

| Current | Fate |
| --- | --- |
| `api/client.ts` (+test) | MOVE → `platform/api/` |
| `api/admin.ts` (574) | SPLIT → `features/<area>/api.ts` per area below |
| `api/auth.ts` (+test) | MOVE → `features/auth/api.ts` |
| `auth/*` (9) + `LoginPage` | MOVE → `features/auth/` |
| `components/*` (24) | MOVE → `design_system/` (ErrorBoundary → `platform/`) |
| `layout/*` (3) | MOVE → `layout/` (unchanged) |
| `pages/*` | DISSOLVE → `features/{dashboard,users,providers,catalog,moderation,notifications,audit}/` — Users+UserDetails→users; Providers+Details+Applications+helpers→providers; Categories+Cities+Services→catalog; Reports+ConversationReports+Reviews→moderation; AuditLogs→audit; contract tests move beside their feature |
| `App.tsx`, `main.tsx`, `styles/`, `test/setup.ts` | UNCHANGED paths (route table in `App.tsx` gets import-only edits) |

All files remain under `admin-web/src/` (docs tooling walks it recursively).
Route paths unchanged; `ADMIN_ROUTES.md` regenerates identically.

## Enforcement Tooling (NEW files)

- `/.dependency-cruiser.cjs` — encodes the four dependency laws for
  `backend/src`: module-boundary rule (only `public/` importable across
  modules), platform/shared-kernel direction rules, domain purity rule,
  cycle detection. Phase R0 ships it with the current violations frozen as a
  named baseline; R3 deletes the baseline for import rules; R8 deletes all
  baselines.
- `backend/test/architecture/ownership.test.ts` — parses
  `infrastructure/`-external Prisma access and asserts the Data Ownership
  Registry (with staged per-module strictness per C8, and the single E1
  exception).
- `backend/test/architecture/ports.test.ts` — asserts every cross-module DI
  token resolves through a `public/` path and `forwardRef` count is 0.
- `scripts/check-mobile-boundaries.mjs` — mobile rules above.
- `ARCHITECTURE.md` (repo root) — human-readable statement of the laws, the
  ownership registry, the module map, and the mobile feature dependency
  list. `AGENTS.md` gains a short section pointing to it and forbidding
  boundary violations in future work.
- CI (`.github/workflows/ci.yml`): backend job adds dependency-cruiser +
  architecture tests; mobile job adds the boundary script; docs job
  unchanged (its byte-identical outputs are themselves a gate).

## Execution Order

Phases are strictly ordered; each phase = at least one plan file. A phase
may not start until the previous phase's exit gate passed. Every phase's
exit gate includes: `npm run check` + `npm test` (backend), affected smoke
suites (full `smoke:all` at R3, R8, R10), `flutter analyze` + `flutter test`
(when mobile touched), admin `build`+`test` (when admin touched),
`node scripts/docs-sync.mjs --check`, `node scripts/docs-verify.mjs`,
`git diff --check`, dependency-cruiser, architecture tests at their current
strictness, and the test-change policy audit (diff shows import-line-only
edits in existing tests).

| Phase | Content | Key exit criteria beyond the standard gate |
| --- | --- | --- |
| **R0 Governance** | `ARCHITECTURE.md`, ownership registry, dependency-cruiser with frozen baseline, architecture tests in report mode, CI wiring, `AGENTS.md` section | zero source file moves; CI green with new jobs |
| **R1 Platform + shared-kernel** | Execute the `common/`, `prisma/`(client), `outbox/`, `health`, otp-transport rows of the fate map; repo-wide import updates | `common/` gone; docs-sync output byte-identical |
| **R2 Schema folder split** | Prisma fate map | `migrate diff` empty; zero migrations; smoke migration suites pass |
| **R3 Ports-first strangler** | Create all 13 `public/` slices as facades delegating to the existing services in place; convert every cross-module import/injection to ports; Public/Full module split; socket auth via identity port | dependency-cruiser import rules strict (baseline deleted); forwardRef=0; full `smoke:all`; may be split into ~4 plan files by consumer cluster |
| **R4 Finance internal** | Dissolve money/budget-categories/wedding-costs into `modules/finance/`; domain layer; repository; god-file split; category matching absorbed | ownership strict for finance's 4 tables + E1; money/financial-ledger/concurrency smokes pass |
| **R5 Identity internal** | Auth service split; deletion saga via erasure ports (order preserved); throttle/quota layering | ownership strict for identity's 8 tables; account-deletion + auth smokes pass |
| **R6 Collaboration internal** | Sharing split; permission domain; contributions relocation; invite delivery via identity port | ownership strict for collaboration's 5 tables; sharing-security 38/38, sharing-concurrency, contributor-history smokes pass |
| **R7 Remaining modules internal** | tasks, guests, marketplace(+provider-dashboard merge), messaging, notifications(+push), media, catalog extraction | ownership strict for their tables; provider/quote/conversation/notification smokes pass |
| **R8 Consumers + hardening** | insights and backoffice re-expressed over ports; `@Global()` removals; repo-wide strict ownership; delete all baselines | zero direct Prisma access outside owners; full `smoke:all`; all 90 tests logic-untouched |
| **R9 Mobile** | Barrels + boundary script strict; provider_portal split; god-file splits; phone consolidation; shared/ redistribution | all 997+ tests pass; `MOBILE_ROUTES.md` identical; boundary script green |
| **R10 Admin + closeout** | Admin restructure; docs refresh (`docs/backend/README.md`, `docs/frontend/*` architecture references, `CHANGELOG.md`); final full verification; final report under `docs/superpowers/reports/` | every binding invariant re-proven in one run; `ADMIN_ROUTES.md` identical |

Dependency notes for planners: R3 is the pivot — after it, R4–R7 are
internally independent of each other except: R4 before the marketplace part
of R7 (acceptance seam), R5 before R6 (invite OTP port), R5 before R8
(erasure ports must exist before backoffice/user flows finalize). R9 and R10
depend only on R8.

## Risk Register

| Risk | Containment |
| --- | --- |
| Hidden behavior coupling inside `sharing.service.ts` / `auth.service.ts` splits | splits are mechanical extraction of whole methods; any needed signature change stops the phase; sharing-security and concurrency smokes are the oracle |
| Transaction/lock-order drift while moving quote acceptance and money mutations | lock-order code moves verbatim; concurrency smoke suites (`phase2-*`) are mandatory in R4/R6/R7 gates |
| Deletion-saga reordering breaking FK constraints | current deleteMany order is copied into the saga as a numbered contract; account-deletion smoke covers all four lifecycles |
| NestJS DI cycles when ports go live | Public/Full pattern + forwardRef=0 assertion in architecture tests |
| docs tooling breakage from moves | tooling walks roots recursively; the only literal path (`mobile/lib/core/routing`) is preserved by C1; byte-identical generated docs are a per-phase gate |
| Long-running mission drift across many agents | every phase re-reads this spec; deviations require updating this spec first, in the same change, with the reason recorded |

## Glossary

- **Port**: a TypeScript interface + injection token exported from a module's
  `public/`, implemented inside that module.
- **Public slice**: `<Name>PublicModule`, the NestJS module exporting only
  port providers.
- **Erasure port**: the per-module `AccountErasurePort` used by identity's
  deletion saga and planning's plan-graph deletion.
- **Strangler facade**: an R3 port implementation that delegates to the
  pre-existing service before internal restructure replaces it.
- **Baseline**: a frozen list of pre-existing violations that new code may
  not extend; deleted when the corresponding phase lands.
