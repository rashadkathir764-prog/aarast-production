import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

// RA-AD-09: eight audited admin writes had no words in «سجل التدقيق» and
// showed «إجراء آخر» with no target. Every admin write route of the server's
// routes table (docs/backend/API_CONTRACT.md, generated from the controllers
// and held current by docs-sync --check) has its words in AuditLogsPage.

const here = path.dirname(fileURLToPath(import.meta.url));
const contract = readFileSync(path.join(here, '../../docs/backend/API_CONTRACT.md'), 'utf8');
const page = readFileSync(path.join(here, '../src/features/audit/AuditLogsPage.tsx'), 'utf8');

const writes = [...contract.matchAll(/^\| (POST|PATCH|PUT|DELETE) \| `(\/admin\/[^`]+)` \|/gm)].map(
  ([, method, route]) => ({ method, route }),
);
// Each entry of ACTIONS: ['METHOD', /^...$/, { ... }]
const actions = [...page.matchAll(/\['(POST|PATCH|PUT|DELETE)', \/(\^[^\n]*?\$)\/, \{/g)].map(
  ([, method, source]) => ({ method, pattern: new RegExp(source) }),
);

test('the scan reads the routes table and the page', () => {
  assert.ok(writes.length > 40, `admin writes found: ${writes.length}`);
  assert.ok(actions.length > 30, `audit words found: ${actions.length}`);
});

test('every admin write the server records has its words', () => {
  const unnamed = writes
    .filter(({ method, route }) => !actions.some((action) => action.method === method && action.pattern.test(route)))
    .map(({ method, route }) => `${method} ${route}`);
  assert.deepEqual(unnamed, []);
});
