# Changelog

## 2026-09-24 - Modular Monolith Mission Closure

The final closure mission (local branch
`final/modular-monolith-mission-closeout-20260913`, from `cd45e435`) executed
the parts of R13–R20 the original 2026-08-04 target requires.
Ownership debt is 0/0 and the ownership baseline is deleted:
`architecture:ownership` is strict, fails on any live foreign table access,
and a planted `prisma.weddingPlan.findMany()` in the back office fails it with
exactly that record. Dependency debt stays 0 with no baseline.
Every context reads and writes only its own tables; data another context
owns is reached through that owner's public port on the caller's client or
transaction (planning, finance, tasks, guests, identity, collaboration,
catalog, marketplace, messaging, notifications, media; insights and the back
office compose over them and own no foreign table).
The Mobile fate map is complete: the phone wrappers are dissolved,
`QuoteFinanceContext` lives in finance, the provider persona is its own
feature (`features/provider_portal`), the seven god files and the touched
marketplace provider are split into same-library parts, and the router is
assembled from per-area route trees with `MOBILE_ROUTES.md` unchanged.
Commits exist only on the local branch. No push, merge, deployment,
production mutation, remote CI, provider delivery, phone acceptance, or
release is claimed. Verification and verdicts:
`docs/superpowers/reports/2026-09-24-modular-monolith-mission-closure-final-report.md`.

- Backend ownership 385/781 -> 0/0. Each owner exposes what other contexts
  read or change as public ports on the caller's client (plan read, plan
  erasure, planning budget write, finance, tasks, guests, user read, active
  plan, provider account, realtime session, collaboration permission / scope
  / history / erasure, catalog read and admin, provider read, quote read,
  marketplace erasure and admin, conversation lifecycle, messaging
  participation / erasure / admin, notifications, notifications erasure and
  admin, identity admin); consumers attach owners' rows after their own reads
  (`MarketplaceRelationsService`, `ConversationRelationsService`,
  `InsightsReadPorts`, `AdminOwners`).
- Ownership scanner provability: dynamic argument shapes resolve through
  their inferred types, product-declared interfaces are walked, a `data`
  column is a field inside a write, an array literal spreading an iterable
  resolves through its element type; declared Prisma input types still fail
  closed, so product code declares exact where/data shapes.
- R18: `architecture:ownership` is strict and reads no baseline;
  `backend/architecture/ownership-baseline.json` and `--write-baseline` are
  deleted; closed gates report the tolerated debt 0/0 and fail if a baseline
  reappears; a planted-violation probe test proves the gate fails.
- R19 Mobile: phone wrappers dissolved; `QuoteFinanceContext` moved to
  finance; `features/provider_portal` split from marketplace (20 areas, live
  legal projection 172; the closed R9 manifest is unchanged, the R9 tests pin
  the delta); invite decision, contributor workspace, task
  timeline, plan management, FinanceApi, AuthController and the marketplace
  provider split into same-library parts (private core + flow mixins for the
  large classes); router assembled from seven per-area route trees;
  `test/support/library_source.dart` lets source-contract tests read a
  library with its parts.

## 2026-09-13 - Modular Monolith R12C Local Completion

R12C is complete locally.
Dependency debt is 0; the dependency baseline is deleted and the import gate
is strict and unbaselined.
Ownership remains 385/781.
The architecture target remains incomplete; R13–R18 remain.
Commits exist only on the local recovery branch
`recovery/r12c-t5-takeover-20260913`. No push, merge, deployment, production
mutation, remote CI, provider delivery, phone acceptance, or release is
claimed.

- Published the unchanged Finance wedding-cost response projection under
  `modules/finance/public`, replaced five direct Marketplace-to-Messaging
  lifecycle imports with one transaction-bound public port backed by the
  existing implementation, and published the pure Marketplace provider-access
  policy under `modules/marketplace/public`; every declared consumer (3, 5, 7)
  uses those contracts and no legacy path, facade, fallback, or duplicate
  remains.
- Retired exactly dependency IDs `10`, `12-17`, `19-20`, moving the ledger
  from `9` to `0`; deleted `.dependency-cruiser-known-violations.json`; made
  `architecture:imports` strict; removed the `architecture:imports:baseline`
  generator. Ownership remains byte-identical at `385/781`.
- Bound the R12 governance gates to repository identity (Git top level
  extending base commit `4d0d3ee9`, base-relative overlay) instead of an
  absolute path, directory name, branch, exact HEAD and dirty working tree, so
  every gate runs from any checkout; canonicalized governance scripts to LF;
  isolated the R8/R3 fixtures from the live dependency installation.
- Applied the registered R12C security prerequisite: multer `2.3.0` and sharp
  `0.35.4` (registry advisories published after 2026-09-05); both audits are
  at zero.
- Task 5 passed the combined 16-file architecture/security run `682/682`;
  Task 6 passed focused `133/133`, full Backend `1499` with `1498` passing and
  one declared Windows skip, aggregate smokes `30/30`, six phase-2
  concurrency smokes, architecture/check/build/security at zero.
- Closed the byte-lineage governance after Task 7 (spec section 19): added
  the tracked closure record `backend/architecture/modular-monolith-closure.json`
  (phase, base commit, lineage commit `4bae5c6d`, frozen manifest hashes,
  lineage gates) and its reader; R12A/R12B/R12C, R3 and R5 verify live
  invariants once it exists (`stage=strict (closed)`) and fail closed on any
  deviation of the record, manifests or ancestry; lineage-only tests skip
  with a printed reason and the governance-portability suite re-runs the
  lineage gates at the lineage commit. Nothing is baselined or ignored.
- No Product, API, schema, migration, Mobile, Admin Web, deployment, or
  release behavior changed.

## 2026-09-06 - Modular Monolith R12B Local Completion

R12B is complete locally.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation followed on 2026-09-13 (see above).
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.

- Relocated the unchanged Planning wedding-location implementation to its
  single `modules/planning/public` owner and rewrote only the seven declared
  consumers; no legacy implementation, facade, fallback, or duplicate remains.
- Re-expressed the nested local-plan task and guest DTOs inside Onboarding with
  exact validation and payload parity, removing only the declared cross-context
  API-DTO reuse.
- Retired exactly dependency IDs `7-9`, `11`, `18`, and `21-22`, moving the
  ledger from `16` to `9` while the ownership baseline remains byte-identical
  at `385/781`.
- Preserved Product Logic, APIs, schema, migrations, permissions, transactions,
  Arabic behavior, Mobile, Admin Web, deployment, and all later-phase scope.
- Task 5 passed focused `54/54`, full Backend `1455/1456` with zero failures and
  one declared Windows skip, affected smokes `9/9`, aggregate smokes `30/30`,
  audits at zero, and independent review at Critical/Important/Minor `0/0/0`.

## 2026-09-02 - Modular Monolith R12A Local Completion

- Moved four Backoffice authority/mutation contracts and one Marketplace
  provider-rating helper to their owner-controlled `public/` locations; rewrote
  nine exact consumers and removed all five legacy implementations without
  facade, duplicate, fallback, or compatibility layer.
- Retired exactly dependency IDs 1-6 through `22 -> 17 -> 16`; projected one
  ownership path without semantic/count drift, preserving `385/781`.
- Removed the exact provider-rating exceptions while retaining the declared R16
  Identity-to-Marketplace helper handoff and the R17 Backoffice permission
  contract handoff.
- Added the strict R12A manifest/scanner, immutable historical handoffs, and a
  fail-closed Prisma package-security projection that rejects duplicate decoded
  JSON members before native parsing. Pinned package/lock fingerprints and the
  package lock remain unchanged.
- Passed behavior `31/31`, architecture `522/522`, full Backend tests
  `1407/1408` with zero failures and one pre-existing skip, all affected smokes,
  all 30 aggregate smoke packages, protected-surface and whitespace gates.
  Task 5 independent review is APPROVED (`0/0/0`).
- Task 6 documentation/scope/identity gates and independent review passed with
  no Critical, Important, or Minor finding. R12A is complete locally.
  No API, schema, migration, route, DTO, error, permission, transaction, Arabic,
  Mobile, Admin Web, deployment, commit, push, merge, remote CI, provider
  delivery, or release change is claimed.

## 2026-09-01 - Modular Monolith R11 Target Reconciliation

- Added the post-R10 remaining-target design, approved R11 execution plan, and
  evidence-receipt path; aligned active architecture, status, decision, and
  execution documents with the original 2026-08-04 target.
- Recorded the exact remaining Backend debt at 22 dependency records and 385
  ownership records / 781 occurrences without modifying or regenerating either
  baseline.
- Assigned the full non-overlapping ownership retirement to R13-R17 and made
  R18 a strict 0/0 proof and baseline-deletion phase only.
- R11 changes documentation only. It changes no application source, API,
  schema, migration, runtime, test, dependency, lockfile, CI, deployment, phone,
  provider delivery, or release state. Local R10 commit
  `4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1` predates R11; R11 performs no
  additional Git mutation.
- Passed the exact nine-Markdown scope, immutable 178-path R10 fence,
  documentation sync/verification, cumulative Backend architecture, unchanged
  debt 22 and 385/781, and independent review with no unresolved finding.

## 2026-08-31 - Modular Monolith R10 Admin Local Completion

- Moved the 78-file Admin source set into eight owner features, Platform,
  Design System, retained composition roots, and test-only contracts. The old
  `api/auth/components/pages` roots are `0/0/0/0`; no facade, duplicate,
  fallback, or compatibility layer remains.
- Added permanent TypeScript-AST boundary and fixed-base scope gates for exact
  public APIs, the acyclic feature graph, composition roots, 22 routes, 62
  request records, 1,020 Arabic literals, 18 existing test files / 96 existing
  tests, and protected hashes.
- Preserved Admin UI behavior, Arabic/RTL copy, routes, request methods/paths,
  auth/session/RBAC behavior, dependencies, Backend product source, Mobile,
  Prisma, database history, and deployment topology.
- Passed Admin 101/101 plus build/smokes/audit/runtime, Backend 1,351 pass / 0
  fail / 1 skip plus Prisma and all smokes, Mobile 1,164/1,164, docs, protected
  surfaces, cleanup, and independent review with zero finding.
- Closed the R0-R10 local execution wave with declared Backend debt 22 and
  385/781. No commit, push, merge, deployment, production mutation, remote CI,
  real WhatsApp delivery, live Firebase Push, or architecture-target completion
  is claimed.

## 2026-08-30 - Modular Monolith R9 Local Completion

- Added controlled public APIs for all 19 Mobile feature owners and migrated
  cross-feature consumers to exact exported symbols. Only `app.dart`,
  `app_router.dart`, and `main.dart` remain approved composition roots.
- Activated the fail-closed strict Mobile boundary in CI. Historical feature
  debt fell from 269 records to zero, root debt from 34 to zero, and the legal
  public projection is 159 records.
- Canonicalized `SafeUser` under `core/session` and decoupled Push lifecycle
  binding from mutable auth state without changing bind, unbind, replacement,
  resume, or pending-notification behavior.
- Corrected the phone-discovered local-plan ownership defect at the teardown
  boundary: ordinary logout, restore rejection, and confirmed session expiry
  preserve an unimported installation-owned guest plan. Confirmed account
  deletion may clear it; successful migration and explicit double-confirmed
  discard keep their existing destructive contracts.
- Passed Mobile governance 230/230, strict debt zero with `legal=159`, Flutter
  1164/1164, focused SafeUser/Push 10/10, direct C5 18/18, expanded session
  19/19, Backend/Admin gates, isolated runtime migrations and smoke, physical
  `SM-S938B` session-invalidation/relaunch acceptance, and independent review
  with zero Critical, Important, or Minor findings.
- Live Firebase Push, iOS/store acceptance, remote CI, deployment, and the stale
  repository seed fixture remain outside this completion. R9 is committed
  locally only; no push, merge, deployment, store release, S10, or R10 is
  claimed.

## 2026-08-28 - Modular Monolith R8 Local Completion

- Removed the final two project-owned Nest `@Global()` declarations from
  `PrismaModule` and `ConversationRealtimeModule`; both are ordinary explicit
  modules with no compatibility facade or duplicated provider.
- Added the missing direct `PrismaModule` import to
  `ApplicationOutboxRuntimeModule`. Strict R8 reports project globals 0,
  Prisma 21/21 with missing 0, Realtime 2, duplicates/`forwardRef()`/cycles 0,
  dependency 22, and ownership 385/781.
- Preserved singleton Prisma and Realtime provider identity, the exact Realtime
  `useExisting` chain, and the dependency-owned
  `@nestjs/schedule@6.1.3`/`@nestjs/throttler@6.5.0` runtime behavior.
- Architecture/check/build, 1,345/1,346 Backend tests with zero failures and one
  intentional Windows skip, both zero-finding audits, Prisma 52/41 and 76/76
  equivalence, 12 focused smokes, all 30 aggregate smokes, docs, scope, and
  protected surfaces passed. Independent Task 3-5 reviews found no Critical or
  Important issue.
- Built immutable image `aarast-backend:r8-candidate-464d785a`, image ID
  `sha256:6fa367649ef2835b6b4b16efba088e9c26c38baa8ffbb9e3efeb74bd853153ad`.
  Corrected probe and local/LAN cutover passed `/live`/`/ready` 200,
  database/Redis/media up, restart 0, OOM false, healthy exact revision, and
  sanitized fatal/configured-key/value checks.
- On owner-authorized phone 26 only, the accepted R5Local app restored the
  authenticated context/dashboard, completed synthetic task
  create/read/update/delete, sent/read one eligible quote-scoped realtime
  message, and restored session/dashboard/clean task state after force-stop.
  S10 was not used and no private identifiers, credentials, or raw bodies were
  retained.
- R8 is locally complete at application candidate
  `464d785a0440b8494768a26a70ac1de73a4bff2c`. R7 is stopped and preserved for
  rollback. No push, merge, PR mutation, deployment, remote CI, or R9 work is
  claimed.

## 2026-08-24 - Modular Monolith R7 Local Completion

- Moved all 18 Collaboration files one-to-one from the retired `sharing` and
  `contribution-history` roots into the existing
  `modules/collaboration` API/internal/public boundary. No compatibility facade
  or duplicate implementation remains.
- Preserved routes, DTO/controller decorators, DI/provider identity, optional
  realtime behavior, public snapshot exports, permissions, history,
  transactions, Arabic/errors, schema, migrations, Mobile, Admin, workflows,
  Compose, and deployment contracts.
- Retired exactly nine dependency debts: the known set is 22. Physical
  ownership remains 385 records / 781 occurrences with path-only relocation.
- Architecture/check/build, R7 210/210, Backend 1242/1243 with zero failures
  and one intentional Windows skip, both zero-finding audits, Prisma 52/41
  equivalence, 11 focused smokes, all 30 aggregate smokes, docs, and protected
  surfaces passed. Independent cumulative review approved the exact candidate
  with no Critical, Important, or Minor finding.
- Built immutable image `aarast-backend:r7-candidate-aafb47ea`, image ID
  `sha256:55a5311048d57ffded953f18dedcf3e8fdcb4da8b3171e8c56ecededa0d3e0ae`.
  Isolated probe and local/LAN cutover passed at `/live`/`/ready` 200,
  database/Redis/media up, restart 0, OOM false, and clean sanitized logs.
- The authenticated phone journey passed session/context/dashboard restore,
  synthetic invite create/reissue/read/cancel cleanup, and force-close/reopen.
  OpenWA was disabled and no real delivery was claimed or attempted. R6 is
  stopped and preserved for rollback.
- R7 is locally complete at application candidate
  `aafb47ea1742c278f6a5ed24799ada7bc23721b0`. No push, merge, PR mutation,
  deployment, remote CI, real-recipient delivery, or R8 work occurred.

## 2026-08-22 - Modular Monolith R5 Local Completion

- Moved all 44 Identity source files one-to-one from `auth`, `users`, `me`, and
  `contexts` into the existing `modules/identity` public/internal/api boundary;
  all four retired roots are absent and no compatibility facade remains.
- Reconciled the dependency baseline to exactly 31 records after retiring the
  58 authorized relocation debts. Ownership remains 385 records / 781
  occurrences after path-only relocation.
- Preserved routes, Arabic/error contracts, auth/OTP/session/context behavior,
  schema, migrations, model ownership, Mobile, Admin, workflow, Compose, and
  deployment surfaces. The exact three smoke-harness setup corrections are
  hash-pinned and limited to existing production preconditions.
- Architecture/check/build, 1006/1007 Backend tests with one intentional
  Windows skip, Prisma equivalence, both zero-finding audits, nine targeted
  smokes, all 30 aggregate smoke packages, docs, protected surfaces, and
  cleanup passed.
- Immutable application candidate
  `8cfee451a76bb17e20d278a1646dde4387bf7b18` runs as
  `aarast-backend:r5-final-8cfee451`; local/LAN live and ready checks passed at
  zero restarts and no OOM. R4 remains stopped and preserved for rollback.
- The owner passed authenticated login, Home/context restore, representative
  reads and writes, and full close/reopen. Sanitized R5 logs contained 237 HTTP
  events, 236 successful responses, zero HTTP 5xx, and one controlled
  unauthenticated 401 probe; no secrets or payload values were retained.
- R5 is locally complete. No push, merge, PR mutation, deployment, remote CI,
  or R6 work is claimed.

## 2026-08-21 - R5 Prisma Config Merge Security Checkpoint

- Kept Prisma, Prisma Client, and Prisma Config at 6.19.3 while pinning the
  affected transitive merge implementation from 7.1.5 to exact patched
  `deepmerge-ts` 8.0.1 for CVE-2026-40345. No force-fix, audit suppression,
  downgrade, or Prisma major upgrade was used.
- Added permanent package/lock, installed-resolution, recursive merge,
  input/primordial immutability, safe-output, and authenticated-worker checks.
  The R5 gate also rejects lock-only activation, unrelated dependency drift,
  ranged overrides, Prisma version drift, and extra implementation paths.
- Security/R5 tests passed 30/30; architecture/check/build, 1005/1006 Backend
  tests with one intentional Windows skip, both zero-finding audits, nine
  targeted smokes, all 30 aggregate smoke packages, docs, and cleanup passed.
- Preserved Prisma semantics at 14 schema files, 52 models, 41 enums, and 76
  migrations with byte-identical DMMF and migration SQL. Frozen application,
  Mobile, Admin, deployment, schema, migration, and Dockerfile surfaces did not
  change.
- The immutable isolated image passed dependency identity, security,
  migrations, live/ready, restart/OOM, and sanitized startup checks. The probe
  was removed and the existing phone runtime was not cut over. Independent
  review passed with no findings.
- This was the local R5 Task 5A checkpoint; the later R5 closeout is recorded
  above. No push, merge, PR mutation, deployment, remote CI, or R6 is claimed.

## 2026-08-16 - Modular Monolith R4 Local Completion

- Replaced Finance's direct `WeddingPlan` budget write with one exact
  Planning-owned `PLANNING_BUDGET_WRITE_PORT`. `MoneyBudgetService` passes its
  existing serializable transaction and unchanged budget input to the sole
  `WeddingPlanBudgetWriter`; no transaction, retry, error, route, payload, or
  response behavior changed.
- Retired exactly the frozen Finance-to-Planning ownership debt. The ownership
  baseline decreased from 386 records / 782 occurrences to 385 / 781, with no
  other record or count change.
- Backend architecture passed at 344 modules, 1395 dependencies, 89 known
  dependency records, ownership 385, zero `forwardRef()`, two approved globals,
  and zero cycles or illegal context edges. Check, build, 968/969 tests with one
  intentional Windows skip, Prisma validation, both zero-finding npm audits,
  affected money smokes, health, and all 30 aggregate smoke packages passed.
- Built and cut over immutable image `aarast-backend:r4-final-536890cc` at exact
  application revision `536890ccafcabebcd4d095a33c014933d6451fdb`. Local and
  LAN live/ready returned HTTP 200, restart count stayed zero, OOM was false,
  76 migrations and the native schema folder were discovered, and safe fatal
  marker checks were empty. The R3 container/image remain stopped and preserved.
- The owner passed login, Home, money-budget/category replacement, reload, and
  force-close/reopen on the unchanged R3Local APK. Sanitized R4 evidence included
  login 200, `/api/v1/auth/me` 200, three money-budget PUT 200 responses, repeated
  money-summary GET 200 responses, zero HTTP 5xx, and no raw bodies or secrets.
- R4 is locally complete. No push, merge, PR mutation, deployment, or remote CI
  is claimed, and R5 has not started.

## 2026-08-16 - Modular Monolith R3 Local Completion

- Implemented demand-driven Nest full/internal/public boundaries for all 13
  business contexts from immutable R3 base
  `6b06eb096aca8cc6684d365d16e05d4cd8529898`. Closed all initial duplicate
  registrations (3/3), platform debts (6/6), and retired provider edges
  (163/163), with zero `forwardRef()`, cycles, or illegal boundary edges.
- Added TypeChecker-resolved context, provider-identity, retirement, source-law,
  and fixed-base scope enforcement. The final local receipt contains exactly 214
  reviewed cumulative paths and zero unexpected paths.
- Preserved schema semantics at 14 files, 52 models, 41 enums, and 76 migrations;
  DMMF remains equal and migrate diff empty. Backend/Admin/Mobile/docs/audit and
  all managed smoke gates passed without route, API, schema, migration, or
  deployment expansion.
- The physical-phone gate reproduced a pre-existing Mobile cold-restore race:
  account-context bootstrap advanced a shared generation and discarded a real
  HTTP-200 `/api/v1/auth/me`. Split account-session and selected-context
  generations at the ApiClient boundary, with permanent RED-to-GREEN and
  isolation coverage.
- Built and cut over immutable image `aarast-backend:r3-final-dfc5488c` at exact
  revision `dfc5488cf30d4eb36dc2d72c618b2442f34ea058`. Local/LAN health, safe logs,
  restart/OOM state, protected probe, and rollback preservation passed.
- Installed the corrected `com.aarast.aarast_mobile.r3local` APK with data
  preservation. The owner reached the dashboard; independent ADB force-stop and
  relaunch restored the authenticated dashboard with one `SESSION_RESTORED`,
  one HTTP-200 `/api/v1/auth/me`, and zero restore failure, logout, or fatal
  markers.
- R3 is locally complete. The prior R3 and accepted R2 images/containers remain
  available for rollback. R4 has not started, and no push, merge, deployment, or
  remote-CI result is claimed.

## 2026-08-14 - Modular Monolith R2 Local Closure Candidate

- Replaced the retired single Prisma schema with the native 14-file folder:
  `_base.prisma` plus 13 current model-owner files, containing exactly 52
  models and 41 enums. All 76 migrations and the seed remain byte-identical to
  immutable `R2_BASE` `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`.
- Added the fail-closed layout manifest, canonical schema loader, normalized
  DMMF fingerprint, fixed-base R2 scope gate, and reviewed mechanical migrations
  for existing schema readers. Prisma config and both Docker stages now discover
  the folder without a compatibility copy or deprecated fallback.
- Empty migrate diff, equal normalized DMMF, frozen generated contracts,
  Backend architecture/check/build/tests/audits/migration rehearsals/all 30
  smoke packages, unchanged Admin and Mobile gates, docs, scope, and protected
  surface checks all passed locally.
- Built immutable image `aarast-backend:r2-final-b40e2961` at revision
  `b40e2961c4c2e0c1e48ebdf1b4eff8444bc1d63f`; image inspection, protected
  probe/cutover, local/LAN readiness, dependency health, zero restarts, and
  sanitized error/log gates passed. The stopped R1 container and image remain
  available for rollback.
- The first phone attempt used a stale R1-local APK with a loopback API URL and
  emitted no R2 request. A separately packaged R2Local APK targeted the verified
  LAN URL; device reachability and the owner's login/home/core-flow checkpoint
  then passed. This distinguishes client configuration from Backend behavior.
- Final independent R2 source/contract/runtime/receipt sign-off is requested.
  At that R2 checkpoint, R3 had not started. Remote CI was not run, and no push
  or merge is claimed.

## 2026-08-13 - Modular Monolith R1 Local Completion

- Implemented the complete R1 platform/shared-kernel relocation locally on
  branch `modular-monolith`, anchored to immutable `R1_BASE`
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. The exact 185-path combined diff
  manifest and exact move map are recorded in
  `docs/project/STATUS.md`; no old-path facade remains.
- Moved configuration, HTTP, database, Redis, observability, health,
  idempotency, outbox, and concrete OTP transport code to `src/platform/`;
  established Money/phone/privacy/application-identity/time under
  `src/shared-kernel/`; moved the pure Admin permission matrix to
  `src/modules/backoffice/domain/`.
- Reconciled the dependency baseline to 260 sorted unique records (mapped 6,
  removed 9, decreased 0), preserved ownership at 386 keys/782 occurrences,
  kept Mobile at 269 records, 52 models/76 migrations, forwardRef 0, and the
  exact two approved globals.
- Removed only the phase-specific `r0-scope` CI job. Backend architecture and
  tests, image, E2E, Admin, Mobile, docs, secrets scan, and dependency audit
  jobs remain. The local R0 scope script/tests remain historical evidence.
- Exact local commands and results:
  - Backend `npm run architecture`, `npm run check`, `npm run build`, and
    `npm test` PASS; 805 total / 804 passed / 0 failed / 1 Windows skip.
  - Bare `npx prisma validate` produced the documented P1012 because this
    worktree has no `DATABASE_URL`; schema-only process-scoped local-placeholder
    rerun PASS without a connection or `.env` write.
  - `npm audit --audit-level=high` and `npm audit --omit=dev` PASS with 0
    vulnerabilities.
  - `npm run smoke:all` PASS: all 30 managed packages after 76 migrations;
    backend-completion 76/76; run resources cleaned.
  - Admin `npm run typecheck`, `npm test -- --run`, `npm run build`,
    `npm run smoke:honesty`, `npm run smoke:routes`, and
    `npm run test:container-config` PASS: 96/96, 12/12, 16/16, 3/3.
  - Mobile boundary tests/baseline PASS 192/192 and 269; `flutter analyze
    --no-pub` PASS; authoritative `flutter test --no-pub` PASS 1151/1151.
  - Docs sync/verify/diff and fixed-base protected pre/postflight PASS with
    zero drift/errors/warnings and no protected source side effect.
- Six exact platform-to-business debts remain assigned to R3; sharing's direct
  OTP transient-policy consumption remains assigned to R6; the two globals
  remain assigned to R8. The independent final review and owner's application
  checkpoint passed; R2 is next and has not started.
- R1 preserves API routes, errors and Arabic text, permissions, transaction/
  lock/retry/scheduler semantics, schema/migrations, Mobile/Admin source, and
  deployment artifacts. Expected negative-path logs, DEP0190, Admin
  ErrorBoundary output, and Flutter desktop plugin notices were observed and
  not hidden.
- Final phone-server review reproduced and corrected one pre-existing
  cross-replica crash: the access-token expiry `NodeJS.Timeout` is now kept in
  a process-local `WeakMap` instead of Redis-serialized `socket.data`. Token
  lifetime and disconnect behavior are unchanged, and the focused Redis
  remote-fetch serialization regression passes.
- This entry records local evidence only. PR #76 remains at the R0 candidate;
  no R1 push, merge, or remote-CI success is claimed. Independent source,
  contract, baseline, gate, final-image, and runtime review passed with no
  findings. The owner then passed authenticated login, conversation open/read,
  and message send from the phone against image revision `d2530c5c`; the
  container remained up with zero restarts and no circular/TypeError/fatal log
  match. R1 is locally complete; R2 is next and has not started.

## 2026-08-12 - Modular Monolith R1 Execution Started

- Recorded the owner's decision to continue R1 and later modular-monolith
  phases locally on the same `modular-monolith` branch without intermediate
  merges. Immutable R0 candidate
  `94b677b7b8e2219e0db2cbc553fa3d26b4876456` is the R1 comparison base.
- Established a hard checkpoint after every task: automated gates, managed
  server smoke, independent review/remediation, clean local commit, and owner
  application testing before continuation.
- PR #76 remains unchanged at the R0 candidate; no R1 push, merge, or remote-CI
  result is claimed by this local execution-start record.

## 2026-08-12 - Modular Monolith R0 Local Verification

- Established the tracked modular-monolith architecture contract, exact
  52-model physical-ownership registry, incremental dependency/ownership/Mobile
  baselines, Nest ports/global/cycle enforcement, fixed-base R0 scope guard,
  and CI wiring. dependency-cruiser is pinned to `18.1.0`.
- Provenance: branch `modular-monolith`, fixed R0 base revision
  `feafe3db0053d6c66d5f46b56ff9a512861dfbad`. This is local evidence only;
  immutable pull-request/workflow metadata owns candidate identity and remote
  CI state, so no mutable branch-tip or current remote-CI claim appears here.
- Observed baselines are 269 unique known dependency violations; 386 ownership
  keys / 782 occurrences (foreign-model 302/564,
  unknown-relation-shape 83/216, unknown-sql-composition 1/2); and 269 Mobile
  keys/occurrences (62 core-to-feature, 207 direct-cross-feature). The ports
  gate reports zero `forwardRef()`, two approved globals, zero illegal future
  imports, and zero Nest cycles.
- Final local review remediation initially stayed inside the 30-path allowlist. Backend
  commits `003474d9`, `302aec72`, `8de041ce`, `d8788ed8`, `8d0e8116`, and
  `182ade08` close ownership/ports provenance, alias, redaction,
  non-reflective-diagnostic, and atomic-result-validation gaps. Mobile commit
  `ff35ea73` closes canonical-junction and nested-interpolation parser bypasses.
  Documentation commit `7f4cd70` reconciles the exact Mobile repair exception,
  official gate commands, and PR-head versus synthetic-merge CI semantics.
  Mobile commit `019f9a28` validates scan and baseline results atomically and
  makes scan-error diagnostics non-reflective: hostile result structures fail
  closed before output, while legitimate errors emit only a fixed kind and
  canonical repository-relative source. Ownership commits `7c53a9d`,
  `70d6de05`, and `9fc322b7` validate current scans, saved baselines, and writes
  atomically without reflecting source-controlled fields; enforce semantic
  record invariants; and bind every context to its registry-backed repository
  path. The independent final local review passed after these remediations.
  None of them adds runtime product behavior, and this local review result
  makes no remote-CI claim.
- The first PR secret-scan run found one false positive in the historical R0
  Symbol-type rejection fixture. Commit `536058bf` removes the secret-shaped
  text from the current test and records only the exact reviewed historical
  fingerprint in `.gitleaksignore`; it does not disable a rule or file path.
  The fixed-base scope therefore contains 31 paths, and a local Gitleaks v8.30.1
  rescan of all 37 R0 commits reported no leaks.
- The exact fixed-base diff is: `.github/workflows/ci.yml`, `.gitleaksignore`,
  `AGENTS.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `backend/.dependency-cruiser-known-violations.json`,
  `backend/.dependency-cruiser.cjs`,
  `backend/architecture/ownership-baseline.json`,
  `backend/architecture/ownership-registry.json`, `backend/package-lock.json`,
  `backend/package.json`,
  `backend/scripts/architecture/ownership-scan.cjs`,
  `backend/scripts/architecture/ports-scan.cjs`,
  `backend/test/architecture-dependencies.test.ts`,
  `backend/test/architecture-ownership.test.ts`,
  `backend/test/architecture-ports.test.ts`, `docs/README.md`,
  `docs/SCRIPTS.md`, `docs/backend/README.md`,
  `docs/frontend/MOBILE_ARCHITECTURE.md`, `docs/project/DECISIONS.md`,
  `docs/project/EXECUTION_PLAN.md`, `docs/project/STATUS.md`,
  `docs/qa/README.md`,
  `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md`,
  `mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`,
  `scripts/architecture/mobile-boundaries-baseline.json`,
  `scripts/check-mobile-boundaries.mjs`,
  `scripts/check-mobile-boundaries.test.mjs`, `scripts/check-r0-scope.mjs`, and
  `scripts/check-r0-scope.test.mjs`.
- The only application-source change is the owner-approved one-line Mobile
  local-import correction in `aarast_path_card.dart`, unchanged since repair
  commit `464a23e0`. Backend source/schema/migrations/routes, Mobile tests and
  integration tests and every other Mobile source file, Admin source,
  deployment artifacts, source locations, and business logic were untouched.
- Exact local commands and results, run from the repository root unless a
  working directory is named:
  - Protected pre/post gate: `git diff --name-status --no-renames
    --diff-filter=ACMRDTUXB
    feafe3db0053d6c66d5f46b56ff9a512861dfbad -- backend/src
    backend/prisma/schema.prisma backend/prisma/migrations mobile/lib
    mobile/test mobile/integration_test admin-web/src deploy
    docker-compose.yml` returned exactly the approved Mobile `M` path;
    `git diff --exit-code 464a23e0..HEAD --
    mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart` PASS;
    `git status --porcelain=v1 --untracked-files=all -- backend/src
    backend/prisma/schema.prisma backend/prisma/migrations mobile/lib
    mobile/test mobile/integration_test admin-web/src deploy
    docker-compose.yml` returned no worktree entry; and
    `node .\scripts\check-r0-scope.mjs --check` PASS.
  - From `backend/`: `npm run architecture` PASS; `npm run check` PASS;
    `npm run build` PASS; `npm test` PASS with 746 total, 745 passed, and one
    intentionally skipped; `npm audit --audit-level=high` PASS with zero
    vulnerabilities; and `npm audit --omit=dev` PASS with zero vulnerabilities.
  - From `backend/`: the first bare `npx prisma validate` failed with `P1012`
    because `.env` and `DATABASE_URL` were absent. The same exact
    `npx prisma validate` command then PASSed after setting a process-scoped,
    non-secret local validation URL; validation made no database connection,
    the value was not persisted, and the process environment entry was removed.
  - Gitleaks v8.30.1 scanned the 37-commit fixed-base R0 range with redaction
    enabled and PASSed with no leaks after applying the exact reviewed
    fingerprint.
  - From `admin-web/`: `npm run typecheck` PASS; `npm test -- --run` PASS
    96/96; `npm run build` PASS; `npm run smoke:honesty` PASS 12/12;
    `npm run smoke:routes` PASS 16/16; and
    `npm run test:container-config` PASS 3/3.
  - `node --test .\scripts\check-mobile-boundaries.test.mjs` PASS 192/192;
    `node .\scripts\check-mobile-boundaries.mjs --check-baseline` PASS with
    269 current records; from `mobile/`, `flutter analyze --no-pub` PASS with
    no issues and `flutter test --no-pub` PASS 1,151/1,151.
  - `node .\scripts\docs-sync.mjs --check` PASS with drift=0/errors=0;
    `node .\scripts\docs-verify.mjs` PASS with errors=0/warnings=0; and
    `git diff --check` PASS before and after the receipt.
  - `(Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+').Count`
    returned 52; `(Get-ChildItem .\backend\prisma\migrations -Directory).Count`
    returned 76.
- Existing Backend fixture/log, Admin ErrorBoundary, and Flutter desktop-plugin
  warnings remained visible while their suites passed.
- No separate local runtime smoke was required because R0 added no Backend
  runtime/schema/route/deployment change or business logic, and the approved
  Mobile import correction passed the full Flutter suite. This receipt records
  local evidence only: the authoritative candidate revision and remote CI
  result belong to immutable PR/workflow metadata. Closure requires
  `r0-scope` on the exact immutable PR-head revision and all other CI jobs on
  the corresponding synthetic merge candidate; no mutable branch-tip or
  current remote-CI claim is made here.

## Unreleased - Provider Application Completion UX

- Removed the customer-facing `فتح الموردين` action from the successful
  provider-application receipt. A newly submitted provider now has one honest
  next action, `العودة للرئيسية`, while approval is pending.

## Unreleased - Dual-Realm Account Deletion

- Corrected `DELETE /api/v1/users/me` for administrators who separately enroll
  in the wedding application: the app identity, app-owned data/media and
  `APPLICATION` sessions are erased while the administrator profile,
  credentials, audit links and `ADMIN` sessions remain intact.
- Prevented Mobile from immediately replaying an account DELETE while the
  durable status is `PENDING`; the termination gate now reports that deletion
  is being verified and reuses the same request id on a later safe retry.
- Added focused Backend/Flutter regressions, a real PostgreSQL/Object Storage
  smoke scenario for dual identities, and matching API/database/QA/Mobile,
  privacy, status, and handoff documentation.

## 2026-08-11 - Production Deployment, Modernization Closure, And Handoff

- Consolidated the prelaunch money domain around optional general budget,
  `BudgetCategory`, `WeddingCost`, append-only `CostPayment`, and dated
  `PaymentSchedule`; removed obsolete debt/expense compatibility surfaces.
- Completed the current Arabic-first Mobile and Admin hardening wave, including
  truthful marketplace/loading states, offline ownership and diagnostics,
  contributor access/history boundaries, account deletion recovery, React
  Router 7, and zero-finding Backend/Admin dependency audits.
- Added versioned reference catalogs, typed Yemen geography, contributor-history
  scope/tenure invariants, and repair migration
  `20260811180000_backfill_missing_contributor_history_scopes`.
- Deployed immutable Backend, Admin Web, and fail-closed public-site images at
  application revision `900897a90e8b030c7c3ddfdc55cc2669b64f2e87` through
  Dokploy. External API/Admin/public checks passed; all 76 migrations are
  current and all 15 live plans have linked contributor-history scopes.
- Verified a fresh custom-format production backup through checksum, catalog,
  isolated restore against the exact Backend image, an idempotent second
  migration pass, schema checks, and relational postconditions.
- Built and verified the signed direct-install Android APK `1.0.0+8` from exact
  Mobile source revision `2ffbe95d7a8e412ead47220536046501f4ac86bf`; it is
  non-debuggable and its upload signer matches deployed Android association.
  It is not a store AAB and does not close physical-device or store gates.
- Merged the audited remediation and production history-scope hotfix through
  green CI, removed fully merged temporary branches, and preserved the unique
  `codex/guest-invitation-campaigns` WIP as a quarantined remote branch plus a
  verified local bundle.
- Added `docs/HANDOFF.md` and synchronized active status, Backend risk,
  deployment, OpenWA, scaling, QA, release, privacy, and store documentation to
  the observed repository and production state. Archived `.md.txt` material
  remains historical only.

## 2026-07-17 - Confirmed WhatsApp OTP And Invite Handoff

- Hardened the private OpenWA delivery contract so Aarast accepts a send only when the transport returns both a non-empty message ID and `deliveryStatus: SENT`; explicit pre-send rejection is separated from an uncertain post-send outcome so valid OTPs are neither consumed early nor reported as definitely delivered.
- Added invite-delivery handling for the same definitive-versus-uncertain contract, keeping user-facing retry states truthful when WhatsApp acceptance cannot be proven.
- Preserved a private invite token in memory across the verified OTP account-boundary switch, then resumes it exactly once under the invited account. A previously signed-in account can no longer query or accept that invite before phone verification.
- Added backend and Flutter regression coverage for malformed or unknown gateway responses, incomplete acknowledgements, two-account invite handoff, logout cleanup, and one-time token consumption. No screen layout, visual identity, database schema, or public route was changed.

## 2026-07-08 - Launch Readiness Wave 3 (10/10 Push)

- Financial data now has database-level CHECK constraints (non-negative amounts, paid ≤ total, positive payment records) on every money table as a last line of defense below the application layer; `Debt.create` was fixed to clamp `paidAmount` to `[0, total]` and derive status, closing a path that could persist `paid > total` with a caller-chosen status. Constraint rejection verified live against Postgres.
- CI gains secret scanning (gitleaks over full history — 262 commits verified clean, one false positive allowlisted with justification) and a `dependency-audit` gate (`npm audit --audit-level=high`); admin-web upgraded Vite 5→7 to clear the esbuild dev-server advisory. Both projects report 0 vulnerabilities. Dependabot enabled for npm, pub, docker, and Actions.
- Added a deployable monitoring stack under `deploy/monitoring/` (Prometheus + Alertmanager + Grafana) with a provisioned dashboard, alert rules (backend down, >5% 5xx, p95 >1s, event-loop saturation, OTP failure spikes), and backend business counters (`aarast_otp_requests_total`, `aarast_otp_verifications_total`, `aarast_payments_recorded_total`) verified incrementing live. Backend now drains in-flight requests on SIGTERM (`enableShutdownHooks`).
- Added a zero-dependency load-test script (`backend/scripts/load/load-test.js`); measured ~1,500 req/s at 50 connections (p95 56ms, 0 errors in 45k requests) on a dev machine, saturation knee documented. Added a verified backup-restore script (restores into a scratch container, checked against a real dump), container memory limits, and a scaling runbook (`docs/deployment/SCALING.md`).
- Admin web gains Vitest + Testing Library (14 tests: auth role-gating, error mapping, token storage, API client, ErrorBoundary) and a top-level ErrorBoundary so a render crash shows a recoverable Arabic message instead of a blank screen; `npm test` runs in CI.
- Mobile: fixed a silent-data-loss bug where a permanently-rejected offline write (4xx or retry-exhausted) was excluded from the pending count and reported as a false "synced" green state; it now surfaces as a sync error. Added 7 tests covering the sync error paths and cross-user cache wipe. 357 mobile tests pass; analyzer clean.
- Store readiness: verified the release signing pipeline end-to-end (a signed AAB was built and its certificate confirmed to be the upload key, not debug); added a Play release guide, an Arabic privacy policy, a Play data-safety answer sheet, and store listing copy. `.gitignore` now blocks keystores and signing config from ever being committed.

## 2026-07-07 - Launch Readiness Wave 2 (Scale, Observability, Hardening)

- Backend now uses Redis (optional `REDIS_URL`) for cross-replica rate limiting and Socket.IO delivery, failing open with a logged warning when Redis is unreachable instead of returning 500s.
- Added request-id correlation (`X-Request-Id`), per-request access logs, a token-guarded Prometheus `/metrics` endpoint, JSON logs in production, and optional Sentry capture for 5xx responses (`SENTRY_DSN`).
- Dokploy compose gains Redis and a nightly `pg_dump` backup sidecar with retention; media (S3), Sentry, metrics, and backup variables documented in `.env.example`.
- Admin web now actually serves its security headers (nginx `add_header` inheritance bug) and ships a strict Content-Security-Policy with the API origin injected at container start.
- Mobile release builds sign with an upload keystore via git-ignored `android/key.properties`, with R8 minification, resource shrinking, and Flutter ProGuard rules; `flutter build apk --release` verified.
- Unbounded list endpoints (expenses, guests, tasks, debts, financial commitments, payment records) accept opt-in `take`/`skip` pagination and are bounded by a 1000-row safety cap; responses stay arrays so existing clients are unaffected.
- CI gains a `backend-e2e` job that boots the compiled backend against Postgres 16 + Redis 7 and runs all 23 smoke suites; the suite passes locally (23/23).

## 2026-07-07 - Launch Readiness Phase 0

- Removed legacy root files (`old_aarast_dashboard_widgets.dart`, `update_dashboard.py`) and untracked local tooling state (`.codex/`, `design_web_refs/` photos) with matching `.gitignore` entries.
- Added `test/password-reset-logic.test.ts` to the backend `npm test` suite (60 tests total).
- Hardened the backend Docker image: dev dependencies are pruned from the runtime layer, the Prisma client is regenerated after pruning, and the container now runs as the non-root `node` user. The `prisma` CLI moved to production dependencies because the container runs `migrate deploy` at startup.
- Added GitHub Actions CI (`.github/workflows/ci.yml`): backend typecheck + tests, backend Docker image build, admin-web build, mobile `flutter analyze` + tests, and docs verification.
- Tagged the nine golden preview test files with `@Tags(['golden'])` and added `mobile/dart_test.yaml`; CI excludes golden tests because their PNGs are Windows-rendered, while local runs still include them.
- No product behavior, API contract, database schema, or deployment topology changed.

## 2026-06-21 - Markdown Source-of-Truth Refresh

- Refreshed documentation to make `API_CONTRACT.md` the route-level API source of truth.
- Reduced risky endpoint duplication in mobile docs by pointing mobile readers to the API contract.
- Marked older backend completion/audit docs with clearer current-vs-historical context.
- Clarified current mobile QA/design source documents and preserved legacy root docs as references.
- Fixed broken Markdown references in the mobile product UX rebuild documentation.
- Confirmed this was a Markdown-only cleanup; no Flutter, backend, admin-web, Prisma, Docker/Dokploy, deployment, migration, package, Git branch, commit, or push work was included.

## 2026-06-14 - Dokploy Production Routing Sync

- Synchronized the production Dokploy Compose configuration with the live server fix.
- Published backend host port `8093` to container port `3000`.
- Published admin dashboard host port `8095` to container port `80`.
- Set production deployment defaults to `PORT=3000`, `CORS_ORIGINS=https://aarast.shadowgardn.com`, and `VITE_API_BASE_URL=https://aarast-api.shadowgardn.com`.
- Updated deployment documentation so future Dokploy redeploys do not restore the old unhealthy port mapping.
- Confirmed no backend business logic, Flutter screens, database migrations, payment/deposit flows, AI, FinTech, internal chat, or confirmed booking behavior were changed.

## 2026-06-07 - Home Dashboard Exact Blueprint Polish

- Polished the Flutter Home dashboard to more closely match the approved Arabic visual reference.
- Tightened the wide-web layout with centered max-width content, denser card hierarchy, and no oversized desktop bottom navigation.
- Reworked the Home hero, metrics, budget summary, quick actions, alerts, members, and shared plans sections using existing APIs only.
- Fixed the Home budget display rule so estimated plan budget is preferred and remaining budget is not shown as negative when budget data is missing.
- Confirmed no backend code, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, confirmed booking logic, generated files, or new packages were created.

## 2026-06-06 - Flutter WeddingPlan Dashboard Command Center Redesign

- Redesigned the Flutter `WeddingPlanDashboardScreen` into a true command center.
- Added new `DashboardSummaryProvider` to fetch and aggregate Plan, Expense Summary, Debt Summary, Due Installments, Tasks, and Shared Members concurrently.
- Replaced basic navigation items with modern summary cards (`WeddingHeroSummaryCard`, `FinancialCommandCard`, `DebtInstallmentCommandCard`, `TaskTimelineCommandCard`, `QuickActionsGrid`).
- Preserved the sharing privacy UX by displaying locked versions of financial cards to shared users without adequate permissions.
- Kept animations subtle and restricted to built-in Flutter widgets (`TweenAnimationBuilder`, `AnimatedSwitcher`, etc.).
- Confirmed no backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created.
- Confirmed no new external Flutter dependencies were introduced.

## 2026-06-05 - Bug-Fix Polish Pass 3

- Improved Sharing member display so cards show safe member name and phone instead of the technical `userId`.
- Added safe shared-user display data to Sharing responses: `id`, `name`, and `phone` only.
- Translated common Sharing errors in Flutter UI, including duplicate member and unknown phone cases.
- Confirmed `passwordHash`, refresh tokens, secrets, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not created or exposed.

## 2026-06-05 - Bug-Fix Polish Pass 2

- Allowed owners to add shared members by registered phone number from Flutter.
- Preserved existing `userId`-based Sharing API support for compatibility.
- Rejected create-share requests that provide both `userId` and `phone`.
- Added sharing smoke coverage for adding a shared member by phone.
- Confirmed no Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, confirmed booking logic, secrets, or unrelated features were created.

## 2026-06-05 - Bug-Fix Polish Pass 1

- Fixed Flutter WeddingPlan Dashboard financial navigation privacy UX for shared users.
- Shared users without financial permissions now see locked/disabled financial cards instead of direct finance or debt navigation.
- Shared users with budget, expense, debt, or financial-record permissions can access the relevant financial dashboard cards.
- Owner dashboard access remains unchanged and still shows finance, debt, task, and sharing navigation.
- Confirmed backend permissions, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-05 - Hands-On MVP QA

- Recorded `MANUAL_QA_REPORT.md` for the successful hands-on MVP QA run.
- Confirmed manual QA passed for Auth, WeddingPlan, Dashboard, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing flows.
- Documented known QA notes for sharing by technical `userId` and financial navigation visibility for shared users.
- Confirmed the next recommended step is a bug-fix polish pass, then deployment planning.
- Confirmed no backend code, Flutter feature code, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created or modified by this QA documentation update.

## 2026-06-05 - Flutter MVP Regression And Manual QA Plan

- Regression-verified the Flutter MVP with `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Audited Flutter routes for Auth, WeddingPlan, Finance, Debts, Tasks, Timeline, and Sharing screens.
- Checked mobile API clients against the frozen `API_CONTRACT.md`.
- Added `MOBILE_QA_PLAN.md` with an Arabic-first manual QA checklist for hands-on backend/mobile validation.
- Documented that the next step after merge is a hands-on QA run and bug-fix pass.
- Confirmed no new mobile features, backend APIs, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, or confirmed booking logic were created.

## 2026-06-04 - Flutter Sharing Screens

- Added Flutter Sharing mobile screens under `mobile/lib/features/sharing/`.
- Wired Sharing API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/sharing`, `/wedding-plans/:id/sharing/add`, `/shared-members/:id/edit`, and `/shared/wedding-plans`.
- Replaced the WeddingPlan Dashboard sharing placeholder with a real navigation card and added a Home entry for shared plans.
- Added privacy-first permission labels for budget, expenses, debts, task management, and financial record management.
- Kept Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Task + Timeline Screens

- Added Flutter Task + Timeline mobile screens under `mobile/lib/features/tasks/`.
- Wired Task and Timeline API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/tasks`, `/wedding-plans/:id/tasks/create`, and `/wedding-plans/:id/timeline`.
- Replaced the WeddingPlan Dashboard task/timeline placeholder with a real navigation card.
- Kept Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Debt + Installment Screens

- Added Flutter Debt + Installment mobile screens under `mobile/lib/features/debts/`.
- Wired Debt and Installment API clients to the existing frozen backend API contract without changing backend APIs.
- Added routes for `/wedding-plans/:id/debts`, `/wedding-plans/:id/debts/create`, `/debts/:debtId`, and `/debts/:debtId/installments/create`.
- Replaced the WeddingPlan Dashboard debt/installment placeholder with a real navigation card.
- Kept Task, Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Budget + Expense Screens

- Added Flutter Budget + Expense mobile screens under `mobile/lib/features/finance/`.
- Wired BudgetCategory and Expense API clients to the existing backend contract without changing backend APIs.
- Added finance routes for `/wedding-plans/:id/finance`, `/wedding-plans/:id/budget-categories/create`, and `/wedding-plans/:id/expenses/create`.
- Replaced the WeddingPlan Dashboard budget/expense placeholder with a real navigation card.
- Kept Debt, Installment, Task, Sharing, Marketplace, payment, AI/FinTech, chat, and confirmed booking mobile flows out of scope.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, Prisma models, migrations, Docker/Dokploy files, deployment scripts, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter WeddingPlan And Dashboard Foundation

- Added Flutter WeddingPlan model, API client, and Provider-based state under `mobile/lib/features/wedding_plans/`.
- Implemented My WeddingPlans, Create WeddingPlan, and WeddingPlan Dashboard screens using the frozen backend API contract.
- Added routes for `/wedding-plans`, `/wedding-plans/create`, and `/wedding-plans/:id/dashboard`.
- Updated Home to link clearly to WeddingPlan planning.
- Kept budget, expense, debt, installment, task, sharing, and timeline mobile screens as dashboard placeholders only.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, backend API contract, Prisma models, migrations, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Flutter Auth Foundation

- Created `mobile/` as the Flutter app foundation for Aarast / اعّرست.
- Added Arabic-first RTL app theme, routing, Dio API client, shared-preferences auth storage, and Provider-based auth state.
- Implemented Splash, Login, Register, and Home placeholder screens wired to the frozen backend Auth contract.
- Added `mobile/README.md` with run instructions, API base URL location, implemented scope, and exclusions.
- Verified `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --debug`.
- Confirmed backend code, backend API contract, Prisma models, migrations, WeddingPlan/dashboard/financial screens, Docker/Dokploy files, marketplace, payments, AI/FinTech, chat, and confirmed booking logic were not changed or created.

## 2026-06-04 - Backend Regression And API Contract Freeze

- Added `API_CONTRACT.md` as the frozen MVP backend API contract for Flutter integration.
- Added `backend/scripts/smoke/all-smoke.js` and `smoke:all` to run all backend MVP smoke scripts in sequence.
- Regression-verified health, auth, WeddingPlan, Budget + Expense, Debt + Installment, Task + Timeline, and Sharing / Permissions smoke coverage.
- Documented that backend MVP core API is ready for Flutter MVP integration after this phase is merged.
- Confirmed deployment/Docker/Dokploy, marketplace, payment, AI/FinTech, chat, confirmed booking, deposit, provider, vendor, and Flutter implementation are still not started in this phase.

## 2026-06-04 - Phase 3 Sharing / Permissions Backend Slice

- Added `SharedMemberRole` and `SharedMember` Prisma schema support with a real migration `20260603212938_add_shared_members_permissions`.
- Implemented protected Sharing endpoints for adding, listing, updating, removing shared members, and listing wedding plans shared with the current user.
- Added a generic permission service for plan ownership, shared plan readability, task management, and financial visibility checks.
- Integrated shared read access for WeddingPlan, task visibility and task management permissions, and permission-aware timeline financial visibility.
- Kept financial endpoints owner-only in this slice; financial privacy remains protected by default.
- Added `backend/scripts/smoke/sharing-smoke.js` and `smoke:sharing` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_shared_members_permissions`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, `npm run smoke:debt-installment`, `npm run smoke:task-timeline`, and `npm run smoke:sharing`.
- Confirmed no product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Sharing / Permissions slice were created.

## 2026-06-03 - Phase 3 Task + Timeline Backend Slice

- Added `WeddingTaskStatus`, `WeddingTaskPriority`, and `WeddingTask` Prisma schema support with a real migration `20260603205638_add_task_timeline_model`.
- Implemented protected Task endpoints under WeddingPlan ownership: create, list, update, and delete.
- Implemented protected Timeline endpoint under WeddingPlan ownership with wedding date, upcoming tasks, due debts, and due installments.
- Added `backend/scripts/smoke/task-timeline-smoke.js` and `smoke:task-timeline` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_task_timeline_model`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, `npm run smoke:debt-installment`, and `npm run smoke:task-timeline`.
- Documented that Sharing and Flutter/mobile work are not implemented yet.
- Confirmed no Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Task + Timeline slice were created.

## 2026-06-03 - Phase 3 Debt + Installment Backend Slice

- Added `DebtStatus`, `InstallmentStatus`, `Debt`, and `Installment` Prisma schema support with a real migration `20260602215807_add_debt_installment_models`.
- Implemented protected Debt endpoints under WeddingPlan ownership: create, list, summary, update, and delete.
- Implemented protected Installment endpoints under Debt/WeddingPlan ownership: create, list, due list, update, and delete.
- Added `backend/scripts/smoke/debt-installment-smoke.js` and `smoke:debt-installment` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npx prisma migrate dev --name add_debt_installment_models`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, `npm run smoke:budget-expense`, and `npm run smoke:debt-installment`.
- Documented that Tasks, Sharing, and Flutter/mobile work are not implemented yet.
- Confirmed no Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Debt + Installment slice were created.

## 2026-06-03 - Phase 3 Budget + Expense Backend Slice

- Added `ExpenseStatus`, `BudgetCategory`, and `Expense` Prisma schema support with a real migration `20260602211007_add_budget_expense_models`.
- Implemented protected BudgetCategory endpoints under WeddingPlan ownership: create, list, update, and delete.
- Implemented protected Expense endpoints under WeddingPlan ownership: create, list, summary, update, and delete.
- Added `backend/scripts/smoke/budget-expense-smoke.js` and `smoke:budget-expense` package script.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, `npm run smoke:wedding-plan`, and `npm run smoke:budget-expense`.
- Documented that Debts, Installments, Tasks, Sharing, and Flutter/mobile work are not implemented yet.
- Confirmed no Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside Budget + Expense slice were created.

## 2026-06-02 - Phase 3 WeddingPlan API Slice

- Implemented protected WeddingPlan API slice with `POST /wedding-plans`, `GET /wedding-plans/my`, `GET /wedding-plans/:id`, `PATCH /wedding-plans/:id`, and `PATCH /wedding-plans/:id/archive`.
- Added `WeddingPlansModule`, `WeddingPlansService`, `WeddingPlansController`, `CreateWeddingPlanDto`, and `UpdateWeddingPlanDto`.
- All WeddingPlan routes require JWT and use authenticated ownership context before returning or mutating plans.
- Added `backend/scripts/smoke/wedding-plan-smoke.js` and `smoke:wedding-plan` package script.
- Verified `npm install`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, `npm run smoke:auth`, and `npm run smoke:wedding-plan`.
- Confirmed `passwordHash` is not returned and no Budget, Expenses, Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, new Prisma models, new migrations, `prisma db push`, fake migrations, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside WeddingPlan API slice were created.

## 2026-06-02 - Phase 3 WeddingPlan Prisma Model

- Added `WeddingPlanStatus` enum and `WeddingPlan` Prisma model with the approved owner, title, city, wedding date, estimated budget, currency, status, and timestamp fields.
- Added `User.weddingPlans` relation and `WeddingPlan.owner` relation through `ownerUserId`.
- Created and applied real Prisma migration `20260602200934_add_wedding_plan_model`.
- Migration SQL creates only `WeddingPlanStatus`, `WeddingPlan`, and the foreign key to `User`.
- Verified `npm install`, `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, and `npm run smoke:auth`.
- Confirmed no WeddingPlan API/controller/service/module, Budget, Expenses, Debts, Installments, Tasks, Sharing, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, `prisma db push`, fake migrations, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 Ownership Context Foundation

- Added a generic authenticated-user shape and ownership context service for future private modules.
- Kept ownership checks generic: compare authenticated user id to resource `ownerUserId`; no WeddingPlan or private resource API was created.
- Updated auth context typing so `CurrentUser` and JWT validation use a safe authenticated-user shape.
- Extended `smoke:auth` to verify `/auth/me` preserves the authenticated user's id and role consistently; auth smoke now has 21 checks.
- Documented the ownerUserId access pattern in API/database planning and decisions.
- Verified `npm install`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit`, `GET /health`, `npm run smoke:health`, and `npm run smoke:auth`.
- Confirmed no WeddingPlan, product modules, Prisma models, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, refresh tokens, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic outside ownership/auth context were created.

## 2026-06-02 - Phase 3 Auth Foundation

- Implemented minimal Auth foundation: `AuthModule`, `AuthService`, `AuthController`, `JwtStrategy`, `JwtAuthGuard`, `CurrentUser` decorator, `RegisterDto`, `LoginDto`, and `SafeUser` mapper.
- Endpoints: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`.
- Registration accepts `name`, `phone`, optional `email`, and `password`; hashes password with bcryptjs; creates User with default `USER` role and `ACTIVE` status.
- Login is phone-first, validates password hash, rejects disabled users.
- `GET /auth/me` requires a valid JWT and returns safe current user.
- `passwordHash` is never returned in any API response — confirmed by 3 explicit smoke checks.
- Added `ValidationPipe` globally in `main.ts` for DTO validation.
- Updated `backend/.env.example` with `JWT_SECRET` placeholder.
- Added `scripts/smoke/auth-smoke.js` with 15 checks covering register, login, wrong-password rejection, unauthenticated /me, and authenticated /me.
- Added `smoke:auth` package script; updated `smoke` to run both `smoke:health` and `smoke:auth`.
- Dependencies added: `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcryptjs`, `class-validator`, `class-transformer`, `@types/passport-jwt`, `@types/bcryptjs`.
- `backend/.env` created locally (untracked, gitignored); `JWT_SECRET` not committed.
- No new Prisma migrations were created or needed; existing User model is sufficient.
- Verified: `npm install` PASS, `prisma:generate` PASS, `npm run check` PASS, `npm run build` PASS, `npm audit` 0 vulnerabilities, `GET /health` PASS, `npm run smoke:health` PASS, `npm run smoke:auth` 15/15 PASS.
- Confirmed no WeddingPlan, Budget, Expenses, Debts, Installments, Tasks, Sharing, Marketplace, AI, FinTech, Payments, Chat, refresh tokens, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic outside Auth foundation were created.

## 2026-06-02 - Phase 3 User Model Migration Created


- Created and applied real Prisma migration `20260602181910_init_user_model` for the User model.
- Migration scope: `UserRole` enum, `UserStatus` enum, `User` table only — no other tables.
- Database: `aarast_dev` (fresh database created in `aarast-db` Docker container on port `5433`).
- Prisma version: `6.19.3` (local install) — global Prisma 7.x was intentionally bypassed to preserve project versioning.
- `aarast` database preserved intact; `aarast_dev` created as a clean isolated dev database.
- `backend/.env` created locally (untracked, gitignored); not committed.
- Verified `prisma format`, `prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health` — all PASS.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Migration Attempt

- Attempted to create the real User model Prisma migration `init_user_model`.
- Confirmed no fake migration was created; `backend/prisma/migrations/` still does not exist.
- Migration is blocked because the local PostgreSQL/DATABASE_URL setup is not usable from this worktree.
- Verified `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Prisma Model

- Added `UserRole` and `UserStatus` enums and the minimal MVP `User` Prisma model.
- Kept the User model limited to approved identity fields with no relations, provider profile fields, refresh tokens, or WeddingPlan relation.
- Attempted local migration `init_user_model`; migration was blocked because `DATABASE_URL` is not configured in this worktree.
- Verified `npx prisma format`, `npx prisma validate`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Auth, Users API/module, WeddingPlan, product modules, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat/marketplace, confirmed booking logic, or business logic were created.

## 2026-06-02 - Phase 3 User Model Design Alignment

- Documented the minimal MVP User model shape: `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`.
- Clarified that phone is important for Yemen-first usage and `passwordHash` must store hashed passwords only, never plaintext passwords.
- Defined initial roles as `USER`, `ADMIN`, and `PROVIDER`, with `PROVIDER` reserved for later provider flows only.
- Defined initial statuses as `ACTIVE` and `DISABLED`.
- Confirmed this task is design-only; no Prisma models, migrations, Auth, backend modules, dependencies, tests, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 Prisma/PostgreSQL Foundation

- Added Prisma/PostgreSQL foundation with an empty Prisma schema, PostgreSQL datasource, Prisma client generation, and neutral NestJS Prisma infrastructure.
- Added placeholder-only `DATABASE_URL` documentation in `backend/.env.example`.
- Verified `npm install`, `npm run prisma:generate`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, `GET /health`, and `npm run smoke:health`.
- Confirmed no Prisma models, migrations, product modules, Auth/User/WeddingPlan logic, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 Persistence/Auth Readiness Planning

- Documented the approved readiness order: Prisma + PostgreSQL foundation, User model, Auth foundation, ownership context, then WeddingPlan module.
- Clarified that WeddingPlan ownership must not use a mock-auth shortcut.
- Clarified that production migrations and Docker/Dokploy deployment work are outside this planning task.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 3 WeddingPlan Design Alignment

- Clarified that WeddingPlan implementation depends on backend persistence and authenticated ownership readiness.
- Kept WeddingPlan as the first Wedding Financial OS domain module after prerequisites.
- Documented the first planned WeddingPlan slice and confirmed SharedMember, Budget, Expenses, Debts, Installments, and Tasks are later slices.
- Confirmed this entry is documentation-only; no code, dependencies, tests, migrations, backend modules, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were created.

## 2026-06-02 - Phase 2 Health Smoke Baseline

- Added a Node-based health smoke script for `GET /health`.
- Added backend `smoke` and `smoke:health` package scripts.
- Kept Phase 2 limited to the existing health endpoint; no product modules, tests, migrations, Flutter/mobile files, Docker/Dokploy files, deployment scripts, or business logic were added.

## 2026-06-02 - Phase 1 Backend Foundation

- Added the minimal NestJS backend foundation in `backend/` with a basic `GET /health` endpoint.
- Verified `npm install`, `npm run check`, `npm run build`, `npm audit` with 0 vulnerabilities, and `GET /health`.
- Committed the backend foundation as `b67246438c4537af91d5445d05507dc569a07885` on `phase/1-backend-foundation`.
- Confirmed no product modules, Flutter/mobile app, migrations, Docker/Dokploy files, deployment scripts, payment/FinTech/AI/chat logic, marketplace logic, or confirmed booking logic were created.

## 2026-06-01 - Docs Foundation

- Created/updated the root Markdown documentation foundation for Aarast / اعّرست, including `DEPLOYMENT_PLAN.md`.
- Documented Docker for local isolation and Dokploy for later VPS deployment; clarified these are planning-only in this phase and no Dockerfile, docker-compose, Dokploy config, or deployment scripts were created.
- Clarified the MVP is Wedding Financial OS first and marketplace second.
- Clarified early provider/service features are planning references and quote/lead flows only.
- Explicitly excluded payment processing, deposits, confirmed bookings, payment status, loans, credit, financing, FinTech, AI, and internal chat from the MVP unless later approved.
- Added private-by-default financial data rules for expenses, debts, installments, attachments, and private tasks.
- Added Attachment as a planning-level entity/API concept.
- Documented Git worktree as the intended workflow, with actual usage blocked until the correct Git repository root is confirmed.
- Strengthened `AGENTS.md` rules and approved-docs discipline.
- Confirmed no application code, tests, Git actions, dependencies, migrations, Docker files, Dokploy config, Flutter screens, backend modules, deployment scripts, or business logic were created.
