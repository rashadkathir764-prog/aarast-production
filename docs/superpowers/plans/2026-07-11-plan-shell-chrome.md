# Canonical Plan Shell Chrome Implementation Plan

**Status:** Implemented and guarded by source/widget tests on 2026-07-11.

> **For agentic workers:** Execute inline in the current workspace. Do not
> create a branch, worktree, commit, or push unless the user requests Git work.

**Goal:** Eliminate independent shell chrome implementations without changing
navigation behavior.

**Architecture:** Add a focused shared widget that renders the shell frame and
accepts body, active tab, navigation callbacks, and quick-add state. Keep state
and routing in the two existing shell wrappers.

**Tech Stack:** Flutter, Provider, GoRouter, Lucide Icons, flutter_test.

## Global Constraints

- Preserve RTL and Arabic copy.
- Preserve all current routes and API behavior.
- Do not change Docker or deployment files.
- Test first and keep both shells free of independent chrome.

### Task 1: Lock the shared-shell contract

**Files:**
- Modify: `mobile/test/features/wedding_plans/canonical_quick_add_actions_test.dart`

- [x] Add a source contract requiring both shell files to use
  `PlanShellChrome` and forbidding direct `Scaffold`,
  `RoyalSmartFloatingActionButton`, and `RoyalDashboardBottomNav` construction.
- [x] Run the test and confirm it fails because `PlanShellChrome` does not exist.

### Task 2: Add the canonical shell frame

**Files:**
- Create: `mobile/lib/features/shell/widgets/plan_shell_chrome.dart`
- Modify: `mobile/lib/features/wedding_plans/widgets/quick_add_actions.dart`

- [x] Implement the shared frame with explicit body, active index, navigation
  callbacks, FAB visibility, and FAB press callback.
- [x] Move the tab-to-Lucide-icon mapping into one exported function.
- [x] Run the source contract and widget tests.

### Task 3: Migrate both wrappers

**Files:**
- Modify: `mobile/lib/features/shell/main_shell.dart`
- Modify: `mobile/lib/features/shell/screens/wedding_plan_shell.dart`

- [x] Replace each direct Scaffold/chrome block with `PlanShellChrome`.
- [x] Preserve IndexedStack lifecycle, GoRouter navigation, permissions, and
  quick-add actions.
- [x] Run canonical quick-add tests, `flutter analyze`, and the full Flutter
  test suite.
