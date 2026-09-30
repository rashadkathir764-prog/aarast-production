# Agent Rules

These rules apply to AI agents and automation working on Aarast / اعّرست.

## Current Agent Checklist - 2026-08-11

- Inspect before editing: read the approved docs and confirm the actual code/config state.
- Do not commit, push, branch, checkout, reset, or create worktrees unless the user explicitly requests Git work.
- Keep edits tightly scoped and report every changed file.
- Run the checks required for the touched area and report PASS/FAIL exactly.
- Never expose secrets from `.env`, Dokploy, Meta/WhatsApp, SMTP, JWT, database, or admin credentials.
- Keep Arabic/RTL product language intact where it already exists.
- Do not overwrite the Flutter offline SQLite layer, provider marketplace/reference flows, provider dashboard, or admin approval flow blindly.
- For deployment docs, distinguish current Compose routing from the target split between API, admin web, and Flutter web/mobile.

## Modular Monolith Guard

- Read `ARCHITECTURE_CONSTITUTION.md` and `ARCHITECTURE.md` before architecture work. The constitution states the binding current laws; the older phase sections in `ARCHITECTURE.md` are history.
- Follow `UNDERSTAND → IDENTIFY OWNER → IDENTIFY PUBLIC CONTRACT → CHECK EXISTING TESTS → MAKE ISOLATED CHANGE → RUN FOCUSED TESTS → RUN ARCHITECTURE GATES → REVIEW DIFF → COMMIT` when Git work is authorized.
- Do not work directly on `main`; use an isolated worktree for significant work and verify its base and cleanliness.
- Confirm ownership in the registry and live source, not from file names or comments. Business-owner Prisma access belongs only in that owner's `infrastructure/`.
- Cross-context Backend code consumes only the owner's public contract.
- No foreign Prisma root/relation/SQL access, deep cross-context import, `forwardRef()`, or project-owned `@Global()` use.
- Do not duplicate owner business logic to avoid a port, add a masking baseline/ignore/exception, weaken a gate, or change a behavioral test assertion to make a defect pass.
- Preserve published migrations and existing API, permission, transaction, locking, Mobile, and Admin contracts unless the task explicitly approves a change.
- Classify findings using the constitution. `OPTIONAL IMPROVEMENT` is not an architecture blocker. A new exception requires explicit approval, a narrow documented scope, a protecting test, and a removal plan if temporary.
- No new Mobile boundary-baseline entry, unresolved local directive, or cross-area `part` relationship.
- A phase cannot start until the prior phase gate is green.

## Phase Discipline

- Do not jump phases.
- Do not implement future-phase features early.
- Do not create Flutter screens unless the active phase explicitly asks for Flutter work.
- Do not create backend modules unless the active phase explicitly asks for backend implementation.
- Do not add confirmed bookings, deposits, payment status, payment processing, loans, credit, financing flows, FinTech, AI, or open messaging outside the approved quote-scoped conversation flow unless explicitly approved.

## Read Before Work

Before implementation tasks, agents must read the relevant approved documentation first:

- `docs/README.md`
- `docs/project/PRODUCT.md`
- `docs/project/SCOPE_AND_PHASES.md`
- `docs/project/STATUS.md`
- `docs/project/DECISIONS.md`
- `docs/backend/API_CONTRACT.md`
- `docs/backend/DATABASE.md`
- `docs/qa/README.md`
- `docs/deployment/README.md`
- Any phase-specific active doc linked from `docs/README.md`.

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
- Archived files under `docs/archive/2026-07-docs-consolidation/` are historical
  references only and must not be treated as active source-of-truth docs.

## Imported Claude Cowork project instructions

## Universal Agent Engineering Instructions

1. Reproduce before fixing; if reproduction is impossible, provide concrete evidence and state the blocker.
2. Fix the root cause, not the symptom; reject band-aids, silent fallbacks, and cosmetic patches.
3. Do not introduce workarounds, hacks, or compatibility layers without explicit approval and a removal plan.
4. Verify before claiming completion; report the exact checks performed, results obtained, and remaining uncertainty.
5. Think like a production engineer, not a code generator; prioritize correctness, simplicity, safety, maintainability, and operability.
6. Reconfirm the objective, constraints, and definition of done before major changes or after any context reset.
7. Read all applicable repository instructions, follow them throughout the task, and demonstrate compliance in the final report.
8. Protect existing tests; never delete, skip, weaken, or rewrite them merely to make the implementation pass.
9. Fix the earliest incorrect source or system boundary instead of patching the same symptom across downstream consumers.
10. Keep the design minimal; add abstractions, layers, dependencies, or future-proofing only for a concrete current need.
11. Handle success, failure, timeout, retry, invalid input, duplication, and other relevant edge cases—not only the happy path.
12. Never hide errors, warnings, or failed checks; classify, handle, log, or propagate them explicitly.
13. Declare the expected change surface first, minimize unrelated edits, and justify every additional file or component changed.
14. Do not preserve old and new implementations together unless a real consumer requires compatibility and removal is scheduled.
15. Do not treat passing tests as sufficient; also review architecture, security, performance, concurrency, and maintainability.
16. Finish with an evidence-based completion receipt covering the diff, tests, type checks, lint, build, migrations, documentation, and remaining risks.
