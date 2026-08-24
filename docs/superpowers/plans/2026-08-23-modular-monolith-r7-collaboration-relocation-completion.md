# Modular Monolith R7 Collaboration Relocation Completion Plan

Date: 2026-08-24

Status: Complete

Immutable base: `31ea5324007fc71fa4b3590fbb98a454ee1deaa7`

Application candidate: `aafb47ea1742c278f6a5ed24799ada7bc23721b0`

Completion specification:
`docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`

## Completed Tasks

- [x] Freeze the approved 18-file fate map, 114-path fence, dependency and
  ownership projections, public snapshot contract, and staged scanner.
- [x] Move the public contribution snapshot builder and reconcile all callers.
- [x] Move contribution-history API/internal sources and constructor handoffs.
- [x] Move sharing API/DTO/internal sources and reconcile Nest composition.
- [x] Promote R7 to strict: source 0, target 18, dependency 22,
  ownership 385/781.
- [x] Run security, Prisma, 11 focused smokes, 30 aggregate smokes,
  architecture/check/build, the complete backend suite, docs, and protected
  surface gates.
- [x] Resolve every independent-review Critical/Important finding test-first.
- [x] Receive final independent cumulative approval with no finding.
- [x] Build and audit the immutable image, run and clean the isolated probe,
  and cut over locally while preserving R6 rollback.
- [x] Verify the authenticated phone create/reissue/read/cancel/cleanup and
  force-close/reopen journey without real-recipient delivery.
- [x] Write exact completion receipts and update active architecture/project/QA
  documentation.
- [x] Stop before R8, push, merge, PR mutation, deployment, or remote CI.

## Final Gate Contract

The docs-only closeout is accepted only when these fresh commands pass after
the documentation edit:

```powershell
Set-Location D:\projects\aarast-modular-monolith\backend
npm run architecture
npm run check
Set-Location ..
node scripts/docs-sync.mjs --check
node scripts/docs-verify.mjs
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
- `docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`
- `docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md`

After that local commit, confirm a clean worktree and stop. Do not start R8.
