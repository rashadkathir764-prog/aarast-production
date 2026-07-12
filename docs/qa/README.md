# QA And Testing

Snapshot date: 2026-07-11

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
npm run smoke:financial-ledger-concurrency
npm run smoke:all
```

For temporary OpenWA OTP work, additionally run the OpenWA channel, durable
quota, readiness, registration, admin MFA, and password-reset source tests.
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

OTP UI changes must prove the resend action remains actually disabled for the
full 60-second server cooldown and becomes enabled at the same boundary.

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
