# Mobile Architecture

Snapshot date: 2026-08-11

## Principles

- Server/account-backed data is authoritative after login.
- Local guest state is a preview/draft path, not a fake server session.
- SQLite/offline cache is a mobile support layer, not a replacement for
  PostgreSQL.
- Repeated dashboard numbers should come from one summary source where possible.
- Route guards must distinguish no plan, guest-only, auth required, permission
  denied, provider-only, user-only, feature disabled, and missing entity states.

## Modular Boundary Modes

- R0 baseline mode: existing direct imports may remain but their counted set
  may only shrink.
- R9 strict mode: cross-feature imports target `<feature>_api.dart`; all
  `core/** -> features/**` imports are forbidden except route assembly under
  `core/routing/**`, which may import feature public route/screen barrels.

The routing exception is a composition-root exception, not a general permission
for core to consume feature state or models.

Dart `part`/`part of` is a compilation-unit relationship, not a boundary
escape: both files must resolve, declare each other through URI-style
directives, and remain inside the same feature/core area. Cross-area parts and
unresolved local directives fail immediately in every phase.

## Current Architecture Areas

- Routing: `mobile/lib/core/routing/app_router.dart`.
- Account-context entry: `mobile/lib/features/account_contexts/providers/account_context_controller.dart`
  and `mobile/lib/features/account_contexts/widgets/account_context_entry_gate.dart`.
- API config: `mobile/lib/core/config/api_config.dart`.
- Offline/cache: `mobile/lib/core/offline/` and related feature repositories.
- Dynamic references: `mobile/lib/features/catalogs/` loads the versioned
  public catalog bootstrap, stores the last valid payload in `local_meta`, and
  keeps hardcoded Money starter data only as a cold-start/failure fallback.
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
- Post-auth routing is a single boundary: `/home` checks the authenticated
  session, fetches live contexts, keeps the existing onboarding route for zero
  contexts, auto-selects one available context, presents a standalone
  `اختر المسار` screen for multiple contexts, and then replaces the route with
  the plan or provider dashboard. Context selection is not rendered inside a
  dashboard shell.

## QA Focus

- Phone-width Arabic layout.
- Guest-first onboarding.
- Protected action gates.
- Offline pending/sync states.
- Shared-member privacy states.
- Provider/user navigation separation.
- Published reference-catalog audience filtering for groom, bride, customer,
  and provider contexts; an invalid or empty remote Money persona falls back
  to the bundled safe catalog rather than an empty screen.
- Location entry must request governorate, then district, then typed locality
  suggestions. Area/neighborhood fields retain manual entry when the catalog
  is incomplete or offline.
- Provider portal state remains separate from the wedding-user shell.
- Quote entry performs read-only conversation lookup. The chat timeline merges
  message and quote/offer event pages, recovers durable activity after
  reconnect, and removes state immediately on permission-revoked events.
- Message sending and media upload remain online-only protected actions;
  they must not enter the wedding-planning SQLite sync queue.
