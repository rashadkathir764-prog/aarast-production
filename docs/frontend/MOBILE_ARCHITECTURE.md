# Mobile Architecture

Snapshot date: 2026-07-23

## Principles

- Server/account-backed data is authoritative after login.
- Local guest state is a preview/draft path, not a fake server session.
- SQLite/offline cache is a mobile support layer, not a replacement for
  PostgreSQL.
- Repeated dashboard numbers should come from one summary source where possible.
- Route guards must distinguish no plan, guest-only, auth required, permission
  denied, provider-only, user-only, feature disabled, and missing entity states.

## Current Architecture Areas

- Routing: `mobile/lib/core/routing/app_router.dart`.
- API config: `mobile/lib/core/config/api_config.dart`.
- Offline/cache: `mobile/lib/core/offline/` and related feature repositories.
- Feature flags: `mobile/lib/core/config/app_feature_flags.dart`.
- Auth action gating: `mobile/lib/features/auth/utils/auth_action_guard.dart`.
- Session recovery: `mobile/lib/core/network/api_client.dart` and secure
  refresh storage in `mobile/lib/core/storage/`.
- Sensitive local values: SQLCipher owns structured offline/cache data, while
  dedicated OS secure-storage namespaces own tokens/database keys and the small
  cached safe-user/guest-onboarding payloads. Production wiring does not store
  those PII payloads in SharedPreferences.
- Pending registration: `PendingRegistration` exists in navigation memory only
  between OTP request and `/api/v1/auth/register/complete`; it is never persisted.
- Provider conversations: `mobile/lib/features/chat/` using a server-created
  plan/provider or account/provider identity, REST conversation/timeline pages,
  and authenticated Socket.IO delivery/recovery.

## QA Focus

- Phone-width Arabic layout.
- Guest-first onboarding.
- Protected action gates.
- Offline pending/sync states.
- Shared-member privacy states.
- Provider/user navigation separation.
- Provider portal state remains separate from the wedding-user shell.
- Quote entry performs read-only conversation lookup. The chat timeline merges
  message and quote/offer event pages, recovers durable activity after
  reconnect, and removes state immediately on permission-revoked events.
- Message sending and media upload remain online-only protected actions;
  they must not enter the wedding-planning SQLite sync queue.
