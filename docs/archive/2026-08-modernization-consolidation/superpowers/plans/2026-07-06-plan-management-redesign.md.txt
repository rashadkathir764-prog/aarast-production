# Plan Management Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the duplicate-dashboard Plan Center with an administrative `إدارة الخطة` screen backed by real plan data.

**Architecture:** Keep the existing route and `PlanCenterScreen` public API for compatibility, but move the implementation into a focused management screen plus a pure `PlanManagementView`. Load the real `GET /wedding-plans/:id` record for editable metadata while using dashboard summary only for permission and participant counts. Preserve local guest editing through `GuestOnboardingStorage`; expose only the supported archive danger action and omit unsupported copy, export, and delete actions.

**Tech Stack:** Flutter, Provider, go_router, existing WeddingPlans API, SharedPreferences guest storage, flutter_test.

---

### Task 1: Real administrative plan model

**Files:**
- Modify: `mobile/lib/features/wedding_plans/models/wedding_plan.dart`
- Modify: `mobile/lib/features/wedding_plans/models/active_wedding_plan.dart`
- Modify: `mobile/lib/features/wedding_plans/providers/wedding_plans_provider.dart`
- Test: `mobile/test/features/wedding_plans/onboarding_dashboard_api_test.dart`

- [ ] Add failing tests proving `WeddingPlan` preserves priorities, persona, and onboarding path, updates active-plan metadata after edit, and clears an archived active plan.
- [ ] Run the focused test and confirm RED.
- [ ] Implement the minimal model/provider changes.
- [ ] Run the focused test and confirm GREEN.

### Task 2: Pure plan-management interface

**Files:**
- Create: `mobile/lib/features/wedding_plans/widgets/plan_management_view.dart`
- Create: `mobile/test/features/wedding_plans/plan_management_view_test.dart`

- [ ] Add failing 320px RTL widget tests for `إدارة الخطة`, compact identity, wedding data, location, participants and permissions, preferences, data completeness, and the final archive danger area.
- [ ] Assert the view excludes plan sections, providers/offers, daily progress, countdown, copy, export, and delete.
- [ ] Run the focused test and confirm RED because the widget does not exist.
- [ ] Implement the pure view with real values and callback-driven actions.
- [ ] Run the focused test and confirm GREEN.

### Task 3: Replace Plan Center orchestration

**Files:**
- Create: `mobile/lib/features/wedding_plans/screens/plan_management_screen.dart`
- Replace: `mobile/lib/features/wedding_plans/screens/plan_center_screen.dart`
- Modify: `mobile/test/features/wedding_plans/plan_center_truth_test.dart`

- [ ] Rewrite the truth contract first to require the compatibility export, real plan loading, structured edit fields, local draft persistence, participant permission summary, and archive-only danger action.
- [ ] Run the focused contract and confirm RED.
- [ ] Implement `PlanCenterScreen` in the new focused file and make the old path export it.
- [ ] Server edit must patch title, date, currency, structured location, and priorities; local edit must persist the equivalent draft fields.
- [ ] Archive must require confirmation, call the existing endpoint, and return to the plans list.
- [ ] Run all focused plan-management tests and confirm GREEN.

### Task 4: Verification

**Files:**
- Update generated route documentation only if the repository guard reports drift.

- [ ] Format touched Dart files.
- [ ] Run `flutter analyze` and `flutter test`.
- [ ] Run `flutter build apk --debug`.
- [ ] Run `node scripts/docs-sync.mjs --check`, `node scripts/docs-verify.mjs`, and scoped whitespace checks.

No Git operation is included because repository instructions prohibit Git-state changes unless explicitly requested.
