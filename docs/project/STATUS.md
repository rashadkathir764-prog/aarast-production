# Current Status

Snapshot date: 2026-07-12

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
- Financial integrity: database CHECK constraints (non-negative amounts,
  paid ≤ total, positive payment records) enforce money invariants below
  the application layer.
- Quality gates in CI: backend unit + e2e smoke, admin-web Vitest,
  mobile analyze + tests, gitleaks secret scan, and `npm audit` gate.
- Mobile: Flutter, Provider, go_router, dio, SQLCipher-backed SQLite, and OS
  keystore/keychain storage for tokens, the random offline-database key, and
  sensitive profile/onboarding state.
- Admin web: React 18, Vite, and TypeScript strict mode.
- Local runtime: Docker Compose backend, PostgreSQL, Redis, and MinIO-compatible
  object storage with an initialized private chat prefix.
- Production path: Dokploy Compose under `deploy/dokploy/`.

## Active Implemented Scope

- Verified-phone registration, atomic OTP consumption, password/OTP login,
  profile, and settings.
- Wedding plans, onboarding, dashboard summaries, money, financial
  commitments, payment records, tasks, guests, sharing, permissions,
  notifications, and offline/cache support.
- Provider catalog, favorites, reviews, quote requests/offers, provider
  dashboard operations, and admin catalog/provider operations.
- Quote-scoped conversations, authenticated Socket.IO delivery, unread/read,
  mute, block, report, private chat objects with membership-gated 120-second
  signed downloads, and admin report moderation.
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
- Append-only financial payment/reversal entries, unique installment-payment
  links, and row-locked installment payment transitions.
- Rotating refresh sessions with single-session logout, logout-all, secure
  mobile storage, and one guarded retry after `401`.
- Password brute-force protection is durable across restarts and backend
  replicas: PostgreSQL stores only an HMAC-SHA-256 account-identifier digest
  keyed by a deployment-only pepper. Five failures enforce a fifteen-minute
  lock that a successful login/reset clears; an hourly advisory-lock-protected
  job removes expired and inactive throttle rows on one replica.
- Flutter account providers are recreated at a user-keyed boundary; plan data
  providers are replaced when the selected plan changes. Disposed providers
  ignore late responses, and offline replay is pinned to its original cache
  owner and access-token snapshot.
- Android/iOS/macOS offline caches are encrypted with SQLCipher. The 256-bit key
  lives only in secure OS storage, supported mobile startup fails closed if the
  key/database cannot be opened, and the old plaintext development cache is
  removed before the secure database is created.
- The cached safe-user profile and guest-onboarding draft also live in a
  dedicated OS secure-storage namespace in production wiring. Existing
  SharedPreferences values migrate once and are deleted; non-sensitive plan
  selectors may remain in preferences.
- A guest may explicitly defer the budget and still open the local dashboard;
  previously saved no-budget local plans are migrated on read.
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
  bounded, redacted results. Production treats Redis and media as required and
  the container healthcheck targets readiness.
- Notification creation and chat-message commits now enqueue durable
  `OutboxEvent` rows transactionally. A cross-replica worker claims with
  `SKIP LOCKED`, retries safely, retains dead letters, and publishes recovery
  events through Redis-backed Socket.IO. Flutter refetches a missing message by
  ID when it receives the recovery event. Queue metrics and alerts are wired.
- User notification reads are side-effect free and paginated end to end. Task
  writes create immediate due reminders, while an hourly PostgreSQL-locked
  repair scan idempotently creates task/installment reminders and preserves
  financial visibility permissions for shared members.
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
- Mobile and admin surfaces listed by the generated route references.

## Approved Work In Flight

The five-tab provider portal, paginated conversation/notification inboxes,
verified media integration, refresh lifecycle, durable login lockout, and
encrypted mobile offline store are integrated in source. Release readiness
still requires a signed physical-device acceptance pass; the local
object-storage and Socket.IO media paths are now covered by Docker-backed
runtime smoke.

## Verification Status

For the current working tree on 2026-07-12, Flutter Analyze passes with no
issues and all 524 Flutter tests pass. SQLCipher key-vault/fail-closed tests are
included. These local results do not prove store signing, signed
physical-device behavior, deployed association files, or the target
object-storage environment. Final AAB/certificate verification is intentionally
deferred at the product owner's request.

Backend TypeScript check/build, all 5 canonical/legacy pretests, and all 216
source tests pass. The rebuilt local Docker backend, PostgreSQL, Redis, and
MinIO-compatible media service are healthy; all 51 migrations are applied and
dependency audit reports zero known vulnerabilities. `/ready` reports database,
Redis, and media as `up`. The auth smoke also proves the durable fifth-failure
account lock through HTTP. All 27 Docker-backed smoke groups pass, including
real signed upload, full image sanitization, durable upload-ticket transition,
private chat media, and provider media persistence. This proves the local
runtime contract, not a multi-host production deployment.

Admin Web production build, all 30 Vitest checks, honesty checks, and all 16
route smokes pass. Production dependency audit reports zero known
vulnerabilities.

The secure-admin HTTP smoke also proves that legacy password/OTP/access/refresh
paths cannot reach `/admin`, one concurrent MFA challenge creates one session,
the cookie rotates, replay fails, and logout immediately invalidates both the
active access JWT and refresh cookie. Live production OTP delivery still
depends on the external Meta-approved channel.

## Known Risks

- Signed media requires valid S3-compatible configuration; the `chat-image/`
  prefix must deny anonymous/public reads, and credentials remain server-side.
- Conversation/media reconnect behavior still needs a signed physical-device
  acceptance pass against the release environment.
- Final Android AAB signing/signer verification and iOS Archive/TestFlight
  validation are still required; they are not covered by the local code gate.
- Android App Links and iOS Universal Links require deployed association files
  populated with real production identities and physical-device tests.
- Financial data remains private by default, including financial commitments,
  payment records, expenses, and financial installments.
- Existing unrelated working-tree changes must be preserved.

## Documentation State

- The explicit active-document inventory and archive policy live in
  `docs/README.md`; no brittle numeric file total is maintained.
- `scripts/docs-sync.mjs` generates route, model, and package-script tables.
- `scripts/docs-verify.mjs` checks active documentation against source.
