# QA And Testing

Snapshot date: 2026-07-17

This folder owns current testing expectations. Older QA files were archived
during the 2026-07 docs consolidation.

## Docs-Only Changes

```powershell
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

The sync check detects generated reference drift. The docs verifier checks
documented routes, migration references, snapshot freshness, and Markdown
links. `git diff --check` catches whitespace errors. The active source list and
archive rules are owned by `docs/README.md`.

## Backend Changes

```powershell
cd D:\projects\aarast\backend
npm run check
npm run build
npm test
npm run smoke:auth-verification
npm run smoke:sharing-security
npm run smoke:marketplace
npm run smoke:provider-dashboard
npm run smoke:private-chat-media
npm run smoke:money-apis
npm run smoke:financial-ledger-concurrency
npm run smoke:all
```

Money-domain changes additionally fail unless tests prove:

- live schema, controllers, and mobile source contain no removed finance model,
  route, or cache contract;
- fresh and upgraded databases contain only BudgetCategory, WeddingCost,
  CostPayment, and PaymentSchedule for the money domain;
- every cost has one valid category and at most one party mode (provider or
  external party);
- initial payment creation is atomic, ordinary payment cannot exceed the
  outstanding cost, reversal is append-only and unique, and concurrent
  schedule-payment requests create one payment only;
- WeddingCost has no due-date field across schema, DTO, response, mobile cache,
  offline import, and API examples; `PaymentSchedule.dueDate` is the only
  payment-reminder date;
- a pending schedule remains a non-reserving reminder: it never changes totals,
  reserves outstanding balance, or blocks a direct payment;
- each schedule amount is independently no greater than the row-locked
  outstanding cost on create/update; other pending reminders are not summed as
  reservations, and any payment that completes a cost cancels all remaining
  pending reminders;
- a null general budget stays null and category allocations never replace it;
- the atomic money-budget route accepts `categories: []` for budget-first setup
  without creating a placeholder category and rejects any positive allocation
  when `totalBudget` is null; the mobile form prevents an entirely empty no-op
  write before calling that route;
- schedule warnings expose counts with `amount: null`, so overlapping reminders
  are never summed or presented as debt;
- direct SQL insert/update of one pending schedule above the current outstanding
  cost is rejected, while overlapping reminders within that per-row limit are
  allowed and remain non-reserving;
- `canViewMoney` and `canManageMoney` fail closed across summary, detail, direct
  route, dashboard, notification, and sharing flows;
- removed finance endpoints return `404` with an authenticated request.

For temporary OpenWA OTP work, additionally run the OpenWA channel, durable
quota, readiness, registration, admin MFA, admin password-recovery, and
application password-reset tests. Auth gates must prove legacy unverified-row
claiming, separate app/admin hashes, stable post-proof error codes, neutral
admin recovery responses and transport timing, persisted session scopes,
separate login throttle realms, private `ADMIN_LOGIN` OTP binding, a 72-byte
bcrypt boundary, one-time concurrent challenge consumption, protected admin
identity deletion/profile updates, and no raw phone or challenge token
persistence.
The release gate is not complete until the pinned hardened fork itself passes
its tests and a real QR-linked session proves the sent OTP marker is absent
from message history, database rows, logs, hooks, and webhooks. A mocked Aarast
adapter test is necessary but not sufficient.

After QR linking, run `npm run smoke:openwa-otp` only with a dedicated test
recipient and the explicit `OPENWA_SMOKE_CONFIRM=I_ACCEPT_REAL_WHATSAPP_SEND`
guard. The smoke performs one real send and fails if its unique marker appears
in the OpenWA message-history API. Database/log/hook/webhook inspection remains
a separate manual gate because the public history response cannot prove those
stores are empty.

Participant invitation tests must also prove that create/reissue uses only the
hardened transient endpoint, the WhatsApp text contains one private HTTPS link
and no plan details, delivery uncertainty is not reported as success, a
token-phone mismatch sends no OTP, and a matching phone can verify, accept, and
open the contributor plan without creating an owner plan.

For private chat media, additionally verify that a non-participant receives no
attachment metadata or signed URL, message/list responses contain no
`storageKey`, links expire after 120 seconds, and the object-store
`chat-image/` prefix rejects an unsigned GET. A member must be able to refresh
an expired link through the authenticated conversation attachment route. The
media smoke must perform a real signed upload with the returned
`If-None-Match: *` header, call `/api/v1/media/uploads/verify`, and persist only the
verified reference. Source tests must exercise full decode/re-encode,
appended-payload removal, invalid image rejection, dimension/pixel bounds, and
conditional replacement behavior.
The HTTP smoke must also prove that presigning creates a durable account-owned
upload ticket, verification leaves it unconsumed, and persisting the provider
image or chat attachment marks it consumed. Source tests must cover the rolling
per-account count/byte quota, cross-replica advisory lock, expired/stalled
ticket cleanup, and retry retention when object storage is unavailable.

The root Docker Compose environment includes MinIO-compatible object storage
and bucket initialization for local media smoke. `/ready` must report media as
`up`; a run where media is `disabled` is not evidence for the media release
gate.

## Mobile Changes

```powershell
cd D:\projects\aarast\mobile
flutter analyze
flutter test
```

Run targeted tests for touched flows and check Arabic/RTL layout at narrow phone
widths for UI work.

The complete Money gate covers the real root and every sub-screen at 320px RTL
with 1.3 text scale: budget management, category create/edit/detail, cost
list/create/edit/detail, payment create/detail/reversal, and payment-schedule
create/detail/pay. It must also cover first use, unset budget, empty, healthy,
near-limit, over-budget, read-only, denied, offline, pending, error/retry,
cancelled cost, paid cost, and reversed payment states. Goldens must render the
actual routed screens, not only isolated hero widgets.

Mobile contract tests must prove that payment entry inherits category and
provider/party from its cost, inline category creation returns to the cost form
selected, accepted quote context is only applied after confirmation, access
revocation clears cached rows, plan switching cannot leak prior money, and the
offline queue preserves dependency and idempotency rules.

OTP UI changes must prove the resend action remains actually disabled for the
full 60-second server cooldown and becomes enabled at the same boundary.
OpenWA tests must also distinguish definitive delivery rejection from an
ambiguous post-send outcome: an ambiguous result keeps the OTP active, returns
no code in the HTTP response, advances the mobile UI to code entry, and shows a
safe notice instead of a false unavailable error.

Session/privacy changes must include a two-account same-device regression:
logout must dispose the first account's providers before network logout
finishes, a late response must remain unreachable, plan switching must replace
plan-sensitive providers without rebuilding navigation, and an in-flight
offline item must retain user A's token rather than replay with user B's token.
Guest onboarding must also prove that an explicitly empty budget opens the
local dashboard and that a legacy saved no-budget plan is recovered.
Secure-storage tests must prove that production wiring never leaves the cached
safe-user profile or guest-onboarding draft in SharedPreferences and that a
legacy plaintext value migrates once and is removed.

## Admin Web Changes

```powershell
cd D:\projects\aarast\admin-web
npm run build
npm run smoke:admin-runtime
```

Admin runtime smoke requires a running backend.

## Reporting

Report every verification as PASS, FAIL, or BLOCKED. Do not claim a check
passed unless it was actually run.
