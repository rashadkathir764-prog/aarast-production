# OpenWA OTP Staging

This is the isolated acceptance environment for the risk-accepted OpenWA OTP
MVP. It is not production and shares no database, Redis instance, volume, or
internal network with production.

The only public route is:

`https://otp-lab-api.shadowgardn.com` -> `aarast-otp-stage-api:3000`

OpenWA has no public hostname. Its operator port binds to server loopback and is
reached only through SSH. PostgreSQL and Redis are internal-only. The backend
joins `nginx-proxy-manager_default` with a unique alias.
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

- OpenWA: `97e758e08035d0ed16567d96cfdaa7450387a77c`
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
3. Install and enable `aarast-otp-staging-firewall.service`, run
   `host-security.sh check`, and verify the `DOCKER-USER` chain before OpenWA.
   After a server reboot, unlock the LUKS mount first and then restart this
   service before running `docker compose up -d`. The persistent services use
   `on-failure` rather than a daemon-reboot restart policy so they cannot start
   against an unmounted ordinary host directory.
4. Run `docker compose --env-file .env config --quiet`.
5. Start the stack and require `db`, `redis`, and `openwa` to become healthy.
6. Create `ssh -N -L 2786:127.0.0.1:2786 rk-server` from the operator machine.
7. Open `http://127.0.0.1:2786/sessions` and pair the dedicated test account.
8. Require the loopback backend `/health` and `/ready` endpoints to return 200.
9. Add the Nginx Proxy Manager host `otp-lab-api.shadowgardn.com` forwarding to
   `http://aarast-otp-stage-api:3000`; enable WebSocket support, request a new
   certificate, force SSL, HTTP/2, and HSTS.
10. Require the public `/health` and `/ready` endpoints to return 200 before
   building the QA APK.

The bootstrap stores the transient key in a backend-only encrypted bind path
and a separate encrypted operator path that the backend never mounts. Never
print, commit, or include either key or the OpenWA session path in ordinary
backups.

## Acceptance and rollback

Run every live gate in `docs/deployment/OPENWA_OTP_MVP.md`. Begin with
`OTP_GLOBAL_DAILY_LIMIT=50`. The immediate kill switch is removing the public
proxy host. To preserve data while stopping delivery, set
`AUTH_OTP_MODE=disabled` and recreate only the backend.

If the session is irrecoverable, remove the staging OpenWA data, backend-secret,
and operator-secret volumes together and pair again. Never delete staging
PostgreSQL during a messaging-session reset.
