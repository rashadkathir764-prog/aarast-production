# Aarast Mobile Release Plan

Date: 2026-06-19
Stage: Release Plan
Status: Planning document only

## 1. Purpose

This document defines the mobile release gates for Aarast after the product, UX, architecture, QA, performance, and privacy plans are ready.

It does not perform deployment, create release scripts, modify production config, or approve a store release.

## 2. Release Principles

- No release without documented QA result.
- No release with hidden 404/blank routes in core navigation.
- No release if private finance data leaks to shared members.
- No release if guest-first onboarding forces login at launch.
- No release if offline queued writes are lost.
- No release if unfinished AI, subscriptions, payments, deposits, maps, analytics, push, quote acceptance, or provider-in-plan flows are visible without approved flags.
- No production release directly from an unverified local build.

## 3. Stage 1 - Internal Dev Build

Purpose: prove that the app builds and core routes run for developers.

Required before build:

- Branch confirmed and not `main` unless explicitly approved.
- Worktree status reviewed.
- Relevant blueprints updated.
- Feature flags checked.
- Known unfinished features hidden.

Checks:

- `dart format` for touched Dart files.
- `flutter analyze`.
- `flutter test`.
- `git diff --check`.

Exit criteria:

- Build can be installed or run locally.
- Core navigation does not crash.
- Known issues are documented.

## 4. Stage 2 - QA Build

Purpose: allow structured QA against a controlled backend/dev environment.

Required:

- QA checklist from `docs/testing/MOBILE_QA_PLAN.md`.
- Backend URL documented.
- Test users documented without secrets.
- Seed/test data prepared.
- No production data.

Manual smoke must cover:

- Guest-first onboarding.
- Account gate.
- Create/open plan.
- Home/Today Center.
- Money.
- Tasks.
- Providers.
- Guests.
- Sharing permissions.
- Notifications.
- Offline read and queued write.

Exit criteria:

- QA report says PASS or lists non-blocking issues.
- Blocking issues have owners or are fixed before next stage.

## 5. Stage 3 - Test APK / Installable Artifact

Purpose: validate installable mobile artifact outside the dev runner.

Required:

- Version name/build number recorded.
- Commit hash recorded.
- Target API/backend recorded.
- Feature flags recorded.
- Changelog draft created.
- Known issues recorded.

Checks:

- Install fresh.
- Upgrade from previous internal build where applicable.
- Launch offline.
- Launch online.
- Complete guest onboarding.
- Login/register path.
- App restart with cached data.

Exit criteria:

- Artifact is reproducible from recorded branch/commit.
- Install/upgrade path is not blocked.
- No critical crash in core flows.

## 6. Stage 4 - Pilot Users

Purpose: test with a small trusted group before production.

Pilot scope:

- Limited users.
- Clear feedback channel.
- No payment/deposit promises.
- Provider flow limited to approved pilot providers if enabled.
- Support response owner assigned.

Pilot must track:

- Onboarding drop-off.
- Route crashes or dead ends.
- Confusing Arabic copy.
- Offline failures.
- Provider quote confusion.
- Privacy concerns.
- Performance complaints.

Exit criteria:

- Pilot feedback triaged.
- Blockers fixed or release deferred.
- Product owner approves moving to production candidate.

## 7. Stage 5 - Production Candidate

Purpose: final readiness review before production release.

Required gates:

- Mobile QA PASS.
- Backend smoke PASS if backend changed.
- Privacy checks PASS.
- Route guard checks PASS.
- Offline/sync checks PASS.
- Performance smoke acceptable.
- Release notes ready.
- Rollback plan ready.
- Support plan ready.
- Legal/privacy notes reviewed where applicable.

Production candidate should not include:

- Experimental AI.
- Subscriptions.
- Payments/deposits.
- Confirmed bookings.
- Loan/credit/financing.
- Hidden admin-only operations exposed to users.

## 8. Rollback Plan

Every release candidate must define:

- Previous known-good commit.
- Previous known-good artifact.
- Backend compatibility notes.
- Local data migration rollback constraints.
- Feature flags to disable risky surfaces.
- User-facing message for outage or rollback.

Rollback cannot rely on deleting user local data.

## 9. Release Notes Template

```text
Release:
Date:
Branch:
Commit:
Build:
Backend target:
Feature flags:

Added:
-

Fixed:
-

Known issues:
-

QA:
- PASS/FAIL - mobile automated checks
- PASS/FAIL - manual smoke
- PASS/FAIL - privacy checks
- PASS/FAIL - offline checks

Rollback:
-
```

## 10. Blocker Categories

Block release for:

- Auth/session broken.
- Guest onboarding broken.
- Core navigation dead route.
- Finance privacy leak.
- Offline queue data loss.
- Dashboard summary contradiction.
- Provider/user flow mix.
- App crash on launch or tab switch.
- Backend compatibility break.
- Undocumented local migration risk.

Non-blocking only if documented:

- Minor copy issue.
- Minor visual alignment issue.
- Non-core empty state copy improvement.
- Deferred feature hidden behind flag.

## 11. Acceptance Criteria

- Internal, QA, APK/test artifact, pilot, and production candidate stages are defined.
- Required checks and exit criteria are defined.
- Rollback and release note templates are defined.
- Blocker categories are defined.
- No deploy/config/code changes are made.

## 12. Risks

- Releasing from dev runner confidence only can miss install/upgrade issues.
- Releasing without backend compatibility can break queued offline writes.
- Releasing with unclear provider wording can imply guaranteed agreements.
- Releasing without rollback plan can trap users on a bad local-data state.

## 13. Next Implementation Notes

- Next stage: `docs/analytics/ANALYTICS_PLAN.md`.
- Release work must remain separate from deployment work unless explicitly requested.
