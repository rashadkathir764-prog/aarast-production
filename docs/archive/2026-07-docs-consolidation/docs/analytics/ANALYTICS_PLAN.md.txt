# Aarast Analytics Plan

Date: 2026-06-19
Stage: Analytics Plan
Status: Planning document only

## 1. Purpose

This document defines how Aarast product flows should be measurable later without implementing analytics now.

Analytics is deferred, disabled by default, and controlled by `enableAnalytics`.

## 2. Current Policy

- Do not add analytics SDKs in this phase.
- Do not send analytics events in this phase.
- Do not track raw financial, contact, address, token, OTP, or password values.
- Do design routes, states, and actions so they can be measured later.
- Follow `docs/architecture/OBSERVABILITY_PLAN.md` for privacy classes and event naming.

## 3. Core Questions To Answer Later

Analytics should help answer:

- Do users complete guest-first onboarding?
- Where do users drop off?
- Which persona/path is selected most?
- Do users create a plan after onboarding?
- Do users understand account gates?
- Are money, tasks, providers, guests, and sharing used?
- Do users hit route guard or permission blocks?
- Do offline sync failures prevent completion?
- Do provider quote requests convert from browse/detail?
- Do notifications lead users to useful actions?

Analytics should not answer questions by exposing sensitive personal data.

## 4. Funnel Definitions

### Guest Onboarding Funnel

Steps:

1. `onboarding_started`
2. `role_selected`
3. `persona_selected`
4. `location_step_completed`
5. `wedding_date_step_completed`
6. `priorities_selected`
7. `budget_step_completed`
8. `categories_selected`
9. `plan_generated`
10. `dashboard_first_seen`

Allowed fields:

- actorType.
- selectedRole.
- persona.
- stepName.
- skipped boolean.
- result.

Forbidden fields:

- Exact address.
- Phone.
- Budget amount.
- Contact data.

### Account Gate Funnel

Steps:

1. `auth_gate_shown`
2. `auth_gate_continue_signup`
3. `auth_gate_continue_login`
4. `auth_completed`
5. `guest_plan_migration_started`
6. `guest_plan_migration_completed`
7. `intended_action_resumed`

Allowed fields:

- route.
- reason.
- actionType.
- result.

Forbidden fields:

- Phone.
- OTP.
- Token.

### Dashboard Action Funnel

Steps:

1. `dashboard_loaded`
2. `next_action_seen`
3. `next_action_tapped`
4. `action_completed`

Allowed fields:

- planId.
- actionType.
- cacheState.
- durationMs.
- result.

Forbidden fields:

- Raw summary values.
- Financial amounts.
- Guest/contact details.

### Provider Funnel

Steps:

1. `provider_list_opened`
2. `provider_filter_applied`
3. `provider_detail_opened`
4. `quote_request_started`
5. `quote_request_created`

Allowed fields:

- providerId.
- categoryId.
- cityId.
- filterType.
- result.

Forbidden fields:

- User address.
- Quote message.
- Budget min/max.
- Phone number.

## 5. Domain Event Matrix

| Domain | Events Later | Safe Dimensions | Forbidden Data |
|---|---|---|---|
| Onboarding | started, step completed, completed, abandoned | role, persona, step, skipped | phone, exact address |
| Plan | generated, created, opened | planId, source, isGuest | title if user-entered sensitive text |
| Money | money opened, expense/debt created | entityType, result, offlineQueued | amount, creditor, note |
| Tasks | task created, completed, overdue opened | dueBucket, priority, result | task title if sensitive |
| Guests | guest added, guest list opened | source, countBucket | phone, name |
| Providers | list opened, detail opened, quote started | categoryId, cityId, providerId | message, exact user address |
| Sharing | invite started, permission changed | permissionType, result | member phone |
| Notifications | opened, mark read, deep link result | notificationType, sourceType | body |
| Offline | sync failed, sync recovered | entityType, operation, retryCount | payloadJson |
| Routes | guard denied, feature disabled | route, reason | user payload |

## 6. Metrics Later

Useful metrics:

- Onboarding completion rate.
- Plan generation rate.
- Account gate conversion rate.
- Guest-to-account migration success rate.
- Dashboard load failure rate.
- Money/task/guest/provider action completion rate.
- Quote request creation rate.
- Notification open rate.
- Route guard denial rate.
- Offline sync failure/recovery rate.
- Feature flag disabled route attempts.

## 7. Implementation Constraints Later

When analytics is implemented:

- Add a no-op analytics interface first.
- Keep event constants centralized.
- Validate event payloads in tests.
- Make analytics opt-in or policy-approved before enabling.
- Respect `enableAnalytics`.
- Batch and retry carefully; analytics must not block UX.
- Never queue analytics in the same critical queue as user data sync.
- Add privacy review before any provider SDK.

## 8. QA For Analytics Later

Tests should verify:

- Events are not emitted when `enableAnalytics` is false.
- No forbidden field is present in event payloads.
- Route/action names are stable.
- Offline analytics failure does not block app flow.
- Account gate events do not include phone or OTP.

## 9. Acceptance Criteria

- Analytics is explicitly deferred.
- Core funnels are defined.
- Safe and forbidden fields are documented.
- Domain event matrix is defined.
- Future metrics and implementation constraints are defined.
- No code is changed.

## 10. Risks

- Analytics can leak private financial/contact/location data if payload rules are vague.
- Early SDK addition can create compliance and performance risk.
- Measuring account gates without context can create misleading conversion pressure.
- Provider quote analytics can accidentally record sensitive message or budget content.

## 11. Next Implementation Notes

- Next stage: `docs/business/MONETIZATION_LATER.md`.
- Product flows should name actions consistently now so analytics can be added later without refactoring every screen.
