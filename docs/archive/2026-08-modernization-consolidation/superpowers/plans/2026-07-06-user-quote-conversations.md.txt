# User Quote Conversations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give wedding-user accounts a clear central inbox and direct conversation access from each real quote request.

**Architecture:** Add an authenticated `/conversations` route that renders the existing conversation list, and expose it from the user marketplace command card. Add a quote-scoped conversation action to each quote request tile. Make chat initialization idempotently start realtime delivery while loading REST conversations immediately, so user and provider paths share the same reliable session behavior.

**Tech Stack:** Flutter, Provider, go_router, REST, Socket.IO, flutter_test.

---

### Task 1: User conversation navigation

**Files:**
- Modify: `mobile/test/features/marketplace/super5_providers_contract_test.dart`
- Modify: `mobile/lib/core/routing/app_router.dart`
- Modify: `mobile/lib/features/marketplace/screens/provider_marketplace_screen.dart`

- [ ] **Step 1: Add failing widget and route assertions**

For an authenticated user, require `user-conversations-action` in the marketplace command card and `quote-conversation-<quoteId>` on each real quote tile. Assert they route to `/conversations` and `/quotes/<quoteId>/conversation`. Require the central route to use `ProviderAuthGate` and `ConversationListView`.

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `flutter test test/features/marketplace/super5_providers_contract_test.dart`

Expected: FAIL because the user inbox route and both actions are absent.

- [ ] **Step 3: Implement the route and actions**

Add `AppRouter.conversations = '/conversations'`, route it through `ProviderAuthGate`, add a `المحادثات` command button for authenticated account data, and add `محادثة المزوّد` to each quote tile using `AppRouter.quoteConversation(quote.id)`.

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run: `flutter test test/features/marketplace/super5_providers_contract_test.dart`

Expected: PASS.

### Task 2: User chat bootstrap

**Files:**
- Modify: `mobile/test/features/marketplace/provider_portal_chat_test.dart`
- Modify: `mobile/lib/features/chat/providers/chat_provider.dart`
- Modify: `mobile/lib/features/chat/widgets/conversation_list_view.dart`
- Modify: `mobile/lib/features/chat/screens/quote_conversation_entry_screen.dart`

- [ ] **Step 1: Add failing initialization assertions**

Require the conversation list and quote entry to initialize chat. Require repeated initialization to avoid duplicate realtime connections while still refreshing REST conversations.

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `flutter test test/features/marketplace/provider_portal_chat_test.dart`

Expected: FAIL because the user list and quote entry do not initialize realtime chat.

- [ ] **Step 3: Implement idempotent realtime bootstrap**

Start Socket.IO at most once per active `ChatProvider`, do not block REST list loading on socket readiness, and reset the realtime-start flag if connection fails so a later refresh can retry. Initialize from both `ConversationListView` and `QuoteConversationEntryScreen`.

- [ ] **Step 4: Run both focused suites**

Run: `flutter test test/features/marketplace/super5_providers_contract_test.dart test/features/marketplace/provider_portal_chat_test.dart`

Expected: PASS.

### Task 3: Mobile verification

**Files:**
- Verify touched Dart and documentation files only.

- [ ] **Step 1: Format touched Dart files**

Run `dart format` on every touched Dart file.

- [ ] **Step 2: Run static analysis and all tests**

Run: `flutter analyze` then `flutter test`.

Expected: no analyzer issues and all tests PASS.

- [ ] **Step 3: Build Android debug APK and run repository guards**

Run: `flutter build apk --debug`, `node scripts/docs-sync.mjs --check`, `node scripts/docs-verify.mjs`, and scoped whitespace checks.

Expected: all PASS and `mobile/build/app/outputs/flutter-apk/app-debug.apk` exists.

No Git operation is included because repository instructions prohibit Git-state changes unless explicitly requested.
