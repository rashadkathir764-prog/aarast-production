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
- Backend runs `NODE_ENV=production`, requires Redis and media readiness,
  uses staging-only media service credentials, Meta test sender and a distinct
  Firebase project. It will not start with missing OTP or Firebase inputs.
- Admin is built with `AARAST_BUILD_TARGET=staging` and an explicit stage API
  origin. The build and runtime guards reject a missing or mismatched origin.
- The invite image rewrites canonical URLs and scheme for QA, and generates
  `assetlinks.json` from the distinct QA Android ID and signing fingerprint.

## Required private inputs

Copy `.env.example` into a file outside Git. Its `GENERATE_UNIQUE_*` values are
independent stage-only secrets. The `REPLACE_WITH_*` values need the owner's
actual stage domains, dedicated Meta test sender/template, and distinct Firebase
project/service account. The QA signing fingerprint comes from the separate
locally generated QA keystore. The
Firebase service account JSON must be mounted read-only in a stage-only private
directory; do not copy a Production credential or session. All four public
origins need DNS, TLS and explicit loopback-to-host routing. The public media
origin must proxy the S3 endpoint without changing the signed request path.

On this candidate's Windows preparation host, generated random secret values
are stored outside Git under
`%LOCALAPPDATA%\Aarast\Staging\full-isolated-staging-20261001\generated-secrets.env`
with an explicit current-user ACL. They are not deploy credentials until
securely installed on the target host. Do not paste them into reports or Git.
An independent QA signing keystore and its protected configuration were also
generated under the same directory (`qa-upload.p12`, `qa-signing.env`). Its
public SHA-256 fingerprint is used for the staging invite image. No QA APK is
built in this task.

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

Run from the repository root, with `STAGE_ENV` set to the private env path:

```sh
docker compose --env-file "$STAGE_ENV" -f deploy/staging/docker-compose.yml -f deploy/staging/docker-compose.build.yml config --format json | node deploy/staging/validate-config.mjs
node --test deploy/staging/staging-contract.test.mjs deploy/staging/public-site/build.test.mjs admin-web/scripts/staging-build-origin.contract.mjs
```

Inventory the server first. Confirm the project name, generated container
names, `aarast-full-staging-20261001_*` networks/volumes and four loopback
ports are unused. Confirm enough CPU, memory and disk for a separate stack.
Do not attach the new stack to a Production network or reuse the old OTP lab.
Do not route traffic until all dependencies are healthy.

After replacing every placeholder and recording a reviewed target candidate
SHA, build the three immutable stage images and start only this project:

```sh
docker compose --env-file "$STAGE_ENV" -f deploy/staging/docker-compose.yml -f deploy/staging/docker-compose.build.yml build backend admin-web public-site
docker compose --env-file "$STAGE_ENV" -f deploy/staging/docker-compose.yml up -d
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
