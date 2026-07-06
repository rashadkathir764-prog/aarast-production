# Aarast Mobile Performance Plan

Date: 2026-06-19
Stage: Performance Plan
Status: Planning document only

## 1. Purpose

This document defines the performance expectations for the mobile rebuild before visual polish or large refactors begin.

The goal is to keep the app responsive on common Android devices while preserving offline behavior, Arabic RTL layout, and reliable financial/task/provider data.

## 2. Current Performance Reality

Current mobile patterns include:

- Provider marketplace API already accepts `page` and `limit` with a default limit of `30`.
- Marketplace provider currently reloads cities, categories, providers, and favorites together.
- Provider detail loads provider, services, packages, and reviews together.
- Home and plan dashboard providers both aggregate plan, finance, debt, task, and sharing data.
- Offline SQLite/JSON cache is used for lists and pending writes.
- Several screens use long `ListView` layouts and local `.take(...)` subsets for dashboard previews.
- Provider/package/review images can become expensive once real media is added.

## 3. Performance Budgets

Target budgets for implementation tasks:

- First meaningful screen after cold launch: under 2.5 seconds on local/dev backend target.
- Bottom-tab switch after data is cached: under 300 ms.
- Pull-to-refresh visible response: under 500 ms.
- Provider list first page: 30 items or fewer.
- Dashboard summary network calls: no duplicate calls from multiple widgets for the same plan.
- Offline cached read for a list screen: under 500 ms for normal MVP data volume.
- No full-screen blank state while cached data exists.

These are engineering targets, not release promises.

## 4. Provider Marketplace Rules

Provider browse must use:

- Server pagination.
- Stable `page` and `limit` parameters.
- Search debounce before network requests.
- Local cached fallback for offline state.
- Incremental load more instead of full reload on scroll.
- Separate loading flags for initial load, refresh, and load more.

Provider list should avoid:

- Reloading reference data on every search keystroke.
- Replacing the full list during load-more.
- Downloading full provider detail data for every list item.
- Loading high-resolution images in list rows.

## 5. Dashboard Rebuild Rules

Home and plan dashboard must not compute or fetch the same data independently after the single-source work begins.

Rules:

- One current-plan summary owner.
- One load per active plan unless explicitly refreshed.
- Use cached data first when available.
- Use partial rendering for non-critical sections.
- Keep permissions in the summary contract so hidden finance data is not fetched/rendered for unauthorized shared members.
- Avoid calling `loadDashboard` from nested widgets.

Required summary partitions:

- Plan identity/date/progress.
- Finance summary.
- Debt/installment summary.
- Task summary.
- Sharing/member summary.
- Guest summary.
- Provider/quote summary.
- Notification summary.

## 6. Offline Query Rules

Local cache should support predictable list reads.

Rules:

- Add indexes before local tables grow, especially by `planId`, `providerId`, `debtId`, `updatedAt`, and dirty/deleted flags.
- Keep `rawJson` as compatibility storage but do not rely on decoding thousands of rows in one frame.
- Limit dashboard reads to summary needs.
- Use parent filters for plan-specific lists.
- Keep pending sync count cheap.
- Do not block UI on sync queue replay.

Any local DB performance change must follow `docs/architecture/MIGRATION_PLAN.md`.

## 7. Image and Media Rules

When provider photos or attachments become real:

- Use thumbnails in lists.
- Use compressed/resized uploads.
- Lazy-load detail images.
- Cache image metadata separately from heavy binary/media content.
- Avoid rendering many full-size images in one scroll view.
- Show placeholders and retry states.
- Do not add image-heavy hero UI before media policy exists.

## 8. State and Rebuild Rules

Provider state changes should avoid broad rebuilds.

Rules:

- Split loading/submitting flags by domain where needed.
- Use immutable list replacement only at clear boundaries.
- Keep details maps keyed by ID.
- Debounce search/filter changes.
- Avoid `notifyListeners` loops around each item mutation.
- Prefer selectors/consumers around small subtrees for heavy screens.
- Do not recalculate expensive summaries in `build`.

## 9. Network Rules

Network usage should be predictable:

- Coalesce duplicate requests for the same plan/provider during one refresh cycle.
- Cache stable reference data such as cities and provider categories.
- Back off after repeated network failure.
- Avoid automatically syncing queued writes repeatedly while offline.
- Keep API response envelopes stable so cached parsing stays cheap.

## 10. Animation and Visual Rules

Visual polish must not harm basic responsiveness.

Rules:

- Avoid heavy animation on dashboard load.
- Use skeletons for loading lists.
- Keep transitions simple on low-end devices.
- Do not animate large shadows, filters, or image-heavy cards.
- Test with Arabic text and larger text scale.

## 11. Measurement Plan

For performance-affecting implementation tasks, record:

- Screen or flow measured.
- Device/browser target.
- Data volume.
- Cold vs warm cache.
- Network status.
- Commands/tests run.
- Observed issue and fix.

Suggested manual checks:

- Fresh launch to dashboard.
- Switch across all bottom tabs.
- Pull-to-refresh dashboard.
- Search provider list.
- Open provider detail.
- Open money screen with multiple categories/items.
- Open tasks with many rows.
- Turn network off and read cached screens.

## 12. Acceptance Criteria

- Provider pagination/caching rules are defined.
- Dashboard duplicate-fetch prevention is defined.
- Offline local query expectations are defined.
- Image/media performance rules are defined.
- State rebuild and network rules are defined.
- No code is changed.

## 13. Risks

- Dashboard visual polish can mask repeated network calls.
- Provider images can make browse unusable if thumbnails are not required.
- Search without debounce can overload backend and UI.
- Offline reads can become slow if all cached rows are decoded on every screen.
- Broad Provider notifications can rebuild expensive screen trees.

## 14. Next Implementation Notes

- Next stage: `docs/architecture/OBSERVABILITY_PLAN.md`.
- First performance implementation should focus on preventing duplicate dashboard loads and marketplace reload storms before adding new visuals.
