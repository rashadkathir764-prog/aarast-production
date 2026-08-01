# QA And Testing

Snapshot date: 2026-07-31

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

The 2026-08-01 local gate passes full analysis and all 941 Flutter tests.
`1.0.0+7` Debug APK, local Release APK, and local Release AAB builds pass
against the Production HTTPS origin. The Release APK is non-debuggable, uses
APK Signature Scheme v2, contains the required notification permission/channel
metadata, and its SHA-256 is
`7C3BF390E459FF913ECF4FB519D02B517F2E0813DE938B6F615A20E43011814F`.
The AAB SHA-256 is
`DFF417C0935DABA8B39B5182F3EC28D1421E049BA387F59679D8C32427D37D90`.
`jarsigner -verify` accepts the AAB with the expected self-signed/no-timestamp
warnings, so final Play/store signer acceptance remains open.

The current Release artifact was not installed on the connected Samsung
Android 16 phone: an earlier controlled runner removed the main package after
a signature mismatch, and the prototype package was intentionally left alone.
The earlier Profile-mode Provider-Logout-Groom run used controlled fakes and
therefore does not prove the live Login/API/Firebase path. No equivalent iOS
run has occurred. Neither artifact enables Sentry because real DSN/upload
credentials are not available. These results close the local build and test
gates, not live-account, live-Push, live-Sentry, TestFlight, or store gates.

If the defect is isolated to Sentry transport, rebuild the same session-fixed
code with an empty `AARAST_SENTRY_DSN`; this disables external delivery without
removing the local ring or session boundary. If session/context behavior
regresses, stop rollout and return to the last accepted signed mobile artifact.
This slice has no backend API or database migration, so do not roll back backend
or schema state. Record the exact release/artifact used for rollback and rerun
the regression gate before resuming rollout.

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
