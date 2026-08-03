# Current Status

Snapshot date: 2026-08-03

This is the compact project status source. Current code, schema, module imports,
and runtime checks override historical completion reports.

## Repository

- Root: `D:\projects\aarast`.
- The 2026-07 documentation consolidation is active.
- The current working tree contains ongoing mobile, backend, migration, and
  documentation work. Do not treat uncommitted files as release-ready solely
  because they exist.

## Current Stack

- Backend: NestJS 11, Prisma 6, PostgreSQL, 15-minute access JWTs, and
  rotating 30-day refresh sessions.
- Scale/observability: optional Redis (shared throttling + Socket.IO
  adapter, fail-open when Redis drops), request-id correlation,
  token-guarded Prometheus `/metrics` with business counters, JSON
  production logs, optional Sentry via `SENTRY_DSN`, graceful shutdown
  draining, nightly pg_dump sidecar in the Dokploy compose, and a
  deployable Prometheus/Grafana/Alertmanager stack under
  `deploy/monitoring/`.
- Financial integrity: the active prelaunch contract uses `WeddingCost`, an
  append-only `CostPayment` ledger, and `PaymentSchedule`. `WeddingCost` has no
  due date; `PaymentSchedule.dueDate` is the only payment-reminder date. Pending
  schedules do not reserve outstanding balance or block direct payments. Each
  schedule is independently capped by the row-locked outstanding cost when
  created or edited, and fully paying a cost cancels its remaining pending
  schedules. Database constraints and row-locked mutations also enforce
  positive amounts, paid not exceeding cost, one reversal per payment, and one
  payment transition per schedule.
- Accepted provider offers now create or return one idempotent `WeddingCost`
  inside the acceptance transaction. Category matching uses the provider
  service and normalized logical aliases, with an unallocated `أخرى` fallback;
  no payment, schedule, task, or booking is created. Accept, reject, provider
  update, and requester cancel now share a request-first row-lock order and
  expected-state writes. Acceptance rechecks provider and money permissions
  under a locked shared-member row, preventing stale permission or lifecycle
  races from producing a cost/link for a non-accepted offer.
- Quality gates in CI: backend unit + e2e smoke, admin-web Vitest,
  mobile analyze + tests, gitleaks secret scan, and `npm audit` gate.
- Mobile: Flutter, Provider, go_router, dio, SQLCipher-backed SQLite, and OS
  keystore/keychain storage for tokens, the random offline-database key, and
  sensitive profile/onboarding state. Structured mobile observability uses
  `AppLogger`, an in-memory ring buffer, and optional `sentry_flutter` 9.25.0;
  `sentry_dart_plugin` 3.4.0 is configured for debug-symbol upload.
- Admin web: React 18, Vite, and TypeScript strict mode.
- Local runtime: Docker Compose backend, PostgreSQL, Redis, and MinIO-compatible
  object storage with an initialized private chat prefix.
- Production path: Dokploy Compose under `deploy/dokploy/`.

## Active Implemented Scope

- Verified-phone registration, row-locked OTP attempt ceilings and one-time
  consumption, cross-replica login lockouts, production JWT-secret strength
  enforcement, legacy unverified-row recovery, stable Arabic auth errors,
  password/OTP login, separate app/admin credentials, administrator password
  recovery, profile, and settings.
- Wedding plans, onboarding, dashboard summaries, the canonical money domain
  (general budget, categories, costs, payments, and payment schedules), tasks,
  guests, sharing, permissions, notifications, and offline/cache support.
- Provider catalog, favorites, reviews, quote requests/offers, provider
  dashboard operations, and admin catalog/provider operations. Public provider
  rating caches are derived under an ordered provider-row lock in the same
  transaction as every user/admin review mutation and account-review purge.
  Service, package, offer, admin-service, and marketplace-filter prices share
  the bounded `numeric(14,2)` validator and fail before writes on overflow or
  excess precision.
  Browser CORS preflight explicitly permits the canonical `PUT` money-budget
  write while retaining the configured origin, credential, and header policy.
- Provider categories remain one catalog with explicit groom/bride visibility
  flags. Flutter filters only from the selected account context persona, while
  provider service management receives the active catalog union. Historical
  UUID bootstrap rows are reconciled by slug with provider/service references
  preserved, so the active catalog contains no legacy duplicates such as
  `مراقصة` beside `فرقة رقص`.
- Yemen administrative references now include 22 governorates/first-level
  units and 335 districts with stable codes and center coordinates, public read
  APIs, and encrypted Flutter cache. Legacy `City` relations remain compatible
  and are not presented as governorates.
- One conversation per plan/provider or account/provider context, created with
  the first real quote request and reused by later requests. The implemented
  timeline combines human messages with persisted quote/offer system events,
  authenticated Socket.IO delivery, unread/read, personal mute, side-level
  block, report, private chat objects with membership-gated 120-second signed
  downloads, and admin report moderation. Send and mark-read recheck live
  authority and the active participant inside a serializable transaction;
  permission revocation removes sockets and cannot be undone by those actions.
  A not-yet-joined provider keeps the customer conversation readable while
  sending remains disabled.
- Image writes verify and sanitize the complete uploaded object server-side
  before persistence. JPEG/PNG/WebP uploads must match their ownership metadata,
  stored size/MIME, fully decode within the pixel/dimension/single-frame bounds,
  and survive metadata-stripping re-encoding. Signed creation uses
  `If-None-Match: *`; the sanitized replacement is conditional on the original
  ETag, preventing silent overwrite races. The same verification is repeated by
  avatar, provider, service, and private-chat persistence paths even when a
  custom client skips the verify call.
- Privacy-safe review identities, route-template-only telemetry, log-safe
  request ids, and server-side redaction of financial admin notifications.
- Append-only cost payment/reversal entries, unique schedule-payment links,
  and row-locked payment-schedule transitions.
- Rotating refresh sessions with single-session logout, logout-all, secure
  mobile storage, one guarded retry after `401`, and bounded 30-day terminal
  history cleaned by one hourly advisory-lock holder.
- Password brute-force protection is durable across restarts and backend
  replicas: PostgreSQL stores only an HMAC-SHA-256 account-identifier digest
  keyed by a deployment-only pepper. Each attempt reserves a row-locked slot
  before password comparison; five admitted attempts enforce a fifteen-minute
  lock that a successful login/reset clears. An hourly advisory-lock-protected
  job removes expired and inactive throttle rows on one replica.
- Flutter account providers are recreated at a user-keyed boundary; plan data
  providers are replaced when the selected plan changes. Disposed providers
  ignore late responses, and offline replay is pinned to its original cache
  owner and access-token snapshot.
- Post-auth `/home` now gates on live account contexts: zero contexts keep the
  existing onboarding state, one available context is selected directly,
  multiple contexts use a standalone Arabic `اختر المسار` screen, and the
  chosen context routes to its matching dashboard. Dashboard shells no longer
  render an account-path switcher.
- Full mobile logout now crosses one explicit session boundary. `AuthController`
  enters `terminating`, removes the in-memory user, and notifies listeners
  before any awaited teardown. Credential capture is bounded to two seconds and
  every local teardown stage to five seconds. `SessionTeardownCoordinator` then
  clears local auth/account/guest state and the account's Push binding before
  draining remote auth revoke plus Push unregister in parallel with a two-second
  deadline. Local cleanup failure or timeout produces a dedicated retry screen;
  remote failure or timeout cannot restore the old session. Session-operation
  generations, sealed teardown credentials, and storage epochs reject late
  results from an older session.
- The selected account context is now persisted as version 2 with `userId` and
  `contextKey` in secure storage. A fresh Login and full Logout clear the old
  selection. A multi-context account always returns to the chooser, a
  single-context account may enter directly, and cold restart restores only a
  same-user selection still present in the latest context response. Legacy raw
  values migrate once and invalid or revoked values are removed.
- `AarastSessionTransitionGate`, `AarastAuthFlowRedirector`, and
  `AccountContextEntryGate` now separate session UI, authentication-driven
  route intent, and context-driven Dashboard entry. Checking, terminating, and
  failed local teardown have explicit safe screens; logout controls do not
  navigate independently. Effective transitions and provider/groom/contributor
  Dashboard build/dispose events are structured trace boundaries.
- Mobile logs are structured under `auth`, `session`, `context`, `navigation`,
  `api`, `cache`, `database`, `state`, `lifecycle`, `provider`, `groom`,
  `contributor`, `push`, `chat`, and `error`; no local `*.log` files are
  created. The Debug console, 300-event/256KB/15-minute memory ring, and
  optional Sentry sink share one redaction boundary. Tokens, contact data,
  headers, query values, and bodies are excluded, while user/context/session
  identifiers are installation-salted hashes. The Support screen can send a
  fresh in-memory JSON diagnostic attachment only after per-send consent and
  never stores or retries a failed report.
- Android/iOS/macOS offline caches are encrypted with SQLCipher. The 256-bit key
  lives only in secure OS storage, supported mobile startup fails closed if the
  key/database cannot be opened, and the old plaintext development cache is
  removed before the secure database is created.
- The cached safe-user profile, guest-onboarding draft, and selected
  account-context key also live in a
  dedicated OS secure-storage namespace in production wiring. Existing
  SharedPreferences values migrate once and are deleted; the non-sensitive
  active-plan preference may remain in preferences for compatibility.
- A guest may explicitly defer the budget and still open the local dashboard.
  A missing general budget remains unset; category allocations never become a
  substitute budget.
- Mobile Release fails closed without a public HTTPS API origin and real
  Android signing configuration. iOS has the equivalent Release build phase,
  contact permission copy, and Associated Domains entitlement.
- Android/iOS launcher and native splash assets now use the Aarast burgundy,
  gold, and ivory mark. Secure token storage is on `flutter_secure_storage`
  10.3.1 with automatic legacy algorithm migration enabled.
- Mobile feature flags now contain only switches consumed by live behavior
  (guest-first onboarding, offline readiness, and push readiness). Provider,
  quote, and deferred-scope restrictions rely on real guards/contracts rather
  than inert false flags.
- The unreachable legacy provider dashboard and 3,611-line dashboard widget
  bundle were removed. My Plans imports the extracted account sheet directly,
  and the routed provider experience remains `ProviderPortalScreen`.
- Runtime health now separates dependency-free `/live` (plus `/health` alias)
  from `/ready`, which checks PostgreSQL and configured Redis/media with
  bounded, redacted results. The container healthcheck targets readiness.
  Redis and S3-compatible media are required in the live deployment. Public
  avatar/provider/service prefixes are phone-reachable over HTTPS, while chat
  images remain private and require membership-authorized signed reads.
- Notification creation and chat-message commits now enqueue durable
  `OutboxEvent` rows transactionally. A cross-replica worker claims with
  `SKIP LOCKED`, retries safely, retains dead letters, and publishes recovery
  events through Redis-backed Socket.IO. Flutter refetches a missing message by
  ID when it receives the recovery event. Queue metrics and alerts are wired.
- User notification reads are side-effect free and paginated end to end. Task
  writes create immediate due reminders, while an hourly PostgreSQL-locked
  repair scan idempotently creates task/payment-schedule reminders and
  preserves `canViewMoney` visibility for shared members.
- Android/Flutter and backend FCM implementation now exists for task
  assignment, task due/overdue, and chat-message alerts. It requests the
  Android notification permission once, registers a Firebase Installation ID
  against the authenticated account, uses an independent durable outbox event,
  clears that account binding and cancels its request immediately on Logout,
  and gives a newer login a fresh operation queue. The device-scoped FID and
  FCM token are retained while the old server binding is removed through the
  bounded remote teardown. Token refresh and app resume revalidate the current
  binding without using the Android-unsafe Firebase Installations ID-change
  stream. Notification taps open only the neutral notification inbox. Local
  analysis, focused tests, and Android builds pass. Live background/terminated
  delivery remains an external release gate.
- Authenticated mutations now bind each idempotency key to a SHA-256 request
  fingerprint without storing raw tokens or query values. Identical retries
  execute once and replay, mismatched reuse returns `409`, response retention is
  finite, and expired rows are cleaned hourly by one replica under a database
  advisory lock.
- All seven paginated admin list surfaces now consume backend page metadata at
  20 rows per request, show real totals and bounded page jumps, reset page state
  on filters/search, and clamp after a last-row removal. The shared RTL control
  has keyboard/focus semantics and narrow-screen overflow handling.
- Browser administration now requires password + phone OTP through a
  short-lived hashed challenge. General login/OTP/refresh paths cannot bypass
  MFA; access tokens are memory-only, refresh tokens are rotating HttpOnly
  cookies, and every admin JWT is bound to a live revocable server session.
- The same phone identity may use both the wedding app and administration
  without sharing credentials, profile presentation, session scope, login
  throttle, or OTP purpose. App sessions never gain admin MFA, cannot mutate or
  delete the administrator identity, and app recovery never changes or revokes
  the admin realm. Admin recovery revokes only admin sessions without changing
  the app password. App-facing relations resolve only the separate app name and
  avatar; an app-side provider profile changes `appRole` without overwriting an
  administrator database role.
- Mobile and admin surfaces listed by the generated route references.

## Completed Prelaunch Money Reset

The prelaunch money rewrite was an approved destructive cleanup because there
are no production users. Live source, routes, Prisma models, encrypted mobile
caches, queue entity types, operational tools, tests, and user copy now use one
contract: `WeddingCost`, `CostPayment`, and `PaymentSchedule`. The removed
`Expense`, `FinancialCommitment`, `FinancialPaymentRecord`, and
`FinancialInstallment` systems are not compatibility APIs and must not be
restored by later work. Historical migrations may describe removed structures;
they are not live product contracts.

The local code gate completed on 2026-07-15: backend typecheck/build and 237
tests passed, Flutter analysis and all 572 tests passed, generated docs were in
sync, and old live routes/models/operational scripts were guarded against
returning. Production deployment verification remains part of the deferred
release phase and is not implied by these local results.

The five-tab provider portal, paginated conversation/notification inboxes,
verified media integration, refresh lifecycle, durable login lockout, and
encrypted mobile offline store are integrated in source. Release readiness
still requires a signed physical-device acceptance pass; the local
object-storage and Socket.IO media paths are now covered by Docker-backed
runtime smoke.

The temporary OpenWA MVP adapter is integrated on the Aarast side behind
`AUTH_OTP_MODE=openwa`: runtime configuration fails closed, delivery uses only
the private transient endpoint, PostgreSQL enforces HMAC-keyed phone/IP/global
quotas, `/ready` verifies both the selected session and transient capability,
and Flutter matches the 60-second resend boundary. The pinned OpenWA `v0.8.16`
fork now builds and runs in the isolated loopback lab: the dedicated session is
QR-linked, transient-role boundaries pass, one live self-recipient OTP returns
`200`, immediate resend returns `429`, verification returns `200`, private
OpenWA persistence tables remain empty, and disconnect/reconnect plus container
restart fail closed and recover without another QR scan. On 2026-07-14, the
hardened OpenWA revision `c3b67952c046f0fc71c2e6bebe4ad4437ab299ce`
was deployed to staging. A real handset OTP request, confirmation, and the
following login all returned `200`; the required fresh 24-hour stability
observation remains an operational gate before a wider MVP rollout.

Participant invite delivery now uses the same non-persisting transient OpenWA
boundary without broad messaging access. The owner creates one pending invite;
the backend sends its generic private HTTPS link and returns an explicit
device-delivered, uncertain, or unavailable result. A link-specific public gate
matches the raw
token and canonical phone before dispatching OTP and exposes no plan details on
mismatch. After successful OTP, the mobile link flow resumes at an explicit
decision screen that shows the invitation, role, permissions, and separate
accept and reject actions. Verification alone creates no membership; only an
explicit acceptance opens the contributor plan center. A first-time contributor chooses
their application name and password while completing that same invite OTP; the
backend no longer creates an inaccessible random password or requires a second
registration code. The resulting rotating session is stored securely, while an
explicit logout revokes it and returns the rebuilt Flutter account boundary to
password login. Android App Link association is
generated for the current signed MVP APK; Google Play signing will require its
store certificate fingerprint before rollout.

The add-participant action refreshes members and pending invitations for the
current plan before sending. If the phone already has a live pending invitation,
the same row is reissued instead of duplicated, and the selected role and
permissions are replaced atomically with the new token fingerprint.
Invite delivery state is now persisted with its attempt time and returned on
every read. Mobile refresh therefore preserves the cooldown instead of sending
twice or disabling uncertain delivery forever. Old rows are explicitly
`UNKNOWN`; late superseded attempts fail with a typed conflict and cannot
overwrite a newer result or produce an invalid invite link.

Contributor acceptance is now recoverable across ambiguous mobile failures.
If the acceptance commits but its response is lost, the same verified invitee
may replay the same token or authenticated invite-id handle and receive the
existing accepted invite, authoritative membership, and contributor context
without a second notification. Flutter also reconciles an ambiguous response
from the invite detail before reporting failure. Owner sharing and dashboard
surfaces reload after app resume or return from sharing, so an accepted invite
does not remain displayed from an old in-memory `PENDING` snapshot. Contributor
workspace resume refreshes both account-context authority and dashboard data;
overlapping invite/dashboard loads are latest-wins, and visible contributor
actions fail closed to the intersection of both current permission snapshots.

Decline has the same retry-safe terminal behavior: concurrent calls or a lost
response reconcile to one authoritative `DECLINED` result without a second
owner notification. An accepted invitation exposes contributor access only
while its `SharedMember` exists; after removal it remains historical
`ACCEPTED` without `contextKey`, and Flutter renders an explicit ended-
membership state with no plan-entry action. Removing a member atomically
revokes every live pending invite matching that user or normalized phone, while
archiving a plan atomically revokes all remaining live pending invitations.

While the owner remains on the sharing screen, Flutter refreshes at a
controlled ten-second interval only when pending invitations exist, preserves
the current content during refresh, and stops polling once the pending set is
resolved. Invite, sharing-access, plan-selection, and dashboard requests are
latest-wins. Account-context gates render checking or error states during an
authority refresh instead of retaining stale contributor actions.

The isolated server acceptance environment is now live at
`https://otp-lab-api.shadowgardn.com` from committed, SHA-pinned images. Its
PostgreSQL, OpenWA session, and scoped credentials live on a separately keyed
LUKS mount; OpenWA has public-only egress, the backend has no host port and does
not join the shared Nginx Proxy Manager network, and the operator QR surface is
loopback-only and time-limited. Live gates prove session `ready`, Aarast
`/health=200` and `/ready=200`, HTTP-to-HTTPS redirect, valid Let's Encrypt TLS,
HSTS, idempotent storage/bootstrap recreation, and blocked staging access to
the host and production networks. This remains an OTP-only staging acceptance
surface, not the production API. The running fresh 24-hour observation remains
mandatory before wider use.

## Contributor Isolation And Frozen History Workstream - 2026-08-02

The current uncommitted worktree contains a production-oriented contributor
access redesign. PostgreSQL is the authority: role defaults are applied only
when an invitation is created, while direct member creation stores omitted
authorization flags as `false` and the stored `SharedMember` booleans remain
authoritative afterward. Current membership plus the current
section permission is required before Backend may return live data. Within an
allowed section, task, guest, money, provider/quote, member, dashboard, and
notification queries are constrained to assignment or the current
contributor's own recorded actions instead of every row sharing the same
`weddingPlanId`. Historical actions from the same actor may span multiple
tenures, but do not reactivate a departed membership or override a revoked
permission.

The new schema and migration add `authorityVersion`,
`ContributorHistoryScope`, `ContributorTenure`, and append-only
`ContributionEvent`. Events use a privacy allowlist, a 16KB database limit,
canonical snapshot and event hashes, per-tenure dedupe keys, lifecycle and
section/entity constraints, lookup indexes, and a database trigger that rejects
UPDATE or DELETE. Every qualifying contributor action stores its allowlisted
snapshot at action time. Permission revocation never re-reads or copies a live
row; it appends only a deterministic `SECTION_REVOKED` boundary before changing
authority. An owner-created assignment on which the contributor never acted is
therefore not invented as historical work. Later edits to an original row
cannot alter an already committed snapshot. Contributor list and summary APIs
return those snapshots without exposing a live entity id; a contributor
receives only their own history while the plan owner may inspect plan history.

Legacy migration is deliberately evidence-only. It creates the history scopes
and current tenures at cutover, and backfills only a direct task assignment,
quote creation, or invite creation that can be matched to a current tenure.
Accepted membership alone and old guest/money rows are left unattributed;
sensitive-looking legacy text is omitted. This policy avoids silently
inventing a creator or executor for production data that never stored one.

Migration `20260803110000_add_account_deletion_receipts` adds an anonymous,
append-only `AccountDeletionReceipt`. The account deletion transaction writes
one SHA-256 receipt derived from the former user id and the stable client
request id before erasing the `User`; neither source identifier is retained in
the receipt. Database triggers reject receipt updates and deletes. Flutter
persists the stable deletion request in secure storage before the first network
call, unmounts every account dashboard, and reconciles a lost response through
the throttled public status endpoint before it can restore a session or clear
the marker.

The source also separates four account actions in the contributor plan center:
leaving the workspace keeps membership, `مغادرة الخطة` transactionally ends
only the selected membership, account logout ends the device session, and
central account deletion removes the whole Aarast account. Self-leave revokes
matching pending invites, closes the
tenure with `MEMBER_LEFT`, clears the selected active plan, removes live
conversation/notification access, and keeps immutable plan history. A repeated
leave is designed to return the prior terminal result. Flutter retains the
leave intent in a durable installation/user/plan-bound marker before issuing
the request, reuses one client request id across ambiguous retries, quarantines
the plan until the server result is reconciled, and replays pending cleanup
before account contexts load. It clears the exact plan-scoped local graph and
refreshes filtered contexts before removing that marker. Definitive client
errors remove the marker and remain visible. Account deletion uses the shared
typed confirmation used by other roles and removes only the deleted user's
pending leave markers as a retryable centralized teardown stage; ordinary
logout does not discard them.

The contributor workspace now uses full-width Arabic `FilledButton.icon`
actions inside permitted section cards; it does not embed a
`FloatingActionButton.extended`. A read-only `سجل مساهماتي` screen presents the
frozen snapshots and coverage date without a route back to the live entity.
Task permission denial has the stable HTTP `403` code
`TASK_PERMISSION_REVOKED` and Arabic message
`لم تعد لديك صلاحية لتنفيذ هذه المهمة`.

The final local verification on 2026-08-03 recorded `npm test` with 651 tests
(650 passed, one intentional skip, zero failures), `flutter analyze` with zero
issues, and all 997 Flutter tests passing. The contributor-history migration
passed on a fresh 74-migration database and in a separate populated legacy
upgrade rehearsal that applied every prior migration before the target
migration. A managed Backend HTTP scenario passed all 28 checks with one owner,
two contributors, different permissions, revocation followed by owner edits,
cross-contributor isolation, frozen history, leave, re-login, and a new
invitation. The managed account-deletion smoke also passed for no-plan, owner,
shared-contributor, and provider data lifecycles. Flutter Web rendered the
Arabic welcome gateway in a real local runtime without console errors. Android
Release was rebuilt from this worktree for the production API, signed by the
Aarast upload identity, and verified as `1.0.0+7`; its SHA-256 is
`509F54E81CBAE7CA4DD3BE9ABA086EACB1CF7D5C2D75F848C767A59741F7AC72`.

This workstream is still not release-complete. The signed Release APK installed
successfully as an in-place update on an SM S938B running Android 16, launched
`MainActivity`, kept its process alive, and emitted no fatal Flutter/Android or
SQLite error during the startup check. Its authenticated context load stopped
at the explicit Arabic retry state because Production is still on the old
Backend contract: the device and workstation both reached `/health=200`, while
the new public `/api/v1/account-deletions/status` route returned `404`. The
owner/two-contributor physical flow therefore cannot be accepted until the
coordinated Backend migrations and compatible Backend release are deployed.
No iOS physical-device pass is available. The local Release artifact reused
the Firebase client configuration already embedded in the previously signed
Aarast artifact; the four required Firebase dart-defines are still absent from
the workspace environment, so CI/release configuration remains non-repeatable
until those values are supplied through the approved secret channel. The
native SQLCipher schema-v6-to-v7 queue ownership upgrade also still requires a
completed post-deployment rehearsal on Android and iOS; shared JSON migration
and the SQLite source contract are covered locally. No Staging or Production
migration/deployment of this uncommitted worktree is claimed.

## Verification Status

The 2026-08-01 contributor-hardening slice is not yet a store-accepted mobile
artifact. `flutter analyze --no-pub` passes with no issues and the complete
`flutter test --no-pub` run passes all 941 tests. The Backend check and complete
test suite also pass (548 passed, 1 skipped, 0 failed); the sharing-security
smoke is 38/38 and the sharing-concurrency smoke passes.

Android Debug APK, local Release APK, and local Release AAB were built as
`1.0.0+7`, package `com.aarast.aarast_mobile`. The Release artifacts use the
explicit production origin `https://aarast-api.shadowgardn.com`. Their current
SHA-256 values are, respectively:

- Debug APK: `D1AA16015C10BC510B06E8A605FE6D30A4395D5C54A2C6194BD3926D1CB7561F`
- Release APK: `7C3BF390E459FF913ECF4FB519D02B517F2E0813DE938B6F615A20E43011814F`
- Release AAB: `DFF417C0935DABA8B39B5182F3EC28D1421E049BA387F59679D8C32427D37D90`

The Release APK is non-debuggable, uses APK Signature Scheme v2, and is signed
with certificate SHA-256
`4D9F978CD647A7CFA165835C551293BDCB8E5E4E556CE0DD94546FFB9BD387B2`.
Manifest checks confirm Internet access, `POST_NOTIFICATIONS`, and the default
notification-channel metadata. Local Release validation used an empty Sentry
DSN and kept Firebase client values in process memory only; protected CI
Firebase/Sentry inputs were not available in this shell, so this is not a
store-release acceptance. `jarsigner -verify` accepts the AAB, with the expected
self-signed/no-timestamp warnings that still require store signing review.

The current artifact was not installed on the connected phone: the earlier
integration runner removed the main package after a signature mismatch, and
the remaining prototype package was intentionally left untouched. Live
two-account OTP/WhatsApp behavior, slow/offline/interruption scenarios, live
Push and Sentry, iOS Archive, AASA deployment, and Staging acceptance remain
external gates.

For revision `0c1d81c7aebb8b3f93f83238ea13219de0994344` on 2026-07-17,
Flutter Analyze passes with no issues and all 628 Flutter tests pass.
SQLCipher key-vault/fail-closed tests are included. A production Release APK
(`versionCode=4`) was built against the production HTTPS origin with a
dedicated 4096-bit upload key and APK Signature Scheme v2. It is not debuggable,
contains Internet permission, contains no staging origin or enabled demo/login
bypass, and its SHA-256 is
`108210A5DEC6723915DEF3A9855B035F51A7D5FF6646B58B7066E8987A7530FE`.
This does not prove AAB/Play signing, deployed association files, iOS signing,
or a physical-device acceptance pass for this exact artifact.

Backend TypeScript check/build, all 11 canonical/legacy/identity pretests, and
all 296 source tests pass (307 total). The local Docker backend,
PostgreSQL, Redis, and MinIO-compatible media service are healthy, and the
long-lived local database now has all 56 migrations applied. A disposable
database independently applied all 56 migrations and passed the direct SQL
money integrity checks. All 28 Docker-backed smoke groups pass together against
the migrated local runtime, including money concurrency, account deletion,
media, sharing, provider, and OTP contracts. Dependency audit previously
reported zero known vulnerabilities. Any Staging rollout must still use an
immutable image built from the exact final commit and pass backup/restore and
post-deploy health verification; older images do not satisfy that gate.

The hardened OpenWA fork has 2,296 passing tests (5 intentionally skipped), a
passing production build, zero lint errors, and zero production dependency
vulnerabilities. Its live lab image returns Aarast `/health=200` and
`/ready=200`; transient sends create no OpenWA message, LID mapping, webhook, or
plugin rows and expose neither recipient nor OTP in runtime logs.

The QA release APK for this acceptance surface is signed with the dedicated
Aarast MVP QA certificate using APK Signature Scheme v2, contains the stable
staging HTTPS origin in its AOT artifact, and passes package/signature
inspection. A physical device has not yet been connected to this workstation,
so installation and the second-recipient request/verify flow remain unclaimed.

Admin Web production build, all 42 Vitest checks, honesty checks, and all 16
route smokes pass. Production dependency audit reports zero known
vulnerabilities.

The secure-admin HTTP smoke also proves that legacy password/OTP/access/refresh
paths cannot reach `/admin`, one concurrent MFA challenge creates one session,
the cookie rotates, replay fails, and logout immediately invalidates both the
active access JWT and refresh cookie. Production revision
`0c1d81c7aebb8b3f93f83238ea13219de0994344` is live: both new auth migrations
are applied, API and Admin containers are healthy, `/live` and `/ready` pass,
and the pinned OpenWA staging container kept the same ID, image, start time,
and restart count throughout deployment. The pre-deploy production backup was
checksum-verified, restored into an isolated PostgreSQL instance, migrated
twice, and also stored encrypted off-host.

## Known Risks

- Signed media requires valid S3-compatible configuration; the `chat-image/`
  prefix must deny anonymous/public reads, and credentials remain server-side.
- The production media target, durable volume, HTTPS origin, signed upload,
  verification, public avatar/provider/service reads, and provider image
  binding passed live end-to-end checks on 2026-07-19. A clean redeploy must
  preserve the private media credentials and persistent volume; chat objects
  must continue to deny anonymous reads.
- Conversation/media reconnect behavior still needs a signed physical-device
  acceptance pass against the release environment.
- Final Android AAB signing/signer verification and iOS Archive/TestFlight
  validation are still required; they are not covered by the local code gate.
- Android App Links and iOS Universal Links require deployed association files
  populated with real production identities and physical-device tests.
- The complete mobile suite and one controlled Android Profile scenario pass.
  The session/context flow still requires a live-account Android run, all
  slow/offline/error/interruption conditions, and the complete iOS
  physical-device run.
- Sentry remains unaccepted until Staging proves symbolication, environment and
  release labeling, mobile/backend request-id correlation, absence of PII, and
  the consent-gated diagnostic attachment. Owner/Admin-only attachment access
  and the targeted 30-day retention are operational Sentry settings, not
  application-enforced guarantees.
- Financial data remains private by default, including the general budget,
  category allocations, costs, payments, and payment schedules. Reads require
  `canViewMoney`; writes require `canManageMoney`.
- Existing unrelated working-tree changes must be preserved.

## Documentation State

- The explicit active-document inventory and archive policy live in
  `docs/README.md`; no brittle numeric file total is maintained.
- `scripts/docs-sync.mjs` generates route, model, and package-script tables.
- `scripts/docs-verify.mjs` checks active documentation against source.
