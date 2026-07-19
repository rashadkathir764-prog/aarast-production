import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const stagingDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(stagingDirectory, '..', '..');

test('staging owns scheduled atomic rotation with separate consumer files', async () => {
  const compose = await fs.readFile(
    path.join(stagingDirectory, 'docker-compose.yml'),
    'utf8',
  );
  const example = await fs.readFile(
    path.join(stagingDirectory, '.env.example'),
    'utf8',
  );

  assert.match(compose, /openwa-credential-rotator:/);
  assert.match(compose, /restart: on-failure/);
  assert.match(compose, /OPENWA_ROTATION_RETRY_SECONDS/);
  assert.match(compose, /OPENWA_BOOTSTRAP_LOCK_PATH/);
  assert.match(
    compose,
    /API_KEY_PREVIOUS_PEPPER: \$\{OPENWA_API_KEY_PREVIOUS_PEPPER:-\}/,
  );
  assert.match(compose, /backend-secret:\/run\/aarast\/staging/);
  assert.match(compose, /production-secret:\/run\/aarast\/production/);
  assert.match(compose, /OPENWA_CREDENTIAL_FILE: \/run\/aarast\/openwa\.env/);
  assert.doesNotMatch(compose, /\. \/run\/aarast\/openwa\.env/);
  assert.match(example, /^OPENWA_ROTATION_CHECK_SECONDS=/m);
  assert.match(example, /^OPENWA_ROTATION_RETRY_SECONDS=/m);
  assert.match(example, /^OPENWA_BOOTSTRAP_LOCK_STALE_SECONDS=/m);
  assert.doesNotMatch(example, /^OPENWA_API_KEY_PREVIOUS_PEPPER=/m);
});

test('production consumes only its encrypted dynamic credential directory', async () => {
  const compose = await fs.readFile(
    path.join(repositoryRoot, 'deploy', 'dokploy', 'docker-compose.yml'),
    'utf8',
  );
  const example = await fs.readFile(
    path.join(repositoryRoot, 'deploy', 'dokploy', '.env.example'),
    'utf8',
  );

  assert.match(compose, /OPENWA_CREDENTIAL_FILE: \/run\/aarast\/openwa\.env/);
  assert.match(compose, /OPENWA_PRODUCTION_CREDENTIAL_DIR/);
  assert.doesNotMatch(compose, /^\s+OPENWA_SESSION_ID:/m);
  assert.doesNotMatch(compose, /^\s+OPENWA_API_KEY:/m);
  assert.match(example, /^OPENWA_PRODUCTION_CREDENTIAL_DIR=/m);
  assert.doesNotMatch(example, /^OPENWA_SESSION_ID=/m);
  assert.doesNotMatch(example, /^OPENWA_API_KEY=/m);
});
