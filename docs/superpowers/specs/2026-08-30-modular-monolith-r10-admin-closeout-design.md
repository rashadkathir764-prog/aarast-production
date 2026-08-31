# Modular Monolith R10 Admin Restructure And Truthful Closeout Design

Date: 2026-08-30

Status: Corrected design written from the owner-approved direction; written-spec
review is required before implementation planning

Branch: `modular-monolith`

Immutable R10 planning base: `e560e5784278907dd6bf565327c3abfa0c9b8cab`

## Objective

Complete the Admin Web restructure assigned to R10 without changing Admin
behavior, then close the R0-R10 execution wave with one exhaustive local
verification receipt that states the remaining Backend architecture debt
truthfully.

R10 is an Admin architecture phase. It moves the existing Admin source into
explicit `platform`, `design_system`, `features`, and composition-root
boundaries; splits the 834-line Admin API by owner; adds fail-closed Admin
boundary enforcement; updates active architecture documentation; and produces
the final local report required by the original R0-R10 mission.

R10 does not add a product feature, redesign the Admin UI, alter Arabic copy,
change routes or API requests, modify authentication/OTP/session behavior,
change Backend or Mobile source, alter Prisma/database/deployment state, or
retire unrelated Backend architecture debt.

## Closeout Semantics

The R10 result must use these exact meanings:

- `R10 Admin phase complete` means the Admin fate map, strict Admin boundary
  rules, Admin verification, documentation, and R10 report all passed.
- `R0-R10 execution wave closed with declared Backend gaps` means the planned
  sequence reached its final local phase while retaining an explicit mission
  gap report.
- `Modular-monolith architecture target complete` is forbidden while the live
  Backend dependency and ownership debt remains non-zero.

At the R10 planning base the Backend debt is:

- dependency baseline: 22 records;
- physical-ownership baseline: 385 records / 781 occurrences.

R10 must re-prove those values and prevent growth. It must not describe them as
resolved, hide them behind passing builds, or absorb their cleanup into the
Admin phase.

## Verified Starting State

The R9 docs-only closeout is clean at the immutable planning base. No R10 code
or plan existed when this design was written.

| Evidence | Verified value |
| --- | --- |
| Git branch | `modular-monolith` |
| Planning base | `e560e5784278907dd6bf565327c3abfa0c9b8cab` |
| Worktree | clean before design creation |
| Admin source files | 78 |
| Admin source lines | 11,718 |
| `src/api/admin.ts` | 834 lines |
| `src/api/auth.ts` | 260 lines |
| `src/api/client.ts` | 199 lines |
| Admin tests | 18 files / 96 tests PASS |
| TypeScript no-emit | PASS |
| Production build | PASS |
| Source honesty | 12/12 PASS |
| Container configuration | 3/3 PASS |
| Route smoke | 16 routes PASS |
| Admin dependency audit | zero vulnerabilities |
| Generated Admin route contract | 22 routes; SHA-256 `a1e3ee774bafca860ee0e95461b9e2384c719fcc6c1fb1eb01d6b4b945672e5e` |
| Admin lockfile SHA-256 | `e663c4fcb3f17a7aeb8923d3563d27ed543267d24f780ae939ba23d0dcb48757` |
| Backend architecture | PASS with dependency 22 and ownership 385/781 |
| Documentation | drift 0; errors 0; warnings 0 |

The three source files that carry the current transport contract are frozen at
the planning base for later equivalence comparison:

| File | SHA-256 |
| --- | --- |
| `admin-web/src/api/admin.ts` | `a7ef361122a3e205bc9be9e63a001fddf4b05370fd1a895a2110c652aadd51b2` |
| `admin-web/src/api/auth.ts` | `611b989e87174619da140f88548059a2dd3d4b126b5ec446bbbccc3d1a0f41d5` |
| `admin-web/src/api/client.ts` | `8e40ae3cacaca875068f79d668c9b86b2af825ec8208cea03a202c06fb0c4a9e` |

These hashes identify the starting inputs. They do not authorize copying old
files into compatibility facades after the move.

The canonical request-call inventory is exactly 62 records with SHA-256
`a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9`.
The base projection scans the three frozen transport files; the candidate
projection scans all production Admin TypeScript/TSX after relocation. It
selects `apiRequest(...)` calls and only direct `fetch(...)` calls whose first
argument resolves to a concrete route beginning `/`. A leading template
expression that is exactly the identifier `apiBaseUrl` is omitted; every other
template expression becomes `<expr>`. This includes the concrete refresh call
as `POST /api/v1/auth/admin/refresh` and excludes the generic transport call
whose URL combines only `apiBaseUrl` and the runtime `path`, because its
remaining path is not concrete.
The method is `GET` unless an object-literal options property contains a string
literal method, which is uppercased. Each record is `${METHOD} ${PATH}`; records
are sorted with the default JavaScript string order without deduplication, then
hashed as UTF-8 `JSON.stringify(records)`. Any unsupported path or method shape
in a selected call fails closed rather than disappearing.

## Chosen Approach

R10 uses a staged, no-facade relocation:

1. freeze the exact source, route, endpoint, method, Arabic-literal, test, and
   protected-surface inventories at the immutable base;
2. add a TypeScript-AST Admin boundary scanner, adversarial scanner tests, and
   an exact R10 scope guard before moving application source;
3. relocate the platform API client, neutral query/date helpers, error
   boundary, not-found page, and shared design-system files;
4. establish Auth as a feature with one public `api.ts` surface;
5. split `api/admin.ts` by owner while moving the corresponding pages into
   feature directories and deleting each old implementation as it moves;
6. move the three cross-feature contract tests into `src/test/contracts` and
   make only approved path/mock-target changes;
7. delete the old `api`, `auth`, `components`, and `pages` roots, activate
   strict CI, and prove the final Admin route/API/copy/test contracts;
8. run the complete Backend, Admin, Mobile, docs, security, runtime, and scope
   gates in one local closeout run;
9. update the active architecture sources and produce an honest final report.

During staged relocation an old root may contain only the exact not-yet-moved
files listed for the current milestone. A moved implementation is removed from
its old path in the same checkpoint. No re-export, forwarding file, alias,
duplicate implementation, fallback import, symlink, or compatibility layer is
allowed.

## Rejected Alternatives

### Split only `api/admin.ts`

This would reduce one file but leave the historical R10 page/component/auth
fate map unfinished and keep the Admin architecture unenforced.

### Combine all remaining Backend cleanup into R10

This would turn a bounded Admin phase into a second migration mission, violate
phase isolation, and make a truthful closeout harder rather than easier. The
22 and 385/781 Backend gaps remain explicit follow-up work.

### Move files without machine enforcement

A directory-only cleanup would permit future deep cross-feature imports and
would not satisfy the original machine-enforced modular-monolith objective.

### Keep `src/api/admin.ts` as a re-export facade

This would preserve the old dependency hub and create two public paths. R10
requires one owner path and deletion of the old root.

### Put every shared Admin DTO in `platform`

Platform is not a domain dumping ground. Only transport-neutral request,
pagination, and query mechanics belong there. Auth, provider, catalog,
moderation, notification, audit, user, and dashboard types stay with their
owners.

## Target Admin Architecture

The final first-party TypeScript dependency direction is:

```text
App.tsx / main.tsx / layout/**
               |
               v
        features/<owner>/api.ts
               |
               v
       platform + design_system
```

The concrete laws are:

- `platform/**` imports neither `features/**` nor `design_system/**`.
- `design_system/**` imports neither `features/**` nor `layout/**`.
- A feature may import itself, `platform/**`, `design_system/**`, or the exact
  `features/<other-owner>/api.ts` public surface.
- A feature may not import another feature's page, helper, component,
  transport implementation, or test.
- `App.tsx`, `main.tsx`, and `layout/**` are explicit composition roots. They
  may consume feature public APIs but may not become domain-logic owners.
- `App.tsx` alone may directly assemble the exact screen modules listed below.
  No other composition root or production file receives this exception:

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
- `src/test/contracts/**` is an exact test-only composition exception. It may
  inspect multiple feature sources but is never imported by production code.
- `styles/**`, `test/setup.ts`, and `vite-env.d.ts` retain their current
  neutral responsibilities and paths.
- The old first-party roots `src/api`, `src/auth`, `src/components`, and
  `src/pages` are absent at strict closeout.
- External package imports are unaffected.

### Allowed Feature Graph

The final inter-feature graph is intentionally small and acyclic:

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

No other inter-feature edge is legal. In particular, providers must not import
catalog, because catalog already needs the Providers public API for the current
service/review provider-search flows.

## Exact File Fate Map

All targets remain under `admin-web/src/`.

### Platform And Shared UI

| Current source | Final fate |
| --- | --- |
| `api/client.ts` and `api/client.test.ts` | move unchanged except imports to `platform/api/client.ts` and `platform/api/client.test.ts` |
| pagination/query construction inside `api/admin.ts` | extract to `platform/api/query.ts` with focused tests |
| generic `formatDate` in `pages/providerHelpers.tsx` | extract byte-equivalent behavior to `platform/i18n/formatDate.ts` with focused tests |
| `components/ErrorBoundary.tsx` and test | move to `platform/errors/` |
| `pages/NotFoundPage.tsx` | move to `platform/routing/NotFoundPage.tsx` |
| every other file under `components/` | move one-to-one to `design_system/` |
| `styles/globals.css` | unchanged path and content |
| `test/setup.ts`, `vite-env.d.ts` | unchanged paths and content |

The 25 design-system files are the current component inventory excluding the
`ErrorBoundary` implementation and test. Component names, props, DOM,
accessibility behavior, Arabic text, and CSS classes remain unchanged.

### Auth Feature

| Current source | Final fate |
| --- | --- |
| `api/auth.ts` and `api/auth.test.ts` | split mechanically into `features/auth/transport.ts` and `features/auth/transport.test.ts` |
| `auth/admin-return-path.ts` and `auth/admin-return-path.test.ts` | move one-to-one under `features/auth/` |
| `auth/adminPermissions.ts` | move one-to-one under `features/auth/` |
| `auth/AuthProvider.tsx` and `auth/AuthProvider.test.tsx` | move one-to-one under `features/auth/` |
| `auth/Can.tsx` | move one-to-one under `features/auth/` |
| `auth/RequireAdmin.tsx` | move one-to-one under `features/auth/` |
| `auth/RequireAdminPermission.tsx` | move one-to-one under `features/auth/` |
| `pages/LoginPage.tsx` and `pages/LoginPage.test.tsx` | move one-to-one under `features/auth/` |
| new `features/auth/api.ts` | sole cross-feature public surface for Auth transport types/functions, session context, permissions, and guards |
| `auth/AdminRbacAuditContract.test.ts` | move to `test/contracts/AdminRbacAuditContract.test.ts` |

The historical `api/auth.ts -> features/auth/api.ts` row is refined because a
single file cannot safely be both the internal transport implementation and a
barrel that re-exports `AuthProvider` while `AuthProvider` consumes that same
transport. `transport.ts` keeps the current implementation; `api.ts` is the
acyclic owner surface. This is a structural correction only and changes no
request, validation, error, token, cookie, OTP, or session behavior.

### Dashboard And Reports

| Current source | Final fate |
| --- | --- |
| `pages/DashboardPage.tsx` and test | move to `features/dashboard/` |
| `pages/ReportsPage.tsx` | move to `features/dashboard/ReportsPage.tsx` |
| `AdminStats`, `AdminReport`, `getStats`, `getReportOverview` | move from `api/admin.ts` to `features/dashboard/api.ts` |

Dashboard consumes provider applications only through
`features/providers/api.ts`.

### Users

| Current source | Final fate |
| --- | --- |
| `pages/UsersPage.tsx` | move to `features/users/UsersPage.tsx` |
| `pages/UserDetailsPage.tsx` | move to `features/users/UserDetailsPage.tsx` |
| `getUsers`, `getUser`, `activateUser`, `disableUser` | move to `features/users/api.ts` |

`AdminUser` remains Auth-owned and is consumed through
`features/auth/api.ts`. User API response DTOs may refer to the Provider DTO
structurally without adding a reverse provider-to-users edge.

### Providers

| Current source | Final fate |
| --- | --- |
| `pages/ProviderApplicationsPage.tsx` | move to `features/providers/` |
| `pages/ProviderApplicationDetailsPage.tsx` | move to `features/providers/` |
| `pages/ProvidersPage.tsx` | move to `features/providers/` |
| `pages/ProviderDetailsPage.tsx` | move to `features/providers/` |
| provider-specific remainder of `pages/providerHelpers.tsx` | move to `features/providers/providerHelpers.tsx` |
| provider DTOs and provider/application lifecycle requests | move to `features/providers/api.ts` |
| `pages/ProviderLifecycleContract.test.ts` | move to `test/contracts/ProviderLifecycleContract.test.ts` |

Provider DTOs keep the same runtime shape. Their nested city, category, and
service projections are structural response shapes inside the Provider owner;
Providers does not import Catalog. This prevents a Providers/Catalog cycle
without moving domain DTOs into Platform or changing response payloads.

### Catalog And Services

| Current source | Final fate |
| --- | --- |
| `pages/CategoriesPage.tsx` | move to `features/catalog/` |
| `pages/CitiesPage.tsx` | move to `features/catalog/` |
| `pages/ServicesPage.tsx` | move to `features/catalog/` |
| `pages/ReferenceCatalogsPage.tsx` | move to `features/catalog/` |
| `pages/AdministrativeAreasPage.tsx` | move to `features/catalog/` |
| city, category, service, dynamic-catalog, and geography DTOs/requests | move to `features/catalog/api.ts` |

Catalog may call the public Providers API for the existing provider search. It
must not import provider internals, and Providers must not import Catalog.

### Moderation, Notifications, And Audit

| Current source | Final fate |
| --- | --- |
| `pages/ReviewsPage.tsx` | move to `features/moderation/ReviewsPage.tsx` |
| `pages/ConversationReportsPage.tsx` | move to `features/moderation/ConversationReportsPage.tsx` |
| review/conversation-report DTOs and requests | move to `features/moderation/api.ts` |
| `pages/NotificationsPage.tsx` plus notification DTOs/requests | move to `features/notifications/` and `features/notifications/api.ts` |
| `pages/AuditLogsPage.tsx` plus audit DTOs/requests | move to `features/audit/` and `features/audit/api.ts` |
| `pages/AdminPaginationContract.test.ts` | move to `test/contracts/AdminPaginationContract.test.ts` |

Moderation may use the public Providers API for the existing provider filter.
Write controls in Catalog, Moderation, Notifications, Users, and Providers
consume permission state only through the Auth public API.

### Composition Roots

| Current source | Final fate |
| --- | --- |
| `App.tsx` | path unchanged; imports only are redirected to final owners |
| `main.tsx` | path unchanged; imports only are redirected to Auth and Platform |
| all eight files under `layout/` | paths and behavior unchanged; import-only redirects allowed |

The 22 generated Admin routes, route hierarchy, redirects, permission guards,
and fallback behavior remain identical.

## Public API And Type Ownership

Every feature has exactly one public path:

```text
admin-web/src/features/<owner>/api.ts
```

Production code outside the owner imports that file and no other owner file,
except that `App.tsx` may import only the exact 18 feature screen modules in the
composition-root allowlist above. The Platform NotFound module is the nineteenth
exact direct screen import. Screens are not exported through feature APIs.
The public API exports only symbols with verified consumers. Wildcard exports,
cross-feature re-exports, compatibility exports, and API-to-API forwarding are
forbidden.

`platform/api/query.ts` owns transport-neutral mechanics:

- `Paginated<T>`;
- the scalar query-value contract;
- deterministic omission of undefined values;
- URL encoding through the current `URLSearchParams` behavior.

Feature-specific query keys and response DTOs remain feature-owned. The API
split preserves every current function name used by a page, every HTTP method,
every URL path/template, every request body shape, and every response shape.

## Admin Boundary Governance

R10 adds these governance artifacts:

- `admin-web/architecture/r10-admin-boundaries.json` — immutable base, source
  and test fate map, exact features, public API paths, composition roots, the
  exact `App.tsx` screen-import allowlist, permitted feature graph, old-root
  milestones, protected hashes, route/API/Arabic-literal inventories, and the
  final changed-path fence;
- `admin-web/scripts/admin-boundaries.mjs` — TypeScript-AST dependency scanner
  and strict CLI;
- `admin-web/scripts/admin-boundaries.contract.mjs` — positive and adversarial
  scanner tests;
- `scripts/check-r10-scope.mjs` and test — fixed-base path, hash, test-change,
  protected-surface, route/API/copy, milestone, and final-scope enforcement.

The scanner uses the installed TypeScript compiler API and adds no dependency.
It recognizes:

- static value and type imports;
- export-from declarations;
- `import = require`;
- `require(...)`;
- dynamic `import(...)`;
- relative extension/index resolution;
- unresolved or escaping first-party paths.

External-package imports are ignored after classification. Every first-party
TypeScript/TSX file is assigned to an exact zone; unknown zones fail. Results
are repository-relative, canonical, unique, sorted, and safe to print.

The scanner fails on:

- an illegal feature edge;
- a deep cross-feature import;
- a direct feature-screen import outside the exact `App.tsx` allowlist;
- a feature import from Platform or Design System;
- a production import from `test/contracts`;
- an unapproved composition root;
- an unresolved relative import;
- an absolute, escaping, case-mismatched, symlink, or junction path;
- a re-created old root after strict activation;
- a public API that re-exports another feature or exposes an unapproved
  symbol.

The package exposes separate scanner-test and strict-scan commands. The Admin
CI job runs both before unit tests and remains fail-closed; there is no
permanent Admin baseline.

## Existing-Test Change Contract

All 96 existing tests remain selected. Existing assertions, expected values,
fixtures, Arabic/error literals, timeouts, and behavioral setup semantics are
frozen.

Allowed changes are:

- test-file moves from the fate map;
- import/export/module-specifier path edits required by a move;
- raw `?raw` path edits in the three cross-feature contract tests;
- the exact `DashboardPage.test.tsx` mock-target exception below;
- one exact location-aware `AdminPaginationContract.test.ts` transformation:
  add a third expected-import value to each of the existing seven page records,
  bind that value in the existing loop, and replace only the fixed Pagination
  assertion operand with `` `from '${expectedPaginationImport}'` ``.

`DashboardPage.test.tsx` currently mocks `getStats` and
`getProviderApplications` from one `api/admin` module. After the API split it
may replace that one module target with two targets:

- `getStats` from `features/dashboard/api.ts`;
- `getProviderApplications` from `features/providers/api.ts`.

The exported mock names, mock implementations, fixtures, `beforeEach` values,
test names, assertions, expected values, and render behavior remain unchanged.
No other setup exception is authorized.

The Pagination transformation changes no selected page, raw fixture, assertion
operator, test name, pagination condition, or behavior. It begins in Task 2,
when the shared component moves. The exact expected values are stage-aware:

| Stage | `../../design_system/Pagination` | `../design_system/Pagination` |
| --- | --- | --- |
| Task 2 and Task 3 | none | Users, ProviderApplications, Providers, Services, Reviews, ConversationReports, Notifications |
| Task 4 | Users, ProviderApplications, Providers | Services, Reviews, ConversationReports, Notifications |
| Task 5 | Users, ProviderApplications, Providers, Services | Reviews, ConversationReports, Notifications |
| Task 6 onward | all seven pages | none |

The scope checker must first prove that the immutable base contains exactly the
seven original two-field records, the two-variable loop binding, and the fixed
literal `from '../components/Pagination'` exactly once. At each candidate stage
it then requires exactly the same seven page/source identities and order, one
third field per record, the three-variable binding, and the exact dynamic
assertion operand above. Each third field must equal the stage table, must be
one of only the two allowed literals, must match the Pagination import found in
that raw page source, and must resolve from that page's current location to
`admin-web/src/design_system/Pagination.tsx`. Missing, duplicate, extra,
reordered, or unresolved records fail closed.

For behavioral comparison the checker canonicalizes only this exact approved
shape: it removes the third field from the seven records, removes the third
loop binding, and replaces the dynamic assertion operand with the immutable
base operand. It then performs the ordinary module-specifier normalization and
requires every remaining token to match the immutable base. It does not use a
broad literal replacement or accept another assertion edit.

The R10 scope checker compares each moved test against the immutable base after
normalizing only import/export module specifiers and `vi.mock` target literals.
For Dashboard it additionally removes the two approved top-level mock-factory
statements and compares all remaining behavioral source, while independently
asserting the exact two factory symbol sets. For the Pagination contract it
applies only the exact location-aware canonicalization above.

## Source Honesty And Tooling Paths

`admin-web/scripts/source-honesty-smoke.mjs` contains hard-coded paths to the
old roots. R10 updates those paths mechanically and keeps all 12 check names and
semantics unchanged. The check must read the final owner files rather than
accept missing files or skip a condition.

The build-config, route-smoke, runtime-config, Docker, Nginx, and managed Admin
runtime scripts keep their behavior. Only a path literal may change where a
script directly names a moved source file.

## Data, Security, And Behavior Preservation

R10 freezes:

- all Admin route paths, redirects, guards, permission values, and navigation;
- all Backend API paths, methods, payloads, response handling, and error maps;
- password plus OTP login, password recovery, refresh-cookie rotation,
  in-memory access token, logout, session expiry, and safe return path;
- all Arabic text, empty/loading/error states, tables, filters, pagination,
  focus behavior, responsive layout, CSS classes, and rendered actions;
- Admin RBAC, audit visibility, provider lifecycle rules, and financial-data
  privacy;
- Backend, Mobile, Prisma schema, migrations, seed, deployment, Docker,
  Compose, Dokploy, dependencies, and lockfiles;
- the generated 22-route Admin contract byte-for-byte.

No package is installed or upgraded. `admin-web/package-lock.json` remains at
its verified SHA-256. No migration, seed, runtime data, secret, credential,
phone number, OTP, token, or private business value is written to a report.

## Migration Milestones

The implementation plan must define exact per-milestone source inventories,
allowed changed paths, and scanner mode. The intended review units are:

1. governance and frozen contracts;
2. Platform, Design System, and mechanical consumer import redirects;
3. Auth feature and public API;
4. Dashboard, Users, and Providers;
5. Catalog and Services;
6. Moderation, Notifications, Audit, and contract tests;
7. composition-root finalization, old-root deletion, and strict CI;
8. exhaustive local verification plus isolated Admin runtime;
9. truthful documentation and final independent review.

Each source-changing milestone must end with its exact scope guard, scanner
tests, current-stage scan, Admin unit tests, typecheck, source honesty, and diff
audit green. A task may not proceed after a failed gate.

## Verification Contract

### Admin governance and static gates

- scanner contract tests PASS;
- exact R10 scope tests PASS;
- current-stage scan PASS for intermediate milestones;
- final strict scan reports zero violations;
- old roots are absent;
- no unapproved cross-feature edge exists;
- existing-test normalized diff audit PASS;
- Admin route document remains byte-identical at 22 routes and the frozen
  SHA-256;
- external Admin request method/path inventory remains identical;
- Arabic string-literal multiset remains identical;
- lockfile remains byte-identical.

### Admin behavior and build gates

- all 18 existing test files / 96 existing tests plus new governance tests;
- `npm run typecheck`;
- `npm run build`;
- `npm run smoke:honesty` with 12/12 semantics unchanged;
- `npm run smoke:routes`;
- `npm run test:container-config` with 3/3;
- `npm audit --audit-level=high` with zero findings.

### Complete mission re-proof

- Backend architecture, check, build, full tests, both audits, Prisma validate
  and generate, DMMF/migration equivalence, affected smokes, and full
  `smoke:all`;
- dependency debt is exactly 22 and ownership debt exactly 385/781, or lower
  only if an independently approved prior correction changed the base before
  R10 starts; any unexplained difference stops the phase;
- Mobile strict-boundary governance, `flutter analyze`, and full
  `flutter test` with Mobile source unchanged;
- docs sync check, docs verification, generated-route equivalence, and
  `git diff --check`;
- final protected-surface and allowed-path-fence checks.

### Runtime acceptance

Run the managed Admin runtime smoke against a disposable migrated database and
exercise local Admin login/session/RBAC/catalog behavior without printing
credentials or OTP values. Run an isolated built Admin preview and confirm the
current route set and fail-closed behavior.

A local-development OTP code or mocked delivery proves the Admin integration
flow only. It must not be reported as real WhatsApp delivery. No deployment,
production mutation, or remote CI is part of local R10 completion.

## Documentation And Final Report

R10 updates only active documents whose truth changes:

- `ARCHITECTURE.md` — final Admin laws, exact existing-test exceptions, R10
  status, and honest Backend debt;
- `docs/README.md` — R10 design/plan/report links and stop boundary;
- `docs/project/STATUS.md` and `docs/project/DECISIONS.md` — local result and
  decisions;
- `docs/project/EXECUTION_PLAN.md` — completed local wave and declared gaps;
- `docs/frontend/ADMIN_WEB.md` and relevant frontend architecture references —
  final source layout and commands;
- `docs/backend/README.md` only to state the re-proven Backend debt accurately;
- `docs/qa/README.md` — exact commands/results/blocked external checks;
- `CHANGELOG.md` — local architectural change;
- generated references only through the existing docs tooling;
- `docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md` —
  final evidence receipt and mission gap report.

The report must separate PASS, FAIL, BLOCKED, and UNVERIFIED evidence. It must
state that R10 is locally complete only if every required local gate passed,
and it must retain these exclusions unless separately proven:

- no push or merge;
- no deployment or production mutation;
- no remote CI claim;
- no real WhatsApp delivery claim;
- no live Firebase Push claim;
- no claim that non-zero Backend dependency/ownership debt is resolved.

## Failure And Stop Rules

Stop R10 at the earliest occurrence of any of these:

- route, method, URL, payload, response, permission, Arabic copy, or rendered
  behavior changes;
- a test assertion, fixture, expected value, timeout, or setup change outside
  the exact Dashboard mock-target and location-aware Pagination exceptions;
- an old and new implementation coexist after their relocation checkpoint;
- the Provider/Catalog graph becomes reciprocal;
- the scanner needs a permanent baseline or broad exception to pass;
- Admin lockfile or dependency drift;
- Backend, Mobile, database, deployment, Docker, Compose, or Dokploy source
  changes;
- dependency or ownership debt grows or changes without an approved cause;
- any required test, build, architecture, audit, smoke, docs, runtime, scope,
  or independent-review gate fails.

Do not patch around a failure, weaken a guard, silently exclude a file, or
advance to documentation closeout with a red gate.

## Git Discipline

This written design does not authorize a branch, worktree, commit, push,
merge, PR mutation, deployment, or remote-CI run. All Git actions remain
stopped unless the owner explicitly authorizes the exact action in the current
task.

The implementation plan may define review checkpoints, but execution must
record them without changing Git state until separate authorization exists.

## Definition Of Done

R10 is locally complete only when:

1. the exact Admin fate map is complete and the four old roots are absent;
2. all feature imports obey the acyclic owner graph through exact public APIs;
3. strict Admin governance and adversarial tests pass without a permanent
   baseline;
4. the 22 routes, request contracts, Arabic literals, tests, lockfile, UI,
   auth/session/RBAC behavior, and deployment surfaces are preserved;
5. Admin static, unit, build, honesty, route, container, audit, and isolated
   runtime gates pass;
6. Backend, Mobile, Prisma, full smoke, docs, protected-surface, and scope gates
   pass in the final combined run;
7. an independent reviewer approves source, contracts, gates, and the final
   report;
8. the final report declares R10 complete but retains every unclosed external
   gate and the live 22 plus 385/781 Backend debt;
9. no push, merge, deployment, remote CI, or architecture-target-complete claim
   is made without separate evidence and authorization.

## Independent Pre-Spec Review Receipt

An independent read-only reviewer evaluated the proposed R10 direction against
the historical R0-R10 design, active documents, and live Admin source.

Verdict: `REVISE` with zero Critical, four Important, and one Minor finding.

This written design incorporates the four important corrections:

- truthful phase-complete versus architecture-target-complete language;
- current-state fate coverage for NotFound, provider helpers, contract tests,
  and hard-coded tooling paths;
- explicit fail-closed Admin laws, public APIs, composition roots, strict CI,
  and no permanent baseline;
- the exact Dashboard mock-target test exception with frozen behavioral
  assertions and fixtures.

The reviewer did not review this final written artifact after those corrections.
Written-spec owner review and later plan/source reviews therefore remain
required.

## Independent Plan Review Correction Receipt

A later independent read-only review of the first complete implementation plan
returned `NOT APPROVED` with zero Critical, five Important, and one Minor
finding. This revision incorporates those findings before execution:

- `AdminRbacAuditContract.test.ts` moves during Task 3 so the declared
  `auth=0` milestone is reachable;
- the graph matches live source with `dashboard -> auth, providers` and
  `audit -> (none)` everywhere;
- the exact 18 feature screens plus Platform NotFound are the only direct
  screen imports allowed to `App.tsx`;
- the Pagination contract has one explicit, stage-aware, location-resolving
  assertion-shape exception for its existing seven pages;
- the 62-record request projection excludes the generic transport fetch and
  defines the exact canonical serialization that reproduces its frozen hash;
- final Prisma verification compares both base and candidate DMMF artifacts.

A second independent read-only review confirmed all six corrections above and
found one remaining Important staging defect: a single final Pagination literal
could not represent the mixed page locations in Tasks 2-5. The location-aware
seven-page contract and Task 2-6 table above are the root correction; they keep
the assertion fail-closed at every checkpoint instead of weakening an
intermediate gate.

Independent rereview of the corrected design and plan remains a hard gate before
Task 1 execution. Recording a later verdict does not require changing these
approved artifacts or their reviewed hashes.
