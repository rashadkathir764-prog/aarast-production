# Modular Monolith R1 Platform and Shared Kernel Design

**Status:** Approved for planning

**Date:** 2026-08-12

**Planning base:** externally verified R0 candidate `94b677b7b8e2219e0db2cbc553fa3d26b4876456`

**Execution base:** the immutable merge revision of R0 PR #76, to be recorded before R1 implementation starts

## Objective

R1 dissolves the legacy Backend infrastructure roots into `src/platform/`,
creates the foundational `src/shared-kernel/`, relocates the current
backoffice permission domain helper, and updates every repository consumer
without changing product or runtime behavior.

R1 is complete only when:

- `backend/src/common/` no longer exists;
- `backend/src/prisma/prisma.module.ts` and `prisma.service.ts` have moved to
  `backend/src/platform/database/` while `@Global()` remains in place;
- `backend/src/outbox/`, root health files, and concrete OTP transport code
  have moved to their target platform folders;
- the shared-kernel contains the Money value object and the existing phone,
  privacy, application-identity, and business-day helpers without importing a
  business or platform source path;
- all source, test, smoke, package-script, documentation, and architecture-tool
  references use the new paths;
- the dependency and ownership baselines change only through reviewed path
  relocation or debt removal, never through new semantic debt;
- generated documentation is byte-identical before and after R1, except for
  explicitly regenerated script inventory rows caused by a package-script path
  change;
- all R1 quality gates are green on one immutable candidate revision.

## Non-Goals

R1 does not:

- create the 13 business `PublicModule`/`InternalModule` slices or business
  ports; that is R3;
- split the Prisma schema or add a migration; that is R2;
- split business services or change model ownership; that is R4-R8;
- remove `@Global()` from `PrismaModule`; that is R8;
- modify routes, response bodies, error codes/messages, Arabic product copy,
  permissions, transaction boundaries, lock order, retry behavior, database
  schema, deployment artifacts, Mobile source, or Admin Web source;
- use compatibility barrels, old-path re-exports, duplicate implementations,
  fallback imports, or temporary aliases to keep both layouts alive.

## Source-of-Truth Corrections

The 2026-08-04 external architecture design remains the target architecture,
but these live facts supersede stale statements in that file:

1. The R0 registry and live Prisma tree contain 52 models and 76 committed
   migrations, not 48/75.
2. `WeddingPlan` is physically owned only by planning. Finance access to
   `WeddingPlan.estimatedBudget` remains frozen debt for R4, not a permanent
   exception.
3. The existing `auth/otp-channel.ts` combines identity policy contracts,
   development behavior, and concrete production transports. R1 splits that
   file at the real responsibility boundary instead of moving it wholesale.
4. `common/privacy/review-identity.ts` currently imports
   `users/application-user-identity.ts`. The application identity helpers are
   shared presentation/privacy rules and move with it into shared-kernel so
   shared-kernel has no business-source dependency.
5. Moving the current platform roots exposes six already-baselined
   platform-to-business dependencies: runtime config to JWT validation, health
   to media readiness, and outbox dispatch/module wiring to messaging and push.
   R1 may relocate those exact known edges; it may not add a new edge. R3 must
   eliminate them when the public/DI seams are introduced.
6. `sharing/invitation-delivery.service.ts` currently calls the OpenWA
   transient transport directly. R1 updates that import to the platform
   transport and records it as existing business-to-platform usage. It does not
   introduce an identity port early; the owning port transition remains R6.

## Chosen Delivery Shape

R1 uses one implementation plan with six independently reviewable execution
checkpoints:

1. immutable preflight, contract tests, and exact move/debt manifests;
2. platform database, configuration, HTTP, Redis, observability, and health;
3. platform idempotency and outbox runtime paths;
4. production OTP transports and the identity-owned channel contract split;
5. shared-kernel plus backoffice permission relocation and final dissolution of
   `common/`;
6. architecture-baseline reconciliation, CI transition, exhaustive verification,
   and the completion receipt.

This is preferred over two separate R1 plan files because neither a platform-
only nor shared-kernel-only half can satisfy the `common/` removal exit gate.
It is preferred over one large relocation task because path, baseline, and test
policy changes would become too large to review causally.

## Target Layout

```text
backend/src/
  platform/
    config/
      cors-options.ts
      cors-origins.ts
      runtime-environment.ts
    database/
      prisma.module.ts
      prisma.service.ts
      serializable-transaction.ts
    health/
      health.controller.ts
      readiness.service.ts
    http/
      bounded-json-response.ts
      global-exception.filter.ts
      list-query.dto.ts
    idempotency/
      idempotency.interceptor.ts
      idempotency-cleanup.scheduler.ts
      idempotency-reconcile.cli.ts
      idempotency-reconciliation.ts
    observability/
      metrics.controller.ts
      metrics.ts
      request-observability.middleware.ts
      sanitize-request-target.ts
    otp-transport/
      otp-delivery.ts
      openwa-otp-config.ts
      openwa-otp.channel.ts
      openwa-transient-text.ts
      whatsapp-otp-config.ts
      whatsapp-otp.channel.ts
    outbox/
      outbox.constants.ts
      outbox.dispatcher.ts
      outbox.module.ts
      outbox.service.ts
      outbox.worker.ts
      outbox-cleanup.scheduler.ts
      realtime-revocation.ts
    redis/
      redis-io.adapter.ts
      resilient-throttler-storage.ts
  shared-kernel/
    money/
      money.ts
    phone/
      phone-normalizer.ts
    privacy/
      admin-notification-privacy.ts
      application-user-identity.ts
      review-identity.ts
    time/
      business-day.ts
  modules/
    backoffice/
      domain/
        admin-permissions.ts
```

No old-path facade or barrel is retained. Consumers import the concrete target
file required by their current responsibility.

## Platform Boundary Decisions

### Database

`PrismaService`, `PrismaModule`, `Tx`, and
`runSerializableTransaction`/`runRetryableTransaction` move together to
`platform/database`. The decorator set, provider/export arrays, lifecycle
methods, transaction isolation level, retry classification, and retry timing
remain byte-for-byte equivalent except for imports and formatting forced by the
move. `PrismaModule` remains one of exactly two approved global modules.

### Health

The root controller and readiness service move into `platform/health` while
`/health`, `/live`, and `/ready` metadata and response/error behavior remain
identical. The current readiness dependency on `MediaStorageService` is not
reimplemented or hidden. It remains one exact baselined platform-to-media edge
until R3 introduces the application-composition seam.

### Idempotency and Outbox

Idempotency and outbox files move without behavioral rewriting. The production
script `prod:reconcile-idempotency` must point to
`dist/platform/idempotency/idempotency-reconcile.cli.js`. Scheduler intervals,
advisory locks, transactions, retry/backoff, event names, payload validation,
logging safety, exports, and module wiring are preserved.

The current outbox dispatcher/module imports of messaging and push are existing
R0 debt. After relocation, their six-edge platform debt set must be a path-
mapped subset of the R0 baseline; the plan may not normalize it into a permanent
permission.

### OTP Transport

R1 separates the mixed `auth/otp-channel.ts` file as follows:

- identity-owned current file: the delivery-channel selection contract,
  `DevEchoOtpChannel`, and the six-digit cryptographic code generator; it
  remains under `auth/` until R5 moves identity internals;
- platform-owned files: the delivery result/uncertainty contract, concrete
  `WhatsAppOtpChannel` and `OpenWaOtpChannel`, their transport-specific errors,
  configuration loaders, and transient text sender;
- `AuthService` generates the code inside identity, then selects and consumes a
  delivery-only platform adapter through the structural delivery contract;
- no file under `platform/otp-transport` imports `randomInt`, exposes
  `generateCode`, or chooses OTP policy;
- platform adapter code does not import from `auth/` or another business root;
- generation format, timeout handling, provider acknowledgement semantics,
  secret-safe failures, OpenWA credential rotation, and response mapping remain
  unchanged.

The existing sharing transient-message consumer imports the platform sender
directly until its R6 port migration. This is explicit migration debt, not a
new public API promise.

## Shared-Kernel Decisions

### Money

`shared-kernel/money/money.ts` exports a `Money` value object and the two
existing validation functions from their new canonical path.

```typescript
class Money {
  static required(value: unknown, field: string): Money;
  static optional(value: unknown, field: string): Money | null;
  compare(other: Money): -1 | 0 | 1;
  equals(other: Money): boolean;
  add(other: Money, field: string): Money;
  subtract(other: Money, field: string): Money;
  toDecimal(): Prisma.Decimal;
  toString(): string;
}

function requiredMoneyAmount(value: unknown, field: string): string;
function optionalMoneyAmount(value: unknown, field: string): string | null;
```

Construction uses the current `numeric(14,2)` grammar exactly. A value supplied
as input preserves its current trimmed string representation so existing
Prisma inputs and responses do not change (`"1.20"` stays `"1.20"`). Decimal
comparison and arithmetic use `Prisma.Decimal`. Negative or out-of-range
arithmetic results fail with the same bounded non-negative field error used by
current validation. The existing exported functions delegate to the value
object and preserve their exact return values and `BadRequestException`
messages; they are stable current API functions, not old-path compatibility
facades.

### Privacy and Application Identity

The review identity helper, admin notification redaction/masking helper, and
the application display-name/avatar/contact helper move into
`shared-kernel/privacy`. This removes the current shared-helper dependency on
`users/` at its root rather than baselining a forbidden shared-kernel import.
All allowlists, Arabic fallback/copy, masking format, enum behavior, and JSON
redaction rules remain unchanged.

### Phone and Time

The phone normalizer and Riyadh business-day helpers move verbatim except for
imports. Their normalization, error strings, timezone behavior, and public
method names do not change.

### Backoffice Permissions

`common/admin/admin-permissions.ts` moves directly to
`modules/backoffice/domain/admin-permissions.ts`. The enum, role matrix, and
return behavior are unchanged. No Backoffice Nest module or public port is
created in R1.

## Architecture Baseline Policy

R1 treats baselines as debt ledgers, never permissions.

- Dependency baseline: every added R1 key must map to an R0 key through the
  declared source relocation map, with the same target semantics. New cycles,
  new targets, or increased unique debt fail. The eliminated OTP/review edges
  must disappear rather than be reintroduced.
- Ownership baseline: path-only key changes caused by moving Prisma-using
  platform files are allowed only when model, operation, mode, reason, owner,
  context, source kind, and occurrence count are identical or decrease. The
  registry platform roots become exactly `["platform"]`; model ownership and
  the 52-model set do not change.
- Ports scanner: the approved Prisma global path changes to
  `backend/src/platform/database/prisma.module.ts`; the exact global count
  remains 2 and `forwardRef()` remains 0. PrismaService provenance recognizes
  only its new canonical declaration path.
- Mobile baseline remains byte-identical and strict mode remains deferred to
  R9.
- Baseline regeneration is never accepted without a machine-readable before/
  after audit and human-readable receipt.

## Test and Verification Policy

Existing behavioral tests may change only through reviewed import/export/
require path edits and moved-source path literals required by R1. Assertions,
fixtures, expected values, Arabic/error text, setup behavior, timeouts, skips,
and test selection are frozen. Additive R1 tests cover the layout contract,
Money value object, OTP split, exact global path, stale-import absence, and
baseline relocation invariants.

Every execution checkpoint runs focused tests plus Backend architecture,
type-check, build, and the relevant existing suite. R1 closeout also runs the
full Backend test suite, all managed smoke packages, Prisma validation, both
npm audits, Admin unchanged-surface gates, Mobile architecture/analyze/tests,
documentation gates, and a pre/post protected-surface audit.

## CI and Phase Transition

The R0 `r0-scope` CI job is removed after R0 is merged because its fixed base
and allowlist are phase-specific. The local R0 scope script/test remain tracked
as historical verification tooling; R1 does not retarget them into a growing
allowlist. All other CI jobs and architecture commands remain active.

R1 implementation must not begin from this planning branch. Before execution:

1. R0 PR #76 must be merged without additional unreviewed changes.
2. The immutable R0 merge SHA must be recorded as `R1_BASE` in the execution
   plan/brief and verified as an ancestor of the R1 branch.
3. The R1 execution worktree must be clean and created from that SHA.
4. If the merge result differs from planning base `94b677b7`, the implementer
   reruns discovery and updates this design and plan before source changes.

## Rejected Alternatives

- **Early Identity/Media/Outbox ports in R1:** rejected because it jumps into
  R3/R5/R6 and expands behavioral risk before the ports-first phase.
- **Old-path compatibility re-exports:** rejected because they preserve two
  layouts, hide stale consumers, and prevent `common/` from being truly gone.
- **Blind baseline regeneration:** rejected because renamed debt could conceal
  new semantic violations.
- **One giant move commit:** rejected because build failures and debt deltas
  would not be attributable to a bounded change.
- **Two separate platform/shared-kernel plans:** rejected because neither half
  independently satisfies the R1 exit contract.

## Acceptance Summary

R1 is accepted only with all source moves complete, zero stale old-path imports,
no `common/` directory, 52 models, 76 migrations, zero schema/migration diff,
exactly two globals at their approved paths, zero `forwardRef`, no new semantic
dependency/ownership debt, unchanged routes and generated docs, green local
quality/smoke gates, and green remote CI on the immutable R1 candidate.
