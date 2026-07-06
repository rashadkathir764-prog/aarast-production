# Provider Account Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real settings, provider-data refresh, and confirmed logout actions to the provider profile tab without mixing provider operations with the wedding-planning offline queue.

**Architecture:** Add one focused provider account-actions widget that owns loading and logout-confirmation UI while accepting callbacks for the actual operations. Wire it from `ProviderProfileTab` to the existing settings route, `ProviderDashboardProvider`, `ChatProvider`, and `AuthController` so provider and wedding-user navigation remain separate.

**Tech Stack:** Flutter, Provider, go_router, flutter_test.

---

### Task 1: Provider account-actions widget

**Files:**
- Create: `mobile/lib/features/marketplace/widgets/provider_account_actions.dart`
- Test: `mobile/test/features/marketplace/provider_account_actions_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover Arabic labels at a 320px RTL viewport, settings callback dispatch, one-at-a-time provider refresh with visible progress, and logout cancellation/confirmation.

- [ ] **Step 2: Verify the tests fail because the widget does not exist**

Run: `flutter test test/features/marketplace/provider_account_actions_test.dart`

Expected: FAIL because `ProviderAccountActions` and its source file are missing.

- [ ] **Step 3: Implement the focused widget**

Create `ProviderAccountActions` with these production callbacks:

```dart
final VoidCallback onOpenSettings;
final Future<void> Function() onSync;
final Future<void> Function() onLogout;
```

The widget must disable duplicate actions while busy, show a destructive Arabic confirmation before logout, and show a clear success/failure message for refresh.

- [ ] **Step 4: Verify the focused tests pass**

Run: `flutter test test/features/marketplace/provider_account_actions_test.dart`

Expected: PASS.

### Task 2: Provider profile integration

**Files:**
- Modify: `mobile/lib/features/marketplace/screens/provider_portal_tabs.dart`
- Modify: `mobile/test/features/marketplace/provider_portal_chat_test.dart`

- [ ] **Step 1: Extend the portal regression test**

Open the fifth provider tab and assert that `الإعدادات`, `مزامنة الآن`, and `تسجيل الخروج` render without overflow at 320px.

- [ ] **Step 2: Verify the integration assertion fails**

Run: `flutter test test/features/marketplace/provider_portal_chat_test.dart`

Expected: FAIL because the profile tab does not yet include account actions.

- [ ] **Step 3: Wire real provider actions**

Append `ProviderAccountActions` outside the profile-loaded conditional. Route settings with `context.push(AppRouter.settings)`, refresh provider dashboard and conversations with `Future.wait`, and log out through `AuthController.logout()` before routing to `AppRouter.login`.

- [ ] **Step 4: Verify focused portal tests pass**

Run: `flutter test test/features/marketplace/provider_portal_chat_test.dart test/features/marketplace/provider_account_actions_test.dart`

Expected: PASS.

### Task 3: Mobile verification

**Files:**
- Verify only.

- [ ] **Step 1: Format touched Dart files**

Run: `dart format lib/features/marketplace/screens/provider_portal_tabs.dart lib/features/marketplace/widgets/provider_account_actions.dart test/features/marketplace/provider_portal_chat_test.dart test/features/marketplace/provider_account_actions_test.dart`

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: PASS with no issues.

- [ ] **Step 3: Run all mobile tests**

Run: `flutter test`

Expected: PASS.

- [ ] **Step 4: Build the Android debug APK**

Run: `flutter build apk --debug`

Expected: PASS and produce `build/app/outputs/flutter-apk/app-debug.apk`.

No Git commit is included because repository instructions prohibit Git-state changes unless explicitly requested.
