# Aarast Observability Plan

Date: 2026-06-19
Stage: Observability / Logs
Status: Planning document only

## 1. Purpose

This document defines how Aarast should observe critical product and technical flows before analytics or production monitoring are implemented.

The goal is to make failures diagnosable without exposing private wedding, financial, contact, location, or provider data.

## 2. Current Reality

Current codebase reality:

- Backend has functional notification creation/listing.
- Backend smoke tests exist for core modules.
- No general analytics SDK is visible in the mobile app.
- No centralized logging or tracing platform is visible in the inspected code.
- Mobile offline sync exposes local sync state, pending count, and last error.
- Provider quote and marketplace flows exist, but monetization/payment flows are not allowed.

## 3. Observability Principles

- Do not log raw financial amounts unless explicitly needed and approved.
- Do not log phone numbers, guest contacts, exact addresses, tokens, OTP codes, or passwords.
- Prefer IDs, types, status, counts, and timing over sensitive payloads.
- Use correlation IDs for backend request tracing later.
- Keep product analytics separate from technical error logging.
- Keep analytics implementation behind `enableAnalytics`.
- Do not add external telemetry SDKs until approved by implementation task and privacy review.

## 4. Event Naming Rules

Use lowercase snake_case.

Examples:

- `onboarding_started`
- `onboarding_completed`
- `role_selected`
- `persona_selected`
- `plan_created`
- `dashboard_loaded`
- `expense_created`
- `task_created`
- `guest_added`
- `quote_request_created`
- `quote_offer_sent`
- `notification_created`
- `notification_opened`
- `sync_failed`
- `sync_recovered`
- `auth_gate_shown`
- `provider_profile_submitted`

Every event should define:

- Event name.
- Source surface.
- Actor type.
- Plan ID if needed.
- Entity type.
- Entity ID if needed.
- Result.
- Error code if failed.
- Timestamp.
- Privacy class.

## 5. Privacy Classes

Classify observability data before implementation:

- `public_reference`: category/city/provider public listing metadata.
- `operational`: route name, screen name, feature flag state, status code.
- `private_plan`: plan ID, owner/shared role, plan status, task/debt/expense IDs.
- `sensitive_financial`: amounts, debts, installment amounts, payment-like details.
- `sensitive_contact`: phone numbers, guest/contact names, member phone.
- `sensitive_location`: exact address, street, device location.
- `secret`: tokens, OTP, passwords, refresh tokens, API keys.

Default rule: only `public_reference` and `operational` are safe for analytics. Other classes need explicit justification and minimization.

## 6. Backend Technical Logs

Backend logs should cover:

- Request start/end at high level.
- Auth failures by reason category, not credentials.
- Permission denials by module and role.
- Validation failures by field name only.
- Smoke-critical API errors.
- Notification generation failures.
- Quote request failures.
- Offline sync endpoint failures.
- Provider application status changes.

Backend logs must not include:

- Passwords or password hashes.
- OTP codes.
- Refresh tokens or access tokens.
- Raw guest/contact lists.
- Full financial payloads.
- Exact addresses unless explicitly approved for a support case.

## 7. Mobile Technical Logs

Mobile logs should cover:

- App startup phase.
- Auth restore result category.
- Route guard result.
- Offline sync state changes.
- Pending queue count.
- Local migration result.
- API failure category.
- Feature flag disabled route.

Mobile logs must not include:

- Token values.
- OTP codes.
- Full API payloads.
- Contact book data.
- Exact location.
- Raw finance values.

## 8. Product Event Matrix

| Event | Trigger | Required Fields | Forbidden Fields |
|---|---|---|---|
| `onboarding_started` | Welcome opened | actorType, appVersion | phone, token |
| `role_selected` | User chooses wedding/provider path | selectedRole | phone, name |
| `persona_selected` | Persona saved | persona | phone |
| `plan_created` | Plan create succeeds | planId, source, isGuest | budget amount, address |
| `dashboard_loaded` | Summary load succeeds | planId, cacheState, durationMs | raw summary payload |
| `expense_created` | Expense create succeeds | planId, entityId, isOfflineQueued | amount, note |
| `task_created` | Task create succeeds | planId, entityId, dueBucket | title if sensitive |
| `guest_added` | Guest add succeeds | planId, entityId, source | phone, contact name |
| `quote_request_created` | Quote request succeeds | providerId, planId, isOfflineQueued | message, budget |
| `notification_opened` | Notification deep link tapped | notificationType, sourceType | notification body |
| `sync_failed` | Sync item fails | entityType, operation, retryCount, errorCode | payloadJson |
| `auth_gate_shown` | Account gate appears | route, reason | phone |

## 9. Error Codes

Use stable error categories:

- `network_unavailable`
- `unauthenticated`
- `permission_denied`
- `validation_failed`
- `not_found`
- `feature_disabled`
- `sync_queue_failed`
- `migration_failed`
- `server_error`
- `unknown_error`

Avoid using raw exception text as analytics data.

## 10. Dashboards and Reports Later

Useful future dashboards:

- Onboarding completion/drop-off.
- Auth gate conversion.
- Plan creation success/failure.
- Dashboard load success/failure.
- Offline pending queue count.
- Sync failure rate.
- Route guard denials.
- Provider search usage.
- Quote request creation.
- Notification open rate.

These dashboards are later work and must respect `enableAnalytics`.

## 11. Support Debug Bundle Later

For user support, a future local debug bundle may include:

- App version.
- Device type.
- Last sync status.
- Pending sync count.
- Last non-sensitive error code.
- Feature flags.
- Route name where issue happened.

It must exclude:

- Tokens.
- OTP/passwords.
- Contact lists.
- Exact financial details.
- Exact addresses.

## 12. Acceptance Criteria

- Current observability reality is documented.
- Event naming and schema rules are defined.
- Privacy classes are defined.
- Backend and mobile logging boundaries are defined.
- Product event matrix is defined.
- Error code taxonomy is defined.
- Analytics remains deferred and feature-flagged.
- No code is changed.

## 13. Risks

- Logging raw payloads could expose private financial or contact data.
- Analytics before privacy review can violate user trust.
- Missing error categories can make QA failures hard to compare.
- External telemetry SDKs can add compliance and performance risk if introduced too early.

## 14. Next Implementation Notes

- Next stage: `docs/release/MOBILE_RELEASE_PLAN.md`.
- First implementation should define internal event constants and no-op recorder behind `enableAnalytics`, only after privacy review.
