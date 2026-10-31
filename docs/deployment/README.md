# Deployment

The live system runs on one AWS host in Frankfurt with Docker Compose (`deploy/aws/`). How to release, back up and restore is in [`docs/handover/OPERATIONS.md`](../handover/OPERATIONS.md). Variable names are in [`docs/handover/ENVIRONMENT.md`](../handover/ENVIRONMENT.md).

## Folders

| Folder | Use |
|---|---|
| `deploy/aws/` | The live stack and `release.ps1` |
| `deploy/public-site/` | The public site image: privacy, support, invites, guest RSVP |
| `deploy/media/` | Bucket setup and media rules |
| `deploy/monitoring/` | Monitoring stack |
| `deploy/openwa-otp-lab/`, `deploy/openwa-otp-staging/` | WhatsApp code transport, see [OPENWA_OTP_MVP.md](OPENWA_OTP_MVP.md) |
| `deploy/staging/` | Full staging candidate, checked by CI, not deployed |
| `deploy/dokploy/` | The former host's Compose files. Tests still read them. Not the live path |

## Release rules

- `deploy/aws/release.ps1` ships the last commit. Uncommitted work does not ship.
- Take a manual database backup before any release with a migration.
- Published migrations never change. Their fingerprints are pinned in `backend/architecture/published-migrations.json`.
- A release is not done without checking `/ready` afterwards.
- Never write real secrets into Markdown.

## Health

- `GET /live` checks that the API process can serve HTTP.
- `GET /ready` checks PostgreSQL, Redis, media and OpenWA. It returns names, status and latency only, and fails with `503`. A stopped OpenWA fails `/ready` even when everything else is fine.

## OTP

`AUTH_OTP_MODE=openwa` is the risk-accepted transport today, through a restricted tunnel to OpenWA. Meta verification was rejected, so `AUTH_OTP_MODE=whatsapp` is not in use. The API refuses to boot with an incomplete channel.

## Admin accounts

`npm run prod:provision-admin` from the backend runtime creates an administrator or rotates a password. It takes `PROVISION_ADMIN_PHONE`, `PROVISION_ADMIN_PASSWORD`, `PROVISION_ADMIN_NAME` and `PROVISION_ADMIN_CONFIRM=PROVISION_AARAST_ADMIN` as one-time inputs, which never stay in the persistent environment.

## Media

Chat images stay private and open only through short signed links. Anonymous reads are limited to the public prefixes: `user-avatar/`, `provider-logo/`, `provider-cover/` and `service-image/`.

## Guest RSVP

The public site serves `/rsvp/<token>`, and the edge proxy forwards `/api/v1/public/rsvp/*` on the same host to the backend (`deploy/aws/Caddyfile`). `INVITE_PUBLIC_ORIGIN` must be the site host.

## Mobile release

Release builds need a public `https://` API origin. Android needs the real upload keystore through `key.properties`, and the four `AARAST_FIREBASE_*` values as private build inputs. Sentry runs from the build defines `AARAST_SENTRY_DSN`, `AARAST_ENVIRONMENT`, `AARAST_SENTRY_TRACES_SAMPLE_RATE` and `SENTRY_RELEASE`; an empty DSN turns it off. See [STORE_RELEASE.md](STORE_RELEASE.md).

Push stays off unless `PUSH_NOTIFICATIONS_ENABLED=true`, which needs `FIREBASE_PROJECT_ID` and private service-account credentials.
