# QA And Testing

Snapshot date: 2026-08-22

Snapshot source: the checked-out branch content. Resolve its immutable revision
with `git rev-parse HEAD`; local phase receipts do not imply a push, merge, or
remote-CI result.

This folder owns current testing expectations. Older QA files were archived
during the 2026-07 docs consolidation.

## Docs-Only Changes

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

The sync check detects generated reference drift. The docs verifier checks
documented routes, migration references, snapshot freshness, and Markdown
links. `git diff --check` catches whitespace errors. The active source list and
archive rules are owned by `docs/README.md`.

## Existing-Test Change Policy

Existing behavioral assertions, expected values, fixtures, Arabic/error
contracts, and setup semantics are frozen. A later move phase may make only
reviewed mechanical import/export/require edits, moved-source path-literal
edits, test-file moves, and DI token wiring edits required by that move. Any
other existing-test change is a stop signal and requires explicit review.

R5 Task 6 used that stop signal and received explicit owner authorization for
one test-only correction checkpoint. Exactly three stale smoke harnesses were
aligned with production contracts already present at `R5_BASE`: the Admin
notifications dependency, completed application-password fixtures, and valid
provider-transition ordering. Their base and approved bytes are pinned in the
R5 manifest and enforced by the live scanner. This is not a general fixture
exception; every other behavioral assertion, fixture, setup, error, timeout,
and selection remains frozen.

R0 itself adds tests and does not edit existing behavioral tests.

## Modular Monolith R1 Closeout Gates

Run the Mobile boundary and documentation gates from the repository root:

```powershell
node --test .\scripts\check-mobile-boundaries.test.mjs
node .\scripts\check-mobile-boundaries.mjs --check-baseline
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

Run the Backend gates from `backend/`:

```powershell
npm run architecture
npm run check
npm run build
npm test
npx prisma validate
npm audit --audit-level=high
npm audit --omit=dev
npm run smoke:all
```

Run the unchanged Admin quality gates from `admin-web/`:

```powershell
npm run typecheck
npm test -- --run
npm run build
npm run smoke:honesty
npm run smoke:routes
npm run test:container-config
```

Run the existing Mobile quality gates from `mobile/` after the root Mobile
boundary commands:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

R1 CI keeps the counted dependency, ownership, and Mobile baseline modes. The
phase-specific R0 fixed-base scope job is removed at R1 closeout; the local
`check-r0-scope` script and tests remain historical R0 evidence and are not
retargeted. The
Backend dependency command with `--no-ignore-known` and
`node .\scripts\check-mobile-boundaries.mjs --strict` deliberately expose
current migration debt and are expected to fail today; they are proof/debug
commands, not closeout gates. Dependency strictness is reached by removing the
known graph debt, while Mobile strict mode becomes the gate in R9.

R1 closeout additionally required the complete managed Backend smoke suite,
independent review, and the owner's application checkpoint; those gates passed
before R2 began. The closeout preserved 52 models, 76 migrations, every
route/error/Arabic/permission/transaction contract, Mobile and Admin source,
and deployment artifacts.

## Modular Monolith R4 Closeout Gates

- Fixed-base R4 scope and permanent near-miss gates passed for the exact
  Planning write port, Finance consumer, transaction identity, implementation
  ownership, and 22-path application candidate.
- Ownership is exactly the R4 base minus one frozen Finance-to-Planning
  `WeddingPlan.update` debt: 385 records / 781 occurrences. Architecture passed
  at 344 modules / 1395 dependencies / 89 known records, ownership 385, zero
  `forwardRef()`, two approved globals, and zero cycles or illegal edges.
- Backend check/build, 968/969 tests with one intentional Windows permission
  skip, Prisma validation, both zero-finding audits, money-budget 50/50,
  money-APIs 60/60, money authorization/concurrency, health, and all 30 managed
  smoke packages passed. Managed residue was zero.
- Immutable image `aarast-backend:r4-final-536890cc` at application revision
  `536890ccafcabebcd4d095a33c014933d6451fdb` passed probe/cutover, schema and 76
  migration discovery, zero restart/OOM, local/LAN live/ready HTTP 200, and safe
  log checks. R3 remains stopped and preserved for rollback.
- On the unchanged R3Local APK, the owner passed login, Home, Money budget and
  category save/reload, and force-close/reopen. Sanitized route evidence showed
  successful auth/session, money-budget writes and money-summary reads, with no
  HTTP 5xx or server fatal markers and no retained secrets or financial values.
- Independent review found no Critical, Important, or Minor issue. R4 is locally
  complete and is the immutable base for the approved R5 plan. No push, merge,
  deployment, PR mutation, or remote-CI result is claimed.

## Modular Monolith R5 Task 5A Security Checkpoint

- The exact `deepmerge-ts` 8.0.1 override, canonical package/lock
  fingerprints, installed `@prisma/config` resolution, recursive and ordinary
  merge semantics, input/primordial immutability, plain-data output, and
  isolated-worker completion passed the permanent security checker.
- R5 security/scope coverage passed 30/30 and rejects lock-only activation,
  unrelated dependencies, ranged overrides, Prisma version drift, and extra
  implementation paths. Independent adversarial review found no Critical,
  Important, or Minor issue.
- Full architecture/check/build and 1005/1006 Backend tests passed with one
  intentional Windows permission skip. Both npm audits reported zero
  vulnerabilities. Nine targeted managed smokes and all 30 aggregate smoke
  packages passed with zero managed residue.
- Prisma remained 6.19.3. Validate/generate passed at 14 schema files, 52
  models, 41 enums, and 76 migrations; DMMF and migration SQL stayed
  byte-identical. Frozen application, Mobile, Admin, schema, migration,
  deployment, workflow, and Dockerfile surfaces did not change.
- The immutable isolated image passed patched dependency identity, security,
  migration discovery, health/readiness, restart/OOM, and sanitized startup
  checks, then the probe was removed. The existing phone runtime was not cut
  over; no phone QA was required because application behavior did not change.

## Modular Monolith R5 Closeout Gates

- Fixed-base R5 manifest proves the exact 44 one-to-one Identity moves and
  rejects missing, extra, converging, overlapping, traversal, stale-root, and
  compatibility-path near-misses.
- R3 Nest/provider/controller/decorator/lifecycle inventories remain exact.
  The dependency baseline contains 31 records after the exact 58 authorized
  public-contract debts were retired; ownership remains 385 records / 781
  occurrences after deterministic path relocation only.
- Existing Auth, OTP, session, profile, context, account-deletion, WebSocket,
  scheduler, and route assertions remain frozen except mechanical import/path
  edits and the exact three hash-pinned Task 6 smoke-harness corrections.
- Full Backend architecture/check/build passed. Backend tests passed 1006/1007
  with one intentional Windows permission skip; Prisma equivalence, both
  zero-finding audits, nine targeted smokes, all 30 aggregate smoke packages,
  residue audits, frozen Mobile/Admin/deployment surfaces, and docs passed.
- The independent Task 6 review found one policy gap in three smoke fixture
  setup/order corrections. Immutable-base evidence and owner authorization
  narrowed this to a hash-pinned production-precondition exception; permanent
  scanner/tests reject any additional fixture or assertion drift.
- The immutable R5 image passed migration discovery, local/LAN live/ready,
  restart/OOM, dependency/security, and safe-log checks. The owner passed
  authenticated phone login, Home/context restore, representative reads and
  writes, and full close/reopen. Sanitized logs showed 237 events, 236 success,
  zero HTTP 5xx, and one controlled unauthenticated 401 probe.
- R5 is locally complete. R4 is stopped and preserved for rollback. R6
  application work is governed by the separately approved plan below; push,
  merge, PR mutation, deployment, and remote-CI claims remain forbidden.

## Modular Monolith R6 Closeout Gates

- Fixed-base scope passed for the approved manifest/scanner/tests, Identity
  public/internal delivery boundary, Collaboration injection cutover, exact R3
  reconciliation, generated script docs, and final receipts. R6 is strict with
  zero Collaboration concrete transport imports and two protected OpenWA files.
- Permanent adversarial tests reject another concrete sender, internal/full
  Identity imports, `useClass` duplication, token/type lookalikes, retries,
  swallowed/remapped unknown errors, changed input, provider-specific public
  types, protected OpenWA/OTP changes, and unrelated baseline movement.
- Aggregate architecture passed at 348 modules, 1405 dependencies, 31 known
  dependency records, ownership 385 records, zero `forwardRef()`, two approved
  globals, zero cycles/illegal edges, all 13 R3 contexts, and green R4, strict
  R5, and strict R6 gates.
- Backend architecture/check/build passed. Tests passed 1021/1022 with one
  intentional Windows permission skip. Prisma 6.19.3 validate/generate and
  equivalence passed; both npm audits reported zero vulnerabilities; all 30
  managed smoke packages, docs, protected surfaces, whitespace, and residue
  checks passed.
- A final verification-only correction updated stale R1/R3/Prisma receipts and
  relocated temporary test fixtures under the ignored fixture root. Repeated
  stress and full-suite runs proved the untracked-file race removed without
  changing a behavioral assertion, product implementation, or package lock.
- Immutable candidate `cefe07a76b0e615d4fecbb666514d9a2b87a7d37`
  passed image audit, migration discovery, isolated probe, protected cutover,
  local/LAN `/live` and `/ready` 200, database/Redis/media readiness, zero
  restart/OOM, and sanitized logs. R5 remains stopped and preserved for rollback.
- The authenticated phone checkpoint reached R6 and passed session/context
  restore, sharing reads, invitation create 201, reissue 201, related reads,
  full close/reopen, dashboard restore, and persistent sharing state. OpenWA
  was disabled and the UI reported delivery unavailable; no real WhatsApp
  delivery, credential, token, phone, OTP, raw body, or business value is
  claimed or retained.
- R6 is locally complete only. External Meta/OpenWA activation remains outside
  scope. At R6 closeout, R7 was approved but not started; the R7 closeout
  section below records its later local result. Push, merge, PR mutation,
  deployment, and remote CI are not claimed by R6.
- R7 design governance is executable: `npm run architecture:r7` must report
  design stage with 18 legacy sources and zero final targets, exact 31/385/781
  baseline evidence, nine dependency handoffs, and 28/80 ownership projection.
  The cumulative `npm run architecture` gate must pass before Task 1 and every
  later R7 checkpoint.

## Modular Monolith R7 Closeout Gates

- Fixed-base R7 scope passed for the exact 18 moves, 114-path fence, four
  public snapshot exports, constructor/controller/decorator handoffs, nine
  dependency retirements, ownership path projection, permanent scanner/tests,
  application checkpoints, and final receipts.
- Strict R7 reports source 0, target 18, dependency 22, and ownership 385/781.
  Both retired roots are absent and no compatibility facade or duplicate
  runtime export remains.
- Permanent adversarial coverage rejects loader/re-export aliases, protected
  internal access, builder facades, duplicate runtime/CommonJS exports,
  indirect Nest globals, receiver/value-origin bypasses, ambient false
  positives, and straight-line or branch-ambiguous CommonJS export versions.
- Architecture/check/build passed. R7 tests passed 210/210; full Backend tests
  passed 1242/1243 with zero failures and one intentional Windows skip.
  Prisma 6.19.3 validate/generate, 52/41 DMMF, no-difference migrate proof,
  both zero-finding audits, 11 focused managed smokes, all 30 aggregate smokes,
  docs, protected surfaces, and cleanup passed.
- Independent cumulative review approved candidate
  `aafb47ea1742c278f6a5ed24799ada7bc23721b0` with no Critical, Important, or
  Minor finding.
- Immutable image `aarast-backend:r7-candidate-aafb47ea` passed in-image audit,
  isolated probe, local/LAN `/live` and `/ready` 200, database/Redis/media up,
  restart 0, OOM false, sanitized logs, and probe cleanup. R6 remains stopped
  and preserved for rollback.
- The authenticated phone gate passed session/context/dashboard restore,
  synthetic invitation create 201, cooldown/reissue 201, sharing reads 200,
  cancellation 200 with post-cancel absence, and force-close/reopen restore.
  OpenWA remained disabled; no real recipient, credential, token, OTP, phone,
  raw body, screenshot, or business value was retained.
- R7 is locally complete only. R8, push, merge, PR mutation, deployment, and
  remote CI have not started.

## Modular Monolith R3 Closeout Gates

- Fixed-base R3 scope PASS at exactly 214 reviewed paths and zero unexpected
  paths; protected schema/migrations/seed/Admin/deployment/workflow/lock-file
  surfaces remain unchanged.
- Backend architecture is strict at 13 contexts, zero remaining duplicate
  registrations out of 3, zero platform debts out of 6, zero retired provider
  edges out of 163, zero `forwardRef()`, exactly two approved globals, zero
  cycles, and zero illegal edges. Backend check/build/tests/audits and all 30
  managed smoke packages passed; schema remains 14 files/52 models/41 enums/76
  migrations with equal DMMF and empty migrate diff.
- Admin gates and Mobile boundaries remained green. The exact phone-discovered
  ApiClient restore regression passed RED-to-GREEN, Flutter analysis passed,
  and the complete non-Golden Mobile suite passed 1102/1102; no UI source
  changed, so Goldens were not rerun.
- Immutable image `aarast-backend:r3-final-dfc5488c` passed protected probe,
  cutover, revision, zero-restart/OOM, local/LAN `/live` and `/ready`, and safe
  log checks. Prior R3 and R2 runtimes remain preserved as rollback artifacts.
- The owner logged in and reached the dashboard in the corrected R3Local APK.
  Independent ADB force-stop/relaunch then proved `SESSION_RESTORED=1`, restore
  failure/logout/teardown=0, `/api/v1/auth/me` HTTP 200,
  `/api/v1/auth/logout`=0, and the authenticated dashboard visible. No secrets
  or raw bodies/logs were retained.
- R3 is locally complete and provided the immutable base for R4; no R3 push,
  merge, deployment, or remote-CI result is claimed.

## Modular Monolith R2 Closeout Gates

R2 uses the R1 commands above plus the explicit fixed-base scope verifier,
Prisma generation and equivalence fingerprints, contributor/guest migration
rehearsals, and immutable Docker inspection/runtime. Local R2 results on
2026-08-14 were:

- R2 scope PASS with the reviewed 49-path manifest and unchanged protected
  Backend application, migration, seed, package, Mobile/Admin, workflow,
  Compose, and deployment surfaces.
- Physical/equivalence gates PASS: 14 schema files, 52 models, 41 enums, 76
  unchanged migrations, byte-identical seed, equal normalized DMMF, and empty
  migrate diff.
- Backend architecture/check/build PASS; 848/849 tests PASS with one expected
  Windows permission skip; both migration rehearsals and all 30 managed smoke
  packages PASS; both npm audits report zero vulnerabilities.
- Admin typecheck/build PASS, tests 96/96, honesty 12/12, routes 16/16, and
  container config 3/3. Mobile boundaries 192/192, baseline 269, analyzer clean,
  and tests 1151/1151 PASS.
- Docs sync/verification/whitespace PASS with zero drift, errors, or warnings.
- Immutable R2 image inspection, protected R1/R2 probe/cutover, localhost/LAN
  `/live` and `/ready`, dependency readiness, revision, zero-restart, and safe
  log gates PASS. The stopped R1 container/image remain rollback evidence.
- Owner phone checkpoint PASS only after installing the corrected, separately
  packaged R2Local APK. The initial APK embedded the old loopback R1 URL and
  emitted no R2 HTTP event; it was a client configuration failure, not a
  Backend result. Sanitized R2 logs then proved successful login and
  authenticated read/write requests without retaining secrets or raw bodies.

Expected non-failing Backend negative-path/DEP0190 output, Admin ErrorBoundary
fixture output, Flutter desktop plugin notices, the initial absent
`DATABASE_URL` Prisma result, and the first `adb` PATH lookup are recorded in
the full receipt in `docs/project/STATUS.md`. Final independent R2 sign-off is
requested; at that R2 checkpoint, R3 had not started. Remote CI was not run,
and no push or merge is claimed.

## Latest Recorded Full Working-Tree Gate — 2026-08-11

- Backend source guard/check/build/Prisma validation: PASS; unit suite PASS with
  670 tests (669 passed, one intentionally skipped); all 30 managed smoke
  packages PASS after all 76 migrations on a disposable database.
- Admin React Router 7 migration: type-check/build PASS, Vitest `96/96`, routes
  `16/16`, honesty `12/12`, container config `3/3`, and full npm audit with zero
  findings. The previous moderate advisories are closed.
- Mobile analysis PASS; `flutter test --no-pub` PASS, `1150/1150`; debug APK
  build against the public API origin PASS. Desktop plugin-resolution notices
  remain toolchain noise and did not fail analysis, tests, or Android build.
- Deployment source contracts PASS, `38/38`; public-site Docker build and live
  route checks PASS with allowlisted routes `200` and fail-closed routes `404`.
- Generated-doc sync/check PASS with zero drift; docs verification PASS with
  zero errors/warnings; `git diff --check` PASS.
- Backend and Admin full npm audits PASS with zero findings. Mobile dependency
  upgrades remain a separate compatibility pass.
- Physical iOS and exhaustive Android secondary/offline-mutation coverage:
  BLOCKED/OPEN as detailed in `MOBILE_QA.md`.

## Local Runtime Refresh — 2026-08-11

- Local rebuilt Backend readiness: PASS — `/live=200` and `/ready=200`, with
  database, Redis, and media all `up`.
- This local readiness result is not a Production deployment, Production
  migration, external-service, or physical-device acceptance result.

## Production Acceptance - 2026-08-11

- Application revision `959c47b756d0bebc3e4e4fda5f81ae3349d05e62` is live.
  Immutable Backend, Admin Web, and public-site containers are healthy with the
  same revision label, zero restarts, and no OOM termination.
- Fresh production backup SHA-256
  `1c327dab578ee8879a2dd845f37d8d736dc5e76ad600bfbe3089294d55ff6c82`
  passed checksum/catalog inspection, full isolated restore against the exact
  Backend image, all 76 migrations, a second idempotent pass, schema checks,
  and relational postconditions.
- Live migration truth is 16 plans, 16 linked contributor-history scopes, zero
  missing scopes, zero lifecycle mismatches, zero missing tenures, and zero
  unfinished migrations.
- External Backend `/live` and `/ready`, Admin `/login`, public privacy/support/
  invite routes, Android association, TLS, and security headers PASS. Unknown
  public routes and Apple association return the intended `404`.
- Managed catalog bootstrap PASS with 55 money items, 39 provider categories,
  7 cities, and 22 governorates; exact-version replay is unchanged.
- This closes the current API/Admin/public/database deployment gate. It does not
  close real-device WhatsApp OTP, Push, contributor/session, iOS, Sentry,
  metrics/monitoring, AAB/store upload, or store-review gates.

## Backend Changes

Start the root Docker Compose PostgreSQL, Redis, and MinIO services before a
backend smoke command. Mutating smoke, admin-runtime smoke, and `load:test`
must run through the managed isolation wrapper; it starts a source backend on
a temporary port and never targets the development backend on `3115`. A run
fails closed if its database name lacks `smoke`/`test`, its Redis namespace is
not empty, or any URL/resource differs from the exact run id. Do not invoke the
underlying fixture scripts directly.

```powershell
cd D:\projects\aarast\backend
npm run check
npm run build
npm test
npm run smoke:auth-verification
npm run smoke:sharing-security
npm run smoke:marketplace
npm run smoke:reference-catalog
npm run smoke:phase2-provider-rating-concurrency
npm run smoke:provider-dashboard
npm run smoke:private-chat-media
npm run smoke:money-apis
npm run smoke:financial-ledger-concurrency
npm run smoke:all
```

Money-domain changes additionally fail unless tests prove:

- live schema, controllers, and mobile source contain no removed finance model,
  route, or cache contract;
- fresh and upgraded databases contain only BudgetCategory, WeddingCost,
  CostPayment, and PaymentSchedule for the money domain;
- every cost has one valid category and at most one party mode (provider or
  external party);
- initial payment creation is atomic, ordinary payment cannot exceed the
  outstanding cost, reversal is append-only and unique, and concurrent
  schedule-payment requests create one payment only;
- WeddingCost has no due-date field across schema, DTO, response, mobile cache,
  offline import, and API examples; `PaymentSchedule.dueDate` is the only
  payment-reminder date;
- a pending schedule remains a non-reserving reminder: it never changes totals,
  reserves outstanding balance, or blocks a direct payment;
- each schedule amount is independently no greater than the row-locked
  outstanding cost on create/update; other pending reminders are not summed as
  reservations, and any payment that completes a cost cancels all remaining
  pending reminders;
- a null general budget stays null and category allocations never replace it;
- repeated acceptance of one provider offer creates exactly one WeddingCost,
  returns that cost, chooses a logical category or creates `أخرى`, and creates
  no payment, schedule, task, or booking;
- schedule payment always returns `{ payment, schedule }` to direct and replay
  clients, and local summary paid totals come from PAYMENT minus REVERSAL rows;
- the atomic money-budget route accepts `categories: []` for budget-first setup
  without creating a placeholder category and rejects any positive allocation
  when `totalBudget` is null; the mobile form prevents an entirely empty no-op
  write before calling that route;
- an HTTP `OPTIONS` preflight for the canonical money-budget route advertises
  `PUT` in `Access-Control-Allow-Methods` without widening origin or header
  policy;
- schedule warnings expose counts with `amount: null`, so overlapping reminders
  are never summed or presented as debt;
- direct SQL insert/update of one pending schedule above the current outstanding
  cost is rejected, while overlapping reminders within that per-row limit are
  allowed and remain non-reserving;
- `canViewMoney` and `canManageMoney` fail closed across summary, detail, direct
  route, dashboard, notification, and sharing flows;
- removed finance endpoints return `404` with an authenticated request.

For temporary OpenWA OTP work, additionally run the OpenWA channel, durable
quota, readiness, registration, admin MFA, admin password-recovery, and
application password-reset tests. Auth gates must prove legacy unverified-row
claiming, separate app/admin hashes, stable post-proof error codes, neutral
admin recovery responses and transport timing, persisted session scopes,
separate login throttle realms, private `ADMIN_LOGIN` OTP binding, a 72-byte
bcrypt boundary, one-time concurrent challenge consumption, protected admin
identity deletion/profile updates, and no raw phone or challenge token
persistence.
The release gate is not complete until the pinned hardened fork itself passes
its tests and a real QR-linked session proves the sent OTP marker is absent
from message history, database rows, logs, hooks, and webhooks. A mocked Aarast
adapter test is necessary but not sufficient.
The fork contract tests must require `messageId` plus
`deliveryStatus: DELIVERED` after a device-delivery acknowledgement, keep a
sent-only acknowledgement uncertain, exercise `NOT_ATTEMPTED`, `REJECTED`, and
`DELIVERY_UNCERTAIN`, reject an otherwise successful `QUEUED` or incomplete
acknowledgement, prove the
`@c.us`-to-`@lid` fallback, and ensure only a true timeout triggers Chromium
force recovery.

The official Meta-channel contract tests must separately prove that a valid
2xx message id returns `PENDING`; timeout/abort, connection failure, 5xx, and a
malformed accepted response become `UNCERTAIN`; an explicit 4xx remains a
definitive rejection except transport-ambiguous `408`, `425`, and `499`; and no
provider body, phone number, or OTP is copied into an error.

After QR linking, run `npm run smoke:openwa-otp` only with a dedicated test
recipient and the explicit `OPENWA_SMOKE_CONFIRM=I_ACCEPT_REAL_WHATSAPP_SEND`
guard. The smoke performs one real send and fails if its unique marker appears
in the OpenWA message-history API. Database/log/hook/webhook inspection remains
a separate manual gate because the public history response cannot prove those
stores are empty.

Participant invitation tests must also prove that create/reissue uses only the
hardened transient endpoint, the WhatsApp text contains one private HTTPS link
and no plan details, delivery uncertainty is not reported as success, a
token-phone mismatch sends no OTP, and a matching phone can verify and review
the invitation without creating membership or an owner plan. Tests must prove
that no accept/decline call occurs before a visible user decision, then cover
both explicit rejection and explicit acceptance followed by opening the
contributor plan. Opening a private
link while another account is signed in must not query the token as that
account; after OTP changes the account boundary, the in-memory token must resume
at the same explicit decision screen.
Acceptance coverage must continue through the cross-account read model: the
owner invite list must expose the accepted row as `ACCEPTED`, owner dashboard
`pendingInvites` must become zero for that invite, and the invitee contexts list
must contain the canonical contributor context. Replaying an acceptance after a
lost response must return the same member/context without another owner
notification, while another user fails closed. Mobile tests must also prove
single-flight acceptance, reconciliation after an ambiguous response, owner
refresh on app resume/return from sharing, contributor-context refresh on
resume, and latest-wins behavior for overlapping invite/dashboard loads.
Decline coverage must prove that concurrent requests and a lost-response retry
by the same verified invitee return the same `DECLINED` result, create one
owner notification, and expose no invitation lifecycle to another account.
Membership-revocation coverage must prove that an accepted invitation remains
historical `ACCEPTED` with `acceptedAt` but loses `contextKey` when its
`SharedMember` is removed. Flutter must render the explicit Arabic ended-
membership state and no plan-entry action. Member removal must revoke every
live pending invitation matching the target user id or normalized phone before
deleting the member, so an old bearer cannot recreate access. Plan archive must
revoke all remaining live pending invitations in the same transaction while
leaving terminal history unchanged. Owner sharing-screen tests must use a
controlled refresh interval and prove that polling runs only while pending
invitations exist, causes no loading flicker, reconciles the terminal state, and
stops afterward. Overlapping invite, sharing-access, plan-selection, and
dashboard requests must all be latest-wins.
Invite delivery coverage must also prove that the stored delivery status and
attempt time survive list refresh, every status obeys the server-provided retry
window, rapid reissue returns the stable 429 contract, and a late completion
from a superseded token returns 409 without overwriting the newer attempt or
returning an invalid raw bearer. Historical rows must remain `UNKNOWN`, not be
backfilled as a delivery failure.

For private chat media, additionally verify that a non-participant receives no
attachment metadata or signed URL, message/list responses contain no
`storageKey`, links expire after 120 seconds, and the object-store
`chat-image/` prefix rejects an unsigned GET. A member must be able to refresh
an expired link through the authenticated conversation attachment route. The
media smoke must perform a real signed upload with the returned
`If-None-Match: *` header, call `/api/v1/media/uploads/verify`, and persist only the
verified reference. Source tests must exercise full decode/re-encode,
appended-payload removal, invalid image rejection, dimension/pixel bounds, and
conditional replacement behavior.
The HTTP smoke must also prove that presigning creates a durable account-owned
upload ticket, verification leaves it unconsumed, and persisting the provider
image or chat attachment marks it consumed. Source tests must cover the rolling
per-account count/byte quota, cross-replica advisory lock, expired/stalled
ticket cleanup, and retry retention when object storage is unavailable.

The root Docker Compose environment includes MinIO-compatible object storage
and bucket initialization for local media smoke. `/ready` must report media as
`up`; a run where media is `disabled` is not evidence for the media release
gate.

For Backend notification settings, tests must prove that
`channelCapabilities.push.supported` follows runtime Firebase Push capability,
while `channelCapabilities.push.enabled` follows the account's enabled device
installation. Tests must also prove that an expected `GET /ready` `503` probe
failure is not emitted to the error log or Sentry, while other `5xx` failures
remain reportable.

For unified provider conversations, database and live API coverage must prove
that two requests for the same plan/provider reuse one Conversation, while a
different plan or ACCOUNT requester receives a different Conversation. Every
QuoteRequest must have `conversationId`; the two partial unique indexes must
report zero duplicates; deleting a QuoteRequest must leave its Conversation.
The smoke must also cover a concurrent creation attempt, a provider without a
User, a provider linked later, timeline order/system-event dedupe, message-only
unread, personal mute, side-level block, report/attachment privacy, and durable
notification/outbox idempotency.

Authorization coverage must exercise the plan owner, an explicit
`canManageProviders` member, a member without that flag, the ACCOUNT requester,
and the linked provider. Revoking the flag must return 404 to REST immediately,
mark any Participant revoked, and eject the current Socket.IO room. Live
coverage must also prove that an explicit false on a role whose defaults grant
provider management is denied by both provider APIs and conversation access.
Flutter coverage must include PLAN/ACCOUNT labels, one inbox row with multiple
request count, read-only quote lookup, event navigation, provider-not-joined
state, error/retry, reconnect, permission revocation, and duplicate-free
pagination.

Provider review concurrency coverage must prove that create, rating update,
delete, admin hide/publish, and reviewer-account deletion always leave
`Provider.ratingAverage` and `ratingCount` equal to a direct aggregate of
published `ProviderReview` rows. The live smoke must exercise interleaved
mutations repeatedly on a managed isolated database and leave no disposable
resource behind.

Provider price coverage must send oversized and over-precision values through
the live service, package, and quote-offer create/update routes, require `400`,
and prove that no new row or partial update reached PostgreSQL. Source tests
must also keep admin service writes and marketplace filters on the same central
money validator.

## Contributor Access And Frozen History Gate - 2026-08-02

This is one cross-layer release gate, not a Flutter visibility test. The test
environment must use an isolated PostgreSQL database and real Backend HTTP
responses. The final report must bind results to the exact revision and state
whether each item is PASS, FAIL, or BLOCKED.

### Migration And Historical Data

- Apply `20260802090000_add_contributor_history` to both a fresh isolated
  database and an upgraded database containing representative legacy plans,
  members, tasks, quotes, invites, guests, and money rows. Run migration deploy
  twice to prove terminal behavior without resetting or using `db push`.
- Verify one history scope per plan, one active tenure per current member, the
  partial uniqueness rule for actor reference within a scope, per-tenure
  dedupe, section/entity checks, snapshot size/hash checks, lifecycle checks,
  and the trigger that rejects every `ContributionEvent` UPDATE or DELETE.
- Inspect legacy attribution row by row. Only direct task assignment, quote
  creation, and invite creation with a matching current tenure may be
  backfilled. Accepted membership alone and old guest/money rows must remain
  unattributed. Unsafe legacy text must be omitted, not rewritten or silently
  assigned to a contributor.
- Record `historyCoverageStartsAt` and communicate that pre-cutover work is not
  claimed unless explicit legacy evidence produced a `LEGACY_EXPLICIT` event.

### Stored Authority And Live Data Isolation

- Create one owner and two contributors in the same plan. Give them different
  stored permissions, including an explicit `false` on a role whose invitation
  defaults would otherwise grant the section. Changing only the role must not
  overwrite that explicit false or re-grant the permission.
- For tasks, guests, money, providers/quotes, members, dashboard aggregates,
  notifications, direct detail routes, and mutation routes, prove Contributor A
  receives only rows assigned to A or supported by A's own allowed
  created/completed contribution evidence. Contributor B's rows and counts must
  be absent from the raw HTTP payload, not merely hidden by Flutter.
- A current membership and the current stored section flag are mandatory even
  when a qualifying contribution exists in the current or a previous tenure.
  After revocation, new rows, later updates, dashboard details/counts,
  notifications, direct ids, conversations, and mutations for that section
  must be inaccessible immediately.
- Task mutation after revocation must return HTTP `403`, stable code
  `TASK_PERMISSION_REVOKED`, and `لم تعد لديك صلاحية لتنفيذ هذه المهمة`.
  It must not return the misleading `Plan not found`. Other privacy-sensitive
  not-found contracts remain unchanged unless their API contract explicitly
  defines a typed denial.
- Repeat the permission update concurrently with a read and a write. The
  transaction/lock order must make one authority version win without a window
  that leaks a post-revocation row or permits a stale mutation.
- Create pending invitations under a delegated member, then narrow one stored
  permission while leaving `canInviteMembers=true`. Invitations above the new
  ceiling must become `CANCELLED` in the same transaction; invitations still
  inside the ceiling remain pending. Disabling either the plan owner or the
  delegated inviter must make acceptance fail atomically with
  `INVITE_AUTHORITY_INACTIVE` and no membership/history/notification write.

### Immutable Snapshot And Privacy

- Before revocation, let Contributor A create and complete representative
  records in every supported section and save the snapshot returned for each
  action. Also assign an owner-created item without letting A act on it. Revoke
  one section and verify that no live row is queried or copied during
  revocation, the assignment-only item is absent from history, the original
  action-time snapshots remain, and one `SECTION_REVOKED` boundary is appended
  before the stored permission change commits.
- Save each returned snapshot and hash, then let the owner edit or delete the
  original live record. Reload history and compare exact JSON and hash values;
  the frozen record must not change and must not depend on the live row.
- Contributor A may list only A's history. Contributor B must receive no event,
  contributor reference, snapshot, count, or entity correlation belonging to
  A. The owner may query plan history according to the owner contract.
- Raw list and summary responses must expose no live `entityId`, phone, email,
  token, authorization value, request body/header/query, message, note,
  attachment, address, or contact field. Test forbidden keys, forbidden values,
  excessive depth/count/size, canonical hashing, dedupe replay, and conflicting
  dedupe-key rejection.
- Re-inviting the same account creates a new tenure. Historical events remain
  attached to their original tenure, while actor reference may identify that
  person's qualifying prior work only after the new membership and current
  permission gates pass.

### Leave Plan And Delete Account

- Call `DELETE /api/v1/wedding-plans/:weddingPlanId/members/me` with a stable
  client request id. Verify one transaction revokes matching pending invites,
  retains prior action-time history, records `MEMBER_LEFT`, closes the tenure, clears
  `activeWeddingPlanId`, removes membership and live conversation/notification
  access, and preserves immutable plan history. Replay the same request and
  require the same terminal result without duplicate history or side effects.
- Before the DELETE leaves the device, persist an installation/user/plan-bound
  cleanup marker containing the stable request id. An ambiguous response,
  process death, cache clear, or ordinary logout must retain the marker and
  quarantine the plan. Replay it before contexts load, delete the exact local
  plan graph, refresh filtered contexts, and only then remove the marker. A
  definitive non-retryable 4xx removes the marker and surfaces the error.
- Every plan-scoped offline queue row must contain an explicit `planId` and the
  final send guard must reject missing, contradictory, or cross-plan ownership
  without issuing a request. Legacy migration may trust only matching top-level
  `planId`/`weddingPlanId` strings; it must never infer ownership from endpoint,
  local entity id, cache key, nested JSON, or substring matching. Prove deleting
  `plan-1` cannot delete or coalesce a `plan-10` row.
- After leave, refresh contexts, restart/re-login, and prove the contributor
  plan no longer appears. A new verified invitation may create a new tenure and
  restore only the newly granted live permissions; the old membership or
  pending bearer must not return.
- Exercise central account deletion as an owner/groom, provider, contributor,
  and multi-context account. Mobile surfaces must reuse the same typed
  confirmation and Backend endpoint. Contributor tenures in other owners'
  plans close with `ACCOUNT_DELETED`, the User reference detaches, immutable
  plan history remains, and no deleted account context can be restored.
- Include one dual administrator/application identity. From an
  `APPLICATION` session, deletion must clear all app credentials/profile/data,
  app media, push registrations, application OTPs/idempotency rows and
  `APPLICATION` refresh sessions, but must retain the administrator row,
  password/profile/avatar, admin challenges/audit links/idempotency rows and
  `ADMIN` refresh sessions. Prove the administrator can still authenticate in
  the browser realm and the deleted app identity cannot refresh or restore an
  app dashboard.
- Before the first account-delete request, require a secure durable marker with
  one stable high-entropy client request id and unmount all dashboards. Simulate
  a committed DELETE whose HTTP response is lost, restart the client, and prove
  `POST /api/v1/account-deletions/status` returns `DELETED` from the immutable
  anonymous receipt. A fresh in-flight reservation returns `PENDING`; only a
  definitive rejection plus `NOT_STARTED` may clear the marker and restore the
  still-live account. The status response must never reveal account fields or
  deletion-graph details. While status is `PENDING`, Flutter must not issue a
  competing DELETE; it stays behind the termination gate, preserves the same
  request id, and offers a later status retry instead of creating a 403/503
  replay loop.
- Keep `الخروج من المساحة`, `مغادرة الخطة`, account logout, and final account
  deletion as four distinct tests. None may be accepted as evidence for
  another.

### Flutter And Live Scenario

- Widget tests must render the real contributor workspace at 320px RTL with
  1.3 and 2.0 text scale. Create actions stay inside their cards as full-width
  Arabic `FilledButton.icon` controls, no `FloatingActionButton` is mounted,
  labels are not clipped, and revoked actions/sections disappear after an
  authority refresh without leaving stale data.
- The history screen must cover loading, empty, populated, Arabic error/retry,
  plan switching, stale-response rejection, coverage notice, and read-only
  cards with no live-entity navigation. Its strict DTO must reject malformed
  rows, duplicate ids, invalid dates, non-string keys, and overlapping or
  inconsistent pagination instead of silently dropping or truncating history.
  Account-action tests must cover leave
  success, ambiguous retry with one request id, failure, context refresh,
  logout, and central account deletion.
- Run Backend and Flutter against the same isolated runtime. With the owner and
  two contributors above, revoke A, edit the owner's original rows, prove A's
  snapshot is unchanged, prove B sees none of A's data, leave as A, re-login,
  and accept a new invitation. Capture raw API responses and the visible mobile
  states for every step.

Focused source tests are necessary but not sufficient. The 2026-08-03 physical
Android run is historical evidence: it installed and launched without a fatal
process/database error, then correctly stopped at the explicit context-load
retry state because Production still had the old account-deletion contract.
The 2026-08-11 deployment receipt above closes that API/migration mismatch; it
does not retroactively turn the old device run into an accepted contributor
flow. Repeat the owner/two-contributor scenario against the deployed revision
without adding a Flutter fallback to the old contract.

The remaining native gates are that post-deployment Android scenario, an iOS
physical-device scenario, real WhatsApp OTP and background/terminated Push,
and a repeatable CI/store release configuration. Native Android/iOS acceptance
must additionally rehearse the full
SQLCipher schema-v6-to-v7-to-v8 chain: the version 7 migration must leave
unknown legacy queue rows permanently blocked rather than guessed or sent, and
the version 8 migration must create `cached_dashboard_summaries` without losing
the migrated queue, ownership metadata, or existing cached data.

## Mobile Changes

```powershell
cd D:\projects\aarast\mobile
flutter analyze
flutter test
```

Run targeted tests for touched flows and check Arabic/RTL layout at narrow phone
widths for UI work.

### Session And Account-Context Regression Gate

Any change to authentication, secure storage, account contexts, push teardown,
offline data, or authentication-driven routing must prove all of the following:

- In `Provider Login -> Dashboard -> Logout -> Groom Login`, the provider
  Dashboard is absent immediately after Logout starts. The assertion must test
  that the widget is not mounted or built, not only that it disappears quickly.
- A hanging push unregister cannot keep the old Dashboard visible. Local
  cleanup failure exposes the retry-only termination screen, while remote
  timeout or failure leaves the local session terminated.
- A stalled Push registration cannot starve local Logout or the next account.
  Logout cancels and detaches the old request immediately, every local cleanup
  stage has a bounded watchdog, and a watchdog expiry enters the retry-only
  termination state instead of spinning indefinitely.
- Account Logout clears the account binding but keeps the device-scoped FID and
  FCM token. A late old-account request cannot mutate a newer binding, and app
  resume plus FCM token refresh revalidate the current account.
- Login, registration, and ordinary session-establishing actions are rejected
  unless the state is `unauthenticated`. The one intentional exception is an
  authenticated account switch backed by a validated private-invite token; it
  remains blocked while checking or terminating and is covered by invite-flow
  tests. Completion of an old Login, context load, token refresh, cache
  operation, or navigation intent cannot mutate a newer session.
- The explicit states `checking`, `authenticated`, `terminating`,
  `terminationFailed`, and `unauthenticated` each render their defined UI.
  Login and Dashboard routes must not bypass the three blocking states,
  including through a deep link.
- A fresh multi-context Login renders the standalone Arabic
  `اختر المسار` chooser without first building any Dashboard. A
  single available context may enter directly, and selecting groom, provider,
  or contributor produces one matching Dashboard and one effective transition.
- A contributor workspace refreshes its account-context authority together with
  dashboard data on app resume and after returning from a protected section.
  Visible mutation actions use the intersection of those permission snapshots,
  so stale dashboard data cannot expose an action rejected by the route gate.
  A contributor plan center mounted behind `WeddingPlanContextGate` must perform
  one authority refresh on resume without entering a refresh/remount loop.
- During an account-context authority refresh, both entry and plan-context
  gates render the checking state. A refresh failure must render its explicit
  error state even when older contexts were previously loaded; stale
  contributor routes or actions must not remain visible.
- A cold restart restores only a version-2 selection whose `userId` matches the
  restored user and whose `contextKey` remains in the fresh API result.
  Different-user, revoked, missing, and malformed selections are cleared. A
  legacy raw selection may migrate once and must still pass current-context
  validation.
- Full Logout clears the context key. `exitWorkspace()` remains a separate
  operation and must not be tested as account Logout.

The focused suite is necessary but not sufficient. The release candidate must
also run the complete Flutter tests plus integration coverage for Login,
Logout, context choice, cold restart, deep links, interrupted Logout, and app
termination during transition.

### Mobile Observability And Privacy Gate

Tests must use fake sinks/transports and prove:

- every event, Sentry event, breadcrumb, and diagnostic attachment passes
  redaction; no access/refresh token, password, phone, email, cookie,
  authorization value, header, query value, request/response body, or raw
  account identifier leaves the logging boundary;
- user, account-context, session, wedding-plan, and Firebase installation
  identifiers are installation-salted hashes, while client and backend request
  ids remain available for correlation;
- the memory ring retains no more than 300 events, 256KB, or 15 minutes,
  whichever bound is reached first, and no `*.log` file is created;
- Error/Fatal events reach the Sentry event sink, lower-level trace events
  become redacted breadcrumbs, and one Flutter error is not captured twice;
- API trace records only method, sanitized route template, status, duration,
  attempt, `X-Client-Request-Id`, and returned `X-Request-Id`, including a
  stable client request id across the single guarded `401` retry;
- the Support action explains the report, requires fresh consent on every send,
  creates `aarast-diagnostic-report.json` only in memory, performs no automatic
  retry, and reports failure without persisting the attachment.

Staging acceptance must verify correct Sentry environment/release labeling,
Android symbols and iOS dSYM symbolication, mobile/backend request correlation,
absence of PII, and the consent-gated attachment. Sentry attachment access must
be restricted operationally to Owner/Admin and the targeted 30-day retention
must be configured and checked in Sentry; neither policy is enforced by Flutter
code.

Push changes additionally require an Android APK build, inspection of the
merged manifest for `POST_NOTIFICATIONS` and the `aarast_updates` channel, and a
physical-device Firebase send while the app is backgrounded and terminated.
Unit tests and a successful APK build do not prove Firebase Console, server
credentials, or live delivery.

The complete Money gate covers the real root and every sub-screen at 320px RTL
with 1.3 text scale: budget management, category create/edit/detail, cost
list/create/edit/detail, payment create/detail/reversal, and payment-schedule
create/detail/pay. It must also cover first use, unset budget, empty, healthy,
near-limit, over-budget, read-only, denied, offline, pending, error/retry,
cancelled cost, paid cost, and reversed payment states. Goldens must render the
actual routed screens, not only isolated hero widgets.

Mobile contract tests must prove that payment entry inherits category and
provider/party from its cost, inline category creation returns to the cost form
selected, accepted quote context is only applied after confirmation, access
revocation clears cached rows, plan switching cannot leak prior money, and the
offline queue preserves dependency and idempotency rules.

OTP UI changes must prove the resend action remains actually disabled for the
full 60-second server cooldown and becomes enabled at the same boundary.
OpenWA tests must also distinguish explicit definitive delivery rejection from
an ambiguous post-send outcome. Only `NOT_ATTEMPTED` and `REJECTED` consume the
new OTP; `DELIVERY_UNCERTAIN`, a sent-only acknowledgement, an unknown/malformed
5xx, a transport break, or an incomplete 2xx acknowledgement keeps it active,
returns no code in the HTTP response, advances the mobile UI to code entry, and
shows a safe notice instead
of a false unavailable error.

Session/privacy changes must include a two-account same-device regression:
logout must dispose the first account's providers before network logout
finishes, a late response must remain unreachable, plan switching must replace
plan-sensitive providers without rebuilding navigation, and an in-flight
offline item must retain user A's token rather than replay with user B's token.
Guest onboarding must also prove that an explicitly empty budget opens the
local dashboard and that a legacy saved no-budget plan is recovered.
Secure-storage tests must prove that production wiring never leaves the cached
safe-user profile or guest-onboarding draft in SharedPreferences and that a
legacy plaintext value migrates once and is removed.

Invitation links remain the first-link-only path and must not turn account
context selection into a second authentication flow.

### Mobile Release And Rollback Gate

Before wider rollout, run and report separately:

- full `flutter analyze` and full `flutter test`;
- Login/Logout/account-context integration tests;
- Android debug APK and signed Release APK/AAB, including Sentry symbol upload;
- iOS Archive on macOS, including dSYM upload;
- the primary scenario on one physical Android and one physical iOS device,
  repeated with a slow network, network loss during Logout, API failure, and
  app termination during transition.

The latest direct-install Release APK is `1.0.0+8`, built from source revision
`2ffbe95d7a8e412ead47220536046501f4ac86bf`. It is non-debuggable, targets SDK
36 with min SDK 24, uses APK Signature Scheme v2, and its Aarast RSA-3072 upload
signer matches deployed Android association. The artifact is 88,634,008 bytes
with SHA-256
`075D82E24BEF4DED75F34D663B76132C9A6D6F89C7FE6535009C734A0CA1C69D`.
Production API and private Firebase client inputs are embedded. Sentry release
identity is embedded, but DSN delivery is intentionally disabled.

The APK is not a store AAB and no equivalent iOS run has occurred. It does not
prove live Login/API/Firebase, OTP, Push, offline interruption, Sentry, TestFlight,
or store behavior. The current web/API deployment at `959c47b7` contains later
Mobile source corrections, but it does not rebuild or install a native binary;
the APK's exact Mobile source provenance remains unchanged.

If the defect is isolated to Sentry transport, rebuild the same session-fixed
code with an empty `AARAST_SENTRY_DSN`; this disables external delivery without
removing the local ring or session boundary. If session/context behavior
regresses, stop rollout and return to the last accepted signed mobile artifact.
This slice has no backend API or database migration, so do not roll back backend
or schema state. Record the exact release/artifact used for rollback and rerun
the regression gate before resuming rollout.

## Dynamic Catalog And Geography Gate

Any managed-reference change must prove all of the following before release:

- Prisma validation, Backend type-check/build, and an isolated migration run
  against a disposable PostgreSQL database;
- `npm run smoke:reference-catalog` passes against the managed disposable
  database and verifies first-load catalog seeding plus version-aware fetch;
- public bootstrap returns only the published active revision, returns
  `unchanged: true` for the current version, and changes version only after a
  publication or another included reference update;
- draft editing does not change the Mobile-visible payload, historical publish
  performs rollback, and disable creates an inactive published revision rather
  than deleting history;
- every Admin write requires `CATALOG_WRITE`, every Admin read requires
  `CATALOG_READ`, and the audit log records attempt plus terminal outcome;
- locality create/update rejects a parent in another district and every direct
  or indirect cycle; disable preserves existing plan/provider text;
- Mobile cold-start, matching-version, corrupt-cache, network-failure, empty
  remote persona, groom/bride audience, and manual-locality fallback paths;
- Admin and Mobile RTL layouts at 320px/420px and enlarged text, including
  empty, loading, error, inactive, unpublished, and rollback states.

Security roles, permissions, payment states, booking states, and finance
calculation semantics must fail review if exposed as editable catalog rows.

## Admin Web Changes

```powershell
cd D:\projects\aarast\admin-web
npm run build
npm run smoke:admin-runtime
```

Admin runtime smoke requires a running backend.

## Reporting

Report every verification as PASS, FAIL, or BLOCKED. Do not claim a check
passed unless it was actually run.

## R8 Execution Contract — Task 0

R8 base: `c2b728bfe54304562923facfb6094e0de04c0b27`
Objective: zero project-owned globals with explicit Prisma/Realtime imports
State: design and plan approved; application source unchanged
Stop: no push, merge, deployment, remote CI, or R9
