# OpenWA OTP Staging

This is the acceptance environment for the risk-accepted OpenWA OTP MVP. Its
database and Redis are isolated from production. During this temporary MVP,
production and acceptance deliberately share the one dedicated WhatsApp
session and OpenWA service so the account is not repeatedly paired; they use
different session-scoped transport credentials and different backend data.
An OpenWA outage therefore affects both environments and remains an explicit
MVP risk until the approved Meta transport replaces it.

The only public route is:

`https://otp-lab-api.shadowgardn.com` -> `aarast-otp-stage-api:3000`

OpenWA has no public hostname. Its operator port binds to server loopback and is
reached only through SSH. PostgreSQL and Redis are internal-only. The backend
joins a dedicated internal proxy bridge with a unique alias. The host security
script attaches only the reviewed active reverse-proxy container to that bridge;
the backend never joins the proxy's shared network.
OpenWA alone also joins an outbound-only bridge so WhatsApp can be reached;
that bridge publishes no port and is not shared with the database or Redis.
`host-security.sh` blocks that bridge from loopback, private, link-local,
carrier-grade NAT, benchmark, multicast, and reserved destinations while
allowing required public WhatsApp egress.

## Provenance gate

Build from clean committed source and label each image with its full Git SHA.
The first private acceptance run may load those exact images over authenticated
SSH. Before a wider rollout, publish to a project-owned registry and pin by
registry digest. Never deploy `latest` or the upstream OpenWA image.

- OpenWA: `b7696b82c3b655d2c4ddb87a66a1d4adb3c1b5bd`
- Aarast: `e2d0c1ab792fc1431d9a7d0be38c12f4ca3da47e`

## First deployment

1. Create and unlock the LUKS mapper `aarast_otp_staging_crypt`, mount it at
   `/var/lib/aarast-otp-staging/secure`, and create the marker
   `.aarast-otp-encrypted` inside the mounted filesystem. Keep its key outside
   the server. `host-storage.sh create` and `host-storage.sh unlock` read that
   key only from standard input; `host-storage.sh check` proves the mapper and
   `nodev,nosuid,noexec` mount flags, and `host-storage.sh verify-key` proves the
   off-server key can reopen the LUKS header. The stack fails closed when the
   mount or marker is absent.
2. Copy `.env.example` to a deployment-host-only `.env`, replace every
   placeholder with a random URL-safe value, and set mode `0600`.
3. Install and start `aarast-otp-staging-firewall.service` with
   `systemctl enable --now`, then run `host-security.sh check` and verify the
   `DOCKER-USER` chain before OpenWA.
   This step also creates `aarast_otp_staging_proxy` and attaches the active
   reverse proxy. The script detects the current `dokploy-traefik` container
   first and retains `nginx-proxy-manager` as a legacy fallback. Set
   `AARAST_OTP_PROXY_CONTAINER_NAME` only when the deployment uses a different
   explicitly reviewed proxy container. After that proxy is recreated, restart
   the firewall service to apply the attachment and then rerun the check.
   After a server reboot, unlock the LUKS mount first and then restart this
   service before running `docker compose up -d`. The persistent services use
   `on-failure` rather than a daemon-reboot restart policy so they cannot start
   against an unmounted ordinary host directory.
4. Run `docker compose --env-file .env config --quiet`.
5. Start the stack and require `db`, `redis`, and `openwa` to become healthy.
   Keep `OPENWA_MEMORY_LIMIT` at `2g` or higher unless a measured acceptance
   run proves a lower cgroup limit does not OOM-kill Chromium.
6. Start `operator-qr-bridge.mjs` as the deployment user with the master key and
   session ID supplied only through its environment. It binds to server
   loopback, exposes neither key, and shuts down automatically after 15 minutes.
7. Create `ssh -N -L 2788:127.0.0.1:2787 rk-server`, open
   `http://127.0.0.1:2788`, and pair the dedicated test account from the live,
   auto-refreshing QR page. Stop the bridge immediately after pairing.
8. From the active reverse proxy container (Dokploy Traefik, or the legacy
   Nginx Proxy Manager fallback), require
   `http://aarast-otp-stage-api:3000/health` and `/ready` to return 200. The
   backend intentionally has no host port and no non-internal network.
9. Add the proxy route `otp-lab-api.shadowgardn.com` forwarding to
   `http://aarast-otp-stage-api:3000`; enable WebSocket support, request a new
   certificate, force SSL, HTTP/2, and HSTS.
10. Require the public `/health` and `/ready` endpoints to return 200 before
   building the QA APK.

The bootstrap stores three independent, expiring credentials inside the
encrypted mount: one for the acceptance backend, one for the production
backend, and a viewer key for operator audits. Each backend mounts only its own
directory read-only and reloads `openwa.env` for every delivery. The scheduled
rotator creates and validates a replacement before atomically switching the
file; the previous correctly-scoped key remains usable only until its expiry.
The bootstrap and rotator share an exclusive, stale-recoverable lock so two
reconciliations cannot create competing sessions or keys. Never print, commit,
or include any key or the OpenWA session path in ordinary backups.

Rotating `OPENWA_API_KEY_PEPPER` is a two-recreate operation and does not
require pairing WhatsApp again. First take an encrypted, stopped-state backup
of the OpenWA database and the three credential directories. Put only the new
pepper in `.env`; provide the old value to the first OpenWA recreate through
the operator shell as `OPENWA_API_KEY_PREVIOUS_PEPPER`. The reviewed OpenWA
startup atomically re-hashes only `API_MASTER_KEY`; ordinary keys never fall
back to the previous pepper. Run the bootstrap to issue and validate new
staging, production, and audit keys, then immediately recreate OpenWA again
without `OPENWA_API_KEY_PREVIOUS_PEPPER`. Require one `ready` session, both
backend `/ready` endpoints at 200, distinct credential ids, and zero unexpected
restarts. Never persist the previous pepper or solve a pepper rotation by
deleting/re-pairing the WhatsApp session.

Before a database-changing backend release, create a custom-format `pg_dump`
inside the encrypted staging mount with mode `0600`, record its SHA-256, and
copy a second encrypted copy off-host. Rehearse that backup with the immutable
candidate backend:

```sh
AARAST_VERIFY_BACKEND_IMAGE=sha256:<candidate-image-id> \
  AARAST_VERIFY_GIT_REVISION=<full-git-sha> \
  AARAST_VERIFY_BACKUP_SHA256=<backup-sha256> \
  deploy/dokploy/scripts/verify-backup-restore.sh <backup-file>
```

The verifier must pass the restore, migration, second migration pass, and
canonical schema checks before the live database is touched. Record all
container IDs and restart counts, then
recreate only `backend` with `--no-deps`. Do not restart `db`, `redis`,
`openwa`, `openwa-bootstrap`, or `openwa-credential-rotator` during a
backend-only release.

## Acceptance and rollback

Run every live gate in `docs/deployment/OPENWA_OTP_MVP.md`. Begin with
`OTP_GLOBAL_DAILY_LIMIT=50`. The immediate kill switch is removing the public
proxy host. To preserve data while stopping delivery, set
`AUTH_OTP_MODE=disabled` and recreate only the backend.

For a backend rollback without an incompatible database migration, pin the
previous immutable image and recreate only `backend`. If an incompatible
migration reached the staging database, first remove public traffic and stop
`backend`; restore the verified pre-deploy database backup while it is stopped;
then pin the previous immutable image and recreate only `backend`. Require
`/health`, `/ready`, the migration ledger, and the route-contract smoke to pass
before restoring traffic. Never roll back or recreate `openwa`, `db`, or `redis`
as part of a backend-only rollback.

If the session is proven irrecoverable, stop both OTP backends before removing
the OpenWA data plus `backend-secret`, `production-secret`, and
`operator-secret`, then pair once and bootstrap all credentials again. Never
delete staging PostgreSQL during a messaging-session reset.
