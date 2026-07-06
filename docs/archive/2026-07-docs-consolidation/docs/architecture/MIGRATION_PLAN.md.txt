# Aarast Migration Plan

Date: 2026-06-19
Stage: Migration Plan
Status: Planning document only

## 1. Scope

This document defines the migration rules for mobile local data, offline queues, and future backend/schema changes before the product rebuild changes any persisted contract.

No mobile local schema, Prisma schema, or API response contract should be changed until the affected migration path is written, tested, and linked from the implementation task.

## 2. Current Local Storage Reality

Current mobile storage includes:

- SQLite database on Android, iOS, and macOS: `aarast_offline.db`.
- JSON/shared-preferences fallback for unsupported platforms or SQLite initialization failure.
- Database version: `1`.
- Core tables:
  - `local_meta`
  - `sync_queue`
  - `current_user_profile`
  - `cached_wedding_plans`
  - `cached_plan_members`
  - `cached_tasks`
  - `cached_budget_categories`
  - `cached_budget_items`
  - `cached_debts`
  - `cached_installments`
  - `cached_provider_categories`
  - `cached_cities`
  - `cached_providers`
  - `cached_provider_services`
  - `cached_provider_packages`
  - `cached_bookings`
  - `cached_favorite_providers`
- Sync queue items store `entityType`, `operation`, `endpoint`, `method`, `payloadJson`, `status`, `retryCount`, `lastError`, `localEntityId`, `createdAt`, and `updatedAt`.
- Cache rows store `rawJson`, `dirty`, `deletedLocally`, `updatedAt`, and `syncedAt`.

## 3. Data That Must Be Protected

Migration must preserve:

- Guest draft plan data.
- Authenticated wedding plans.
- Budget categories and expense items.
- Debts and installments.
- Tasks.
- Plan members and permissions.
- Cached provider lists and favorites.
- Cached cities/provider categories.
- Pending sync queue items.
- Failed sync queue items with retry count and last error.
- Current user profile cache.
- `local_meta` values such as last sync time.

## 4. Migration Triggers

A migration plan is required when changing:

- SQLite table columns.
- `OfflineTables` names or entity mapping.
- Sync queue payload shape.
- Backend endpoint paths used by queued offline writes.
- Entity IDs or local temporary ID strategy.
- API response envelopes cached in `rawJson`.
- Prisma fields that mobile caches or sends while offline.
- Guest draft plan structure.
- Provider quote/request flow shape.
- Permission fields or visibility rules.

## 5. Required Migration Pattern

For every mobile local schema change:

1. Increase the local database version.
2. Add `onUpgrade` with explicit `oldVersion` to `newVersion` steps.
3. Keep migrations additive where possible.
4. Do not drop columns/tables while there are pending sync items.
5. Read `sync_queue` count before destructive work.
6. Backup affected local rows into a migration backup table or JSON meta value before destructive transformation.
7. Validate migrated row counts after transformation.
8. If validation fails, keep old data and surface a clear recovery message.
9. Add tests for SQLite migration and JSON fallback migration.

## 6. Pending Sync Safety

Pending queue must be handled before any destructive change:

- If pending count is greater than zero, block destructive migration.
- Safe additive migration can proceed if queued payloads remain compatible.
- Endpoint renames require a queue rewrite table mapping old endpoint to new endpoint.
- Entity type renames require a deterministic mapping in `OfflineTables.tableForEntityType`.
- Failed items must not be deleted automatically.
- The UI must say that unsynced changes need review if a migration cannot safely rewrite them.

## 7. Guest Data Migration

Guest-first data must support account creation later:

- Guest plan should have a stable local ID.
- Guest plan fields must be separable from account-only server fields.
- On signup, migration should attach local guest entities to the newly authenticated account.
- If cloud attach fails, keep guest data local and queued.
- Never discard guest budget, tasks, guests, or provider drafts after auth failure.

## 8. Backend and Prisma Migration Rules

Backend migrations must not assume mobile clients update immediately.

Rules:

- Add fields as nullable or with safe defaults first.
- Keep old response fields until mobile migration is shipped.
- Avoid endpoint removal while mobile may have queued offline writes to the old endpoint.
- Add compatibility adapters for renamed fields.
- Document any breaking API change in `API_CONTRACT.md` and the relevant blueprint.
- Run backend checks and smoke tests when backend code changes.

## 9. JSON Fallback Migration

The JSON fallback must remain compatible with SQLite migrations.

Rules:

- Use the same logical table/entity names.
- Store a local schema version in preferences/meta.
- Migrate JSON blobs before using them in providers.
- If JSON migration fails, keep the original blob under a backup key.
- Tests must cover JSON fallback because unsupported platforms use it directly.

## 10. Failure UX

Migration failure must be visible and recoverable.

Required user-facing states:

- "تعذر تحديث البيانات المحلية. بياناتك محفوظة، حاول فتح التطبيق مرة أخرى."
- "لديك تغييرات غير متزامنة. اتصل بالإنترنت قبل تحديث هذه البيانات."
- "اكتملت المزامنة، يمكنك المتابعة الآن."

Do not show raw SQLite, JSON, Prisma, or stack-trace details to users.

## 11. Test Requirements

Any implementation migration must include:

- Unit test for old database version to new version.
- Test that pending `sync_queue` items survive.
- Test that dirty cached items stay dirty.
- Test that deleted-local markers survive.
- Test for JSON fallback migration.
- Manual smoke: launch with old cache, open dashboard, open money, open tasks, open providers, then sync.

## 12. Acceptance Criteria

- Current local/offline storage is documented.
- Protected data classes are listed.
- Migration trigger rules are defined.
- Pending sync safety is defined.
- Guest data migration is defined.
- Backend compatibility rules are defined.
- Failure UX and tests are defined.
- No code is changed.

## 13. Risks

- Dropping local tables could lose offline expenses, tasks, debts, or guest drafts.
- Renaming endpoints could strand queued writes.
- Server-only migrations could break older mobile clients.
- JSON fallback can drift from SQLite if migrations are implemented in only one path.
- Silent migration failure would damage user trust.

## 14. Next Implementation Notes

- Next stage: `docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md`.
- Implementation tasks must reference this file before changing local database version, queue payload shape, or backend contracts.
