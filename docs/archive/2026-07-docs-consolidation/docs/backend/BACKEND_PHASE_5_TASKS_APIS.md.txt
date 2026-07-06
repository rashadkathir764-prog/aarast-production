# Backend Phase 5 - Task Management APIs

Date: 2026-06-19
Status: Implemented

## Scope

Phase 5 completes task backend support for the mobile UX:

- task CRUD compatibility under `/api/v1`
- task get-by-id
- checklist item CRUD
- task assignment
- task summary
- `URGENT` priority

No Flutter UI, admin-web code, payments, deposits, AI, push, maps, or production configuration was changed.

## Migration

Created:

- `backend/prisma/migrations/20260619123546_add_task_checklist_assignment/migration.sql`

Schema additions:

- `WeddingTaskPriority.URGENT`
- `WeddingTask.assigneeUserId`
- relation from task to assigned user
- `WeddingTaskChecklistItem`
- indexes for plan/status, assignee, and checklist ordering

## Endpoints

New `/api/v1` compatibility endpoints:

- `GET /api/v1/wedding-plans/:planId/tasks`
- `POST /api/v1/wedding-plans/:planId/tasks`
- `GET /api/v1/tasks/:id`
- `PATCH /api/v1/tasks/:id`
- `DELETE /api/v1/tasks/:id`
- `POST /api/v1/tasks/:id/checklist`
- `PATCH /api/v1/tasks/:id/checklist/:itemId`
- `DELETE /api/v1/tasks/:id/checklist/:itemId`
- `PATCH /api/v1/tasks/:id/assign`
- `GET /api/v1/wedding-plans/:planId/tasks/summary`

New unprefixed compatibility endpoints:

- `GET /tasks/:id`
- `POST /tasks/:id/checklist`
- `PATCH /tasks/:id/checklist/:itemId`
- `DELETE /tasks/:id/checklist/:itemId`
- `PATCH /tasks/:id/assign`
- `GET /wedding-plans/:planId/tasks/summary`

Existing unprefixed task list/create/update/delete endpoints remain available.

## Rules

- JWT is required.
- Task read uses plan read access.
- Task write, checklist write, and assignment use existing task manage permission.
- Assignment accepts the plan owner or a shared member only.
- Assignment outside the plan returns `400`.
- `TODO`, `IN_PROGRESS`, `DONE`, and `CANCELLED` remain supported.
- `LOW`, `MEDIUM`, `HIGH`, and `URGENT` priorities are supported.
- Today and overdue task counts are calculated from real due dates.

## Task Summary

`GET /api/v1/wedding-plans/:planId/tasks/summary` returns:

- `totalTasks`
- `completedTasks`
- `openTasks`
- `overdueTasks`
- `todayTasks`
- `assignedToMe`
- `byStatus`
- `byPriority`

## Smoke Coverage

Added:

- `npm run smoke:tasks-apis`

Included in:

- `npm run smoke:all`

Covered cases:

- task create/list/get/update/delete through `/api/v1`
- `URGENT` priority
- checklist create/update/delete
- assignment to shared plan member
- assignment outside plan blocked
- task-capable shared member creates task
- task summary calculations
- unauthenticated access blocked
- unrelated user blocked

## Verification

Expected commands for this phase:

- `npx.cmd prisma format`
- `npx.cmd prisma validate`
- `npx.cmd prisma migrate dev --name add_task_checklist_assignment`
- `npm.cmd run check`
- `npm.cmd run smoke:tasks-apis`
- `npm.cmd run smoke:all`
- `git diff --check`
- `git diff --cached --check`
