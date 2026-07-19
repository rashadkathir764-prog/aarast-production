# Deployment

Snapshot date: 2026-07-19

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
bucket initializer. Anonymous downloads are limited to the `user-avatar/`,
`provider-logo/`, `provider-cover/`, and `service-image/` prefixes. The
`chat-image/` prefix is never public. Provider services may own multiple image
rows; Flutter uploads and verifies each selected image before binding it to the
service, and the public provider profile exposes the ordered gallery.

## Mobile Store Release Gate

Release builds require an explicit public `https://` API origin and reject the
development login bypass. Android additionally requires a real non-debug upload
keystore through private `key.properties` or `AARAST_ANDROID_*` environment
variables. iOS runs the equivalent configuration check as a Release Xcode build
phase. Native launcher/splash assets and link declarations are committed, but
final AAB/IPA signing, store upload, and real-device links remain external
gates. See `STORE_RELEASE.md`.

The public app domain must serve Android `assetlinks.json` and Apple
`apple-app-site-association` using the production signing fingerprint and Apple
Team ID. Do not publish temporary verification identities.
