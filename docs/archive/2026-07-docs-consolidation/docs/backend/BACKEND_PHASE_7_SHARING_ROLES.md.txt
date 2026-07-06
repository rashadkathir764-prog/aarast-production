# Backend Phase 7 - Sharing, Roles, and Permissions

Date: 2026-06-19
Status: Implemented

## Scope

Phase 7 completes the mobile sharing backend on top of the existing `shared-members` APIs:

- `/api/v1` member listing, update, and revoke
- invite token creation
- invite preview
- invite acceptance
- permission summary for the current user
- role defaults for `OWNER`, `EDITOR`, `VIEWER`, `FINANCE_MANAGER`, and `HELPER`

The existing `VIEWER`, `CONTRIBUTOR`, and `MANAGER` roles remain supported for backward compatibility.

No Flutter UI, admin-web code, payments, deposits, bookings, AI, push, maps, or production configuration was changed.

## Migration

Created:

- `backend/prisma/migrations/20260619125929_add_plan_invites_roles/migration.sql`

Schema additions:

- added `OWNER`, `EDITOR`, `FINANCE_MANAGER`, and `HELPER` to `SharedMemberRole`
- added `PlanInvite`
- added invite relations from `User` and `WeddingPlan`

## Endpoints

New `/api/v1` endpoints:

- `GET /api/v1/wedding-plans/:planId/members`
- `POST /api/v1/wedding-plans/:planId/invites`
- `GET /api/v1/invites/:token`
- `POST /api/v1/invites/:token/accept`
- `PATCH /api/v1/wedding-plans/:planId/members/:memberId`
- `DELETE /api/v1/wedding-plans/:planId/members/:memberId`
- `GET /api/v1/wedding-plans/:planId/permissions/me`

Existing unprefixed sharing endpoints remain available:

- `GET /wedding-plans/:weddingPlanId/shared-members`
- `POST /wedding-plans/:weddingPlanId/shared-members`
- `PATCH /shared-members/:id`
- `DELETE /shared-members/:id`
- `GET /shared/wedding-plans`

## Role Rules

- `OWNER` is reserved for the wedding plan owner and cannot be assigned to shared members.
- `EDITOR` can manage the plan and tasks, but does not get finance access by default.
- `FINANCE_MANAGER` can view and manage finance records by default.
- `HELPER` can manage tasks and guests, but cannot update the plan.
- `VIEWER` is read-only by default.
- Legacy `MANAGER` remains plan/task capable.
- Legacy `CONTRIBUTOR` remains task capable.

## Invite Rules

- Only the owner can create invites.
- Invites target either `userId` or `phone`, not both.
- Invite tokens are unique and expire after 14 days by default.
- Targeted invites can only be accepted by the intended user or phone owner.
- Accepting an invite creates or updates the real `SharedMember` row.
- The owner cannot invite themselves.

## Permission Summary

`GET /api/v1/wedding-plans/:planId/permissions/me` returns:

- `role`
- `isOwner`
- `canViewBudget`
- `canViewExpenses`
- `canViewDebts`
- `canManageTasks`
- `canManageGuests`
- `canManageFinancialRecords`
- `canManagePlan`
- `canManageMembers`

## Smoke Coverage

Added:

- `npm run smoke:sharing-roles`

Included in:

- `npm run smoke:all`

Covered cases:

- owner permission summary
- invite creation
- public invite preview
- wrong user cannot accept targeted invite
- invite acceptance
- member list includes virtual owner
- owner updates member role to `FINANCE_MANAGER`
- finance manager can create a budget category
- helper invite by phone
- helper can create guests but cannot update the plan
- last owner protection
- revoke member
- revoked member loses plan access
- unauthenticated access blocked

## Verification

Expected commands for this phase:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_plan_invites_roles`
- `npm.cmd run check`
- `npm.cmd run smoke:sharing-roles`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`
