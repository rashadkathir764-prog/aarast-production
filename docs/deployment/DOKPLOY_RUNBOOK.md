# Aarast Dokploy Deployment Runbook

This folder prepares Aarast for a Dokploy Docker Compose deployment. It does not deploy anything by itself.

## Current Audit Note - 2026-06-14

Current committed Compose:

- `backend`: host `8093` -> container `3000`, domain `aarast-api.shadowgardn.com`.
- `admin-web`: host `8094` -> container `80`, documented/deployed at `aarast-admin.shadowgardn.com`.
- No separate Flutter web/mobile service exists in this Compose file.

Target split under review:

- API: `aarast-api.shadowgardn.com` on host port `8093`.
- Admin: `aarast-admin.shadowgardn.com` on host port `8094`.
- Flutter Web/Mobile Web: `aarast.shadowgardn.com` on host port `8095`.

Do not claim the full target split is live until Dokploy/NPM are updated and verified. Earlier audits saw `aarast-admin.shadowgardn.com` return HTTP 502 before the admin service was moved to the target host port.

## Services

- `postgres`: private PostgreSQL 16 database with the named volume `aarast_postgres_data`.
- `postgres-roles`: one-shot owner-authenticated role/grant initializer. It never
  starts the application and exits after reconciling the migrator/runtime roles.
- `migrate`: one-shot Backend image that validates the migrator identity, applies
  committed Prisma migrations, confirms their status, and exits before Backend.
- `backend`: NestJS API deployed from a prebuilt content-addressed image, exposed on host port `8093` and container port `3000`.
- `admin-web`: React/Vite admin dashboard deployed from a prebuilt content-addressed image, exposed on host port `8094` and container port `80`.

PostgreSQL must stay private. Do not create a public domain or host-port binding for the database.

## Required Environment Variables

Copy `deploy/dokploy/.env.example` into Dokploy's environment editor or into a private `.env` file managed outside Git. Never commit the real `.env`.

Required:

- `AARAST_BACKEND_IMAGE_ID`
- `AARAST_ADMIN_WEB_IMAGE_ID`
- `POSTGRES_DB`
- `POSTGRES_OWNER_USER`
- `POSTGRES_OWNER_PASSWORD`
- `AARAST_DB_MIGRATOR_USER`
- `AARAST_DB_MIGRATOR_PASSWORD`
- `AARAST_DB_MIGRATOR_DATABASE_URL`
- `AARAST_DB_RUNTIME_USER`
- `AARAST_DB_RUNTIME_PASSWORD`
- `AARAST_DB_RUNTIME_DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ORIGINS`
- `NODE_ENV`
- `PORT`
- `VITE_API_BASE_URL`
- `AUTH_OTP_MODE`
- `AUTH_LOGIN_THROTTLE_PEPPER`
- `AARAST_MEDIA_ROOT_USER`
- `AARAST_MEDIA_ROOT_PASSWORD`
- `AARAST_MEDIA_BUCKET`
- `AARAST_MEDIA_ACCESS_KEY_ID`
- `AARAST_MEDIA_SECRET_ACCESS_KEY`
- `AARAST_MEDIA_SIGNED_ENDPOINT`
- `PUSH_NOTIFICATIONS_ENABLED`
- `FIREBASE_PROJECT_ID` when push is enabled
- `AARAST_FIREBASE_CREDENTIAL_DIR` when push is enabled

Current backend note: the backend code reads `JWT_SECRET`. The compose file maps `JWT_ACCESS_SECRET` into the backend container as `JWT_SECRET`. `JWT_REFRESH_SECRET` is documented for the production secret contract, but it is not consumed by the current backend code.
`JWT_ACCESS_SECRET` must contain at least 32 UTF-8 bytes, include at least 12
distinct characters, and provide at least 128 estimated entropy bits. Known
placeholder or repetitive values are rejected at process startup; validation
errors never include the secret.

Channel-dependent required values:

- `AUTH_OTP_MODE=whatsapp`: configure the `WHATSAPP_*` Graph API/template values.
- `AUTH_OTP_MODE=openwa`: configure `OPENWA_BASE_URL`,
  `OPENWA_PRODUCTION_CREDENTIAL_DIR`, and the existing private
  `OPENWA_DOCKER_NETWORK`. The directory must be the production-only encrypted
  output of `deploy/openwa-otp-staging/bootstrap-openwa.mjs`; never copy a raw
  session id or API key into Dokploy. The backend mounts it read-only and
  reloads the credential for every send.

Optional:

- `OTP_EXPIRES_MINUTES`
- `OTP_MAX_ATTEMPTS`
- `AARAST_EXPOSE_OTP_IN_SMOKE`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `EMAIL_FROM`

### Firebase Admin credential

Keep `PUSH_NOTIFICATIONS_ENABLED=false` until the Aarast Firebase service
account is installed on the Dokploy host. Create the private directory outside
the repository, store the downloaded key with the exact name
`service-account.json`, and make it readable only by the container runtime
user:

```sh
install -d -m 0700 -o 1000 -g 1000 /var/lib/aarast/firebase
install -m 0600 -o 1000 -g 1000 \
  /secure/operator/firebase-service-account.json \
  /var/lib/aarast/firebase/service-account.json
```

Set:

```env
PUSH_NOTIFICATIONS_ENABLED=true
FIREBASE_PROJECT_ID=aarast-d62e9
AARAST_FIREBASE_CREDENTIAL_DIR=/var/lib/aarast/firebase
```

The Backend mounts this directory read-only. Its production startup command
fails before serving traffic when the file is missing, malformed, or belongs
to another Firebase project. Never place the downloaded JSON under the
repository checkout, Dokploy logs, shell history, or Markdown.

Production never echoes OTP codes. Meta remains the supported long-term
channel; the hardened OpenWA channel is the explicitly risk-accepted MVP path.
Its API key must come from the bootstrap secret and its session must pass the
`otp-readiness` contract before backend traffic is switched.

Use the Docker network service name for PostgreSQL. Passwords inside either URL
must be percent-encoded; the matching plain password remains in Dokploy's secret
environment for the one-shot role initializer:

```env
AARAST_DB_MIGRATOR_DATABASE_URL=postgresql://aarast_migrator:replace-with-url-encoded-migrator-password@postgres:5432/aarast?schema=public
AARAST_DB_RUNTIME_DATABASE_URL=postgresql://aarast_runtime:replace-with-url-encoded-runtime-password@postgres:5432/aarast?schema=public
```

The three identities are deliberately separate:

- The PostgreSQL owner is the bootstrap/recovery identity and is available only
  to `postgres`, `postgres-roles`, and the backup operation.
- The migrator owns the application database, `public` schema, and migration
  objects, but is explicitly `NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS`.
- The runtime can connect, use the application schema and types, perform
  `SELECT/INSERT/UPDATE/DELETE`, and use sequences. It cannot create schemas,
  tables, roles, or databases and receives no owner/migrator membership.

For an existing PostgreSQL volume, `POSTGRES_OWNER_USER` must name the actual
bootstrap superuser that already owns the cluster; changing the variable does
not create a new owner inside an initialized PostgreSQL volume. The
`postgres-roles` operation safely transfers current application objects to the
migrator and reconciles grants without deleting data.

Set CORS and API URLs for the public domains:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
VITE_API_BASE_URL=https://aarast-api.shadowgardn.com
```

The production admin image and Compose file also default to this public API
origin so a missing build argument can never produce a browser bundle that
calls `127.0.0.1`. The admin build gate rejects any production bundle that
contains the development loopback origin or omits the current MFA login route.

## Immutable Application Image Gate

The production Compose file never builds application images and never pulls a
mutable tag. Build both candidates from the final release commit on the
Dokploy host:

```sh
export AARAST_GIT_REVISION="$(git rev-parse HEAD)"
test "$(printf '%s' "$AARAST_GIT_REVISION" | wc -c)" -eq 40
docker compose \
  -f deploy/dokploy/docker-compose.build.yml \
  build --no-cache backend admin-web
```

Resolve the resulting content-addressed IDs and verify both revision labels:

```sh
BACKEND_TAG="aarast-backend:candidate-${AARAST_GIT_REVISION}"
ADMIN_TAG="aarast-admin-web:candidate-${AARAST_GIT_REVISION}"
AARAST_BACKEND_IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$BACKEND_TAG")"
AARAST_ADMIN_WEB_IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$ADMIN_TAG")"
test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$AARAST_BACKEND_IMAGE_ID")" = "$AARAST_GIT_REVISION"
test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$AARAST_ADMIN_WEB_IMAGE_ID")" = "$AARAST_GIT_REVISION"
```

Put only those two `sha256:...` IDs in Dokploy's private environment. Preserve
both images with `docker save`, record the archive SHA-256, and copy the
encrypted archive off-host before deployment. The runtime services use
`pull_policy: never`; a missing local image is a hard failure, not permission
to fall back to a tag. A registry digest may replace this single-host flow only
after a project-owned registry and explicit pre-pull step are approved.

If only the admin dashboard calls the API, `aarast-admin.shadowgardn.com` is enough. If Flutter web/mobile also runs on `aarast.shadowgardn.com`, include both browser origins:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
```

## Dokploy UI Steps

1. Open Dokploy.
2. Create a project named `Aarast`.
3. Add a Docker Compose application.
4. Select the GitHub repository for Aarast.
5. Select the protected `main` release branch.
6. Set the compose file path to `deploy/dokploy/docker-compose.yml`.
7. Complete the immutable image gate, then add environment variables from
   `deploy/dokploy/.env.example`, replacing every placeholder secret and image
   ID with the verified release values.
8. Create a domain for the backend service:
   - Service: `backend`
   - Internal port: `3000`
   - Host port: `8093`
   - Domain: `aarast-api.shadowgardn.com`
9. Create a domain for the admin dashboard service:
   - Service: `admin-web`
   - Internal port: `80`
   - Host port: `8094`
   - Domain: `aarast-admin.shadowgardn.com`
10. Enable SSL for both domains.
11. Deploy only after the backup restore rehearsal passes with the exact
    `AARAST_BACKEND_IMAGE_ID`.
12. Open logs for `postgres`, `backend`, and `admin-web`.
13. Test API liveness and readiness at `https://aarast-api.shadowgardn.com/health`
    and `https://aarast-api.shadowgardn.com/ready`.
14. Open `https://aarast-admin.shadowgardn.com`, confirm the browser bundle calls
    the public API origin, and complete password plus OTP admin login.

If the target split is used, open `https://aarast-admin.shadowgardn.com` for admin and reserve `https://aarast.shadowgardn.com` for Flutter web/mobile.

## Domain And DNS Plan

Create DNS records before deployment:

- `aarast-api.shadowgardn.com` points to the Dokploy server.
- `aarast.shadowgardn.com` points to the Dokploy server.
- `aarast-admin.shadowgardn.com` points to the Dokploy server.

All deployed browser domains must have SSL enabled in Dokploy. Keep `CORS_ORIGINS` limited to the domains that actually call the API.

## Migration And Startup Behavior

Migrations never run in the long-lived Backend runtime. Compose enforces this
order:

```text
postgres healthy
  -> postgres-roles completed successfully
  -> migrate completed successfully
  -> backend starts with the runtime URL
```

Both one-shot and runtime containers execute
`assert-database-identity.cjs` before touching the database. It validates that
the URL user and database match the assigned service role without printing the
URL or credentials. The `migrate` job then runs `prisma migrate deploy` and
`prisma migrate status`; Backend runs only `node dist/main.js`.

`prisma migrate deploy` applies committed migrations only. Do not run `prisma migrate dev`, `prisma db push`, database resets, or destructive migration commands against production.

After a clean deployment, verify the role attributes and database ownership
read-only from the private network:

```sh
docker compose -f deploy/dokploy/docker-compose.yml exec -T postgres \
  psql -U "$POSTGRES_OWNER_USER" -d "$POSTGRES_DB" -Atc \
  "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
   FROM pg_roles
   WHERE rolname IN ('$AARAST_DB_MIGRATOR_USER', '$AARAST_DB_RUNTIME_USER')
   ORDER BY rolname;"

docker compose -f deploy/dokploy/docker-compose.yml exec -T postgres \
  psql -U "$POSTGRES_OWNER_USER" -d "$POSTGRES_DB" -Atc \
  "SELECT datname, pg_get_userbyid(datdba)
   FROM pg_database WHERE datname = '$POSTGRES_DB';"
```

Expected: both application roles return `f` for every cluster-wide capability,
and the application database owner is the migrator. The release rehearsal must
also connect as runtime, prove CRUD succeeds, and prove `CREATE TABLE`,
`CREATE DATABASE`, and `CREATE ROLE` fail.

### Zero-downtime credential rotation and rollback

Do not replace the password of the live role in place. PostgreSQL keeps existing
sessions alive, but a pool reconnect in the rotation window could still fail.
Use a blue/green role and Backend rollout:

1. Keep the old Backend and role unchanged.
2. Choose a new safe runtime role name, generate a new password, and update the
   three `AARAST_DB_RUNTIME_*` values in the green deployment only.
3. Run `postgres-roles`, then `migrate`, for green. The initializer creates the
   new runtime role with the same bounded grants while blue remains connected.
4. Start green, wait for `/ready`, send a read and a reversible application
   smoke request, then switch traffic in Dokploy.
5. Drain blue. Revoke `CONNECT` and terminate only idle sessions of the exact
   old runtime role after the rollback window; do not drop the role while any
   owned or reviewed dependency remains.

Rollback before retiring blue is a router switch back to the still-running blue
Backend. If green fails after traffic moves, restore the old traffic target and
leave the new bounded role disabled for investigation. Owner and migrator
credentials use the same blue/green secret procedure around one-shot jobs; they
are never introduced into a Backend environment.

Before the first production deployment, confirm a database backup and rollback process exists. For later deployments, check migration SQL before deploying.

## Admin User Setup

The current production image does not include a production-safe admin reset command. Do not use hardcoded development credentials for production.

Before launch, create an approved one-off admin creation flow that accepts secrets from Dokploy environment variables or a secure console prompt. Never paste the admin password, Meta token, WhatsApp token, JWT secret, or database password into chat or commit them.

## Marketplace Bootstrap

The production marketplace can be initialized without running the broad development seed by using the limited, idempotent bootstrap script:

```sh
AARAST_PROVIDER_TEST_PASSWORD="set-this-outside-git" npm run prod:bootstrap-marketplace
```

The script upserts Yemen-first city references, provider categories, one clearly marked test provider account, and one active provider service. It does not delete data and must not be used as a payment, booking, deposit, loan, credit, or financing setup.

## Idempotency Tombstone Reconciliation

An expired `IdempotencyKey` with `completedAt = NULL` is ambiguous: the domain
transaction may have committed before its replay response was stored. The
hourly scheduler reports the `aarast_idempotency_ambiguous_tombstones` metric
but never deletes or reclaims these rows automatically.

Run the reconciliation command only inside the built Backend runtime whose
`DATABASE_URL` is already managed by Dokploy. It never prints the client key,
user id, request hash, stored response, or database credentials.

1. List at most the oldest 100 expired ambiguous rows, then inspect one exact
   opaque id:

   ```sh
   npm run prod:reconcile-idempotency -- --action=list
   npm run prod:reconcile-idempotency -- --action=inspect --id=<opaque-id>
   ```

2. Correlate the safe method/route/time with Backend request logs, the relevant
   domain row, audit records, notifications, and outbox events. Do not infer an
   outcome from the HTTP error alone.
3. If the domain mutation is proven not to have committed, release only that
   expired row. The exact method and route from `inspect`, an explicit proof
   label, and an id-bound confirmation are mandatory:

   ```sh
   IDEMPOTENCY_RECONCILE_CONFIRM=RECONCILE_IDEMPOTENCY_<opaque-id> \
     npm run prod:reconcile-idempotency -- \
     --action=release \
     --id=<opaque-id> \
     --expected-method=POST \
     --expected-path=/api/v1/example/:id \
     --proof=no-domain-commit
   ```

4. If the domain mutation is proven to have committed, reconstruct the exact
   original 2xx body, status, and only replay-safe representation headers in a
   private JSON file:

   ```json
   {
     "body": { "id": "verified-domain-id" },
     "statusCode": 201,
     "headers": { "location": "/api/v1/example/verified-domain-id" }
   }
   ```

   Then complete the same tombstone for deterministic replay:

   ```sh
   IDEMPOTENCY_RECONCILE_CONFIRM=RECONCILE_IDEMPOTENCY_<opaque-id> \
     npm run prod:reconcile-idempotency -- \
     --action=complete \
     --id=<opaque-id> \
     --expected-method=POST \
     --expected-path=/api/v1/example/:id \
     --proof=domain-commit-verified \
     --response-file=/secure/local/path/replay.json
   ```

   Remove the private response file after the incident evidence is retained in
   the approved operations system.

Both mutation modes lock the exact row, require it to remain expired and
ambiguous, compare method and route, and update/delete it conditionally in one
serializable transaction. If commit status cannot be proven, take no mutation
action: preserve the tombstone and escalate. Never use direct SQL, `db push`,
`migrate reset`, or a broad delete as a reconciliation shortcut.

## MinIO identity and policy

MinIO has two credential boundaries:

- `AARAST_MEDIA_ROOT_USER` and `AARAST_MEDIA_ROOT_PASSWORD` are available only
  to the `media` server and one-shot `media-init` service.
- `AARAST_MEDIA_ACCESS_KEY_ID` and `AARAST_MEDIA_SECRET_ACCESS_KEY` identify a
  dedicated Backend service account. These are the only MinIO credentials
  available in the long-lived Backend container.

`media-init` first removes anonymous access from the bucket, then enables
download only for `user-avatar/`, `provider-logo/`, `provider-cover/`, and
`service-image/`. It explicitly keeps `chat-image/` private. The Backend
service-account session policy permits only `GetBucketLocation` and
`PutObject/GetObject/DeleteObject` under those five exact prefixes in the one
application bucket. It grants no bucket creation/deletion, policy/user
administration, or access to another bucket. Re-running the initializer edits
the exact service account and policy in place rather than creating duplicates.

Before releasing, run the isolated MinIO least-privilege rehearsal and prove:

1. Backend credentials can put/get/delete in a public asset prefix and in
   `chat-image/`.
2. An unsigned public-prefix GET succeeds while an unsigned `chat-image/` GET
   is denied.
3. The same credentials cannot create a bucket, change a policy, write outside
   the five prefixes, or access a second bucket.
4. Root credentials do not occur in the rendered Backend environment.

Rotate the service account with a second access key: create and validate the
new key/policy, roll Backend to it, then remove the old key after the rollback
window. Never rotate by placing root credentials in Backend. If the new key
fails readiness, route back to the old Backend/key and leave the failed key
disabled for investigation.

## Health Checks

After deploy:

```powershell
Invoke-RestMethod https://aarast-api.shadowgardn.com/health
```

Expected result: HTTP 200 with the backend health payload.

Then open:

```text
https://aarast-admin.shadowgardn.com
```

Expected result: admin dashboard loads and sends API requests to `https://aarast-api.shadowgardn.com`.

## Backups

Enable backups for the PostgreSQL volume `aarast_postgres_data` in Dokploy or
the VPS backup layer. Before a schema-changing release, take a fresh backup,
store its SHA-256 beside a second off-host encrypted copy, and rehearse the
restore with the exact immutable candidate image:

```sh
AARAST_VERIFY_BACKEND_IMAGE=sha256:<candidate-image-id> \
  AARAST_VERIFY_GIT_REVISION=<full-git-sha> \
  AARAST_VERIFY_BACKUP_SHA256=<backup-sha256> \
  deploy/dokploy/scripts/verify-backup-restore.sh <backup-file>
```

The release is blocked unless restore, candidate migrations, a clean second
migration pass, and canonical schema checks all succeed. If an incompatible
migration has committed, rolling back the backend image alone is invalid: stop
the backend, restore the verified pre-deploy backup, and then restore the old
image.

## Rollback

1. Remove public backend traffic and stop `backend` before changing database
   state. Leave PostgreSQL, Redis, media, and OpenWA running.
2. Determine whether the release applied a database migration that is
   incompatible with the previous backend image.
3. If it did, restore the verified pre-deploy backup while `backend` remains
   stopped. Do not manually edit production data as a rollback shortcut.
4. Pin the previous known-good immutable backend image and recreate only
   `backend`. If no incompatible migration was applied, skip the database
   restore and perform only this image rollback.
5. Require the migration ledger, backend logs, `/health`, `/ready`, and the
   post-deploy route smokes to pass before restoring public traffic.
6. Roll back `admin-web` independently only when its artifact changed, then
   verify it loads and calls the intended public API origin.

## Local Review Commands

These commands are safe for reviewing this deployment preparation locally:

```powershell
cd D:\projects\aarast
git diff -- deploy/dokploy admin-web/Dockerfile admin-web/nginx.conf .gitignore
git status --short --untracked-files=all
```
