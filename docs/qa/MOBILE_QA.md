# Aarast Mobile QA Plan

Snapshot date: 2026-08-11
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

Contributor navigation must cover:

- One `مساحتي` root with no bottom navigation or hidden tab subtrees.
- Only permission-backed sections appear.
- The account action remains available in loading, success, and error states.
- `الخروج من المساحة` returns to path choice without clearing the account
  session.
- `تسجيل الخروج من الحساب` clears the selected context and account session,
  then opens login.
- The full surface remains RTL-safe and overflow-free at 320px and 1.3 text
  scale.

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
- A blocked item shows safe Arabic entity/operation/error details, never retries
  automatically, and exposes retry only when `canRetry` is true.
- A blocked item exposes no unsafe edit or discard action.
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
- Blocked work is shown as pending, silently auto-retried, or given an unsafe
  edit/discard action.

## 10. Provider and Quote QA

Visible stable flows:

- Browse providers.
- In a selected groom plan, confirm groom/shared provider categories appear
  and bride-only categories do not.
- In a selected bride plan, confirm bride/shared provider categories appear
  and groom-only categories do not.
- Change context between groom and bride plans and confirm the category filter
  follows `AccountContextController.selectedContext` with no stale selection.
- Upgrade from a build with legacy cached categories and confirm those rows are
  cleared; a category response missing either audience flag must fail closed.
- Confirm provider context can use the union of active categories when managing
  services.
- Load all 22 Yemen governorates, select `أمانة العاصمة` separately from
  `صنعاء`, and load only that governorate's districts. Repeat offline after one
  successful load to verify encrypted-cache fallback.
- Open provider detail.
- Verify a failed Marketplace favorites refresh keeps the prior successful
  favorites visible with an Arabic error and retry, rather than showing empty.
- Verify failed services, packages, or reviews keep any prior successful data;
  with no prior data, show an explicit Arabic section error and retry rather
  than an empty-state claim.
- Request quote only when authenticated and feature enabled.
- Provider dashboard only for provider path.
- Pending/change-requested/rejected/suspended provider keeps profile status and
  review note visible; active-only endpoint failures must not erase them.
- Provider workspace exit returns to path choice without clearing the account
  session; full logout still returns to login.
- Service and package edit, pause, and reactivate update real API data, and the
  provider profile shows published reviews.
- Quote-offer submit rejects blank details, blank/zero/invalid amount, uses the
  plan currency, and permits editing only while the offer remains pending.
- Admin approval/status change appears after provider sync without requiring a
  new login and creates a durable provider lifecycle notification.
- Accepting a plan-scoped quote creates one unpaid WeddingCost and refreshes
  Money; replaying acceptance must show the same cost and never a duplicate.
- The accepted quote offers `عرض التكلفة في المال`, not a second manual cost
  form, and creates no payment, payment schedule, task, or booking.

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
- First configured launch requests the Android notification permission once,
  after the first frame.
- Permission denial does not repeat the OS prompt on every launch.
- A real task assignment and chat message show generic notifications while the
  app is backgrounded and terminated.
- Tapping a push opens the account notification inbox without selecting or
  changing `AccountContextController.selectedContext`.
- Remote push is available only when both Backend capability and local Firebase
  capability are available. Missing either must fail closed for remote push,
  while supported in-app notifications remain available.

Fail if:

- A configured first launch does not request notification permission, requests
  it repeatedly, or requests it before the app renders.
- A lock-screen alert exposes task titles, sender identity, phone numbers, or
  private message text.
- A push tap selects a plan context or restores history from a previous
  context.
- Notification deep link opens a forbidden route.
- Notification opens a blank screen.
- Missing Backend or local Firebase capability is presented as a working remote
  push channel, or it disables supported in-app notifications.

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

## 13. Latest Combined Local Evidence — 2026-08-11

- PASS — `flutter analyze --no-pub`: no issues.
- PASS — `flutter test --no-pub`: 1150/1150 combined tests.
- PASS — the updated settings Golden was visually reviewed and now preserves
  the fail-closed Push state when Backend capability is absent.
- PASS — public-API debug APK build.
- OPEN — no physical-device run was performed for this 2026-08-11 working tree;
  the latest physical evidence remains the prior checkpoint below.

### Previous physical-device and release-build evidence — 2026-08-10

- PASS — `flutter analyze --no-pub`: no issues.
- PASS — `flutter test --exclude-tags golden`: 1084/1084.
- PASS — `flutter test --tags golden --concurrency=1`: 50/50 reviewed Goldens.
- PASS — `flutter test --no-pub`: 1134/1134 combined tests.
- PASS — Release Web build with the documented public HTTPS API origin.
- PASS — debug APK build with the documented public HTTPS API origin.
- PASS — the latest debug APK installed and cold-launched on Samsung SM-S938B
  at 1440x3120 and 1.15 text scale. Home, Money, Tasks, Guests, and Providers
  rendered; the post-navigation fatal/Flutter/RenderFlex/SQLite scan was clean.
- PASS — a cached owner dashboard cold-launched in airplane mode without a
  fatal, Flutter, RenderFlex, or SQLite error; connectivity was restored after
  the check.
- OPEN — physical secondary/auth/form states and offline mutation/sync recovery
  still require a complete device checklist; root-tab and offline cold-start
  smoke are not that checklist.
- BLOCKED — physical iOS: the available host is Windows.

Automated widget and offline-sync results are not a substitute for these two
physical-device gates.

### Soft Royal V2 evidence — 2026-08-10

- PASS — `flutter analyze --no-pub`.
- PASS — 1084/1084 non-Golden tests.
- PASS — 50/50 reviewed Golden tests after a full visual contact-sheet review.
- PASS — 41/41 focused contrast, native-brand, source-guard, accessibility, and
  responsive-boundary tests.
- PASS — docs sync and docs verification.
- PASS — debug APK build and data-preserving install on Samsung SM-S938B.
- PASS — focused physical Home review with the app foregrounded.
- PASS — final Home plan-moment review after the responsive height and stacked
  date/location refinement; the 320px Golden remains overflow-free.
- OPEN — exhaustive physical secondary routes, short-height forms, offline
  mutation/sync recovery, and notification receipt/tap behavior.
- BLOCKED — physical iOS on the available Windows host.

### Targeted Marketplace truth evidence — 2026-08-11

- PASS — targeted only: `flutter test test/favorite_providers_preview_test.dart test/features/marketplace/marketplace_loading_truth_test.dart test/features/marketplace/provider_details_view_test.dart --no-pub` (11 tests).
- This evidence covers retained Marketplace data, explicit retry states, and
  the affected favorites/details widgets. It is not a full Flutter suite,
  device smoke, Backend integration, or release claim.

## 14. Release Configuration and Native Identity QA

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

## 15. Manual QA Report Template

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

## 16. Acceptance Criteria

- QA levels are defined.
- Required commands by change type are defined.
- Existing test coverage is acknowledged.
- Guest-first, route, privacy, offline, provider, notification, and visual/accessibility checks are covered.
- Manual report template is provided.
- Release configuration evidence distinguishes local automation from external
  signing, deployment, and physical-device checks.

## 17. Risks

- Static Flutter checks can pass while the post-login or guest dashboard is visibly broken.
- Route regressions can hide behind unused paths unless every nav item is tapped.
- Privacy bugs need role-specific manual checks.
- Offline bugs often appear only after restart or failed sync.

## 18. Next Implementation Notes

- Next stage should be tracked in the active frontend or release plan, not in an
  archived mobile-architecture file.
- Implementation tasks should copy the relevant QA section into their task acceptance criteria.
