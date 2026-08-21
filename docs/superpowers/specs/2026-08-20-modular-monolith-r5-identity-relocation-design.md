# Modular Monolith R5 Identity Source Relocation Design

**Status:** Owner-approved design; implementation not started

**Date:** 2026-08-20

**Immutable base:** `9dab73acdc187a4a18d8a675713d8ded40a16d02`

## Objective

R5 physically consolidates the Identity bounded context under
`backend/src/modules/identity/` without changing application behavior. The
legacy `auth/`, `users/`, `me/`, and `contexts/` roots disappear. Existing R3
Identity public tokens remain the only cross-context DI contracts, while the
small exact set of runtime decorators, guards, types, errors, and pure helpers
already consumed across contexts moves into the Identity public slice.

R5 is complete only when:

- all 44 current Identity TypeScript files have one canonical target;
- `backend/src/auth`, `backend/src/users`, `backend/src/me`, and
  `backend/src/contexts` no longer exist;
- no compatibility barrel, re-export, alias file, copied implementation, or
  fallback import preserves an old path;
- controller routes, DTO validation, Arabic and English messages, auth/OTP
  policy, session behavior, scheduler timing, lock ordering, transaction
  boundaries, and error identity remain unchanged;
- the R3 Nest graph retains exact provider/token identity and no new boundary
  edge, cycle, `forwardRef()`, duplicate provider, or `@Global()` declaration;
- dependency and ownership baselines differ from the R5 base only through the
  declared one-to-one file relocation;
- schema, migrations, seed, API contract, Mobile, Admin Web, workflows,
  deployment files, Compose, and package locks remain unchanged;
- exhaustive local gates, an immutable local runtime, independent review, and
  the owner phone checkpoint pass before local R5 closeout.

## Why R5 Is A Source Relocation Phase

R1 deliberately left Identity policy in `auth/` until R5. R3 then created the
full/internal/public Nest boundaries and migrated foreign DI consumers to
Symbol contracts, but retained implementation and controller bodies in the
legacy roots. R4 removed one Finance-to-Planning physical ownership debt and
did not authorize a broad model-access rewrite.

The live R5 base contains:

- 31 files under `backend/src/auth`;
- 8 files under `backend/src/users`;
- 1 file under `backend/src/me`;
- 4 files under `backend/src/contexts`;
- 13 business contexts, zero remaining R3 provider/platform debts, zero Nest
  cycles, zero `forwardRef()`, and exactly two approved globals;
- 31 remaining dependency-baseline records after exactly 58 obsolete
  cross-context debts are resolved by the ten public-runtime moves, plus 385
  ownership records / 781 occurrences.

R5 therefore moves Identity source and path-indexed evidence. It does not try
to eliminate all foreign reads/writes of Identity-owned Prisma models. That is
a separate ownership-port problem and would combine many contexts, methods,
transactions, and lifecycle behaviors into an unreviewable phase.

## Non-Goals

R5 does not:

- add, remove, or change an HTTP/WebSocket route, payload, status, validation
  rule, product copy, permission, role, OTP length, timeout, retry, or token
  lifetime;
- add a public business capability merely to make the folder move look more
  complete;
- change Prisma schema, migrations, seed, generated clients, tables, relations,
  or physical ownership declarations;
- remove sharing's direct transient OTP transport use; that remains R6;
- move another business context, remove either approved global, activate R9
  Mobile strict mode, or start R10 Admin restructuring;
- edit Mobile, Admin Web, deployment, Compose, workflows, or production
  configuration; the sole package-lock exception is the approved R5 Task 5A
  Prisma Config merge security checkpoint, which may resolve only
  `deepmerge-ts@8.0.1` while Prisma remains 6.19.3;
- use a compatibility facade, old-path barrel, duplicate class, symlink,
  junction, fallback import, or mixed old/new runtime;
- push, merge, mutate PR #76, deploy, or claim remote CI.

## Chosen Target Layout

```text
backend/src/modules/identity/
  identity.module.ts
  api/
    auth.controller.ts
    account-deletion-status.controller.ts
    contexts.controller.ts
    me.controller.ts
    users.controller.ts
    auth-dto/
    context-dto/
    user-dto/
  internal/
    identity-auth.internal.module.ts
    identity-profile.internal.module.ts
    auth/
      auth.service.ts
      auth-challenge-cleanup.scheduler.ts
      jwt-secret.ts
      jwt.strategy.ts
      login-throttle.service.ts
      login-throttle-cleanup.scheduler.ts
      otp-channel.ts
      otp-dispatch-quota.service.ts
      otp-dispatch-quota-cleanup.scheduler.ts
      refresh-token-policy.ts
    profile/
      contexts.service.ts
      users.service.ts
  public/
    identity-auth-public.module.ts
    identity-auth.port.ts
    identity-session.types.ts
    access-token-scope.ts
    auth-error.ts
    context-key.ts
    current-user.decorator.ts
    jwt-auth.guard.ts
    jwt-payload.interface.ts
    jwt-session.guard.ts
    max-utf8-bytes.decorator.ts
    safe-user.ts
    user-lifecycle-lock.ts
```

The `api/` slice owns transport metadata and DTOs. The `internal/` slice owns
concrete providers and policy implementations. The `public/` slice contains
the existing Symbol contracts plus only the exact cross-context runtime/type/
pure-function surface already consumed in the R5 base.

## Exact Move Families

### Public contracts and runtime metadata

The following files move to `backend/src/modules/identity/public/`:

| Source | Target name |
| --- | --- |
| `auth/access-token-scope.ts` | `access-token-scope.ts` |
| `auth/auth-error.ts` | `auth-error.ts` |
| `auth/current-user.decorator.ts` | `current-user.decorator.ts` |
| `auth/dto/max-utf8-bytes.decorator.ts` | `max-utf8-bytes.decorator.ts` |
| `auth/jwt-auth.guard.ts` | `jwt-auth.guard.ts` |
| `auth/jwt-payload.interface.ts` | `jwt-payload.interface.ts` |
| `auth/jwt-session.guard.ts` | `jwt-session.guard.ts` |
| `auth/safe-user.ts` | `safe-user.ts` |
| `contexts/context-key.ts` | `context-key.ts` |
| `users/user-lifecycle-lock.ts` | `user-lifecycle-lock.ts` |

These are not new public capabilities. They are path moves of already-frozen
runtime decorator/value/type/pure-function references. Public Nest modules
continue exporting only the two existing Symbol tokens.

`OtpDispatchContext` has one canonical declaration in
`identity-auth.port.ts`. The internal quota service and Collaboration consumer
import that public type rather than maintaining a duplicate legacy declaration.

### Auth implementation

These ten files move to `modules/identity/internal/auth/`:

- `auth-challenge-cleanup.scheduler.ts`;
- `auth.service.ts`;
- `jwt-secret.ts`;
- `jwt.strategy.ts`;
- `login-throttle-cleanup.scheduler.ts`;
- `login-throttle.service.ts`;
- `otp-channel.ts`;
- `otp-dispatch-quota-cleanup.scheduler.ts`;
- `otp-dispatch-quota.service.ts`;
- `refresh-token-policy.ts`.

`IdentityAuthInternalModule` still owns exactly the same providers, schedulers,
configured `JwtModule`, implementation token, and exports.

### Auth API

`auth/auth.controller.ts` moves to `modules/identity/api/auth.controller.ts`.
The twelve remaining files in `auth/dto/` move one-to-one to
`modules/identity/api/auth-dto/` with unchanged class names and validation.

### Profile/context implementation and API

- `contexts/contexts.service.ts` and `users/users.service.ts` move to
  `modules/identity/internal/profile/`;
- `contexts/contexts.controller.ts`, `me/me.controller.ts`,
  `users/users.controller.ts`, and `users/account-deletion-status.controller.ts`
  move to `modules/identity/api/`;
- `contexts/dto/validate-context.dto.ts` moves to `api/context-dto/`;
- the four `users/dto/*.ts` files move to `api/user-dto/`.

`IdentityProfileInternalModule` and `IdentityModule` retain equivalent imports,
providers, exports, controller registration, route metadata, and lifecycle.

## Dependency And Source Laws

R5 introduces `backend/architecture/r5-identity-relocation.json` as the
machine-readable contract. It contains:

- immutable R5 base revision;
- stage (`inventory`, `task-2`, `task-3`, `task-4`, or `strict`);
- exact sorted 44-entry source-to-target move map;
- exact public-runtime contract list and declaration identities;
- exact old roots that must be absent in strict stage;
- expected dependency and ownership record counts;
- exact cumulative changed-path allowlist.

The R5 scanner and permanent tests fail closed on:

- a missing, extra, duplicated, reordered, converging, or overlapping move;
- an old root or stale active import after strict cutover;
- a compatibility file, re-export, symlink, junction, or copied implementation;
- a public helper that was not already consumed outside Identity at the base;
- a concrete class exported from a public Nest module;
- provider/module/controller/route/lifecycle identity drift;
- an import that changes context direction or bypasses a public contract;
- dependency or ownership semantic drift hidden behind a path change;
- a changed path outside the exact R5 allowlist.

The existing R3 scanner is updated path-for-path: Identity legacy roots become
an empty set only in the strict R5 state, decorator/runtime identities point to
their canonical public paths, and all existing inventory counts/identities stay
equal. R3 remains the live Nest-boundary gate; R5 does not fork it.

## Baseline Reconciliation

The dependency and ownership candidates are generated only after source and
focused behavior gates pass. Comparison uses the immutable R5 base plus the
exact move map:

- the 31 remaining dependency records have identical rule/from/to/unresolved/
  type semantics after deterministic path mapping, and the only 58 removals are
  the exact base debts whose targets became the ten approved public contracts;
- ownership remains 385 records / 781 occurrences with identical context,
  owner, model, operation, mode, source, reason, and count after file/key path
  mapping;
- no removed record is treated as permission to add a different record;
- no blind baseline regeneration is accepted.

## Existing-Test Policy

Existing behavioral tests and smokes may change only for mechanical import or
moved-path literal updates required by the exact move map. Assertions, expected
values, fixtures, Arabic/error strings, timeouts, skips, test selection, and
setup semantics remain frozen.

New R5 tests may add architecture, path, identity, baseline, and route-parity
assertions. A behavioral change discovered during execution stops R5 and
requires a separately approved correction; it is not hidden inside relocation.

## Delivery Checkpoints

R5 uses nine checkpoints:

1. approve and locally checkpoint the design/plan;
2. freeze the 44-file move/scope/baseline contract with RED architecture tests;
3. move the ten public runtime/type/pure contracts and their consumers;
4. move the Auth API and implementation;
5. move Users/Me/Contexts API and implementation and delete all old roots;
6. reconcile baselines and begin exhaustive static/behavior/smoke gates;
7. complete the separately specified Task 5A Prisma Config merge security
   checkpoint when the newly published High advisory makes both audits red;
8. create an immutable local image, protected cutover, and owner phone test;
9. complete independent review and truthful local receipts.

Every checkpoint leaves a reviewable candidate. No later checkpoint starts
while an earlier focused gate or review finding is unresolved.

## Verification Contract

At minimum R5 runs:

- R5 exact architecture/scope/relocation tests;
- R3, R4, dependency, ownership, ports, and full architecture gates;
- Backend type-check, build, full tests, Prisma validation/generation/diff, and
  both npm audits;
- Task 5A's permanent declared/locked/installed dependency proof, circular
  merge regression, real Prisma Config load, DMMF/migration equivalence, and
  temporary no-cutover image probe;
- focused auth, refresh, OTP, password recovery, session, users, contexts,
  account deletion, WebSocket, scheduler, and route tests;
- managed `smoke:health`, `smoke:auth`, `smoke:auth-verification`,
  `smoke:otp-profile`, `smoke:phase1-identity`,
  `smoke:phase2-auth-retention`,
  `smoke:phase2-auth-lifecycle-concurrency`,
  `smoke:phase3-context-transition`, `smoke:account-deletion`, and
  `smoke:all`;
- Admin and Mobile frozen-surface/hash gates plus documentation sync/verify and
  whitespace checks;
- managed residue audits after every runtime group.

The immutable R5 runtime must prove the exact image/revision, all 76 migrations,
local and assigned-LAN `/live` and `/ready` HTTP 200, zero restart/OOM state,
and no secret-bearing or fatal marker. The previous accepted R4 runtime remains
preserved for rollback.

The owner phone checkpoint covers login or local WhatsApp OTP, Home, profile or
context read, one safe core read/write, force-stop/reopen session restoration,
and absence of unexpected logout/error. No OTP, phone, password, token, body,
or private value is retained in receipts.

## Git And Release Discipline

Local checkpoint commits are authorized on the existing `modular-monolith`
worktree. R5 creates no branch or worktree and performs no push, merge, PR
mutation, deployment, or remote-CI claim. Runtime testing uses immutable local
images only. R6 does not start until R5 receives final local review and owner
approval.

## Rejected Alternatives

- **Move only `otp-channel.ts`:** rejected because it leaves four fragmented
  Identity roots and does not satisfy the physical context boundary.
- **Move all files under one flat `internal/` directory:** rejected because
  controllers/DTOs and frozen cross-context runtime contracts are not private
  provider implementations.
- **Eliminate every Identity ownership-baseline record in R5:** rejected because
  it combines Backoffice, Planning, Collaboration, Messaging, Marketplace, and
  lifecycle transactions into one unsafe phase.
- **Keep old-path re-exports:** rejected because they preserve two layouts and
  make stale consumers invisible.
- **Regenerate baselines blindly:** rejected because semantic drift can hide
  behind a changed path.

## Acceptance Summary

R5 is accepted only when the four legacy Identity roots are absent, the 44
moves and all consumers are exact, Nest/provider/route/behavior parity is
proved, dependency and ownership baselines are path-equivalent, all local gates
and managed smokes pass, immutable runtime and owner phone checkpoints pass,
independent review has no unresolved finding, and active docs truthfully state
local-only completion. R5 acceptance does not authorize R6, push, merge,
deployment, PR mutation, or remote CI.
