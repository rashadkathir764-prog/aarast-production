# Deployment

Snapshot date: 2026-08-11

Deployment source files live under `deploy/dokploy/`, with the public static
image source under `deploy/public-site/`. This folder is the compact
documentation entry point for deployment.

## Current Runtime Contract From Source Files

Local Docker Compose:

- PostgreSQL: `5433 -> 5432`
- Backend: `3115 -> 3000`

Production Dokploy Compose:

- Backend API: `8093 -> 3000`
- Admin web: `8094 -> 80`
- Public static site: `8095 -> 80`

Public domains documented for the current deployment path:

- Backend API: `https://aarast-api.shadowgardn.com`
- Admin web: `https://aarast-admin.shadowgardn.com`
- Public privacy, support, invite, and mobile-link surface:
  `https://aarast.shadowgardn.com`
- Public/signed media origin: `https://aarast-media.shadowgardn.com`

The service on `8095` is the allowlisted static image under
`deploy/public-site/`, not Flutter Web. Production Compose requires its
content-addressed `AARAST_PUBLIC_SITE_IMAGE_ID`; release-build Compose stamps
Backend, Admin Web, and the public-site image with the same full 40-character
Git revision. No Flutter web service is currently defined, and adding one
requires a later routing, caching, CORS, and release decision.

Admin production builds default to the public backend origin and fail their
post-build gate if a loopback API or the current MFA login route is missing.

## Rules

- Do not modify Docker, Docker Compose, Dokploy, domains, ports, migrations, or
  production secrets unless deployment work is explicitly requested.
- Never write real secrets into Markdown.
- Production deployment is not complete without post-deploy smoke checks.

## Dependency Gate

The current Admin dependency tree uses `react-router-dom@7.18.2` with
`react-router@7.18.2` and `nanoid@3.3.18`. The full `npm audit` currently reports
zero vulnerabilities. This is source evidence only; it does not replace the
Admin test, type-check, build, route, honesty, container-config, or deployed
runtime gates.

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

## Latest Production Deployment Receipt - 2026-08-11

Dokploy is running application revision
`959c47b756d0bebc3e4e4fda5f81ae3349d05e62` with healthy immutable Backend,
Admin Web, and public-site images. Their accepted image IDs are:

- Backend: `sha256:3a2bdd5686077df37bce6f03ea002bb8deec4b6c95e14f91cf2c3e10e937d7bd`
- Admin Web: `sha256:7a61bdc31f5836b3d3fec753b220410bf867dc362d635f78d65e7239ec7b4ed0`
- public site: `sha256:b36dd8b52e94e75055484412f0f044acfb40f6e77cd676bbde382b382355850e`

The acceptance snapshot reports zero restarts and no OOM termination. External
Backend `/live` and `/ready`, Admin `/login`, public privacy/support/invite, and
Android association checks PASS. Unknown public routes and Apple association
fail closed with `404`.

The pre-deployment custom-format PostgreSQL backup has SHA-256
`1c327dab578ee8879a2dd845f37d8d736dc5e76ad600bfbe3089294d55ff6c82`.
Checksum, catalog listing, full isolated restore against the exact Backend
image, all `76` migrations, a second idempotent migration pass, canonical
schema checks, and contributor-history relational postconditions PASS. The
live result is 16 plans, 16 linked history scopes, zero missing scopes, zero
lifecycle mismatches, zero missing tenures, and zero unfinished migrations.

The protected production release directory contains the previous environment
and route snapshots plus one old/new immutable-image rollback archive with
SHA-256 `1b18817397e284703e3c8a24a640d59b58a4d9cdc587dc3e81653633e5c1532e`.

This receipt closes the current Backend/Admin/public deployment and database
recovery gate. It does not close Mobile physical-device, store signing/upload,
iOS, live Sentry, metrics/monitoring, OTP, or Push acceptance.

## Contributor History And Account Deletion Migration Release Gate

Migrations `20260802090000_add_contributor_history`,
`20260803110000_add_account_deletion_receipts`, and the repair migration
`20260811180000_backfill_missing_contributor_history_scopes` ship through one
coordinated writer cutover, not a rolling mixed-version migration. Old replicas do not enforce the
stored-flag authority, frozen contribution-event contract, membership-bound
self-leave, or recoverable account-deletion receipt consistently, so they must
not accept writes after the new schema starts recording history.

The required production order is:

1. Enter maintenance mode, stop new API traffic, and drain all in-flight
   requests from every old Backend replica.
2. Confirm the database backup/restore point and keep all application writes
   stopped.
3. Run `npx prisma migrate deploy`; require
   `20260802090000_add_contributor_history`,
   `20260803110000_add_account_deletion_receipts`, and
   `20260811180000_backfill_missing_contributor_history_scopes` to finish
   successfully. The
   history migration's table locks and baseline/backfill count assertions fail
   closed rather than accepting an incomplete cutover; the receipt migration
   installs its immutable table and mutation-rejection triggers before the new
   account-deletion recovery route receives traffic.
4. Deploy the contributor-history-compatible Backend image to every replica
   while traffic remains closed. Do not leave an old replica eligible for
   routing or background writes.
5. Confirm `npx prisma migrate status`, `/ready`, and targeted owner/two-
   contributor smoke checks for stored permission revocation, cross-contributor
   isolation, immutable history, membership-bound self-leave, login/context
   refresh, a new invitation tenure, and account deletion with lost-response
   receipt reconciliation.
6. Reopen traffic only after every replica is on the same compatible release
   and all checks pass.

If migration or validation fails before traffic reopens, keep maintenance mode
and correct the migration/deployment forward or restore the coordinated
pre-cutover database and old application release before accepting any new
writes. Once any new `ContributionEvent` has been committed, do not roll back
the schema, drop the history tables/enums/trigger, or run an old writer. Roll
the application forward. A database restore to the pre-cutover point would
discard post-cutover contribution history and other writes and therefore is
not an ordinary rollback path.

The matching mobile release gate includes a native sequential upgrade rehearsal
from SQLCipher schema version 6 through version 7 to the current version 8.
The version 6 -> 7 step must prove that every plan-scoped pending sync row
emerges with a verified explicit `planId`; unknown or contradictory legacy
ownership remains permanently blocked and must never be guessed from an
endpoint, local id, cache key, nested payload, or substring. The version
7 -> 8 step must prove that `cached_dashboard_summaries` is created without
losing the migrated queue, account ownership, or existing cached data. The same
rehearsal must also prove that a durable pending-leave marker survives process
death, cache clear, and ordinary logout, hides the departed plan before context
selection, and is removed only after server reconciliation, exact plan-graph
deletion, and a filtered context refresh. Do not roll out the mobile build until
the complete version 6 -> 7 -> 8 chain passes on both Android and iOS.

Release automation must supply `AARAST_FIREBASE_API_KEY`,
`AARAST_FIREBASE_APP_ID`, `AARAST_FIREBASE_MESSAGING_SENDER_ID`, and
`AARAST_FIREBASE_PROJECT_ID` through the approved protected build environment.
Recovering public client configuration from a previously signed APK is useful
for a one-off local verification artifact but is not an acceptable repeatable
CI or store-release configuration source.

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

The repository now contains static source for the current store-facing URLs:

- Privacy: `https://aarast.shadowgardn.com/privacy`
- Support and account-deletion guidance:
  `https://aarast.shadowgardn.com/support`

These URLs must return the intended pages over HTTPS in the release environment
before they are submitted to either store. Their presence in source and Compose
is not production-deployment evidence.

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

The latest direct-install Android Release APK is `1.0.0+8`, built from source
revision `2ffbe95d7a8e412ead47220536046501f4ac86bf` against the Production HTTPS
origin with the private Firebase client inputs. It is non-debuggable, targets
SDK 36 with min SDK 24, uses APK Signature Scheme v2, and is signed by the
Aarast RSA-3072 upload identity that matches the deployed Android
`assetlinks.json`. Its size is 88,634,008 bytes and SHA-256 is
`075D82E24BEF4DED75F34D663B76132C9A6D6F89C7FE6535009C734A0CA1C69D`.
The embedded Sentry release identifier is
`aarast-mobile@1.0.0+8-2ffbe95d7a8e412ead47220536046501f4ac86bf`.

This APK is a signed direct-install artifact, not a store-approved AAB, and it
intentionally uses an empty Sentry DSN because live Sentry credentials were not
available for this local build. It has not completed the live-account
slow/offline/error/interruption matrix, background/terminated Push, WhatsApp
OTP, iOS Archive, live symbol upload, or store upload. The current web/API
deployment at revision `959c47b7` includes later Mobile source corrections but
does not build or install a native binary; the APK provenance remains the exact
`2ffbe95d` source revision above.

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

Production now serves Android `assetlinks.json` through the well-known path and
deliberately returns `404` for Apple `apple-app-site-association`. External TLS,
headers, expected routes, fail-closed routes, and the current Android upload
identity passed at revision `959c47b7`. Before store release, repeat Android
association against the final Play signing certificate and replace the Apple
fail-closed response only after the real Apple Team ID and bundle association
are known. Do not publish temporary verification identities. Deployed HTTP
acceptance still does not prove physical-device link handling.
