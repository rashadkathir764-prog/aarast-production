# Modular Monolith R10 Admin Restructure And Truthful Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure Admin Web into strict owner-controlled feature boundaries,
preserve every observable Admin contract, and close the R0-R10 local execution
wave with an honest report of the remaining Backend architecture debt.

**Architecture:** Freeze the immutable R10 contracts first, then relocate
Platform and Design System, establish Auth, and drain the monolithic Admin API
into eight acyclic feature owners in reviewable stages. Activate a TypeScript-
AST boundary scanner and strict CI only after the four old roots reach zero,
then re-prove Admin, Backend, Mobile, Prisma, smoke, docs, security, and runtime
contracts in one local closeout sequence.

**Tech Stack:** Windows/PowerShell, Node.js 22, TypeScript 5.9.3 compiler API,
React 18.3.1, Vite 7.3.6, Vitest 4.1.10, React Router 7.18.2, GitHub Actions,
NestJS/Prisma/PostgreSQL verification, Flutter/Dart verification, Docker Compose
isolated smoke infrastructure.

**Spec:**
`docs/superpowers/specs/2026-08-30-modular-monolith-r10-admin-closeout-design.md`

**Status:** Owner-approved design; first and second independent plan-review
findings incorporated; final independent rereview required before
implementation; implementation has not started

## Global Constraints

- Work only in `D:\projects\aarast-modular-monolith` on the existing
  `modular-monolith` branch.
- Immutable R10 base is
  `e560e5784278907dd6bf565327c3abfa0c9b8cab`.
- The approved design SHA-256 is
  `7abc4aecf3cfcceb4a6b601fcbe83377371a4aed58cb0cf06bce7a67d200f76e`.
- This plan does not authorize a branch, worktree, checkout, stage, commit,
  push, merge, PR mutation, deployment, production mutation, or remote-CI run.
  The skill's normal commit step is replaced by a read-only review checkpoint.
  A later owner instruction must authorize each Git action explicitly.
- R10 is Admin architecture work plus final verification and documentation. Do
  not modify Backend source, Mobile source, Prisma schema/migrations/seed,
  dependencies, lockfiles, Docker, Compose, Dokploy, deployment, product scope,
  Admin UI behavior, routes, API contracts, permissions, Arabic copy, OTP, or
  session behavior.
- Keep `admin-web/package-lock.json` byte-identical at SHA-256
  `e663c4fcb3f17a7aeb8923d3563d27ed543267d24f780ae939ba23d0dcb48757`.
- Keep `docs/frontend/ADMIN_ROUTES.md` byte-identical at 22 routes and SHA-256
  `a1e3ee774bafca860ee0e95461b9e2384c719fcc6c1fb1eb01d6b4b945672e5e`.
- Preserve the canonical Admin request inventory at exactly 62 sorted records
  and SHA-256
  `a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9`.
  Template expressions normalize to `<expr>`.
- Preserve the production Arabic-literal multiset at exactly 1,020 records and
  SHA-256
  `db93ddc6d31d7e79410fb6e1d711e9cdb56ee69cfd2563dab549124bf398f0d0`.
- Preserve all 18 existing Vitest files and 96 existing tests. The only setup
  exception is splitting the two `DashboardPage.test.tsx` API mock targets.
  The only assertion-shape exception is the exact stage-aware Pagination
  contract transformation defined by the spec. All other assertions, fixtures,
  names, expected values, timeouts, and behavior stay unchanged.
- Every cross-feature production import targets the exact
  `features/<owner>/api.ts`. The only deep screen-import exception is the exact
  `App.tsx` allowlist in Appendix B. Platform and Design System import no
  feature.
- The only composition roots are `App.tsx`, `main.tsx`, `layout/**`, and the
  test-only `test/contracts/**` exception defined by the spec.
- A moved implementation is deleted from its old path in the same task. Never
  add a facade, re-export alias, duplicate, fallback, symlink, junction, or
  compatibility layer.
- Every source-changing task runs its scanner tests, exact stage scan, R10
  scope gate, Admin tests, typecheck, source honesty, and diff review. Stop on
  the first red gate.
- Backend dependency debt must remain exactly 22 and physical-ownership debt
  exactly 385 records / 781 occurrences. A different value is a stop unless a
  separately approved pre-R10 correction changed the immutable base.
- Never print or retain secrets, credentials, OTPs, tokens, phone numbers,
  private data, raw business content, environment values, or device serials.

## Planned File Responsibilities

| Path or group | Responsibility |
| --- | --- |
| `admin-web/architecture/r10-admin-boundaries.json` | Immutable base, hashes, source fate map, feature graph, legacy-root milestones, request/copy/test contracts, and exact changed-path fence |
| `admin-web/scripts/admin-boundaries.mjs` | TypeScript-AST import/export/require/dynamic-import scanner and stage/strict CLI |
| `admin-web/scripts/admin-boundaries.contract.mjs` | Positive, adversarial, traversal, resolution, graph, public-API, and old-root scanner proofs |
| `scripts/check-r10-scope.mjs` | Fixed-base path/hash/protected-surface/request/copy/test/milestone checker |
| `scripts/check-r10-scope.test.mjs` | Manifest, path, hash, test-normalization, stage, and escape rejection proofs |
| `admin-web/src/platform/api/client.ts` | Existing API client and in-memory Admin session behavior |
| `admin-web/src/platform/api/query.ts` | `Paginated<T>` and unchanged query-string construction |
| `admin-web/src/platform/i18n/formatDate.ts` | Existing shared `ar-YE` date formatter |
| `admin-web/src/platform/errors/ErrorBoundary.tsx` | Existing top-level render recovery boundary |
| `admin-web/src/platform/routing/NotFoundPage.tsx` | Existing Admin fallback page |
| `admin-web/src/design_system/**` | Existing reusable Admin components, one-to-one, excluding ErrorBoundary |
| `admin-web/src/features/auth/api.ts` | Sole cross-feature Auth public surface |
| `admin-web/src/features/auth/transport.ts` | Existing login/OTP/recovery/refresh/logout transport and error mapping |
| `admin-web/src/features/dashboard/api.ts` | Dashboard statistics and operational report transport/types |
| `admin-web/src/features/users/api.ts` | User list/detail/status transport and user-owned response projections |
| `admin-web/src/features/providers/api.ts` | Provider/application DTOs, reads, and lifecycle mutations |
| `admin-web/src/features/catalog/api.ts` | Cities, categories, services, dynamic catalogs, and geography transport/types |
| `admin-web/src/features/moderation/api.ts` | Review and conversation-report transport/types |
| `admin-web/src/features/notifications/api.ts` | Admin notification transport/types |
| `admin-web/src/features/audit/api.ts` | Read-only Admin audit transport/types |
| `admin-web/src/test/contracts/**` | Three exact cross-feature raw-source contracts |
| `.github/workflows/ci.yml` | Strict Admin scanner tests and strict boundary gate after local zero |
| Active R10 docs and final report | Exact local evidence, remaining gaps, and external stop boundary |

---

### Task 1: Govern The Exact R10 Contract Before Moving Source

**Files:**

- Create: `admin-web/architecture/r10-admin-boundaries.json`
- Create: `admin-web/scripts/admin-boundaries.mjs`
- Create: `admin-web/scripts/admin-boundaries.contract.mjs`
- Create: `scripts/check-r10-scope.mjs`
- Create: `scripts/check-r10-scope.test.mjs`
- Modify: `ARCHITECTURE.md`

**Interfaces:**

- Consumes: immutable base, approved design, exact fate map in Appendix A,
  public surface map in Appendix B, milestones in Appendix C, and fence in
  Appendix D.
- Produces:

```js
parseAdminModuleSpecifiers({ sourceText, relativePath })
// => [{ kind, specifier, typeOnly, dynamic, line }]

resolveAdminSpecifier({ srcRoot, sourcePath, specifier })
// => { external: true } | { external: false, targetPath }

classifyAdminPath({ relativePath, manifest })
// => { zone, feature: string | null, compositionRoot: boolean }

scanAdminBoundaries({ srcRoot, manifest, stage })
// => { errors, edges, legacyRoots, publicApis, sourceFiles }

extractAdminRequestInventory({ sourceFiles })
// => sorted strings such as "PATCH /admin/providers/<expr>/approve"

extractAdminArabicLiteralInventory({ sourceFiles })
// => sorted production string/template/JSX literal multiset

normalizeExistingAdminTest({ sourceText, relativePath, manifest })
// => canonical behavioral source with approved module targets removed

checkR10Scope({ repoRoot, task, manifest })
// => { ok, errors, changedPaths, requestHash, arabicHash, testDiffs }
```

All outputs are repository-relative, canonical, unique where set semantics
apply, sorted, and sanitized. No absolute path, source text, environment value,
or secret appears in normal output.

`changedPaths` is the union of fixed-base tracked changes from
`git diff --name-status -z <base>` and untracked files from
`git ls-files --others --exclude-standard -z`. Rename/copy records are expanded
to both source and destination before fence evaluation. Deleted paths remain
visible. NUL-delimited parsing is mandatory so spaces and non-ASCII names do
not weaken the fence.

- [ ] **Step 1: Verify the immutable inputs before writing governance**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git rev-parse HEAD
Get-FileHash -Algorithm SHA256 .\docs\superpowers\specs\2026-08-30-modular-monolith-r10-admin-closeout-design.md
Get-FileHash -Algorithm SHA256 .\docs\frontend\ADMIN_ROUTES.md
Get-FileHash -Algorithm SHA256 .\admin-web\package-lock.json
git status --short
```

Expected: HEAD equals the immutable base; the three hashes equal Global
Constraints; status contains only the approved design and this plan. Stop if
any application, generated, package, or unknown path is already dirty.

- [ ] **Step 2: Add the canonical R10 laws and test exception first**

Add one R10 section to `ARCHITECTURE.md` that copies these exact rules from the
spec: eight owners, exact feature graph, exact App screen allowlist,
composition roots, strict final old-root absence, no permanent baseline,
truthful `phase complete` language, Dashboard two-mock-target exception, and
Pagination location-aware seven-page exception. Record planning status only;
do not claim implementation or completion.

- [ ] **Step 3: Write boundary-scanner RED fixtures**

Use temporary directories created by `mkdtemp` and `node:test`. Add named tests
for every case in this fixed array:

```js
const requiredBoundaryCases = [
  'accepts same-feature imports',
  'accepts platform and design-system imports from a feature',
  'accepts only an allowed feature edge through owner api.ts',
  'rejects a deep cross-feature import',
  'rejects an undeclared feature edge',
  'rejects providers importing catalog',
  'rejects platform importing a feature',
  'rejects design-system importing a feature or layout',
  'accepts exact App main layout composition roots',
  'accepts only the exact App screen-import allowlist',
  'rejects an unlisted App screen and any screen import from main or layout',
  'rejects an unapproved production composition root',
  'accepts exact test/contracts raw-source composition',
  'rejects production imports from test/contracts',
  'recognizes import type export-from import-equals require and dynamic import',
  'rejects unresolved relative imports',
  'rejects absolute traversal case symlink and junction escapes',
  'enforces exact stage legacy-root counts and file identities',
  'rejects wildcard and cross-feature public re-exports',
  'requires strict old-root absence',
];
```

- [ ] **Step 4: Write scope-guard RED fixtures**

Add tests that reject wrong base/design/hash/count/order, duplicate and
absolute paths, `..`, slash/case near-misses, symlink/junction escape, unknown
task, an unapproved changed path, protected Backend/Mobile/deployment/lockfile
drift, request count/hash drift, Arabic count/hash drift, a changed test
assertion/fixture/timeout, an unauthorized `vi.mock` change, and every wrong
legacy-root milestone. Add positive fixtures for import-only test moves, the
exact Dashboard two-target split, and the exact Pagination transformation from
seven two-field records plus a fixed literal into seven three-field records
plus one dynamic expected-import operand. For every Task 2-6 stage, require the
exact seven identities and order, exact stage values from the spec, no other
value, and resolution from each page's current path to
`src/design_system/Pagination.tsx`. Reject a missing, duplicate, extra,
reordered, unresolved, wrongly staged, or behaviorally changed record.

- [ ] **Step 5: Run RED and preserve the failure reason**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
```

Expected: new tests fail because the manifest/scanner/scope implementation is
absent. No existing application test is edited to obtain RED.

- [ ] **Step 6: Implement the manifest and AST scanner**

The manifest must encode these exact immutable values:

```json
{
  "version": 1,
  "phase": "R10",
  "base": "e560e5784278907dd6bf565327c3abfa0c9b8cab",
  "designSha256": "7abc4aecf3cfcceb4a6b601fcbe83377371a4aed58cb0cf06bce7a67d200f76e",
  "adminRoutes": {
    "count": 22,
    "sha256": "a1e3ee774bafca860ee0e95461b9e2384c719fcc6c1fb1eb01d6b4b945672e5e"
  },
  "adminLockfileSha256": "e663c4fcb3f17a7aeb8923d3563d27ed543267d24f780ae939ba23d0dcb48757",
  "requestInventory": {
    "count": 62,
    "sha256": "a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9"
  },
  "arabicLiteralInventory": {
    "count": 1020,
    "sha256": "db93ddc6d31d7e79410fb6e1d711e9cdb56ee69cfd2563dab549124bf398f0d0"
  }
}
```

Use `typescript` from existing Admin dev dependencies. Traverse
`ImportDeclaration`, `ExportDeclaration`, `ImportEqualsDeclaration`,
`require(...)`, and `import(...)`; normalize extensionless `.ts`/`.tsx` and
`index` resolution; resolve the real path before accepting containment.

- [ ] **Step 7: Implement request, copy, and test equivalence**

Generate the base request-call projection from the three immutable transport
files and the candidate projection from every production Admin `.ts/.tsx`
file. Select `apiRequest(...)` plus only direct `fetch(...)` calls whose
canonical first argument begins `/`. Omit a leading template expression only
when it is exactly the identifier `apiBaseUrl`; replace every other expression
with `<expr>`. Therefore the refresh call becomes exactly
`POST /api/v1/auth/admin/refresh`, while the generic client fetch whose
remaining route is only the runtime `path` is excluded. Use `GET` unless an
object-literal options property has a string-literal method, then uppercase it.
Fail on unsupported selected path/method syntax. Format every record as
`${METHOD} ${PATH}`, retain duplicates, default-sort the strings, and hash the
UTF-8 bytes of `JSON.stringify(records)`. Require exactly 62 records and the
manifest hash; this algorithm must reproduce
`a740ff61ff987899c5f64520de2f74839c1257314383912929fd93970d77fbf9`
from the immutable base before it is allowed to inspect a candidate.

Arabic extraction scans production `.ts/.tsx`, excludes `*.test.*` and
`src/test/**`, and records Arabic-bearing string literals, no-substitution
templates, template head/middle/tail fragments, and JSX text.

Test normalization removes only import/export module specifiers and `vi.mock`
target literals. For Dashboard, remove the approved top-level mock-factory
statements from behavioral comparison and separately require factory symbol
sets `{ getStats }` and `{ getProviderApplications }`. Parse both replacement
factories and require a zero-argument arrow returning exactly the named property
mapped to `vi.fn()` with no extra key, spread, wrapper, argument, or alternate
implementation. For `AdminPaginationContract.test.ts`, prove the immutable base
has exactly its seven ordered two-field records, two-variable loop, and fixed
Pagination literal. Candidate Task 2-6 must contain the same ordered page/source
identities with exactly one expected-import third field, a three-variable loop,
and only `` `from '${expectedPaginationImport}'` `` as the assertion operand.
Validate every stage value and raw page import against the exact table in the
spec, allow only `../design_system/Pagination` or
`../../design_system/Pagination`, and resolve the value from the page's current
location to `src/design_system/Pagination.tsx`. For behavioral comparison,
remove exactly those seven third fields and the third binding, restore the base
operand, then require all remaining normalized source unchanged.

- [ ] **Step 8: Run GREEN and the exact Task 1 stage**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-1
node .\scripts\check-r10-scope.mjs --task task-1
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: all pass; legacy roots are exactly `api=5`, `auth=9`,
`components=27`, `pages=24`; strict mode still fails specifically because
approved legacy roots remain.

- [ ] **Step 9: Record the read-only review checkpoint**

```powershell
git status --short
git diff --name-status e560e5784278907dd6bf565327c3abfa0c9b8cab
git diff --check
```

Expected: only Task 1 paths plus the design/plan are present. Obtain an
independent read-only review of governance rules and adversarial tests. Do not
stage or commit.

---

### Task 2: Relocate Platform And Design System Without Behavior Drift

**Files:**

- Move: `admin-web/src/api/client.ts` and `client.test.ts` to
  `admin-web/src/platform/api/`
- Create: `admin-web/src/platform/api/query.ts`
- Create: `admin-web/src/platform/api/query.test.ts`
- Create: `admin-web/src/platform/i18n/formatDate.ts`
- Create: `admin-web/src/platform/i18n/formatDate.test.ts`
- Move: `admin-web/src/components/ErrorBoundary.tsx` and test to
  `admin-web/src/platform/errors/`
- Move: `admin-web/src/pages/NotFoundPage.tsx` to
  `admin-web/src/platform/routing/NotFoundPage.tsx`
- Move one-to-one to `admin-web/src/design_system/`:
  `ActionButton.tsx`, `ConfirmDialog.tsx`, `ConfirmDialog.test.tsx`,
  `DataTable.tsx`, `DataTable.test.tsx`, `DetailField.tsx`, `EmptyState.tsx`,
  `ErrorState.tsx`, `FilterSelect.tsx`, `FormCard.tsx`, `FormField.tsx`,
  `LoadingSkeleton.tsx`, `LoadingState.tsx`, `MiniDonut.tsx`, `PageHeader.tsx`,
  `Pagination.tsx`, `Pagination.test.tsx`, `RoleBadge.tsx`, `SearchInput.tsx`,
  `SearchInput.test.tsx`, `SectionCard.tsx`, `StatCard.tsx`, `StatusBadge.tsx`,
  `TableToolbar.tsx`, `Timeline.tsx`
- Modify import paths in all current consumers under `admin-web/src/**`
- Modify: `admin-web/src/pages/AdminPaginationContract.test.ts`
- Modify moved-source paths only in
  `admin-web/scripts/source-honesty-smoke.mjs`

**Interfaces:**

- Consumes: Task 1 stage-aware scanner/scope guard and exact existing files.
- Produces:

```ts
export type QueryValue = string | number | boolean | null | undefined;
export type Paginated<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};
export function toQuery<T extends object>(params: T): string;
export function formatDate(value?: string | null): string;
```

- [ ] **Step 1: Add query-helper RED tests**

```ts
expect(toQuery({})).toBe('');
expect(toQuery({ status: 'PENDING', empty: '', nil: null, missing: undefined }))
  .toBe('?status=PENDING');
expect(toQuery({ page: 0, unreadOnly: false, search: 'قاعة & صالة' }))
  .toBe(`?${new URLSearchParams({
    page: '0', unreadOnly: 'false', search: 'قاعة & صالة',
  }).toString()}`);
```

Run only the new file. Expected: FAIL because `query.ts` does not exist.

- [ ] **Step 2: Implement the exact query behavior**

```ts
export function toQuery<T extends object>(params: T): string {
  const searchParams = new URLSearchParams();
  Object.entries(params as Record<string, QueryValue>).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.set(key, String(value));
    }
  });
  const query = searchParams.toString();
  return query ? `?${query}` : '';
}
```

Move `Paginated<T>` unchanged from `api/admin.ts`; remove it and `toQuery` from
the old file in the same edit.

- [ ] **Step 3: Add exactly two date-helper RED tests**

In the first test, loop over `[null, undefined]` and require both values to
return `غير محدد`. In the second test, spy on `Intl.DateTimeFormat` for a
non-null value and require locale `ar-YE`, options `{ year: 'numeric', month:
'short', day: 'numeric' }`, one call to `format(new Date(value))`, and the
formatter's return value unchanged. Together with the three query-helper tests,
this adds exactly five tests. Expected: both date tests FAIL before the file
exists.

- [ ] **Step 4: Move the exact date implementation**

```ts
export function formatDate(value?: string | null) {
  if (!value) return 'غير محدد';
  return new Intl.DateTimeFormat('ar-YE', {
    year: 'numeric', month: 'short', day: 'numeric',
  }).format(new Date(value));
}
```

Delete only this function from `pages/providerHelpers.tsx`; redirect its seven
current consumers to Platform. Leave page-local formatters untouched.

- [ ] **Step 5: Move client, ErrorBoundary, NotFound, and Design System files**

Move each exact file one-to-one, update relative imports, and delete each old
path in the same change. Do not change component bodies, props, DOM, CSS class
names, accessibility behavior, tests, or Arabic strings.

- [ ] **Step 6: Install the exact location-aware Pagination contract**

Preserve the seven existing page/source records and their order. Add one third
field named `expectedPaginationImport` to every record, bind it as the third
loop value, and replace only the current fixed assertion operand with
`` `from '${expectedPaginationImport}'` ``. Because all seven pages still live
under `src/pages` in Task 2, every third field is exactly
`../design_system/Pagination`. The scope checker must prove the authorized AST
shape, exact identities/order, raw page import equality, and resolution to
`src/design_system/Pagination.tsx`; it must reject any other behavioral edit.

- [ ] **Step 7: Update the honesty script mechanically**

Redirect `StatusBadge` to `src/design_system/StatusBadge.tsx` and the API client
to `src/platform/api/client.ts`. Keep all 12 check names, conditions, and
failure semantics unchanged.

- [ ] **Step 8: Run Task 2 gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-2
node .\scripts\check-r10-scope.mjs --task task-2
Set-Location .\admin-web
npm test -- --run
npm run typecheck
npm run smoke:honesty
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: existing 96 tests plus five focused helper tests pass; stage counts
are `api=3`, `auth=9`, `components=0`, `pages=23`; honesty remains 12/12;
request/copy/route/lock hashes remain frozen.

- [ ] **Step 9: Review without Git mutation**

Review exact moves/imports and Task 2 scope output. Obtain independent read-only
review of Platform purity, Design System purity, and behavior equivalence. Do
not stage or commit.

---

### Task 3: Establish The Auth Feature And Its Acyclic Public API

**Files:**

- Move: `admin-web/src/api/auth.ts` to
  `admin-web/src/features/auth/transport.ts`
- Move: `admin-web/src/api/auth.test.ts` to
  `admin-web/src/features/auth/transport.test.ts`
- Create: `admin-web/src/features/auth/api.ts`
- Move all current non-contract `admin-web/src/auth/*` files one-to-one under
  `admin-web/src/features/auth/`
- Move: `admin-web/src/auth/AdminRbacAuditContract.test.ts` to
  `admin-web/src/test/contracts/AdminRbacAuditContract.test.ts`
- Move: `pages/LoginPage.tsx` and `LoginPage.test.tsx` under
  `admin-web/src/features/auth/`
- Modify imports in `App.tsx`, `main.tsx`, all eight `layout/**` files, current
  pages, remaining `api/admin.ts`, and affected tests
- Modify path literals only in `source-honesty-smoke.mjs` and the moved
  `test/contracts/AdminRbacAuditContract.test.ts`

**Interfaces:**

- Consumes: `platform/api/client.ts` and current Auth implementation.
- Produces exact public exports:

```ts
export {
  startAdminLogin,
  completeAdminLogin,
  requestAdminPasswordReset,
  confirmAdminPasswordReset,
  restoreAdminSession,
  logoutAdmin,
} from './transport';
export type {
  AdminUser,
  OtpDeliveryStatus,
  AdminLoginChallenge,
  AdminPasswordResetChallenge,
} from './transport';
export { AdminPermission, hasAdminPermission } from './adminPermissions';
export { AuthProvider, useAuth } from './AuthProvider';
export { Can } from './Can';
export { RequireAdmin } from './RequireAdmin';
export { RequireAdminPermission } from './RequireAdminPermission';
```

Internal Auth files import `transport`, `AuthProvider`, and
`adminPermissions` directly. They do not import their own public barrel, so no
runtime cycle is created.

- [ ] **Step 1: Add the Auth public-surface RED fixture**

Extend the boundary contract suite with a fixture that fails unless the exact
named public exports above exist, no wildcard export exists, and every export
resolves inside `features/auth`. Run the focused test and observe RED.

- [ ] **Step 2: Move transport and Auth internals**

Move bodies one-to-one. Change only relative module specifiers. Keep API paths,
validation, Arabic errors, `ApiError` mapping, challenge checks, refresh-cookie
behavior, access-token memory, logout-finally behavior, and safe return path
unchanged.

- [ ] **Step 3: Create the explicit Auth public API**

Write the exact named exports in Interfaces. Do not export
`safeAdminReturnPath`; it remains internal to Login. Do not re-export Platform
or another feature.

- [ ] **Step 4: Redirect consumers according to ownership**

`App.tsx`, `main.tsx`, `layout/**`, and non-Auth features consume the public
Auth API. `App.tsx` uses its separately governed direct Login screen exception.
Auth-owned files consume their internal siblings. `api/admin.ts` imports only
`AdminUser` from the public API. Move `AdminRbacAuditContract` to
`test/contracts/` and update it to inspect `features/auth/transport.ts?raw` for
session fields; this is a test-file move plus raw path edit, not an assertion
change.

- [ ] **Step 5: Update Auth tests mechanically**

Move tests, update import and `vi.mock` targets only, and preserve all existing
test bodies. The contract scope normalizer must report zero unauthorized
behavioral differences.

- [ ] **Step 6: Update honesty paths and run Task 3 gates**

Point the honesty script at Auth transport and Login owner paths, keeping its
conditions exact. Then run:

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-3
node .\scripts\check-r10-scope.mjs --task task-3
Set-Location .\admin-web
npm test -- --run
npm run typecheck
npm run smoke:honesty
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: stage counts `api=1`, `auth=0`, `components=0`, `pages=21`; all 101
Vitest tests and 12 honesty checks pass; request inventory remains 62.

- [ ] **Step 7: Review without Git mutation**

Obtain independent read-only review of Auth cycles, public exports, frozen OTP/
session behavior, test normalization, and scope. Do not stage or commit.

---

### Task 4: Move Dashboard Users And Providers Into Owner Features

**Files:**

- Create: `admin-web/src/features/dashboard/api.ts`
- Move: `DashboardPage.tsx`, `DashboardPage.test.tsx`, and `ReportsPage.tsx`
  under `features/dashboard/`
- Create: `admin-web/src/features/users/api.ts`
- Move: `UsersPage.tsx` and `UserDetailsPage.tsx` under `features/users/`
- Create: `admin-web/src/features/providers/api.ts`
- Move: `ProviderApplicationsPage.tsx`,
  `ProviderApplicationDetailsPage.tsx`, `ProvidersPage.tsx`,
  `ProviderDetailsPage.tsx`, and the provider-only remainder of
  `providerHelpers.tsx` under `features/providers/`
- Modify: `admin-web/src/api/admin.ts` by deleting only the moved declarations
  and functions
- Modify import-only composition in `App.tsx`, remaining old pages, and the two
  still-old contract tests that inspect moved sources
- Modify: `admin-web/src/pages/AdminPaginationContract.test.ts`
- Modify the Dashboard path in `source-honesty-smoke.mjs`

**Interfaces:**

- Consumes: Platform query/client/date, Auth public API, Design System.
- Produces:

```ts
// features/dashboard/api.ts
export type AdminStats = {
  totalUsers: number;
  totalProviders: number;
  pendingProviders: number;
  approvedProviders: number;
  rejectedProviders: number;
  needsChangesProviders: number;
  suspendedProviders: number;
  totalQuoteRequests: number;
  totalWeddingPlans: number;
  totalCities: number;
  totalProviderCategories: number;
};
export type AdminReport = {
  generatedAt: string;
  range: { from: string | null; to: string | null };
  users: { total: number; active: number; disabled: number; admins: number; providers: number; regularUsers: number };
  providers: { total: number; pending: number; active: number; needsChanges: number; suspended: number; rejected: number; featured: number };
  services: { total: number; active: number; disabled: number; featured: number };
  reviews: { total: number; published: number; hidden: number; pending: number; averageRating: string };
  quotes: { total: number; byStatus: Array<{ status: string; count: number }> };
  notifications: { total: number; unread: number; archived: number; high: number; urgent: number };
  catalog: { cities: number; categories: number };
  weddingPlans: { total: number };
  source: string;
  paymentOrDepositDataIncluded: boolean;
};
export function getStats(): Promise<AdminStats>;
export function getReportOverview(params?: ReportQueryParams): Promise<AdminReport>;

// features/users/api.ts
export type UserProviderSummary = {
  id: string;
  businessName: string;
  status: string;
  city?: { nameAr: string } | null;
  primaryCategory?: { nameAr: string } | null;
};
export type AdminUserRecord = AdminUser & {
  provider?: UserProviderSummary | null;
};
export function getUsers(params?: UserQueryParams): Promise<Paginated<AdminUserRecord>>;
export function getUser(id: string): Promise<AdminUserRecord>;
export function activateUser(id: string): Promise<AdminUserRecord>;
export function disableUser(id: string): Promise<AdminUserRecord>;

// features/providers/api.ts
export type CityProjection = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  countryCode: string;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};
export type ProviderCategoryProjection = {
  id: string;
  nameAr: string;
  nameEn: string | null;
  slug: string;
  icon: string | null;
  showForGroom: boolean;
  showForBride: boolean;
  isActive: boolean;
  sortOrder: number;
  providersCount?: number;
  servicesCount?: number;
};
export type ProviderServiceProjection = {
  id: string;
  providerId?: string;
  provider?: ProviderReference;
  categoryId?: string;
  title: string;
  description: string | null;
  basePrice: string | null;
  priceUnit: string | null;
  currency: string;
  cityId?: string | null;
  isActive: boolean;
  isFeatured?: boolean;
  category?: ProviderCategoryProjection;
  city?: CityProjection | null;
  images?: Array<{ id: string; serviceId: string; imageUrl: string; altText: string | null; sortOrder: number; createdAt: string }>;
  createdAt?: string;
  updatedAt?: string;
};
export type ProviderPackageProjection = {
  id: string;
  title: string;
  description: string | null;
  price: string | null;
  currency: string;
  items: unknown;
  isActive: boolean;
  service?: { id: string; title: string } | null;
};
export type ProviderReference = {
  id: string;
  businessName: string;
  phone: string;
  whatsapp: string | null;
  logoUrl: string | null;
  status: string;
  ratingAverage: string;
  ratingCount: number;
  city?: CityProjection | null;
  primaryCategory?: ProviderCategoryProjection | null;
};
export type ProviderApplication = {
  id: string;
  userId: string | null;
  user: AdminUser | null;
  cityId: string;
  city: CityProjection | null;
  primaryCategoryId: string | null;
  primaryCategory: ProviderCategoryProjection | null;
  businessName: string;
  ownerName: string | null;
  phone: string;
  whatsapp: string | null;
  email: string | null;
  description: string | null;
  address: string | null;
  logoUrl: string | null;
  coverUrl: string | null;
  status: string;
  reviewNote: string | null;
  reviewedAt: string | null;
  reviewedBy: AdminUser | null;
  isFeatured: boolean;
  ratingAverage: string;
  ratingCount: number;
  servicesCount: number;
  packagesCount: number;
  quoteRequestsCount: number;
  reviewsCount: number;
  services?: ProviderServiceProjection[];
  packages?: ProviderPackageProjection[];
  createdAt: string;
  updatedAt: string;
};
export function getProviderApplications(params?: ProviderQueryParams): Promise<Paginated<ProviderApplication>>;
export function getProviderApplication(id: string): Promise<ProviderApplication>;
export function getProviders(params?: ProviderQueryParams): Promise<Paginated<ProviderApplication>>;
export function getProvider(id: string): Promise<ProviderApplication>;
export function approveProvider(id: string): Promise<ProviderApplication>;
export function rejectProvider(id: string, reason: string): Promise<ProviderApplication>;
export function requestProviderChanges(id: string, note: string): Promise<ProviderApplication>;
export function suspendProvider(id: string, reason: string): Promise<ProviderApplication>;
export function activateProvider(id: string): Promise<ProviderApplication>;
```

The braces above mean mechanical relocation of the complete named type block
from immutable `src/api/admin.ts`; no field is added, removed, renamed, or
retyped. Provider city/category/service projections stay structural inside
Providers. Providers imports Auth for `AdminUser` but never imports Catalog.

- [ ] **Step 1: Add owner-surface and graph RED tests**

Add exact export-list fixtures for dashboard/users/providers. Add a compile-
fixture that fails if Providers imports Catalog or Users imports Providers.
Run focused boundary tests and observe RED.

- [ ] **Step 2: Extract Dashboard transport and move pages**

Move the complete existing `AdminStats`, `AdminReport`, `getStats`, and
`getReportOverview` blocks with unchanged request paths and response fields.
Dashboard imports provider applications only from `../providers/api`.

- [ ] **Step 3: Apply the exact Dashboard mock exception**

Replace the one old import/mock target with:

```ts
import { getStats, type AdminStats } from './api';
import {
  getProviderApplications,
  type ProviderApplication,
} from '../providers/api';

vi.mock('./api', () => ({ getStats: vi.fn() }));
vi.mock('../providers/api', () => ({ getProviderApplications: vi.fn() }));
```

Keep the fixtures, `beforeEach`, test names, render helper, assertions, and
expected values byte-equivalent after normalized module-target removal.

- [ ] **Step 4: Extract Users transport with a structural provider summary**

Define `AdminUserRecord` exactly as Interfaces and move the four request
functions. Replace page-local provider aliases with that type. Do not import
Providers from Users and do not change rendered fields or links.

- [ ] **Step 5: Extract Providers transport without a Catalog edge**

Move provider/application/reference/package types and nine provider functions.
Inline the existing city/category/service response projections inside the
Provider owner so the runtime shape stays exact and the graph stays acyclic.
Move provider helper actions after Task 2's date extraction.

- [ ] **Step 6: Redirect transitional consumers and delete moved old blocks**

Old Services and Reviews pages use `features/providers/api.ts` for current
provider search. Remove every moved declaration/function from `api/admin.ts`;
do not leave re-exports. Update App route imports and raw contract paths only.
In the Pagination contract, change only the expected third fields for Users,
ProviderApplications, and Providers to
`../../design_system/Pagination`; keep Services, Reviews,
ConversationReports, and Notifications at `../design_system/Pagination`.
Require all seven raw page imports to match and resolve to the same Design
System component before the stage gate can pass.

- [ ] **Step 7: Run Task 4 gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-4
node .\scripts\check-r10-scope.mjs --task task-4
Set-Location .\admin-web
npm test -- --run
npm run typecheck
npm run smoke:honesty
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: stage counts `api=1`, `auth=0`, `components=0`, `pages=11`; feature
graph contains only `dashboard -> auth, providers`, `users -> auth`, and
`providers -> auth` among moved owners; all 101 tests pass.

- [ ] **Step 8: Review without Git mutation**

Obtain independent read-only review of DTO equivalence, Dashboard exception,
Provider/Catalog non-cycle, endpoint inventory, and scope. Do not stage or
commit.

---

### Task 5: Move Catalog And Services Without Creating A Provider Cycle

**Files:**

- Create: `admin-web/src/features/catalog/api.ts`
- Move under `admin-web/src/features/catalog/`:
  `CategoriesPage.tsx`, `CitiesPage.tsx`, `ServicesPage.tsx`,
  `ReferenceCatalogsPage.tsx`, `AdministrativeAreasPage.tsx`
- Modify: remaining `admin-web/src/api/admin.ts`
- Modify import-only routes/raw-source paths in `App.tsx`,
  `AdminPaginationContract.test.ts`,
  `test/contracts/AdminRbacAuditContract.test.ts`, and
  `ProviderLifecycleContract.test.ts`

**Interfaces:**

- Consumes: Platform client/query, Auth public API, Providers public API.
- Produces `features/catalog/api.ts` with the complete current fields and these
  exact public symbols:

```text
City, ProviderCategory, ProviderService, ServicePayload, CatalogPayload,
ReferenceCatalogSummary, ReferenceCatalogRevision, ReferenceCatalogItem,
ReferenceCatalog, ReferenceCatalogItemPayload, Governorate, District,
AdministrativeLocalityType, AdministrativeLocality,
AdministrativeLocationPayload,
getServices, createService, updateService, deleteService,
getCategories, createCategory, updateCategory, deleteCategory,
getCities, createCity, updateCity, deleteCity,
getReferenceCatalogs, getReferenceCatalog, createReferenceCatalogItem,
updateReferenceCatalogItem, publishReferenceCatalogItem,
disableReferenceCatalogItem,
getGovernorates, createGovernorate, updateGovernorate, disableGovernorate,
getDistricts, createDistrict, updateDistrict, disableDistrict,
getLocalities, createLocality, updateLocality, disableLocality
```

`ProviderService.provider` retains its existing inline response shape. Catalog
may import only `getProviders` and required Provider public types from
`features/providers/api.ts`; Providers must not import Catalog.

- [ ] **Step 1: Add Catalog surface and non-cycle RED tests**

Require every symbol in Interfaces, reject any missing/extra public export,
accept `catalog -> auth, providers`, and reject `providers -> catalog`. Run the
focused contract and observe RED.

- [ ] **Step 2: Extract Catalog types and request functions**

Move the complete exact type/function blocks from old Admin API. Import
`apiRequest`, `Paginated`, and `toQuery` from Platform. Define feature-specific
service query keys without changing serialized keys or omission/encoding.

- [ ] **Step 3: Move five pages and redirect imports**

Pages use `./api` internally, exact Auth public exports, Design System, and
Platform. Services uses Providers public API for search. Preserve all page
bodies, forms, actions, validation, permissions, strings, and response handling.

- [ ] **Step 4: Delete Catalog blocks from old Admin API**

After consumers compile, remove the moved types/functions from `api/admin.ts`.
The remaining file may contain only Moderation, Notifications, and Audit
contracts assigned to Task 6.

- [ ] **Step 5: Advance the exact location-aware Pagination contract**

Update the Services record's expected third field to
`../../design_system/Pagination` when Services moves into Catalog. Keep Users,
ProviderApplications, and Providers at that same value; keep Reviews,
ConversationReports, and Notifications at `../design_system/Pagination` while
those three pages remain under `src/pages`. Update only the required raw-source
module specifiers. The scope checker must prove the exact seven-record Task 5
mapping, page-import equality, and resolution to the one Design System
component. Do not change page membership, totals, filters, assertion operator,
test name, expected behavior, or any other assertion.

- [ ] **Step 6: Run Task 5 gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-5
node .\scripts\check-r10-scope.mjs --task task-5
Set-Location .\admin-web
npm test -- --run
npm run typecheck
npm run smoke:honesty
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: stage counts `api=1`, `auth=0`, `components=0`, `pages=6`; no graph
cycle; all 101 tests and frozen request/copy/route/lock contracts pass.

- [ ] **Step 7: Review without Git mutation**

Obtain independent read-only review of all Catalog requests/types, service
provider search, dynamic catalog/geography behavior, graph, and scope. Do not
stage or commit.

---

### Task 6: Move Moderation Notifications Audit And Contract Tests

**Files:**

- Create: `admin-web/src/features/moderation/api.ts`
- Move: `ReviewsPage.tsx`, `ConversationReportsPage.tsx` to
  `admin-web/src/features/moderation/`
- Create: `admin-web/src/features/notifications/api.ts`
- Move: `NotificationsPage.tsx` to `features/notifications/`
- Create: `admin-web/src/features/audit/api.ts`
- Move: `AuditLogsPage.tsx` to `features/audit/`
- Move to `admin-web/src/test/contracts/`:
  `AdminPaginationContract.test.ts` and `ProviderLifecycleContract.test.ts`
- Delete: final `admin-web/src/api/admin.ts`
- Modify: `App.tsx` import paths
- Modify: all moved-source path literals in
  `admin-web/scripts/source-honesty-smoke.mjs`

**Interfaces:**

- Consumes: Moderation uses Platform, Auth public API, Providers public API,
  and Design System; Notifications uses Platform, Auth public API, and Design
  System; Audit uses only Platform and Design System.
- Produces:

```text
features/moderation/api.ts:
  ProviderReview, ConversationReport,
  getReviews, updateReviewStatus, hideReview,
  getConversationReports, updateConversationReportStatus

features/notifications/api.ts:
  AdminNotification,
  getAdminNotifications, getAdminUnreadNotificationCount,
  markAdminNotificationRead, archiveAdminNotification,
  deleteAdminNotification

features/audit/api.ts:
  AdminAuditPhase, AdminAuditLog, getAdminAuditLogs
```

Moderation may import `ProviderReference` from Providers public API. No reverse
edge is allowed. Audit remains read-only.

- [ ] **Step 1: Add final owner-surface RED tests**

Require the exact symbols in Interfaces, accept only `moderation -> auth,
providers` and `notifications -> auth`, and require zero Audit feature edges.
Run focused scanner tests and observe RED.

- [ ] **Step 2: Extract Moderation transport and move pages**

Move complete DTOs/functions; preserve `/admin/reviews` and
`/admin/conversation-reports` methods/paths/bodies. Reviews provider filtering
uses Providers public API. Preserve permissions and page-local formatters.

- [ ] **Step 3: Extract Notifications transport and page**

Move the complete notification type and five request functions. Preserve
redaction fields, read/archive/delete semantics, permissions, filters, and
strings.

- [ ] **Step 4: Extract read-only Audit transport and page**

Move `AdminAuditPhase`, `AdminAuditLog`, and `getAdminAuditLogs`. Preserve the
absence of update/delete API and controls.

- [ ] **Step 5: Move the two remaining cross-feature contract tests**

Move Pagination and ProviderLifecycle; the RBAC contract already resides in
`test/contracts/` from Task 3. Update raw source module specifiers only and
advance only the Reviews, ConversationReports, and Notifications expected
third fields to `../../design_system/Pagination`. All seven Pagination records
must now use that value, match their raw page imports, and resolve to
`src/design_system/Pagination.tsx`. Keep the exact record identities/order,
dynamic assertion operand, every other assertion, page membership, lifecycle
expected object, RBAC string, and honesty condition unchanged after approved
path normalization.

- [ ] **Step 6: Delete the old Admin API and old page root**

After all consumers compile, delete `src/api/admin.ts`. Confirm `src/api` and
`src/pages` contain no file, then remove the empty directories. Do not create a
barrel or facade at either old path.

- [ ] **Step 7: Point source honesty at final owners**

Read StatusBadge from Design System, Dashboard from Dashboard, conversation
report transport/page from Moderation, Auth transport/Login from Auth, and
client from Platform. Keep 12 exact checks and failure behavior.

- [ ] **Step 8: Run Task 6 gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node --test .\admin-web\scripts\admin-boundaries.contract.mjs
node --test .\scripts\check-r10-scope.test.mjs
node .\admin-web\scripts\admin-boundaries.mjs --stage task-6
node .\scripts\check-r10-scope.mjs --task task-6
Set-Location .\admin-web
npm test -- --run
npm run typecheck
npm run smoke:honesty
Set-Location ..
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Expected: all old-root counts are zero; all 101 Vitest tests pass; request
inventory is 62; Arabic inventory is 1,020; honesty is 12/12; only the declared
acyclic graph remains.

- [ ] **Step 9: Review without Git mutation**

Obtain independent read-only review of old-root absence, final DTO/request
equivalence, privacy/RBAC/audit behavior, test normalization, and scope. Do not
stage or commit.

---

### Task 7: Activate Strict Admin CI And Generated Script Truth

**Files:**

- Modify: `admin-web/package.json`
- Modify: `.github/workflows/ci.yml`
- Regenerate only: `docs/SCRIPTS.md`

**Interfaces:**

- Consumes: Task 6 zero-root candidate and strict scanner.
- Produces package scripts:

```json
{
  "architecture": "node scripts/admin-boundaries.mjs --strict",
  "architecture:stage": "node scripts/admin-boundaries.mjs --stage",
  "test:architecture": "node --test scripts/admin-boundaries.contract.mjs"
}
```

CI runs `npm run test:architecture` and `npm run architecture` before existing
Admin unit/typecheck/build/honesty/route/container gates.

- [ ] **Step 1: Prove strict zero before editing CI**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\admin-web\scripts\admin-boundaries.mjs --strict
node .\scripts\check-r10-scope.mjs --task task-6
```

Expected: both pass; do not edit CI if strict is red.

- [ ] **Step 2: Add only the three package scripts**

Insert the exact Interfaces entries. Do not change dependencies, versions, or
lockfile. Verify the lockfile hash immediately after editing.

- [ ] **Step 3: Wire only the Admin CI job**

After `npm ci`, add `npm run test:architecture` and `npm run architecture`
before `npm test`. Do not change workflow triggers, permissions, runners,
actions, Node version, caches, Backend/Mobile jobs, secrets, or release jobs.

- [ ] **Step 4: Regenerate and verify script documentation**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
```

Expected: only `docs/SCRIPTS.md` changes among generated references;
`ADMIN_ROUTES.md` remains at its frozen hash.

- [ ] **Step 5: Run strict CI-equivalent Admin gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\admin-web
npm run test:architecture
npm run architecture
npm test -- --run
npm run typecheck
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
npm audit --audit-level=high
Set-Location ..
node .\scripts\check-r10-scope.mjs --task task-7
git diff --check
```

Expected: strict zero, all Admin tests/build/smokes/audit pass, route smoke has
16 HTTP-200 routes, container contracts 3/3, honesty 12/12, audit zero, and no
lockfile or route drift.

- [ ] **Step 6: Review without Git mutation**

Confirm the CI diff contains only two commands and package diff only three
scripts. Obtain independent read-only CI/governance review. Do not stage,
commit, push, or run remote CI.

---

### Task 8: Prove The Admin Candidate Statically And At Runtime

**Files:**

- Conditional test-only remediation after the first evidence run:
  - Modify: `docs/superpowers/plans/2026-08-30-modular-monolith-r10-admin-closeout.md`
  - Modify: `admin-web/architecture/r10-admin-boundaries.json`
  - Modify: `admin-web/scripts/admin-boundaries.mjs`
  - Modify: `scripts/check-r10-scope.mjs`
  - Modify: `scripts/check-r10-scope.test.mjs`
  - Modify: `admin-web/scripts/admin-runtime-smoke.mjs`
- Inspect: every path allowed by `architecture/r10-admin-boundaries.json`
- Inspect: protected Admin build/runtime/deployment paths
- Evidence only: command output retained for Task 10; do not write credentials,
  OTP values, phone numbers, tokens, environment values, or private records

**Interfaces:**

- Consumes: strict zero-root Admin candidate from Task 7.
- Produces: one local evidence matrix with `PASS`, `FAIL`, `BLOCKED`, or
  `UNVERIFIED` for every Admin static, behavior, build, security, and runtime
  gate. The original evidence-only run modifies no source or runtime
  configuration.

**Approved conditional remediation:** The first Task 8 evidence run correctly
ended `FAIL` because the protected existing managed harness did not prove a
permission-limited RBAC denial, a distinct propagated runtime failure, or a
fresh re-login after logout. Owner approval permits one test-only correction in
the same managed/disposable harness: preserve the complete SUPER_ADMIN journey,
then change only that disposable identity's local database role to `SUPPORT`,
perform a fresh password/MFA login, prove catalog read permission without
catalog write permission, assert one valid catalog write returns a structured
`403`, assert a separate guaranteed-missing catalog read returns a structured
`404`, and logout the restricted session. Permanent scope/source contracts must
prove Task 7 still rejects the harness path, Task 8 accepts it, and these are
real request/status/body assertions rather than labels. This exception permits
no Backend, Mobile, Prisma schema, migration, dependency, lockfile, route,
deployment, product, credential, retry, fallback, or second-harness change.

After the corrected harness passed independently, adversarial review proved
that an open-ended semantic blacklist cannot make every future JavaScript
control-flow or dynamic-mutation bypass fail closed. The approved harness is
therefore also a byte-exact protected artifact: add the exact
`adminRuntimeSmoke` `{ path, sha256 }` record to the R10 manifest, require that
exact two-key shape and identity in `admin-boundaries.mjs`, and include the
record in `scripts/check-r10-scope.mjs` protected-hash verification. A one-byte
harness mutation must fail `protected-hash-mismatch`. This governance-only
addition may update only the amended plan/document integrity hashes and the
new exact runtime-smoke identity constant; it does not authorize another
harness, product, runtime, dependency, or deployment change.

- [ ] **Step 1: Prove the working tree matches the exact R10 fence**

```powershell
Set-Location D:\projects\aarast-modular-monolith
git status --short
git diff --name-status e560e5784278907dd6bf565327c3abfa0c9b8cab
node .\scripts\check-r10-scope.mjs --task task-8
node .\admin-web\scripts\admin-boundaries.mjs --strict
```

Expected: every changed/untracked path is in Appendix D; all protected hashes,
62 requests, 1,020 Arabic literals, 22 routes, 18 existing test files, 96
existing test bodies, and the lockfile match the frozen contract; all four old
roots are absent.

- [ ] **Step 2: Run the complete Admin local gate set from a clean process**

```powershell
Set-Location D:\projects\aarast-modular-monolith\admin-web
npm run test:architecture
npm run architecture
npm test -- --run
npm run typecheck
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
npm audit --audit-level=high
```

Expected: scanner contracts and strict scan pass; 101 Vitest tests pass; build
and typecheck pass; honesty is 12/12; route smoke returns HTTP 200 for all 16
preview probes; container contracts are 3/3; audit reports zero findings.

- [ ] **Step 3: Run the managed Admin runtime smoke with disposable data**

Use the existing repository-owned runtime/smoke command discovered in
`docs/qa/README.md` and `admin-web/package.json`; do not invent a second harness.
Point it only at the disposable migrated local database used by the existing
smoke tooling. Exercise Admin login, session restoration, RBAC denial, catalog
read/write behavior, error propagation, logout, and re-login. Redact all
credentials and OTP values from retained output.

Expected: the same scenarios and response semantics that passed before R10 pass
after relocation. A local `123456` development OTP or mocked delivery is
recorded only as a local integration PASS, never as real WhatsApp delivery.

- [ ] **Step 4: Inspect the built preview independently**

Start the existing built-preview command on an unused local port. Run the
existing route smoke against that exact preview and manually inspect login,
dashboard, one list, one detail, one write control under allowed RBAC, one
forbidden RBAC path, the fallback page, refresh/session restoration, and logout.
Stop the preview when complete.

Expected: routes, redirects, rendered Arabic/RTL copy, loading/empty/error
states, request methods/paths, and permission visibility are unchanged.

- [ ] **Step 5: Audit architecture, security, performance, and maintainability**

Inspect all cross-feature edges, public exports, response DTO ownership,
request cancellation/timeout behavior, token/session handling, failure
propagation, bundle warnings, duplicate source, and unreachable old paths.
Treat any permanent scanner suppression, reciprocal Provider/Catalog edge,
secret output, behavior drift, or duplicate implementation as FAIL.

- [ ] **Step 6: Obtain an independent read-only Admin review**

Give the reviewer the approved design, this plan, exact diff, scope output,
strict scan, test/typecheck/build/smoke/audit output, and runtime matrix. Require
file-and-line findings with severities. Resolve every finding by returning to
its owning task and rerunning all downstream gates; do not waive findings.

---

### Task 9: Re-Prove The Complete R0-R10 Mission Locally

**Files:**

- Modify: none
- Conditional governance/test remediation after the first combined gate run:
  - Modify: `docs/superpowers/plans/2026-08-30-modular-monolith-r10-admin-closeout.md`
  - Modify: `admin-web/architecture/r10-admin-boundaries.json`
  - Modify: `admin-web/scripts/admin-boundaries.mjs`
  - Modify: `scripts/check-r10-scope.test.mjs`
  - Modify: `backend/scripts/architecture/r3-scope.cjs`
  - Modify: `backend/test/architecture-r3-scope.test.ts`
  - Modify: `backend/test/architecture-r4-planning-finance-boundary.test.ts`
  - Modify: `admin-web/scripts/admin-boundaries.contract.mjs`
  - Modify: `backend/scripts/architecture/r5-identity-scan.cjs`
  - Modify: `backend/test/architecture-r5-identity-relocation.test.ts`
- Inspect: Backend, Prisma, Mobile, Admin, docs, generated references, and the
  repository-wide protected-surface fence
- Evidence only: append results later in Task 10

**Interfaces:**

- Consumes: independently approved Admin candidate from Task 8.
- Produces: one combined local regression receipt. It proves preservation; it
  does not authorize cleanup of the 22 Backend dependency findings or 385
  records / 781 occurrences of physical-ownership debt.

**Approved conditional remediation:** The combined runs exposed three
historical-gate defects, not product drift. R3/R4 receipts compared their old
base with the live R10 tree instead of their immutable R9 closeout, and the
final Admin boundary contract retained a RED-stage dynamic-import fallback
that Phase 0 correctly rejects. Task 9 may add an exact optional R9 phase
ceiling `e560e5784278907dd6bf565327c3abfa0c9b8cab` to the R3 scope tool and
historical R3/R4 tests while preserving default live fail-closed behavior, and
may replace only that contract fallback with a static namespace import. It may
not widen R4/R9 allowlists, skip a gate, exempt a guarded file, or change
Backend product source, dependencies, Prisma, Mobile, runtime, deployment, or
production configuration. Snapshot mode must read the R3 and delegated R4-R9
manifests from that exact commit, not from the working tree, and its atomic
report must record the exact `targetRef`; live mode must record
`targetRef: null` and continue to include untracked files. The CLI accepts
only four fixed-order forms: live, live plus report, snapshot, and snapshot
plus report, with `--target-ref` before `--report-path`; duplicate, unknown,
incomplete, reordered, wrong-base, and wrong-target forms must fail closed.
The complete Backend test run may also correct the historical R5
`liveChangedPaths` subprocess boundary to capture Git stderr locally while
retaining stdout parsing, nonzero fail-closed behavior, and the exact bounded
CLI error. It may not change line endings, Git configuration, or weaken the
exact stderr assertion.

- [ ] **Step 1: Re-run Backend architecture and quality gates**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
npm run build
npm test
npm audit --audit-level=high
npm audit --omit=dev
npm run security:prisma-config-merge
```

Use `npm ci` only if dependencies are absent and the frozen lockfile already
authorizes it; never update dependencies or the lockfile.

Expected: all pre-R10 Backend gates pass unchanged. Dependency debt remains
exactly 22; a different value is FAIL unless the immutable base was separately
and explicitly corrected before Task 1.

- [ ] **Step 2: Re-prove Prisma generated and migration equivalence**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
$proof = Join-Path ([IO.Path]::GetTempPath()) `
  ('aarast-r10-prisma-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proof | Out-Null
$baseSchema = Join-Path $proof 'backend/prisma/schema'
$baseDmmf = Join-Path $proof 'base-dmmf.json'
$candidateDmmf = Join-Path $proof 'candidate-dmmf.json'
$hadDatabaseUrl = Test-Path Env:DATABASE_URL
$previousDatabaseUrl = [Environment]::GetEnvironmentVariable('DATABASE_URL', 'Process')
$env:DATABASE_URL = 'postgresql://placeholder:placeholder@127.0.0.1:1/placeholder'
$candidateRestoreFailed = $false
try {
  git archive e560e5784278907dd6bf565327c3abfa0c9b8cab backend/prisma/schema | tar -xf - -C $proof
  npx prisma generate --schema $baseSchema
  if ($LASTEXITCODE -ne 0) { throw 'base Prisma generate failed' }
  node scripts/prisma/dmmf-fingerprint.cjs --output $baseDmmf
  if ($LASTEXITCODE -ne 0) { throw 'base DMMF fingerprint failed' }

  npx prisma validate
  if ($LASTEXITCODE -ne 0) { throw 'candidate Prisma validate failed' }
  npx prisma generate
  if ($LASTEXITCODE -ne 0) { throw 'candidate Prisma generate failed' }
  node scripts/prisma/dmmf-fingerprint.cjs --output $candidateDmmf
  if ($LASTEXITCODE -ne 0) { throw 'candidate DMMF fingerprint failed' }

  $baseProjection = Get-Content -Raw -LiteralPath $baseDmmf | ConvertFrom-Json
  $candidateProjection = Get-Content -Raw -LiteralPath $candidateDmmf | ConvertFrom-Json
  if ($baseProjection.modelCount -ne 52 -or $baseProjection.enumCount -ne 41) {
    throw 'base DMMF counts drifted'
  }
  if ($candidateProjection.modelCount -ne 52 -or $candidateProjection.enumCount -ne 41) {
    throw 'candidate DMMF counts drifted'
  }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $baseDmmf).Hash -ne `
      (Get-FileHash -Algorithm SHA256 -LiteralPath $candidateDmmf).Hash) {
    throw 'base and candidate DMMF differ'
  }
  if (@(Get-ChildItem -LiteralPath prisma/migrations -Directory).Count -ne 76) {
    throw 'migration count drifted'
  }
  npx prisma migrate diff --exit-code `
    --from-schema-datamodel $baseSchema `
    --to-schema-datamodel prisma/schema
  if ($LASTEXITCODE -ne 0) { throw 'Prisma migrate diff detected drift' }
  git diff --exit-code e560e5784278907dd6bf565327c3abfa0c9b8cab -- `
    prisma/schema prisma/migrations prisma/seed.ts prisma.config.ts package-lock.json
  if ($LASTEXITCODE -ne 0) { throw 'protected Prisma surface drifted' }
} finally {
  npx prisma generate
  if ($LASTEXITCODE -ne 0) { $candidateRestoreFailed = $true }
  if ($hadDatabaseUrl) {
    $env:DATABASE_URL = $previousDatabaseUrl
  } else {
    Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
  }
  $resolvedProof = (Resolve-Path -LiteralPath $proof -ErrorAction SilentlyContinue).Path
  $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
  if ($resolvedProof -and $resolvedProof.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedProof -Recurse -Force
  }
  if ($candidateRestoreFailed) { throw 'candidate Prisma client restoration failed' }
}
```

This creates no tracked artifact and applies no migration. It generates and
fingerprints the archived base client, regenerates and fingerprints the
candidate client, requires both fingerprint files byte-identical at 52 models
and 41 enums, restores the candidate client even on failure, restores the prior
process environment without printing it, requires 76 migrations and empty
migrate/protected diffs, and removes the verified temporary directory.

Expected: schema and history are equivalent to the frozen base; no Prisma file
or generated contract drifts.

- [ ] **Step 3: Run affected Backend smokes and full smoke aggregation**

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run smoke:health
npm run smoke:auth
npm run smoke:tasks-apis
npm run smoke:conversation-unification
npm run smoke:notifications
npm run smoke:sharing
npm run smoke:phase2-auth-lifecycle-concurrency
npm run smoke:phase2-conversation-revocation
npm run smoke:phase2-idempotency-reconciliation
npm run smoke:phase2-notification-preferences
npm run smoke:phase2-task-guest-permission-concurrency
npm run smoke:phase3-context-transition
npm run smoke:all
```

Use only the approved disposable local environment. Record environment blockers
as `BLOCKED`; do not convert them to PASS or patch around them. Expected: all 12
focused packages and all 30 aggregate packages pass with cleanup and no retained
database/container/media residue.

- [ ] **Step 4: Re-run Mobile architecture, analysis, and all tests**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\check-mobile-boundaries.mjs --strict
Set-Location D:\projects\aarast-modular-monolith\mobile
flutter analyze --no-pub
flutter test --no-pub
```

Expected: all pass with zero Mobile source/config changes in R10.

- [ ] **Step 5: Re-run the final Admin gate set once**

Repeat every Task 8 static/build/smoke/audit command against the final tree. Do
not rely on earlier output because Task 10 has not yet changed active docs.

- [ ] **Step 6: Re-prove documentation and protected surfaces**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
node .\scripts\check-r10-scope.mjs --task task-9
git diff --check
```

Confirm the generated Admin route set remains 22 and byte-identical, Backend
ownership debt remains 385/781, deployment/Docker/Compose/Dokploy files are
unchanged, and no secret-bearing or environment file entered the diff.

- [ ] **Step 7: Stop on any red combined gate**

Do not begin documentation closeout with a FAIL. Return to the earliest owning
task, make only the approved correction, and rerun that task plus Tasks 8 and 9.
`BLOCKED` external evidence may be documented only when every local gate that
can run is green and the blocker is outside R10 authorization.

---

### Task 10: Synchronize Active Truth And Write The R10 Final Report

**Files:**

- Modify: `ARCHITECTURE.md`
- Modify: `docs/README.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/EXECUTION_PLAN.md`
- Modify: `docs/frontend/ADMIN_WEB.md`
- Modify only if its current statement becomes inaccurate:
  `docs/frontend/README.md`
- Modify: `docs/backend/README.md`
- Modify: `docs/qa/README.md`
- Modify: `CHANGELOG.md`
- Regenerate only: `docs/SCRIPTS.md`
- Create:
  `docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md`
- Keep byte-identical: `docs/frontend/ADMIN_ROUTES.md`

**Interfaces:**

- Consumes: complete PASS/FAIL/BLOCKED/UNVERIFIED receipts from Tasks 8 and 9.
- Produces active documentation that says only what those receipts prove.
  Allowed headline: `R10 Admin phase complete` and, if every local R0-R10 gate
  passed, `R0-R10 execution wave locally closed with declared gaps`. Forbidden
  headline: `architecture target complete` while Backend debt is non-zero.

- [ ] **Step 1: Update the authoritative architecture contract**

In `ARCHITECTURE.md`, replace the Admin planning statement with the final
feature/platform/design-system layout, exact public-API and composition-root
rules, exact App screen allowlist, zero legacy-root result, strict scanner/CI
commands, Dashboard mock-target exception, and stage-aware location-resolving
Pagination exception.
Keep Backend debt explicitly at 22 and 385/781. Do not rewrite product scope or
historical R0-R9 decisions.

- [ ] **Step 2: Update status, decision, execution, and area docs**

Add the R10 design, plan, and report links to `docs/README.md`. Record the local
result and external stop boundary in `STATUS.md`; record the no-facade Admin
owner graph, structural Provider projections, exact test exceptions, and
phase-vs-target closeout language in `DECISIONS.md`; mark only the local R10
wave complete in `EXECUTION_PLAN.md`; document the final Admin tree and commands
in `ADMIN_WEB.md`; update `docs/frontend/README.md` only if its live tree summary
is otherwise false; preserve truthful Backend debt in `docs/backend/README.md`;
and add exact commands/results/blockers to `docs/qa/README.md`.

- [ ] **Step 3: Add the changelog entry**

Describe an internal Admin modular relocation with unchanged routes, API,
Arabic UI, auth/session/RBAC behavior, dependencies, Backend, Mobile, database,
and deployment. Do not describe an unpublished commit, deployment, real
WhatsApp delivery, live push, or resolved Backend debt.

- [ ] **Step 4: Write the evidence report with fixed sections**

The final report must contain, in this order:

1. immutable base, branch, design hash, and plan hash;
2. exact changed-path inventory and zero out-of-scope paths;
3. 78-source Admin fate receipt and `5/9/27/24 -> 0/0/0/0` milestones;
4. feature graph, public APIs, composition roots, and strict scanner result;
5. frozen contracts: 22 routes, 62 requests, 1,020 Arabic literals, 18 existing
   test files / 96 existing tests, 101 total Admin tests, and lockfile hash;
6. Admin tests, typecheck, build, honesty 12/12, route 16, container 3/3,
   audit zero, managed runtime, and preview results;
7. Backend architecture/check/build/tests/audits/Prisma/focused-smoke/full-smoke
   results and unchanged 22 plus 385/781 debt;
8. Mobile strict/analyze/full-test results with zero Mobile changes;
9. docs/protected-surface/scope/diff results;
10. independent review findings and disposition;
11. separate `PASS`, `FAIL`, `BLOCKED`, and `UNVERIFIED` tables;
12. explicit exclusions: no commit unless separately authorized, no push/merge,
    no deployment/production mutation, no remote CI claim, no real WhatsApp
    delivery claim, no live Firebase Push claim, and no architecture-target-
    complete claim.

Never include credentials, OTPs, phone numbers, tokens, environment values,
private records, device serials, raw business content, or temporary database
connection details.

- [ ] **Step 5: Regenerate the script reference and verify docs**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
node .\scripts\check-r10-scope.mjs --task task-10
git diff --check
```

Expected: only `docs/SCRIPTS.md` changes among generated docs; Admin routes stay
byte-identical; documentation has zero verifier errors/warnings; all changed
paths remain inside Appendix D.

- [ ] **Step 6: Perform a claim-to-evidence audit**

For every completion statement, point to a command result from Tasks 8 or 9.
Downgrade missing external evidence to `BLOCKED` or `UNVERIFIED`. Ensure `R10
Admin phase complete` is not silently broadened into completion of the remaining
Backend target or any external release activity.

---

### Task 11: Final Independent Review And Local Stop

**Files:**

- Modify: none unless the review finds an in-scope defect; any correction
  returns to the owning task and invalidates downstream receipts
- Inspect: approved design, this plan, complete diff, all gate output, active
  docs, final report, Git status, and protected surfaces

**Interfaces:**

- Consumes: Task 10 documented candidate.
- Produces: an independent `APPROVED` or `NOT APPROVED` local R10 verdict and an
  exact stop receipt. It does not authorize Git or release actions.

- [ ] **Step 1: Run the final read-only invariants**

```powershell
Set-Location D:\projects\aarast-modular-monolith
node .\admin-web\scripts\admin-boundaries.mjs --strict
node .\scripts\check-r10-scope.mjs --task task-11
node .\scripts\check-mobile-boundaries.mjs --strict
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
git status --short
git diff --stat e560e5784278907dd6bf565327c3abfa0c9b8cab
git diff --name-status e560e5784278907dd6bf565327c3abfa0c9b8cab
```

Expected: all scanners/docs/diff checks pass; status contains only the approved
R10 surface; no protected file or secret-bearing path is present.

- [ ] **Step 2: Request independent source-and-evidence review**

Require the reviewer to answer all of these explicitly:

- Does every one of the 78 starting Admin files have exactly one final fate?
- Are all old roots absent with no facade, duplicate, fallback, or hidden bypass?
- Do imports obey the approved acyclic graph through exact public APIs?
- Are routes, requests, Arabic copy, tests, auth/session/RBAC, dependencies,
  Backend, Mobile, Prisma, and deployment surfaces preserved?
- Do scanner/scope tests fail closed under adversarial inputs?
- Does the report distinguish phase completion, target debt, and external gates?
- Is every PASS claim backed by output from this candidate?

The reviewer reports Critical, Important, and Minor findings with exact paths
and lines and concludes `APPROVED` only with zero unresolved Critical or
Important findings.

- [ ] **Step 3: Resolve findings without scope expansion**

For any Critical or Important finding, return to its earliest owning task, add
or retain a failing regression proof, fix only the root cause, rerun all gates
from that task through Task 11, and request another independent review. Do not
weaken a contract, edit a baseline to hide drift, or relabel a failure.

- [ ] **Step 4: Record the local stop receipt**

When approved, report the exact final status, plan/report hashes, changed files,
PASS/FAIL/BLOCKED/UNVERIFIED evidence, remaining 22 and 385/781 Backend debt,
and the absence of Git/release mutations. Stop. Await a separate owner command
before any stage, commit, push, merge, deployment, production change, or remote
CI action.

---

## Appendix A: Exact Starting-File Fate Map

The Task 1 manifest records all 78 current files as explicit source/target
pairs. These are the required fates; no glob is accepted by the checker as a
substitute for those 78 records.

| Starting path(s) under `admin-web/src/` | Required final fate |
| --- | --- |
| `api/client.ts`, `api/client.test.ts` | move to `platform/api/` |
| pagination/query mechanics in `api/admin.ts` | extract to `platform/api/query.ts` and `query.test.ts` |
| `components/ErrorBoundary.tsx`, `components/ErrorBoundary.test.tsx` | move to `platform/errors/` |
| `pages/NotFoundPage.tsx` | move to `platform/routing/NotFoundPage.tsx` |
| `components/ActionButton.tsx`, `ConfirmDialog.tsx` and test, `DataTable.tsx` and test, `DetailField.tsx`, `EmptyState.tsx`, `ErrorState.tsx`, `FilterSelect.tsx`, `FormCard.tsx`, `FormField.tsx`, `LoadingSkeleton.tsx`, `LoadingState.tsx`, `MiniDonut.tsx`, `PageHeader.tsx`, `Pagination.tsx` and test, `RoleBadge.tsx`, `SearchInput.tsx` and test, `SectionCard.tsx`, `StatCard.tsx`, `StatusBadge.tsx`, `TableToolbar.tsx`, `Timeline.tsx` | move one-to-one to `design_system/` |
| `api/auth.ts`, `api/auth.test.ts` | split mechanically into `features/auth/transport.ts` and test; expose used symbols through new `features/auth/api.ts` |
| `auth/admin-return-path.ts` and test, `adminPermissions.ts`, `AuthProvider.tsx` and test, `Can.tsx`, `RequireAdmin.tsx`, `RequireAdminPermission.tsx` | move one-to-one to `features/auth/` |
| `auth/AdminRbacAuditContract.test.ts` | move to `test/contracts/` |
| `pages/LoginPage.tsx`, `pages/LoginPage.test.tsx` | move to `features/auth/` |
| `pages/DashboardPage.tsx` and test, `pages/ReportsPage.tsx` | move to `features/dashboard/` |
| dashboard DTOs/requests in `api/admin.ts` | move to `features/dashboard/api.ts` |
| `pages/UsersPage.tsx`, `pages/UserDetailsPage.tsx` | move to `features/users/` |
| user requests/projections in `api/admin.ts` | move to `features/users/api.ts` |
| `pages/ProviderApplicationsPage.tsx`, `ProviderApplicationDetailsPage.tsx`, `ProvidersPage.tsx`, `ProviderDetailsPage.tsx` | move to `features/providers/` |
| generic `formatDate` in `pages/providerHelpers.tsx` | extract behavior-identically to `platform/i18n/formatDate.ts` and test |
| provider-only remainder of `pages/providerHelpers.tsx` | move to `features/providers/providerHelpers.tsx` |
| provider DTOs/requests in `api/admin.ts` | move to `features/providers/api.ts` |
| `pages/ProviderLifecycleContract.test.ts` | move to `test/contracts/` |
| `pages/CategoriesPage.tsx`, `CitiesPage.tsx`, `ServicesPage.tsx`, `ReferenceCatalogsPage.tsx`, `AdministrativeAreasPage.tsx` | move to `features/catalog/` |
| catalog/service/geography DTOs/requests in `api/admin.ts` | move to `features/catalog/api.ts` |
| `pages/ReviewsPage.tsx`, `ConversationReportsPage.tsx` | move to `features/moderation/` |
| moderation DTOs/requests in `api/admin.ts` | move to `features/moderation/api.ts` |
| `pages/NotificationsPage.tsx` plus notification DTOs/requests | move to `features/notifications/` and its `api.ts` |
| `pages/AuditLogsPage.tsx` plus audit DTOs/requests | move to `features/audit/` and its `api.ts` |
| `pages/AdminPaginationContract.test.ts` | move to `test/contracts/` |
| `api/admin.ts` | delete after its last owned block moves in Task 6 |
| `App.tsx`, `main.tsx` | retain paths; import-only redirects |
| `layout/AdminLayout.tsx` and test, `adminNavigation.ts` and test, `Sidebar.tsx` and test, `Topbar.tsx` and test | retain paths and bodies; import-only redirects |
| `styles/globals.css`, `test/setup.ts`, `vite-env.d.ts` | retain byte-identically |

The split blocks inside `api/admin.ts` and `providerHelpers.tsx` are counted as
fates of those source files, not extra starting files. Final scan requires the
directories `src/api`, `src/auth`, `src/components`, and `src/pages` not to
exist.

## Appendix B: Exact Feature Public Surfaces And Graph

Every production consumer outside an owner imports only the named
`features/<owner>/api.ts`, except that `App.tsx` alone may import the exact
screen modules below. Internal page/helper files are never public APIs,
wildcard exports are forbidden, and one feature API cannot re-export another
feature.

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

The first 18 paths are the only feature-screen exception; Platform NotFound is
the nineteenth direct screen import. `main.tsx`, `layout/**`, other features,
Platform, and Design System may not deep-import any feature screen.

| Owner | Used symbols allowed on its public surface |
| --- | --- |
| Auth | `AdminUser`, `OtpDeliveryStatus`, `AdminLoginChallenge`, `AdminPasswordResetChallenge`, `startAdminLogin`, `completeAdminLogin`, `requestAdminPasswordReset`, `confirmAdminPasswordReset`, `restoreAdminSession`, `logoutAdmin`, current session-context symbols, permission helpers, `Can`, `RequireAdmin`, `RequireAdminPermission` |
| Dashboard | `AdminStats`, `AdminReport`, `getStats`, `getReportOverview` |
| Users | `UserProviderSummary`, `AdminUserRecord`, `getUsers`, `getUser`, `activateUser`, `disableUser` |
| Providers | provider response projections, `ProviderApplication`, `ProviderReference`, `getProviderApplications`, `getProviderApplication`, `getProviders`, `getProvider`, `approveProvider`, `rejectProvider`, `requestProviderChanges`, `suspendProvider`, `activateProvider` |
| Catalog | `City`, `ProviderCategory`, `ProviderService`, `ServicePayload`, `CatalogPayload`, reference-catalog types, geography types, all current city/category/service/reference-catalog/governorate/district/locality request functions |
| Moderation | `ProviderReview`, `ConversationReport`, `getReviews`, `updateReviewStatus`, `hideReview`, `getConversationReports`, `updateConversationReportStatus` |
| Notifications | `AdminNotification`, `getAdminNotifications`, `getAdminUnreadNotificationCount`, `markAdminNotificationRead`, `archiveAdminNotification`, `deleteAdminNotification` |
| Audit | `AdminAuditPhase`, `AdminAuditLog`, `getAdminAuditLogs` |

Allowed cross-feature edges are exactly:

```text
dashboard -> auth
dashboard -> providers
users -> auth
providers -> auth
catalog -> auth
catalog -> providers
moderation -> auth
moderation -> providers
notifications -> auth
audit -> (none)
auth -> (none)
```

No other feature edge is allowed. In particular `providers -> catalog` is
forbidden, so the existing Provider nested city/category/service shapes remain
structural Provider-owned projections.

## Appendix C: Stage Inventory And Advancement Gates

The four values below are exact regular-file counts for
`src/api`, `src/auth`, `src/components`, and `src/pages` after each task.

| Stage | api | auth | components | pages | Advancement condition |
| --- | ---: | ---: | ---: | ---: | --- |
| Immutable base / Task 1 | 5 | 9 | 27 | 24 | governance tests green; stage scan matches |
| Task 2 | 3 | 9 | 0 | 23 | Platform/Design System gates green |
| Task 3 | 1 | 0 | 0 | 21 | Auth surface and graph gates green |
| Task 4 | 1 | 0 | 0 | 11 | Dashboard/Users/Providers gates green |
| Task 5 | 1 | 0 | 0 | 6 | Catalog/Services gates green |
| Tasks 6-11 | 0 | 0 | 0 | 0 | strict mode and every downstream gate green |

At every stage, the source-fate manifest also requires exact target presence,
exact old-source absence, no unknown TypeScript zone, no duplicate
implementation, and no out-of-scope changed path. A count match alone is never
sufficient.

## Appendix D: Exact Changed-Path Fence

Task 1 expands this list into canonical repository-relative strings. The scope
checker accepts only those strings; `**`, prefix matching, case folding,
symlink/junction traversal, absolute paths, and path escape are rejected.

**Governance/tooling paths:**

`admin-web/scripts/admin-runtime-smoke.mjs` is first allowed at Task 8 only by
the approved conditional test-only remediation above.
The following Backend governance/test paths are first allowed at Task 9 only
by the approved historical-gate remediation above.

```text
admin-web/architecture/r10-admin-boundaries.json
admin-web/scripts/admin-boundaries.mjs
admin-web/scripts/admin-boundaries.contract.mjs
admin-web/scripts/admin-runtime-smoke.mjs
scripts/check-r10-scope.mjs
scripts/check-r10-scope.test.mjs
admin-web/scripts/source-honesty-smoke.mjs
admin-web/package.json
.github/workflows/ci.yml
backend/scripts/architecture/r3-scope.cjs
backend/scripts/architecture/r5-identity-scan.cjs
backend/test/architecture-r3-scope.test.ts
backend/test/architecture-r4-planning-finance-boundary.test.ts
backend/test/architecture-r5-identity-relocation.test.ts
```

**Retained composition-root paths allowed import-only edits:**

```text
admin-web/src/App.tsx
admin-web/src/main.tsx
admin-web/src/layout/AdminLayout.tsx
admin-web/src/layout/AdminLayout.test.tsx
admin-web/src/layout/adminNavigation.ts
admin-web/src/layout/adminNavigation.test.ts
admin-web/src/layout/Sidebar.tsx
admin-web/src/layout/Sidebar.test.tsx
admin-web/src/layout/Topbar.tsx
admin-web/src/layout/Topbar.test.tsx
```

**Deleted/moved starting paths:** every `admin-web/src/api/**`,
`admin-web/src/auth/**`, `admin-web/src/components/**`, and
`admin-web/src/pages/**` file enumerated individually in the immutable 78-file
fate map. No newly created file under those roots is allowed.

**Created Platform and Design System targets:**

```text
admin-web/src/platform/api/client.ts
admin-web/src/platform/api/client.test.ts
admin-web/src/platform/api/query.ts
admin-web/src/platform/api/query.test.ts
admin-web/src/platform/i18n/formatDate.ts
admin-web/src/platform/i18n/formatDate.test.ts
admin-web/src/platform/errors/ErrorBoundary.tsx
admin-web/src/platform/errors/ErrorBoundary.test.tsx
admin-web/src/platform/routing/NotFoundPage.tsx
admin-web/src/design_system/ActionButton.tsx
admin-web/src/design_system/ConfirmDialog.tsx
admin-web/src/design_system/ConfirmDialog.test.tsx
admin-web/src/design_system/DataTable.tsx
admin-web/src/design_system/DataTable.test.tsx
admin-web/src/design_system/DetailField.tsx
admin-web/src/design_system/EmptyState.tsx
admin-web/src/design_system/ErrorState.tsx
admin-web/src/design_system/FilterSelect.tsx
admin-web/src/design_system/FormCard.tsx
admin-web/src/design_system/FormField.tsx
admin-web/src/design_system/LoadingSkeleton.tsx
admin-web/src/design_system/LoadingState.tsx
admin-web/src/design_system/MiniDonut.tsx
admin-web/src/design_system/PageHeader.tsx
admin-web/src/design_system/Pagination.tsx
admin-web/src/design_system/Pagination.test.tsx
admin-web/src/design_system/RoleBadge.tsx
admin-web/src/design_system/SearchInput.tsx
admin-web/src/design_system/SearchInput.test.tsx
admin-web/src/design_system/SectionCard.tsx
admin-web/src/design_system/StatCard.tsx
admin-web/src/design_system/StatusBadge.tsx
admin-web/src/design_system/TableToolbar.tsx
admin-web/src/design_system/Timeline.tsx
```

**Created Auth targets:**

```text
admin-web/src/features/auth/api.ts
admin-web/src/features/auth/transport.ts
admin-web/src/features/auth/transport.test.ts
admin-web/src/features/auth/admin-return-path.ts
admin-web/src/features/auth/admin-return-path.test.ts
admin-web/src/features/auth/adminPermissions.ts
admin-web/src/features/auth/AuthProvider.tsx
admin-web/src/features/auth/AuthProvider.test.tsx
admin-web/src/features/auth/Can.tsx
admin-web/src/features/auth/RequireAdmin.tsx
admin-web/src/features/auth/RequireAdminPermission.tsx
admin-web/src/features/auth/LoginPage.tsx
admin-web/src/features/auth/LoginPage.test.tsx
```

**Created feature and contract targets:**

```text
admin-web/src/features/dashboard/api.ts
admin-web/src/features/dashboard/DashboardPage.tsx
admin-web/src/features/dashboard/DashboardPage.test.tsx
admin-web/src/features/dashboard/ReportsPage.tsx
admin-web/src/features/users/api.ts
admin-web/src/features/users/UsersPage.tsx
admin-web/src/features/users/UserDetailsPage.tsx
admin-web/src/features/providers/api.ts
admin-web/src/features/providers/providerHelpers.tsx
admin-web/src/features/providers/ProviderApplicationsPage.tsx
admin-web/src/features/providers/ProviderApplicationDetailsPage.tsx
admin-web/src/features/providers/ProvidersPage.tsx
admin-web/src/features/providers/ProviderDetailsPage.tsx
admin-web/src/features/catalog/api.ts
admin-web/src/features/catalog/CategoriesPage.tsx
admin-web/src/features/catalog/CitiesPage.tsx
admin-web/src/features/catalog/ServicesPage.tsx
admin-web/src/features/catalog/ReferenceCatalogsPage.tsx
admin-web/src/features/catalog/AdministrativeAreasPage.tsx
admin-web/src/features/moderation/api.ts
admin-web/src/features/moderation/ReviewsPage.tsx
admin-web/src/features/moderation/ConversationReportsPage.tsx
admin-web/src/features/notifications/api.ts
admin-web/src/features/notifications/NotificationsPage.tsx
admin-web/src/features/audit/api.ts
admin-web/src/features/audit/AuditLogsPage.tsx
admin-web/src/test/contracts/AdminRbacAuditContract.test.ts
admin-web/src/test/contracts/ProviderLifecycleContract.test.ts
admin-web/src/test/contracts/AdminPaginationContract.test.ts
```

**Documentation paths:**

```text
ARCHITECTURE.md
CHANGELOG.md
docs/README.md
docs/SCRIPTS.md
docs/project/STATUS.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/frontend/ADMIN_WEB.md
docs/frontend/README.md
docs/backend/README.md
docs/qa/README.md
docs/superpowers/specs/2026-08-30-modular-monolith-r10-admin-closeout-design.md
docs/superpowers/plans/2026-08-30-modular-monolith-r10-admin-closeout.md
docs/superpowers/reports/2026-08-30-modular-monolith-r10-final-report.md
```

Everything else is protected. In particular, the fence rejects
`admin-web/package-lock.json`, `admin-web/src/styles/globals.css`,
`admin-web/src/test/setup.ts`, `admin-web/src/vite-env.d.ts`, other Admin
build/runtime/route/container/Docker/Nginx files, all Backend/Mobile/Prisma/
database/deployment/Docker/Compose/Dokploy paths, environment files, credentials,
and generated artifacts outside `docs/SCRIPTS.md`.

## Appendix E: Review Checkpoints And Conditional Commit Messages

Current authorization is read/write for the plan only and later implementation
changes if the owner starts execution; it does not authorize any Git mutation.
At each checkpoint, record `git status --short`, `git diff --check`, the exact
task gate outputs, and independent review without staging.

Only after a future explicit owner instruction authorizes commits may the
executor create these narrow checkpoints, and then only after rerunning that
checkpoint's gates on the exact staged diff:

| After task | Suggested message |
| --- | --- |
| 1 | `test: govern R10 admin boundaries` |
| 2 | `refactor: establish admin platform and design system` |
| 3 | `refactor: establish admin auth feature` |
| 4 | `refactor: move admin dashboard users and providers` |
| 5 | `refactor: move admin catalog and services` |
| 6 | `refactor: complete admin feature ownership` |
| 7 | `ci: enforce strict admin boundaries` |
| 10 | `docs: close R10 admin phase honestly` |

No commit may mix checkpoints, include a protected path, or imply push, merge,
deployment, remote CI, or complete architecture-target closure. If commit
authorization never arrives, the valid outcome is a reviewed local working tree
with no Git mutation.

## Plan Self-Review Checklist

- [ ] Every approved design requirement maps to at least one task and gate.
- [ ] Every one of the 78 starting Admin files has exactly one final fate.
- [ ] Every task lists concrete files, interfaces, commands, expected results,
  failure behavior, and a read-only review checkpoint.
- [ ] The only existing-test setup exception is the two Dashboard mock targets.
- [ ] The only existing-test assertion-shape exception is the exact
  seven-record, stage-aware, location-resolving Pagination transformation.
- [ ] The stage sequence is exactly `5/9/27/24`, `3/9/0/23`, `1/0/0/21`,
  `1/0/0/11`, `1/0/0/6`, then `0/0/0/0`.
- [ ] The final graph is acyclic and Providers never imports Catalog.
- [ ] Routes 22, requests 62, Arabic literals 1,020, existing tests 18/96,
  total tests 101, and the lockfile hash are enforced rather than merely noted.
- [ ] Backend debt 22 and 385/781 remains a declared gap, not R10 scope.
- [ ] No Backend, Mobile, Prisma, deployment, dependency, lockfile, behavior,
  route, API, permission, Arabic-copy, OTP, or session change is authorized.
- [ ] No stage/commit/push/merge/deploy/remote-CI action is authorized here.
- [ ] Completion language distinguishes local R10 Admin completion, local
  R0-R10 wave closeout with gaps, remaining architecture target, and external
  release evidence.
