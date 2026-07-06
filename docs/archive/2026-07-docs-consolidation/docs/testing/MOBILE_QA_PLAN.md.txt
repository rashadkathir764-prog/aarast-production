# Aarast Mobile QA Plan

Date: 2026-06-19
Stage: Testing & QA Plan
Status: Planning document only

Source-of-truth note: this is the current mobile rebuild QA plan. The root `MOBILE_QA_PLAN.md` remains a legacy MVP manual checklist and should not be expanded with rebuild coverage unless explicitly reopened.

## 1. Purpose

This plan defines the QA gate for the mobile product rebuild. It complements the existing root `MOBILE_QA_PLAN.md`, `MANUAL_QA_REPORT.md`, `TESTING_PLAN.md`, and `SMOKE_TESTS.md` by adding coverage for guest-first onboarding, route guards, privacy, offline sync, user/provider separation, and single-source dashboard behavior.

## 2. QA Levels

Use these levels in order:

1. Static scope check.
2. Automated unit/provider/widget tests.
3. Route and guard regression tests.
4. Offline/sync tests.
5. Manual product smoke.
6. Release candidate QA.

Docs-only changes normally require only `git diff --check`.

## 3. Required Commands By Change Type

Docs-only:

- `git diff --check`

Mobile code:

- `dart format` on touched Dart files.
- `flutter analyze`
- `flutter test`
- Targeted widget/provider tests for the changed flow.

Backend code:

- `npm --prefix backend run check`
- `npm --prefix backend run smoke:all`

Backend plus mobile:

- Run both mobile and backend gates.
- Add at least one manual smoke covering the integration point.

## 4. Existing Mobile Automated Coverage

Current test areas include:

- Startup widget test.
- Home dashboard layout and preview tests.
- Offline sync service tests.
- JSON local database tests.
- Offline local mapper tests.
- Debt data tests.
- Yemeni phone normalizer tests.

New implementation work should extend these areas instead of replacing them blindly.

## 5. Guest-First Onboarding QA

Automated coverage:

- Welcome screen opens without login.
- Choose Path separates wedding-user and provider flows.
- Persona is stored for Arabic copy selection.
- Location setup can continue without device permission.
- Wedding date creates valid timeline input.
- Budget setup can be skipped.
- Suggested categories do not require account.
- Generated dashboard receives a local guest draft.

Manual smoke:

- Fresh install.
- Complete guest onboarding.
- Reach dashboard without account.
- Close app and reopen.
- Confirm guest draft still exists.
- Trigger account-required action and verify account gate appears.

Fail if:

- Login is forced on first launch.
- Provider CTA appears repeatedly inside normal user pages.
- Guest draft disappears after restart.

## 6. Navigation and Route Guard QA

User bottom navigation must cover:

- Home.
- Money.
- Tasks.
- Providers.
- More.

Provider bottom navigation must cover:

- Home.
- Requests.
- Offers.
- Profile.
- More.

Guard cases:

- No plan selected.
- Guest-only local plan.
- Auth required.
- Permission denied.
- Provider-only.
- User-only.
- Feature disabled.
- Missing entity.

Manual route smoke:

- Tap every bottom-nav item.
- Tap every quick-add item.
- Open every route reachable from More.
- Open a notification deep link.
- Open a stale/deleted plan link.
- Open provider route while in user mode.
- Open user plan route while in provider mode.

Fail if:

- Any route opens blank UI.
- Any route opens 404/coming-soon when it should be a core flow.
- Any disabled feature looks available to real users.

## 7. Dashboard Single Source QA

Repeated numbers must match across screens:

- Days remaining.
- Progress percentage.
- Total budget.
- Spent amount.
- Remaining amount.
- Debts total.
- Due installments.
- Open tasks.
- Overdue tasks.
- Guests count.
- Active providers.
- Unread notifications.

Test cases:

- Create plan with date.
- Add expense.
- Add debt.
- Add installment.
- Add task due today.
- Add overdue task.
- Add guest.
- Refresh Home and plan dashboard.
- Confirm numbers match.

Fail if:

- Home and My Plans show different days/progress for the same plan.
- Money total differs from dashboard total.
- Offline cached summary is not marked stale or pending when relevant.

## 8. Privacy and Permissions QA

Sensitive areas:

- Expenses.
- Debts.
- Installments.
- Attachments.
- Guest contacts.
- Address/location.
- Shared member permissions.
- Provider quote details.

Required shared-member cases:

- Viewer with no finance permission.
- Member with task permission only.
- Member with expense read permission.
- Member with debt read permission.
- Owner.

Fail if:

- Viewer sees private finance details.
- Task-only member can open money/debt screens.
- Guest contacts are uploaded without explicit selection.
- Provider sees private plan data not needed for quote.

## 9. Offline and Sync QA

Automated coverage should include:

- Pending sync queue survives app restart.
- Dirty cached item stays dirty until server sync succeeds.
- Failed sync item keeps retry count and error.
- JSON fallback behavior stays compatible.

Manual smoke:

- Open plan online.
- Turn network off.
- Add expense.
- Add task.
- Add guest if supported offline.
- Confirm pending-sync indicator.
- Restart app.
- Confirm pending local data remains.
- Turn network on.
- Trigger sync.
- Confirm queued items resolve or show clear failure.

Fail if:

- App claims cloud success while offline.
- Pending queue is lost.
- Offline banner/status is missing on affected screens.

## 10. Provider and Quote QA

Visible stable flows:

- Browse providers.
- Open provider detail.
- Request quote only when authenticated and feature enabled.
- Provider dashboard only for provider path.

Deferred or flagged flows:

- Quote acceptance.
- Provider-in-plan conversion.
- Payments/deposits.
- Confirmed bookings.
- Subscriptions.

Fail if:

- Payment, deposit, subscription, or confirmed booking appears as active MVP behavior.
- Normal user can enter provider dashboard without provider state.
- Quote request can be sent without required plan/location context when the flow requires it.

## 11. Notifications QA

Cases:

- Notification list empty state.
- Unread count.
- Mark one as read.
- Mark all as read.
- Delete notification if supported.
- Deep link to task, quote, plan, money, or safe fallback.
- Push permission prompt timing.

Fail if:

- Push permission appears at first app launch.
- Notification deep link opens a forbidden route.
- Notification opens a blank screen.

## 12. Visual and Accessibility QA

Before visual polish is accepted:

- RTL layout is stable.
- Arabic text does not overflow.
- Tap targets are reachable.
- Loading, empty, error, locked, offline, and pending states are visible.
- Text scale does not break core screens.
- Low-end device scrolling stays usable.

This phase does not authorize visual polish before product/architecture readiness.

## 13. Manual QA Report Template

```text
QA Date:
Tester:
Branch:
Commit:
Backend URL:
Flutter target:
Device/browser:

Commands:
- PASS/FAIL - command

Manual Flows:
- PASS/FAIL - flow

Privacy Checks:
- PASS/FAIL - check

Offline Checks:
- PASS/FAIL - check

Route Checks:
- PASS/FAIL - check

Known Issues:
-

Overall Verdict:
PASS / FAIL / BLOCKED
```

## 14. Acceptance Criteria

- QA levels are defined.
- Required commands by change type are defined.
- Existing test coverage is acknowledged.
- Guest-first, route, privacy, offline, provider, notification, and visual/accessibility checks are covered.
- Manual report template is provided.
- No code is changed.

## 15. Risks

- Static Flutter checks can pass while the post-login or guest dashboard is visibly broken.
- Route regressions can hide behind unused paths unless every nav item is tapped.
- Privacy bugs need role-specific manual checks.
- Offline bugs often appear only after restart or failed sync.

## 16. Next Implementation Notes

- Next stage: `docs/mobile-architecture/PERFORMANCE_PLAN.md`.
- Implementation tasks should copy the relevant QA section into their task acceptance criteria.
