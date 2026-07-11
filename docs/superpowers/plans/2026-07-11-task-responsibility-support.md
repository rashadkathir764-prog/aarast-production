# Task Responsibility Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make task responsibility truthful for account-backed plans by persisting manual responsible details and mapping "أنا" to the authenticated plan member.

**Architecture:** `WeddingTask` gains optional `responsibleName`, `responsiblePhone`, and `responsibleSource` fields for non-member responsibility. Registered plan members continue to use `assigneeUserId`; these two responsibility modes are mutually exclusive. Flutter sends the manual fields through the existing task create/update endpoints and resolves the current authenticated user from the plan-member list when the user chooses or keeps "أنا".

**Tech Stack:** NestJS 11, Prisma 6/PostgreSQL, Flutter/Provider, Node test runner, Flutter widget tests.

## Global Constraints

- Preserve all unrelated dirty-tree changes from the other active session.
- Do not change task routes or add dependencies.
- A member assignment uses `assigneeUserId`; a manual responsibility uses the three `responsible*` fields; never persist both modes on one task.
- `responsiblePhone` remains optional and is normalized by the mobile client before submission.
- Do not commit, push, deploy, or modify Docker configuration.

---

### Task 1: Backend task responsibility contract

**Files:**
- Modify: `backend/prisma/schema.prisma`
- Create: `backend/prisma/migrations/20260711120000_add_task_manual_responsibility/migration.sql`
- Modify: `backend/src/tasks/dto/create-task.dto.ts`
- Modify: `backend/src/tasks/dto/update-task.dto.ts`
- Modify: `backend/src/tasks/tasks.service.ts`
- Test: `backend/test/task-responsibility.test.ts`

**Interfaces:**
- Consumes: existing task create/update routes.
- Produces: optional `responsibleName`, `responsiblePhone`, and `responsibleSource` properties in task requests and responses.

- [ ] Write a backend test proving create/update persist optional manual responsibility and clear it when a participant is assigned.
- [ ] Run the targeted test and confirm it fails because the DTO/service/schema contract is missing.
- [ ] Add nullable Prisma columns, an additive migration, DTO validation, normalized service writes, response mapping, and mutual-exclusion clearing.
- [ ] Run the targeted test, backend typecheck/build, and task-related smoke coverage.

### Task 2: Flutter account-backed responsibility flow

**Files:**
- Modify: `mobile/lib/features/tasks/data/task_timeline_api.dart`
- Modify: `mobile/lib/features/tasks/screens/create_task_screen.dart`
- Test: `mobile/test/features/tasks/super3_tasks_contract_test.dart`

**Interfaces:**
- Consumes: backend `responsible*` request/response contract and `AuthController.user.id`.
- Produces: truthful account task creation for either the authenticated plan member or a manual responsible person.

- [ ] Write widget/API tests reproducing the screenshot: a manual name with an empty phone saves, and "أنا" selects the authenticated member.
- [ ] Run the targeted Flutter test and confirm the new assertions fail for the current guard/payload behavior.
- [ ] Remove the blocking placeholder guard, send manual fields for cloud create/update/offline replay, and resolve "أنا" against the authenticated plan member.
- [ ] Run the targeted tests, `flutter analyze`, and the complete Flutter suite.

### Task 3: Documentation and final verification

**Files:**
- Modify: `docs/backend/API_CONTRACT.md`
- Modify: `docs/backend/DATABASE.md`

- [ ] Update the active task API/database truth and generated model table.
- [ ] Run docs sync/check, docs verification, backend checks/tests, Flutter checks/tests, and `git diff --check`.
- [ ] Report every touched file and every PASS/FAIL/BLOCKED result without committing.
