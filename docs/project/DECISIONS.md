# Decisions

## Modular Monolith Mission — Closure — 2026-09-24

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

| Decision | Status | Rationale |
| --- | --- | --- |
| Retire the ownership debt owner by owner through the owners' public ports instead of the R13–R17 buckets. | Accepted; completed | The first provability fix re-measured 385/781 as 369/900 (the old walker undercounted); each owner commit subtracted its exact records; R14A identity still exited before R14B collaboration. Ledger outcome in `ARCHITECTURE.md`. |
| Grow an owner's existing port with the methods other contexts need; add a new port only for a new consumer role (erasure steps, admin). | Accepted | One contract per owner role; no facade over a service; the R3 frozen port surfaces only grow. |
| Account erasure runs as per-owner erasure-step ports called by identity's deletion saga, in the saga's order, not as one AccountErasurePort. | Accepted | Each owner deletes its own rows on the saga's transaction; the saga keeps the order and the single transaction. |
| Present another owner's rows through context-private holders that attach them after the own-table read. | Accepted | No foreign include or relation filter remains; response shapes are unchanged. |
| Product code declares the exact where/data shapes it passes to Prisma. | Accepted | Generated Prisma input types admit every relation and fail closed in the scanner; declared shapes are provable. |
| Keep the provider-rating lock/refresh in the admin mutation executor and pass identity's lock port into the Backoffice mutation gate. | Accepted | R12A freezes the consumers of `provider-review-rating.ts` and forbids Backoffice-public runtime imports of Identity-public; both constraints stay intact. |
| Make the ownership gate strict, delete its baseline and let the closed gates report the tolerated debt from one strict-regime fact. | Accepted; R18 | "R8 deletes all baselines"; a reappearing baseline fails every closed gate; a planted foreign access fails the gate. |
| The R12A run-only parity unit test reads its fixture from the R12A entry revision. | Accepted | R12A is closed and its scan checks no behavioral-test bytes; the live test evolves with `AdminService`'s constructor. |
| `identity/public/user-lifecycle-lock.ts` stays identity's public helper used by other contexts. | Accepted | It is identity's own SQL on its own `User` row in identity's public folder; the owner performs the statement. |
| Keep `livePlanAuthorizationWhere` on the frozen R3 collaboration port although no production code uses it. | Accepted; recorded | Removing a frozen contract method is a contract change; any non-owner use would fail the strict ownership gate. |
| Split the provider persona into `features/provider_portal`; keep the R9 manifest as the closed R9 record and pin the live delta (20th area, legal owner-API projection 172) in the R9 tests. | Accepted; R19 (spec M6, C9) | The provider is a separate account role; route paths and names are unchanged. Amending the manifest broke the backend R3 scope gate, which validates the historical manifest (fixed in `88e6c9c7`); closed manifests are never re-registered. |
| Split god files into same-library parts; a class too large for one file becomes a private core plus flow mixins. | Accepted; R19 (spec M6) | Public class names, imports, privacy and overridability are unchanged; session and account deletion stay one mixin because they are mutually recursive. |
| Do not split `main.dart` (723 -> 721 lines). | Accepted | It is the composition root, touched only for one import; the <= 700 target belongs to the god-file row, and a split would change the R9 composition sources for no boundary gain. |
| Move `QuoteFinanceContext` to finance although no lib code uses it. | Accepted; recorded | The spec moves it out of `shared/`; deleting tested product code is a product decision. |
| Put the money invariants in pure Finance domain policies that return violations; services map them to the unchanged HTTP errors. | Accepted; O3, R11 item 4 | The domain stays framework-free; "mandatory category" stays a schema/DTO invariant (non-null FK, DTO, plan-scope check), since a domain check would be dead or change the error of a blank id. |
| Forbid runtime Prisma and the persistence layer in every `domain/` (depcruise `domain-no-runtime-prisma`). | Accepted | The original purity law has two halves; only `@nestjs/*` was enforced. |
| Evaluate every live authorization filter and the read it guards in one RepeatableRead (or Serializable) snapshot. | Accepted; exit-review fix | Splitting the former single statement into two autocommit statements let a revocation committing in between pass; the AST guard keeps every call site on a snapshot client. |
| No real-phone QA for R19. | Recorded | R19 changes no Mobile behavior (analyze clean, 1164 tests, routes identical); no device is available here and phone acceptance is not claimed. |

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

| Decision | Status | Rationale |
| --- | --- | --- |
| Close IDs 10 and 13 by publishing the unchanged Finance wedding-cost projection from the Finance owner public boundary. | Local Completion | Three consumers use the public path; exports and behavior are byte-identical; no facade or duplicate remains. |
| Close IDs 12 and 14-17 with one synchronous, transaction-bound Messaging lifecycle port backed by the existing private implementation via a single `useExisting` alias. | Local Completion | Five consumers hold the port; nine calls pass the exact `tx`; no direct lifecycle import, dual path, or fallback exists. |
| Close IDs 19 and 20 by publishing the pure Marketplace provider-access policy and retiring the historical Identity exception. | Local Completion | Seven consumers use the public path; copies, re-exports, and alternate paths are rejected; exception authorities are 0. |
| Delete the dependency baseline, make `architecture:imports` strict, and retire the `architecture:imports:baseline` generator. | Local Completion | Direct unignored depcruise is 353/1420/0; the scanner rejects the ledger's existence, so a generator could only produce a rejected artifact or invite `--ignore-known` back. |
| Bind governance gates to repository identity (Git top level extending the immutable base commit, base-relative overlay) instead of absolute path, directory name, branch, exact HEAD and dirty working tree. | Accepted; spec section 18 | The pinned environment could not be reproduced by any other checkout or after any commit, so the laws were not independently verifiable; every governed byte stays fingerprinted and every rejection is re-proven from a fresh clone. |
| Canonicalize governance scripts to LF and register the historical mixed-ending bytes as reversible line-ending records. | Accepted | Git could not reproduce the registered bytes; the records prove nothing beyond line endings and registered splices changed. |
| Isolate architecture fixtures from the live dependency installation with a real, link-free copy of the Nest closure. | Accepted | Junctions from temp fixtures into the live `node_modules` had stubbed out installed packages in the original worktree. |
| Apply multer 2.3.0 and sharp 0.35.4 as a registered R12C security prerequisite with an approved lock lineage. | Local Completion | Registry advisories published after the R12B audit; fixes are within declared ranges; both audits are zero; R12B keeps validating its own approved lock. |
| Keep R12C local completion distinct from architecture-target and release completion. | Accepted boundary | Physical-ownership debt 385/781 remains for R13-R18; nothing left this machine. |
| Close the byte-lineage governance after Task 7 with a tracked closure record (phase, base commit, lineage commit `4bae5c6d`, frozen manifest hashes, lineage gates) and verify live invariants from then on. | Accepted; spec section 19 | The lineage regime forbids any change to a governed byte without a mutable re-registration, which is a deferred obstacle rather than a guarantee; the lineage stays provable at the lineage commit (re-run by the portability suite), nothing is baselined or ignored, and governed files become ordinary reviewed code. |

## Modular Monolith R12B — Local Completion — 2026-09-06

R12B is complete locally.
Dependency debt is 9.
Ownership remains 385/781.
The architecture target remains incomplete.
R12C implementation followed on 2026-09-13 (see above).
No commit, push, merge, deployment, production mutation, remote CI,
provider delivery, phone acceptance, or release is claimed.

| Decision | Status | Rationale |
| --- | --- | --- |
| Publish the unchanged wedding-location implementation from the Planning owner public boundary and remove the legacy path. | Local Completion | Exactly seven declared consumers use the public path. Source parity, behavior, and predecessor reconstruction pass without a facade, fallback, duplicate, route, payload, or runtime change. |
| Own local-plan nested task and guest DTO shapes inside Onboarding. | Local Completion | The two local DTOs are exact class-name re-expressions of the immutable API DTOs. External keys, decorator order, accepted/rejected values, and nested transformation behavior remain unchanged. |
| Retire only R12B dependency records `7-9`, `11`, `18`, and `21-22`. | Local Completion | The dependency ledger is `16 -> 9` with additions `0` and unrelated removals `0`; ownership remains byte-identical at `385/781`. R12C retains the remaining nine records. |
| Keep R12B local completion distinct from architecture-target and release completion. | Accepted boundary | Task 5 and the Task 6 candidate review are approved; activated exact-state re-review remains mandatory. No Git, deployment, provider, phone, production, remote-CI, or release evidence is implied. |

## Modular Monolith R0 Decisions - 2026-08-11

| Decision | Status | Rationale |
| --- | --- | --- |
| Adopt `ARCHITECTURE.md` as the canonical modular-monolith human contract with 13 exhaustive business modules, one physical owner per Prisma model, public-only cross-context consumption, an acyclic Nest graph, and no `forwardRef()`. | Accepted; R0 governance active | A single contract keeps the later machine-readable registry, dependency gates, Backend ports, and Mobile boundaries aligned while incremental source moves preserve runtime behavior. Platform owns `IdempotencyKey` and `OutboxEvent` but is not a business module. |
| Keep `WeddingPlan` physically owned by planning and treat Finance's direct `WeddingPlan.estimatedBudget` write as temporary baseline debt. | Accepted; removed in locally completed R4 | R4 replaced the write with the singleton Planning public write port and passed the caller's explicit transaction client unchanged. Ownership covers Prisma roots, relation traversal, nested writes, and every raw-SQL table; unresolved query shapes are debt, not permission. The exact debt was deleted from the baseline rather than converted into an exception. |
| Preserve completed P2 checkpoints, pause further P2 implementation by owner direction, and activate P3 R0 Governance on `modular-monolith`. | Completed; superseded by active R1 execution | R0 established governance with zero application-source moves and closed with all documented local and remote gates green at candidate `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. The later same-branch R1 decision below now governs execution. |
| Keep the tracked R0 receipt local-check-only and resolve immutable candidate identity and CI status from pull-request/workflow metadata. | Accepted | Back-writing a candidate SHA or changing CI result into the tracked receipt would make that document self-referential and stale. |
| Continue R1 and later modular-monolith phases locally on the same `modular-monolith` branch without intermediate merges, anchored to R0 candidate `94b677b7b8e2219e0db2cbc553fa3d26b4876456`. | Accepted; R1 locally completed | Owner direction on 2026-08-12 supersedes the merge-first execution assumption. Every task requires automated gates, managed server smoke, independent review/remediation, a clean local checkpoint commit, and owner application testing before continuation. Those R1 checkpoints passed on 2026-08-13. PR #76 remains unchanged until a separate push decision. |
| Close R1 only after the final local gates, full managed smoke suite, independent review, and owner application checkpoint; remove only the phase-specific `r0-scope` CI job while retaining its local script as historical evidence. | Accepted; R1 locally completed | The target platform/shared-kernel layout, full managed smoke, independent source/runtime review, and owner phone checkpoint passed on 2026-08-13 without route, schema, migration, Mobile/Admin source, or deployment changes. A future push of this branch is a combined post-R0 candidate, so the obsolete phase-specific job must not certify it as the immutable R0 diff. Remote CI remains unclaimed until a separately authorized push. R2 then used this accepted R1 closeout as its immutable base. |
| Plan R2 as a native Prisma schema folder split from immutable R1-closeout base `8ba0db78ac669bd6d17de878b77a4d1e6c5e542d`, with one file per current model owner plus `_base.prisma`. | Accepted; R2 locally completed | The manifest agrees with the ownership registry at exactly 52 models, 41 enums, 14 files, and 76 unchanged migrations. Empty migrate diff, equal normalized DMMF, frozen seed/migrations/generated contracts, exhaustive local gates, immutable Docker runtime, owner phone acceptance, and independent review passed. |
| Keep `prisma/seed.ts` byte-identical in R2 and copy `prisma.config.ts` into both Backend Docker stages. | Accepted; R2 locally completed | Per-module seeds require later business modules and remain deferred. The seed is byte-identical; the two exact config-copy lines make both image stages discover the native schema folder without a deprecated package fallback or schema compatibility copy. Image inspection, startup migration discovery, probe, and cutover passed. |
| Bind the R2 phone cutover to immutable candidate `b40e2961c4c2e0c1e48ebdf1b4eff8444bc1d63f`, preserve the stopped R1 rollback, and accept only an explicitly R2-configured client result. | Accepted; R2 locally completed | The first phone attempt used an old loopback R1 URL and produced no R2 request, so it was not treated as Backend evidence. The separately packaged R2Local APK targeted the verified LAN endpoint; health, device reachability, successful login/authenticated request audit, owner PASS, and independent review then closed the local phone gate. No credentials, tokens, environment values, or raw bodies were retained. |
| Execute R3 as a strict demand-driven Nest public/internal/full boundary cut from immutable R2 closeout base `6b06eb096aca8cc6684d365d16e05d4cd8529898`. | Accepted; R3 locally completed | All 13 contexts are covered without speculative ports, concrete cross-context injection, duplicate registrations, platform debts, retired provider edges, `forwardRef()`, or module cycles. Provider identity and scope gates are TypeChecker-resolved and fail closed; schema, APIs, migrations, Admin, and deployment contracts remain frozen. |
| Treat the phone-discovered session-restore race as an exact R3 runtime blocker and correct it at the Mobile request-generation boundary. | Accepted and locally verified | Account-session and selected-context generations are independent. Context bootstrap may not discard a successful `/api/v1/auth/me` restore, while stale account and stale-context responses remain rejected. A real force-stop/relaunch restored the dashboard with no restore failure or logout; the correction is limited to the ApiClient and its regression plus reviewed scope/receipt files. |
| Bind final R3 phone evidence to runtime candidate `dfc5488cf30d4eb36dc2d72c618b2442f34ea058` and the separately packaged R3Local APK. | Accepted and locally verified | The exact image revision, local/LAN health, safe logs, APK package/hash, owner login/dashboard result, and independent ADB force-stop/relaunch all passed. Prior R3 and R2 artifacts remain preserved for rollback. No push, merge, or remote CI is claimed. |
| Route Finance budget replacement through one Planning-owned write port from immutable R4 base `502b181a2ce624458fd7eae064f194497ec0151e`. | Accepted; R4 locally completed | `MoneyBudgetService` passes its existing transaction and unchanged budget input through `PLANNING_BUDGET_WRITE_PORT` to the sole `WeddingPlanBudgetWriter`. Singleton `useExisting` identity, order, error identity, and the absence of another transaction or compatibility facade are machine-checked. Ownership decreased exactly from 386/782 to 385/781. |
| Bind R4 runtime and phone evidence to application candidate `536890ccafcabebcd4d095a33c014933d6451fdb` and the preserved R3Local APK. | Accepted and locally verified | The immutable R4 image, protected probe/cutover, local/LAN health, zero restart/OOM state, safe logs, owner Money save/reload/force-close result, and independent review passed. The R3 runtime remains preserved for rollback. No push, merge, PR mutation, deployment, or remote CI is claimed. This row records the R4 closeout boundary before the separately approved R5 plan below. |
| Consolidate Identity source under `modules/identity` from immutable R5 base `9dab73acdc187a4a18d8a675713d8ded40a16d02`. | Accepted; R5 locally completed | All 44 files moved one-to-one from `auth`, `users`, `me`, and `contexts` into exact public/internal/api slices, and all four old roots are absent. Dependency evidence is exactly 31 records after retiring 58 authorized relocation debts; ownership remains 385/781. Routes, provider identity, auth/OTP/session/context behavior, schema, Mobile, Admin, and deployment stayed frozen. |
| Pin the Prisma Config transitive merge implementation to patched `deepmerge-ts` 8.0.1 while retaining Prisma 6.19.3. | Accepted and locally verified in R5 Task 5A | CVE-2026-40345 affects the previously resolved 7.1.5 package and both required audits were red. A permanent checker now proves exact package/lock and installed identity, recursive ordinary merge semantics, input/primordial immutability, safe output, and authenticated worker completion; R5 scope rejects five package/lock near-misses. Prisma major/downgrade, audit suppression, and force-fix were rejected. Remove the override only when the pinned Prisma line resolves a non-affected merge package without it and the complete security/equivalence/audit/smoke/runtime gates pass. No application behavior, schema, phone runtime, push, merge, PR, deployment, remote CI, or R6 scope changed. |
| Bind final R5 runtime and phone evidence to application candidate `8cfee451a76bb17e20d278a1646dde4387bf7b18`. | Accepted and locally verified | The exact immutable image, probe/cutover, local/LAN health, zero restart/OOM state, safe logs, authenticated owner login/read/write/close-reopen result, and sanitized request audit passed. The independent Task 6 review found one documentation-policy gap in three smoke fixtures; it was closed with an owner-authorized, hash-pinned, production-contract-only exception and permanent gates before the candidate commit. R4 remains stopped and preserved for rollback. No push, merge, PR mutation, deployment, remote CI, or R6 work is claimed. |
| Remove Collaboration's direct concrete OpenWA transient-sender dependency through one Identity-owned public delivery port from immutable R6 base `ce0c0d19824bff79d91417e2fe4617914c6bcd70`. | Accepted; R6 locally completed | At candidate `cefe07a76b0e615d4fecbb666514d9a2b87a7d37`, the provider-neutral Identity token, input, interface, and uncertain/rejected errors are the only public contract. The sole private adapter calls the unchanged platform sender once and maps only its two known concrete errors; Collaboration imports only the Identity public module. Invitation copy, branch order, statuses, metrics, logs, persistence, timeouts, retries, schema, clients, and deployment stayed frozen. Full local gates, immutable runtime, and authenticated phone sharing/restore passed with OpenWA disabled truthfully and R5 preserved for rollback. Real-recipient OpenWA delivery, R7, push, merge, PR mutation, deployment, and remote CI remain outside this completion. |
| Relocate all 18 legacy Collaboration source files one-to-one into `modules/collaboration` from immutable R7 base `31ea5324007fc71fa4b3590fbb98a454ee1deaa7`. | Accepted; R7 locally completed | At candidate `aafb47ea1742c278f6a5ed24799ada7bc23721b0`, all 18 files are in the final API/internal/public boundary and both old roots are absent. The four-export snapshot boundary, constructor/controller/decorator identities, optional realtime dependency, routes, permissions, history, transactions, Arabic/errors, schema, Mobile, Admin, and deployment stayed frozen. Dependency debt is exactly 22 and ownership remains 385/781. Exhaustive gates, cumulative independent review, immutable runtime, and the phone create/reissue/read/cancel/restore journey passed; OpenWA remained disabled and R6 is preserved for rollback. No push, merge, PR mutation, deployment, remote CI, or R8 work occurred. |
| Remove the final two project-owned Nest globals from immutable R8 base `c2b728bfe54304562923facfb6094e0de04c0b27`. | Accepted; R8 locally completed | At candidate `464d785a0440b8494768a26a70ac1de73a4bff2c`, `PrismaModule` and `ConversationRealtimeModule` are ordinary modules, all 21 Prisma and both Realtime consumers import explicitly, and singleton/`useExisting` identities remain exact. Project-owned globals, missing importers, duplicates, `forwardRef()`, and cycles are zero. The existing `@nestjs/schedule@6.1.3` and `@nestjs/throttler@6.5.0` dependency-owned global behaviors remain exact and frozen. Exhaustive gates, independent reviews, immutable runtime, and the owner-authorized 26-phone task/chat/restore journey passed; R7 is preserved for rollback. No push, merge, PR mutation, deployment, remote CI, or R9 work occurred. |

### Existing-Test Change Policy

Existing behavioral assertions, expected values, fixtures, Arabic/error
contracts, and setup semantics are frozen. A later move phase may make only
reviewed mechanical import/export/require edits, moved-source path-literal
edits, test-file moves, and DI token wiring edits required by that move. Any
other existing-test change is a stop signal and requires explicit review.

R0 adds tests and does not edit existing behavioral tests.

## Current Decisions Addendum - 2026-06-14

| Decision | Status | Rationale |
| --- | --- | --- |
| Treat Flutter SQLite as a mobile cache/sync layer only. | Accepted | PostgreSQL remains the backend source of truth; SQLite supports offline UX and selected queued writes without storing credentials or replacing server data. |
| Keep provider marketplace work as planning/reference and quote-lead flows. | Accepted | Provider listings, favorites, reviews, quote requests, provider dashboard, and admin approval exist, but paid booking, deposits, provider settlement/payment-processing status, and financing remain excluded. The user's manual CostPayment ledger is part of planning, not payment processing. |
| Split production domains only after Compose/Dokploy/NPM are aligned. | Accepted | Current Dokploy Compose has Backend on `8093`, Admin Web on `8094`, and a separate allowlisted public static site on `8095`. The public site owns privacy, support, invite, and mobile-link association routes; it is not Flutter Web. A Flutter web service remains undefined and requires a later explicit routing, caching, CORS, artifact, and release decision. |
| Meta WhatsApp OTP remains the target official production channel, while external activation is pending. | Accepted and implemented in code; external activation pending | The backend sends approved authentication templates through Meta Cloud API, never echoes production codes, and fails boot on incomplete channel configuration. The current deployment selects the separately documented temporary OpenWA exception; it is not evidence that Meta activation or the remaining OpenWA device/stability gates passed. |

## Current Decisions Addendum - 2026-07-06

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow conversations only when attached to a real quote request. | Accepted | Messaging is limited to the requester and the provider account on that quote. Open or unsolicited messaging remains excluded. |
| Use one prelaunch money domain: general budget, categories, `WeddingCost`, `CostPayment`, and `PaymentSchedule`. | Accepted and implemented | `Expense`, `FinancialCommitment`, `FinancialPaymentRecord`, `FinancialInstallment`, their routes, caches, operational seed/load tools, and user-facing concepts were removed rather than kept as compatibility paths because there are no production users. Every cost belongs to one category; payments and schedules belong to one cost. |
| Calculate every money surface from the canonical cost ledger. | Accepted | Confirmed cost is the sum of non-cancelled cost totals. Paid is the net append-only payment ledger after reversals. Outstanding is confirmed cost minus paid, and remaining budget is the general budget minus confirmed cost. A schedule is only a reminder and contributes nothing until paid. |
| Keep category allocation separate from the general budget. | Accepted | A null general budget remains unset and category allocations never become a fallback general budget. Budget-first setup may save no categories; any positive category allocation requires a non-null general budget, and total allocations may not exceed it. |
| Make finance sharing understandable. | Accepted | `canViewMoney` controls all private money reads and `canManageMoney` controls all money writes. Hidden values are absent, not returned as misleading zeros. |
| Use short-lived access tokens with rotating refresh tokens. | Accepted and implemented | Access JWTs default to 15 minutes. Opaque 30-day refresh tokens are hashed at rest, rotated transactionally, and revocable per session or per user. Terminal rows remain for 30 days after their applicable expiry or revocation event for reuse detection and incident evidence, then an hourly single-replica cleanup removes them. |
| Keep one active documentation source per area. | Accepted | `docs/README.md` owns the source map. Historical plans and reports live as `.md.txt` under `docs/archive/` and must not compete with current docs. |

## Current Decisions Addendum - 2026-07-10

| Decision | Status | Rationale |
| --- | --- | --- |
| Require verified phone ownership before account or invite access. | Accepted and implemented | Registration creates no User/session before OTP completion; legacy unverified sessions are revoked and JWT/refresh/password login remain blocked until phone proof. |
| Persist invite-token fingerprints and enforce delegated permission ceilings. | Accepted and implemented | Raw external tokens exist only in the create response, invite consumption is atomic, and a delegated inviter cannot grant effective authority above their own. Email-only invites remain disabled until verified-email identity exists. |
| Scope Flutter state by account and selected plan. | Accepted and implemented | Account identity changes dispose the complete data-provider subtree; plan changes replace plan-sensitive providers without rebuilding navigation. Late responses from disposed providers cannot repopulate another session. |
| Bind offline replay to its originating session. | Accepted and implemented | Replay captures the cache owner, session generation, and access token. Logout or account change stops the old loop, prevents the new token from authorizing an old write, and restarts only the new account queue. |
| Keep guest budget optional through dashboard entry. | Accepted and implemented | Saving an empty quick-setup budget records an explicit skip; completion accepts a budget or that skip. A skipped or null budget remains unset and category allocations must not silently replace it. |
| Fail mobile Release closed. | Accepted and implemented in source | Product builds require an explicit public HTTPS API origin, reject development login bypass, and Android refuses missing/placeholder/nonexistent signing configuration instead of falling back to debug keys. iOS runs the equivalent API gate before its Flutter build. |
| Keep native launch identity consistent with the live design system. | Accepted and implemented | Android adaptive/legacy icons and splash plus iOS AppIcon/LaunchImage use the same burgundy, gold, ivory, and celebration-spark mark as the in-app brand. Generated sizes are tested, while final store and device review remains a release gate. |
| Separate liveness from readiness. | Accepted and implemented | `/live` and `/health` prove only that the process responds; `/ready` verifies PostgreSQL and required Redis/media dependencies with bounded timeouts and redacted failures. Production containers use readiness before receiving dependent traffic. |
| Use a transactional PostgreSQL outbox before adding an external broker. | Accepted and implemented | Notification and chat availability events commit with their domain rows. Workers use `FOR UPDATE SKIP LOCKED`, stale-lock recovery, bounded retries, failed-event retention, metrics, and alerts. Immediate Socket.IO delivery remains the low-latency path; outbox availability events repair commit-to-publish crashes. |
| Bind and expire idempotency keys. | Accepted and implemented | A user key is valid only for one method, concrete target, and canonical body. Identical retries replay safely, mismatches return `409`, pending reservations and completed responses have bounded lifetimes, and cleanup uses a cross-replica PostgreSQL advisory lock. |
| Keep provider rating caches transactionally exact. | Accepted and implemented | Review create/update/delete and admin publish/hide serialize on the Provider row, mutate the review, and derive the published-only count/average in one transaction. Account deletion explicitly refreshes every surviving provider whose review cascades would otherwise make the cache stale. |
| Validate provider prices at the shared money boundary. | Accepted and implemented | Service base prices, package prices, quote-offer amounts, admin service prices, and marketplace price filters share one `numeric(14,2)` validator. Overflow and excess precision fail as `400` before persistence instead of becoming PostgreSQL rounding or `500`. |
| Require password + phone OTP and server-bound browser sessions for administration. | Accepted and implemented | General login paths cannot mint admin assurance. Every access JWT has a signed `application` or `admin` scope; product and Chat guards reject admin-scoped tokens, while admin guards require the admin scope, MFA, and a live server session. Access tokens stay in memory, refresh tokens stay in rotating HttpOnly/SameSite cookies, and refresh/logout invalidate the prior admin JWT immediately. |

## Current Decisions Addendum - 2026-07-12

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow a temporary hardened OpenWA OTP transport for the risk-accepted MVP, while retaining Meta as the target channel. | Accepted and locally verified; limited rollout gates remain | Aarast never calls stock `send-text`, applies durable HMAC-keyed phone/IP/global quotas, and fails readiness unless a connected session exposes the transient contract. The pinned fork, QR link, no-persistence proof, protected restart, and live self-recipient request/verify flow pass. An independently owned second recipient and 24-hour stability observation remain mandatory before widening the MVP rollout. |

## Current Decisions Addendum - 2026-07-23

| Decision | Status | Rationale |
| --- | --- | --- |
| Make conversation identity the provider relationship context, not one request. | Accepted and implemented | `PLAN` is unique by `weddingPlanId + providerId`; `ACCOUNT` is unique by `accountRequesterUserId + providerId`. Every QuoteRequest is linked to exactly one conversation and multiple requests share its timeline. |
| Derive conversation authorization live from plan/provider relations. | Accepted and implemented | Plan owners, explicit `SharedMember.canManageProviders` members, the account requester, and the linked provider account are authorized by current rows on every REST/Socket operation. Role defaults initialize the stored provider flag only on a new invitation; direct member creation is fail-closed, and the current stored boolean is authoritative across provider APIs and conversations. `ConversationParticipant` stores only personal state and is never an authority source. |
| Keep quote lifecycle updates as system events, separate from human messages. | Accepted and implemented | `ConversationEvent` stores idempotent request/offer events without price or contact data. Offer expiry is derived from `validUntil`; unread counts include human messages only. |

## Current Decisions Addendum - 2026-07-15

| Decision | Status | Rationale |
| --- | --- | --- |
| Keep payment schedules non-reserving and use one payment-reminder date. | Accepted and implemented | `WeddingCost` has no due date; `PaymentSchedule.dueDate` is the only payment-reminder date. A pending schedule neither deducts nor reserves money and cannot block a direct payment. Each reminder amount is checked independently against the row-locked outstanding cost on create/update, and any payment that completes the cost cancels the remaining pending reminders. |

## Current Decisions Addendum - 2026-07-17

| Decision | Status | Rationale |
| --- | --- | --- |
| Send participant invitation links from Aarast and bind access to token plus verified phone. | Accepted and implemented in source | Invite creation remains pending until the recipient proves the exact invited phone. The backend sends a generic private link through the hardened transient OpenWA contract, reports uncertain delivery honestly, and sends OTP only after token-phone matching. A first-time contributor creates a real application password with that same verified invite OTP; no hidden random password or second registration OTP is allowed. Verification only reveals the invitation, role, and permissions; the participant must explicitly accept or reject before any membership is created or the shared plan opens. Manual `wa.me` composition was removed so the owner is not responsible for delivering the link. |

## Current Decisions Addendum - 2026-07-20

| Decision | Status | Rationale |
| --- | --- | --- |
| Create one planning cost when a provider offer is accepted. | Accepted and implemented in source | Offer acceptance and `WeddingCost` creation are one serializable, idempotent transaction keyed by unique `quoteOfferId`. The cost starts unpaid, uses the plan currency and provider/service context, and falls back to `أخرى` only when no logical budget-category match exists. This creates no payment, payment schedule, task, booking, settlement, or payment-processing state. |

## Current Decisions Addendum - 2026-07-24

| Decision | Status | Rationale |
| --- | --- | --- |
| Fail closed on weak production JWT secrets and serialize authentication attempt ceilings at the database row. | Accepted and implemented in source | Production startup rejects missing, placeholder, short, repetitive, or low-entropy JWT secrets without exposing them. OTP comparison, failed attempts, exhaustion, and consumption are committed under one row lock; password attempts reserve admission under a row-locking upsert before credential comparison so concurrent replicas cannot bypass the configured ceiling. |
| Serialize every quote decision with one request-first lock order and live permissions. | Accepted and implemented in source | Accept, reject, provider update, and requester cancel lock QuoteRequest before QuoteOffer, re-read the current state, and use an expected-state write. Acceptance also locks and rechecks provider plus money authority inside the same transaction, so revocation or another terminal decision cannot leave cost/link rows attached to a non-accepted offer. |
| Make conversation revocation transactional and reactivation explicit. | Accepted and implemented in source | Send and mark-read recheck live authority plus the active participant under locks in one serializable transaction. Sending and reading never clear `revokedAt`; only an explicit provider-management grant may reactivate a participant. A provider joins only through its own access, so customer reads preserve the truthful `providerJoined: false` read-only state. |

## Current Decisions Addendum - 2026-07-25

| Decision | Status | Rationale |
| --- | --- | --- |
| Derive account contexts from current ownership and membership rows. | Accepted and implemented in backend source | One authenticated User may expose owner contexts from `WeddingPlan.ownerUserId`, contributor contexts from `SharedMember`, and one provider context from `Provider.userId`. `User.role` and `appRole` are not sufficient context authority, no role-membership table is added, and every validation rebuilds permissions from current database rows. |
| Never replace an invalid active plan automatically. | Accepted and implemented in backend source | `GET /api/v1/wedding-plans/active` returns the explicitly selected accessible planning plan or null. Deleted, archived, or revoked selections never fall back to a different plan; the future Flutter context selector owns the next explicit choice. |

## Current Decisions Addendum - 2026-07-29

| Decision | Status | Rationale |
| --- | --- | --- |
| Keep one provider category catalog with groom/bride discovery flags. | Accepted and implemented in source | What the customer requests remains the shared category identity. `showForGroom` and `showForBride` separate visibility without duplicating provider data, while service titles and later tags carry specialization. Flutter derives the active view only from `AccountContextController.selectedContext.persona`. |
| Model Yemen governorates and districts separately from legacy City. | Accepted and implemented in source | The OCHA Yemen/CSO HDX v01 reference provides 22 first-level units including Amanat Al Asimah and 335 districts. Stable codes and coordinates live in database tables and public read APIs; the existing City relations remain temporarily compatible and are not relabeled as governorates. |

## Current Decisions Addendum - 2026-07-30

| Decision | Status | Rationale |
| --- | --- | --- |
| Make `AuthController` and `SessionTeardownCoordinator` the single Logout/session-expiry termination boundary. | Accepted and implemented in mobile source | The session state machine is `checking`, `authenticated`, `terminating`, `terminationFailed`, and `unauthenticated`. Logout increments the session operation generation, removes the in-memory user, enters `terminating`, and notifies the widget tree before awaiting cleanup. Credential capture is bounded to two seconds and every local cleanup stage to five seconds, so no dependency can leave the termination screen spinning forever. Local auth storage, account cache, and the account's push binding are cleared before remote auth revoke and push unregister run in parallel with a two-second deadline. The installation-owned guest draft is preserved for ordinary logout, confirmed session expiry, and restore rejection; confirmed account deletion may clear it. Successful migration and explicit double-confirmed discard retain their dedicated deletion contracts. A local failure or timeout exposes only a retry-safe termination screen; a remote failure or timeout never restores the old session. |
| Bind the persisted account context to its authenticated user. | Accepted and implemented in mobile source | Context persistence version 2 stores `version`, `userId`, and `contextKey` in the sensitive-value vault. A fresh authenticated session and full logout clear the prior selection. A multi-context account must choose again, a single available context may be selected directly, and cold restart restores only a same-user context that remains available in the fresh API result. A legacy raw key is migrated once when its user is known and is cleared if it is no longer valid. |
| Give the session and account-context gates ownership of authentication-driven entry navigation. | Accepted and implemented in mobile source | `AarastSessionTransitionGate` prevents Login or any Dashboard from being mounted while the session is `checking`, `terminating`, or `terminationFailed`. `AarastAuthFlowRedirector` consumes Login, Logout, expiry, and invite-entry intents once; `AccountContextEntryGate` owns the matching Dashboard entry after context resolution. Logout widgets only request `AuthController.logout()`. Effective route transitions are recorded centrally, while ordinary in-feature navigation remains local to its feature. |
| Use structured, privacy-redacted, memory-bounded mobile observability with optional Sentry delivery. | Accepted and implemented in mobile source; external acceptance pending | `AppLogger` uses logical categories rather than local `*.log` files, a Debug console sink, a 300-event/256KB/15-minute memory ring, and an optional Sentry sink. Identifiers are installation-salted hashes; tokens, credentials, contact data, headers, query values, and bodies are removed. Sentry errors are sampled at 100%, traces default to 100% in Staging and 10% elsewhere, and profiling, replay, screenshots, default PII, raw print/HTTP breadcrumbs, and request bodies are disabled. A diagnostic JSON attachment is generated in memory and sent only after explicit consent for that attempt. Live symbolication, access control, retention, and PII verification remain release gates outside the application code. |
| Keep the Firebase installation identity device-scoped across account Logout. | Accepted and implemented in mobile source | Logout immediately cancels the old account registration request, clears its in-memory binding, and gives a new session a fresh operation queue. It does not delete the device FID or FCM token; the captured old credentials are used only for the bounded server unregister. Token refresh and app resume revalidate the current account binding. The `FirebaseInstallations.onIdChange` bridge is intentionally not used because the current Flutter plugin dispatches that callback from a Firebase background thread on Android. |

## Current Decisions Addendum - 2026-07-31

| Decision | Status | Rationale |
| --- | --- | --- |
| Make contributor invite outcomes replay-safe and bind access to live membership. | Accepted and implemented in backend and mobile source | Acceptance and decline perform one authoritative terminal mutation and safely replay the result only to the same verified invitee without duplicate notifications. An accepted invite exposes `contextKey` only while its live `SharedMember` exists. Member removal revokes every matching live pending invite before deleting membership, and plan archive revokes all remaining live pending invitations, preventing stale links from restoring access. Flutter single-flights accept/decline, reconciles ambiguous responses, refreshes owner state while pending and at lifecycle boundaries, fails closed during context-authority refresh, and ignores out-of-order invite, access, plan, and dashboard results. |

## Current Decisions Addendum - 2026-08-02

| Decision | Status | Rationale |
| --- | --- | --- |
| Make stored `SharedMember` permission booleans the final contributor authority. | Accepted and verified locally in Backend source, tests, and the managed HTTP scenario | A role supplies defaults only when an invitation is created. Direct member creation stores explicit flags and fail-closed `false` values for omitted authorization fields. Later role changes preserve the stored booleans unless the request explicitly changes them, so `CONTRIBUTOR` or another role cannot silently re-grant a permission that the owner revoked. Every live read or mutation still requires a current membership and the current stored section permission. Staging deployment and native-device acceptance remain separate release gates. |
| Filter contributor live data per item in Backend, never by plan membership alone. | Accepted and verified locally across Backend read/write boundaries | A current contributor may receive only an item assigned to them or an item supported by their own created/completed contribution evidence, as applicable to that domain. Evidence from current or previous tenures may identify the same contributor's work, but it does not restore plan access or a revoked section permission by itself. Flutter receives the already-scoped result and must not hide plan-wide data after download. |
| Preserve contributor work as immutable, privacy-allowlisted snapshots. | Accepted; schema, source, isolated migrations, and managed runtime scenario verified locally | `ContributorHistoryScope`, `ContributorTenure`, and append-only `ContributionEvent` separate historical evidence from live entities. Each qualifying action records plan scope, stable contributor reference, tenure, section, entity type, action, bounded action-time snapshot, hashes, provenance, permission-policy version, authority version, and timestamps. Revocation appends a boundary but never re-snapshots a live row. Database constraints, dedupe keys, indexes, and an UPDATE/DELETE rejection trigger protect consistency. History responses intentionally omit live `entityId` links, and snapshots reject contact, credential, request, attachment, and free-form sensitive fields outside the entity allowlist. |
| Backfill legacy contribution history only from explicit evidence. | Accepted, isolated-rehearsal verified, and deployed | The original migration sets a cutover coverage timestamp and attributes only relationships proved directly by existing columns: task assignee, quote requester/creator, and invite creator while a matching current tenure exists. Repair migration `20260811180000_backfill_missing_contributor_history_scopes` creates a scope for any live plan missed by an older writer and reconstructs only directly evidenced active tenure. Accepted membership alone and old guest/money rows remain unattributed. Production revision `900897a90e8b030c7c3ddfdc55cc2669b64f2e87` completed all 76 migrations with 15 live plans, 15 linked scopes, and zero missing scopes, lifecycle mismatches, or missing tenures. |
| Separate leaving one plan from deleting the Aarast account. | Accepted and verified locally across Backend HTTP and Flutter state tests; native-device acceptance pending | `DELETE /api/v1/wedding-plans/:weddingPlanId/members/me` is a transactional, replay-safe membership exit bound to the exact `expectedMemberId` and `expectedAuthorityVersion`: a delayed request cannot delete a newly invited tenure. It revokes matching pending invites, closes the tenure, clears the selected active plan, removes live membership/conversation/notification access, and retains immutable contribution events. Flutter first stores a durable installation/user/plan/membership-bound cleanup marker, quarantines ambiguous outcomes, replays before contexts load, clears the exact local plan graph, and removes the marker only after filtered contexts commit. |
| Make central account deletion recoverable after a lost response without crossing the administrator realm. | Accepted, verified, and production-deployed; native process-death acceptance pending | The client persists one secure stable deletion request before sending and immediately unmounts all dashboards. The deletion transaction commits an immutable anonymous `AccountDeletionReceipt` hash with erasure. Ordinary accounts erase the User; a dual administrator/application row erases only its app credential/profile/data and `APPLICATION` sessions while retaining the administrator identity and `ADMIN` sessions. A throttled unauthenticated status endpoint returns only `DELETED`, `PENDING`, or `NOT_STARTED`; the client never replays DELETE while status is `PENDING`, and may restore a still-live account only after a definitive rejection plus `NOT_STARTED`. Confirmed deletion uses the one central teardown path and removes only that user's pending plan-leave markers. Application revision `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` carries the server correction; the affected physical-device path remains an explicit acceptance gate. |
| Keep contributor create actions inside responsive section cards. | Accepted; implemented in current mobile source, physical-device acceptance pending | A full-width Arabic `FilledButton.icon` belongs below the section summary and is shown only for a current write permission. A nested or clipped `FloatingActionButton.extended` is not used. The contract includes narrow RTL screens and enlarged text, while final device review remains required. |

## Current Decisions Addendum - 2026-08-07

| Decision | Status | Rationale |
| --- | --- | --- |
| Keep one active documentation source per concern and archive superseded plans as `.md.txt`. | Accepted and completed; ongoing discipline | `docs/README.md` is the inventory authority and `docs/HANDOFF.md` is the continuation entry point. The old release/remediation plans, Premium roadmap, and `docs/superpowers/` working notes are preserved under `docs/archive/2026-08-modernization-consolidation/`; they must not be edited as current truth. Temporary compatibility tombstones are allowed only while a known test or tool still opens an old path, and each tombstone must name its removal gate. |
| Retire the Royal/Premium visual direction and establish a quiet semantic design contract. | Accepted; ornamental implementation retired and semantic migration in progress | Crowns, ornamental gradients, glow, glass, decorative shadows, card-heavy hierarchy, and feature-owned Royal/Premium palettes remain forbidden. The later Soft Royal decision permits restrained semantic burgundy and champagne roles; it does not restore the retired implementation. Mobile and Admin converge on visible context, one primary action, honest states, responsive RTL behavior, and accessible operational surfaces. |
| Protect the baseline before remediation. | Accepted and completed; branch cleanup recorded | The former `codex/snapshot-money-redesign-20260807` and `codex/aarast-modernization-20260807` branches were removed during the explicit cleanup after their relevant history was incorporated or preserved. The complete pre-modernization recovery state remains in the verified `_ai_backups/aarast-before-modernization-20260807.bundle`. Canonical work is promoted through reviewed `main` history; temporary release branches are not long-term sources of truth. The bundle is recovery evidence, not a release candidate. |

## Current Decisions Addendum - 2026-08-09

| Decision | Status | Rationale |
| --- | --- | --- |
| Treat Plan Pulse as a deterministic product projection, not AI. | Accepted and implemented for Mobile P2 | Home selects one next decision from real task, guest, provider, and permitted money state. It never invents readiness, participants, reminders, or predictions. |
| Use one Plan Path signature and Focus Mode interaction grammar. | Accepted and implemented for Mobile P2 | Home, Tasks, and Guests share a thin truthful milestone path; primary creation forms begin with one decision, reveal secondary detail progressively, preserve drafts, and end with one action. This creates product identity through continuity rather than decoration. |
| Limit Wedding Day Mode to the operational event window and existing contracts. | Accepted and implemented for Mobile P2; physical-device acceptance pending | The route is offered only from seven days before the event through the day after, requires plan-view access, and uses real plan date/time/location, urgent unfinished tasks, responsible contacts, existing providers, and cached tasks. Missing provider phone data stays absent. No backend/schema, booking, payment, open messaging, or AI contract is introduced. |
| Resolve one global wedding stage from the real date. | Accepted and implemented for Mobile P2 | Plan chrome, Home, and smart creation ordering use one deterministic date-boundary engine. It does not infer readiness or replace factual task, guest, money, or provider signals. |
| Cache the full dashboard summary for offline event operations. | Accepted and implemented in Mobile schema version 8 | Wedding Day cold-start uses the last successful plan-scoped summary plus cached tasks. The cache preserves API-returned permissions, time/location, important items, and provider previews without adding queued writes or fabricated contact data. |
| Use one temporal grammar and one non-blocking form outcome. | Accepted and implemented for Mobile P2 | Tasks, notifications, and payment schedules share `الآن / اليوم / هذا الأسبوع / لاحقًا / مكتمل`; successful forms show a receipt with a truthful next action or return automatically, never a success dialog. |
| Manage flexible product references through versioned published catalogs. | Accepted and implemented in the current Backend, Admin, and Mobile working tree | Administrator edits create immutable revisions and remain drafts until explicitly published. Clients request a stable bootstrap version, cache only the last complete payload, and apply groom/bride plus customer/provider audience flags. Historical publication is the rollback mechanism. Roles, permissions, finance lifecycle states, payment semantics, and other security/domain invariants remain code-owned. |
| Keep Yemen geography typed and hierarchical instead of one generic list. | Accepted and implemented in the current Backend, Admin, and Mobile working tree | Governorate and District remain distinct from legacy City. `AdministrativeLocality` adds area, isolation, neighborhood, and zone below one immutable district, with optional same-district parentage and cycle rejection. Deletes soft-disable. Mobile preserves the order and manual entry when suggestions are missing. |

## Current Decisions Addendum - 2026-08-10

| Decision | Status | Rationale |
| --- | --- | --- |
| Restore Aarast's restrained burgundy, soft-white, and champagne Mobile identity without restoring the Royal/Premium implementation. | Accepted, implemented, Golden-verified, and physically reviewed on Android; exhaustive device/iOS gates remain | The 2026-08-07 decision remains authoritative for retiring crowns, ornamental gradients, glow, glass, decorative shadows, compatibility aliases, and card-heavy hierarchy. Mobile resolves a near-white canvas, deep burgundy brand/action roles, and contrast-bounded champagne accents from the V3 semantic source. Status colors retain their domain meaning. Admin Web remains outside this Mobile identity decision. |
| Give Home an asymmetric truthful hierarchy rather than equal metric tiles. | Accepted, implemented, Golden-verified, and physically reviewed on Android | Home keeps one solid-burgundy plan moment and one next decision, separates tasks/guests/providers into three compact signal cards, gives permission-aware Money the larger decision surface, and ends with the compact team strip. The final plan moment places date above location and scales within the responsive height contract. It does not invent readiness, repeat facts, or add a long decorative scroll. |

## Current Decisions Addendum - 2026-08-11

| Decision | Status | Rationale |
| --- | --- | --- |
| Serve privacy, support, participant invites, and mobile-link association from one fail-closed static image. | Accepted, implemented, and production-verified | `deploy/public-site` copies only an explicit asset allowlist. Privacy and support have no JavaScript or forms; invite JavaScript retains the token in page memory only. Production revision `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` deploys the content-addressed image on host `8095`; external TLS, security headers, allowlisted `200` routes, fail-closed unknown routes, and the Android association PASS. Apple association remains `404` until the real Team ID exists. |
| Keep Flutter Web separate from the current public domain service. | Accepted; future decision deferred | Port `8095` now belongs to the public static image. No Flutter web runtime is defined. Adding one later must choose its own artifact, route ownership, SPA fallback, caching, API origin/CORS, security headers, health checks, and release gates without weakening the public site's fail-closed routes. |
| Close the current Admin dependency audit through tested explicit upgrades. | Accepted and locally verified | Admin uses `react-router-dom@7.18.2`, `react-router@7.18.2`, and `nanoid@3.3.18`; the full `npm audit` reports zero vulnerabilities. Existing tests, type-check, build, route, honesty, and container-config gates remain mandatory, and automated force upgrades are not a substitute for compatibility verification. |
| Keep store claims bounded by implemented planning behavior and external release proof. | Accepted | Store copy may describe the optional general budget, categories, costs, recorded payments, payment dates, tasks, guests, permissions, provider quote flows, and feature-specific offline continuity. It must not claim debt/installment products, universal offline operation, absolute rounding guarantees, paid bookings, or payment processing. Public privacy/support/Android-association deployment is verified; store signing/upload, reviewed assets, Apple Team ID/provisioning, and physical-device acceptance remain external gates. |

## Initial Project Decisions

| Decision | Status | Rationale |
| --- | --- | --- |
| Use Flutter for the mobile app. | Accepted | Flutter supports cross-platform mobile delivery with a single codebase. |
| Use NestJS for the backend. | Accepted | NestJS provides a structured TypeScript backend suitable for modular API development. |
| Use PostgreSQL for the database. | Accepted | PostgreSQL is reliable for relational planning, marketplace, and financial records. |
| Use Git worktree workflow. | Accepted | Worktrees support isolated branches and safer phase-based development, but actual worktree usage must wait until the correct Git repository root is confirmed. Do not run git init, create branches, or create worktrees during Docs Foundation. |
| Run smoke tests before expanding core features. | Accepted | Smoke checks help confirm foundations are stable before more work is added. |
| MVP starts with Wedding Financial OS, not marketplace-first. | Accepted | The primary user problem is planning, money, obligations, and coordination. |
| Do not implement confirmed bookings, deposits, provider settlement/payment-processing status, payment processing, loans, credit, financing flows, or FinTech features in MVP. | Accepted | These flows require later validation, privacy review, legal review, operational readiness, and explicit approval before implementation. Manual CostPayment entries remain allowed because they record the user's own planning ledger and do not move money. |
| Financial data is private by default. | Accepted | Budgets, categories, costs, payments, payment schedules, attachments, and private tasks must not be visible unless `canViewMoney` allows it; mutations require `canManageMoney`. |
| Early provider/service features are planning references and quote/lead flows only. | Accepted | The MVP must not become marketplace-first, paid booking, confirmed reservation, or deposit-driven. |
| Phase 3 readiness order is Prisma + PostgreSQL, User, Auth, ownership context, then WeddingPlan. | Accepted | WeddingPlan ownership must be backed by persistence and real authenticated user context before domain implementation begins. |
| Do not use mock-auth shortcuts for WeddingPlan ownership. | Accepted | Ownership and privacy behavior must not be validated against fake or temporary identity assumptions. |
| MVP User model shape is minimal and phone-aware. | Accepted | The initial User design includes `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`; phone matters for Yemen-first usage and `passwordHash` stores hashed passwords only. |
| Initial User roles are USER, ADMIN, and PROVIDER. | Accepted | `PROVIDER` is reserved for later provider flows and must not trigger provider logic in the User model slice. |
| Initial User statuses are ACTIVE and DISABLED. | Accepted | The MVP needs a simple account availability state before richer lifecycle rules are introduced. |
| Ownership checks use authenticated user context. | Accepted | Future private modules must compare resource `ownerUserId` with the authenticated user id before returning or mutating private data; this prepares WeddingPlan without creating it yet. |
| Shared access is explicit and permission-based. | Accepted | Shared members may collaborate on a WeddingPlan, but financial visibility and task management must be granted through explicit SharedMember permissions; private financial data remains hidden by default. |
| Docs Foundation is documentation-only. | Accepted | The current phase may create or update Markdown files only and must not create app code, backend modules, Flutter screens, tests, migrations, Docker files, or deployment configs. |
| Use Docker for local service isolation and reproducible runtime environments. | Accepted | Docker is an operations decision for consistent local services and runtime behavior; it is not an implementation task in the current documentation phase. |
| Use Dokploy for VPS deployment and operations. | Accepted | Dokploy is the approved production deployment path. The current Compose runbook lives in `deploy/dokploy/`, using backend host port `8093`, admin host port `8094`, public-site host port `8095`, `PORT=3000`, `CORS_ORIGINS=https://aarast-admin.shadowgardn.com`, and `VITE_API_BASE_URL=https://aarast-api.shadowgardn.com`. The static public site does not call the API and is not included in the CORS allowlist. |

## Deferred Decisions

- Final mobile UI structure.
- Final admin dashboard implementation details.
- Final database schema and migration sequence.
- AI planning approach.
- Payment-processing, savings, or financing partnerships.
- Confirming the actual Git repository root.
- Permission model details for shared members.
- Attachment storage implementation.
- Exact persistence package/setup sequence.
- Exact User model constraints, indexes, and uniqueness rules.

## Modular Monolith R9 Decisions - 2026-08-30

| Decision | Status | Rationale |
| --- | --- | --- |
| Enforce owner-controlled public APIs for all Mobile cross-feature imports. | Accepted and implemented locally | Each of the 19 feature owners exposes one exact `<feature>_api.dart` surface. The strict scanner rejects deep cross-feature imports and unauthorized composition-root imports; final debt is zero with 159 legal records. |
| Treat an unimported guest plan as installation-owned rather than account-owned. | Accepted and implemented locally | Ordinary logout, restore rejection, and confirmed session expiry must not destroy a local plan that has not been imported. Confirmed account deletion may clear it; successful migration and explicit double-confirmed discard remain the only other approved deletion paths. |
| Close R9 with local checkpoints but without external integration. | Accepted and completed; R10 was later approved separately | The reviewed C5 application candidate and docs-only receipt checkpoint were committed locally. At R9 closeout, push, merge, PR mutation, deployment, remote CI, store release, S10 work, and R10 were stopped; the separately approved R10 local execution is recorded below. |

## R9 Local Completion Stop Boundary

R9 is locally complete at application candidate
`0f61bf283b455c4404182f5028ab78d2448053d3`; the docs-only checkpoint is the
commit containing this decision. These decisions are bounded to local
completion. Its stop before R10 was honored until the owner separately approved
the R10 design and plan; external Git, deployment, CI, store, and S10 actions
remain outside both receipts.

## Modular Monolith R10 Decisions - 2026-08-31

| Decision | Status | Rationale |
| --- | --- | --- |
| Make each Admin domain an owner-controlled feature with one exact public API and an acyclic allowlisted graph. | Accepted and implemented locally | The eight owners are Auth, Dashboard, Users, Providers, Catalog, Moderation, Notifications, and Audit. Cross-feature imports go only through `features/<owner>/api.ts`; Platform and Design System remain domain-free. The strict AST scanner and exact symbol surfaces prevent deep imports and public-API forwarding. |
| Delete each legacy Admin implementation when it moves; do not retain a facade, alias, duplicate, fallback, or compatibility layer. | Accepted and implemented locally | All 78 starting Admin source files have one fate and the old `api/auth/components/pages` roots are `0/0/0/0`. A compatibility layer would hide ownership and make strict closeout false. |
| Resolve cross-owner UI composition only at approved roots. | Accepted and implemented locally | `App.tsx` injects Dashboard statistics and Catalog loaders into Provider screens through narrow provider-owned structural projections. This preserves request order and UI behavior without a reciprocal Provider dependency or a Catalog/Provider cycle. |
| Keep the two existing-test transformations exact and location-aware. | Accepted and machine-enforced | Dashboard may split only its two mock targets without changing mock behavior; Pagination may add only the resolved expected import for the same seven page records. Across the full preserved set of 96 existing tests, every other fixture, assertion, Arabic/error value, and behavior remains frozen. |
| Distinguish local R10 phase closure from architecture-target or release completion. | Accepted | R10 passed the complete local Admin/Backend/Mobile/Prisma/runtime/docs matrix and independent review, but Backend debt remains 22 and 385/781. No commit, push, merge, deployment, remote CI, real WhatsApp delivery, live Push, or store release is implied. |

## R10 Local Completion Stop Boundary

R10 Admin phase is complete in the working tree from immutable R9 closeout
`e560e5784278907dd6bf565327c3abfa0c9b8cab`. Stop before commit, push, merge,
deployment, production mutation, remote CI, store release, or S10. A future
Backend debt-removal phase requires a separate decision, design, and plan.

That historical stop was lifted only for local R10 commit
`4d0d3ee91fb32d0432aa3bd69fe018d9a5a323b1`. It did not authorize push,
merge, deployment, remote CI, provider delivery, or release.

## Modular Monolith R11 Decisions - 2026-09-01

| Decision | Status | Rationale |
| --- | --- | --- |
| Version the post-R10 execution sequence as R11-R20 while preserving the 2026-08-04 final target. | Accepted and completed locally in R11 | Later R4-R9 plans narrowed their phase labels without updating the original external specification. The reconciliation keeps completed work, forbids false target-complete language, and restores just-in-time phase gates while live debt remains 22 and 385/781. |
| Treat dependency and ownership baselines as exact subtraction ledgers. | Accepted and active | Each future plan names the exact records it retires. Regeneration, count widening, unrelated subtraction, and early deletion are forbidden. |
| Allocate all ownership retirement to R13-R17 and reserve R18 for strict zero proof. | Accepted and active | R13, R14A Identity, R14B Collaboration, R15, R16, and R17 total 44/85, 60/78, 28/80, 10/19, 140/288, and 103/231, summing exactly to 385/781. R14B is blocked until R14A exits because the invite OTP owner port must exist first. The reason totals classify those same records; R18 enters at 0/0 and returns any residue to its owner. |
| Keep R11 documentation-only and require separate authority for R12A. | Accepted and completed locally in R11 | R11 aligned nine Markdown paths and verified the unchanged live debt. It changed no application source, schema, package, runtime, deployment, provider, or release state. |

## R11 Target Reconciliation Stop Boundary

Stop before R12A source work, any additional commit, push, merge, deployment,
production mutation, remote CI, provider delivery, store release, or S10. R12A
requires its own reviewed design, implementation plan, scope fence, and owner
approval.

## Modular Monolith R12A Decisions - 2026-09-02

| Decision | Status | Rationale |
| --- | --- | --- |
| Publish the four existing Backoffice authority/mutation contracts from `modules/backoffice/public` and the existing provider-rating mutation helper from `modules/marketplace/public`. | Accepted; R12A completed locally | The five implementations moved one-to-one, nine declared consumers now use owner-public paths, and all legacy files are absent. Export identity, guard order, transaction/lock order, permissions, errors, and behavior remain machine-checked without facades or fallbacks. |
| Retire only dependency records 1-6 and project only the Backoffice mutation-gate ownership path. | Accepted; strict local result verified | The ledger moves exactly `22 -> 17 -> 16`; ownership remains `385/781`. Baselines are subtraction ledgers and were neither regenerated nor widened. |
| Keep the remaining runtime-public and permission-contract handoffs explicit. | Accepted and active | R16 owns the Identity-to-Marketplace provider-rating infrastructure/public-port replacement. R17 owns publication of the pure Backoffice permission contract and deletion of the exact R1 pre-port exception before R18. |
| Reject duplicate decoded JSON members before Prisma package-security parsing. | Accepted; independently reviewed | Exact and Unicode-escaped duplicate R12A script keys failed through the live CLI. The rule applies to every JSON object, retains pinned package/lock fingerprints, and adds no fallback or package change. |

## R12A Local Closeout Stop Boundary

R12A is complete locally. Task 5 and Task 6 are APPROVED (`0/0/0`), and the
documentation, scope, identity, and final independent review gates passed.
Stop before commit, push, merge, deployment, production mutation,
remote CI, provider delivery, release, or R12B execution. After closeout, the
only next permitted work is separate R12B design/planning with owner approval.
