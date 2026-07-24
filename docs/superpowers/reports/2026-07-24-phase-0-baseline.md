# Phase 0 baseline and test isolation

Date: 2026-07-24
Branch: `codex/aarast-full-remediation`
Merge base: `87a1f0df6c7ec8cd4280991a974b42686268c819`

## Scope and review status

Status: `READY_FOR_INDEPENDENT_REVIEW`.

This work is limited to Phase 0 test-isolation infrastructure: managed smoke execution, fixture cleanup, source and cleanliness guards, and their tests. It does not change product behavior, Flutter UI, Admin behavior, Prisma schema or migrations, Docker/Compose, or deployment configuration.

## Backup evidence

The pre-remediation backup is:

- Path: `D:\projects\aarast-backups\aarast-phase0-20260724-030527.dump`
- Size: `349434` bytes
- SHA-256: `472D43AA3075D6070EBFC5C07CE04CF22E451FA649B6AE2967234885BA97A6A4`
- `pg_restore --list` inventory: `395` lines

No permanent database was targeted during this remediation. The isolated smoke runner creates a run-owned `aarast_smoke_*` database and removes it in cleanup.

## TDD evidence

RED was observed before each repair:

- The original Phase 0 guard suite began at `0/6` passing checks.
- Follow-up RED cases covered permanent PostgreSQL targets, fixture-graph cleanup, concurrent cleanup ordering, AST aliases/interpolation/dynamic database imports, and the fixture-smoke return/fail-closed contracts.
- The final cleanliness RED proved that the dirty executable entrypoint was incorrectly classified as a protected artifact; a second RED proved that a TypeScript fixture must remain protected.

GREEN evidence from the final implementation:

```text
node --test -r ts-node/register test/phase0-guards.test.ts
20 pass / 0 fail

npm.cmd test
pretest 38 pass / 0 fail
main 371 pass / 0 fail / 1 existing skip
posttest PASS
```

The final tests prove that `createOperationOutputs` returns its transaction result; every saved operation-output id is counted through its matching model; cleanup fails closed when a quote fixture lacks `operationOutputs`; and importing the smoke script does not start `main`.

## Guard and fixture contracts

- Official mutating smoke/load commands must exactly match a managed runner command; command chains, prefixes, suffixes, and pipes are rejected.
- Guarded source inventory covers `.js`, `.ts`, `.mjs`, and `.cjs` smoke/load/Admin paths.
- PostgreSQL target inspection parses TypeScript AST expressions, including escaped literals, concatenation, constant identifiers, and template interpolation. It rejects decoded `aarast` and `aarast_dev` targets without rejecting isolated smoke names.
- Database-client policy is module-specific. Allowlisted entrypoints may use only `@prisma/client`; `pg`, `postgres`, adapter imports, and all dynamic database imports are rejected. Prisma constructor aliases are tracked and constructor arguments are rejected.
- Environment aliases and mutations are guarded for direct properties, computed keys, `Object.assign`, and `Reflect.set`.
- Quote fixture cleanup runs transactionally, removes dependent operation records before fixture roots, and validates every saved output id after cleanup.
- Cleanliness protection keeps all fixture/golden path patterns, including TypeScript fixture paths, protected. The one explicit exception is the executable implementation entrypoint `backend/scripts/smoke/phase0-fixtures-smoke.js`, which is reviewed and tested as code rather than as a static test artifact.
- OpenWA remains an explicit, separately-confirmed external non-database contract; it is not silently treated as an isolated database smoke.

## Changed Phase 0 files

- `backend/package.json`
- `backend/scripts/smoke/phase0-source-guard.js`
- `backend/scripts/smoke/phase0-git-cleanliness.js`
- `backend/scripts/smoke/phase0-fixtures-smoke.js`
- `backend/test/phase0-guards.test.ts`
- `backend/test/support/phase0-postgres-support.js`
- `docs/SCRIPTS.md`
- `docs/superpowers/reports/2026-07-24-phase-0-baseline.md`

## Final verification evidence

| Check | Result |
| --- | --- |
| `node --test -r ts-node/register test/phase0-guards.test.ts` | PASS - 20/20 |
| `npx.cmd prisma validate` | PASS (with Prisma package-config deprecation warning) |
| Backend `npm.cmd run check` / `npm.cmd run build` | PASS / PASS |
| Backend `npm.cmd test` | PASS - pretest 38/38; main 371/371; 1 existing skip; posttest PASS |
| `npm.cmd run smoke:phase0-fixtures` | PASS - managed isolated PostgreSQL fixture create/cleanup |
| PostgreSQL count for `aarast_smoke%` after smoke | PASS - `0` |
| Flutter `flutter analyze` / `flutter test` | PASS - no issues / 721/721 |
| Admin `npm.cmd run typecheck` / `npm.cmd test` / `npm.cmd run build` | PASS / PASS 50/50 / PASS |
| `node .\scripts\docs-sync.mjs --check` / `node .\scripts\docs-verify.mjs` | PASS - 0 drift / 0 errors, 0 warnings |
| `git diff --check` | PASS |

The Admin test deliberately exercises an error boundary and prints its expected render-failure stack while still completing 50/50 tests successfully.

## Ten-point exit-evidence rubric

This is evidence for an independent reviewer, not a self-assigned readiness score.

| # | Exit condition | Evidence |
| --- | --- | --- |
| 1 | Scope contains no product, schema, migration, UI, or deployment change | PASS - focused Phase 0 paths only |
| 2 | Original state can be recovered | PASS - verified backup path, size, hash, and inventory recorded |
| 3 | Managed commands cannot be bypassed | PASS - exact-command behavioral tests |
| 4 | Permanent Aarast database targets are rejected | PASS - AST and decoded-target tests |
| 5 | Independent DB clients and env mutation aliases are rejected | PASS - module/alias/dynamic-import tests |
| 6 | Fixture creation and cleanup are transactional and ordered | PASS - behavioral tests and managed smoke |
| 7 | Cleanup validates all saved operation outputs and fails closed | PASS - behavioral tests and managed smoke |
| 8 | Test artifacts remain protected | PASS - positive TypeScript fixture test and exact entrypoint exception |
| 9 | Full backend, mobile, Admin, and documentation gates pass | PASS - results recorded above |
| 10 | Disposable smoke resources are absent after completion | PASS - post-smoke `aarast_smoke%` count is `0` |

## Data impact and rollback

- No permanent database, Redis namespace, media bucket, golden, or tracked product fixture was changed by the smoke run.
- No `prisma migrate reset`, `prisma db push`, or permanent database target was used.
- Rollback is a focused revert of the Phase 0 remediation commit range after independent review.
