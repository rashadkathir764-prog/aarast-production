# Phase 0 baseline and test isolation

Date: 2026-07-24
Branch: `codex/aarast-full-remediation`
Merge base: `87a1f0df6c7ec8cd4280991a974b42686268c819`

## Result

PASS, with no product-logic, schema, migration, deployment, Admin behavior, or Flutter UI changes.

## Baseline and backup proof

- The verified pre-phase baseline was Backend 371 pass / 1 existing skip, Flutter 721/721, and Admin 50/50.
- The pre-phase Compose backup is `aarast-phase0-20260724-030527.dump`: 349434 bytes, SHA-256 `472D43AA3075D6070EBFC5C07CE04CF22E451FA649B6AE2967234885BA97A6A4`, with 395 readable `pg_restore --list` entries.
- No mutating smoke, Prisma reset/push, migration, or permanent database operation was run in this phase.

## Change set

- `backend/scripts/smoke/phase0-source-guard.js`: CI-executed source guard. It requires the managed runner for official Backend mutating smoke/load commands, keeps the intentionally external confirmed OpenWA send outside the database-smoke set, and rejects destructive Prisma commands or permanent database URLs in test sources.
- `backend/scripts/smoke/phase0-git-cleanliness.js`: post-test check for `mobile/test/goldens/` and every tracked fixture/golden path.
- `backend/test/support/phase0-postgres-fixtures.js`: managed-run-only PostgreSQL fixtures for a two-SUPER_ADMIN case, OTP ceiling, quote accept/reject, quote accept/update, and send/permission-revoke races. Each fixture supplies exact-row cleanup and the concurrency helper starts all supplied operations behind one barrier.
- `backend/test/phase0-guards.test.ts`: regression contract for the new guard/fixture assets and their lifecycle integration.
- `backend/package.json`, `docs/SCRIPTS.md`: run the source/fixture contract in `pretest` and the tree-cleanliness check in `posttest`; generated script inventory was synchronized.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Backend check | PASS | `npm.cmd run check` |
| Backend build | PASS | `npm.cmd run build` |
| Backend tests | PASS | pretest 20/20; main test 371 pass, 1 existing skip, 0 fail; posttest cleanliness PASS |
| Prisma validate | PASS | completed with a temporary non-connected `phase0_validate_test` target; initial invocation was BLOCKED only by missing `DATABASE_URL` |
| Flutter analyze | PASS | no issues |
| Flutter tests | PASS | 721/721 |
| Admin typecheck | PASS | `tsc -b` |
| Admin tests | PASS | 50/50; expected ErrorBoundary render output appeared with exit 0 |
| Admin build | PASS | Vite build and config smoke passed |
| Docs sync/verify | PASS | sync check 0 drift; verify 0 errors, 0 warnings |
| Diff whitespace | PASS | `git diff --check` |
| Test artifact cleanliness | PASS | protected goldens/tracked fixtures unchanged |

## Rollback and data impact

- Rollback is one focused Git commit revert.
- No permanent database, Redis namespace, media bucket, golden, or product fixture was modified.
- The only generated Flutter files shown as modified by Git have worktree blob hashes equal to the index after Flutter tooling; they are excluded from this change set and were not staged.

## Exit rubric

1. PASS — working directory scope is limited to Phase 0 guards, fixtures, reports, and generated script documentation.
2. PASS — existing managed smoke runner remains the sole official Backend mutating smoke/load database path.
3. PASS — existing guard rejects `aarast`, `aarast_dev`, unsafe names, and non-run-owned databases.
4. PASS — existing lifecycle tests prove exact-run cleanup after success/failure; no cleanup behavior changed.
5. PASS — source guard detects runner bypass, destructive Prisma commands, and permanent database URLs.
6. PASS — post-test Git guard protects goldens and tracked fixtures.
7. PASS — five future RED-test fixture shapes are reusable, isolated, and carry exact cleanup functions.
8. PASS — no intentionally failing test, product fix, migration, or schema change is included.
9. PASS — Backend, Flutter, Admin, and documentation gates completed as recorded above.
10. PASS — no permanent-data impact; backup proof remains recorded and rollback is commit-level.
