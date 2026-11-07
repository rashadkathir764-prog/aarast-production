# Scaling Runbook

Snapshot date: 2026-11-07

What one Aarast server carries, measured, and the order in which to grow it.
The measurements and their evidence are in
[RELEASE_AUDIT.md](../project/RELEASE_AUDIT.md), section 3.6.

## Current production footprint

One AWS `t3.small` in `eu-central-1` (2 vCPUs, which are 1 core with 2
threads; 2 GB of memory and 2 GB of swap) runs `deploy/aws/compose.yml`: the
backend, the admin web, the public site, Caddy for HTTPS, PostgreSQL 16,
Redis 7 and the backup sidecar. Media live on S3. WhatsApp codes go through
OpenWA on another server, over a restricted tunnel. This is one server: no
replica, no failover. Do not describe horizontal scaling, Postgres HA or a
monitoring stack as deployed.

## Measured capacity (2026-11-07)

The production image of `main` (`NODE_ENV=production`) with PostgreSQL and
Redis on the **same two cores** (`--cpuset-cpus`), with compose's own
settings and memory limits (Postgres `shared_buffers=64MB`,
`max_connections=40`, 384 MB; Redis 64 MB `noeviction`; backend 640 MB), and
the connection pool the live server gets (see below). The data: 20 accounts
with plans of real size (one of 2,000 guests, 19 of 150, 20 tasks each). The
app's mix, fixed: home summary 20%, money summary 15%, guests 15%, tasks 10%,
costs 10%, the directory 10%, my plans 10%, adding a guest 10%.

| connections | requests/s | p50 | p95 | p99 | errors |
|---|---|---|---|---|---|
| 5 | 96.5 | 43 ms | 104 ms | 130 ms | 0 / 5,797 |
| 10 | 100.8 | 96 ms | 160 ms | 192 ms | 0 / 6,056 |
| 20 | 101.7 | 190 ms | 304 ms | 381 ms | 0 / 6,115 |
| 40 | 103.7 | 364 ms | 602 ms | 709 ms | 0 / 6,264 |

With the backend held to 0.4 of a CPU, the `t3.small` baseline once its CPU
credits are spent (Postgres outside the limit): about 17 requests/s, p95
724 ms at 5 connections and 1.7 s at 20.

What limits it:

- **The CPU, through Node's single thread.** Throughput stays near 100/s
  whatever the connections; the backend uses one core and Postgres the other.
  With Postgres off the box it was 4–9% higher (104–108/s).
- **Not the connection pool.** The live database URL has no
  `connection_limit`, so Prisma 6 takes physical cores × 2 + 1 = 3 on a
  `t3.small`. 3 connections (above), and 5 or 10 with Postgres apart, all gave
  about 100/s.
- **The home summary** (`GET /wedding-plans/:id/dashboard-summary`) is the
  heaviest route: p50 116 ms against 12–46 ms for the rest, a fifth of the
  requests and about half of the CPU time. It is the first thing to make
  cheaper when capacity is needed.
- **WhatsApp codes:** 150 a day for the whole app (`OTP_GLOBAL_DAILY_LIMIT`,
  D92), so new sign-ups stop at 150 a day whatever the server can carry.

In people, assuming someone using the app sends about 4 requests a minute:
about **1,500 at the same moment** while CPU credits last, about **250** at
the baseline with about a second of waiting. A `t3.small` earns 24 credits an
hour and holds up to 576; full load spends 120 an hour, so a full balance
carries about six hours of continuous full load. Short evening peaks get the
first number as long as the day's average CPU stays under 20%.

These are an **upper bound**: this machine's cores are faster than a
`t3.small`'s, and the runs were local. Run the same mix against the real host
before any capacity claim, and never claim millions from one server.

## Growth path, cheapest first

1. **A larger instance** (`t3.medium` for twice the memory and credits, or a
   compute instance such as `c7g.large` with no credit model). One
   CloudFormation change; nothing in the code.
2. **Make the home summary cheaper**, after measuring its queries
   (`pg_stat_statements`, `EXPLAIN ANALYZE`).
3. **Move Postgres to a managed instance** (RDS), with PgBouncer once
   replicas × pool size approach `max_connections`.
4. **Two or more backend replicas behind a load balancer.** The code is
   ready for it: sessions are database rows, idempotency keys live in
   Postgres, throttle counters and Socket.IO events go through Redis, and
   every scheduled job is safe on two replicas through row locks and
   conditional updates (RA-BE-03). Socket.IO needs sticky sessions or a
   websocket-only transport.
5. **Managed Redis**, and the **official WhatsApp Business API** instead of
   OpenWA, which lifts the 150-a-day ceiling on sign-ups.

Run the load mix again after each step instead of trusting this page.

## Backup and restore

See [OPERATIONS.md](../handover/OPERATIONS.md), sections «النسخ الاحتياطي»
and «الاستعادة». In short: a daily dump kept 7 days, 4 weeks and 3 months on
the host and 30 days in the ops bucket, a dump before every deploy, rollback
and restore, and a daily disk snapshot. `deploy/aws/restore.ps1` puts a
backup back (tested end to end on a stand-in host: a million-row database in
about half a minute of downtime), and `deploy/aws/host/restore-drill.sh`
proves the newest backup restores whole without touching the live database.

## Honest limits

- Multi-server behavior has not been exercised on real infrastructure: the
  code paths are tested, a real two-replica deployment behind a load
  balancer has not been.
- During a Redis outage each process falls back to its own in-memory
  limits; that protects one replica, not a fleet.
- Restoring onto a brand-new server from a disk snapshot has not been tried.
- No CDN is in front of the admin web or the media.
