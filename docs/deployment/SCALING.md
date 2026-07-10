# Scaling Runbook

Snapshot date: 2026-07-07

How to take Aarast from one server to many, and what is already prepared
in code versus what requires real infrastructure.

## What the code already supports

- **Stateless backend**: sessions are DB-backed JWT + refresh rows,
  idempotency keys live in Postgres, uploads go to S3-compatible
  storage. Any replica can serve any request.
- **Shared rate limiting**: with `REDIS_URL` set, throttle counters are
  shared across replicas (fail-open if Redis drops — verified by
  killing Redis mid-run).
- **Shared Socket.IO delivery**: the Redis adapter propagates
  conversation events across replicas.
- **Cross-replica retry safety**: Postgres atomically reserves idempotency keys,
  binds each key to one request fingerprint, and elects one hourly expiry
  cleaner with a transaction-scoped advisory lock.
- **Graceful shutdown**: SIGTERM drains in-flight requests
  (`enableShutdownHooks`), so rolling deploys drop nothing.
- **Observability**: every instance exposes `/metrics`; the
  `deploy/monitoring` stack aggregates them.

## Measured single-instance capacity

Measured 2026-07-07 with `backend/scripts/load/load-test.js` on a
Windows dev machine (production build, `NODE_ENV=production`, local
Postgres in Docker, read-heavy authenticated mix):

| connections | throughput | p50 | p95 | p99 | errors |
|-------------|-----------|-----|-----|-----|--------|
| 50 | ~1,500 req/s | 35 ms | 56 ms | 63 ms | 0 / 45,336 |
| 150 | ~500 req/s | 114 ms | 180 ms | 6.7 s | saturated |

The knee between 50 and 150 connections is the Prisma connection pool
(default: `num_cpus * 2 + 1`). Tune with
`DATABASE_URL=...?connection_limit=30&pool_timeout=10` per replica and
keep `replicas x connection_limit` under the Postgres `max_connections`.

Server-class hardware and a tuned pool will beat these numbers; treat
them as a conservative floor. Re-run the script against every new
environment instead of trusting this table.

## Scale-out procedure

1. **Move Postgres out** to a managed instance (or dedicated VM) with
   PgBouncer in front once replicas × pool size approach
   `max_connections`.
2. **Set `REDIS_URL`** on every backend replica (already wired in the
   Dokploy compose).
3. **Add replicas**: in Dokploy raise the backend service replica
   count, or under plain compose:
   `docker compose up -d --scale backend=3` (drop the fixed
   `container_name` and host port binding; let the proxy discover
   instances).
4. **Load-balance** through the existing reverse proxy (Traefik/NPM in
   Dokploy). Socket.IO needs either sticky sessions or
   websocket-only transport; the Redis adapter handles cross-replica
   event delivery either way.
5. **Run the load test against the balanced endpoint** and watch the
   Grafana dashboard (`deploy/monitoring`) while it runs: p95, 5xx
   ratio, event-loop lag.

## Backup and restore

- Nightly `pg_dump` sidecar writes to the `aarast_postgres_backups`
  volume (retention: 7 daily / 4 weekly / 6 monthly).
- **A backup is only real once restored**: run
  `deploy/dokploy/scripts/verify-backup-restore.sh <file>` monthly and
  after schema migrations. It restores into a scratch container and
  fails on any restore error or missing core table.

## Honest limits (require real infrastructure, not code)

- Multi-server behavior has not been exercised on real infrastructure
  yet — the code paths (Redis adapter, shared throttle) are tested, but
  a real 3-replica deployment behind a real load balancer has not been.
- Postgres HA (failover, read replicas) is a hosting decision.
- A CDN in front of admin-web/media is unconfigured.
- Capacity numbers above are one dev machine, not a fleet benchmark.
