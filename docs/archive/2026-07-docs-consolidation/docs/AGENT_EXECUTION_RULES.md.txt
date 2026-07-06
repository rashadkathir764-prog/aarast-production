# Aarast Agent Execution Rules

Date: 2026-06-19
Stage: Agent Execution Rules
Status: Planning document only

## 1. Purpose

This document translates the Aarast mobile rebuild README, `AGENTS.md`, and the new blueprints into execution guardrails for AI agents and automation.

It applies to future work in this repository unless a newer approved instruction explicitly replaces it.

## 2. Start Checklist

Before implementation:

1. Confirm repository root.
2. Confirm branch.
3. Confirm task scope.
4. Read `AGENTS.md`.
5. Read the relevant approved blueprints.
6. Check `git status --short`.
7. Identify files expected to change.
8. Identify required verification commands.

Do not start code edits if the phase, product boundary, or target files are unclear.

## 3. Required Reading By Task Type

Mobile product/UX work:

- `docs/mobile-ux/PRODUCT_LOGIC_BLUEPRINT.md`
- `docs/mobile-ux/UX_BLUEPRINT.md`
- `docs/mobile-ux/NAVIGATION_BLUEPRINT.md`
- `docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md`
- `docs/testing/MOBILE_QA_PLAN.md`

Mobile state/offline work:

- `docs/mobile-architecture/STATE_MANAGEMENT_PLAN.md`
- `docs/mobile-architecture/SINGLE_SOURCE_OF_TRUTH_PLAN.md`
- `docs/architecture/OFFLINE_SYNC_PLAN.md`
- `docs/architecture/MIGRATION_PLAN.md`

Backend/API/data work:

- `API_PLAN.md`
- `API_CONTRACT.md`
- `docs/architecture/DATA_MODEL_BLUEPRINT.md`
- `docs/architecture/BACKEND_FLOW_BLUEPRINT.md`
- `DATABASE_PLAN.md`

Security/privacy/support/provider work:

- `docs/security/SECURITY_PRIVACY_PLAN.md`
- `docs/legal/PRIVACY_TERMS_NOTES.md`
- `docs/support/SUPPORT_DISPUTES_PLAN.md`
- `docs/admin/ADMIN_PROVIDER_OPERATIONS.md`

Visual work:

- `docs/mobile-ux/DESIGN_SYSTEM.md`
- `docs/mobile-ux/VISUAL_SYSTEM.md`
- `docs/mobile-ux/ERROR_LOADING_EMPTY_STATES_GUIDE.md`

Release/analytics/monetization:

- `docs/release/MOBILE_RELEASE_PLAN.md`
- `docs/analytics/ANALYTICS_PLAN.md`
- `docs/business/MONETIZATION_LATER.md`

## 4. Phase Discipline

Agents must not:

- Jump phases.
- Implement future-phase features early.
- Add Flutter screens unless the active phase asks for Flutter work.
- Add backend modules unless the active phase asks for backend work.
- Add admin-web changes unless the task asks for admin-web work.
- Start visual polish before product/UX/data/architecture readiness.
- Treat placeholder support, AI, subscriptions, push, maps, analytics, or quote acceptance as complete features.

## 5. Product Boundaries

Do not add or expose without explicit approval:

- Confirmed bookings.
- Deposits.
- Payment status.
- Payment processing.
- Provider commission.
- Subscriptions.
- Loans.
- Credit.
- Financing.
- FinTech.
- AI helper.
- Internal chat.
- Full marketplace promises.

Provider flows are planning/reference and quote-lead flows until later approval.

## 6. Guest-First Rule

Agents must preserve:

- No forced login at first launch.
- Wedding-user path separate from provider path.
- Guest draft data preserved locally.
- Account gate only when the action needs identity/server ownership.
- Intended action resumes after auth and migration.

Do not lose guest plan, budget, tasks, guests, provider drafts, or local queue data during auth/migration work.

## 7. Privacy Rule

Financial and planning data is private by default.

Agents must ensure:

- Shared members see finance/debts/installments only when permission allows.
- Provider cannot see full plan, budget, debts, guest list, or shared members.
- Notifications do not reveal hidden finance details.
- Contact upload is never broad/automatic.
- Exact address sharing is explicit.
- Logs/analytics do not include sensitive raw payloads.

## 8. Single Source Rule

Do not compute the same summary independently in multiple screens.

Single-source domains:

- Days remaining.
- Progress percentage.
- Budget/spent/remaining.
- Debts and due installments.
- Task counts and overdue counts.
- Guests.
- Providers/quotes.
- Notifications.
- Sync state.

## 9. Offline And Migration Rule

Preserve existing offline/sqflite/JSON fallback.

Before changing local storage:

- Read `docs/architecture/OFFLINE_SYNC_PLAN.md`.
- Read `docs/architecture/MIGRATION_PLAN.md`.
- Protect `sync_queue`.
- Protect dirty/deleted-local flags.
- Do not drop data with pending sync items.
- Add migration tests.

Never claim cloud/server success for local-only action.

## 10. Feature Flag Rule

Incomplete or risky features must be hidden behind flags.

Default disabled:

- AI.
- Subscriptions.
- Payments/deposits.
- Maps.
- Push.
- Analytics.
- Quote offer/accepted-provider integration.
- Support/disputes implementation until approved.

## 11. File Discipline

Agents must:

- Modify only files needed for the task.
- Preserve user changes.
- Avoid unrelated refactors.
- Update relevant Markdown when product/API/database/testing/deployment/phase boundaries change.
- Avoid package installs unless explicitly requested.
- Avoid migrations unless explicitly requested.
- Avoid Docker, Compose, Dokploy, and production config unless explicitly requested.

## 12. Git Discipline

Agents must:

- Not work on `main` unless explicitly ordered.
- Not run `git init`.
- Not create branches/worktrees unless explicitly requested.
- Not push.
- Not deploy.
- Not reset or discard user changes.
- Commit only when the user/task explicitly asks for commits.
- Keep commits small and scoped.

If `git` is not on PATH in this Windows shell, use the local Git executable path already proven for this workspace:

```text
C:\Program Files\Git\cmd\git.exe
```

## 13. Verification Rules

Docs-only:

- `git diff --check`

Mobile code:

- `dart format` on touched Dart files.
- `flutter analyze`
- `flutter test`
- Targeted widget/provider tests.
- Manual smoke for visible navigation or post-login/guest flows.

Backend code:

- `npm --prefix backend run check`
- `npm --prefix backend run smoke:all`

If a required check cannot run, report it as not run with the reason.

## 14. Stop Conditions

Stop and report BLOCKED if:

- Current branch is `main` and task did not explicitly allow it.
- Required auth/smoke failure is real and task says not to bypass it.
- Local data migration would be destructive without plan.
- Scope requires deployment/production config but task did not approve it.
- A requested implementation contradicts product/legal/privacy boundaries.
- The task would expose payment/deposit/AI/FinTech behavior early.

## 15. Report Format

Every implementation task should end with:

```md
## Report

### What was changed
-

### Files modified
-

### Tests run
-

### Result
PASS / FAIL / BLOCKED

### Known issues
-

### Risks
-

### Next recommended step
-
```

Docs-only tasks may use a shorter report but must still list files, checks, and result.

## 16. Acceptance Criteria

- Required reading is mapped by task type.
- Phase, product, guest-first, privacy, single-source, offline, feature-flag, file, git, and verification rules are documented.
- Stop conditions and report format are documented.
- No app/backend/admin/deployment code is changed.

## 17. Risks

- Agents can break stable work by expanding scope silently.
- Passing static checks alone can miss visible UI failures.
- Privacy and support/legal boundaries are easy to violate through copy, logs, and notification previews.
- Small route changes can expose unfinished features without feature flags.

## 18. Next Implementation Notes

- The blueprint/documentation track is now complete.
- Next safe work should be a narrow mobile implementation skeleton behind flags, starting from `docs/mobile-ux/MOBILE_IMPLEMENTATION_PLAN.md` and `docs/testing/MOBILE_QA_PLAN.md`.
