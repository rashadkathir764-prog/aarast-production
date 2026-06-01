# Git Worktree Guide

## Purpose

Git worktrees let Aarast development happen in isolated folders while sharing the same repository history. This keeps each phase or feature separated from unrelated work and helps keep the main branch stable.

## Repository Prerequisite

Git worktree can only be used after confirming the correct Git repository root.

- `D:\projects\aarast` must be verified as the actual project repository root before creating worktrees.
- If Git is initialized in a subfolder such as `backend` or `mobile`, the repository root must be identified before using worktree.
- Do not create worktrees until the repository location is confirmed.

## Docs Foundation Boundary

During the current documentation phase, this file documents the intended worktree workflow only.

- Do not run `git init` as part of Docs Foundation unless explicitly requested later.
- Do not create branches as part of Docs Foundation unless explicitly requested later.
- Do not create worktrees as part of Docs Foundation unless explicitly requested later.

## Conceptual Workflow

- The main branch represents the stable project baseline.
- Each phase or feature should happen in its own branch.
- Each active branch should have its own worktree folder.
- Worktrees should be named clearly by phase or feature.
- Changes should be reviewed and verified before merging back to the stable branch.

## Branch Isolation Rules

- Do not mix unrelated phases in one branch.
- Do not implement future-phase work in a documentation-only branch.
- Do not modify unrelated files just because they are nearby.
- Keep generated, experimental, or local-only files out of stable branches unless explicitly approved.
- A docs-only branch must remain docs-only unless the user explicitly changes scope.
- A smoke-test branch must not implement product features.
- A deployment branch must not modify product logic unless explicitly approved.
- A feature branch must update relevant Markdown files when scope, API, database, testing, deployment, or decisions change.

## Documentation Sync Rule

When a worktree changes project scope, update the matching documentation file:

- Product scope changes -> `MVP_SCOPE.md` or `PRODUCT_VISION.md`.
- Phase changes -> `PHASES.md`.
- Database changes -> `DATABASE_PLAN.md`.
- API changes -> `API_PLAN.md`.
- Testing changes -> `TESTING_PLAN.md` or `SMOKE_TESTS.md`.
- Deployment changes -> `DEPLOYMENT_PLAN.md`.
- Architectural decisions -> `DECISIONS.md`.
- Agent rules -> `AGENTS.md`.

## Main Branch Stability

The main branch must remain stable. Feature branches should only merge after:

- The requested scope is complete.
- Relevant documentation is updated.
- Required checks have been run.
- Smoke tests pass for affected units when implementation code is involved.
- Known issues are documented.

## Agent And Developer Expectations

AI agents and developers should treat worktree isolation as a project safety rule. Before starting work, confirm the current phase and branch intent. When in doubt, stop at documentation or ask for scope confirmation instead of expanding implementation.
