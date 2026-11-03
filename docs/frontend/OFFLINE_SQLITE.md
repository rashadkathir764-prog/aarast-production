# Aarast Mobile Offline SQLite

Snapshot date: 2026-11-04

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

- `local_meta`: small cached endpoint payloads such as summaries, timelines,
  shared plans, last sync time, the versioned catalog bootstrap, and
  district-scoped locality suggestions.
- `sync_queue`: pending offline writes with endpoint, method, payload, status, retry count, and last error.
- `current_user_profile`: safe current-user profile only; no passwords, OTP codes, or raw secrets.
- `cached_wedding_plans`: local wedding-plan list/detail cache.
- `cached_dashboard_summaries`: full plan summary cache used by Home and the
  operational Wedding Day view, including time/location, permission snapshot,
  important items, and provider previews already returned by the API.
- `cached_plan_members`: shared-member/member permission cache.
- `cached_tasks`: task/timeline task cache with dirty and deleted flags; each
  row keeps the task's checklist in its stored JSON.
- `cached_guests`: guest list cache. For a plan on the account it is a read
  copy of the last server list (kept in step with confirmed guest writes);
  for a device-only plan it holds the guests themselves. The plan's guest
  groups are kept in `local_meta` under `guest-groups:<planId>`, removed with
  the plan graph.
- `cached_budget_categories`: local budget category cache.
- `cached_costs`: category-first cost cache.
- `cached_cost_payments`: append-only actual money-out ledger cache.
- `cached_payment_schedules`: dated payment-reminder cache.
- `cached_provider_categories`: provider category reference cache.
- `cached_cities`: city reference cache.
- `cached_providers`: marketplace provider cache.
- `cached_provider_services`: provider service cache.
- `cached_provider_packages`: provider package cache.
- `cached_bookings`: quote-request/local booking-lead style cache.
- `cached_favorite_providers`: favorite-provider pending/cache state.

## Read Strategy

D85 (2026-11-04): one contract for every feature's data layer, in
`lib/core/offline/offline_contract.dart`.

- `OfflineReads.list` / `item` / `blob` / `blobList`: the server's answer is
  kept on the phone (a cache table, or a JSON blob in `local_meta` for a
  payload no table models) and served when the server is out of reach. The
  failure is measured and told to the sync service (D84), never swallowed;
  only a phone with no copy at all reports it.
- `cached*` readers return the phone's copy alone. Providers call
  `readCachedFirst` (`lib/core/offline/cached_first_load.dart`): the server
  request leaves at once, the copy shows while it is in flight, the answer
  replaces the copy, and a server out of reach keeps the copy marked stale
  instead of a spinner until the timeout or a retry screen.
- `test/core/offline/offline_contract_test.dart` counts raw API calls per
  data file and lets them only shrink. Money, tasks, plans and the
  marketplace keep a bounded number inside their own cache/queue logic.

Database schema version 9 adds `cached_plan_events`,
`cached_funding_sources` and `cached_guest_groups` (D85). Version 8 added
`cached_dashboard_summaries`. The Wedding Day
route can cold-start without a network connection from the last successful full
dashboard summary plus cached tasks. It never invents a provider phone,
permission, time, or location that was not present in those cached contracts.
Remote images are not part of this offline guarantee.

The dynamic reference bootstrap stores both its stable server `version` and
the last complete JSON payload in `local_meta`. A matching-version response
does not rewrite the payload. Network failure uses only a previously parsed
payload; corrupt JSON is removed. Money starter UI still owns a bundled
persona-safe fallback so first launch cannot become blank. District locality
lists are cached independently under a district-scoped key and never replace
the authoritative governorate/district tables.

Costs, payments, and payment schedules use separate cache tables but one domain
contract. A payment and schedule always reference one cached cost; category and
provider/party context are inherited from that cost. A schedule is never added
to paid or confirmed-cost totals until a real payment exists.

The prelaunch database upgrade intentionally drops the removed expense,
financial-commitment, financial-payment, and financial-installment caches and
their queue entity types. There are no production users whose mobile finance
data requires compatibility. Tests must cover both a fresh database and an
upgrade from the prior development schema so stale rows cannot reappear.

## Offline Write Queue

Network-failed safe writes create a local dirty row and add a `sync_queue` item.
D85 routes new ones through `OfflineWrites.queued`: the row is kept on the
phone at once (a `queued-*` id until the server names it; an edit of such a
row merges into its pending create through `PendingCreate`, a delete drops
it), and the first answer from the server sends it:

- create/update wedding plan
- create budget category
- create/update/delete or cancel wedding cost
- create cost payment or append a reversal
- create/update/delete or pay a payment schedule
- create/update/delete task
- favorite/unfavorite provider
- create/update/delete guest, guest group; the plan's invitation card (D85)
- create/update/delete plan event (D85)
- create/update/delete funding source; add, settle or remove a loan
  repayment (D85; a repayment of a loan the server has not named yet waits
  with the loan's create)
- mark a notice read, read all, archive or remove it (D85)
- mark a conversation read or muted (D85)
- the account's settings and the privacy answer (D85)

What reaches another person or the server's own authority goes through
`OfflineWrites.serverOnly` and says so with the measured cause: login,
registration, OTP, password flows, a member invite, its reminder, rights,
removal and leaving, a chat message, a block or a report, a quote request,
an offer, a booking decision, a review, task checklist steps, a phone
change, account deletion, the data export, receipt and portfolio photos.
Quote-request reads use `cached_bookings`, but a failed create is never
presented as queued or saved offline.

## Sync Behavior

The app attempts sync after auth restore/login/register, when returning to
foreground, and when the user taps `مزامنة الآن` in More. Queue items run in
dependency-safe creation order. A cost and its initial payment must replay as
one idempotent logical operation; category deletion must be rejected locally
while costs still reference it. Failures keep payloads, increment retry count,
and preserve `lastError`. Successful items are removed from the queue and clear
their pending badge.

Blocked queue items are never auto-replayed. Their status surface shows only
safe Arabic details about the affected entity, operation, reason, and retry
eligibility. It offers retry only when the item is eligible; it does not expose
unsafe edit or discard actions for blocked work.

## UI Indicators

The main shell shows a compact banner for:

- `بدون اتصال`
- `جار المزامنة`
- `تعذر الاتصال بالخادم`
- pending change count
- last sync time

Pending plan/task/cost cards show `بانتظار المزامنة`. Offline saves show:
`تم الحفظ على الجهاز، وسيتم المزامنة عند عودة الاتصال`.

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
- A missing general budget remains null offline; category allocations never
  become its fallback value.
- Shared-member permission writes and provider dashboard writes are not queued:
  they reach another person, so they say they need the server (D85).
- A participant's plan view (`plan-view`) is read from the server only: the
  access fails closed (C64).
- The provider portal keeps its own per-load offline flag, not yet unified on
  `ServerReachability`.
- Images loaded from remote URLs may not be available offline even when provider text data is cached.
