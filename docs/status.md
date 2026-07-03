# Project Status

_Maintained by /mxSave_

## Historical Audit Snapshot - 2026-06-14

- Observed branch at audit time: `main`.
- Backend, mobile, admin-web, deployment docs, smoke scripts, and Prisma schema were audited.
- Backend is implemented for auth, Wedding Financial OS, sharing, provider references, provider dashboard, and admin APIs.
- Mobile includes the core Flutter planning flows, provider marketplace screens, and SQLite offline cache/sync queue.
- Admin web includes provider approval/catalog/user flows, with several placeholder/admin-required pages still partial.
- Deployment is partial: API and `aarast.shadowgardn.com` returned HTTP 200; `aarast-admin.shadowgardn.com` returned HTTP 502.
- Historical status snapshot file: `PROJECT_STATUS.md`.
- Deployment troubleshooting file: `DEPLOYMENT_TROUBLESHOOTING.md`.

## Implemented Features

- Backend Wedding Financial OS source is broad and documented in `API_CONTRACT.md`: auth/profile, onboarding, active plan, dashboard summary, money, tasks, guests, sharing, notifications, provider references/quotes, and admin APIs.
- Backend completion smoke passed in the 2026-06-19 final report, but the 2026-06-20 audit found a local Docker runtime/source mismatch in `smoke:dashboard-summary`; rerun runtime smoke after rebuild/restart before claiming current runtime readiness.
- Dashboard Command Center redesign is present for Flutter mobile.
- Aarast Dashboard (Claude Design handoff) implemented in Flutter on 2026-06-08: custom top bar, completion donut, live countdown, budget segmented donut, mini stats, quick actions, alerts, participants, shared plans, custom bottom nav, RTL typography, real data wiring, and permission-aware cards.
- Dashboard Scaling + Navigation Fix implemented locally on 2026-06-08: `/home` uses `MainShell`, persistent bottom navigation is backed by `IndexedStack`, dashboard content scales through `AspectRatio` + `FittedBox`, and detail/create screens preserve back navigation.

## Open Items

- Rebuild/restart the local backend runtime and rerun backend smoke before treating runtime readiness as current.
- Tighten provider quote permissions, remove JWT fallback risk, decide guest read permissions, and add admin smoke coverage.
- Continue mobile rebuild work behind feature flags using `docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md` and `docs/testing/MOBILE_QA_PLAN.md`.
- Keep endpoint details in `API_CONTRACT.md`; mobile docs should link there instead of duplicating route lists.
- Existing uncommitted mobile work is present in the worktree and should be reviewed separately from this docs refresh.

## Knowledge-DB

- Project registered in mxLore as `aarast` (project_id **30**) on 2026-06-07.
- Root reference docs were migrated into mxLore; `AGENTS.md` is also present there.
- Source of truth for decisions, plans, and specs is the Knowledge-DB; see `CLAUDE.md`.
