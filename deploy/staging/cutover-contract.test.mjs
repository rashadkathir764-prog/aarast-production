import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { test } from 'node:test';
import { requireBuildApiOrigin } from '../../admin-web/scripts/staging-build-origin.mjs';
import { buildStagingInvite } from './public-site/build.mjs';
import { validateStagingConfig, cutoverMediaLabels } from './validate-config.mjs';

const profile = 'aarast-controlled-cutover';
const api = 'https://aarast-api.shadowgardn.com';
const invite = 'https://aarast.shadowgardn.com';
const fixture = JSON.parse(execFileSync('docker', [
  'compose', '--env-file', 'deploy/staging/.env.example',
  '-f', 'deploy/staging/docker-compose.yml', 'config', '--format', 'json',
], { encoding: 'utf8' }));
function cutover() {
  const x = structuredClone(fixture);
  const backend = x.services.backend.environment;
  backend.AARAST_STAGING_ROUTE_PROFILE = profile;
  backend.DATABASE_URL = backend.DATABASE_URL.replace('@postgres:', '@aarast-staging-postgres:');
  backend.REDIS_URL = 'redis://aarast-staging-redis:6379';
  backend.AARAST_MEDIA_ENDPOINT = 'http://aarast-staging-media:9000';
  for (const name of ['postgres', 'redis', 'media']) {
    x.services[name].networks.private = { aliases: [`aarast-staging-${name}`] };
  }
  backend.CORS_ORIGINS = 'https://aarast-admin.shadowgardn.com';
  backend.INVITE_PUBLIC_ORIGIN = invite;
  backend.AARAST_MEDIA_SIGNED_ENDPOINT = 'https://aarast-media.shadowgardn.com';
  backend.AARAST_MEDIA_PUBLIC_BASE_URL = `${backend.AARAST_MEDIA_SIGNED_ENDPOINT}/${backend.AARAST_MEDIA_BUCKET}`;
  Object.assign(x.services['admin-web'].environment, {
    API_ORIGIN: api, ADMIN_PUBLIC_ORIGIN: backend.CORS_ORIGINS, CORS_ORIGINS: backend.CORS_ORIGINS,
  });
  x.networks.edge = { name: 'aarast-production-ytxoik_aarast_internal', external: true };
  for (const [name, alias, port] of [
    ['backend', 'aarast-backend-prod', '8093'],
    ['admin-web', 'aarast-admin-web-prod', '8094'],
    ['public-site', 'aarast-public-site-prod', '8095'],
  ]) {
    x.services[name].networks.edge = { aliases: [alias] };
    x.services[name].ports[0].published = port;
  }
  x.services.media.ports = [];
  return x;
}

test('Admin accepts the established Aarast API only through explicit controlled cutover', () => {
  assert.equal(requireBuildApiOrigin('staging', api, profile), api);
  assert.throws(() => requireBuildApiOrigin('staging', api), /distinct/);
  assert.throws(() => requireBuildApiOrigin('staging', 'https://other.example.org', profile));
  assert.throws(() => requireBuildApiOrigin('staging', api, 'unapproved'));
});
test('Invite cutover retains the QA package, scheme and signing requirement', () => {
  const out = mkdtempSync(resolve(tmpdir(), 'aarast-cutover-'));
  const options = { source: resolve('deploy/public-site'), out, origin: invite,
    inviteHost: 'aarast.shadowgardn.com', packageName: 'com.aarast.aarast_mobile.qa',
    fingerprint: Array(32).fill('AA').join(':'), routeProfile: profile };
  try {
    buildStagingInvite(options);
    assert.throws(() => buildStagingInvite({ ...options, routeProfile: 'isolated' }));
    assert.throws(() => buildStagingInvite({ ...options, origin: 'https://other.example.org', inviteHost: 'other.example.org' }));
    assert.throws(() => buildStagingInvite({ ...options, packageName: 'com.aarast.aarast_mobile' }));
    assert.throws(() => buildStagingInvite({ ...options, fingerprint: '' }));
  } finally { rmSync(out, { recursive: true, force: true }); }
});
test('cutover is an exact route/port/network contract, never permission to reuse data or integrations', () => {
  assert.deepEqual(validateStagingConfig(cutover(), { allowExampleValues: true }), []);
  for (const mutate of [
    x => { delete x.services.backend.environment.AARAST_STAGING_ROUTE_PROFILE; },
    x => { x.services.backend.environment.AARAST_STAGING_ROUTE_PROFILE = 'unknown'; },
    x => { x.networks.edge.name = 'abdo_default'; },
    x => { x.services.backend.ports[0].published = '443'; },
    x => { x.services.backend.networks.edge.aliases = ['abdo']; },
    x => { x.services.media.ports = [{ host_ip: '127.0.0.1', published: '9000', target: 9000 }]; },
    x => { x.services.backend.environment.INVITE_PUBLIC_ORIGIN = 'https://aarast.shadowgardn.com.evil.example'; },
    x => { x.services.backend.environment.REDIS_URL = 'redis://aarast-production:6379'; },
    x => { x.services.backend.environment.DATABASE_URL = x.services.backend.environment.DATABASE_URL.replace('@aarast-staging-postgres:', '@postgres:'); },
    x => { x.services.backend.environment.REDIS_URL = 'redis://redis:6379'; },
    x => { x.services.backend.environment.AARAST_MEDIA_ENDPOINT = 'http://media:9000'; },
    x => { x.volumes.postgres_data.name = 'aarast-production-ytxoik_aarast_postgres_data'; },
    x => { x.services.backend.environment.FIREBASE_PROJECT_ID = 'aarast-d62e9'; },
    x => { x.services.backend.environment.OPENWA_SESSION_ID = 'production'; },
  ]) {
    const x = cutover(); mutate(x);
    assert.notDeepEqual(validateStagingConfig(x, { allowExampleValues: true }), []);
  }
});
test('actual cutover overlays render without server builds and preserve private data/integration boundaries', () => {
  const resolved = JSON.parse(execFileSync('docker', [
    'compose', '--env-file', 'deploy/staging/.env.example',
    '--env-file', 'deploy/staging/phone.env.example',
    '--env-file', 'deploy/staging/cutover.env.example',
    '-f', 'deploy/staging/docker-compose.yml',
    '-f', 'deploy/staging/docker-compose.phone.yml',
    '-f', 'deploy/staging/docker-compose.cutover.yml',
    'config', '--format', 'json',
  ], { encoding: 'utf8' }));
  assert.deepEqual(validateStagingConfig(resolved, { allowExampleValues: true, phoneAcceptance: true }), []);
  assert.deepEqual(resolved.services.media.labels, cutoverMediaLabels);
  for (const mutate of [
    x => { x.networks.otp_transport.name = 'aarast-openwa-otp-staging_default'; },
    x => { x.services.postgres.networks.otp_transport = null; },
    x => { x.services.media.labels['traefik.http.routers.abdo.rule'] = 'Host(`abdo.example.org`)'; },
    x => { x.services.backend.build = { context: '.' }; },
  ]) {
    const x = structuredClone(resolved); mutate(x);
    assert.notDeepEqual(validateStagingConfig(x, { allowExampleValues: true, phoneAcceptance: true }), []);
  }
  const built = JSON.parse(execFileSync('docker', [
    'compose', '--env-file', 'deploy/staging/.env.example',
    '--env-file', 'deploy/staging/phone.env.example',
    '--env-file', 'deploy/staging/cutover.env.example',
    '-f', 'deploy/staging/docker-compose.yml', '-f', 'deploy/staging/docker-compose.phone.yml',
    '-f', 'deploy/staging/docker-compose.cutover.yml', '-f', 'deploy/staging/docker-compose.build.yml',
    'config', '--format', 'json',
  ], { encoding: 'utf8' }));
  assert.deepEqual(validateStagingConfig(built, {
    allowExampleValues: true, phoneAcceptance: true, allowBuildTopology: true,
  }), []);
});

test('cutover Backend uses unique private aliases even when the legacy edge exports generic service names', () => {
  const resolved = JSON.parse(execFileSync('docker', [
    'compose', '--env-file', 'deploy/staging/.env.example',
    '--env-file', 'deploy/staging/phone.env.example',
    '--env-file', 'deploy/staging/cutover.env.example',
    '-f', 'deploy/staging/docker-compose.yml',
    '-f', 'deploy/staging/docker-compose.phone.yml',
    '-f', 'deploy/staging/docker-compose.cutover.yml', 'config', '--format', 'json',
  ], { encoding: 'utf8' }));
  const env = resolved.services.backend.environment;
  assert.equal(new URL(env.DATABASE_URL).hostname, 'aarast-staging-postgres');
  assert.equal(env.REDIS_URL, 'redis://aarast-staging-redis:6379');
  assert.equal(env.AARAST_MEDIA_ENDPOINT, 'http://aarast-staging-media:9000');
  for (const name of ['postgres', 'redis', 'media']) {
    assert.ok(resolved.services[name].networks.private.aliases.includes(`aarast-staging-${name}`));
    const missing = structuredClone(resolved);
    delete missing.services[name].networks.private.aliases;
    assert.ok(validateStagingConfig(missing, { allowExampleValues: true, phoneAcceptance: true })
      .some(error => error.includes('unique private DNS')));
  }
});
