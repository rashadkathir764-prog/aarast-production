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
- **Premium mobile rebuild** on branch `phase/mobile-premium-screens-v1` (2026-07-04). Design system: IBM Plex Sans Arabic display font, unified Lucide icon set, champagne-gold + burgundy tokens, `AarastProgressRing`. Redesigned surfaces, each with golden previews + green suite:
  - 5 main tabs (P1–P4): Dashboard (`PremiumDashboardView`), Money (`BudgetPulseHero`/`PaymentTimelineRail`), Tasks (`SmartTaskCard`/`TasksProgressHero`), Guests (`GuestMeterHero`/`SmartGuestCard`), Providers (`PremiumVendorCard`). Commits e2cfb57, 8ad6726, 0e6b6ce, f0090f7, a99066e2.
  - Shell (P5.0, 71e4eed1): `RoyalDashboardBottomNav` + FAB on Lucide, calmed gold breath, champagne active indicator.
  - Welcome gateway (P5.1, 06a327b8): Lucide icons, step indicator, removed "Dashboard"/"تجربة محلية" leaks.
  - Auth copy (P5.2, aa7c8701): gender-neutral login/otp.
  - Guest dashboard unified onto `PremiumDashboardView` via optional `notice` slot (P5.3, 4f8f5b3f).
  - Level 1 forms: create-expense (P6.0, a6640eca) + create-task (P6.1, 68428363) icons → Lucide; task categories deduped onto shared `taskCategoryIcon`.
- Language utils added: `currency_label.dart`, `plan_status_label.dart`, `notification_copy.dart`; shared `task_display.dart`/`guest_display.dart`.

## Open Items

- Rebuild/restart the local backend runtime and rerun backend smoke before treating runtime readiness as current.
- Tighten provider quote permissions, remove JWT fallback risk, decide guest read permissions, and add admin smoke coverage.
- Continue mobile rebuild work behind feature flags using `docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md` and `docs/testing/MOBILE_QA_PLAN.md`.
- Keep endpoint details in `API_CONTRACT.md`; mobile docs should link there instead of duplicating route lists.
- Existing uncommitted mobile work is present in the worktree and should be reviewed separately from this docs refresh.
- **Premium rebuild roadmap (source of truth):** [PLAN-mobile-premium-screens.md](./plans/PLAN-mobile-premium-screens.md) — git-based inventory of the 19 remaining old screens in phases (0 cleanup → أ money → ب providers → ج sharing → د settings → هـ provider-B2B). P6.2 done: `plan_center` icons only (still needs premium hero/cards).
- **Phase 0 cleanup (do first):** (1) delete dead `RoyalHomeTodayCenter` (~3600 lines, zero callers after P5.3); (2) thread active-plan currency into `create_expense_screen` (7 hardcoded «ر.ي» — wrong for SAR/USD plans); (3) decide login "نسيت كلمة المرور؟" dead link; (4) **push the 12 local commits**.

## Documentation

- **mxLore is decommissioned** — the `docs/` .md files are the sole source of truth for plans/decisions/specs. Ignore any `/mxMigrateToDb`, Knowledge-DB, or `project_id 30` references in older notes.
- Plans index: [docs/plans/index.md](./plans/index.md).
