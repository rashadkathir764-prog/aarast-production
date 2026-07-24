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
6 pass / 0 fail

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
| Phase 0 behavioral guards | PASS - 6/6 |
| Existing smoke isolation guards | PASS - 12/12 |
| Isolated PostgreSQL fixture smoke | PASS |
| Backend check | PASS |
| Backend build | PASS |
| Backend test | PASS - pretest 24/24; main 371/371, 1 existing skip; posttest cleanliness PASS |
| Docs sync | PASS - 0 drift |
| Docs verify | PASS - 0 errors, 0 warnings |
| Diff whitespace | PASS |

## Data impact and rollback

- No permanent database, Redis namespace, media bucket, golden, or tracked product fixture was modified.
- No `prisma migrate reset`, `prisma db push`, or permanent database target was used.
- Rollback is the focused revision commit revert.
