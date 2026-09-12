# R12A Backoffice/Catalog Public Contracts Design

**Date:** 2026-09-01  
**Status:** APPROVED FOR IMPLEMENTATION PLANNING; SOURCE IMPLEMENTATION NOT STARTED  
**Repository:** `D:\projects\aarast-modular-monolith`  
**Branch:** `modular-monolith`  
**Immutable application base:** `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`  
**Parent authority:**
`docs/superpowers/specs/2026-09-01-modular-monolith-remaining-target-design.md`

## Decision Summary

R12A will retire dependency records 1-6 by moving five existing runtime
contracts, unchanged in behavior, into their owning contexts' `public/`
slices. The old files will be deleted and every repository consumer will use
the new owner-public path. R12A will not introduce a facade, re-export,
duplicate implementation, fallback, compatibility layer, new Nest provider,
or constructor dependency.

The implementation is a real boundary correction, not a scanner-only move:

- Backoffice owns admin access, admin permission metadata, admin permission
  enforcement, and authorized admin mutation orchestration.
- Marketplace owns provider review rating locks, aggregation, and refresh.
- Catalog and other contexts consume those capabilities only through the
  owner's `public/` path.
- The same executable code moves once; no legacy source remains.

Runtime functions in `public/` are permitted here because the repository
already has reviewed executable transaction contracts such as
`modules/identity/public/user-lifecycle-lock.ts` and
`modules/collaboration/public/contribution-snapshot.builder.ts`. R12A does
not create a `BackofficePublicModule` or `MarketplacePublicModule`. The
Symbol/`useExisting` rule remains mandatory when a Nest injectable provider is
exported by a PublicModule; these five contracts are not such providers.

## Problem And Exact Exit

The entry dependency baseline contains 22 records. R12A owns these six and no
others:

| ID | Rule | From | Legacy target |
| ---: | --- | --- | --- |
| 1 | `context-backoffice-cross-context` | `src/admin/admin-mutation-executor.ts` | `src/marketplace/provider-review-rating.ts` |
| 2 | `context-catalog-cross-context` | `src/catalogs/administrative-catalog.service.ts` | `src/admin/admin-mutation-gate.ts` |
| 3 | `context-catalog-cross-context` | `src/catalogs/catalogs.controller.ts` | `src/admin/admin-permission.decorator.ts` |
| 4 | `context-catalog-cross-context` | `src/catalogs/catalogs.controller.ts` | `src/admin/admin-permission.guard.ts` |
| 5 | `context-catalog-cross-context` | `src/catalogs/catalogs.controller.ts` | `src/admin/admin.guard.ts` |
| 6 | `context-catalog-cross-context` | `src/catalogs/reference-catalog.service.ts` | `src/admin/admin-mutation-gate.ts` |

The exit is exact:

- dependency records: `22 -> 16`;
- ownership: remains `385 records / 781 occurrences`;
- old runtime-contract files: `5 -> 0`;
- new owner-public runtime-contract files: `0 -> 5`;
- new dependency violations: `0`;
- `forwardRef()`: `0`;
- project-owned `@Global()`: `0`;
- routes, schema, migrations, DTOs, errors, permissions, transaction semantics,
  response contracts, Arabic, Mobile, Admin Web, deployment, and provider
  delivery: unchanged.

The dependency baseline is not regenerated. Only the six rows above are
removed. It remains present with 16 records for R12B. The ownership baseline
is not reduced; one path-bearing record is projected 1:1 because its source
file moves.

## Rejected Alternatives

### New DI ports for all five contracts

Rejected for R12A. It would change constructors, manual service construction,
and the Nest module graph without a behavioral or ownership need. In
particular, `AdminMutationExecutor` is constructed inside `AdminService`, and
existing tests construct `AdminService` directly. Adding optional defaults or
service-locator fallbacks merely to preserve those tests would be a
compatibility workaround.

### Legacy re-exports or forwarding facades

Rejected. A file at an old path that forwards to `public/` keeps two apparent
truths, hides stale consumers, and turns the dependency count into a cosmetic
result. Old paths must be absent.

### Copying implementations into `public/`

Rejected. R12A moves the existing implementation; it does not retain old and
new copies.

### Retiring the Backoffice-to-Identity ownership record early

Rejected. R12A removes dependency debt, not ownership debt. The Backoffice
ownership allocation belongs to R17. Moving `admin-mutation-gate.ts` changes
the record's path key, so R12A maps the old record to the new path with the same
context, owner, model, operation, mode, source, reason, and count.

## Target File Map And Export Inventory

| Legacy path to delete | Owner-public target | Exact public exports |
| --- | --- | --- |
| `backend/src/admin/admin.guard.ts` | `backend/src/modules/backoffice/public/admin.guard.ts` | `AdminGuard` |
| `backend/src/admin/admin-permission.decorator.ts` | `backend/src/modules/backoffice/public/admin-permission.decorator.ts` | `ADMIN_PERMISSIONS_KEY`, `RequireAdminPermission` |
| `backend/src/admin/admin-permission.guard.ts` | `backend/src/modules/backoffice/public/admin-permission.guard.ts` | `AdminPermissionGuard` |
| `backend/src/admin/admin-mutation-gate.ts` | `backend/src/modules/backoffice/public/admin-mutation-gate.ts` | type `AuthorizedAdminMutationActor`, `authorizeAdminMutationActor`, `runAuthorizedAdminMutation` |
| `backend/src/marketplace/provider-review-rating.ts` | `backend/src/modules/marketplace/public/provider-review-rating.ts` | `lockProviderRatingRows`, `refreshProviderRating`, `runProviderReviewMutation` |

The moved files keep their function/class bodies, error messages, ordering,
and transaction behavior. Import paths change only as required by the new
location. `AuthenticatedUser` imports in Backoffice public files must use
syntactic `import type` so Backoffice Public does not create a runtime import
to Identity Public.

### Immutable source-parity evidence

The R12A manifest records these immutable entry hashes:

| Legacy source | Entry SHA-256 |
| --- | --- |
| `backend/src/admin/admin.guard.ts` | `7b0af6a63c11d68ac8322083146a8e6df034a4244574707f4ed34dac0e115420` |
| `backend/src/admin/admin-permission.decorator.ts` | `ace0cee2b39428563e465f85419edef4810ebbfa7e2ecf6f6ca17a0a26a60d18` |
| `backend/src/admin/admin-permission.guard.ts` | `85eb85348cd5acdff9766122b2983f1ba67e24caebf2721ddb6aa31d37717628` |
| `backend/src/admin/admin-mutation-gate.ts` | `aeb7f07cfdc5e62949ff16e59705c5652fe6e5ea5d28c789f6bd8425c3072c47` |
| `backend/src/marketplace/provider-review-rating.ts` | `870c5c1d5f14b60c67a1b8c7a4f6e4a1689fb196b86754f190cc861d0644e8d1` |

For every move, the manifest also lists the exact old and new import
declarations. The R12A scanner reads the old source from the immutable base,
requires its raw hash, parses both sources, validates the declared import
rewrite set, rewrites the live imports back to their exact historical forms,
normalizes line endings only, and requires full-source equality. A changed
statement, branch, literal, decorator, SQL fragment, transaction call, export,
or any undeclared import fails source parity.

The same protection applies to all nine consumers and four behavioral tests
whose only approved changes are import/path literals. The manifest records
their immutable entry hashes, exact literal rewrite pairs, and owning `moveId`.
The scanner activates each pair only when that move is active in the declared
stage. It compares consumer module specifiers and behavioral-test string
literals as exact AST node values, never substrings, normalizes only those
active node ranges and line endings, then requires complete source equality.
This prevents the `M1` rewrite in
`admin-mutation-executor.ts` from being applied during the intermediate
Backoffice stage while its `B4` rewrite is already active. The two run-only
regression tests have immutable hashes and must remain byte-identical.

The Prisma code in `provider-review-rating.ts` remains an explicit Marketplace
layout handoff to R16. The Prisma code in `admin-mutation-gate.ts` remains an
explicit Backoffice layout/ownership handoff to R17. R12A neither claims nor
attempts the final `infrastructure/` target for those future phases.

## Complete Consumer Projection

R12A must update every live consumer; the fixed list is:

### Backoffice owner consumers

- `backend/src/admin/admin-audit.controller.ts`
- `backend/src/admin/admin.controller.ts`
- `backend/src/admin/admin-user-status.ts`
- `backend/src/admin/admin-mutation-executor.ts`

### Catalog consumers

- `backend/src/catalogs/catalogs.controller.ts`
- `backend/src/catalogs/administrative-catalog.service.ts`
- `backend/src/catalogs/reference-catalog.service.ts`

### Marketplace and Identity consumers

- `backend/src/marketplace/marketplace.service.ts`
- `backend/src/modules/identity/internal/profile/users.service.ts`

No other TypeScript source may contain one of the five retired import
literals. String literals in architecture fixtures are allowed only where a
test intentionally represents the historical state or asserts rejection of a
legacy import; the R12A scanner records those fixtures explicitly.

## Transaction, Lock, Authorization, And Error Invariants

R12A preserves these operations byte-for-byte except imports and line-ending
normalization:

1. `AdminGuard` requires `UserRole.ADMIN`, `adminMfa === true`, and
   `sessionScope === 'admin'`, then returns `true`.
2. `AdminPermissionGuard` reads `ADMIN_PERMISSIONS_KEY`, rejects missing
   permissions, and requires every permission through `hasAdminPermission`.
3. All protected admin and catalog controllers retain guard order
   `JwtSessionGuard, AdminGuard, AdminPermissionGuard`.
4. `authorizeAdminMutationActor` keeps the `User` row `FOR UPDATE`, active
   admin checks, permission check, and exact
   `ForbiddenException('Admin permission is required')`.
5. `runAuthorizedAdminMutation` keeps one `runSerializableTransaction` and
   authorizes before calling the mutation callback on the same transaction.
6. `lockProviderRatingRows` keeps sorted/deduplicated provider IDs, `FOR
   UPDATE`, and returned row ordering.
7. `refreshProviderRating` keeps the published-review aggregate, two-decimal
   average, count, and `updateMany` result contract.
8. `runProviderReviewMutation` keeps one serializable transaction, lock before
   mutation, refresh after mutation, and exact
   `NotFoundException('Provider not found')` behavior.
9. `AdminMutationExecutor` keeps its existing review mutation order inside the
   same Prisma transaction.

Any change to an assertion, fixture, expected value, error literal, timeout,
route, DTO, or transaction callback is a stop condition, not R12A work.

## Ownership Projection

The entry ownership baseline contains this record:

```text
backend/src/admin/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model
```

At Backoffice stage it becomes exactly:

```text
backend/src/modules/backoffice/public/admin-mutation-gate.ts|backoffice|identity|User|select|read|sql|foreign-model
```

Only `key` and `file` change. The following values remain exact:

```json
{
  "context": "backoffice",
  "owner": "identity",
  "model": "User",
  "operation": "select",
  "mode": "read",
  "source": "sql",
  "reason": "foreign-model",
  "count": 1
}
```

The R12A scanner compares the live baseline to the immutable entry baseline at
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`, applies only this deterministic
path substitution, and requires `385/781`. It must reject deletion, count
change, any second ownership change, or a new record.

## Cumulative Architecture Handoff

The current R3-R8 scanners are cumulative historical gates but several also
pin the current dependency count or old file hashes. Moving the contracts
without a handoff would make `npm run architecture` fail even when the new
boundary is correct. R12A therefore adds a reviewed live handoff while
preserving the historical evidence.

### R12A stages

The R12A manifest has three ordered stages:

| Stage | Runtime state | Dependency | Ownership |
| --- | --- | ---: | ---: |
| `design` | five legacy files present; targets absent | 22 | 385/781 |
| `backoffice` | four Backoffice files moved; records 2-6 retired | 17 | 385/781 with one path projection |
| `strict` | Marketplace file moved; record 1 retired | 16 | 385/781 with the same path projection |

Skipping a stage, observing a count other than 22/17/16, or seeing an
unapproved key fails the gate.

### Historical scanners

R3, R5, R6, R7, and R8 keep their original phase constants, immutable bases,
manifests, and historical assertions. Their live checks consume the validated
R12A manifest and accept only the exact stage projection above:

- R3 maps the four Backoffice legacy runtime paths to their public targets and
  continues to validate the original context composition evidence.
- R3 permits one manifest-declared cross-context runtime-public edge only at
  `strict`:
  `modules/identity/internal/profile/users.service.ts` may import exactly
  `lockProviderRatingRows` and `refreshProviderRating` from
  `modules/marketplace/public/provider-review-rating.ts`. The source, target,
  two imported names, and stage are exact; any near-miss fails. This temporary
  runtime edge is removed when R16 replaces the Marketplace helper with its
  final owner infrastructure/public-port shape.
- R5 keeps the original `users.service.ts` hash and validates the live file by
  normalizing only the exact provider-rating import literal back to its
  historical literal before hash comparison.
- R6, R7, and R8 keep historical dependency count 22 and verify that the live
  baseline is the historical 22 minus exactly the R12A keys allowed by the
  current stage.
- R5 security keeps its immutable package hash and exact R6-R8 delegation
  evidence. Its additive handoff accepts exactly one `architecture:r12a`
  standalone command appended exactly after `architecture:r8`, projects that
  one command away first, then runs the unchanged R8-to-R6 projection and
  historical hash comparison. Any other name, command, order, duplicate,
  prefix sibling, or modification to R3-R8 still fails.
- R7 keeps its original Collaboration ownership projection, then applies the
  one R12A Backoffice path projection only at `backoffice`/`strict`, re-sorts
  all violations canonically by `key`, and compares the complete live
  baseline. R5/R7 tests prove the original R7 handoff remains unchanged, the
  R12A projection changes no semantic field/count, and any second projection
  or unsorted result fails.
- R8 continues to require ownership `385/781`, globals `0`, `forwardRef()`
  `0`, and the same provider composition.

This is not permission to replace historical evidence with new counts. Tests
must prove that changing a historical constant still fails, adding a seventh
retired dependency fails, and changing any non-import byte of
`users.service.ts` fails.

### New R12A authority

R12A adds:

- `backend/architecture/r12a-backoffice-catalog-public-contracts.json`;
- `backend/scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs`;
- `backend/test/architecture-r12a-backoffice-catalog-public-contracts.test.ts`;
- `architecture:r12a` in `backend/package.json`, appended after
  `architecture:r8` in the cumulative `architecture` command.

The new scanner is the authority for the live 22/17/16 projection, the five
moves, export inventories, legacy-path absence, import-literal absence,
ownership path projection, exact exception removal, guard order, and scope.

The R12A manifest is a complete reviewed contract, not a scaffold. It contains
no empty placeholder collection: every dependency record, move, immutable
hash, import rewrite, consumer, behavioral-test literal rewrite, run-only test,
runtime-public edge, ownership projection, exception identity, guard order,
stage activation, and R16/R17 handoff is present with exact values before
source implementation starts. Unknown or missing nested keys fail validation.
Every consumer/test rewrite is tied to exactly one declared move, and its old
or new literal is required according to that move's activation at the current
stage.

## Transitional Exception Retirement

Moving the Marketplace rating contract makes the old Identity-to-Marketplace
helper exception obsolete. R12A strict stage removes only the exact
provider-rating entries from:

- `backend/.dependency-cruiser.cjs`;
- `backend/scripts/architecture/ports-scan.cjs`;
- `backend/scripts/architecture/r3-context-scan.cjs`.

The sibling provider access-policy exception remains because it belongs to a
later R12C record. R12A tests must reject removing or changing that sibling.

The separate R1 pre-port exception for
`modules/backoffice/domain/admin-permissions.ts` is intentionally unchanged in
R12A because it is not one of dependency records 1-6. R17, as the Backoffice
owner phase, must publish that pure permission contract from Backoffice
`public/`, update every remaining Auth/Catalog/Identity consumer, and delete
the exact R1 exception before R18. R16 Catalog may retain only this already
documented exception until R17; it may not widen it.

## Test Change Policy

Existing behavioral tests may change only import declarations or exact source
path literals that point to a moved file. Test names, setup, fixtures, mocks,
assertions, expected values, Arabic/error literals, and timeouts are frozen.

Architecture manifests, scanners, and architecture tests are governance code,
not behavioral fixtures. They may receive additive R12A handoff logic and
negative tests, but they may not weaken or delete an older phase assertion.

Directly affected behavioral tests include:

- `backend/test/admin-auth-session-security.test.ts`;
- `backend/test/admin-rbac-audit.test.ts`;
- `backend/test/admin-mutation-authorization.test.ts`;
- `backend/test/provider-rating-atomicity.test.ts`;

`backend/test/admin-mutation-gate-runtime.test.ts` and
`backend/test/reference-catalogs.test.ts` are run-only regression coverage;
they contain no moved import/path literal and must not be edited.

Affected cumulative architecture coverage includes R3, R5, R6, R7, R8,
dependency, ports, ownership, and the new R12A suite.

## Scope Fence

R12A implementation may change only:

1. the five moved runtime contracts and their nine fixed consumers;
2. the dependency and ownership baseline files by the exact projections above;
3. the three exact transitional exception locations;
4. R3/R5/R6/R7/R8 scanner/manifest/test files required for the cumulative
   handoff;
5. the new R12A manifest/scanner/test and `backend/package.json` script wiring;
6. directly affected tests under the frozen test-change policy;
7. R12A completion documentation and report, including generated
   `docs/SCRIPTS.md` because `backend/package.json` gains the exact
   `architecture:r12a` command.

Forbidden surfaces include Prisma schema, migrations, seed, packages and lock
files, API routes, DTO behavior, application modules, Mobile, Admin Web,
Docker, Compose, Dokploy, runtime configuration, provider credentials,
deployment, push, merge, production mutation, remote CI, and store release.

R11 remains a separate nine-Markdown overlay on the R10 commit. This R12A
design and its implementation plan are two additional planning documents. A
future R12A scope gate must classify those historical overlays separately from
application changes rather than pretending the working tree began clean.

## Verification And Exit Gates

R12A is complete only after one fresh final run proves:

1. R12A strict scanner passes at dependency 16 and ownership 385/781.
2. The current dependency baseline equals immutable entry 22 minus records
   1-6 in identity and order; no regeneration or unrelated edit occurred.
3. The ownership baseline equals immutable entry ownership after the single
   path projection; counts remain 385/781.
4. Five owner-public files exist with exact exports; five old files are absent.
5. Source parity passes for all five moves after only the manifest-declared
   import rewrites and line-ending normalization.
6. All fixed consumers use owner-public paths; no retired runtime import
   literal remains.
7. No facade, re-export, duplicate, fallback, unapproved public runtime edge,
   cycle, `forwardRef()`, or project-owned `@Global()` exists. The single
   manifest-declared Identity-to-Marketplace edge matches exactly.
8. Guard order, permission metadata, mutation authorization, provider rating,
   lock order, and exact errors pass focused tests.
9. The focused managed smoke suites pass for reference catalogs, admin
   mutation authorization, Marketplace write concurrency, and provider rating
   concurrency, followed by `smoke:all`.
10. `npm run architecture`, `npm run check`, `npm run build`, and the complete
   Backend test suite pass.
11. Documentation sync, documentation verification, scope verification, and
   `git diff --check` pass.
12. The final independent review runs after completion docs and final scope/
    identity gates, and returns `APPROVED` with no Critical or Important
    finding.

No phone test is required because R12A changes no Mobile or visible runtime
behavior. Any observed API or device behavior difference is a failure and
requires stopping, not expanding the phase.

## Permanent Stop Rules

Stop R12A immediately if:

- repository identity or immutable base drifts;
- the R11 nine-path overlay is lost or mixed into application scope;
- dependency is not exactly 22, 17, or 16 at its declared stage;
- ownership differs from 385/781 or more than the one approved path changes;
- an unlisted dependency is retired or added;
- a historical R3-R8 assertion must be deleted or weakened;
- a behavioral test needs more than an import/path-literal change;
- a constructor, module graph, route, schema, migration, permission, error,
  transaction, lock order, response, or Arabic string changes;
- source parity fails for any of the five moved implementations;
- consumer/test parity fails after the exact declared path rewrites;
- R3 requires a runtime-public exception broader than the single exact
  Identity-to-Marketplace edge;
- a facade, fallback, alias, duplicate implementation, or compatibility layer
  appears;
- future R12B/R12C/R16/R17 work becomes necessary to make R12A pass.

## Authorization Boundary

This design authorizes creation and independent review of the R12A
implementation plan. It does not authorize source implementation, Git commit,
push, merge, deployment, production mutation, remote CI, provider delivery,
store release, or any later phase. Source implementation requires separate
owner approval of the reviewed plan.
