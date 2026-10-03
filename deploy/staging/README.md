# Full isolated staging deployment candidate

This directory defines a **new** Compose project, `aarast-full-staging-20261001`.
It has never been deployed merely by building or validating these files. The
existing Dokploy Production and OpenWA OTP lab projects are not dependencies.

## Isolation contract

- PostgreSQL, Redis, MinIO, backup, migration, Backend, Admin and invite site
  use project-owned service names, networks and volumes. PostgreSQL, Redis,
  role initialization, migration and backups have no public port. Public-facing
  services bind only to host `127.0.0.1`; an independently approved TLS route
  must be installed before phone testing.
- The owner/bootstrap account starts PostgreSQL and provisions two distinct
  accounts via the existing least-privilege SQL: migrator owns the application
  schema; runtime has DML and sequence use, without CREATE or role membership.
  `migrate` runs separately before Backend. Neither app container receives
  the owner password. The bootstrap account is confined to the private
  PostgreSQL service and backup job.
- `postgres_backups` is a project-owned volume with a daily retention policy.
  Before real use, choose a stage-only off-host encrypted backup destination
  and prove a restore. Never copy Production data into staging.
- Core Backend runs `NODE_ENV=production`, requires PostgreSQL, Redis and media
  readiness, and uses staging-only media credentials. Its explicit
  `AARAST_DEPLOYMENT_TIER=staging` fails boot against another database or
  runtime role; Production Compose does not set this marker. Its explicit
  `AUTH_OTP_MODE=disabled` and `PUSH_NOTIFICATIONS_ENABLED=false` need no
  OpenWA or Firebase credential. OTP request and verification fail explicitly
  while disabled; Push delivery does not contact Firebase. `/live` is process
  liveness. `/ready` requires database, Redis and media; the existing `openwa`
  diagnostic is `disabled` in Core and does not claim phone OTP readiness.
- Phone acceptance is a separate gate: it additionally requires an isolated
  real OTP sender, isolated Firebase client and Backend credentials, QA APK,
  App Links, and acceptance accounts and journeys. Core `/ready=200` is not
  evidence that OTP or Push is operational. Enabling Push requires the existing
  Firebase credential preflight and fails closed without a stage-only account.
- Admin is built with `AARAST_BUILD_TARGET=staging` and an explicit stage API
  origin. The build and runtime guards reject a missing or mismatched origin.
- The invite image rewrites canonical URLs and scheme for QA, and generates
  `assetlinks.json` from the distinct QA Android ID and signing fingerprint.
- Compose enforces `mem_limit` and `cpus` on the one-shot jobs: role setup
  128 MiB/0.20 CPU, media initialization 128 MiB/0.20 CPU, and migration
  768 MiB/1.00 CPU. The existing long-running memory caps total 2,528 MiB.
  Given the measured 5.34 GiB `MemAvailable`, the maximum overlapping
  startup caps are 2,656 MiB, leaving about 2.75 GiB before host/Docker
  overhead. No swap or on-server image build is part of this budget.

## Required private inputs

Copy `.env.example` into a file outside Git. Its `GENERATE_UNIQUE_*` values are
independent stage-only secrets. Core needs the owner's four actual stage domains,
but **no** OpenWA/Firebase credential. Its runtime Compose has no Firebase
mount; it runs the credential preflight only when Push is explicitly enabled.
Phone acceptance later needs a dedicated OpenWA session and a separate
Firebase project, Android app and Backend service account. The reviewed
`docker-compose.phone.yml` overlay and `phone.env.example` require two distinct
stage-only read-only credential mounts and a separately proven OpenWA endpoint.
The old `deploy/openwa-otp-staging` installation shares a Production session and
must never be used for this overlay. Core `/ready` remains a Core-only signal;
phone readiness additionally requires a real OTP and Push delivery test.
The validator rejects enabled Push without isolated credentials and rejects
Production origins. The technical `.qa` package/project names denote this
private Staging/Test Release, not a publicly released product.
Never copy a Production credential or session. All four public origins need
DNS, TLS and explicit loopback-to-host routing. The public media origin must
proxy the S3 endpoint without changing the signed request path.

On this candidate's Windows preparation host, generated random secret values
are stored outside Git under
`%LOCALAPPDATA%\Aarast\Staging\full-isolated-staging-20261001\generated-secrets.env`
with an explicit current-user ACL. They are not deploy credentials until
securely installed on the target host. Do not paste them into reports or Git.
An independent QA signing keystore and its protected configuration were also
generated under the same directory (`qa-upload.p12`, `qa-signing.env`). Its
public SHA-256 fingerprint is used for the staging invite image. No QA APK is
built until the staging origins and external integrations are verified.

The registered Firebase Android app uses the existing technical package ID
`com.aarast.aarast_mobile.qa` for this private Staging/Test Release. The
current Flutter/Gradle integration consumes four `AARAST_FIREBASE_*` Dart
defines and generates the Android resource values from them; it does not
require a committed `google-services.json`. Keep the project-specific
`firebase-android-dart-defines.json` outside Git and supply it to Flutter with
`--dart-define-from-file` alongside the staging API/invite defines. The
Android API key must remain restricted to this package and the QA signing
certificate SHA-1. The Backend credential is a separate service-account JSON
mounted read-only at `/run/aarast-firebase/service-account.json` only when
Push is enabled.

For the later Android QA build, set `AARAST_ANDROID_APPLICATION_ID` to the QA
package, `AARAST_ANDROID_APP_LABEL` to the QA label and load the private QA
signing variables. Supply Dart defines `AARAST_ENVIRONMENT=staging`,
`AARAST_API_BASE_URL=<stage API origin>`,
`AARAST_INVITE_HOST=<stage invite host>`, `AARAST_INVITE_SCHEME=aarast-qa`,
and the four values from the separate Firebase Android app. The Gradle release
guard rejects QA identity without these stage settings and never reads the
Production `android/key.properties` when staging is selected. Match the
keystore fingerprint to `STAGING_QA_CERT_FINGERPRINT` before a future APK build.

## Preflight and deployment order

Run from the repository root, with `STAGE_ENV` set to the private env path.
The deployment preflight uses only the runtime Compose file; the separate
build file is for an off-server build host:

```sh
docker compose --env-file "$STAGE_ENV" -f deploy/staging/docker-compose.yml config --format json | node deploy/staging/validate-config.mjs
node --test deploy/staging/staging-contract.test.mjs deploy/staging/public-site/build.test.mjs admin-web/scripts/staging-build-origin.contract.mjs
```

For the future phone-acceptance deployment, first prove that the OpenWA
session, endpoint and credential path are independent of the older shared
installation. A new OpenWA bootstrap must use
`OPENWA_BOOTSTRAP_PROFILE=isolated-staging` and an explicit new session name;
that profile creates only the Staging transport and operator audit keys. It
must never mount the old Production transport directory. Keep `PHONE_ENV`
outside Git with the values described in
`phone.env.example`, then run the separate fail-closed preflight:

```sh
docker compose --env-file "$STAGE_ENV" --env-file "$PHONE_ENV" -f deploy/staging/docker-compose.yml -f deploy/staging/docker-compose.phone.yml config --format json | node deploy/staging/validate-config.mjs --phone-acceptance
```

This command validates configuration only; it does not create a session or
prove OTP/Push delivery. Do not run the phone overlay until both external
integrations and their isolated credential files have been verified.

The separate `docker-compose.openwa.yml` describes a **new** OpenWA instance,
not an extension of `deploy/openwa-otp-staging/`. It has a different Compose
project, networks, encrypted data root, SQLite session, API master key,
pepper, transport key and session name. Its bootstrap runs the
`isolated-staging` profile, which never creates a Production transport key.
Before running it, choose a host with at least its 2 GiB OpenWA memory budget
in addition to Core Staging and existing workloads. Prepare a fresh encrypted
mount containing `.aarast-full-staging-openwa-encrypted`, fresh secrets and an
immutable reviewed OpenWA image outside Git. Check the resolved topology with:

```sh
docker compose --env-file "$OPENWA_ENV" -f deploy/staging/docker-compose.openwa.yml config --format json | node deploy/staging/validate-config.mjs --openwa
```

The operator port remains loopback-only. The Backend must receive only this
instance's short-lived `backend-secret/openwa.env`, including each rotation,
through a protected transport. If OpenWA runs on another host, establish its
private authenticated TLS route and credential synchronization before enabling
the phone overlay. QR pairing of a separate WhatsApp number is an operator
step; no old session directory may be copied. Neither the Compose file nor a
successful bootstrap proves OTP delivery before pairing and live send/verify
tests.

Inventory the server first. Confirm the project name, generated container
names, `aarast-full-staging-20261001_*` networks/volumes and four loopback
ports are unused. Confirm enough CPU, memory and disk for a separate stack.
Do not attach the new stack to a Production network or reuse the old OTP lab.
Do not route traffic until all dependencies are healthy.

After replacing every placeholder, check out the reviewed final candidate SHA
on a separate build host. Give that host a separate `BUILD_ENV` file containing
only `STAGING_GIT_REVISION`, the three `STAGING_*_IMAGE_ID` tags,
`STAGING_API_ORIGIN`, `STAGING_INVITE_ORIGIN`, `STAGING_QA_INVITE_HOST`,
`STAGING_QA_APPLICATION_ID`, and `STAGING_QA_CERT_FINGERPRINT`. It does not
need database, OTP, Firebase, or other runtime secrets. Set the revision and
all three image tags to the exact 40-character candidate SHA. Do not build on
the deployment server:

```sh
# Off-server build host, from the final candidate checkout:
set -a; . "$BUILD_ENV"; set +a
test "$(git rev-parse HEAD)" = "$STAGING_GIT_REVISION"
docker compose --env-file "$BUILD_ENV" -f deploy/staging/docker-compose.build.yml config --quiet
docker compose --env-file "$BUILD_ENV" -f deploy/staging/docker-compose.build.yml build backend admin-web public-site
for image in "$STAGING_BACKEND_IMAGE_ID" "$STAGING_ADMIN_IMAGE_ID" "$STAGING_PUBLIC_SITE_IMAGE_ID"; do
  test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")" = "$STAGING_GIT_REVISION"
done
```

Record each image digest and transfer the immutable images through an approved
private registry by digest, or an authenticated `docker save`/`docker load`
channel. On the server, verify the loaded image IDs/digests and revision labels
against the build-host record. The three SHA tags must resolve to those exact
images. Run the runtime Compose preflight above again, then use only
`docker-compose.yml` with `up --no-build`; never pass
`docker-compose.build.yml` on the server. This is a future deployment step,
not an instruction to start this candidate now.

```sh
# Future server command only, after all prerequisites and approvals are met:
docker compose --env-file "$STAGE_ENV" -f deploy/staging/docker-compose.yml up -d --no-build
```

Verify 76 migration records and `prisma migrate status` using the migrator
role. A second `migrate deploy` must be a no-op. Verify owner/migrator/runtime
role identity and privileges, Redis ping, MinIO bucket/service-account/media
round-trip, `/live`, `/ready`, Admin runtime origin and HTTPS invite
assetlinks. Then configure independent TLS routes and recheck through the
public stage domains. A `200` alone does not prove deployment SHA; inspect
the image revision labels. No APK or acceptance accounts are created here.

If prerequisites are absent, leave the server unchanged and report the exact
missing input. Never use a disabled readiness flag, fake Firebase key, shared
OpenWA session, or Production origin to make the stack green.
