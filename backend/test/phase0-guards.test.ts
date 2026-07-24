import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const backendRoot = join(__dirname, '..');

test('phase zero supplies isolated source and PostgreSQL fixture guards', () => {
  const sourceGuard = join(
    backendRoot,
    'scripts',
    'smoke',
    'phase0-source-guard.js',
  );
  const fixtureHelper = join(
    backendRoot,
    'test',
    'support',
    'phase0-postgres-fixtures.js',
  );

  assert.equal(existsSync(sourceGuard), true, 'missing Phase 0 source guard');
  assert.equal(existsSync(fixtureHelper), true, 'missing Phase 0 PostgreSQL fixtures');

  const fixtureSource = readFileSync(fixtureHelper, 'utf8');
  for (const helper of [
    'createSuperAdminPairFixture',
    'createOtpAttemptFixture',
    'createQuoteDecisionFixture',
    'createPermissionRevocationFixture',
    'runConcurrentlyAfterBarrier',
  ]) {
    assert.match(fixtureSource, new RegExp(`function ${helper}\\b`));
  }
  assert.match(fixtureSource, /assertManagedSmokeEnvironment/);
});

test('the backend suite runs Phase 0 source and tree cleanliness guards', () => {
  const packageJson = JSON.parse(
    readFileSync(join(backendRoot, 'package.json'), 'utf8'),
  );
  assert.match(packageJson.scripts.pretest, /phase0-source-guard\.js/);
  assert.match(packageJson.scripts.pretest, /phase0-guards\.test\.ts/);
  assert.match(packageJson.scripts.posttest, /phase0-git-cleanliness\.js/);
});
