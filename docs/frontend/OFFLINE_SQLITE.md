# Aarast Mobile Offline SQLite

## Scope

SQLite is used only by the Flutter mobile app as a local cache and write queue. It does not replace backend PostgreSQL, Prisma, Docker PostgreSQL, or the React admin web app.

## Package Choice

- `sqflite_sqlcipher` 3.4: SQLCipher-backed SQLite for Android, iOS, and
  macOS. The 256-bit database password is generated with `Random.secure()` and
  stored only in the OS keystore/keychain through `flutter_secure_storage`.
- `path`: safe local database path joining.
- Existing `shared_preferences`: web, Windows, Linux, and test fallback so `flutter build web --debug` remains supported.

Drift was not used because this project does not need generated query code yet, and adding build-runner/codegen would be larger than the MVP offline layer needs.

## Local Database Location

On supported mobile platforms the encrypted database is created through the
platform database directory as:

```text
aarast_offline_secure_v1.db
```

Android, iOS, and macOS never fall back to plaintext storage when SQLCipher or
the OS keystore fails. Startup fails closed with a clear Arabic recovery screen
instead. Unsupported desktop platforms and Flutter web retain the JSON
development fallback with the same `LocalDatabase` contract; it is not the
mobile release storage path.

The pre-release plaintext `aarast_offline.db` and any legacy
`aarast_offline*` SharedPreferences cache keys are deleted before the secure
database is opened. This is an intentional destructive development migration;
there are no real user installations to preserve.

## Sensitive State Outside The Database

Production startup also injects a dedicated `flutter_secure_storage` namespace
for small PII values that do not belong in SQLite. The cached safe-user profile
and guest-onboarding draft are stored there, while SharedPreferences retains
only non-sensitive selectors and development/test fallbacks. If a legacy
profile or draft exists in SharedPreferences, it is copied into secure storage
once and the plaintext value is removed. Access and refresh tokens remain in
their separate secure token vault.

## Tables

- `local_meta`: small cached endpoint payloads such as summaries, timelines, shared plans, last sync time.
- `sync_queue`: pending offline writes with endpoint, method, payload, status, retry count, and last error.
- `current_user_profile`: safe current-user profile only; no passwords, OTP codes, or raw secrets.
- `cached_wedding_plans`: local wedding-plan list/detail cache.
- `cached_plan_members`: shared-member/member permission cache.
- `cached_tasks`: task/timeline task cache with dirty and deleted flags.
- `cached_budget_categories`: local budget category cache.
- `cached_budget_items`: expense cache.
- `cached_financial_commitments`: category-first agreed-cost cache.
- `cached_financial_payment_records`: actual money-out record cache.
- `cached_financial_installments`: commitment installment cache.
- `cached_provider_categories`: provider category reference cache.
- `cached_cities`: city reference cache.
- `cached_providers`: marketplace provider cache.
- `cached_provider_services`: provider service cache.
- `cached_provider_packages`: provider package cache.
- `cached_bookings`: quote-request/local booking-lead style cache.
- `cached_favorite_providers`: favorite-provider pending/cache state.

## Read Strategy

Feature API classes remain the boundary used by UI providers. On successful remote reads, API classes update the local cache. On network failure, they return cached rows when available and mark sync state as offline. If no cache exists, the existing Arabic error flow is preserved.

Financial commitments, payment records, and financial installments use their
own cache tables. They remain separate from the expense cache because expenses
mean actual money paid while commitments represent agreed
costs and remaining obligations.

## Offline Write Queue

Network-failed safe writes create a local dirty row and add a `sync_queue` item:

- create/update wedding plan
- create budget category
- create expense
- create/update/delete financial commitment
- create financial payment record
- create financial installment
- create/update/delete task
- favorite/unfavorite provider
- create quote request

Login, registration, OTP, password flows, provider dashboard/admin actions, and shared-member permission mutations remain online-only.

## Sync Behavior

The app attempts sync after auth restore/login/register, when returning to foreground, and when the user taps `مزامنة الآن` in More. Queue items run in creation order. Failures keep payloads, increment retry count, and preserve `lastError`. Successful items are removed from the queue and clear their pending badge.

## UI Indicators

The main shell shows a compact banner for:

- `بدون اتصال`
- `جار المزامنة`
- `تعذر الاتصال بالخادم`
- pending change count
- last sync time

Pending plan/task/expense cards show `بانتظار المزامنة`. Offline saves show: `تم الحفظ على الجهاز، وسيتم المزامنة عند عودة الاتصال`.

## Development Reset

For mobile emulator/device testing, uninstall the app or clear app data to
delete `aarast_offline_secure_v1.db` and its keystore/keychain password. For
web/test fallback, clear browser site data or reset `shared_preferences`.

## Limitations

- First login still requires internet.
- Web uses a lightweight JSON fallback, not SQLite.
- A mobile keystore/SQLCipher failure disables startup rather than silently
  writing financial or contact data without encryption.
- Conflict handling is MVP-safe and simple: local dirty data is preserved until sync succeeds.
- Shared-member permission writes and provider dashboard writes are not queued.
- Images loaded from remote URLs may not be available offline even when provider text data is cached.
