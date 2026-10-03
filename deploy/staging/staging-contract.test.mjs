import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { validateOpenWaStagingConfig, validateStagingConfig } from './validate-config.mjs';

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
const phoneCompose = JSON.parse(execFileSync('docker', [
  'compose', '--env-file', 'deploy/staging/.env.example',
  '--env-file', 'deploy/staging/phone.env.example',
  '-f', 'deploy/staging/docker-compose.yml',
  '-f', 'deploy/staging/docker-compose.phone.yml', 'config', '--format', 'json',
], { encoding: 'utf8' }));
const openWaCompose = JSON.parse(execFileSync('docker', [
  'compose', '--env-file', 'deploy/staging/openwa.env.example',
  '-f', 'deploy/staging/docker-compose.openwa.yml', 'config', '--format', 'json',
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
  assert.equal(compose.services.backend.environment.AARAST_DEPLOYMENT_TIER, 'staging');
  assert.equal(compose.services.backend.environment.READINESS_REQUIRE_REDIS, 'true');
  assert.equal(compose.services.backend.environment.READINESS_REQUIRE_MEDIA, 'true');
  assert.equal(compose.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED, 'false');
  assert.equal(compose.services.backend.environment.AUTH_OTP_MODE, 'disabled');
  assert.equal(compose.services.backend.environment.FIREBASE_PROJECT_ID, undefined);
  assert.equal(compose.services.backend.environment.GOOGLE_APPLICATION_CREDENTIALS, undefined);
  assert.equal(compose.services.backend.environment.WHATSAPP_ACCESS_TOKEN, undefined);
  assert.equal(compose.services.backend.volumes, undefined);
  assert.match(compose.services.backend.command.join('\n'),
    /if \[ "\$\$\{PUSH_NOTIFICATIONS_ENABLED\}" = "true" \]; then\s+node scripts\/prod\/assert-firebase-credentials\.cjs/);
});

test('Core staging accepts absent external integrations and rejects unsafe enablement', () => {
  const core = structuredClone(compose);
  core.services.backend.environment.AUTH_OTP_MODE = 'disabled';
  core.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED = 'false';
  for (const key of Object.keys(core.services.backend.environment)) {
    if (key.startsWith('WHATSAPP_') || key === 'FIREBASE_PROJECT_ID' ||
        key === 'GOOGLE_APPLICATION_CREDENTIALS') {
      delete core.services.backend.environment[key];
    }
  }
  delete core.services.backend.volumes;
  assert.deepEqual(validateStagingConfig(core, { allowExampleValues: true }), []);

  const missingFirebase = structuredClone(core);
  missingFirebase.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED = 'true';
  assert.notDeepEqual(validateStagingConfig(missingFirebase, { allowExampleValues: true }), []);

  const withoutFirebasePreflight = structuredClone(core);
  withoutFirebasePreflight.services.backend.command = ['/bin/sh', '-ec',
    'node scripts/prod/assert-database-identity.cjs\nexec node dist/main.js'];
  assert.match(validateStagingConfig(withoutFirebasePreflight, {
    allowExampleValues: true,
  }).join('\n'), /Firebase credential preflight/);

  const missingMeta = structuredClone(core);
  missingMeta.services.backend.environment.AUTH_OTP_MODE = 'whatsapp';
  assert.notDeepEqual(validateStagingConfig(missingMeta, { allowExampleValues: true }), []);

  const devOtp = structuredClone(core);
  devOtp.services.backend.environment.AUTH_OTP_MODE = 'dev';
  assert.notDeepEqual(validateStagingConfig(devOtp, { allowExampleValues: true }), []);

  const sharedOpenWa = structuredClone(core);
  sharedOpenWa.services.backend.environment.OPENWA_SESSION_ID = 'production-session';
  assert.notDeepEqual(validateStagingConfig(sharedOpenWa, { allowExampleValues: true }), []);

  const productionOrigin = structuredClone(core);
  productionOrigin.services.backend.environment.INVITE_PUBLIC_ORIGIN =
    'https://aarast.shadowgardn.com';
  assert.notDeepEqual(validateStagingConfig(productionOrigin, { allowExampleValues: true }), []);

  const wrongRuntimeIdentity = structuredClone(core);
  wrongRuntimeIdentity.services.backend.environment.AARAST_DB_EXPECTED_ROLE = 'production_runtime';
  wrongRuntimeIdentity.services['postgres-roles'].environment.AARAST_DB_RUNTIME_USER =
    'production_runtime';
  assert.notDeepEqual(validateStagingConfig(wrongRuntimeIdentity, { allowExampleValues: true }), []);
});

test('phone integration overlay uses separate Staging Firebase and OpenWA contracts', () => {
  assert.deepEqual(validateStagingConfig(phoneCompose, {
    allowExampleValues: true, phoneAcceptance: true,
  }), []);
  const backend = phoneCompose.services.backend;
  assert.equal(backend.environment.AUTH_OTP_MODE, 'openwa');
  assert.equal(backend.environment.PUSH_NOTIFICATIONS_ENABLED, 'true');
  assert.equal(backend.environment.FIREBASE_PROJECT_ID, 'aarast-staging-qa');
  assert.equal(backend.environment.OPENWA_CREDENTIAL_FILE,
    '/run/aarast-openwa-staging/openwa.env');
  assert.equal(backend.volumes.length, 2);
  for (const [mutate, expected] of [
    [(x) => { x.services.backend.environment.FIREBASE_PROJECT_ID = 'aarast-d62e9'; }, /Firebase/],
    [(x) => { delete x.services.backend.environment.GOOGLE_APPLICATION_CREDENTIALS; }, /Firebase/],
    [(x) => { x.services.backend.environment.OPENWA_BASE_URL = 'http://aarast-openwa-otp:2785'; }, /OpenWA/],
    [(x) => { x.services.backend.environment.OPENWA_CREDENTIAL_FILE = '/run/aarast/openwa.env'; }, /OpenWA/],
    [(x) => { x.services.backend.environment.AUTH_OTP_MODE = 'whatsapp'; }, /OpenWA/],
    [(x) => { x.services.backend.volumes[1].source = '/var/lib/aarast-otp-staging/secure/backend-secret'; }, /OpenWA/],
  ]) {
    const mutated = structuredClone(phoneCompose);
    mutate(mutated);
    assert.match(validateStagingConfig(mutated, {
      allowExampleValues: true, phoneAcceptance: true,
    }).join('\n'), expected);
  }
});

test('independent OpenWA stack cannot mount the old shared session or credentials', () => {
  assert.deepEqual(validateOpenWaStagingConfig(openWaCompose, { allowExampleValues: true }), []);
  assert.match(validateOpenWaStagingConfig(openWaCompose).join('\n'),
    /immutable|placeholder/i);
  assert.equal(openWaCompose.name, 'aarast-full-staging-openwa-test-release');
  assert.deepEqual(Object.keys(openWaCompose.services).sort(),
    ['openwa', 'openwa-bootstrap', 'openwa-credential-rotator', 'storage-init']);
  assert.equal(openWaCompose.services.openwa.mem_limit, '2147483648');
  assert.deepEqual(openWaCompose.services.openwa.ports.map((port) => port.host_ip),
    ['127.0.0.1']);
  assert.equal(openWaCompose.services['openwa-bootstrap'].environment.OPENWA_BOOTSTRAP_PROFILE,
    'isolated-staging');
  assert.equal(openWaCompose.services['openwa-credential-rotator'].environment.OPENWA_BOOTSTRAP_PROFILE,
    'isolated-staging');
  assert.equal(openWaCompose.services['openwa-bootstrap'].environment.OPENWA_SESSION_NAME,
    'aarast-full-staging-test-release');
  for (const service of Object.values(openWaCompose.services)) {
    assert.equal(service.build, undefined);
    for (const volume of service.volumes ?? []) {
      assert.equal(/aarast-otp-staging|\/run\/aarast\/production/i.test(
        `${volume.source} ${volume.target}`), false);
    }
  }
  for (const name of Object.keys(openWaCompose.networks)) {
    assert.match(openWaCompose.networks[name].name,
      /^aarast_full_staging_openwa_test_release_/);
  }
  const sharedMount = structuredClone(openWaCompose);
  sharedMount.services.openwa.volumes[0].source =
    '/var/lib/aarast-otp-staging/secure/openwa';
  assert.match(validateOpenWaStagingConfig(sharedMount, { allowExampleValues: true }).join('\n'),
    /old shared|dedicated/i);
  const sharedSession = structuredClone(openWaCompose);
  sharedSession.services['openwa-bootstrap'].environment.OPENWA_SESSION_NAME =
    'aarast-otp-staging';
  assert.match(validateOpenWaStagingConfig(sharedSession, { allowExampleValues: true }).join('\n'),
    /session/i);
  const publicPort = structuredClone(openWaCompose);
  publicPort.services.openwa.ports[0].host_ip = '0.0.0.0';
  assert.match(validateOpenWaStagingConfig(publicPort, { allowExampleValues: true }).join('\n'),
    /loopback/i);
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

test('media initializer Go runtime stays within the unchanged hard resource limit', () => {
  const expected = { GOMEMLIMIT: '96MiB', GOMAXPROCS: '1', GOGC: '25' };
  for (const [key, value] of Object.entries(expected)) {
    assert.equal(compose.services['media-init'].environment[key], value);
    const weakened = structuredClone(compose);
    delete weakened.services['media-init'].environment[key];
    assert.ok(validateStagingConfig(weakened, { allowExampleValues: true })
      .some((error) => error.includes('media-init Go runtime')));
  }
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
    (x) => { x.services.backend.environment.PUSH_NOTIFICATIONS_ENABLED = 'true'; },
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
