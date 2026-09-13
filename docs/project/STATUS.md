# Current Status

Snapshot date: 2026-09-13

This is the compact current-status source for Aarast. Source code, schema,
generated references, and observed checks override historical plans or
completion reports.

## Closeout Mission — Governance Closed, Product Audited — 2026-09-13

The 2026-09-13 closeout mission (recovery branch
`recovery/r12c-t5-takeover-20260913`, final verified commit `053166bd`)
closed the byte-lineage governance of R3–R8 and R12A–R12C into live
invariants, passed the architecture exit audit (0 open), completed the full
product forensic audit, remediated 26 engineering defects in their own
commits, and passed a clean-room verification of every surface from a fresh
clone (77/77 gates, tree clean). MODULAR MONOLITH MISSION: NOT CLOSED —
ownership 385/781 and R13–R20 remain. PROJECT READY FOR NEXT PRODUCT PHASE:
READY (engineering). Three product decisions are recorded (unreferenced
routes, FK indexes, desktop targets). Reviews were same-agent. No push,
merge, deployment, remote CI, provider delivery, or release is claimed. See
`docs/superpowers/reports/2026-09-13-modular-monolith-and-product-readiness-final-report.md`.

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

The Finance wedding-cost projection, the Messaging conversation-lifecycle
port, and the Marketplace provider-access policy each have one owner public
contract; their legacy paths are absent; the declared consumers (3, 5, 7) use
the public contracts. Dependency IDs `10`, `12-17`, `19-20` are retired, so
the ledger is `9 -> 0` and `depcruise --config .dependency-cruiser.cjs src`
reports 0 violations without any allowance; ownership remains byte-identical
at `385/781`.

Task 5 passed the combined 16-file architecture/security run `682/682`. Task 6
passed focused `133/133`, full Backend `1499` with `1498` passing, zero
failures and one declared Windows skip, aggregate smokes `30/30`, six phase-2
concurrency smokes, architecture/check/build/security at zero, and both
audits at zero. Governance gates now bind to repository identity and run from
any checkout; fixtures are isolated from the live dependency installation;
multer `2.3.0` and sharp `0.35.4` are the registered security prerequisite.
Reviews for Tasks 5-7 were performed by the implementing agent and are
recorded as such. Local completion does not authorize R13 or any external
action.

The byte-lineage governance is closed (spec section 19): the closure record
`backend/architecture/modular-monolith-closure.json` freezes the three
manifests by hash and names lineage commit `4bae5c6d`; R12A/R12B/R12C, R3 and
R5 now verify live invariants (`stage=strict (closed)`), the lineage gates
are re-run at the lineage commit by the governance-portability suite, and
governed files are ordinary reviewed code from here on. Nothing is baselined
or ignored by the closure.

The requirement traceability matrix
`docs/superpowers/reports/2026-09-13-modular-monolith-requirement-traceability-matrix.md`
traces the original target (now tracked at
`docs/superpowers/specs/2026-08-04-modular-monolith-architecture-design.md`)
to live proof: the import law, acyclicity, schema split, migrations, mobile
and admin boundaries and route contracts are closed; the ownership law
(385/781), the pure Finance domain, the erasure-port saga, port-based
insights/reminders and the Mobile fate-map remainder are open (R13–R20).
The modular-monolith mission is not closed.

## Modular Monolith R12B — Local Completion — 2026-09-06

R12B is complete locally.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation followed on 2026-09-13 (see above).
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.

The unchanged wedding-location implementation now has one Planning public
owner, its legacy path is absent, and the seven declared consumers use the
public contract. Onboarding owns two local nested DTOs with exact source and
validation parity. Only dependency IDs `7-9`, `11`, `18`, and `21-22` were
retired, so the ledger is `16 -> 9`; ownership remains byte-identical at
`385/781`.

Task 5 passed focused `54/54`, full Backend `1455/1456` with zero failures and
one declared Windows skip, affected smokes `9/9`, aggregate smokes `30/30`,
both audits at zero, and independent review at Critical/Important/Minor
`0/0/0`. The Task 6 candidate review approved activation; the four-receipt
documentation transition is complete and activated exact-state re-review is
the final close gate.

## Modular Monolith R12A Local Completion - 2026-09-02

R12A is complete locally on branch
`modular-monolith` from immutable entry
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. Four Backoffice
authority/mutation contracts and one Marketplace provider-rating helper now
exist only under owner `public/` locations; nine fixed consumers use them and
all five legacy paths are absent without facade, duplicate, or fallback.

Dependency records 1-6 were subtracted exactly: `22 -> 17 -> 16`, with no
addition or unrelated removal. One ownership path was projected without
semantic/count drift, so ownership remains `385/781`. R16 still owns the exact
Identity-to-Marketplace runtime-public helper handoff; R17 still owns the R1
Backoffice pure permission-contract pre-port handoff. The architecture target
is not complete.

Fresh verification passed behavior `31/31`, architecture `522/522`, cumulative
architecture/check/build, full Backend tests `1407/1408` with zero failures and
one pre-existing skip, five affected managed smokes, and all 30 aggregate smoke
packages. The security reader rejects exact and Unicode-escaped duplicate JSON
members before package projection; Task 5 independent re-review approved the
candidate with Critical `0`, Important `0`, Minor `0`.

Task 6 documentation, exact scope, immutable identity, and independent review
passed with Critical `0`, Important `0`, Minor `0`. No API/schema/migration/route/DTO/error/permission/
transaction/Arabic/Mobile/Admin Web/deployment behavior changed. No commit,
push, merge, deployment, production mutation, remote CI, provider delivery, or
release occurred. Do not start R12B; R12B design/planning still requires
separate owner approval.

## Modular Monolith R11 Target Reconciliation - 2026-09-01

R11 documentation reconciliation is locally complete on branch
`modular-monolith` from immutable local R10 closeout
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. The original target remains
binding; the R0-R10 wave is locally closed with declared gaps, not equivalent
to full architecture completion.

R11 is documentation-only. It records the exact live Backend debt at 22
dependency records and 385 ownership records / 781 occurrences, the immutable
record allocations, and the ordered R11-R20 completion program. R13-R17 own
the full non-overlapping ownership retirement; R14A Identity must exit before
R14B Collaboration begins so the invite OTP owner port exists first. R18 must
enter at 0/0 and may only prove strict zero and delete the zero-valued baseline.

The exact nine-Markdown scope fence, historical 178-path R10 fence,
architecture debt truth checks, documentation gates, and independent review
passed with no unresolved finding. R11 does not authorize R12 implementation.
Push, merge, deployment, production mutation, remote CI, provider delivery,
and release remain outside scope.

## Modular Monolith R10 Admin Local Completion - 2026-08-31

R10 Admin phase is locally complete on branch `modular-monolith` from immutable
R9 closeout `e560e5784278907dd6bf565327c3abfa0c9b8cab`. The reviewed design,
implementation plan, and final report are under `docs/superpowers/`.

Admin Web now has eight exact feature owners (`auth`, `dashboard`, `users`,
`providers`, `catalog`, `moderation`, `notifications`, and `audit`) plus
`platform`, `design_system`, retained composition roots, and test-only
contracts. The legacy `src/api`, `src/auth`, `src/components`, and `src/pages`
roots moved from `5/9/27/24` to `0/0/0/0` without a facade, alias, duplicate,
fallback, or hidden compatibility path. Routes, 62 request records, 1,020
Arabic literal records, auth/session/RBAC behavior, and all 96 pre-existing
tests are frozen by permanent scanners; total Admin coverage is 101 tests.

Final local verification passed: Admin boundaries 35/35 and strict zero,
101/101 tests, typecheck, 2,401-module build, honesty 12/12, routes 16/16,
container 3/3, zero audit findings, and managed runtime after 76 migrations;
Backend architecture/check/build, 1,351 pass / 0 fail / 1 intentional skip,
zero audits, security gate, Prisma 52-model/41-enum equivalence, 12 focused
smokes plus aggregate smoke; Mobile strict `legal=159`, analysis clean, and
1,164/1,164 tests; docs, protected surfaces, cleanup, and independent review
all passed. The managed runtime proved fresh SUPER_ADMIN and SUPPORT sessions,
allowed reads, structured `403`/`404` propagation, refresh, revocation, and
logout without retaining disposable database, Redis, media, or process state.

R10 is an internal Admin relocation, not completion of the whole architecture
target. Backend dependency debt remains exactly 22 records and physical
ownership debt remains 385 records / 781 occurrences. The R0-R10 execution wave
is locally closed with those declared gaps. The R10 report itself claimed no
commit; the owner subsequently authorized the local R10 closeout commit
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. No push, merge, PR mutation,
deployment, production mutation, remote CI, real WhatsApp delivery, or live
Firebase Push is claimed; release/store evidence remains governed separately.

## Modular Monolith R9 Local Completion - 2026-08-30

R9 is locally complete on branch `modular-monolith` from immutable base
`833a4f1d31781b45cd0a68ecee1b969ac85f237f` at application candidate
`0f61bf283b455c4404182f5028ab78d2448053d3`. The exact completion specification
and plan are under `docs/superpowers/`; the docs-only checkpoint is the commit
containing those receipts.

All 19 Mobile feature owners expose controlled public APIs. Cross-feature debt
is zero, root debt is zero, and the legal public projection is 159 records;
`app.dart`, `app_router.dart`, and `main.dart` remain the only approved
composition roots. `SafeUser` is canonical under `core/session`, and Push
binding consumes immutable nullable identity data without changing lifecycle
behavior.

C5 corrects one phone-discovered product defect at the earliest boundary. An
unimported guest plan belongs to the installation: ordinary explicit logout,
restore rejection, and confirmed session expiry preserve it. Confirmed account
deletion may clear it; successful migration and explicit double-confirmed
discard retain their existing deletion contracts.

Final local verification passed: Mobile governance 230/230; strict debt zero
with `legal=159`; SafeUser/Push 10/10; direct C5 18/18; expanded session 19/19;
Flutter analysis clean and 1164/1164 tests; Backend architecture/check/build,
1346 pass with zero failures and one intentional skip, and both audits at zero
vulnerabilities; Admin 18 files / 96 tests plus typecheck/build/honesty and 3/3
container checks; isolated current-R9 database migrations 76/76 and managed
Marketplace smoke 62/62. Independent Task 10/C5 review approved with zero
Critical, Important, or Minor findings.

The final full Flutter rerun emitted existing Windows/Linux desktop-plugin
metadata notices while still exiting successfully at 1164/1164. R9 accepts the
Android application only and does not claim Windows/Linux desktop packaging.

The owner-selected `SM-S938B` was the only phone used. The accepted debug APK
created a synthetic local plan, reached the migration gate without Upload or
Discard, then survived server session invalidation and two separate
force-stop/relaunch cycles with the same local Dashboard restored. Disposable
QA database/runtime and Redis state were cleaned. No device identifier, LAN
address, credential, OTP, token, raw UI/log/body, screenshot, or private value
is retained.

Live Firebase Push is `UNVERIFIED`. Bare Task 9 Prisma validation was
`BLOCKED — environment`, while isolated Task 10 migration/runtime proof passed.
The stale repository seed fixture remains adjacent debt and was not patched
outside scope. That R9 receipt was local-only and claimed no push, merge, PR
mutation, deployment, remote CI, store release, S10 work, or R10; the separately
approved R10 result is recorded above.

## Modular Monolith R8 Local Completion - 2026-08-28

R8 is locally complete on branch `modular-monolith` from immutable R7 closeout
`c2b728bfe54304562923facfb6094e0de04c0b27` at application candidate
`464d785a0440b8494768a26a70ac1de73a4bff2c`. The exact completion receipts are
the R8 completion specification and plan under `docs/superpowers/`.

The final two project-owned Nest globals are removed. `PrismaModule` and
`ConversationRealtimeModule` are ordinary modules; all 21 Prisma consumers and
both Realtime consumers import explicitly. `ApplicationOutboxRuntimeModule`
owns the one previously missing Prisma import. Real Nest contexts preserve the
singleton Prisma and Realtime providers and the exact Realtime `useExisting`
aliases. The dependency-owned Schedule 6.1.3 and Throttler 6.5.0 global
behaviors remain exact and frozen.

Final local verification passed: architecture at 348 modules / 1,406
dependencies, dependency 22, ownership 385/781, project globals 0, Prisma
21/21 with missing 0, Realtime 2, duplicates/`forwardRef()`/cycles 0; check;
build; focused R8 453/453; 1,345/1,346 Backend tests with zero failures and one
intentional Windows skip; Prisma 6.19.3 validate/generate, 52-model/41-enum
fingerprint, 76/76 migrations, and no-difference equivalence; both audits at
zero vulnerabilities; 12 focused smokes; all 30 aggregate smokes with real
Socket.IO; docs; protected surfaces; cleanup; and cleanliness. Independent
Task 3, Task 4, and Task 5 reviews found no Critical or Important issue.

Immutable image `aarast-backend:r8-candidate-464d785a`, image ID
`sha256:6fa367649ef2835b6b4b16efba088e9c26c38baa8ffbb9e3efeb74bd853153ad`,
passed the in-image audit, corrected isolated probe, protected local/LAN
cutover, database/Redis/media readiness, restart 0, OOM false, healthy exact
revision, sanitized fatal/exact-configured-key/value gates, and probe cleanup.
The initial probe stop was a verifier false positive caused by matching
ordinary lowercase password/token route metadata; exact key/value detection
proved zero disclosure before cutover. R7 remains stopped and preserved for
rollback.

The owner-authorized non-S10 phone 26 reached R8 through the installed accepted
R5Local package. Session, selected context, and dashboard restored; one
synthetic task was created/read/updated/deleted; one eligible existing
quote-scoped conversation sent/read one synthetic realtime message; and
force-stop/reopen restored session, context, dashboard, Tasks, and the cleaned
task state. S10 was not used. Server and phone fatal/connection markers were
zero. No device serial, phone, OTP, token, credential, provider/business data,
raw body, screenshot, or private business value was retained.

R8 is a local completion only. No push, merge, PR mutation, deployment, remote
CI, or R9 work is claimed. R9 requires a separate owner instruction and plan.

## Modular Monolith R7 Local Completion - 2026-08-24

R7 is locally complete on branch `modular-monolith` from immutable R6 closeout
`31ea5324007fc71fa4b3590fbb98a454ee1deaa7` at application candidate
`aafb47ea1742c278f6a5ed24799ada7bc23721b0`. The exact completion receipts are
the R7 completion specification and plan under `docs/superpowers/`.

All 18 approved files moved one-to-one into the existing Collaboration
API/internal/public boundary. The old `sharing` and `contribution-history`
roots are absent without facades. The public snapshot builder keeps its four
runtime exports, optional realtime injection remains unchanged, dependency
evidence is 22 records after retiring the nine approved debts, and physical
ownership remains 385 records / 781 occurrences.

Final local verification passed: architecture at 348 modules / 1405
dependencies, strict R7 source 0/target 18/dependency 22/ownership 385/781,
zero `forwardRef()`, two approved globals, zero cycles or illegal edges; check;
build; R7 210/210; 1242/1243 Backend tests with zero failures and one
intentional Windows skip; Prisma 6.19.3 validate/generate, 52-model/41-enum
fingerprint, and no-difference equivalence; both audits at zero vulnerabilities;
11 focused smokes; all 30 aggregate smokes; docs; protected surfaces; and
cleanliness. The cumulative independent review approved the exact candidate
with no Critical, Important, or Minor finding.

Immutable image `aarast-backend:r7-candidate-aafb47ea`, image ID
`sha256:55a5311048d57ffded953f18dedcf3e8fdcb4da8b3171e8c56ecededa0d3e0ae`,
passed in-image audit, isolated probe, protected local/LAN cutover, database/
Redis/media readiness, restart 0, OOM false, and sanitized logs. OpenWA is
disabled. R6 remains stopped and preserved for rollback.

The authenticated phone journey reached R7 and passed session/context/dashboard
restore, sharing reads, one synthetic invitation create 201, cooldown/reissue
201, members/invitations/permissions reads 200, cancellation 200, post-cancel
absence, and force-close/reopen restore. No real delivery occurred or was
claimed. No device identifier, phone, token, OTP, credential, raw body,
screenshot, or business value was retained.

R7 is a local completion only. No push, merge, PR mutation, deployment, remote
CI, or R8 work is claimed. R8 requires a separate owner instruction and plan.

## Modular Monolith R6 Local Completion - 2026-08-23

R6 is locally complete on branch `modular-monolith` from immutable completed-R5
base `ce0c0d19824bff79d91417e2fe4617914c6bcd70` at application candidate
`cefe07a76b0e615d4fecbb666514d9a2b87a7d37`. The tracked docs-only receipt is
the commit containing this status; its SHA is recorded externally after commit
because a commit cannot truthfully contain its own final hash.

Identity now owns one provider-neutral transient-delivery public Symbol, input,
interface, and uncertain/rejected errors. Its sole private adapter calls the
unchanged platform OpenWA sender once and maps only the two known concrete
errors. Collaboration consumes only the Identity public module and port. The R3
inventory is reconciled exactly and R6 is strict with zero concrete protected
imports. Invitation text, condition order, statuses, persistence, metrics,
privacy-safe logs, unknown-error identity, timeouts, retries, OTP behavior,
routes, schema, migrations, Mobile, Admin, workflows, Compose, and deployment
remain frozen.

Final local verification passed: architecture at 348 modules, 1405
dependencies, 31 known dependency records, ownership 385 records, zero
`forwardRef()`, two approved globals, zero cycles/illegal edges, all 13 R3
contexts, strict R5 and strict R6; check; build; 1021/1022 Backend tests with
one intentional Windows permission skip; Prisma 6.19.3 validate/generate and
equivalence; both npm audits with zero vulnerabilities; all 30 managed smoke
packages; documentation; protected surfaces; whitespace; and residue checks.
The final verification-only correction aligned stale R1/R3/Prisma receipts and
moved temporary test fixtures under the ignored test-fixture root, removing a
full-suite untracked-file race without changing product behavior or the lock.

Immutable image
`aarast-backend:r6-candidate-cefe07a76b0e615d4fecbb666514d9a2b87a7d37`,
image ID
`sha256:ebaf53768a855f31c101147bed06ce7a9648efea798abd2e7d11584c2084afb5`,
passed isolated probe and protected cutover. Local/LAN `/live` and `/ready`
returned 200; database, Redis, and media were up; restart count was zero, OOM
was false, and sanitized fatal/secret markers were zero. OpenWA was disabled.
The R5 image/container remain stopped and preserved for rollback.

The authenticated phone journey reached the R6 LAN endpoint and passed session
restore, sharing reads, invitation create 201, invitation reissue 201, related
reads, force-close/reopen, dashboard restore, and persistent sharing state. The
UI truthfully reported that provider delivery was unavailable; no real WhatsApp
delivery or real-recipient OpenWA smoke is claimed. No credential, token, phone
number, OTP, invitation token, raw body, or business value was retained.

R6 is a local completion only. No push, merge, PR mutation, deployment, or
remote CI is claimed. External Meta/OpenWA production activation is outside
this architecture phase. At R6 closeout, R7 was approved but not started; the
R7 section above records its later local completion.

## Modular Monolith R5 Local Completion - 2026-08-22

R5 is locally complete on branch `modular-monolith` from immutable base
`9dab73acdc187a4a18d8a675713d8ded40a16d02` at application candidate
`8cfee451a76bb17e20d278a1646dde4387bf7b18`. The tracked docs-only receipt is
the commit containing this status; its SHA is recorded externally after commit
because a commit cannot truthfully contain its own final hash.

All 44 Identity files moved one-to-one from `auth`, `users`, `me`, and
`contexts` into the existing `modules/identity` public/internal/api boundary.
The four legacy roots are absent with no compatibility facade. The dependency
baseline contains exactly 31 records after the 58 authorized relocation debts
were retired; ownership remains 385 records / 781 occurrences. Routes,
controller/provider identity, Arabic/error behavior, auth/OTP/session/context
contracts, schema, migrations, model ownership, Mobile, Admin, workflows,
Compose, and deployment remain frozen.

The independent Task 6 review found that three smoke setup/order corrections
were not authorized by the original path-only test policy. Immutable-base
source evidence proved that each restores a production precondition already
required at R5 base. The owner authorized one narrow, hash-pinned exception;
permanent tests and the live scanner now reject any other fixture/setup drift.
No behavioral assertion was deleted, skipped, or weakened.

Final local verification passed: R5 relocation 16/16; architecture at 344
modules, 1395 dependencies, 31 known records, ownership 385, zero
`forwardRef()`, two approved globals, zero cycles/illegal edges; check; build;
1006/1007 Backend tests with one intentional Windows permission skip; Prisma
6.19.3 validate/generate and exact DMMF/migration equivalence; both npm audits
with zero findings; nine targeted managed smokes; all 30 `smoke:all` packages;
docs; protected surfaces; and zero managed residue.

Immutable image `aarast-backend:r5-final-8cfee451`, image ID
`sha256:36843e956ed236926e7391b3928002e7188cb4617e496fed84b860db94547f8a`,
is bound to the full application candidate revision. Probe and cutover passed
76-migration discovery, local/LAN `/live` and `/ready`, DB/Redis/media checks,
zero restarts, no OOM, and sanitized fatal-marker checks. R4 remains stopped
and preserved for rollback.

The separately packaged R5Local APK targeted the verified LAN endpoint. The
owner passed authenticated login, Home/context restore, representative reads
and writes, and full close/reopen. Sanitized R5 logs contained 237 HTTP events:
236 successful responses, zero HTTP 5xx, five successful logins, and one
controlled unauthenticated `/api/v1/auth/me` 401 probe. No credential, token, body,
phone number, or business value was retained. One empty OS-temp audit directory
remains outside the repository because deletion was denied; it contains zero
files and is not a product artifact.

R5 is a local completion only. No push, merge, PR mutation, deployment, or
remote CI is claimed. Its docs-only closeout commit is the immutable base for
the separately approved R6 planning section above.

## Modular Monolith R5 Task 5A Local Security Checkpoint - 2026-08-21

R5 Task 5A is locally complete on branch `modular-monolith`. The checkpoint
keeps Prisma, Prisma Client, and Prisma Config pinned at 6.19.3 and resolves the
transitive `deepmerge-ts` security finding CVE-2026-40345 with an exact root
override to patched 8.0.1. A Prisma 7 major upgrade, downgrade, audit
suppression, and `npm audit fix --force` were rejected because none is a
smaller verified correction for the active R5 candidate. The override may be
removed only after the pinned Prisma line resolves a non-affected merge package
without it and the same security, semantic, audit, build, smoke, and runtime
gates pass.

The permanent checker proves the canonical package/lock fingerprints, exact
installed resolution through `@prisma/config`, one patched package root,
recursive and ordinary Prisma-config merge behavior, complete input and
primordial immutability, safe plain-data output, and an authenticated isolated
worker completion. The R5 phase scanner also requires the exact 11-path
security-checkpoint activation and rejects lock-only activation, unrelated
dependencies, ranged overrides, Prisma version drift, and extra implementation
paths. Independent adversarial review passed with no Critical, Important, or
Minor findings.

The final uncommitted application candidate before its authorized local
checkpoint contained 24 reviewed paths with sorted `path|SHA-256` aggregate
`d07b7907667181ca24cec80b1de6b77f56cea74d7be6f0108bb7212e5fdd12a6`.
Security/R5 focused tests passed 30/30; full Backend tests passed 1005/1006
with one intentional Windows permission skip; architecture passed at 344
modules, 1395 dependencies, 31 known records, ownership 385, zero
`forwardRef()`, two approved globals, and zero cycles or illegal edges. Check,
build, both zero-finding audits, nine targeted managed smokes, all 30 aggregate
smoke packages, docs, and protected-surface gates passed. Managed residue was
zero.

Prisma validate/generate passed with 14 schema files, 52 models, 41 enums, and
76 migrations. The DMMF and migration SQL remained byte-identical with
SHA-256 `0511990aa3a32e92ecb15837699aceb8b41b9c8faa736103c926fda3db034d3f`
and `0b6e9f853f6fc5a4b9fbdd3e2cafbf78d74f9d88f3242f1f208616519eef5248`.
The final isolated image was
`aarast-backend:r5-prisma-security-d07b7907667181ca24cec80b1de6b77f56cea74d7be6f0108bb7212e5fdd12a6`,
image ID
`sha256:dd2a2be20e9843a388aa3990edeab966b5f769503a4e352ba25c3f60e1fd97a9`.
It passed dependency identity, security, migration discovery, `/live`,
`/ready`, restart/OOM, and sanitized startup checks; the probe was removed.
The existing phone runtime was not cut over and remained healthy. No phone QA
was requested because application behavior did not change.

This was the local security checkpoint inside the now-completed R5 phase. No
push, merge, PR mutation, deployment, remote CI, or R6 work is claimed.

## Modular Monolith R5 Planning Approved - 2026-08-20

R5 planning is approved on branch `modular-monolith` from immutable local R4
receipt `9dab73acdc187a4a18d8a675713d8ded40a16d02`. The worktree was clean at the
planning preflight. The live Identity source contains 44 TypeScript files in
four legacy roots: 31 under `auth`, 8 under `users`, 1 under `me`, and 4 under
`contexts`.

The approved design moves those files one-to-one into the existing
`modules/identity` public/internal/api boundary, deletes all four old roots, and
reconciles path-indexed dependency and ownership evidence without changing
routes, auth/OTP/session behavior, schema, migrations, model ownership
semantics, Mobile, Admin, workflows, deployment, or Compose. Local checkpoint
commits are allowed; no branch/worktree creation, push, merge, PR mutation,
deployment, remote-CI claim, or R6 work is authorized. Task 5A has since
completed locally as recorded above; the remaining R5 work later passed the
gates and closeout recorded in the current completion section.

## Repository Baseline

- Repository root: `D:\projects\aarast`.
- Canonical integration branch: `main`. Release-candidate changes are promoted
  through reviewed Git history only after the required CI jobs pass.
- Resolve the exact checked-out revision with `git rev-parse HEAD`. Deployed
  images and release artifacts must carry that immutable revision; this tracked
  document intentionally avoids a self-referential mutable HEAD claim.
- The pre-modernization state remains recoverable from the verified local Git
  bundle `_ai_backups/aarast-before-modernization-20260807.bundle`. The former
  snapshot branch has been removed during the explicit branch cleanup and is
  not a release candidate.
- No stash exists. One Codex-managed detached worktree remains untouched because
  deleting worktrees or ignored backups was not part of the authorized cleanup.

## Modular Monolith R4 Local Completion - 2026-08-16

R4 executed locally on branch `modular-monolith` from immutable `R4_BASE`
`502b181a2ce624458fd7eae064f194497ec0151e`. The reviewed application candidate
is `536890ccafcabebcd4d095a33c014933d6451fdb` with exactly 22 R4 application,
architecture, test, plan, and generated-script paths.

Finance no longer touches the Planning-owned `WeddingPlan` delegate. The sole
`MoneyBudgetService` consumer calls `PLANNING_BUDGET_WRITE_PORT` inside its
existing serializable transaction, passing the exact transaction object and
unchanged `weddingPlanId`, estimated budget, and currency to the sole
`WeddingPlanBudgetWriter`. The public and implementation aliases use
`useExisting`; there is no duplicate registration, compatibility facade, new
transaction, retry, catch, or error translation.

The ownership baseline is exactly the R4-base baseline minus the frozen
`backend/src/money/money-budget.service.ts|finance|planning|WeddingPlan|update|write|delegate|foreign-model`
record: 385 records / 781 occurrences instead of 386 / 782. No other ownership
record changed. Architecture passed at 344 modules, 1395 dependencies, 89 known
dependency records, ownership 385, zero `forwardRef()`, two approved globals,
and zero cycles or illegal context edges. Check, build, Prisma validation,
968/969 tests with one intentional Windows permission skip, both zero-finding
npm audits, affected money/health smokes, and all 30 aggregate smoke packages
passed. Managed residue was zero. Schema and migrations remain 14 files / 52
models / 41 enums / 76 migrations; API, Mobile, Admin, CI, Compose, and
deployment surfaces are unchanged.

Immutable image `aarast-backend:r4-final-536890cc` has image ID
`sha256:16ef05de0308b71ba9d08c873eb0d74661385901a49589e130478db7c08d025d`
and exact OCI revision `536890ccafcabebcd4d095a33c014933d6451fdb`. Its
probe and cutover passed; local and assigned-LAN `/live` and `/ready` returned
HTTP 200, restart count remained zero, OOM was false, all 76 migrations and the
native schema folder were discovered, and the safe fatal/unhandled/TypeError/
Prisma-schema scan was empty. The accepted R3 container/image are stopped and
preserved for rollback.

The unchanged installed APK is package `com.aarast.aarast_mobile.r3local`,
version code 8, SHA-256
`05be807966bd762e5628d35034197cf80c09298d21e97dc2f490a91f9cd4514a`.
The owner passed login, Home, Money budget and category replacement, reload,
and force-close/reopen with the session and saved values preserved. Sanitized
R4 route-template evidence included login HTTP 200, `/api/v1/auth/me` HTTP 200,
three money-budget PUT HTTP 200 responses, repeated money-summary GET HTTP 200
responses, zero matched HTTP 5xx, and zero server fatal markers. No OTP,
credential, token, phone number, financial value, raw body, or raw log is
retained.

Independent source, ownership, runtime, and phone-evidence review passed with
no Critical, Important, or Minor findings. R4 is locally complete. No push,
merge, PR mutation, deployment, or remote CI is claimed. It is the immutable
base for the approved R5 plan above.

## Modular Monolith R3 Local Completion - 2026-08-16

The strict R3 Nest-boundary implementation is committed locally on branch
`modular-monolith` at implementation checkpoint
`0cbf5922c3d82e196722569e224754a1dd97dae5`, from immutable `R3_BASE`
`6b06eb096aca8cc6684d365d16e05d4cd8529898`. The physical phone gate later
reproduced one pre-existing Mobile session-restore race; its exact reviewed
correction is committed at `ad99687d00b94929b378bee1605b4d7ed82e8474`, and
the immutable corrected runtime receipt is bound to candidate
`dfc5488cf30d4eb36dc2d72c618b2442f34ea058`. The fixed-base scope verifier now
reports exactly 214 reviewed cumulative paths and zero unexpected paths.

The committed architecture state is strict and internally closed: 13 business
contexts, 340 scanned modules, 1383 dependency edges, 89 known dependency
records, 386 ownership records, zero remaining duplicate registrations out of
the initial 3, zero remaining platform debts out of 6, zero remaining retired
provider edges out of 163, zero `forwardRef`, exactly two globals, zero Nest
module cycles, and zero illegal boundary edges. All superseded Nest metadata is
retired; the one approved realtime global leaf remains byte-identical.

The full local pre-runtime gates passed. Backend architecture, check, build,
Prisma validation, 953/954 tests with one intentional Windows permission skip,
both zero-finding npm audits, and all 30 managed smoke packages passed. Admin
typecheck, 96/96 tests, build, 12 honesty checks, 16 route checks, and 3
container-config checks passed. Mobile boundary tests passed 192/192 with the
269-record baseline; Flutter analysis reported no issues and all 1151 tests
passed before the phone gate. After the exact session correction, the focused
network and account/context isolation tests passed, Flutter analysis reported no
issues, and the complete non-Golden suite passed 1102/1102; visual Goldens were
not rerun because no UI source changed. The existing Windows/Linux default-plugin warnings for
`shared_preferences`, `image_picker`, `path_provider`, and
`flutter_secure_storage` were observed and did not fail the gates.

Schema semantics remain frozen at 14 files, 52 models, 41 enums, and 76
migrations. Base and candidate DMMF are byte-equal with SHA-256
`1c0ddfb1108c4218dd4f8615f5afe7a0971dd72e92feaf2d1414228e6d605eee`;
Prisma migrate diff returned `No difference detected`. The final dependency
baseline SHA-256 is
`ebf61ce931e2dafff29a5f1bd7fba338f9993a15bd1d93c862453c0f89a85ac6`,
and the ownership baseline remains byte-identical at
`a4d478f45c5bfa76123be60e1cc77f99001969951afc219478916c87638ff3e6`.
Protected schema, migrations, seed, Admin, deployment, workflow, and lock-file
surfaces have zero R3-base drift. Mobile differs only in
`mobile/lib/core/network/api_client.dart` and its focused regression: account
session and selected-context generations are now independent, so context
bootstrap cannot discard a successful session-restore response while stale
account and stale-context requests remain rejected. Documentation sync and
verification report zero drift, errors, and warnings; managed test residue is
zero.

The Task 9 scope gate was corrected before the immutable runtime build to admit
only the seven active Markdown receipt/navigation files named by the approved
plan plus the exact two-file Mobile runtime correction. Its permanent
RED-to-GREEN regression passes 15/15, the manifest and scanner allowlists remain
byte/order-exact, and the final fixed-base scope is 214 reviewed paths with zero
unexpected paths.

The earlier immutable R3 runtime reached port 3120 healthy with restart count
zero, and the owner passed login, dashboard, core read/write, notifications, and
messaging. Force-stop/relaunch then reproduced the blocker: Backend returned
HTTP 200 from `/api/v1/auth/me`, but a concurrent account-context selection
advanced the shared client generation, the Mobile interceptor rejected that
successful response, and session teardown returned the app to the unauthenticated
welcome flow. The focused test reproduced this failure before production code
changed and passes after the network-boundary correction.

The corrected immutable image `aarast-backend:r3-final-dfc5488c` has image ID
`sha256:1f12732ff5dd6ce201f5a9fedf20f6f1ae91ce8f1baac4fa3c9e3feaee469013`
and exact OCI revision `dfc5488cf30d4eb36dc2d72c618b2442f34ea058`. Its
protected probe and cutover passed; localhost and assigned-LAN `/live` and
`/ready` returned HTTP 200, restart count remained zero, OOM was false, and the
safe fatal/unhandled/circular/TypeError/Prisma-not-found scan returned zero. The
previous R3 runtime is stopped and preserved as
`aarast-backend-r3-rollback-5c76970b`; the accepted R2 container and image also
remain stopped and preserved.

The corrected APK is package `com.aarast.aarast_mobile.r3local`, version code 8,
with SHA-256
`05be807966bd762e5628d35034197cf80c09298d21e97dc2f490a91f9cd4514a`.
It was installed with data preservation. The owner logged in and reached the
dashboard; an independent ADB force-stop/relaunch then returned to the
authenticated dashboard. Sanitized evidence was exactly one
`SESSION_RESTORED`, zero `SESSION_RESTORE_FAILED`, zero teardown/logout events,
one HTTP-200 `/api/v1/auth/me`, zero `/api/v1/auth/logout`, and zero server fatal
markers. No credential, OTP, token, phone number, raw body, or raw log is
retained. R3 is locally complete and provided the immutable base for R4. No R3
push, merge, PR, deployment, or remote CI run is claimed.

## Modular Monolith R2 Local Closure Candidate - 2026-08-14

R2 implementation is committed locally on branch `modular-monolith` from
immutable `R2_BASE`
`8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`. The reviewed implementation
checkpoints are `9e3e51b54c85e7e6c52da7340c0b678ecf13203e` and
`186e76d671a07eef835a1f4a7459c843e4ca1d99`. The native schema folder contains
exactly `_base.prisma` plus 13 owner files, with 52 models, 41 enums, and all
76 committed migration directories preserved. The retired single schema file
is absent.

The complete local pre-runtime gates passed against the committed candidate:
the R2 fixed-base scope audit reported the reviewed 49 paths; Backend
architecture, check, build, 848/849 tests with one expected Windows permission
skip, Prisma folder validation/generation, both migration rehearsals, all 30
managed smoke packages, and both zero-finding Backend dependency audits passed.
Admin typecheck, 96/96 tests, build, honesty, routes, and container-config
contracts passed. Mobile boundary tests, the 269-record baseline, analysis,
and 1151/1151 tests passed. Documentation sync/verification and whitespace
checks passed with zero drift, errors, or warnings. Managed smoke cleanup left
no matching database process, listener, Redis, bucket, container, network,
volume, or temporary resource.

Schema semantics remain unchanged: migrations and seed are byte-identical to
the base; normalized DMMF and migrate diff remain equal/empty; dependency and
ownership baselines remain 260 and 386 records / 782 occurrences; ports remain
`0/2/0/0`; generated API, Mobile routes, Admin routes, scripts inventory, and
database model table remain byte-identical. The sole generated-source wording
change is the reviewed database source path from the retired file to
`backend/prisma/schema/`.

The production-shaped image is
`aarast-backend:r2-final-b40e2961`, image ID
`sha256:fcbf41b7ede0c656d7b57bd4ea0fc64b2d960c44acbb1a1a7e8d13e8727ca865`,
and its OCI revision is the immutable 40-character runtime-candidate commit
`b40e2961c4c2e0c1e48ebdf1b4eff8444bc1d63f`. Image inspection proved
`/app/prisma.config.ts`, the exact 14-file schema folder, the absence of the
retired single file, and successful Prisma discovery. The protected probe and
cutover passed. `aarast-backend-r2-phone` remains running on
`aarast_default`, host port 3120, with restart count zero; localhost and the
owner-confirmed LAN address returned HTTP 200 from `/live` and `/ready` with
database, Redis, and media healthy. The stopped
`aarast-backend-r1-phone` container and its R1 image remain available for
rollback.

The owner phone checkpoint passed after one corrected client build. The first
attempt used a previously installed R1-local APK whose embedded API URL was
`127.0.0.1:3115`; it produced no R2 HTTP request and therefore was a client
configuration failure, not an R2 Backend failure. The corrected debug APK used
the separate package `com.aarast.aarast_mobile.r2local`, targeted the verified
LAN R2 URL, and had SHA256
`f5389e372674c045ab8b48862e4f03847ba21f0ed651ed48afde67495b0eeecb`.
It was installed and opened on device `R5CY31TM4PW`; device TCP reachability
passed and the owner explicitly reported PASS. The build's generated desktop
registrant side effects were restored, so no Mobile code or tracked generated
file changed.

The post-checkpoint log audit retained only sanitized method, templated path,
status, and count data. It parsed 43 safe HTTP events, of which 42 succeeded,
including two successful login events and 21 authenticated successes. Observed
successful flows included login, registration completion, active-plan/home
summary reads, provider/profile reads, guest creation and update, conversation
listing, and logout. No credential, token, phone number, environment value, or
raw response body was recorded. There was no Prisma-schema-discovery, fatal,
unhandled, circular-serialization, or `TypeError` match.

| Sanitized method and templated path | Status | Count |
| --- | ---: | ---: |
| `GET /api/v1/cities` | 200 | 3 |
| `GET /api/v1/contexts` | 200 | 3 |
| `GET /api/v1/conversations` | 200 | 1 |
| `GET /api/v1/provider-categories` | 200 | 3 |
| `GET /api/v1/provider/me/packages` | 200 | 1 |
| `GET /api/v1/provider/me/profile` | 200 | 3 |
| `GET /api/v1/provider/me/quote-requests` | 200 | 1 |
| `GET /api/v1/provider/me/reviews` | 200 | 1 |
| `GET /api/v1/provider/me/services` | 200 | 1 |
| `GET /api/v1/provider/me/summary` | 200 | 1 |
| `GET /api/v1/wedding-plans/:planId/dashboard-summary` | 200 | 4 |
| `GET /api/v1/wedding-plans/:weddingPlanId/guest-groups` | 200 | 1 |
| `GET /api/v1/wedding-plans/:weddingPlanId/guests` | 200 | 1 |
| `GET /api/v1/wedding-plans/:weddingPlanId/guests/summary` | 200 | 1 |
| `GET /api/v1/wedding-plans/:weddingPlanId/invites` | 200 | 2 |
| `GET /api/v1/wedding-plans/:weddingPlanId/members` | 200 | 2 |
| `GET /api/v1/wedding-plans/:weddingPlanId/tasks` | 200 | 1 |
| `GET /api/v1/wedding-plans/:weddingPlanId/tasks/summary` | 200 | 1 |
| `GET /api/v1/wedding-plans/:weddingPlanId/timeline` | 200 | 1 |
| `GET /api/v1/wedding-plans/active` | 200 | 1 |
| `PATCH /api/v1/guests/:id` | 200 | 1 |
| `POST /api/v1/auth/login` | 200 | 2 |
| `POST /api/v1/auth/logout` | 200 | 2 |
| `POST /api/v1/auth/register` | 201 | 1 |
| `POST /api/v1/auth/register/complete` | 201 | 1 |
| `POST /api/v1/provider/apply` | 201 | 1 |
| `POST /api/v1/wedding-plans/:weddingPlanId/guests` | 201 | 1 |

The table contains all 42 successful events in the sanitized set. Conversation
listing supplies endpoint-level messaging evidence. No successful notification
path appeared in this retained event set, so no endpoint-specific notification
claim is made beyond the owner's explicit overall phone PASS.

### Exact R2 candidate manifest

The fixed-base candidate diff contains exactly the following 49 paths from
`R2_BASE` to the immutable runtime candidate:

```text
ARCHITECTURE.md
backend/Dockerfile
backend/architecture/prisma-schema-layout.json
backend/prisma.config.ts
backend/prisma/schema.prisma
backend/prisma/schema/_base.prisma
backend/prisma/schema/backoffice.prisma
backend/prisma/schema/catalog.prisma
backend/prisma/schema/collaboration.prisma
backend/prisma/schema/finance.prisma
backend/prisma/schema/guests.prisma
backend/prisma/schema/identity.prisma
backend/prisma/schema/marketplace.prisma
backend/prisma/schema/media.prisma
backend/prisma/schema/messaging.prisma
backend/prisma/schema/notifications.prisma
backend/prisma/schema/planning.prisma
backend/prisma/schema/platform.prisma
backend/prisma/schema/tasks.prisma
backend/scripts/architecture/ownership-scan.cjs
backend/scripts/prisma/dmmf-fingerprint.cjs
backend/scripts/prisma/r2-schema-scope.cjs
backend/scripts/prisma/schema-files.cjs
backend/scripts/smoke/contributor-history-migration-smoke.js
backend/test/admin-auth-session-security.test.ts
backend/test/admin-rbac-audit.test.ts
backend/test/architecture-ownership.test.ts
backend/test/architecture-r2-schema-layout.test.ts
backend/test/auth-refresh-wiring.test.ts
backend/test/contribution-history-migration.test.ts
backend/test/financial-ledger.test.ts
backend/test/legacy-finance-removal.test.ts
backend/test/marketplace-presenter.test.ts
backend/test/outbox-logic.test.ts
backend/test/prisma-dmmf-fingerprint.test.ts
backend/test/prisma-r2-manifest.test.ts
backend/test/prisma-r2-schema-scope.test.ts
backend/test/prisma-schema-files.test.ts
backend/test/provider-chat-logic.test.ts
backend/test/reference-catalogs.test.ts
backend/test/support/live-prisma-schema.ts
docs/README.md
docs/backend/DATABASE.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/superpowers/plans/2026-08-13-modular-monolith-r2-prisma-schema.md
docs/superpowers/specs/2026-08-13-modular-monolith-r2-prisma-schema-design.md
scripts/docs-sync.mjs
```

The final docs-only closure extends that immutable runtime-candidate manifest
with exactly `CHANGELOG.md` and `docs/qa/README.md`. The complete final R2
fixed-base path set is therefore 51 paths; the other eight receipt files were
already present in the 49-path candidate manifest. No code, schema, migration,
package, Mobile/Admin, workflow, Compose, or deployment path is added by the
closure receipt.

### R2 equivalence and gate receipt

| Evidence | Result |
| --- | --- |
| Physical schema | PASS: 14 files, 52 models, 41 enums, and 76 migration directories; retired single file absent |
| Migration and seed freeze | PASS: all 77 migration-root files byte-identical; recursive migration SHA256 `2415eeab05047cf79cc7e11b00703f7bd6b976d344abcd08222bb86b060aa959`; seed SHA256 `67be9b62405f8d02d66da76aafbbe0fc097cb5e9defe4f61a657818d91778643` |
| Semantic equivalence | PASS: normalized DMMF SHA256 `1c0ddfb1108c4218dd4f8615f5afe7a0971dd72e92feaf2d1414228e6d605eee`; empty migrate diff; schema-block aggregate `cd0dd24dcf0345c26ca7226b999aaa673e5c4eddd40f4439bfecb02f8f5c590c`; normalized comment aggregate `f596d1dabd2d4050f1a97cd0843c055d72d43ecc157a6bf68c64014ff9908932` |
| Architecture baselines | PASS: dependency 260, SHA256 `76f6d069c27172dc2c8756c04d2282806650d9eeb062043353860b61a1454000`; ownership 386 records/782 occurrences, SHA256 `a4d478f45c5bfa76123be60e1cc77f99001969951afc219478916c87638ff3e6`; ports `0/2/0/0` |
| Generated truth | PASS: API `23c1d99ff80d6e458dfdea8e83cd87efe80fec18f57b7c8af8e8bf17c0391ee3`; Mobile routes `6de036d60b194c26a5a4e1c8abbca5763cc7b081bf0a75bdd0243fb1ae25bfff`; Admin routes `a1e3ee774bafca860ee0e95461b9e2384c719fcc6c1fb1eb01d6b4b945672e5e`; scripts `2f15a46ef20b20d6e3f83a112bfdb07871dd8b06aa7b796c0ee1e93c09d8bf47`; database model-table `70d35ff8718ed688f5c52c4d509b153362ff45af40d9a753219b47f740cf70d5` |
| Backend and Prisma | PASS: `npm run architecture`, `npm run check`, `npm run build`, 848/849 tests with one expected Windows permission skip, process-scoped Prisma validate/generate, contributor and guest migration rehearsals, all 30 `smoke:all` packages, and both zero-finding npm audits |
| Admin Web | PASS: typecheck, 96/96 tests, build, 12 honesty checks, 16 route checks, and 3 container-config tests |
| Mobile | PASS: 192 boundary tests, 269-record baseline, analyzer with no issues, and 1151/1151 tests |
| Docs and scope | PASS: R2 scope reported 49 reviewed runtime-candidate paths and 51 final receipt paths; docs sync drift 0; docs verify errors/warnings 0; whitespace check clean |
| Immutable runtime | PASS: image/revision/schema discovery, probe, cutover, local/LAN health, dependency readiness, zero restarts, safe logs, and preserved R1 rollback |
| Owner phone | PASS: corrected R2Local client reached the R2 server and the owner explicitly reported success |

The bare `npx prisma validate` invocation first returned P1012 because
`DATABASE_URL` was absent. Validation and generation then passed with a
process-scoped, non-secret, non-connecting placeholder which was removed and
was never written to `.env`. Expected non-failing warnings were retained:
Backend negative-path/DEP0190 output, Admin ErrorBoundary fixture output, and
Flutter missing-default-desktop-plugin notices. An initial `adb` lookup through
`PATH` failed; the installed Android SDK executable then verified the distinct
R2Local package on the connected device.

R2 implementation, immutable runtime, and owner acceptance are locally green;
the final independent source/contract/runtime/receipt sign-off is now requested.
At that R2 checkpoint, R3 was next and had not started. Remote CI was not run,
and no push or merge is claimed.

Planning artifacts:

- `docs/superpowers/specs/2026-08-13-modular-monolith-r2-prisma-schema-design.md`
- `docs/superpowers/plans/2026-08-13-modular-monolith-r2-prisma-schema.md`

No R3 start, push, merge, or remote-CI result is claimed.

## Modular Monolith R1 Locally Complete - 2026-08-13

R1 was executed locally on branch `modular-monolith` against immutable
`R1_BASE` `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. The target Backend layout and
all automated local closeout gates are green. Independent source, contract,
baseline, gate, final-image, and runtime review passed, including the reviewed
Redis socket-timer root fix. The owner then passed the phone application
checkpoint against the final local image: authenticated login, conversation
open/read, and message send succeeded. The container remained running with
zero restarts; `/live` and `/ready` stayed green; its post-test logs contained
72 successful API events, including one message `201`, and zero circular/
`TypeError`/fatal matches. R1 is therefore locally complete. PR #76 still points to the
immutable R0 candidate; no R1 push, merge, or remote-CI result is claimed.

### Implemented target and exact move map

- `src/common/{config,filters,http,pagination,redis,observability,prisma}` ->
  `src/platform/{config,http,http,http,redis,observability,database}`.
- `src/prisma/` -> `src/platform/database/`.
- root `health.controller.ts` and `src/health/` -> `src/platform/health/`.
- `src/common/idempotency/` -> `src/platform/idempotency/`.
- `src/outbox/` -> `src/platform/outbox/`.
- `src/auth/{openwa-otp-config,openwa-transient-text,whatsapp-otp-config}.ts`
  -> `src/platform/otp-transport/`, with delivery-only OpenWA/WhatsApp
  adapters and identity-owned OTP generation/selection.
- `src/common/validation/money.ts` -> `src/shared-kernel/money/money.ts` and
  the approved exact Decimal value object.
- `src/common/phone/` -> `src/shared-kernel/phone/`.
- `src/common/privacy/`, `src/users/application-user-identity.ts`, and
  `src/admin/admin-privacy.ts` -> `src/shared-kernel/privacy/`.
- `src/common/time/` -> `src/shared-kernel/time/`.
- `src/common/admin/admin-permissions.ts` ->
  `src/modules/backoffice/domain/admin-permissions.ts`.
- No old-path facade, barrel, shim, duplicate implementation, symlink, or
  fallback remains.

The machine-enforced exact prefix vocabulary is tracked at
`backend/architecture/r1-relocation-map.json`. The combined R1 diff contains
185 paths. Its exact manifest is the output of:

```powershell
git diff --name-only 94b677b7b8e2219e0db2cbc553fa3d26b4876456 --
```

<details>
<summary>Exact 185-path R1 manifest</summary>

```text
.github/workflows/ci.yml
ARCHITECTURE.md
CHANGELOG.md
backend/.dependency-cruiser-known-violations.json
backend/.dependency-cruiser.cjs
backend/architecture/ownership-registry.json
backend/architecture/r1-relocation-map.json
backend/package.json
backend/scripts/architecture/ownership-scan.cjs
backend/scripts/architecture/ports-scan.cjs
backend/scripts/architecture/r1-baseline-relocation.cjs
backend/scripts/smoke/phase2-admin-mutation-authorization-smoke.ts
backend/scripts/smoke/phase2-conversation-revocation-smoke.ts
backend/scripts/smoke/phase2-idempotency-reconciliation-smoke.ts
backend/scripts/smoke/phase2-notification-authorization-concurrency-smoke.ts
backend/scripts/smoke/phase2-notification-preferences-smoke.ts
backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts
backend/src/admin/admin-audit.controller.ts
backend/src/admin/admin-audit.interceptor.ts
backend/src/admin/admin-audit.service.ts
backend/src/admin/admin-mutation-executor.ts
backend/src/admin/admin-mutation-gate.ts
backend/src/admin/admin-permission.decorator.ts
backend/src/admin/admin-permission.guard.ts
backend/src/admin/admin-user-status.ts
backend/src/admin/admin.controller.ts
backend/src/admin/admin.module.ts
backend/src/admin/admin.presenter.ts
backend/src/admin/admin.service.ts
backend/src/app.module.ts
backend/src/auth/auth-challenge-cleanup.scheduler.ts
backend/src/auth/auth.controller.ts
backend/src/auth/auth.module.ts
backend/src/auth/auth.service.ts
backend/src/auth/jwt.strategy.ts
backend/src/auth/login-throttle-cleanup.scheduler.ts
backend/src/auth/login-throttle.service.ts
backend/src/auth/otp-channel.ts
backend/src/auth/otp-dispatch-quota-cleanup.scheduler.ts
backend/src/auth/otp-dispatch-quota.service.ts
backend/src/auth/safe-user.ts
backend/src/budget-categories/budget-categories.module.ts
backend/src/budget-categories/budget-categories.service.ts
backend/src/catalogs/administrative-catalog.service.ts
backend/src/catalogs/catalogs.controller.ts
backend/src/catalogs/catalogs.module.ts
backend/src/catalogs/reference-catalog.service.ts
backend/src/common/validation/money.ts
backend/src/contexts/contexts.module.ts
backend/src/contexts/contexts.service.ts
backend/src/contribution-history/contribution-history.service.ts
backend/src/conversations/conversation-lifecycle.ts
backend/src/conversations/conversations.gateway.ts
backend/src/conversations/conversations.module.ts
backend/src/conversations/conversations.service.ts
backend/src/dashboard/dashboard-home-queries.ts
backend/src/dashboard/dashboard.module.ts
backend/src/dashboard/dashboard.service.ts
backend/src/guests/guests.controller.ts
backend/src/guests/guests.module.ts
backend/src/guests/guests.service.ts
backend/src/main.ts
backend/src/marketplace/marketplace.module.ts
backend/src/marketplace/marketplace.presenter.ts
backend/src/marketplace/marketplace.service.ts
backend/src/marketplace/provider-review-rating.ts
backend/src/marketplace/quote-offer-acceptance.ts
backend/src/marketplace/quote-offer-rejection.ts
backend/src/marketplace/quote-request-cancellation.ts
backend/src/marketplace/quote-request-creation.ts
backend/src/media/media-upload-cleanup.scheduler.ts
backend/src/media/media-upload-ticket.service.ts
backend/src/modules/backoffice/domain/admin-permissions.ts
backend/src/money/money-budget.service.ts
backend/src/money/money-summary.service.ts
backend/src/money/money.module.ts
backend/src/notifications/notifications.module.ts
backend/src/notifications/notifications.service.ts
backend/src/platform/config/cors-options.ts
backend/src/platform/config/cors-origins.ts
backend/src/platform/config/runtime-environment.ts
backend/src/platform/database/prisma.module.ts
backend/src/platform/database/prisma.service.ts
backend/src/platform/database/serializable-transaction.ts
backend/src/platform/health/health.controller.ts
backend/src/platform/health/readiness.service.ts
backend/src/platform/http/bounded-json-response.ts
backend/src/platform/http/global-exception.filter.ts
backend/src/platform/http/list-query.dto.ts
backend/src/platform/idempotency/idempotency-cleanup.scheduler.ts
backend/src/platform/idempotency/idempotency-reconcile.cli.ts
backend/src/platform/idempotency/idempotency-reconciliation.ts
backend/src/platform/idempotency/idempotency.interceptor.ts
backend/src/platform/observability/metrics.controller.ts
backend/src/platform/observability/metrics.ts
backend/src/platform/observability/request-observability.middleware.ts
backend/src/platform/observability/sanitize-request-target.ts
backend/src/platform/otp-transport/openwa-otp-config.ts
backend/src/platform/otp-transport/openwa-otp.channel.ts
backend/src/platform/otp-transport/openwa-transient-text.ts
backend/src/platform/otp-transport/otp-delivery.ts
backend/src/platform/otp-transport/whatsapp-otp-config.ts
backend/src/platform/otp-transport/whatsapp-otp.channel.ts
backend/src/platform/outbox/outbox-cleanup.scheduler.ts
backend/src/platform/outbox/outbox.constants.ts
backend/src/platform/outbox/outbox.dispatcher.ts
backend/src/platform/outbox/outbox.module.ts
backend/src/platform/outbox/outbox.service.ts
backend/src/platform/outbox/outbox.worker.ts
backend/src/platform/outbox/realtime-revocation.ts
backend/src/platform/redis/redis-io.adapter.ts
backend/src/platform/redis/resilient-throttler-storage.ts
backend/src/provider-dashboard/provider-dashboard.module.ts
backend/src/provider-dashboard/provider-dashboard.service.ts
backend/src/push/push-delivery.service.ts
backend/src/push/push-installations.service.ts
backend/src/push/push.module.ts
backend/src/shared-kernel/money/money.ts
backend/src/shared-kernel/phone/phone-normalizer.ts
backend/src/shared-kernel/privacy/admin-notification-privacy.ts
backend/src/shared-kernel/privacy/application-user-identity.ts
backend/src/shared-kernel/privacy/review-identity.ts
backend/src/shared-kernel/time/business-day.ts
backend/src/sharing/invitation-delivery.service.ts
backend/src/sharing/invite-access.service.ts
backend/src/sharing/permission.service.ts
backend/src/sharing/sharing.module.ts
backend/src/sharing/sharing.service.ts
backend/src/tasks/tasks.controller.ts
backend/src/tasks/tasks.module.ts
backend/src/tasks/tasks.service.ts
backend/src/timeline/timeline.module.ts
backend/src/timeline/timeline.service.ts
backend/src/users/users.controller.ts
backend/src/users/users.module.ts
backend/src/users/users.service.ts
backend/src/wedding-costs/wedding-costs.module.ts
backend/src/wedding-costs/wedding-costs.service.ts
backend/src/wedding-plans/wedding-plans.module.ts
backend/src/wedding-plans/wedding-plans.service.ts
backend/test/admin-auth-session-security.test.ts
backend/test/admin-rbac-audit.test.ts
backend/test/architecture-dependencies.test.ts
backend/test/architecture-ownership.test.ts
backend/test/architecture-ports.test.ts
backend/test/architecture-r1-baseline-relocation.test.ts
backend/test/architecture-r1-layout.test.ts
backend/test/auth-otp-mode.test.ts
backend/test/backend-support.test.ts
backend/test/cors-preflight.test.ts
backend/test/financial-integrity.test.ts
backend/test/financial-ledger.test.ts
backend/test/global-exception-filter.test.ts
backend/test/health-readiness.test.ts
backend/test/idempotency-interceptor.test.ts
backend/test/idempotency-reconciliation.test.ts
backend/test/invite-delivery.test.ts
backend/test/media-url-ownership.test.ts
backend/test/notification-contributor-scope.test.ts
backend/test/notification-logic.test.ts
backend/test/notification-mutation-atomicity.test.ts
backend/test/openwa-credential-file.test.ts
backend/test/openwa-otp-channel.test.ts
backend/test/otp-dispatch-quota.test.ts
backend/test/outbox-logic.test.ts
backend/test/password-reset-logic.test.ts
backend/test/phase0-guards.test.ts
backend/test/privacy-contract.test.ts
backend/test/provider-price-validation.test.ts
backend/test/push-notifications.test.ts
backend/test/request-target-redaction.test.ts
backend/test/scheduler-lock.test.ts
backend/test/shared-kernel-money.test.ts
backend/test/support/phase0-postgres-support.js
backend/test/websocket-session-hardening.test.ts
backend/test/whatsapp-otp-channel.test.ts
docs/README.md
docs/SCRIPTS.md
docs/backend/README.md
docs/project/DECISIONS.md
docs/project/EXECUTION_PLAN.md
docs/project/STATUS.md
docs/qa/README.md
docs/superpowers/plans/2026-08-12-modular-monolith-r1-platform-shared-kernel.md
docs/superpowers/specs/2026-08-12-modular-monolith-r1-platform-shared-kernel-design.md
```

</details>

### Final local evidence

| Area | Command | Result |
| --- | --- | --- |
| Backend architecture | `npm run architecture` | PASS: 306 modules, 1314 dependencies, 260 counted known records, ownership 386, ports `forwardRef=0`, globals=2, illegal imports=0, cycles=0 |
| Backend type/build | `npm run check`; `npm run build` | PASS |
| Backend tests | `npm test` | PASS: 805 total, 804 passed, 0 failed, 1 expected Windows permission skip; artifact guard PASS |
| Prisma | `npx prisma validate` | First run P1012 because `DATABASE_URL` was absent; PASS on the schema-only rerun with a process-scoped non-secret local placeholder and no connection or `.env` write |
| Dependency audit | `npm audit --audit-level=high`; `npm audit --omit=dev` | PASS: 0 vulnerabilities in each |
| Managed runtime | `npm run smoke:all` | PASS: all 30 registered packages after all 76 migrations; final backend-completion package 76/76; run `smoke_20260813001205991_fad1a26e` cleaned its DB/Redis/process/temp resources |
| Admin Web | `npm run typecheck`; `npm test -- --run`; `npm run build`; `npm run smoke:honesty`; `npm run smoke:routes`; `npm run test:container-config` | PASS: 96/96 tests, honesty 12/12, routes 16/16, container 3/3 |
| Mobile architecture | `node --test .\scripts\check-mobile-boundaries.test.mjs`; `node .\scripts\check-mobile-boundaries.mjs --check-baseline` | PASS: 192/192 and 269 current records |
| Mobile | `flutter analyze --no-pub`; `flutter test --no-pub` | PASS: no analyzer issues; authoritative direct test run 1151/1151 |
| Docs | `node .\scripts\docs-sync.mjs --check`; `node .\scripts\docs-verify.mjs`; `git diff --check` | PASS: drift/errors/warnings 0 |
| Protected surfaces | fixed-base preflight and postflight Git checks | PASS: schema/migrations, Mobile, Admin source, deploy, and Compose unchanged; protected worktree clean |
| Test policy | fixed-base name/status and `-U0` audits | PASS: 0 removed/renamed, 36 reviewed behavioral path/QA/runtime-safety changes, 3 reviewed architecture changes, exact 3 additive tests |
| Independent review | final source, contract, baseline, image, and runtime review | PASS: no Critical/Important/Minor findings on image revision `d2530c5cdfbff5a4fc5f90433da3a6cfae0652ff` |
| Owner phone checkpoint | authenticated application flow against `http://10.185.93.102:3120` | PASS: login, conversation open/read, and message send; container remained running with zero restarts and no recurrence of the Redis circular-serialization crash |

Fresh final baseline verification against `R1_BASE` passed. Dependency
candidate/tracked SHA256 is
`76f6d069c27172dc2c8756c04d2282806650d9eeb062043353860b61a1454000`
with 260 sorted unique records and totals mapped 6 / removed 9 / decreased 0.
Ownership candidate/tracked SHA256 is
`a4d478f45c5bfa76123be60e1cc77f99001969951afc219478916c87638ff3e6`
with 386 keys / 782 occurrences and totals 0/0/0. Mobile baseline remains 269
records and byte-identical. Registry has 52 models, no exceptions, and
`currentRoots.platform=['platform']`. Live schema remains 52 models and 76
migrations.

Six exact platform debts remain for R3: runtime config -> JWT secret;
readiness -> media storage; outbox dispatcher -> conversation realtime
publisher; outbox dispatcher -> push delivery; outbox module -> conversation
realtime module; and outbox module -> push module. Sharing's
`invitation-delivery.service.ts` direct consumption of platform OpenWA
transient-text policy remains migration debt until R6. The two approved globals
remain until R8.

R1 changes no API route, error/Arabic contract, permission, transaction/lock/
retry/scheduler behavior, schema, migration, Mobile source, Admin source, or
deployment artifact. Final phone-server review found one pre-existing runtime
crash: `ConversationsGateway` stored a circular `NodeJS.Timeout` in
Redis-serialized `socket.data`, so a cross-replica `fetchSockets()` request
could terminate Node. The reviewed root fix keeps that handle in a process-local
`WeakMap`; the existing token expiry/disconnect contract remains unchanged and
the exact Redis response-shape regression is green. The phase-specific
`r0-scope` CI job alone is removed;
its local script/tests remain historical evidence. Warnings were not hidden:
the Backend negative-path logs and DEP0190 notice, Admin ErrorBoundary fixture
output, and Flutter desktop default-plugin notices are non-failing expected
test/tool noise. A second Flutter output-tail wrapper returned a PowerShell
pipeline status 1 after printing `All tests passed`; the authoritative direct
command returned 0 and 1151/1151.

## Modular Monolith R0 Local Verification Receipt - 2026-08-12

R0 governance was verified locally on branch `modular-monolith` against the
fixed base revision `feafe3db0053d6c66d5f46b56ff9a512861dfbad`. This receipt
records local evidence only. The authoritative candidate revision and remote
CI result must come from immutable pull-request/workflow metadata; this tracked
receipt intentionally makes no claim about its own mutable branch tip or the
current remote CI state.

The exact fixed-base diff contains these 31 paths:

- `.github/workflows/ci.yml`
- `.gitleaksignore`
- `AGENTS.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `backend/.dependency-cruiser-known-violations.json`
- `backend/.dependency-cruiser.cjs`
- `backend/architecture/ownership-baseline.json`
- `backend/architecture/ownership-registry.json`
- `backend/package-lock.json`
- `backend/package.json`
- `backend/scripts/architecture/ownership-scan.cjs`
- `backend/scripts/architecture/ports-scan.cjs`
- `backend/test/architecture-dependencies.test.ts`
- `backend/test/architecture-ownership.test.ts`
- `backend/test/architecture-ports.test.ts`
- `docs/README.md`
- `docs/SCRIPTS.md`
- `docs/backend/README.md`
- `docs/frontend/MOBILE_ARCHITECTURE.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md`
- `docs/qa/README.md`
- `docs/superpowers/plans/2026-08-11-modular-monolith-r0-governance.md`
- `mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`
- `scripts/architecture/mobile-boundaries-baseline.json`
- `scripts/check-mobile-boundaries.mjs`
- `scripts/check-mobile-boundaries.test.mjs`
- `scripts/check-r0-scope.mjs`
- `scripts/check-r0-scope.test.mjs`

The only application-source change is the owner-approved one-line local import
URI correction in
`mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`. Its
content is unchanged from repair commit `464a23e0`. Backend application source,
schema, all 76 migrations, and routes; Mobile tests, integration tests, and
every other Mobile source file; Admin application source; deployment and
Compose artifacts; source locations; and business logic were untouched. No
module, port, repository, barrel, migration, route, endpoint, or product
behavior was added by R0.

The final local review remediation initially stayed inside the 30-path scope.
Commits `003474d9`, `302aec72`, `8de041ce`, `d8788ed8`, `8d0e8116`, and
`182ade08` close Backend ownership/ports provenance, alias, path-redaction,
non-reflective diagnostic, and atomic scan-result validation gaps. Commit
`ff35ea73` makes Mobile boundary parsing fail closed around canonical junction
identity and nested Dart interpolation. Commit `7f4cd70` reconciles the R0
plan's protected-source exception, documents the official local gates, and
records the distinct PR-head versus synthetic-merge CI semantics. Commit
`019f9a28` validates Mobile scan and baseline results atomically and makes
scan-error diagnostics non-reflective: malformed or hostile result structures
fail closed before any diagnostic is rendered, while legitimate scan errors
emit only a fixed error kind and canonical repository-relative source. The
Ownership commits `7c53a9d`, `70d6de05`, and `9fc322b7` apply the same atomic,
non-reflective boundary to current scans, saved baselines, and baseline writes;
enforce operation/mode/source, model/owner/reason, and recomputed-key
invariants; and derive every context from its registry-backed repository path.
The independent final local review passed after these remediations. These are
gate-hardening and documentation corrections only; they add no runtime product
behavior and make no claim about remote CI state.

The first remote PR run then identified one Gitleaks false positive in the
historical Symbol-type rejection fixture. Commit `536058bf` removes the
secret-shaped text from the current test, records only that exact reviewed
historical fingerprint in `.gitleaksignore`, and expands the fixed R0 scope by
that one governance file to 31 paths. No Gitleaks rule or file path is disabled.
The same 37-commit R0 range was rescanned locally with Gitleaks v8.30.1 and
reported no leaks.

Observed governance baselines:

- dependency-cruiser `18.1.0`: 269 unique known dependency violations. The live
  graph contains 303 modules and 1,307 dependencies, with no new violation.
- Prisma ownership: 386 keys and 782 occurrences. By reason this is 302/564
  foreign-model keys/occurrences, 83/216 unknown-relation-shape, and 1/2
  unknown-sql-composition. By source this is 183/303 delegate, 163/425
  relation, and 40/54 SQL keys/occurrences.
- Mobile boundaries: 269 keys/occurrences, comprising 62 core-to-feature and
  207 direct-cross-feature records. The live scan reported zero errors.
- Ports/Nest: zero `forwardRef()`, exactly two approved globals, zero illegal
  future imports, and zero Nest module cycles.
- Source counts: 52 Prisma models and 76 committed migration directories.

Local verification evidence:

| Area | Exact command | Result |
| --- | --- | --- |
| Protected surface | Task 7 Step 1 and Step 7 exact PowerShell gates using `git diff --name-status --no-renames --diff-filter=ACMRDTUXB`, `git diff --exit-code 464a23e0..HEAD -- mobile/lib/features/welcome_gateway/widgets/aarast_path_card.dart`, protected-path `git status`, and `node .\scripts\check-r0-scope.mjs --check` | PASS before and after tests: exactly the approved Mobile `M` path, repair unchanged, protected worktree clean, no unexpected R0 path |
| Backend | `npm run architecture` | PASS: imports, ownership, and ports |
| Backend | `npm run check` | PASS |
| Backend | `npm run build` | PASS |
| Backend | `npm test` | PASS: 746 total, 745 passed, 1 intentionally skipped |
| Backend | `npx prisma validate` | PASS with a process-scoped non-secret local validation URL; no database connection was used |
| Backend | `npm audit --audit-level=high` | PASS: 0 vulnerabilities |
| Backend | `npm audit --omit=dev` | PASS: 0 vulnerabilities |
| Secret scan | Gitleaks v8.30.1 over the fixed-base R0 commit range with redaction enabled | PASS: 37 commits scanned, no leaks |
| Admin | `npm run typecheck` | PASS |
| Admin | `npm test -- --run` | PASS: 96/96 |
| Admin | `npm run build` | PASS |
| Admin | `npm run smoke:honesty` | PASS: 12/12 |
| Admin | `npm run smoke:routes` | PASS: 16/16 |
| Admin | `npm run test:container-config` | PASS: 3/3 |
| Mobile architecture | `node --test .\scripts\check-mobile-boundaries.test.mjs` | PASS: 192/192 |
| Mobile architecture | `node .\scripts\check-mobile-boundaries.mjs --check-baseline` | PASS: 269 current records |
| Mobile | `flutter analyze --no-pub` | PASS: no issues |
| Mobile | `flutter test --no-pub` | PASS: 1,151/1,151, including the repository's current Golden behavior |
| Docs | `node .\scripts\docs-sync.mjs --check` | PASS: drift=0, errors=0 |
| Docs | `node .\scripts\docs-verify.mjs` | PASS: errors=0, warnings=0 |
| Repository | `git diff --check` | PASS |
| Source counts | `Select-String .\backend\prisma\schema.prisma -Pattern '^model\s+'` and `Get-ChildItem .\backend\prisma\migrations -Directory` | PASS: 52 models, 76 migrations |

The first bare `npx prisma validate` invocation reported Prisma `P1012` because
this isolated worktree has no `.env` and `DATABASE_URL` was unset. Inspection
confirmed that `prisma.config.ts` only loads `.env` when present. The same
validation then passed with a process-scoped, non-secret local PostgreSQL URL;
the value was not persisted and Prisma validation made no database connection.
Backend tests also emitted the existing Windows `DEP0190` fixture warning and
intentional warning/error logs. Admin's ErrorBoundary test printed its expected
`render failure`. Flutter printed existing desktop default-plugin-package
warnings while the analyzer and all 1,151 tests passed. These diagnostics were
not suppressed.

No separate local HTTP/database smoke run was required for R0: the only source
repair is the approved local Dart import URI correction, the full Mobile suite
passed, and R0 changed no Backend runtime source, schema, migration, route,
Admin source, deployment artifact, source location, or business logic. Remote
closure still requires the fixed-base `r0-scope` job to pass on the exact
immutable PR-head revision and every other CI job to pass on the corresponding
synthetic merge candidate for that pull request. This receipt does not claim
the current remote state of either Git object.

## Product Position

Aarast is an Arabic-first, Yemen-focused wedding planning product centered on
a Wedding Financial OS. The current product covers planning, tasks, guests,
sharing, provider references, quote leads, quote-scoped conversations, and
administration.

The current scope does not include confirmed bookings, deposits, payment
processing, provider settlements, loans, credit, financing, production AI, or
open unsolicited messaging. Accepting a provider offer creates one idempotent
`WeddingCost`; it does not create a payment, payment schedule, task, deposit,
or booking.

Financial data remains private by default. `canViewMoney` controls reads and
`canManageMoney` controls writes. Shared members must not receive hidden money
values as zero-valued substitutes.

## Current Stack

- Backend: NestJS 11, TypeScript strict mode, Prisma 6, PostgreSQL, Redis,
  Socket.IO, MinIO/S3-compatible media, and optional Sentry.
- Mobile: Flutter, Provider, go_router, dio, SQLCipher-backed SQLite, secure OS
  storage, Socket.IO, Firebase Messaging, and optional Sentry.
- Admin: React 18, Vite, strict TypeScript, Vitest, and React Router.
- Deployment: local Docker Compose plus the current production-oriented
  Dokploy Compose under `deploy/dokploy/`.

Current Compose still treats Backend, Admin Web, the static public safety
surface, and Mobile distribution as separate concerns. Production Compose
defines Backend on host port `8093`, Admin Web on `8094`, and the immutable
public invite/privacy/support site on `8095`. It does not define Flutter web as
an additional production service. Mobile store artifacts remain a separate
release path.

## Implemented Core

- Verified-phone registration, password/OTP login, password recovery, separate
  application/admin session scopes, rotating refresh sessions, and durable
  login throttling.
- Wedding plans, account contexts, onboarding, dashboard, settings, and
  account/session teardown.
- General budget, categories, `WeddingCost`, append-only `CostPayment`, and
  non-reserving `PaymentSchedule` reminders.
- Tasks, timeline, guests/groups, notifications, sharing, invitation consent,
  roles, permissions, contributor isolation, and immutable contribution
  history.
- Provider catalog, favorites, reviews, quote requests/offers, provider portal,
  admin approval/catalog operations, and quote-scoped conversations.
- Versioned managed catalogs with draft/publish/rollback, groom/bride and
  customer/provider audiences, Admin management, public bootstrap versioning,
  and Mobile offline cache. Money starter categories consume the published
  catalog with a bundled safe fallback.
- Admin-managed Yemen geography through governorate, district, and typed
  area/isolation/neighborhood/zone rows. Mobile keeps the enforced geographic
  order, offers remote locality suggestions, and preserves manual entry.
- Authenticated real-time chat, unread/read state, mute/block/report controls,
  private media signing, media ownership tickets, quotas, sanitization, and
  abandoned-upload cleanup.
- SQLCipher cache and selected offline replay with user/plan ownership and
  session-generation isolation.
- Redis-assisted throttling/realtime scaling, request correlation, protected
  metrics, structured logs, outbox delivery, and readiness checks.

## Verified Local Baseline — 2026-08-07

The following commands were run against the clean baseline or against areas
unchanged by the preserved Mobile-only WIP:

| Area | Command | Result |
| --- | --- | --- |
| Backend | `npm run check` | PASS |
| Backend | `npm test` | PASS — 655 tests, 654 passed, 1 skipped |
| Admin | `npm run typecheck` | PASS |
| Admin | `npm test` | PASS — 92/92 |
| Admin | `npm run build` | PASS |
| Mobile | `flutter analyze` | PASS — no issues |
| Mobile | `flutter test --no-pub` | PASS — 997 tests |
| Docs | `node scripts/docs-sync.mjs --check` | PASS |
| Docs | `node scripts/docs-verify.mjs` | PASS |
| Repository | `git diff --check` | PASS on the clean branch |
| Backend dependencies | `npm audit --omit=dev` | PASS — zero findings |
| Admin dependencies | `npm audit --omit=dev` | NEEDS FIX — two Moderate React Router findings |

This historical baseline predates the React Router 7 remediation recorded in
the 2026-08-11 closure below. At this checkpoint the offered npm fix was a major
upgrade and was intentionally not merged without migration coverage.

## P2 Modernization Checkpoint — 2026-08-08

The first Mobile navigation and Home slices are complete, but P2 is not
complete. Mobile and Admin now expose the shared semantic-token vocabulary,
with automated contrast coverage for the Mobile values. The first shared
Mobile primitives include quiet surfaces/sections and an accessible pressable
selection state.

- Plan and provider shells now use one plain, labelled navigation bar and one
  contextual add action. The migrated chrome has no glass, blur, ornamental
  gradient, automatic glow, crown, or rotated floating action button.
- The shell now keeps the current plan name and active destination visible in a
  smaller semantic context bar. Its navigation height adapts to enlarged text,
  labels remain available at 320px RTL, and the quick-action sheet scrolls on
  short viewports instead of overflowing.
- The provider home action now says `عرض الطلبات`; this keeps the visible
  navigation destination `الطلبات` unambiguous to assistive technology.
- Account-backed and local-guest Home now render through one semantic dashboard
  composition. It exposes the plan moment, one deterministic next action,
  truthful task/guest/provider counts, permission-aware money, setup progress,
  and plan-team state without changing data or route ownership.
- The reviewed Home direction is now a warm one-screen brief: one compact solid
  burgundy plan moment, one deterministic urgent action, three independent
  truth signals, one larger permission-aware Money surface, and a compact team
  strip. It avoids repeated dashboard facts and keeps the primary brief visible
  without a long phone scroll.
- The visible `+ إضافة` control now opens one labelled creation sheet for real
  task, guest, cost, and quote routes. Urgency wins first and the last useful
  action in the running session provides a secondary ordering signal. It now
  floats at the lower RTL side above navigation, becomes contextual on task,
  guest, and money roots, and compacts while scrolling down rather than taking
  space from the location header.
- Overdue tasks, incomplete/pending guests, and overdue payments expose direct
  contextual actions. Guest reply updates are backed by the existing status
  mutation; no unsupported reminder-delivery action is presented.
- Task, guest, cost, and quote-request creation now restore account-scoped
  drafts from secure storage, clear them after successful submit, and remove
  them on account teardown. The cost form adds an explicit total/paid/remaining
  confirmation summary without a blocking dialog.
- Provider details now keep the quote CTA labelled during loading/disabled
  states and render compact, explicit gallery loading/failure states instead
  of large blank image regions.
- Three real shell-plus-dashboard Goldens were generated only after behavior
  tests passed and were manually reviewed at 320px, 420px, and 1000px RTL. The
  former blank shell-only preview is no longer an active test.
- This slice did not change APIs, routes, auth/session behavior, permissions,
  offline SQLite ownership, database schema, provider capability boundaries, or
  contributor isolation.
- The Admin shell, dashboard, and login now use the same semantic direction:
  grouped navigation, visible location, operational priority, quiet surfaces,
  and one clear primary action. The Login migration retains the existing
  password + phone OTP, recovery, and session contracts.
- The migrated Login surface has no crown, burgundy/gold panel, ornamental
  gradient, or premium button. It was reviewed at wide desktop, 760px tablet,
  and 390px phone widths without horizontal overflow.
- The shared confirmation dialog now has verified Escape, focus containment and
  restoration, pending-dismissal protection, and mutation-error behavior. All
  12 current Admin tables use one labelled token-based responsive primitive,
  and all current search filters expose visible labels and named search
  landmarks without changing their backend queries.

Observed validation for this checkpoint:

| Area | Command | Result |
| --- | --- | --- |
| Mobile | `flutter analyze` | PASS — no issues |
| Mobile | `flutter test --exclude-tags golden` | PASS — 966 tests |
| Mobile | `flutter test --tags golden` | PASS — 42 reviewed Goldens, including 320px/420px/1000px RTL Home |
| Mobile | plan/provider navigation, contributor isolation, semantic-token and visual-contract tests | PASS |
| Mobile | `flutter build web --release` with the public HTTPS API origin | PASS |
| Mobile | `flutter build apk --debug` with the public HTTPS API origin | PASS |
| Admin | `npm test -- --run` | PASS — 96/96 |
| Admin | `npm run typecheck` and `npm run build` | PASS |
| Admin | `npm run smoke:routes` | PASS — 16/16 |
| Admin | `npm run smoke:honesty` | PASS — 12/12 |

### Mobile V3 density and source guard — 2026-08-09

- Home metrics are one operable 2x2 surface; the dashboard no longer reads as
  four unrelated cards.
- Guests, tasks, participants, notifications, settings, and More use the V3
  density/list hierarchy. Status and metadata stack safely at 320px, and
  secondary mutations remain in overflow or a dedicated account-action sheet.
- Provider details expose services first and move packages, provider detail,
  and reviews behind one explicit progressive disclosure.
- The old Premium splash mark was replaced by the flat `AarastBrandMark`.
  Production Dart now contains no gradient implementation or decorative
  `BoxShadow`; the visual-contract test scans all of `mobile/lib`.
- Mobile verification for this branch: `flutter analyze` PASS; 969/969
  non-Golden tests PASS; 42/42 serial reviewed Goldens PASS; Release Web and a
  public-API debug APK build PASS.
- This checkpoint did not change routes, APIs, auth/session behavior,
  permissions, database schema, or offline ownership. Money feature redesign
  remains intentionally deferred; only the shared flat-white canvas applies
  to it.

### Mobile V3 interaction and Wedding Day checkpoint — 2026-08-09

- Home now resolves one deterministic Plan Pulse from real task, guest,
  provider, and money attention. Tasks and Guests share a thin Plan Path
  signature and quiet shared-element navigation from their Home metrics.
- The floating creation control supports a labelled action sheet, session-last
  long press, contextual ordering, scroll compaction, and permission-aware
  absence. Reversible task/guest changes use unified haptics, feedback, and
  Undo; list gestures reveal the real contextual action without auto-deleting.
- Task, guest, and quote forms use Focus Mode with one opening decision,
  progressive detail, live summary, draft continuity, inline validation, and a
  keyboard-safe action area.
- Provider detail now orders identity, media, trust/price, services, and quote
  action before secondary detail. Broken media has an explicit designed state.
- Added `/wedding-plans/:id/wedding-day`, visible from Home only in the seven
  days before the event through the day after. It requires plan-view access and
  uses real plan/task/provider data with cached-task failure continuity; it
  introduces no API, schema, booking, payment, AI, or messaging contract.
- Verification: `flutter analyze` PASS; 981/981 non-Golden tests PASS; 44/44
  reviewed serial Goldens PASS; Release Web and public-API debug APK builds
  PASS.
- Physical Android/iOS acceptance and exhaustive routed edge-state review
  remain release gates. Money product redesign remains deferred.

### Mobile V3 global completion checkpoint — 2026-08-09

- Retired `Premium`/`Royal` production class, file, and token vocabulary from
  Mobile and extended the source contract so the legacy visual language cannot
  return through a newly routed screen.
- Every non-auth domain form is decision-led with a compact Focus prompt.
  Durable task, guest, quote, plan, sharing, provider, budget, cost, payment,
  and schedule forms restore encrypted account-scoped drafts and keep their
  primary action fixed above the keyboard. Password and OTP forms remain
  intentionally ephemeral and never persist credentials.
- Success feedback now uses one restrained haptic and non-blocking receipt.
  Reversible task, guest, and saved-provider changes expose a real Undo; no
  reminder, message, or delivery action is shown without a working contract.
- The deterministic wedding-stage engine now provides compact, offline-safe
  context on Tasks, Guests, Money, and Providers in addition to Home and plan
  chrome. It changes priority, not navigation or invented readiness. In the
  final month, real provider decisions such as open offers and conversations
  are ordered before discovery.
- `guest_list_screen.dart` was split at the independent filtering/summary
  boundary so the routed screen remains below the enforced 1,000-line limit.
- Verification on this working tree: `flutter analyze` PASS; 997/997 serial
  non-Golden tests PASS; 44/44 reviewed serial Goldens PASS; the focused
  320px/420px, 1.3x/2.0x, finance, provider, sharing, and contributor gate PASS
  (73/73); Release Web and public-API debug APK builds PASS.
- Installation of this latest APK and physical offline recovery are BLOCKED in
  this checkpoint because the previously available Android device disconnected
  from ADB. Physical iOS remains BLOCKED on the available Windows host.

### Mobile Soft Royal V2 identity checkpoint — 2026-08-10

- Mobile V3 now resolves one warm identity from semantic roles: near-white
  canvas, white paper, deep burgundy brand/actions, readable deep-gold accents,
  decorative champagne only on dark identity surfaces, and unchanged semantic
  success/warning/danger/information colors.
- Home now uses one solid-burgundy plan moment, one next decision, three
  independent compact truth signals, one expanded permission-aware Money
  surface, and the compact team strip. The layout preserves real data and does
  not restore gradients, glow, crowns, decorative shadows, or Royal/Premium
  compatibility names.
- Primary actions, selected controls, plan-level floating creation, native
  splash, and Android notification accent now share the burgundy identity.
  Forms, lists, providers, Money, feedback, and empty/error states keep their
  existing contracts and use semantic status color only where it adds meaning.
- Verification on this working tree: `flutter analyze --no-pub` PASS;
  `flutter test --no-pub` PASS with 1134/1134 total tests (1084 non-Golden plus
  50 reviewed Goldens); token contrast, native brand, visual source guard,
  accessibility, and responsive boundary tests PASS; docs sync and verification
  PASS; debug APK build PASS.
- The debug APK was installed with data-preserving `adb install -r` and the
  routed Home surface was physically reviewed on Samsung SM-S938B while the app
  held focus. The final plan moment uses a 146-176px responsive height range,
  keeps the wedding date above the location, and remains overflow-free at
  320px. Exhaustive physical secondary-route, short-height, mutation, and
  sync-recovery review remains OPEN. Physical iOS remains BLOCKED on the
  available Windows host.

### Product-truth and release-hardening checkpoint — 2026-08-11

- Provenance truth: the candidate must be committed, reviewed, green in CI, and
  bound to one immutable merge revision before deployment. The release receipt
  records that revision rather than freezing a stale branch tip in this file.
- Backend now reports push capability from the configured Firebase runtime,
  distinguishes it from per-user device registration, and suppresses expected
  `GET /ready` probe failures from error/Sentry reporting while preserving
  reporting for other server errors.
- Local Compose Backend was rebuilt and recreated without deleting data. The
  container is healthy; `/live` and `/ready` both return `200`, with database,
  Redis, and media all reported `up`.
- Admin Web now runs React Router `7.18.2`; the complete npm audit reports zero
  findings. Existing auth/return-path behavior, 96 tests, type-check, route and
  honesty smokes, container-config test, and production build pass.
- Mobile Marketplace failures no longer masquerade as empty data, blocked
  offline operations expose safe Arabic diagnostics and valid retry actions,
  and push availability requires both server support and a locally configured
  Firebase gateway. Missing capability data fails closed.
- The static public surface now serves actionable Arabic `/privacy` and
  `/support` pages alongside invitation links, with no scripts or forms and
  fail-closed unknown routes. Production Compose uses an immutable image ID and
  the build candidate is stamped with the same Git revision as Backend/Admin.
- Combined closure PASS: Backend `670` tests (669 passed, one skipped), build,
  Prisma validation, zero-finding npm audit, and all `30` managed smoke packages
  after `76` migrations; Admin `96/96`, type-check/build, routes `16/16`,
  honesty `12/12`, container `3/3`, and zero-finding full audit; Mobile analysis,
  `1150/1150`, reviewed Golden, and public-API debug APK; deployment contracts
  `38/38`, public Docker build/live routes, Compose validation; docs sync and
  verification with zero drift/errors/warnings; and `git diff --check` PASS.

## Account-deletion production correction - 2026-08-11

- A physical Android report exposed one dual-identity defect in the deployed
  revision: an administrator enrolled in the wedding application was projected
  correctly as an application user at login, but `DELETE /api/v1/users/me`
  re-read the shared database `role=ADMIN` and returned `403`. The durable
  idempotency reservation then appeared `PENDING`, and an immediate Mobile
  replay could surface `503` while the first reservation was still live.
- Deployed source corrects the realm boundary. Ordinary users/providers still
  delete the complete User graph. A dual administrator/application identity
  deletes only its app credential/profile/data/media, push registration,
  application OTP/idempotency rows and `APPLICATION` sessions; the admin
  password/profile/avatar, challenges, audit links/idempotency rows and
  `ADMIN` sessions remain. Flutter no longer replays DELETE while status is
  `PENDING` and shows a truthful account-deletion verification state.
- Corrective source evidence: Backend full suite `671` total (`670` passed,
  one intentionally skipped), Backend type/seed checks, 30 focused deletion /
  recovery / media tests, managed isolated account-deletion smoke after all 76
  migrations, Flutter analysis, 8 focused session-transition tests, and the
  complete `1151/1151` Flutter suite all PASS. Documentation/public-site and
  final diff/secret checks are recorded by the change receipt.
- PR `#74` passed all eight GitHub checks and application revision
  `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` is deployed. The affected
  physical-device deletion path and administrator-browser survival check remain
  native acceptance gates.

## Production Deployment Receipt - 2026-08-11

- Application revision `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` is deployed
  through Dokploy. Backend, Admin Web, and the public static site are healthy,
  use immutable image IDs, report the same full revision label, and have zero
  restarts and no OOM termination in the acceptance snapshot.
- A fresh pre-deployment PostgreSQL custom-format backup is retained at the
  production host with SHA-256
  `1c327dab578ee8879a2dd845f37d8d736dc5e76ad600bfbe3089294d55ff6c82`.
  Its catalog, checksum, full isolated restore, all `76` migrations, second
  idempotent migration pass, schema checks, and relational postconditions PASS
  against the exact deployed Backend image.
- Production migration status is current. All `16` live wedding plans have one
  linked contributor-history scope; there are zero missing scopes, lifecycle
  mismatches, missing contributor tenures, or unfinished migrations.
- External HTTPS acceptance PASS for Backend `/live` and `/ready`, Admin
  `/login`, and the allowlisted public `/privacy`, `/support`, participant
  invite, and Android `assetlinks.json` routes. Unknown public routes and the
  intentionally unavailable Apple association return `404`.
- The managed catalog bootstrap is live with 55 money items, 39 provider
  categories, 7 cities, and 22 governorates; exact-version replay is unchanged.

## Current Quality Debt

### Design And UX

The implementation does not yet close every release gate for the 2026-08
design-system reset:

- Production Mobile no longer contains the retired Royal/Premium class, file,
  token, gradient, glow, or decorative-shadow vocabulary. Source and visual
  contract tests now guard that boundary.
- Admin feature pages still mix one large legacy stylesheet with page/component
  inline styles, hard-coded colors, and local responsive grids. The shell,
  dashboard, and login surface have been migrated and are not a claim of
  repository-wide compliance.
- Existing visual contract tests enforce wrappers and primitives but do not
  prove navigation clarity, content hierarchy, accessibility, or usability.
- The preserved Money starter WIP can produce suggested allocations whose
  percentages exceed 100%; it must not be restored or merged without fixing
  the product logic and tests.

The active target contract is `docs/frontend/DESIGN_SYSTEM.md`.

### Maintainability

Several Backend services and Mobile screens/providers exceed 1,000 lines.
Notable examples include sharing, auth, notifications, wedding costs, provider
dashboard, invitation decisions, finance API, marketplace provider state, and
the mobile router.

Backend and Admin currently have strict TypeScript checks but no project ESLint
configuration. Flutter uses the default `flutter_lints` set without additional
architecture rules. Refactoring must preserve transaction lock order,
authorization decisions, session isolation, and offline ownership.

### Documentation

Historical implementation plans, the former Premium roadmap, and
`docs/superpowers/` working notes are preserved under
`docs/archive/2026-08-modernization-consolidation/`. The remaining
non-Markdown prototype assets are reference-only until the P2 design migration
replaces them. The obsolete Flutter documentation assertions that mandated the
Premium/Royal identity were replaced at the start of P2; the active contract
now verifies the semantic system and keeps the retired roadmap archived.

## Security Status

No confirmed Critical or High application vulnerability was found during the
latest repository security review. Backend and Admin npm audits currently
report zero findings.

Current strengths include:

- separate application/admin JWT scopes and live server-session checks;
- admin access token in memory and rotating HttpOnly/SameSite refresh cookie;
- global DTO whitelist, unknown-field rejection, and transformation;
- production CORS allowlist behavior and protected Prometheus metrics;
- secure mobile token storage and SQLCipher key handling;
- image ownership, quota, signature, decode, sanitization, and re-encoding;
- fail-closed production configuration for auth and media dependencies.

Open security/release work includes dependency-by-dependency Mobile upgrade
review, physical-device session and push delivery tests, Sentry
privacy/symbolication checks, WhatsApp OTP acceptance, a non-empty protected
metrics token plus an operated monitoring stack, real Apple Team/signing
configuration, and store evidence. Production backup/restore and deployed
Backend/Admin/public acceptance are complete as recorded above.

## Branch Status

- `main` is the canonical local and remote integration branch. Temporary
  release branches are removed only after a verified merge; use `git branch`
  and `git branch -r` for the exact live inventory.
- Fully merged remote remediation branches were removed during the explicit
  branch cleanup. `main` remains the default branch.
- `origin/codex/guest-invitation-campaigns` remains preserved and quarantined:
  it contains a large unique WIP commit outside the approved current scope.
- Open Dependabot branches remain because each is tied to an open dependency PR
  and requires independent compatibility testing; their automated count may
  change at any time, so they are not treated as disposable branches.

## Release Judgment

The Backend, Admin Web, public static site, database migrations, and production
backup/restore gate are deployed and accepted at application revision
`959c47b756d0bebc3e4e4fda5f81ae3349d05e62`. Production operations still have
explicit notes: `METRICS_TOKEN` and `SENTRY_DSN` are not configured, and no
Prometheus/Grafana/Alertmanager stack is running.

Current verdict: source, local-runtime hardening, and the current web/API
production deployment PASS with the operational notes above. Mobile store
release remains BLOCKED by physical-device OTP/Push/session acceptance, live
Sentry symbolication, repeatable store AAB signing/upload, iOS/macOS evidence,
store assets/approval, and the Apple association identity.

The active priority and acceptance order is defined in
`docs/project/EXECUTION_PLAN.md`.

## R10 Local Completion Stop Boundary

R10 Admin phase is locally complete in the working tree from immutable R9
closeout `e560e5784278907dd6bf565327c3abfa0c9b8cab`. Stop before any commit,
push, merge, PR mutation, deployment, production mutation, remote CI, store
release, or S10 work unless the owner authorizes that action separately. The
remaining Backend target debt requires its own future phase and plan.

That stop was later lifted only for the owner-authorized local R10 commit
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`; no external Git or deployment
action followed.

## R11 Target Reconciliation Stop Boundary

R11 may change only its nine approved Markdown paths. Stop before R12 source
implementation, any additional commit, push, merge, PR mutation, deployment,
production mutation, remote CI, provider delivery, store release, or S10.
