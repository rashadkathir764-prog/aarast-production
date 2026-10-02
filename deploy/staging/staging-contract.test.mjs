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
const revision = 'a'.repeat(40);
const buildOnly = JSON.parse(execFileSync('docker', [
  'compose', '-f', 'deploy/staging/docker-compose.build.yml', 'config', '--format', 'json',
], {
  encoding: 'utf8',
  env: {
    Path: process.env.Path,
    PATH: process.env.PATH ?? process.env.Path,
    PATHEXT: process.env.PATHEXT,
    ProgramFiles: process.env.ProgramFiles,
    ProgramData: process.env.ProgramData,
    HOMEDRIVE: process.env.HOMEDRIVE,
    HOMEPATH: process.env.HOMEPATH,
    SystemRoot: process.env.SystemRoot,
    USERPROFILE: process.env.USERPROFILE,
    HOME: process.env.HOME,
    APPDATA: process.env.APPDATA,
    LOCALAPPDATA: process.env.LOCALAPPDATA,
    DOCKER_CONFIG: process.env.DOCKER_CONFIG,
    TMP: process.env.TMP,
    TEMP: process.env.TEMP,
    STAGING_GIT_REVISION: revision,
    STAGING_BACKEND_IMAGE_ID: `aarast-staging-backend:${revision}`,
    STAGING_ADMIN_IMAGE_ID: `aarast-staging-admin:${revision}`,
    STAGING_PUBLIC_SITE_IMAGE_ID: `aarast-staging-invite:${revision}`,
    STAGING_API_ORIGIN: 'https://api.proof.example.org',
    STAGING_INVITE_ORIGIN: 'https://invite.proof.example.org',
    STAGING_QA_INVITE_HOST: 'invite.proof.example.org',
    STAGING_QA_APPLICATION_ID: 'com.aarast.aarast_mobile.qa',
    STAGING_QA_CERT_FINGERPRINT: Array(32).fill('AA').join(':'),
  },
}));

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
  assert.deepEqual(validateStagingConfig(buildCompose, {
    allowExampleValues: true, allowBuildTopology: true,
  }), []);
  const wrongHost = structuredClone(buildCompose);
  wrongHost.services['public-site'].build.args.STAGING_QA_INVITE_HOST = 'aarast.shadowgardn.com';
  assert.match(validateStagingConfig(wrongHost, {
    allowExampleValues: true, allowBuildTopology: true,
  }).join('\n'), /QA App Link host/);
});

test('temporary jobs have enforced Compose resource limits', () => {
  for (const [name, memory, cpus] of [
    ['postgres-roles', '134217728', 0.20],
    ['media-init', '134217728', 0.20],
    ['migrate', '805306368', 1.00],
  ]) {
    assert.equal(compose.services[name].mem_limit, memory, `${name} memory`);
    assert.equal(compose.services[name].cpus, cpus, `${name} CPU`);
    const weakened = structuredClone(compose);
    delete weakened.services[name].mem_limit;
    assert.match(validateStagingConfig(weakened, { allowExampleValues: true }).join('\n'),
      new RegExp(name));
    const withoutCpu = structuredClone(compose);
    delete withoutCpu.services[name].cpus;
    assert.match(validateStagingConfig(withoutCpu, { allowExampleValues: true }).join('\n'),
      new RegExp(name));
  }
});

test('server deployment topology consumes prebuilt SHA-tagged images only', () => {
  for (const name of ['backend', 'admin-web', 'public-site']) {
    assert.equal(compose.services[name].build, undefined, `${name} server build`);
    assert.equal(compose.services[name].pull_policy, 'never', `${name} pull policy`);
    const withBuild = structuredClone(compose);
    withBuild.services[name].build = { context: '.' };
    assert.match(validateStagingConfig(withBuild, { allowExampleValues: true }).join('\n'),
      /build/);
  }
});

test('off-server build topology needs no runtime database, OTP or Firebase secrets', () => {
  assert.deepEqual(Object.keys(buildOnly.services).sort(), ['admin-web', 'backend', 'public-site']);
  for (const name of ['backend', 'admin-web', 'public-site']) {
    assert.equal(buildOnly.services[name].image.endsWith(`:${revision}`), true);
    assert.equal(buildOnly.services[name].build.args.AARAST_GIT_REVISION, revision);
    assert.equal(buildOnly.services[name].environment, undefined);
  }
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
