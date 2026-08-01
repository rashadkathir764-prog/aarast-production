# Deployment

Snapshot date: 2026-07-31

Deployment source files live under `deploy/dokploy/`. This folder is the compact
documentation entry point for deployment.

## Current Runtime From Committed Files

Local Docker Compose:

- PostgreSQL: `5433 -> 5432`
- Backend: `3115 -> 3000`

Production Dokploy Compose:

- Backend API: `8093 -> 3000`
- Admin web: `8094 -> 80`

Public domains documented for the current deployment path:

- Backend API: `https://aarast-api.shadowgardn.com`
- Admin web: `https://aarast-admin.shadowgardn.com`
- Public/signed media origin: `https://aarast-media.shadowgardn.com`

Admin production builds default to the public backend origin and fail their
post-build gate if a loopback API or the current MFA login route is missing.

## Rules

- Do not modify Docker, Docker Compose, Dokploy, domains, ports, migrations, or
  production secrets unless deployment work is explicitly requested.
- Never write real secrets into Markdown.
- Production deployment is not complete without post-deploy smoke checks.

## Runtime Health Contract

- `GET /live` (and compatibility alias `/health`) checks only that the API
  process can serve HTTP.
- `GET /ready` checks PostgreSQL and every configured Redis/media dependency;
  OpenWA mode also checks its selected session and transient endpoint,
  returns dependency names/status/latency only, and fails with `503` without
  exposing connection strings or provider errors.
- Redis and media default to required when `NODE_ENV=production`. The Dokploy
  deployment provisions durable S3-compatible media and requires an explicit
  phone-reachable HTTPS signed endpoint; readiness fails closed when that
  target is unavailable.
- Container health and admin startup dependency use `/ready`, so traffic is not
  sent to an API whose required dependencies are down.

## Admin Account Operations

Production administrator creation and password rotation use the same explicit,
idempotent operation: `npm run prod:provision-admin` from the backend runtime.
The operator must provide `PROVISION_ADMIN_PHONE`, `PROVISION_ADMIN_PASSWORD`,
`PROVISION_ADMIN_NAME`, and
`PROVISION_ADMIN_CONFIRM=PROVISION_AARAST_ADMIN` through the private runtime
environment. The operation requires at least 12 characters containing an
English letter and a digit, with a hard maximum of 72 UTF-8 bytes. It never
prints the phone or password, promotes only the target account, preserves an
existing wedding-application credential/profile as the separate app identity,
and revokes previous sessions, MFA challenges, and the administrator-realm
login lock before completion. These variables are one-time operator inputs and
must not be committed or left in the persistent deployment environment.

## OTP Release Gate

The approved production path uses `AUTH_OTP_MODE=whatsapp`. Dokploy must
provide the Graph API version, phone-number ID, system-user access token,
approved authentication-template name, and template language. The API refuses
to boot when whatsapp mode is selected with an incomplete channel. Secrets
must remain in Dokploy/environment storage and never be committed.

For the explicitly risk-accepted MVP only, `AUTH_OTP_MODE=openwa` is available
behind a hardened private contract and PostgreSQL delivery quotas. Stock OpenWA
`send-text` is forbidden because it stores OTP content. The production backend
may join the existing private OpenWA transport network only after the pinned
fork, transient-persistence test, QR link, protected volume, and stop rules in
`OPENWA_OTP_MVP.md` pass. `OPENWA_BASE_URL`, session ID, API key, login-throttle
pepper, and network name are required deployment secrets/configuration; no OTP
secret is committed to Compose or Git.
The isolated `deploy/openwa-otp-lab/` stack is the reproducible local acceptance
environment; it is intentionally separate from Dokploy and is not a production
manifest.

The server acceptance environment is defined separately in
`deploy/openwa-otp-staging/`. It joins only the backend to the existing reverse
proxy network and keeps OpenWA, its QR dashboard, PostgreSQL, Redis, and both
OpenWA credentials private. It must use `otp-lab-api.shadowgardn.com` and must
not reuse any production domain, Compose project, volume, or database.

## Private Chat Media Release Gate

The S3-compatible bucket must deny anonymous reads for every object under
`chat-image/`. The API signs uploads and membership-authorized GET requests;
the CDN/public media base is only for public avatar and provider assets. Before
release, verify an unsigned chat-object GET is denied, a participant-signed URL
works for 120 seconds, a non-participant cannot mint one, and expired links no
longer work. Object-storage credentials remain server-side.

## Public Provider Media

The Dokploy Compose stack provisions a persistent MinIO volume and a one-shot
bucket/service-account initializer. MinIO root credentials exist only in those
two services; Backend receives a separate session-policy-limited service
account. Anonymous downloads are limited to the `user-avatar/`,
`provider-logo/`, `provider-cover/`, and `service-image/` prefixes. The
`chat-image/` prefix is never public. Backend can get bucket location and
put/get/delete objects only below those five application prefixes; it cannot
list or manage buckets, users, or policies. Provider services may own multiple
image rows; Flutter uploads and verifies each selected image before binding it
to the service, and the public provider profile exposes the ordered gallery.

## Mobile Store Release Gate

Release builds require an explicit public `https://` API origin and reject the
development login bypass. Android additionally requires a real non-debug upload
keystore through private `key.properties` or `AARAST_ANDROID_*` environment
variables. iOS runs the equivalent configuration check as a Release Xcode build
phase. Native launcher/splash assets and link declarations are committed, but
final AAB/IPA signing, store upload, and real-device links remain external
gates. See `STORE_RELEASE.md`.

## Mobile Session And Observability Release Gate

The mobile session/context change is application-only. It does not change the
Backend API or database schema. Do not couple its rollout or rollback to a
Backend/database deployment.

Sentry runtime configuration is supplied through Flutter build defines:

- `AARAST_SENTRY_DSN`
- `AARAST_ENVIRONMENT`
- `AARAST_SENTRY_TRACES_SAMPLE_RATE`
- `SENTRY_RELEASE`

An empty `AARAST_SENTRY_DSN` disables Sentry initialization and the diagnostic
upload action; the application still uses its in-memory ring and Debug builds
still use the console sink. The DSN is client configuration, but symbol-upload
credentials are not. `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT`
must exist only in the protected CI environment. `SENTRY_RELEASE` must identify
the same immutable mobile release for both the Flutter runtime and the CI
symbol-upload step.

The committed `sentry_dart_plugin` configuration uploads debug symbols, does
not upload source maps or source files, waits for processing, and does not
associate commits. Release CI must fail if the expected symbol upload cannot be
confirmed; never place the Sentry auth token in a Dart define, source file,
artifact, or runtime log.

The fixed client privacy policy is:

- 100% error sampling;
- 100% trace sampling in Staging and 10% by default elsewhere, unless the
  explicit trace build define supplies a valid value from 0 to 1;
- profiling, replay, screenshots, view hierarchy, default PII, raw print/HTTP
  breadcrumbs, failed-request capture, and request bodies disabled;
- identifiers hashed with a per-installation salt and tokens, credentials,
  contact data, headers, query values, and bodies removed before every sink.

The Support diagnostic report is a consent-gated in-memory JSON attachment. It
is never written to a local file or queued for automatic retry. Restrict
attachment access to Sentry Owner/Admin roles and configure the targeted
30-day retention in Sentry itself; these are operational controls and are not
enforced by the mobile binary.

Release order is Internal Android plus TestFlight on Staging, then the primary
Provider-Logout-Groom scenario on a physical Android and iOS device. Repeat it
with slow network, network loss during Logout, API failure, and app termination
during the transition. Before Production, verify Sentry symbolication,
environment/release labeling, mobile/backend request-id correlation, absence of
PII, and the consent-gated attachment.

At the 2026-08-01 snapshot, full Flutter analysis and all 941 Flutter tests
pass. Android Debug APK, local Release APK, and local Release AAB builds
succeed as `1.0.0+7` against the Production HTTPS origin. The local
Release-validation artifacts use the Aarast upload certificate and Firebase
client resources recovered in memory from a prior same-package/same-signer
Aarast artifact; the values were not written to source or logs. The Release APK
is non-debuggable, uses APK Signature Scheme v2, and contains
`POST_NOTIFICATIONS`, default-channel metadata, and `aarast_updates`. The APK
SHA-256 is
`7C3BF390E459FF913ECF4FB519D02B517F2E0813DE938B6F615A20E43011814F`;
the AAB SHA-256 is
`DFF417C0935DABA8B39B5182F3EC28D1421E049BA387F59679D8C32427D37D90`.

The current Release APK was not installed on the connected Samsung Android 16
device: an earlier controlled runner removed the main package after a signature
mismatch, and the prototype package was intentionally left untouched. A
controlled-fake Profile integration scenario for Provider Logout followed by
Groom Login passed earlier, with a Flutter runner warning that it did not
detect the `integration_test` plugin; this does not prove the live
Login/API/Firebase path. Strict local AAB `jarsigner -verify` succeeds with the
expected self-signed/no-timestamp warnings, so final Play/store signing
acceptance remains open. These artifacts intentionally use an empty Sentry DSN
because no live Sentry/CI credentials are available. Live-account
slow/offline/error/interruption scenarios, background/terminated Push, iOS
Archive, live symbol upload, and Staging Sentry checks remain unverified. This
section defines a gate; it is not evidence that every external gate has passed.

For an observability-only incident, rebuild the same session-fixed release with
an empty `AARAST_SENTRY_DSN`. For a session/context regression, halt rollout and
return to the last accepted signed mobile artifact. Record the exact
release/artifact and rerun the session/context regression suite before
resuming. No Backend or database rollback belongs to this mobile-only change.

## Firebase Push Release Gate

Android release builds require these non-secret Firebase client values as
private build inputs:

- `AARAST_FIREBASE_API_KEY`
- `AARAST_FIREBASE_APP_ID`
- `AARAST_FIREBASE_MESSAGING_SENDER_ID`
- `AARAST_FIREBASE_PROJECT_ID`

The Gradle release gate fails closed when any is missing and generates the
native Android resources needed for delivery while the Flutter process is
terminated. Do not bind Aarast to an unrelated Firebase project.

Backend delivery remains off unless `PUSH_NOTIFICATIONS_ENABLED=true`. When it
is enabled, the backend requires `FIREBASE_PROJECT_ID` plus Google Application
Default Credentials supplied through the private runtime environment (for
example workload identity or `GOOGLE_APPLICATION_CREDENTIALS`). Never commit a
service-account JSON file. The committed Dokploy deployment uses
`AARAST_FIREBASE_CREDENTIAL_DIR` as a private host directory, mounts it
read-only at `/run/aarast-firebase`, and expects the exact file name
`service-account.json`. Its startup guard verifies that the file is a service
account for `FIREBASE_PROJECT_ID` before the Backend starts. The host directory
and file must be owned by the container runtime user and must not be
group/world-readable.

Production acceptance requires a real task and chat notification on a physical
Android device in both background and terminated states.

The public app domain must serve Android `assetlinks.json` and Apple
`apple-app-site-association` using the production signing fingerprint and Apple
Team ID. Do not publish temporary verification identities.
