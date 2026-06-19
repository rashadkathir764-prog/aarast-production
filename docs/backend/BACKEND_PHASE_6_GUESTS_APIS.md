# Backend Phase 6 - Guest Management APIs

Date: 2026-06-19
Status: Implemented

## Scope

Phase 6 completes guest backend support for the mobile UX:

- guest CRUD compatibility under `/api/v1`
- guest get-by-id
- guest groups CRUD
- bulk guest import
- invitation status
- attendance status
- companions count
- guest summary

No Flutter UI, admin-web code, payments, deposits, bookings, AI, push, maps, or production configuration was changed.

## Migration

Created:

- `backend/prisma/migrations/20260619124545_add_guest_groups_statuses/migration.sql`

Schema additions:

- `GuestInvitationStatus`
- `GuestAttendanceStatus`
- `Guest.groupId`
- `Guest.invitationStatus`
- `Guest.attendanceStatus`
- `Guest.companionsCount`
- `GuestGroup`
- indexes for invitation status, attendance status, group, and group ordering

## Endpoints

New `/api/v1` compatibility endpoints:

- `GET /api/v1/wedding-plans/:planId/guests`
- `POST /api/v1/wedding-plans/:planId/guests`
- `POST /api/v1/wedding-plans/:planId/guests/bulk`
- `GET /api/v1/wedding-plans/:planId/guests/summary`
- `GET /api/v1/wedding-plans/:planId/guest-groups`
- `POST /api/v1/wedding-plans/:planId/guest-groups`
- `GET /api/v1/guests/:id`
- `PATCH /api/v1/guests/:id`
- `DELETE /api/v1/guests/:id`
- `PATCH /api/v1/guest-groups/:id`
- `DELETE /api/v1/guest-groups/:id`

New unprefixed compatibility endpoints:

- `POST /wedding-plans/:weddingPlanId/guests/bulk`
- `GET /wedding-plans/:weddingPlanId/guests/summary`
- `GET /wedding-plans/:weddingPlanId/guest-groups`
- `POST /wedding-plans/:weddingPlanId/guest-groups`
- `GET /guests/:id`
- `PATCH /guest-groups/:id`
- `DELETE /guest-groups/:id`

Existing unprefixed guest list/create/update/delete endpoints remain available.

## Rules

- JWT is required.
- Guest read uses plan read access.
- Guest write, bulk import, and group write use plan manage access.
- Guest `groupId`, when supplied, must belong to the same wedding plan.
- Duplicate phone numbers inside the same plan are rejected when a phone is supplied.
- Bulk import accepts request payload only and creates real guest records.
- No phone permission or external messaging behavior was added.
- Summary values are calculated from real guest and group rows.

## Guest Summary

`GET /api/v1/wedding-plans/:planId/guests/summary` returns:

- `totalGuests`
- `confirmedGuests`
- `declinedGuests`
- `pendingGuests`
- `invitedGuests`
- `groupsCount`
- `seatsTotal`
- `companionsTotal`
- `bySide`
- `byInvitationStatus`
- `byAttendanceStatus`

## Smoke Coverage

Added:

- `npm run smoke:guests-apis`

Included in:

- `npm run smoke:all`

Covered cases:

- guest group create/list/update/delete
- guest create/get/update/delete through `/api/v1`
- duplicate phone blocked inside the same plan
- bulk import from payload
- invitation and attendance statuses
- summary calculations
- unauthenticated access blocked
- unrelated user blocked

## Verification

Expected commands for this phase:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_guest_groups_statuses`
- `npm.cmd run check`
- `npm.cmd run smoke:guests-apis`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`
