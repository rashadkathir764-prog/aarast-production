# Mobile Architecture And R9 Status

Snapshot date: 2026-08-30

This is the active Mobile-specific architecture entry point. Product behavior,
routes, offline ownership, and design remain governed by the current source and
the documents indexed in `docs/README.md`.

## Strict Feature Boundary

R9 makes Mobile's feature boundary strict. Cross-feature consumers import only
the owner-controlled `<feature>_api.dart` library. The 19 public surfaces are:

- `account_contexts_api.dart`
- `auth_api.dart`
- `catalogs_api.dart`
- `chat_api.dart`
- `finance_api.dart`
- `guests_api.dart`
- `home_api.dart`
- `marketplace_api.dart`
- `more_api.dart`
- `notifications_api.dart`
- `onboarding_api.dart`
- `settings_api.dart`
- `sharing_api.dart`
- `shell_api.dart`
- `support_api.dart`
- `tasks_api.dart`
- `wedding_day_api.dart`
- `wedding_plans_api.dart`
- `welcome_gateway_api.dart`

Only `app.dart`, `app_router.dart`, and `main.dart` are approved composition
roots. Strict R9 reports zero illegal feature edges, zero illegal root edges,
and 159 legal public records.

## Session And Local-Plan Ownership

`SafeUser` has one canonical implementation under `core/session`. Push binding
consumes nullable immutable identity data and preserves bind, unbind,
replacement, resume, and pending-notification behavior.

An unimported guest plan belongs to the installation, not to an authenticated
account. Ordinary explicit logout, restore rejection, and confirmed session
expiry must preserve it. Confirmed account deletion may clear it. Successful
migration clears it only after the server import succeeds; explicit discard
uses its double-confirmed destructive flow.

## R9 Verification

- Governance tests: 230/230 PASS.
- Strict boundary: PASS, `legal=159`.
- Full Flutter: 1164/1164 PASS on the final C5 candidate.
- SafeUser and Push lifecycle focused proof: 10/10 PASS.
- Direct C5 teardown/transition proof: 18/18 PASS; expanded session group:
  19/19 PASS.
- Android debug APK: `com.aarast.aarast_mobile`, `1.0.0+8`, SHA-256
  `917505e72b9c6697673ba6493c9cdc873b8eb58e4303a3302638904e590a7f9a`.
- Owner-selected `SM-S938B`: local plan -> synthetic login -> migration gate
  without upload/discard -> server session revocation -> two complete relaunches
  restored the same local plan. PASS.
- Live Firebase Push: `UNVERIFIED`.

No S10 testing, push, merge, deployment, remote CI, store release, or R10 is
claimed. The exact completion receipt is under `docs/superpowers/`.
