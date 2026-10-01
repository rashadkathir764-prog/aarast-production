import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { validateStagingConfig } from './validate-config.mjs';

const compose = JSON.parse(execFileSync('docker', [
  'compose', '--env-file', 'deploy/staging/.env.example',
  '-f', 'deploy/staging/docker-compose.yml', 'config', '--format', 'json',
], { encoding: 'utf8' }));
const buildCompose = JSON.parse(execFileSync('docker', [
  'compose', '--env-file', 'deploy/staging/.env.example',
  '-f', 'deploy/staging/docker-compose.yml',
  '-f', 'deploy/staging/docker-compose.build.yml',
  'config', '--format', 'json',
], { encoding: 'utf8' }));

test('resolved staging topology is isolated and dependencies remain required', () => {
  assert.deepEqual(validateStagingConfig(compose, { allowExampleValues: true }), []);
  assert.equal(compose.name, 'aarast-full-staging-20261001');
  assert.equal(compose.services.backend.environment.NODE_ENV, 'production');
  assert.equal(compose.services.backend.environment.READINESS_REQUIRE_REDIS, 'true');
  assert.equal(compose.services.backend.environment.READINESS_REQUIRE_MEDIA, 'true');
  assert.equal(compose.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED, 'true');
  assert.equal(compose.services.backend.environment.AUTH_OTP_MODE, 'whatsapp');
});

test('build topology pins QA Admin and App Link inputs to staging origins', () => {
  assert.deepEqual(validateStagingConfig(buildCompose, { allowExampleValues: true }), []);
  const wrongHost = structuredClone(buildCompose);
  wrongHost.services['public-site'].build.args.STAGING_QA_INVITE_HOST = 'aarast.shadowgardn.com';
  assert.match(validateStagingConfig(wrongHost, { allowExampleValues: true }).join('\n'), /QA App Link host/);
});

test('preflight rejects example placeholders', () => {
  assert.match(validateStagingConfig(compose).join('\n'), /placeholder/);
});

test('preflight rejects foreign resource and production fallback mutations', () => {
  const cases = [
    (x) => { x.services.backend.environment.CORS_ORIGINS = 'https://aarast.shadowgardn.com'; },
    (x) => { x.services['admin-web'].environment.API_ORIGIN = x.services.backend.environment.INVITE_PUBLIC_ORIGIN; },
    (x) => { x.services.backend.environment.READINESS_REQUIRE_MEDIA = 'false'; },
    (x) => { x.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED = 'false'; },
    (x) => { x.services.backend.environment.AUTH_OTP_MODE = 'openwa'; },
    (x) => { x.services.backend.environment.FIREBASE_PROJECT_ID = 'aarast-d62e9'; },
    (x) => { x.services.backend.ports[0].host_ip = '0.0.0.0'; },
    (x) => { x.volumes.postgres_data.name = 'aarast-production_data'; },
    (x) => { x.services.postgres.volumes[0].source = 'aarast_aarast_db_data'; },
    (x) => { x.services.backend.environment.DATABASE_URL = x.services.migrate.environment.DATABASE_URL; },
    (x) => { x.services.backend.networks.production = null; },
  ];
  for (const change of cases) {
    const mutated = structuredClone(compose);
    change(mutated);
    assert.notDeepEqual(validateStagingConfig(mutated, { allowExampleValues: true }), []);
  }
});
