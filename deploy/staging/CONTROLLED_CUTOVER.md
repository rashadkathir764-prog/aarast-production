# Aarast pre-launch controlled cutover

Owner-approved on 2026-10-03: Aarast has not launched publicly. Replace its old
deployment using the existing Aarast domains, ports and proxy routes. This is
an explicit `aarast-controlled-cutover` profile; `isolated` remains the default.
It permits no changes to other projects or reuse of old data or credentials.

## Fixed route contract

| Origin | Existing upstream alias | Host port |
| --- | --- | --- |
| `https://aarast-api.shadowgardn.com` | `aarast-backend-prod:3000` | loopback 8093 |
| `https://aarast-admin.shadowgardn.com` | `aarast-admin-web-prod:80` | loopback 8094 |
| `https://aarast.shadowgardn.com` | `aarast-public-site-prod:80` | loopback 8095 |
| `https://aarast-media.shadowgardn.com` | new MinIO, same media router | none |

The verified Aarast edge network is `aarast-production-ytxoik_aarast_internal`.
Traefik already joins it. Keep Traefik and its existing route files unchanged;
replace only the proven Aarast upstreams. New PostgreSQL, Redis and backups
stay on the new internal network and new project-owned volumes. Media uses
only its new volume. Never migrate the new schema into the old database.

## Source, images and integrations

Build Backend, Admin, Invite and patched OpenWA outside the server from one
clean committed candidate. Use full-SHA tags and verify OCI revision labels,
image IDs and transfer checksum. Server Compose has no build definitions.
Use `docker-compose.build.yml` only on the build machine, with
`STAGING_ROUTE_PROFILE=aarast-controlled-cutover`. Admin has no missing-origin
fallback in Staging; the invite artifact retains QA package, scheme and signing
fingerprint. These are technical Test Release identities, not a public launch.

Use base Compose + `docker-compose.phone.yml` + `docker-compose.cutover.yml`.
Use `cutover.env.example` only for non-secret approved routing values, alongside
private generated Staging values. Validate resolved JSON with
`validate-config.mjs --phone-acceptance` before running any service.
OpenWA uses `docker-compose.openwa.yml` + `docker-compose.openwa.cutover.yml`.
Its existing Aarast loopback operator port is 2786. Stop the proven old Aarast
OpenWA/rotator before reusing it, preserve their files, and transfer only the
new independently linked Test Release session. Do not run both copies of that
new session concurrently. Its 2 GiB / 1.5 CPU limit stays unchanged.

The new internal transport network is
`aarast_full_staging_openwa_test_release_transport`; Backend connects to
`http://openwa-staging.internal:2785`. Backend has only the independent
read-only transport credential and `aarast-staging-qa` Firebase credential.
OpenWA session files require the dedicated encrypted host mount. A marker file
alone is not evidence of encryption: verify the actual encrypted mount first.
Core readiness requires DB, Redis and media. OTP requires real send evidence
and device ACK. Firebase initialization is not real device Push delivery.

## Backup and rollback before cutover

1. Capture container IDs, ownership labels, mounts, networks, ports, proxy
   rules, health, restarts, available RAM and disk. Protect all non-Aarast IDs.
2. Before stopping old Aarast services, save a verified PostgreSQL custom dump,
   media file archive, and old deployment/session metadata in a private backup
   directory. Keep old volumes and database untouched. Never print credentials.
3. Create only the new project volumes/networks/private credential paths.
   Start PostgreSQL/roles, Redis, MinIO/media-init; replay the unchanged 76
   migrations and verify status and a second deploy no-op.
4. Once new dependencies are healthy, stop only the proven old Aarast UI/media
   upstreams. Start the new services with the fixed aliases/media labels.
   Verify DNS inside the edge network resolves aliases to the new containers.
5. Restore the independent OpenWA session, initialize Staging Firebase, then
   prove all four HTTPS origins and real server OTP including rejected wrong,
   expired and reused codes. Record actual RAM, OOM and restart counts.
6. If failure or existing-service degradation occurs, stop only the new
   Staging services, leaving their volumes intact. Restart the recorded old
   Aarast upstream containers and verify their routes. Never use `down -v`,
   delete old resources, prune Docker, or restart shared Traefik.

No merge to `main`, public release or APK build is part of this cutover.
Backend joins the existing Aarast edge only for its proxy route. The edge also
exports the old generic `postgres`, `redis`, and `media` aliases, so the cutover
Backend must never use those names for its dependencies. Its private network
provides `aarast-staging-postgres`, `aarast-staging-redis`, and
`aarast-staging-media`; the cutover environment uses these exact aliases and
the config/runtime guards reject ambiguous database or dependency endpoints.
Before starting Backend, resolve each unique alias on its actual network set
and compare the addresses to the new service IDs. Leave old DB/Redis networks,
data and credentials unchanged.
The first server attempt exposed a `media-init` OOM at the unchanged 128 MiB
hard limit during `mc admin user svcacct add`. Its Go runtime now uses
`GOMEMLIMIT=96MiB`, `GOMAXPROCS=1`, and `GOGC=25`; the configuration gate rejects
removal of these settings. A local test of the pinned client and real MinIO
completed initialization at an observed peak of 82,804,736 bytes, compared
with 134,217,728 bytes for the original runtime settings. Repeat initialization
and actual server cgroup evidence remain deployment gates. These settings do
not increase the hard memory/CPU limits or change the storage access policy.
After server stability is proven, signed Release APK and real phone acceptance
are separate gates covering Push, App Links, roles and journeys.
