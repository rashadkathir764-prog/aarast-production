# Aarast Mobile QA Plan

Date: 2026-07-14
Stage: Active mobile QA contract
Status: Current; local automation does not replace device or environment smoke

Source-of-truth note: this is the current mobile rebuild QA plan. The old root
`MOBILE_QA_PLAN.md` was archived during the 2026-07 docs consolidation.

## 1. Purpose

This plan defines the QA gate for the mobile product rebuild. It complements
`docs/qa/README.md` by adding coverage for guest-first onboarding, route guards,
privacy, offline sync, user/provider separation, and single-source dashboard
behavior.

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
- WeddingCost, CostPayment, PaymentSchedule, and canonical money-summary tests.
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
- Services.
- Messages.
- Profile.

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

Provider portal and conversation release gate:

- Render the five provider tabs at 320px without overflow.
- Confirm requester and provider resolve the same quote conversation.
- Confirm an unrelated account receives `403` for conversation access.
- Confirm REST message send appears through the authenticated Socket.IO room.
- Confirm unread/read, mute, block, and report behavior.
- Confirm blocked conversations reject sending.
- Confirm service images, provider logo, cover, and chat images use signed
  Aarast media URLs rather than arbitrary external attachment URLs.

Do not mark this gate PASS until the integrated modules and schema are running
against the target PostgreSQL, object-storage, and Socket.IO environment.

## 7. Dashboard Single Source QA

Repeated numbers must match across screens:

- Days remaining.
- Progress percentage.
- Total budget.
- Spent amount.
- Remaining amount.
- Confirmed cost total.
- Paid and outstanding totals.
- Due payment schedules.
- Open tasks.
- Overdue tasks.
- Guests count.
- Active providers.
- Unread notifications.

Test cases:

- Create plan with date.
- Set or explicitly leave the general budget unset.
- Add a category allocation.
- Add a cost and optional initial payment.
- Add and pay a payment schedule.
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

- General budget and category allocations.
- Costs and payment records.
- Payment schedules.
- Attachments.
- Guest contacts.
- Address/location.
- Shared member permissions.
- Provider quote details.

Required shared-member cases:

- Viewer with no `canViewMoney` permission.
- Member with task permission only.
- Member with `canViewMoney` but not `canManageMoney`.
- Owner.
- A money viewer can read the complete permitted money surface through one
  permission without split budget/payment requests failing the screen.
- View-only members never see add, edit, delete, reverse-payment, or money FAB
  actions, including through direct write routes.
- Switching to a plan whose finance load fails leaves no rows from the previous
  plan.
- Money heroes, category cards, costs, payments, and payment schedules render
  `SAR` as `ر.س` and never as `ر.ي`.

Fail if:

- Viewer sees private finance details.
- Task-only member can open money screens.
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
- Add a cost.
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
- Accepting a quote may offer a prefilled cost draft only after explicit user
  confirmation; cancelling that confirmation creates no money record.

Deferred or flagged flows:

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
- The Money root and every money sub-screen pass at 320px RTL and 1.3 text
  scale with real loading, empty, error, locked, offline, and pending states.
- User-facing money copy is limited to `الميزانية`, `التصنيف`, `التكلفة`,
  `الدفعة`, and `موعد الدفع`; removed finance vocabulary does not reappear.

This phase does not authorize visual polish before product/architecture readiness.

## 13. Manual QA Report Template

## 13. Release Configuration and Native Identity QA

Automated/local gate:

- Release rejects a missing, HTTP, local/private, credentialed, malformed, or
  otherwise unsafe API origin.
- Release rejects `AARAST_DEV_BYPASS_LOGIN_GATES=true`.
- Android Release rejects missing/placeholder signing values, missing
  keystore files, and every debug-signing fallback.
- iOS Release runs the equivalent configuration script from Xcode.
- Android adaptive/legacy launcher and splash resources compile.
- Required iOS AppIcon/LaunchImage sizes decode successfully.

External/manual gate:

- Build the AAB with the real upload key and verify its signer.
- Archive iOS on macOS using the real team and provisioning profile.
- Test HTTPS and custom-scheme invitations on physical Android and iOS devices.
- Verify deployed `assetlinks.json` and `apple-app-site-association` use the
  production identities.

Do not mark the store release gate PASS when artifact signing/certificate
verification was skipped or intentionally deferred.

## 14. Manual QA Report Template

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

## 15. Acceptance Criteria

- QA levels are defined.
- Required commands by change type are defined.
- Existing test coverage is acknowledged.
- Guest-first, route, privacy, offline, provider, notification, and visual/accessibility checks are covered.
- Manual report template is provided.
- Release configuration evidence distinguishes local automation from external
  signing, deployment, and physical-device checks.

## 16. Risks

- Static Flutter checks can pass while the post-login or guest dashboard is visibly broken.
- Route regressions can hide behind unused paths unless every nav item is tapped.
- Privacy bugs need role-specific manual checks.
- Offline bugs often appear only after restart or failed sync.

## 17. Next Implementation Notes

- Next stage should be tracked in the active frontend or release plan, not in an
  archived mobile-architecture file.
- Implementation tasks should copy the relevant QA section into their task acceptance criteria.
