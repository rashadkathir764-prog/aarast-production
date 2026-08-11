# Contributor History And Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver backend-enforced contributor isolation, immutable frozen contribution history, correct permission errors, safe self-leave, responsive contributor UI, and shared account deletion.

**Execution receipt (2026-08-03):** Tasks 1-11 and the local/isolated parts of
Task 12 are implemented and verified. The checkbox list below remains the
original execution sequence, not a current release-status ledger. Active status
is recorded in `docs/project/STATUS.md` and `docs/qa/README.md`. Android/iOS
physical-device acceptance, native SQLCipher v6-to-v7 rehearsal, repeatable CI
Firebase configuration, iOS archive, and Staging/Production rollout remain
open; this plan must not be read as release approval.

**Architecture:** Add an append-only contribution-history subsystem with durable plan scopes and membership tenures. Domain writes append privacy-safe snapshots in the same database transaction, domain reads use a centralized contributor scope policy, permission revocation preserves the action-time snapshots already recorded and appends only a deterministic section boundary before stored flags are disabled, and Flutter consumes only filtered live/history APIs.

**Tech Stack:** NestJS 11, TypeScript 5.9, Prisma 6, PostgreSQL, Flutter/Dart, Provider, Dio, SQLCipher SQLite.

## Global Constraints

- Stored `SharedMember` flags are the runtime authority; roles seed defaults only.
- No Flutter-only filtering, compatibility layer, silent fallback, or attribution guess.
- Frozen snapshots never join to live entities after revocation.
- Snapshots contain no phone, email, token, payload, chat text, notes, payment method, attachment, or private provider contact.
- `TASK_PERMISSION_REVOKED` is HTTP 403 with `لم تعد لديك صلاحية لتنفيذ هذه المهمة`.
- Self-leave is independent from logout/account deletion and retains immutable plan history.
- Existing unprovable history remains explicitly unknown.
- Existing tests may be updated only when the documented product contract intentionally changes; no test is skipped or weakened.
- Do not commit, push, branch, reset, or create a worktree in this execution unless the user separately requests Git work.

---

### Task 1: Characterization Tests And Contract Red Gate

**Files:**
- Create: `backend/test/contributor-permission-authority.test.ts`
- Create: `backend/test/contributor-data-scope.test.ts`
- Create: `backend/test/contribution-history-freeze.test.ts`
- Create: `backend/test/sharing-self-leave.test.ts`
- Modify: `backend/test/task-responsibility.test.ts`
- Modify: `mobile/test/features/wedding_plans/contributor_workspace_view_test.dart`
- Modify: `mobile/test/features/wedding_plans/contributor_account_actions_test.dart`

**Produces:** Failing tests for stored-flag precedence, two-contributor isolation, frozen snapshots, Arabic 403, responsive add controls, self-leave, and shared deletion UI.

- [ ] Write tests that keep role `CONTRIBUTOR` while setting every stored section flag false and assert effective false.
- [ ] Write owner + contributor A + contributor B fixtures and assert A never receives B's task/guest/money/provider/member rows.
- [ ] Write grant -> contribute -> revoke -> owner update tests and assert the history JSON/hash stays byte-for-byte unchanged.
- [ ] Write self-leave transaction/idempotency/re-invite tests.
- [ ] Write Flutter tests that reject `FloatingActionButton`, exercise 320px/textScale 2.0, and distinguish leave/logout/delete.
- [ ] Run focused tests and record their expected failures before production changes.

### Task 2: Prisma History Schema And Migration

**Files:**
- Modify: `backend/prisma/schema.prisma`
- Create: `backend/prisma/migrations/20260802090000_add_contributor_history/migration.sql`
- Create: `backend/test/contribution-history-migration.test.ts`

**Produces:** `ContributorHistoryScope`, `ContributorTenure`, immutable `ContributionEvent`, enums, `SharedMember.authorityVersion`, indexes, checks, trigger, and evidence-only backfill.

- [ ] Add schema relations/enums with nullable user/plan links only on mutable scope/tenure rows.
- [ ] Add unique active-tenure and event dedupe indexes plus JSON-object/hash/check constraints.
- [ ] Add a PostgreSQL trigger rejecting `UPDATE`/`DELETE` on `ContributionEvent`.
- [ ] Backfill scopes/current tenures and only current task assignment and plan quote creator evidence.
- [ ] Assert row counts and leave all unsupported legacy attribution absent.
- [ ] Generate Prisma client and deploy migration to an isolated upgraded database.

### Task 3: Contribution Core, Snapshot Privacy, And History API

**Files:**
- Create: `backend/src/contribution-history/contribution-history.module.ts`
- Create: `backend/src/contribution-history/contribution-history.service.ts`
- Create: `backend/src/contribution-history/contributor-scope.service.ts`
- Create: `backend/src/contribution-history/contribution-snapshot.builder.ts`
- Create: `backend/src/contribution-history/contribution-history.controller.ts`
- Create: `backend/src/contribution-history/dto/list-contributions.dto.ts`
- Create: `backend/src/contribution-history/contribution-history.contracts.ts`
- Modify: `backend/src/app.module.ts`
- Create: `backend/test/contribution-history-privacy.test.ts`
- Create: `backend/test/contribution-history-dedupe.test.ts`

**Produces:** `recordInTransaction`, tenure/scope lifecycle, section/entity scope IDs, revocation freezing, owner/current-member history listing and summary, and snapshot validators.

- [ ] Test every snapshot type against allowlists and forbidden key/value patterns.
- [ ] Test deterministic dedupe replay versus conflicting fingerprints.
- [ ] Implement canonical JSON hashing and append-only event recording.
- [ ] Implement current-member history/summary endpoints without live entity joins.
- [ ] Implement scope ID queries used by domain services and dashboard.
- [ ] Run privacy/dedupe/API tests to green.

### Task 4: Stored Permission Authority And Atomic Revocation

**Files:**
- Modify: `backend/src/sharing/permission.service.ts`
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify: `backend/src/sharing/sharing.module.ts`
- Modify: `backend/src/contexts/contexts.service.ts`
- Modify: `backend/src/sharing/plan-permissions.ts`
- Modify: `backend/test/plan-permissions.test.ts`
- Modify: `backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts`

**Produces:** Stored-flag-only runtime checks, authority version increments, deterministic revocation boundary markers before flag changes, and stable permission errors.

- [ ] Keep role defaults only in invitation materialization; direct member creation stores omitted authorization flags as `false`, and later role changes preserve omitted stored flags and never restore an explicitly revoked permission.
- [ ] Return stored flags from every runtime `can*` method for non-owners.
- [ ] Preserve existing action-time snapshots and append only a deterministic section boundary inside the membership update transaction for true-to-false live-read changes; never query or re-snapshot live entities during revocation.
- [ ] Increment and expose `authorityVersion`.
- [ ] Return 403 `TASK_PERMISSION_REVOKED` for an existing member whose task permission is false while retaining 404 for outsiders.
- [ ] Run permission and concurrency tests to green.

### Task 5: Task Isolation And Contribution Events

**Files:**
- Modify: `backend/src/tasks/tasks.service.ts`
- Modify: `backend/src/tasks/tasks.module.ts`
- Modify: `backend/src/tasks/tasks.controller.ts`
- Modify: `backend/src/tasks/tasks.contracts.ts` or existing response interfaces
- Modify: `backend/src/timeline/timeline.service.ts`
- Modify: `backend/src/notifications/notifications.service.ts`
- Modify: `backend/test/task-responsibility.test.ts`
- Modify: `backend/scripts/smoke/tasks-apis-smoke.js`

**Produces:** Scoped task list/detail/summary/timeline, assignment/create/complete snapshots, per-task server capabilities, correct Arabic denial, and assignee-only notifications.

- [ ] Record create/assignment/completion/reopen/checklist actions transactionally without duplicate composite events.
- [ ] Filter live tasks by current assignee or qualifying creator/completer events.
- [ ] Reject mutations on another contributor's tasks.
- [ ] Show success only after the task mutation commits.
- [ ] Limit task notifications to owners/authorized managers and the current assignee.
- [ ] Run task isolation/API/timeline/notification tests.

### Task 6: Guest Isolation And Contribution Events

**Files:**
- Modify: `backend/src/guests/guests.service.ts`
- Modify: `backend/src/guests/guests.module.ts`
- Modify: `backend/test/quote-guest-visibility.test.ts`
- Modify: `backend/scripts/smoke/guests-apis-smoke.js`

**Produces:** Contributor-scoped guests/groups and frozen create/update/status snapshots with no phone or notes.

- [ ] Record guest/group single and bulk actions in their existing transactions.
- [ ] Filter list/detail/summary/group reads before serialization.
- [ ] Reject access/mutation of another contributor's guest rows.
- [ ] Verify snapshots omit contact and notes.
- [ ] Run guest tests and smoke.

### Task 7: Money Isolation And Contribution Events

**Files:**
- Modify: `backend/src/money/money-budget.service.ts`
- Modify: `backend/src/budget-categories/budget-categories.service.ts`
- Modify: `backend/src/budget-categories/budget-categories.module.ts`
- Modify: `backend/src/wedding-costs/wedding-costs.service.ts`
- Modify: `backend/src/wedding-costs/wedding-costs.module.ts`
- Modify: relevant backend money tests and smokes

**Produces:** Scoped categories/costs/payments/schedules, write-event snapshots, and `canViewMoney`/`canManageMoney` separation.

- [ ] Require active `canViewMoney` for live reads and `canManageMoney` for writes.
- [ ] Allow non-owner writes only to money aggregates already in that contributor's scope or created by them.
- [ ] Record one semantic event for composite operations such as schedule payment/reversal.
- [ ] Filter all money summaries and attachments server-side; history never includes notes/methods/attachments.
- [ ] Run money authorization, concurrency, ledger, and smoke tests.

### Task 8: Provider, Member, Plan, Dashboard, And Notification Isolation

**Files:**
- Modify: `backend/src/marketplace/marketplace.service.ts`
- Modify: `backend/src/marketplace/marketplace.module.ts`
- Modify: quote lifecycle helper files where transactions commit
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify: `backend/src/dashboard/dashboard.service.ts`
- Modify: `backend/src/dashboard/dashboard.contracts.ts`
- Modify: `backend/src/wedding-plans/wedding-plans.service.ts`
- Modify: relevant marketplace/dashboard/sharing tests and smokes

**Produces:** Own-request provider scope, own-invite member scope, plan-edit events, contributor-filtered dashboard, and per-section history counts.

- [ ] Filter quote requests/provider links to contributor-owned requests and qualifying events.
- [ ] Filter member data to self, owner-safe metadata, and members invited by the contributor.
- [ ] Record provider/member/plan semantic events exactly once per transaction.
- [ ] Apply scope predicates to every dashboard query and important item.
- [ ] Add `contributionHistory` distinct counts to dashboard responses.
- [ ] Update old plan-wide viewer assertions to the approved isolation contract and run smokes.

### Task 9: Atomic Self-leave And Account Deletion Regression

**Files:**
- Modify: `backend/src/sharing/sharing.controller.ts`
- Modify: `backend/src/sharing/sharing.service.ts`
- Modify: `backend/src/users/users.service.ts`
- Modify: `backend/test/sharing-self-leave.test.ts`
- Modify: `backend/test/account-deletion.test.ts`
- Modify: `backend/test/contexts.test.ts`
- Modify: `backend/scripts/smoke/sharing-smoke.js`
- Modify: `backend/scripts/smoke/account-deletion-smoke.ts`

**Produces:** Idempotent self-leave, closed tenure, invite/conversation/notification/active-plan cleanup, re-invite support, and anonymized deletion history.

- [ ] Reuse one internal member-removal transaction for administrative removal and self-leave.
- [ ] Return success on replay only when a closed `MEMBER_LEFT` tenure proves the caller previously held that membership.
- [ ] Reject owner self-leave and retain outsider 404 behavior.
- [ ] Anonymize tenure identity during central account deletion without modifying immutable events.
- [ ] Verify contributor/provider/owner deletion regressions and re-invite behavior.

### Task 10: Flutter Contracts, History UI, And Responsive Actions

**Files:**
- Create: `mobile/lib/features/sharing/models/contribution_history.dart`
- Extend: `mobile/lib/features/sharing/data/sharing_api.dart`
- Create: `mobile/lib/features/sharing/providers/contribution_history_provider.dart`
- Create: `mobile/lib/features/sharing/screens/contribution_history_screen.dart`
- Modify: `mobile/lib/features/wedding_plans/widgets/contributor_workspace_view.dart`
- Modify: `mobile/lib/features/wedding_plans/screens/plan_management_screen.dart`
- Modify: `mobile/lib/features/wedding_plans/models/dashboard_summary.dart`
- Modify: `mobile/lib/core/routing/app_router.dart`
- Modify: relevant Flutter tests

**Produces:** Server-driven history cards/screen, no live links while revoked, and responsive full-width Arabic add actions.

- [ ] Parse only the documented history/dashboard contracts.
- [ ] Render frozen records without live entity IDs/routes/write callbacks.
- [ ] Replace the embedded FAB with a normal in-flow full-width `FilledButton.icon` using two-line Arabic text where needed.
- [ ] Test 320px, RTL, and text scales 1.0/1.3/2.0 with rectangle visibility assertions.
- [ ] Ensure late live responses cannot replace a refreshed revoked context.

### Task 11: Flutter Task Error, Self-leave, And Shared Account Management

**Files:**
- Modify: `mobile/lib/core/network/api_client.dart`
- Modify: `mobile/lib/features/tasks/providers/task_timeline_provider.dart`
- Modify: `mobile/lib/features/tasks/screens/task_timeline_screen.dart`
- Create: `mobile/lib/features/auth/widgets/account_deletion_flow.dart`
- Modify: `mobile/lib/features/more/screens/more_screen.dart`
- Modify: `mobile/lib/features/marketplace/widgets/provider_account_actions.dart`
- Modify: `mobile/lib/features/wedding_plans/screens/plan_management_screen.dart`
- Modify: `mobile/lib/features/account_contexts/providers/account_context_controller.dart`
- Modify: relevant Flutter tests

**Produces:** Arabic stable-code errors, no premature success, self-leave/cache/context cleanup, and one deletion confirmation implementation for all roles.

- [ ] Map `TASK_PERMISSION_REVOKED` centrally without rewriting unrelated 403 errors.
- [ ] Wait for task mutation success before displaying completion and rollback stale optimistic state.
- [ ] Confirm self-leave, send an idempotency key, clear context only after terminal backend success, refresh contexts, and route safely.
- [ ] Extract and reuse one typed-confirmation deletion flow while keeping `AuthController.deleteAccount()` the sole executor.
- [ ] Test leave failure/retry/lost response, logout distinction, and deletion from owner/contributor/provider paths.

### Task 12: Contracts, Full Verification, And Live Scenario

**Files:**
- Modify: `docs/backend/API_CONTRACT.md`
- Modify: `docs/backend/DATABASE.md`
- Modify: `docs/project/DECISIONS.md`
- Modify: `docs/project/STATUS.md`
- Modify: `docs/frontend/MOBILE.md`
- Modify: `docs/qa/README.md`
- Modify: `docs/deployment/README.md` only if deployment steps materially change

**Produces:** Truthful active documentation and an evidence-backed completion receipt.

- [ ] Document final schema, APIs, error codes, scope rules, privacy allowlists, legacy coverage, and rollback requirements.
- [ ] Run Prisma format/generate, backend type checks, focused tests, complete tests, and all affected smokes.
- [ ] Deploy every migration to a fresh and an upgraded isolated PostgreSQL database.
- [ ] Run Flutter format/analyze/focused tests/full tests and build a debug/release Android artifact as available.
- [ ] Start backend and Flutter, execute owner + contributor A + contributor B grant/contribute/revoke/update/leak/frozen-history scenario.
- [ ] Execute self-leave, relogin, new invitation, and account deletion role matrix.
- [ ] Report every PASS/FAIL, changed file, migration behavior, legacy gap, and anything not verified; do not claim completion otherwise.
