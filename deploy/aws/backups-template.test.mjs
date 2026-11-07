import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { test } from 'node:test';

// go-live (2026-11-07): AWS refused the daily-snapshot policy because its
// description had a comma; Data Lifecycle Manager takes letters, digits,
// spaces, `_` and `-` only (pattern [0-9A-Za-z _-]+, up to 500). The stack
// failed on its first creation, so the disk had no daily snapshot.
const template = readFileSync(resolve(import.meta.dirname, 'backups.yaml'), 'utf8');

test('the snapshot policy description is one AWS takes', () => {
  const policy = template.split(/^\s{2}DailySnapshots:\s*$/m)[1];
  assert.ok(policy, 'backups.yaml declares DailySnapshots');
  const description = policy.match(/^\s{6}Description:\s*(.+?)\s*$/m)?.[1];
  assert.ok(description, 'the policy has a description');
  assert.match(description, /^[0-9A-Za-z _-]{1,500}$/);
});
