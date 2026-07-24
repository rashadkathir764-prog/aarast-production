# Phase 0 baseline and test isolation

Date: 2026-07-24
Branch: `codex/aarast-full-remediation`
Merge base: `87a1f0df6c7ec8cd4280991a974b42686268c819`

## Result

PASS. Phase 0 remains test-isolation infrastructure only: no product logic, schema, migration, deployment, Admin behavior, or Flutter UI changes.

## Review remediation

The review found that the original guard was too permissive and fixture checks were mostly structural. This revision corrects those gaps.

- Official mutating smoke/load commands now use an exact command allowlist. Command chains, prefixes, suffixes, and pipes do not pass.
- The source scan inventories `.js`, `.ts`, `.mjs`, and `.cjs` files under Backend smoke/load and Admin smoke paths.
- `smoke:openwa-otp` is an explicit external, non-database contract. Its exact command and literal `OPENWA_SMOKE_CONFIRM=I_ACCEPT_REAL_WHATSAPP_SEND` confirmation are required, and the source guard rejects database access in the script.
- The fixture wrapper validates the managed environment and invokes cleanup through `finally`.
- Quote fixture cleanup runs in one transaction and removes messages, attachments, events, reports, notifications, outbox records, plan-provider links, payment ledger rows, schedules, costs, quote data, participants, conversation, and fixture roots. Its transaction-local ledger purge setting matches the existing account-deletion maintenance path and changes no product behavior.
- The cleanliness guard checks all tracked paths whose names identify fixtures or goldens, including filename patterns outside a literal `fixtures/` directory.

## TDD evidence

RED before remediation:

```text
node --test -r ts-node/register test/phase0-guards.test.ts
0 pass / 6 fail
```

The failures covered runner-command bypasses, extension inventory, the external OpenWA contract, `finally` cleanup, operation-output cleanup ordering, and fixture filename cleanliness coverage.

GREEN after remediation:

```text
node --test -r ts-node/register test/phase0-guards.test.ts
13 pass / 0 fail

npm.cmd run smoke:phase0-fixtures
PASS - Phase 0 PostgreSQL fixtures create operation outputs and clean them in finally.
```

The second command ran through the managed isolated runner, created a run-owned temporary PostgreSQL database, applied migrations there, exercised the fixture shapes and operation outputs, and cleaned the run-owned resources.

## Changed files

- `backend/package.json`
- `backend/scripts/smoke/phase0-source-guard.js`
- `backend/scripts/smoke/phase0-git-cleanliness.js`
- `backend/scripts/smoke/phase0-fixtures-smoke.js`
- `backend/test/phase0-guards.test.ts`
- `backend/test/support/phase0-postgres-support.js`
- `docs/SCRIPTS.md`
- `docs/superpowers/reports/2026-07-24-phase-0-baseline.md`

## Verification

| Check | Result |
| --- | --- |
| Phase 0 behavioral guards | PASS - 13/13 |
| Existing smoke isolation guards | PASS - 12/12 |
| Isolated PostgreSQL fixture smoke | PASS |
| Backend check | PASS |
| Backend build | PASS |
| Backend test | PASS - pretest 31/31; main 371/371, 1 existing skip; posttest cleanliness PASS |
| Docs sync | PASS - 0 drift |
| Docs verify | PASS - 0 errors, 0 warnings |
| Diff whitespace | PASS |

## Data impact and rollback

- No permanent database, Redis namespace, media bucket, golden, or tracked product fixture was modified.
- No `prisma migrate reset`, `prisma db push`, or permanent database target was used.
- Rollback is the focused revision commit revert.

## Second review remediation

RED was observed with `node --test -r ts-node/register test/phase0-guards.test.ts`: 6 failures for decoded PostgreSQL database targets, notification outbox cleanup, atomic permission fixture creation, OTP cleanup by phone, helper protection, and dependent-row smoke coverage. A follow-up RED was observed for raw/commented permanent URLs and observable barrier arrival/release ordering.

GREEN: the same guard suite passes 13/13. The guard parses extracted PostgreSQL URL pathnames after decoding and rejects `aarast` and `aarast_dev` in raw or encoded form without rejecting isolated smoke names or non-PostgreSQL URLs. Permission fixtures are one transaction; notification IDs are collected before notification deletion and their `aggregateType: notification` outbox records are removed; user OTP cleanup uses the actual phones read before user deletion. The isolated fixture smoke now asserts all specified dependent tables are empty after cleanup.

## Third review remediation

RED was observed for escaped/concatenated PostgreSQL URLs, independent direct database clients and datasource overrides, multiple concurrent failures, cleanup before slow settlement, and the expanded fixture table inventory.

GREEN: the TypeScript AST guard evaluates literals, escaped strings, constant concatenations, and constant identifiers without `eval`. It also blocks unapproved direct database client imports/requires, aliases, datasource overrides, and writes to `DATABASE_URL` or `SMOKE_DATABASE_URL`; managed direct Prisma entrypoints are explicitly allowlisted and cannot use constructor arguments. Concurrent fixture operations now settle through `Promise.allSettled` before rethrowing one original error or an `AggregateError`. The isolated smoke checks every fixture and operation row by saved IDs or actual phones.

### Current full gate evidence

| Command | Result |
| --- | --- |
| `npx.cmd prisma validate` | PASS |
| Backend `npm.cmd run check` / `npm.cmd run build` | PASS / PASS |
| Backend `npm.cmd test` | PASS - pretest 35/35; main 371/371, 1 existing skip; posttest PASS |
| Backend `npm.cmd run smoke:phase0-fixtures` | PASS - managed isolated PostgreSQL |
| Flutter `flutter analyze` | PASS - no issues |
| Flutter `flutter test` | PASS - 721/721 |
| Admin `npm.cmd run typecheck` / `npm.cmd test` / `npm.cmd run build` | PASS / PASS 50/50 / PASS |
| `node .\\scripts\\docs-sync.mjs --check` / `node .\\scripts\\docs-verify.mjs` | PASS - 0 drift / 0 errors, 0 warnings |
| `git diff --check` | PASS |

`git status --short` reports seven Flutter generated registrant paths after the requested Flutter gates. Every worktree blob hash exactly equals its index hash, so there is no content delta; they are excluded from the focused Phase 0 commit.
