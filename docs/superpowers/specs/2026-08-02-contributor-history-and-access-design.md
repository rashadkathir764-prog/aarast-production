# Contributor History And Access Isolation Design

**Status:** Approved for implementation on 2026-08-02.

## Objective

Make stored `SharedMember` permission flags authoritative, isolate every contributor's live plan data, preserve a frozen privacy-safe history of the contributor's own work after section revocation, add atomic self-leave, and expose safe account management in the contributor mobile path.

WhatsApp assignment and contributor deep links are explicitly outside this change.

## Authorization Rules

- `rolePermissionDefaults()` seeds flags only when an invitation is created. Direct member creation stores omitted authorization flags as `false`. Later role changes preserve omitted stored flags and never restore an explicitly revoked permission.
- Runtime authorization for every non-owner member uses the stored flags only.
- Owners retain full plan authority.
- A non-owner live section read requires the section's stored read flag:
  - tasks: `canManageTasks`
  - guests: `canManageGuests`
  - money: `canViewMoney`
  - providers: `canManageProviders`
  - members: `canInviteMembers`
  - plan editing: `canEditPlan`
- A non-owner sees only live entities currently assigned to them or entities for which their current or previous tenure contains a qualifying contribution event (`CREATED`, `COMPLETED`, or a domain execution event).
- Assignment alone grants live task visibility only while the task is currently assigned to that user. Reassignment leaves frozen assignment history but removes live access.
- Revoked sections never return live entities. They return only immutable contribution events for the current member.
- Leaving a plan removes all access, including history UI. The history remains attached to the plan and becomes visible again only if a new membership is created for the same account.

## Persistent History Model

Three persistent concepts are used:

1. `ContributorHistoryScope`: one durable history scope per wedding plan. Its plan relation becomes null if the plan is deleted, so immutable audit rows are not rewritten.
2. `ContributorTenure`: one contributor membership period. Leaving/removal closes the tenure before `SharedMember` is deleted. Re-invitation creates a new tenure.
3. `ContributionEvent`: append-only event with section, entity type, action, safe snapshot, snapshot hash, permission policy version, authority version, occurrence/capture time, and a deterministic deduplication key.

`ContributionEvent` rows are protected by a PostgreSQL trigger that rejects direct `UPDATE` and `DELETE`. Account deletion anonymizes the mutable tenure link (`actorUserId = null`) rather than modifying events. Plan deletion detaches the mutable scope link rather than modifying events.

## Snapshot Policy

Snapshots are copied values and never join back to live entities in history responses. Snapshot builders are per entity type and use explicit allowlists.

Allowed examples:

- task: title, status, priority, due date, category
- guest: display name, group display name, side, invitation/attendance status
- money: item title, category label, currency, allowed amounts, status, relevant date
- provider: provider display label, category label, request/link status; offer amount only when money visibility was active
- member/invite: display label, role, non-sensitive permission labels, invite state
- plan: plan title and non-sensitive date/status values

Never stored in contribution snapshots:

- phone numbers, email addresses, normalized contacts
- tokens, headers, request/response bodies, query values
- chat or quote free-text messages
- guest notes, finance notes, payment methods, attachments
- provider private contact details

Every snapshot is validated before insert and its canonical JSON SHA-256 is stored. History APIs never return `entityId`, `weddingPlanId`, or a live route when the relevant section is revoked.

## Revocation Atomicity

`SharingService.updateMemberForPlan()` keeps the existing row-lock order. When a live-read flag changes from true to false it must, inside the same serializable transaction:

1. lock the target membership;
2. preserve the immutable snapshots already written by qualifying contributor actions;
3. never query or re-snapshot live entities and never treat assignment alone as historical contribution;
4. append a deterministic section revocation marker;
5. revoke any pending delegated invitation that exceeds the actor's new stored ceiling;
6. increment `SharedMember.authorityVersion`;
7. persist the new stored permission flags;
8. emit the existing post-commit authority refresh signal.

Concurrent contributor writes either commit first together with their own
action-time contribution event, or observe the revoked membership and fail.
Owner changes never rewrite contributor history because revocation does not
copy the later live state.

## Live Scope And History APIs

- Existing task, guest, money, provider, sharing, timeline, notification, and dashboard reads are filtered in the backend before serialization.
- `GET /api/v1/wedding-plans/:weddingPlanId/contributions` lists the current member's immutable events; owners may filter by contributor.
- `GET /api/v1/wedding-plans/:weddingPlanId/contributions/summary` returns distinct entity counts per section for dashboard cards.
- Direct live endpoints return a stable `403` when the member exists but the section is revoked; unknown/non-member resources retain privacy-preserving `404` behavior.
- Task mutation denial after revocation returns:
  - HTTP `403`
  - code `TASK_PERMISSION_REVOKED`
  - message `لم تعد لديك صلاحية لتنفيذ هذه المهمة`

Flutter renders server-filtered responses and server-provided capabilities only. It never receives plan-wide data and hides it locally.

## Self-leave

`DELETE /api/v1/wedding-plans/:weddingPlanId/members/me` ends only the authenticated user's membership. It is transactionally idempotent per tenure and reuses member-removal cleanup:

- close the active tenure with `MEMBER_LEFT`;
- revoke matching pending invites while preserving accepted invite history;
- revoke plan conversation participation;
- purge plan money notifications for the leaving user;
- clear `activeWeddingPlanId` when it references the plan;
- delete only the caller's `SharedMember` row.

Owners cannot leave their owned plan. Repeating a lost-response request for an already closed tenure returns the same successful terminal result. A new invitation creates a new membership and tenure.

## Account Deletion

The contributor UI reuses `AuthController.deleteAccount()` through one shared confirmation flow. It does not create a second deletion implementation. Account deletion anonymizes contribution tenure identity and preserves non-personal immutable plan history; the deleted account cannot use or recover that history.

## Existing Data

The migration is additive and does not change original domain rows.

- Create a history scope for every existing plan.
- Create a tenure for every current `SharedMember`, with `trackingStartedAt` equal to the migration cutover time.
- Backfill only evidence that is explicit in existing columns:
  - current `WeddingTask.assigneeUserId` as `LEGACY_CONFIRMED_ASSIGNMENT`, with unknown occurrence time;
  - `QuoteRequest.userId` for plan-bound requests as `LEGACY_CONFIRMED_CREATION`, using `QuoteRequest.createdAt`.
- Do not infer task creators/completers, guest creators, money actors, prior assignees, or ended memberships.
- API responses expose `historyCoverageStartsAt` so the UI never claims that pre-cutover history is complete.

## Verification Gate

Completion requires unit/contract tests, isolated PostgreSQL migration deployment, full backend tests, Flutter analyze/tests, a real running backend with an owner and two contributors, permission revoke followed by owner edits, cross-contributor leak checks, leave/login/re-invite checks, and an Android build. Anything not executed must be reported as unverified.
