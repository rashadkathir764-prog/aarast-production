# Aarast Feature Flags Plan

Date: 2026-06-19
Stage: Feature Flags
Status: Planning document only

## 1. Decision

Any incomplete or risky feature must be hidden behind a feature flag before it appears in user-facing navigation.

## 2. Required Flags

- `enableProviderMode`
- `enableProviderQuotes`
- `enableGuestContacts`
- `enableOfflineSync`
- `enableAIHelper`
- `enablePushNotifications`
- `enableSubscriptions`
- `enableMaps`
- `enableAnalytics`
- `enablePlanProviderLinking`
- `enableQuoteOffers`
- `enableSupportDisputes`

## 3. Default Policy

Default to disabled for:

- AI.
- Subscriptions.
- Payments/deposits.
- Maps.
- Push.
- Analytics.
- Quote offers/accepted provider integration until data model exists.

Default can be enabled for:

- Existing stable MVP features already in production-ready scope.
- Internal/dev-only surfaces with clear labels.

## 4. Flag Sources

Possible sources:

- Local constants for early mobile development.
- Remote config later.
- Backend feature flag endpoint later.

Do not add backend feature-flag system until implementation plan requires it.

## 5. UX Behavior

If disabled:

- Hide entry point where possible.
- Or show internal/dev-only message.
- Never tease payment/AI/subscription to real users.

## 6. Acceptance Criteria

- Required flags are listed.
- Default policy is documented.
- Disabled UX behavior is documented.
- No code is changed.

## 7. Risks

- Visible incomplete features reduce trust.
- Flags without QA matrix can hide broken routes.
- Remote config too early adds operational complexity.

## 8. Next Implementation Notes

- Next stage: `docs/architecture/MIGRATION_PLAN.md`.
