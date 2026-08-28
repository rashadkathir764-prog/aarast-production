# Modular Monolith R8 Global Module Removal Completion Plan

Date: 2026-08-28

Status: Complete

Immutable base: `c2b728bfe54304562923facfb6094e0de04c0b27`

Application candidate: `464d785a0440b8494768a26a70ac1de73a4bff2c`

Completion specification:
`docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`

## Completed Tasks

- [x] Approve the hash-bound R8 design and staged implementation plan.
- [x] Freeze exact scope, project-global semantics, provider/import closure,
  R3 projection, external package identities, and protected surfaces.
- [x] Harden the permanent semantic scanner against decorator, DynamicModule,
  option-object, alias, spread, computed-key, and factory-resolution bypasses.
- [x] Remove `@Global()` from `PrismaModule` and
  `ConversationRealtimeModule` atomically.
- [x] Add the one missing explicit `PrismaModule` import to
  `ApplicationOutboxRuntimeModule` and prove 21/21 Prisma plus two Realtime
  direct importers.
- [x] Prove singleton provider identity, exact Realtime `useExisting`, lifecycle,
  zero project globals, and unchanged external Schedule/Throttler behavior.
- [x] Run both audits, Prisma validation/generation/equivalence, 12 focused
  managed smokes, all 30 aggregate smokes, architecture/check/build, the full
  Backend suite, docs, scope, protected-surface, and cleanup gates.
- [x] Receive independent Task 3 and Task 4 approval with no finding.
- [x] Build and audit the immutable R8 image, correct the probe verifier,
  clean the probe, and cut over locally while preserving R7 rollback.
- [x] Verify the owner-authorized 26 phone only: authenticated restore, task
  create/read/update/delete, eligible quote-scoped realtime send/read, and
  force-stop/reopen cleanup restore; leave S10 untouched.
- [x] Receive independent Task 5 approval with no Critical or Important finding.
- [x] Write exact completion receipts and update active architecture/project/QA
  documentation.
- [x] Stop before R9, push, merge, PR mutation, deployment, or remote CI.

## Final Gate Contract

The docs-only closeout is accepted only when these fresh commands pass after
the documentation edit:

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture:r8
npm run architecture
npm run check
npm run build
npm test
Set-Location ..
node .\scripts\docs-sync.mjs
node .\scripts\docs-sync.mjs --check
node .\scripts\docs-verify.mjs
git diff --check
```

The docs-only commit stages exactly:

- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `docs/README.md`
- `docs/backend/README.md`
- `docs/project/DECISIONS.md`
- `docs/project/EXECUTION_PLAN.md`
- `docs/project/STATUS.md`
- `docs/qa/README.md`
- `docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`
- `docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md`

After that local commit, confirm a clean worktree, R8 healthy on the exact
application candidate, and R7 stopped/preserved. Stop. Do not start R9.
