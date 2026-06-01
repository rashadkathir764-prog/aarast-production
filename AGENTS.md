# Agent Rules

These rules apply to AI agents and automation working on Aarast / اعّرست.

## Phase Discipline

- Do not jump phases.
- Do not implement future-phase features early.
- Do not create Flutter screens unless the active phase explicitly asks for Flutter work.
- Do not create backend modules unless the active phase explicitly asks for backend implementation.
- Do not add confirmed bookings, deposits, payment status, payment processing, loans, credit, financing flows, FinTech, AI, or internal chat unless explicitly approved.

## Read Before Work

Before implementation tasks, agents must read the relevant approved documentation first:

- `PRODUCT_VISION.md`
- `MVP_SCOPE.md`
- `PHASES.md`
- `DATABASE_PLAN.md`
- `API_PLAN.md`
- `TESTING_PLAN.md`
- `SMOKE_TESTS.md`
- `GIT_WORKTREE_GUIDE.md`
- `DEPLOYMENT_PLAN.md`
- `DECISIONS.md`
- Any phase-specific docs.

## File Discipline

- Do not modify unrelated files.
- Keep changes tightly scoped to the current task.
- Always update relevant Markdown files when product scope, API scope, database scope, testing expectations, or phase boundaries change.
- Do not modify already-approved documentation files unless the current task explicitly asks for it or a contradiction must be fixed. If a contradiction is fixed, report exactly what changed and why.
- Do not create or modify Docker, Docker Compose, or Dokploy deployment files unless the current task explicitly requests deployment work.
- Preserve existing user changes unless the user explicitly asks to replace them.

## Git Discipline

- Do not run `git init`.
- Do not create branches.
- Do not create worktrees.
- Do not modify Git state.
- Git/worktree actions are allowed only when the current task explicitly requests Git work and the repository root has been confirmed.

## Privacy Discipline

- Financial data such as expenses, debts, installments, and attachments is private by default.
- Shared members must not see private financial details unless permissions explicitly allow it.

## Verification Discipline

- When implementing code in later phases, always run the required checks for that phase.
- Prefer smoke API tests before expanding core features.
- Report commands run, PASS/FAIL results, known issues, and next steps.
- Do not claim checks passed unless they were actually run.

## Documentation-Only Tasks

For the Docs Foundation task:

- Only Markdown files may be changed.
- Do not implement application code.
- Do not create Flutter screens.
- Do not create backend modules.
- Do not install packages.
- Do not run database migrations.
- Do not create Dockerfiles, docker-compose files, or Dokploy configuration.
- Do not modify business logic.
