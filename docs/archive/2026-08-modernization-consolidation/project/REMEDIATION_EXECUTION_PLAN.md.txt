# Aarast Full Remediation Execution Plan

**Created:** 2026-07-26

**Branch:** `codex/aarast-full-remediation-v1`

**Baseline commit:** `569a1be0f01d198f3dcc997fa03ec73cb041ae77`
**Status:** active

## Purpose

This file is the execution contract for the current remediation effort. It is
based on the live code, routes, configuration, and tests. Older status and
release documents remain useful for product constraints, but they are not
evidence that an implementation currently works.

A phase is complete only when its stated behavior is covered by tests, all
required gates pass, and the remaining uncertainty is written down. A healthy
process, a successful build, or an agent statement is not sufficient by itself.

## Fixed Product Boundaries

- PostgreSQL is canonical; Flutter SQLite is an account-isolated offline cache
  and sync queue.
- Archived wedding plans remain readable to previously authorized users but are
  read-only and cannot become active.
- Provider marketplace and quote conversations remain planning and lead flows.
  This plan does not add bookings, deposits, payment processing, loans, credit,
  FinTech, AI, or unrestricted messaging.
- Financial data remains private unless explicit plan permissions allow access.
- One account may own plans, contribute to other plans, and have a provider
  profile at the same time. A single role field must not erase those contexts.
- Backend authorization is authoritative. UI guards may explain or hide actions
  but never replace backend checks.
- Production deployment, Git commits, and pushes require separate explicit
  authorization.

## Evidence Baseline

Before remediation changes on the branch:

| Gate | Result |
| --- | --- |
| `backend: npm run check` | PASS |
| `backend: npx prisma validate` | PASS, with the existing Prisma 7 configuration deprecation warning |
| `backend: npm test` | PASS: 417 tests, 416 passed, 1 existing skip, 0 failed |
| `backend: npm run build` | PASS |

The existing skip is not counted as new coverage and must not be increased to
hide a failure.

## Confirmed Defect Register

| ID | Confirmed current defect | Completion evidence |
| --- | --- | --- |
| `BE-LIFE-001` | Authorized users can still mutate an archived wedding plan through shared permission helpers. | Table-driven read/write tests plus backend gates. |
| `BE-PROV-001` | Non-active providers retain dashboard operations and customer quote data because ownership is checked without `Provider.status`. | Status-matrix tests for every provider dashboard capability. |
| `BE-PROV-002` | Non-active providers can retain provider-side conversation access and customer contact/budget data. | Conversation list/read/send tests for every provider status. |
| `BE-PROV-003` | Non-active provider accounts can retain provider-audience notifications, including historical alert text that duplicated customer identity. | Query-level visibility tests, dashboard-preview tests, live suspension smokes, and a historical PII scrub migration. |
| `BE-RACE-001` | Several permission checks and writes are not guaranteed to observe the same authorization state. | Deterministic transaction/concurrency tests. |
| `BE-INV-001` | Accepting a stale invitation can overwrite a newer membership state. | Membership-preservation and concurrent invite tests. |
| `BE-NOTIF-001` | Some stored notification preferences do not control notification creation, while unsupported channels can appear meaningful. | Preference behavior tests and an additive capability contract. |
| `CTX-001` | Backend exposes multiple contexts, but identity fields and clients still treat an account as one exclusive journey in important paths. | Additive context capability contract and compatibility tests. |
| `MOB-CTX-001` | Flutter routing and plan-scoped providers can select the wrong context or race during plan changes. | Unit, widget, and integration context-switch tests. |
| `MOB-OFF-001` | A cold offline start can lose the last usable plan and show onboarding/no-plan state incorrectly. | Connected-to-offline restart integration test. |
| `MOB-SYNC-001` | Blocked sync work can coexist with a false “synced” state and weak recovery controls. | Persistent blocked-item tests and truthful UI states. |
| `MOB-TASK-001` | Local task create/edit/delete sequences can send stale data or local IDs to the API. | Queue coalescing and reconnect integration tests. |
| `MOB-MIG-001` | Guest-plan migration/discard cleanup can leave related rows or clear unrelated authenticated cache. | Atomic graph cleanup and account-isolation tests. |
| `ADM-AUTH-001` | Admin session refresh and late `401` handling need a deterministic single-generation contract. | Controlled concurrent refresh tests and full session-expiry UI reset. |
| `ADM-ACT-001` | Some admin actions do not present backend rejection consistently. | Action-state component tests for `400/403/409` and rejected promises. |
| `ADM-CSP-001` | Admin media/CSP configuration and external avatar behavior are inconsistent. | Production-container CSP and browser resource tests. |
| `ADM-PAGE-001` | Provider selectors capped at a fixed first page can silently exclude valid providers. | Server-side paginated search test with more than 100 providers. |
| `OPS-CONF-001` | Built admin API origin, runtime CSP origin, and backend CORS can drift independently. | Fail-fast configuration manifest and negative startup tests. |
| `OPS-BACK-001` | Database/media backup evidence does not yet prove off-host restoration within an approved RPO/RTO. | Isolated database and media restore drill with checksums. |
| `OPS-MON-001` | Monitoring, alert delivery, secret matching, and private network exposure lack one verified production gate. | Scrape, synthetic alert, and external-denial tests. |
| `SUPPLY-001` | Production images/actions and release evidence are not uniformly immutable and traceable. | Digest/SHA policy, SBOM, scan, and revision checks. |

New confirmed defects are appended with evidence; existing IDs are not silently
deleted or renamed.

## Phase Order And Exit Gates

### Phase 0 — Baseline And Executable Contracts

Scope:

- Preserve the clean baseline results above.
- Add failing tests that reproduce `BE-LIFE-001`, `BE-PROV-001`, and
  `BE-PROV-002`.
- Record stable error codes and the provider capability matrix.

Exit gate:

- The new tests fail for the intended missing guards, not from broken fixtures.
- No production implementation is changed before the failing evidence exists.

### Phase 1 — Backend Lifecycle And Provider Security

Scope:

- Make every plan mutation guard reject `ARCHIVED` while reads remain allowed.
- Read provider status live from the database.
- Allow profile/status visibility according to the matrix below.
- Require `ACTIVE` for provider services, packages, reviews, quote operations,
  operational summary, and provider-side conversations.
- Revoke access at service boundaries; do not rely on JWT role or UI hiding.

Provider capability matrix:

| Status | Read application/profile | Edit application/profile | Operational dashboard and customer data |
| --- | --- | --- | --- |
| `PENDING` | allow | allow | deny |
| `NEEDS_CHANGES` | allow | allow | deny |
| `ACTIVE` | allow | allow | allow |
| `SUSPENDED` | allow status/profile | deny | deny |
| `REJECTED` | allow status/profile | deny | deny |

Stable denials:

- Archived write: HTTP `409`, code `PLAN_ARCHIVED_READ_ONLY`.
- Non-active provider operation: HTTP `403`, code
  `PROVIDER_NOT_ACTIVE`.
- Provider profile mutation in a terminal/restricted state: HTTP `403`, code
  `PROVIDER_PROFILE_READ_ONLY`.

Exit gate:

- Targeted RED tests become PASS without weakening old tests.
- `npm run check`, full `npm test`, `npm run build`, and
  `npx prisma validate` all pass.
- Relevant isolated API smokes pass when their managed dependencies are
  available; otherwise the exact environment blocker is recorded as a blocker,
  not converted into PASS.

### Phase 2 — Atomic Authorization, Invites, And Notification Truth

Scope:

- Move authorization checks that protect writes into the same serializable
  transaction or lock boundary as the mutation.
- Prevent stale invitations from overwriting an existing membership.
- Apply task, payment, and provider-message preferences before creating in-app
  notifications/outbox work.
- Mark unsupported external channels as unsupported without inventing a
  delivery integration.

Exit gate:

- Deterministic concurrency tests cover revoke-versus-write and
  invite-versus-membership races.
- No notification preference is writable without a tested effect.
- Full backend gates and the affected isolated smokes pass.

### Phase 3 — Additive Multi-Context Backend Contract

Scope:

- Extend `/api/v1/contexts` and context validation with lifecycle/access mode
  and explicit capabilities.
- Preserve compatibility fields temporarily.
- Stop new provider application/admin status changes from erasing wedding
  contexts.
- Do not backfill or remove legacy role fields until the mobile transition is
  verified.

Exit gate:

- One test account can be owner, contributor, and provider simultaneously.
- Each context reports truthful availability and capabilities.
- Accepting an invite does not replace an already selected valid context.

#### Phase 3 execution receipt — 2026-07-26

Status: **exit gate passed locally; no deployment claim**

- Context list/validation retain compatibility fields and add live
  `lifecycle`, `accessMode`, and provider `capabilities`.
- Archived plans are discoverable `READ_ONLY` history; active validation
  returns `409 CONTEXT_UNAVAILABLE` with `PLAN_ARCHIVED`, and all plan write
  permissions are false.
- Provider capabilities use the canonical provider access policy across
  `PENDING`, `NEEDS_CHANGES`, `ACTIVE`, `SUSPENDED`, and `REJECTED`.
- Invite acceptance additively returns a contributor `contextKey` without
  changing `activeWeddingPlanId`.
- No schema migration or backfill was added. Legacy role/onboarding/persona
  fields remain compatible while relationship rows remain the context source
  of truth.

| Check | Result |
| --- | --- |
| Targeted TDD RED (`contexts` + invite acceptance) | Expected 4 failures: additive fields and invite `contextKey` absent |
| Targeted GREEN (`contexts` + invite acceptance) | PASS: 51/51 |
| Backend TypeScript check | PASS |
| Managed PostgreSQL Phase 3 transition smoke | PASS on 67 migrations: apply, all five provider states plus reactivation, HTTP list/validate/accept, archived contributor, and active-plan preservation |

### Phase 4 — Flutter Context, Routing, And Provider Journey

Scope:

- Introduce one account-context controller and a centralized post-auth entry
  gate. Multiple contexts use a standalone Arabic path-selection screen; the
  dashboard shells do not contain a context switcher.
- Scope plan providers to the selected context and reject stale async results.
- Refresh user and contexts after provider application without losing wedding
  contexts.
- Wire route guards and feature flags to real runtime behavior.

Exit gate:

- Unit, widget, and Android integration tests cover owner/contributor/provider
  switching, restart, deep links, revocation, RTL, and 320 px width.
- `flutter analyze` and the complete `flutter test` suite pass.

### Phase 5 — Flutter Offline Data Integrity

Scope:

- Restore the last cached plan on a genuine offline cold start.
- Persist blocked sync items and expose recovery instead of false success.
- Coalesce local task operations and never send `local-task-*` IDs.
- Atomically delete only the guest-plan graph during migration/discard.

Exit gate:

- Offline restart, blocked recovery, local task reconnect, migration, discard,
  and two-account isolation pass on Android.
- No blocked work can be represented as fully synced.

### Phase 6 — Admin Reliability And Honest Operations

Scope:

- Make refresh single-generation and resilient to late `401` responses.
- Reset the entire authenticated UI state on terminal refresh failure.
- Standardize loading/success/error handling for admin mutations.
- Align visible actions with backend policy without weakening backend checks.
- Replace fixed provider caps with paginated server-side search.
- Remove external avatar dependence or explicitly allow only the approved media
  origin.

Exit gate:

- Admin typecheck, unit tests, build, production-container browser tests, and
  delegated-role flows pass.
- No unhandled rejected mutation and no hidden first-100 provider limit remain.

#### Phase 4 and Phase 5 execution receipt — 2026-07-28

Status: **local implementation and desktop-test gates passed; Android exit
gates remain BLOCKED by the environment**

Phase 4 evidence:

- Context selection is now one controller with owner, contributor, provider,
  archived read-only, revocation, stale-result, logout, persistence, and
  disposal contracts.
- Plan-scoped providers are keyed from the selected context, while provider
  contexts cannot inherit the last wedding-plan data.
- Login, OTP, provider application, deep-link guards, runtime guest flags, and
  the standalone Arabic context-selection screen are wired to the live
  context boundary. The selected context key is stored through secure
  storage.
- Archived plan deep links render read-only history without calling
  `set-active`; revoked or missing contexts render a generic unavailable state.
- A real `integration_test/account_context_android_test.dart` artifact covers
  owner-to-provider switching at 320 px. It passes static analysis.

Phase 5 evidence:

- A connected call followed by an offline cold restart restores the persisted
  active plan from the account-isolated cache and refuses archived plans as
  active.
- Blocked queue items persist across service recreation, remain visible as
  `syncError`, expose a manual requeue/retry action, and cannot be reported as
  fully synced.
- Task create/edit/delete sequences coalesce locally; local task IDs are
  rewritten before dependent replay, and local create/delete is canceled
  without an API request.
- Guest-plan migration/discard deletes only the plan graph, queue references,
  and plan metadata; authenticated user data, other plans, and other queued
  writes remain.

| Check | Result |
| --- | --- |
| Context foundation/controller/API/storage focused gate | PASS: 34/34 |
| Context hardening and routing/provider journey gate | PASS: 42/42 |
| Runtime guest onboarding route-flag gate | PASS: 3/3 |
| Connected → offline active-plan restart gate | PASS: 10/10 |
| Blocked-sync persistence/recovery gate | PASS: 8/8 |
| Task queue coalescing/reconnect gate | PASS: 3/3 |
| Guest-plan graph cleanup gate | PASS: 1/1 |
| Offline/onboarding regression bundle | PASS: 19/19 |
| `flutter analyze` on affected production/tests/integration | PASS |
| Complete Flutter test suite | PASS: 792/792 |
| `flutter devices` Android availability | BLOCKED: no Android device |
| `flutter emulators` | BLOCKED: no emulator available |
| Integration run on Windows fallback | BLOCKED: missing
  `atlstr.h` for `flutter_secure_storage_windows` |

No Android release-readiness claim is made until the same integration artifact
is executed on an Android device or emulator. Phase 4 and Phase 5 therefore
remain open at their external-device exit gates; the next safe action is to
provide an Android target, then run the artifact and offline journeys there.

#### Phase 6 bounded execution receipt — 2026-07-28

Status: **bounded Admin reliability slice verified locally; Phase 6 remains
open**

Objective completed in this slice:

- A terminal authenticated `401` now shares one refresh generation, retries
  once, and notifies the authenticated UI only once when refresh fails or the
  retry is still unauthorized.
- The Admin auth provider clears the user, MFA challenge, and loading state on
  terminal session expiry so the protected UI cannot remain visibly signed in.
- Admin mutation errors are rendered or stored as explicit UI errors instead
  of becoming unhandled rejected click promises.
- Provider lookups on Services and Reviews use server-side `search/page/limit`
  instead of a hidden `limit: 100` cap.
- The Admin topbar avatar is generated locally and no longer depends on
  `ui-avatars.com`, which was outside the current CSP.

Files changed in this slice:

- `admin-web/src/api/client.ts` and `client.test.ts`: single-generation
  refresh-expiry notification contract and concurrent/late-401 regressions.
- `admin-web/src/auth/AuthProvider.tsx` and `AuthProvider.test.tsx`: complete
  authenticated-UI reset proof.
- `admin-web/src/components/ConfirmDialog.tsx` and its test: visible
  mutation-failure handling without an unhandled promise.
- `admin-web/src/pages/ServicesPage.tsx`, `ReviewsPage.tsx`,
  `UsersPage.tsx`, `NotificationsPage.tsx`, and `UserDetailsPage.tsx`:
  server-side provider search and mutation error capture.
- `admin-web/src/layout/Topbar.tsx` and `AdminLayout.tsx`: local avatar and
  logout navigation cleanup.
- `admin-web/src/pages/AdminPaginationContract.test.ts` and
  `admin-web/src/auth/AdminRbacAuditContract.test.ts`: source contracts for
  provider pagination and CSP-safe avatar behavior.

RED evidence:

- Before the implementation, the targeted client suite failed all 12 tests
  because `setAdminSessionExpiredHandler` did not exist. This was the
  intentional red gate for the new contract.

| Check | Result |
| --- | --- |
| Targeted refresh/401 client suite | PASS: 12/12 |
| AuthProvider terminal-expiry UI test | PASS: 1/1 |
| Provider lookup/CSP source contracts | PASS: 14/14 |
| ConfirmDialog rejected-mutation test | PASS: 1/1 |
| Full Admin Vitest suite | PASS: 10 files, 74/74 tests |
| Admin typecheck | PASS |
| Admin production build + config smoke | PASS |
| Admin `smoke:honesty` | PASS: all assertions |
| Admin `smoke:routes` | PASS: all 16 routes |
| Production-container browser/runtime proof | NOT RUN in this slice |

This receipt does not claim the complete Phase 6 exit gate: production
container browser coverage, delegated-role end-to-end flows, and the
remaining operations/runtime phases are still unopened. No commit, push,
merge, or deployment was performed.

#### Phase 6 container and runtime follow-up receipt - 2026-07-28

The local Admin container gate is now exercised against the built image. The
image fails closed when its build-time API origin differs from `API_ORIGIN`,
when `ADMIN_PUBLIC_ORIGIN` is absent from `CORS_ORIGINS`, or when a required
runtime value is missing. The positive container probe returned `200`, the
canonical CSP, HSTS, `Server: nginx` without a version, and
`aarast-build-config.json` bound to the expected API origin. All five
generated assets returned `200`.

| Check | Result |
| --- | --- |
| Admin Vitest | PASS: 10 files, 74/74 tests |
| Admin typecheck/build/honesty/routes | PASS |
| Admin container-config contract | PASS: 3/3 |
| Positive/negative Admin container probes | PASS: 1 positive, 2 fail-closed negatives |
| Delegated Admin mutation authorization smoke | PASS |
| Admin runtime MFA/cookie/PII/rotation smoke | PASS |

The production-container proof is local only; this branch was not deployed.

### Phase 7 — Runtime Configuration, Backup, And Monitoring

Scope:

- Fail fast when built API origin, CSP, runtime origin, or CORS disagree.
- Bind backup and monitoring components with least privilege.
- Produce encrypted off-host database and media backups.
- Verify isolated restore, checksums, RPO/RTO, private metrics access, and a
  delivered synthetic alert.

Exit gate:

- The exact candidate images pass positive and negative configuration tests.
- A restore drill proves both database and media recovery.
- Alert delivery reaches a human-owned receiver and metrics/Grafana are not
  publicly exposed.

#### Phase 7 local execution receipt - 2026-07-28

Local configuration hardening is complete for the parts that do not require
production credentials:

- Grafana binds to `127.0.0.1` only.
- Prometheus and the Backend share an explicitly required private external
  network; there is no silent `dokploy-network` fallback.
- Alertmanager requires an operator-supplied receiver configuration and cannot
  start from the checked-in placeholder template.
- Production and monitoring Compose validation passed with non-secret example
  values; monitoring contract tests pass 4/4.

The off-host encrypted database/media copy, isolated media restore, measured
RPO/RTO, and delivered human alert remain BLOCKED until an approved off-host
target and a real receiver are supplied. The local database restore script and
source tests are not evidence of those external operations.

### Phase 8 — Supply Chain And Release Candidate

Scope:

- Pin production images by digest and CI actions by commit SHA.
- Generate SBOMs, scan dependencies/images, and bind evidence to Git revision
  and image digest.
- Prove rollback using a known prior image.

Exit gate:

- No unapproved critical/high vulnerability or mutable production dependency.
- Source tests, built images, runtime smokes, restore proof, monitoring proof,
  and rollback evidence all refer to the same candidate.

#### Phase 8 local execution receipt - 2026-07-28

- All GitHub Actions in CI are pinned to full commit SHAs.
- Production and monitoring infrastructure images are digest-pinned.
- CI now builds images with the Git revision, emits CycloneDX SBOM artifacts
  named with that revision, and rejects HIGH/CRITICAL Trivy findings.
- Supply-chain contract tests pass 3/3.
- Backend `npm audit --audit-level=high`: PASS, 0 advisories.
- Admin `npm audit --audit-level=high`: PASS at the configured gate, with 2
  documented Moderate React Router advisories.

The first local Trivy run found 37 vulnerabilities (35 HIGH, 2 CRITICAL) in
the old Nginx 1.27 Alpine base. That image was not accepted. The Admin image
was rebuilt on the digest-pinned Nginx 1.29 Alpine slim base with the current
Alpine security upgrade and its final HIGH/CRITICAL scan exited 0 with no
findings (`sha256:4cb9c1d04cec393eddc6c1bce60b3825263896fa8abed58ce273f586d4e6823e`).
The Backend image initially exposed six npm-bundled findings (five HIGH, one
CRITICAL); the runtime npm toolchain was updated and the final scan also
exited 0 with no HIGH/CRITICAL findings
(`sha256:04e221fbcc99cf153e6f8a1eb1024a6a508c209a79a43e9f560248bbbfaca6a1`).
The local candidate image gate is therefore PASS. Rollback, off-host restore,
human alert delivery, and deployment proof remain external gates; no rollback
or deployment was performed.

### Phase 9 — Integrated Acceptance And Readiness Verdict

Scope:

- Execute backend, mobile, admin, security, offline, deployment, and recovery
  acceptance journeys together.
- Reconcile the defect register, generated references, API contract, status,
  and release notes against the tested implementation.

Exit gate:

- Every defect is `PASS`, explicitly deferred with an owner/reason, or
  `BLOCKED` by a named external dependency.
- No required test is skipped or weakened.
- Readiness is reported separately for backend, mobile, admin, operations, and
  public release. “READY” is forbidden when any critical gate is not proven.

## Per-Phase Completion Receipt

Every phase report must contain:

1. Objective and fixed behavior.
2. Files changed and why each file changed.
3. Reproduction or RED evidence.
4. Exact commands and `PASS`/`FAIL` results.
5. Build, typecheck, lint, migration/schema, and runtime-smoke status as
   applicable.
6. Security, privacy, concurrency, offline, and compatibility review.
7. Remaining uncertainty and the next unopened phase.

## Phase 0 And Phase 1 Completion Receipt

**Verdict:** Phase 0 is complete. Phase 1 is complete for the sequential
request/service-boundary contract. Atomic lifecycle races are deliberately not
claimed as fixed; they remain `BE-RACE-001` and are the first work in Phase 2.

Implemented behavior:

- Every shared plan mutation guard now rejects an archived plan with HTTP `409`
  and `PLAN_ARCHIVED_READ_ONLY`, while authorized reads remain available.
- An archived plan cannot be selected as active, accept a new membership,
  change a linked quote, or send a new quote-conversation message.
- The provider capability matrix is enforced from live `Provider.status`.
  Nineteen operational methods were checked across `PENDING`,
  `NEEDS_CHANGES`, `SUSPENDED`, and `REJECTED` (76 denial cases).
- Provider profile reads remain available in non-active states. Profile writes
  remain available only for `PENDING` and `NEEDS_CHANGES`; terminal states are
  read-only.
- A suspended provider's provider-side conversations are excluded from the
  mixed-context inbox. Direct read/send is denied with
  `PROVIDER_NOT_ACTIVE`, while that account's customer and wedding contexts are
  preserved.
- Provider quote and chat notifications are filtered before pagination,
  unread counts, dashboard previews, and bulk read operations. Direct access is
  denied, other account notifications remain visible, and inbox reads use
  `Cache-Control: private, no-store`.
- New provider notification bodies are generic and carry an explicit
  `recipientAudience`. Migration
  `20260726010000_scrub_notification_contact_pii` removes copied requester and
  sender names from historical provider quote/chat alert bodies.
- A newly accepted offer locks and rechecks the provider's live status.
  A historical accepted-offer replay remains read-only and idempotent after a
  later suspension, but rejects missing or mismatched cost/link artifacts.
- Suspending, rejecting, or otherwise deactivating a provider revokes its
  current realtime conversation-room access.

Evidence:

| Check | Final result |
| --- | --- |
| Targeted provider notification visibility tests | PASS: 6/6 |
| Targeted quote notification/replay tests | PASS: 11/11 |
| Provider dashboard runtime smoke | PASS: 99/99 |
| Conversation unification runtime smoke | PASS: 111/111 |
| Providers and quotes runtime smoke | PASS: 66/66 |
| Wedding plan runtime smoke | PASS: 37/37 |
| Sharing security runtime smoke | PASS: 34/34 |
| Notifications API runtime smoke | PASS: 52/52 |
| `npm run check` | PASS |
| `npx prisma validate` | PASS; existing Prisma 7 configuration deprecation warning remains |
| `npm test` pretest | PASS: 42/42 |
| `npm test` main suite | PASS: 445 total, 444 passed, 1 existing skip, 0 failed |
| `npm run build` | PASS |
| `node scripts/docs-sync.mjs --check` | PASS: drift 0, errors 0 |
| `node scripts/docs-verify.mjs` | PASS: errors 0, warnings 0 |

Intermediate failures were not hidden:

- The first expanded provider notification smoke exposed PostgreSQL
  three-valued `NULL` behavior (`87` passed, `2` failed). The visibility query
  was corrected and rerun to `99/99`.
- The first notifications API smoke correctly rejected service creation by a
  `PENDING` provider. Its stale fixture was changed to activate the provider
  before the operation, then the smoke passed `52/52`.
- The first full suite run found two ordinary-account notification mocks that
  lacked the newly required provider lookup (`442` passed, `2` failed,
  `1` skipped). The mocks were made explicit and the complete suite was rerun
  successfully.

Phase 2 verification status:

- Stale-invite acceptance, quote-offer acceptance, provider suspension versus
  message send, notification preference effects, core plan mutations, and all
  delegated member/invite administration now have deterministic transaction
  coverage.
- Task, guest, finance, marketplace, provider-dashboard, media, notification,
  administrator, authentication, sharing, and conversation revocation
  boundaries now have targeted transactional/runtime coverage. The current
  source inventory is guarded by sixteen named `smoke:phase2-*` commands; these
  are separate gates and are not implied by `smoke:all`.
- The invite-OTP database invariant and guarded test inventory have focused
  proof, and the full guarded unit suite passes on their combined source state.
  All sixteen Phase 2 smokes, `smoke:all`, backend check/build/container rebuild,
  and final Gitleaks scan also pass. The current code-remediation verification
  scope is therefore verified. A sequential permission call is not classified
  as a defect until its write boundary and concurrent outcome are proven.
- Notifications already delivered to a browser/device before suspension cannot
  be recalled. Server reads are no-store and re-authorized, but client-side
  notification handling still needs an explicit Phase 2/4 contract.

## Phase 2 Progress

### Slice 1 — Stale Invitation Membership Preservation

RED evidence:

- A pending invitation granted finance and provider authority.
- A newer existing membership intentionally reduced the same account to a
  read-only viewer.
- Accepting the stale invitation overwrote the newer row, restored all three
  sensitive permissions, and reopened provider conversation participation.

Implemented contract:

- Acceptance uses a retryable `SERIALIZABLE` transaction.
- Lock order begins with `WeddingPlan FOR SHARE`, then
  `PlanInvite FOR UPDATE`.
- Plan and invite lifecycle are re-read inside the transaction.
- The still-live invitation is claimed once.
- `SharedMember` is create-if-missing; an existing membership is returned
  unchanged and remains authoritative.

Evidence so far:

| Check | Result |
| --- | --- |
| Intended RED regression | FAIL as intended: stale invite restored finance/provider permissions |
| Focused regression after fix | PASS: 1/1 |
| Complete sharing permission unit file | PASS: 30/30 |
| Sharing security runtime smoke after fix | PASS: 34/34, including the exact stale-member scenario |

This slice does not complete Phase 2. The exact stale-member scenario now has
both focused and isolated PostgreSQL runtime proof.

### Slice 2 — Plan Archive Versus Quote Acceptance

RED evidence:

- An isolated PostgreSQL transaction changed the plan to `ARCHIVED` without
  committing.
- Quote acceptance started while that lifecycle change was uncommitted.
- Before the fix, acceptance settled instead of waiting for the plan row;
  the deterministic assertion failed with `settled` instead of `blocked`.

Implemented contract:

- A transactional plan permission check first takes
  `WeddingPlan FOR SHARE`, then re-reads lifecycle state.
- Quote acceptance runs that check before locking `QuoteRequest` and
  `QuoteOffer`; a non-owner's `SharedMember` permission row is locked between
  the plan and quote rows.
- A new acceptance then locks the live `Provider` row before any acceptance
  graph write.
- If archive commits first, the serializable retry observes `ARCHIVED` and
  returns `PLAN_ARCHIVED_READ_ONLY`. If acceptance locks first, archive waits
  until the entire acceptance graph commits.

Evidence:

| Check | Result |
| --- | --- |
| Intended archive-versus-accept RED | FAIL as intended: acceptance settled while archive was uncommitted |
| TypeScript checks after fix | PASS |
| Transactional plan-permission tests | PASS: 14/14 |
| Quote notification/replay tests | PASS: 11/11 |
| Phase 2 isolated PostgreSQL concurrency smoke | PASS: permission/lifecycle revocation fails closed |
| Targeted `git diff --check` | PASS |

The first post-fix runtime attempt was stopped after the old permission-race
fixture produced a test-only circular wait under the stronger lock order. The
fixture was corrected to hold an uncommitted permission revocation first, then
the complete smoke was rerun successfully. This slice does not complete Phase
2; suspension-versus-message and the remaining lifecycle/notification work
remain open.

### Slice 3 — Provider Suspension Versus Conversation Send

RED evidence:

- An isolated transaction changed the linked provider to `SUSPENDED` without
  committing.
- The provider then started a conversation send while the suspension was
  uncommitted.
- Before the fix, the send settled instead of waiting for the provider row;
  the deterministic assertion failed with `settled` instead of `blocked`.

Implemented contract:

- The serializable conversation mutation locks `Conversation FOR UPDATE`,
  then `Provider FOR SHARE`, and re-reads the provider status.
- Provider-side access is rejected with `PROVIDER_NOT_ACTIVE` after a
  suspension that commits first.
- The provider lifecycle lock remains held across message, notification, and
  outbox writes, so a suspension that starts second waits for the complete
  message graph.

Evidence:

| Check | Result |
| --- | --- |
| Intended suspension-versus-send RED | FAIL as intended: provider send settled while suspension was uncommitted |
| TypeScript checks after fix | PASS |
| Provider/lifecycle/chat focused tests | PASS: 18/18 |
| Conversation pagination/private media focused tests | PASS: 7/7 |
| Phase 2 isolated conversation revocation smoke | PASS: permission and provider suspension fail closed |
| Targeted `git diff --check` | PASS |

One aborted RED run left only its managed-smoke ownership key in dedicated
Redis database `15`. The exact owner was verified against that run id, the
single stale test lock was removed, and the database was confirmed empty
before rerunning. No application or production Redis database was touched.

### Slice 4 — Truthful Notification Preferences And Delivery Capabilities

RED evidence:

- A quote notification ignored `providerMessagesEnabled=false` and attempted a
  notification write.
- The reminder scheduler created five rows instead of the three allowed by the
  task/payment preference matrix.
- The settings contract had no `channelCapabilities`, while the mobile screen
  exposed push, SMS, WhatsApp, and email as working switches.
- In the deterministic disable-versus-create race, notification creation waited
  for the settings transaction but still used the old enabled value and returned
  a persisted notification instead of `null`.

Implemented contract:

- In-app notifications are explicitly supported, always enabled, and
  non-configurable. Push, SMS, WhatsApp, and email are explicitly unsupported,
  forced to `false`, and reject enable attempts with
  `NOTIFICATION_CHANNEL_UNSUPPORTED`.
- `taskRemindersEnabled`, `paymentRemindersEnabled`, and
  `providerMessagesEnabled` now gate their corresponding notification and
  outbox writes. General account/sharing notifications remain available.
- Settings writers take `User FOR UPDATE`; preference-aware notification
  creation and the scheduler take `User FOR SHARE` before re-reading settings.
  A disable that commits first therefore prevents the notification.
- Migration `20260726020000_disable_unsupported_notification_channels` scrubs
  old unsupported channel values and changes the push default to `false`.
- Flutter parses the capability contract, submits only the three real content
  preferences, shows the in-app/external delivery truth as status text, and
  exposes only three switches. The support guidance now states the same limits.

Evidence:

| Check | Result |
| --- | --- |
| Intended functional preference REDs | FAIL as intended: provider notification write attempted; scheduler produced 5 instead of 3 |
| Intended disable-versus-create RED | FAIL as intended: a notification object was returned instead of `null` |
| TypeScript checks after fix | PASS |
| Notification/settings/provider focused tests | PASS: 30/30 |
| Settings HTTP smoke on an isolated database | PASS: 31/31 |
| Phase 2 isolated notification preference/outbox smoke | PASS |
| Flutter model, 320px RTL settings, and support tests | PASS: 7/7 |
| Flutter settings golden | PASS: 1/1 and visually inspected |

The first preference smoke fixture tried to mark a schedule paid by directly
editing its status. PostgreSQL correctly rejected that test-only mutation
because it bypassed the immutable financial ledger. The fixture was corrected
without weakening the ledger, then the smoke passed. One earlier aborted RED
run left only its exact managed-smoke lock in dedicated Redis database `15`;
the owner and single-key scope were verified before deleting that test lock,
and the database was confirmed empty. No application or production Redis
database was touched.

### Slice 5 — Atomic Wedding Plan Mutations

RED evidence:

- Plan archive and plan update both settled while a concurrent
  `canEditPlan` revocation was still uncommitted.
- Active-plan selection settled while deletion of the acting member's
  `SharedMember` row was still uncommitted.
- In each case, the operation had authorized from a stale snapshot instead of
  waiting for the authority change.

Implemented contract:

- Plan update and archive run inside retryable `SERIALIZABLE` transactions.
- They lock `WeddingPlan FOR UPDATE` first, re-read lifecycle state, then lock
  the acting non-owner's `SharedMember FOR SHARE` before checking authority and
  writing.
- Active-plan selection locks `User FOR UPDATE` first, then locks and rechecks
  the requested `WeddingPlan` and applicable `SharedMember` before updating
  `activeWeddingPlanId`.
- Existing product semantics were preserved: manager-style plan authority may
  archive a plan. Whether archive should become owner-only remains an explicit
  product decision, not a hidden concurrency fix.

Evidence:

| Check | Result |
| --- | --- |
| Intended plan update/archive REDs | FAIL as intended: each mutation settled while permission revocation was uncommitted |
| Intended set-active RED | FAIL as intended: selection settled while membership deletion was uncommitted |
| TypeScript checks after fix | PASS |
| Focused lifecycle and permission tests | PASS: 21/21 |
| Phase 2 isolated plan-mutation PostgreSQL smoke | PASS: permission revocation and membership removal fail closed |

### Slice 6 — Atomic Delegated Sharing Administration

RED evidence:

- Member update and member removal both settled while an uncommitted
  `canInviteMembers=false` revocation was holding the acting member row.
- The operations could therefore continue from stale delegated authority.

Implemented contract:

- Member creation, invitation creation/cancellation/reissue, member update, and
  member removal recheck delegated authority inside retryable `SERIALIZABLE`
  transactions.
- Lock order begins with `WeddingPlan FOR SHARE`, then the acting non-owner's
  `SharedMember FOR SHARE`.
- Member update/removal lock the target member `FOR UPDATE`; permission
  ceilings, writes, and notification/conversation cleanup remain in the same
  transaction. Realtime revocation is emitted only after commit.
- Invitation state transitions retain their conditional expected-state writes,
  but now share the locked actor/lifecycle check.
- Reverse lifecycle coverage proves that a plan archive committing first makes
  waiting member update/removal return `PLAN_ARCHIVED_READ_ONLY` without
  changing or deleting the target.

Evidence:

| Check | Result |
| --- | --- |
| Intended delegated update/remove REDs | FAIL as intended: both settled while revocation was uncommitted |
| TypeScript checks after fix | PASS |
| Focused sharing/permission/notification tests | PASS: 53/53 |
| Phase 2 isolated sharing concurrency smoke | PASS: six authority-revocation cases plus two archive cases |
| Sharing API smoke | PASS: 80/80 |
| Sharing roles smoke | PASS: 70/70 |
| Sharing security smoke | PASS: 34/34 |
| Wedding plan smoke | PASS: 37/37 |

The expanded invitation smoke exposed a test-infrastructure cleanup omission:
the shared isolated fixture deleted a WeddingPlan before deleting PlanInvite
children. The fixture now deletes those invitations first; the foreign key was
not weakened and application behavior was unchanged.

### Slice 7 — Atomic Task And Guest Mutations

RED evidence:

- Task creation and guest creation both settled while their domain-permission
  revocations were still uncommitted, proving stale authorization windows.

Implemented contract:

- All seven task mutation shapes and all seven guest/group mutation shapes now
  recheck lifecycle and authority inside retryable `SERIALIZABLE` transactions.
- Task lock order is plan, acting member, applicable assignee, task, then
  checklist item.
- Guest lock order is plan, acting member, applicable referenced group, then
  the target guest/group.
- Task assignment cannot retain a concurrently removed plan member.
- Guest bulk creation is atomic, name normalization stays paired with the locked
  current name, and one non-null normalized phone is enforced per plan by
  migration `20260726030000_enforce_unique_guest_phone`.

Evidence:

| Check | Result |
| --- | --- |
| Intended task/guest creation REDs | FAIL as intended: both mutations settled while permission revocation was uncommitted |
| TypeScript checks | PASS |
| Phase 2 isolated task/guest concurrency smoke | PASS: create cases, task matrix 6, guest matrix 6, archive matrix 6, assignee removal, duplicate phone, bulk rollback, and normalization |
| Focused unit tests | PASS: 24/24 |
| Tasks API smoke | PASS: 55/55 |
| Task timeline smoke | PASS: 42/42 |
| Guests smoke | PASS: 28/28 |
| Guests API smoke | PASS: 45/45 |

### Slice 8 — Atomic Financial Mutations And Summary

Pre-fix evidence:

- All fifteen financial write handlers checked money authority before their
  write transaction, so a concurrent archive, membership removal, or permission
  revocation could commit between authorization and mutation.
- Cost update exposed cancelled state before transactional authorization, and
  payment/schedule creation parsed target-specific input before the permission
  gate.
- Budget replacement committed first and then re-authorized a separate summary
  read, allowing a successful write to be reported as a failed request.

Implemented contract:

- All fifteen financial mutation handlers recheck lifecycle and authority inside
  retryable `SERIALIZABLE` transactions.
- Cost create/update lock old and target provider/offer/category references in
  deterministic order before the cost row. Provider suspension that commits
  first rejects the waiting link/update without a write.
- Money-summary permission and rows use the same `REPEATABLE READ` transaction
  snapshot.
- Budget replacement builds the returned summary inside its successful mutation
  transaction, eliminating commit-then-auth/error ambiguity.
- An AST source guard inventories exactly fifteen controller-to-service write
  mappings and verifies their transaction-local gates and summary boundary.

Evidence:

| Check | Result |
| --- | --- |
| TypeScript checks | PASS |
| Focused finance/lifecycle/permission tests | PASS: 33/33 |
| Phase 2 isolated finance concurrency smoke | PASS: six deterministic races plus exact 15-handler AST guard |
| Money budget smoke | PASS: 49/49 |
| Money API smoke | PASS: 60/60 |
| Money route contract smoke | PASS: 18/18 |
| Financial ledger concurrency smoke | PASS: 29/29 |

The first attempt to run two regression smokes in parallel was rejected before
either affected scenario because both workers found the dedicated Redis test
database occupied. No keys were deleted. The affected smokes were rerun
sequentially and passed as reported above.

### 2026-07-26 Consolidated Local Verification Receipt

**Verdict:** The current backend, Flutter, and admin-web remediation changes
have complete local verification for the defined code-remediation scope.
Code-remediation verification is `VERIFIED`: the backend
check/build/container rebuild, guarded unit suite, all sixteen Phase 2 smokes,
`smoke:all`, administrator runtime smoke, Gitleaks, and the documentation gates
pass on the resulting code. This receipt does not claim deployment, production
readiness, or a physical-device acceptance pass.

Additional implemented contract:

- `npm test` uses one protected-artifact runner. It discovers every top-level
  `backend/test/*.test.ts` file, runs the five Phase 0 contract files first and
  every remaining file exactly once in a second batch, and fails if either
  batch creates, removes, or mutates protected fixtures, goldens, or
  `phase0-postgres-support.js`. There is no Git-dirty `posttest`.
- Prisma CLI configuration now lives in `backend/prisma.config.ts`, loads the
  optional backend `.env` through Node's environment loader, and owns the
  migrations seed command. The deprecated `package.json#prisma` block was
  removed.
- Invite access uses `INVITE_ACCESS`, bound to the exact
  `OtpCode.planInviteId`. General OTP request/verify rejects that internal
  purpose; login and separate invitations for one phone cannot consume one
  another's codes. Migration
  `20260726041000_enforce_invite_otp_context` makes the context bidirectional at
  the database boundary: invite access requires `planInviteId`, and every other
  purpose forbids it.
- Every application and administrator access JWT carries the current
  `RefreshToken.id` as `sid` and requires that exact user/scope session row to
  remain live. Refresh rotation serializes one replacement family. Reusing the
  old token, even immediately, rejects the replay and revokes the winning
  descendant in both application and administrator realms while leaving
  independent login families and the other realm intact.
- A replacement-chain cycle or traversal beyond the 4,096-row limit is treated
  as an untrustworthy family, not as an ordinary replay. Refresh/logout then
  fail closed by revoking every active session for that user and the affected
  realm only. `APPLICATION` and `ADMIN` remain isolated; normal replay continues
  to preserve independent login families. Traversal is one bounded recursive
  CTE that returns at most `max + 1` rows and locks the traversed token rows in
  one `FOR UPDATE` query instead of issuing one lock query per generation.
- Application session and conversation-access revocations are written to the
  PostgreSQL outbox in the same transaction as the authoritative mutation.
  Immediate Socket.IO revocation remains best-effort for latency; strict outbox
  delivery stays retryable until the realtime adapter completes the action.
- Guest storage enforces one canonical `phone`/`normalizedPhone` pair and at
  most one non-null normalized phone per plan. Historical canonicalization
  fails transactionally and without logging phone values rather than merging
  or deleting a guest.
- In-app notifications remain the only supported notification delivery
  channel. Legacy push, SMS, WhatsApp, and email toggles remain false and reject
  enable attempts. Content preferences default to enabled when no row exists,
  serialize with notification creation, and suppress both the notification and
  its outbox event. Provider-audience quote/chat alert text is generic in new
  writes and historical stored bodies.

Confirmed evidence:

| Check | Result |
| --- | --- |
| `npm run check` | PASS after bounded refresh-family traversal |
| `npx prisma validate` | PASS; Prisma config loaded without the former package-configuration deprecation warning |
| `npx prisma generate` | PASS |
| Backend `npm audit --audit-level=high` | PASS: 0 vulnerabilities |
| Final `npm test` after bounded refresh-family traversal | PASS: 567 total = 566 passed + 1 intentional Windows symlink/permission skip, 0 failed; protected artifacts unchanged |
| `npm run build` | PASS after bounded refresh-family traversal |
| Phase 0 source guard | PASS |
| Guarded-runner contract tests | RED as intended: 25 passed / 5 failed; GREEN: 30/30 |
| Automatic top-level test inventory | PASS: 66 files = 5 ordered preflight + 61 main; no missing, extra, or duplicate file |
| `npm run smoke:phase0-fixtures` | PASS |
| `npm run smoke:phase1-identity` | PASS after correcting its stale fixture |
| `npm run smoke:guest-phone-migration` | PASS |
| Invite OTP focused unit files | RED as intended when reissue did not invalidate the expected token hash; GREEN: 59/59 |
| Bounded refresh-family traversal regression | RED: 18 passed / 1 failed because the 128-row case issued 128 lock queries instead of 1; GREEN: 19/19 with one bounded lock query |
| Phase 2 authentication lifecycle PostgreSQL smoke | PASS on all 67 migrations, including a 4,097-row overflow at the real production limit without modifying private static state |
| `npm run smoke:all` | PASS: final standalone run 30/30 on all 67 migrations |
| All sixteen named `smoke:phase2-*` gates | PASS: 16/16 on a managed isolated database with all 67 migrations; each remains separate from `smoke:all` |
| Flutter analysis | PASS |
| Flutter CI tests | PASS: 696/696 |
| Admin web typecheck | PASS |
| Admin web Vitest | PASS: 7 files, 51 tests; the ErrorBoundary render-failure messages were expected and the command exited 0 |
| Admin web `npm audit --audit-level=high` | PASS at the configured high-severity gate; 2 Moderate advisories remain and are documented below |
| Admin web production build | PASS locally; not deployed |
| Admin `smoke:honesty` | PASS: all assertions |
| Admin `smoke:routes` | PASS: all 16 routes against the local production build |
| Admin `smoke:admin-runtime` | PASS after bounded refresh-family traversal on a managed isolated database: MFA, cookie rotation, logout, PII redaction, and routes |
| Admin web Docker build | PASS; image not deployed |
| Backend Docker build | PASS: `aarast-backend:codex-remediation`, revision `development-unversioned`; in-image production prune reported 0 vulnerabilities; image not deployed |
| Final Gitleaks scan | PASS: tracked diff 905.31 KB and intended untracked source 392.44 KB contained no leaks; the earlier full-history scan also passed |
| Independent security re-review | CLOSED after the bounded recursive-CTE traversal and production-depth PostgreSQL proof |
| `node scripts/docs-sync.mjs --check` | PASS: drift 0, errors 0 |
| `node scripts/docs-verify.mjs` | PASS: errors 0, warnings 0 |
| Documentation diff/whitespace checks | PASS, including the untracked remediation receipt |
| Public API observation — 2026-07-26 | `https://aarast-api.shadowgardn.com/live` returned 200 with `{ok}`; `/ready` returned 200 with `{ready}` and database, Redis, media, and OpenWA all reported `up` |
| Public deployment provenance | NOT VERIFIED for this branch: the branch was not deployed and the public API exposes no revision endpoint that binds the observed runtime to this source state |
| Local development container | NOT READY: `/aarast-backend` uses `aarast-backend:local`, reports revision `development-unversioned`, state `running`, Docker health `unhealthy`; inside it `/live=200`, `/ready=503`, database/Redis `up`, media `down`, and OpenWA `disabled` |
| External OpenWA send smoke | NOT RUN intentionally because it sends through an external provider; public readiness `up` does not prove a real OTP send |

The public runtime was operational at the time of observation, but it is
unbound to this branch and is not evidence that this remediation was deployed.
The local development runtime is not ready because its media dependency is
down. Neither runtime result changes the verified local code verdict, and no
branch deployment or production-readiness claim may be derived from this
receipt.

The invite lifecycle smoke also proves concurrent issuance for one invitation,
database rejection of both invalid purpose/context combinations, old-token
reissue invalidation, and invitation-deletion cascade/race behavior. Its first
post-CHECK attempt exposed PostgreSQL `40001` through Prisma `P2010` rather than
`P2034`; retry classification was narrowed to that exact serialization signal
and the managed smoke then passed.

The final security review classified the former five-second refresh replay
grace as Medium because an attacker replaying the old token during that window
could leave the winning descendant alive. The grace was removed. New
application and administrator unit regressions prove immediate replay revokes
the winner, and the real PostgreSQL Phase 2 authentication lifecycle smoke
passes with the same contract while preserving independent login families.

A follow-up targeted RED proved that the safe fail-closed behavior still used
one lock query per generation: 18 tests passed and the 128-row regression
failed after observing 128 lock queries instead of one. The final implementation
uses one bounded recursive CTE with `max + 1` detection and `FOR UPDATE`, then
revokes all active rows for that user and realm when the family is incomplete.
Application overflow also publishes durable all-session revocation;
administrator overflow remains confined to the administrator realm. The focused
suite is now 19/19 with one traversal query. The real PostgreSQL authentication
lifecycle smoke builds 4,097 rows at the production limit, without modifying
private static state, and passes. Independent security re-review is closed.

The first attempt to run the final `smoke:all` concurrently with administrator
runtime smoke was rejected by the Redis isolation guard before either
application scenario started. This was an isolation-safety refusal, not an
application failure. Both commands were then run sequentially and passed.

The five intended guarded-runner REDs covered the package/runner/source-guard
contract before implementation. The final runner discovers top-level tests
itself, passes paths as argv with `shell: false`, rejects all additional
arguments, and is importable without executing tests.

Admin supply-chain note:

- `react-router-dom` was raised from `6.30.1` to `6.30.4`. Current `npm audit`
  still reports two new Moderate React Router advisories: open redirect below
  `7.18` and SSR hydration constructor injection.
- The live Vite administrator application is client-side rendered and does not
  use SSR hydration. Its `safeAdminReturnPath` additionally fails closed on
  external targets, encoded slash/backslash variants, query strings, and
  fragments; seventeen regression cases pass.
- `7.18.1` was evaluated and reverted because the audit then exposed a High
  advisory in unstable RSC behavior. The advisory-fixed `8.3.0` release was not
  published on npm at the time of this check. Therefore the configured
  high-severity gate passes, but this receipt does not claim zero administrator
  dependency vulnerabilities.

## Current Position

- Phase 0: **COMPLETE**
- Phase 1: **COMPLETE for sequential request/service boundaries**
- Phase 2 code remediation: **VERIFIED for the defined local code scope**
- Phase 3 backend: **COMPLETE locally; check/build/unit/smoke:all PASS**
- Phases 4-5 mobile: **OPEN only for the user-owned Android/device gate**
- Phase 6 Admin: **COMPLETE locally; deployment/browser proof unverified**
- Phase 7 runtime/monitoring: **LOCAL CONFIG PASS; off-host restore/alert BLOCKED**
- Phase 8 supply chain: **LOCAL CANDIDATE PASS; rollback/deployment proof OPEN**
- Phase 9 integrated acceptance: **PENDING the user-owned phone run**
- Public runtime: **OPERATIONAL AT OBSERVATION, BUT UNBOUND TO THIS BRANCH**
- Deployment of this branch: **NOT VERIFIED**
- Local development runtime: **NOT READY — media is down and `/ready=503`**
- External OpenWA send smoke: **NOT RUN — readiness does not prove OTP send**
- No commit, push, merge, or deployment was performed.
