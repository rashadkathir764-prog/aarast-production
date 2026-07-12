# OpenWA OTP Lab

This Compose stack is an isolated, loopback-only MVP laboratory. It does not
modify the normal Aarast Compose or Dokploy services and is not a production
deployment manifest.

It starts PostgreSQL, non-persistent Redis, the pinned Aarast OpenWA fork, a
one-shot credential bootstrap, and the Aarast backend. The bootstrap creates a
single WhatsApp session plus a session-scoped `transient_sender` key and stores
that key in a Docker volume readable by the backend, not in the repository.

## Required gate

1. Build the two reviewed local images from their pinned source trees.
2. Populate a private env file from `.env.example` with cryptographically
   random, URL-safe values.
3. Validate with `docker compose --env-file <private-file> config --quiet`.
4. Start with `docker compose --env-file <private-file> up -d`.
5. Open only the loopback operator port, fetch the session QR, and scan it with
   the dedicated disposable WhatsApp number.
6. Require Aarast `GET /ready` to return `200` before any OTP test.

The API and OpenWA operator ports bind only to `127.0.0.1`; PostgreSQL and Redis
have no host ports. Both application containers use read-only root filesystems,
bounded resources, dropped capabilities, and `no-new-privileges`.
OpenWA auto-starts previously linked sessions after a container restart; a
restart must return Aarast `/ready` to `200` without another QR scan or a manual
session-start request.

This OTP-only lab intentionally has no media service and sets
`READINESS_REQUIRE_MEDIA=false`. Its acceptance state is database, Redis, and
OpenWA `up` with media reported as `disabled`. The full product deployment keeps
its separate media-readiness requirement.

Destroying only `openwa-bootstrap-secrets` creates another API key. For a clean
reset, stop the stack and remove both `openwa-data` and
`openwa-bootstrap-secrets` together. Never back up either volume into ordinary
application backups.

The live-send, 60-second throttle, disconnect fail-closed, restart persistence,
and plaintext-leak checks remain mandatory as documented in
`docs/deployment/OPENWA_OTP_MVP.md`.
