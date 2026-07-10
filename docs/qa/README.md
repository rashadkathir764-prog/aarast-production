# QA And Testing

Snapshot date: 2026-07-05

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

For private chat media, additionally verify that a non-participant receives no
attachment metadata or signed URL, message/list responses contain no
`storageKey`, links expire after 120 seconds, and the object-store
`chat-image/` prefix rejects an unsigned GET. A member must be able to refresh
an expired link through the authenticated conversation attachment route.

## Mobile Changes

```powershell
cd D:\projects\aarast\mobile
flutter analyze
flutter test
```

Run targeted tests for touched flows and check Arabic/RTL layout at narrow phone
widths for UI work.

Session/privacy changes must include a two-account same-device regression:
logout must dispose the first account's providers before network logout
finishes, a late response must remain unreachable, plan switching must replace
plan-sensitive providers without rebuilding navigation, and an in-flight
offline item must retain user A's token rather than replay with user B's token.
Guest onboarding must also prove that an explicitly empty budget opens the
local dashboard and that a legacy saved no-budget plan is recovered.

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
