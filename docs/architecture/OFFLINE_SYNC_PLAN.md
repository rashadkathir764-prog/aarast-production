# Aarast Offline & Sync Plan

Date: 2026-06-19
Stage: Offline & Sync Plan
Status: Planning document only

## 1. Decision

Offline support is part of the product foundation and must be preserved. Do not delete or replace existing offline/sqflite/json behavior during the rebuild.

Offline behavior must distinguish local-only, pending sync, synced, failed, and server-required actions.

## 2. Current State

Current mobile includes:

- `core/offline/local_database_mobile.dart`
- `core/offline/local_database_json.dart`
- `core/offline/local_database_web.dart`
- `core/offline/offline_sync_service.dart`
- `core/offline/sync_queue.dart`
- offline status widgets.

The app already has cache/sync concepts. The product rules need to be made explicit before deeper implementation.

## 3. Works Offline

Allowed offline or cached behavior:

- View cached/current local plan.
- View cached dashboard summary.
- Complete guest onboarding.
- Create local guest plan.
- Add local task draft.
- Add local expense draft.
- Add local guest draft.
- View cached budget/debt/task/guest/provider data.
- Favorite provider locally only if sync queue supports it.

## 4. Requires Online

Must require online/account:

- Register/login/OTP.
- Cloud migration.
- Share plan.
- Invite member.
- Send quote request.
- Accept quote/offer.
- Provider application.
- Provider service/package management.
- Push token registration.
- Server notification read/write if not queue-supported.

## 5. Sync States

Required states:

- `local_only`
- `pending_sync`
- `syncing`
- `synced`
- `sync_failed`
- `needs_review`

UI must show these states clearly for records that can be local.

## 6. Guest Migration

Guest local data migrates after account gate:

1. Create server plan.
2. Upload starter categories.
3. Upload starter tasks.
4. Upload approved local drafts.
5. Map local IDs to server IDs.
6. Mark synced only after server success.

Failure:

- Keep local data.
- Show retry.
- Do not duplicate without idempotency checks.

## 7. Conflict Rules

Initial rule:

- Server wins for existing server records unless local record is newer and explicitly queued.
- Local-only records create new server records.
- Conflicts that cannot be resolved become `needs_review`.

Do not implement destructive merge without a migration plan.

## 8. Domain Offline Matrix

| Domain | Read offline | Write offline | Notes |
|---|---|---|---|
| Onboarding | Yes | Yes | Local guest plan. |
| Home | Yes | No direct writes | Use cached summary. |
| Money | Yes | Draft/pending only | Must not claim cloud save. |
| Debts | Yes | Draft/pending only | Due reminders may be local later. |
| Tasks | Yes | Draft/pending only | Good first offline write candidate. |
| Guests | Yes | Draft/pending only | Selected contacts only. |
| Providers | Cached only | Favorite maybe queued | Quote requires online. |
| Sharing | Cached read only | No | Requires server. |
| Notifications | Cached read | Queue read only if supported | Push requires account. |
| Provider dashboard | Limited cached read | No | Provider ops require online. |

## 9. Acceptance Criteria

- Existing offline layer is acknowledged and protected.
- Offline-capable and online-required actions are defined.
- Sync states are defined.
- Guest migration and conflict rules are documented.
- Domain offline matrix is documented.
- No code is changed.

## 10. Risks

- Ambiguous offline success can mislead users.
- Guest migration can duplicate records.
- Conflict resolution can corrupt financial data if rushed.
- Provider quote/sharing must not be queued as if completed.

## 11. Next Implementation Notes

- Next stage: `docs/security/SECURITY_PRIVACY_PLAN.md`.
- Future implementation must add tests around offline financial/privacy behavior.

