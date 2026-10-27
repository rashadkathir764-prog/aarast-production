import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { test } from 'node:test';

const image = 'sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d';
const ip = '3.121.198.183';
const env = {
  ...process.env,
  AARAST_RELEASE: 'a'.repeat(40), AWS_REGION: 'eu-central-1',
  AARAST_API_HOST: 'api.proof.example.org', AARAST_ADMIN_HOST: 'admin.proof.example.org',
  AARAST_SITE_HOST: 'proof.example.org', AARAST_DIRECT_API_IP: ip,
  AARAST_MEDIA_BUCKET: 'proof-media', OPENWA_LINK_TARGET: 'operator@proof.example.org',
  POSTGRES_DB: 'proof', POSTGRES_OWNER_USER: 'owner', POSTGRES_OWNER_PASSWORD: 'proof-only',
  AARAST_DB_MIGRATOR_USER: 'migrator', AARAST_DB_MIGRATOR_PASSWORD: 'proof-only',
  AARAST_DB_RUNTIME_USER: 'runtime', AARAST_DB_RUNTIME_PASSWORD: 'proof-only',
  AARAST_DB_MIGRATOR_DATABASE_URL: 'postgresql://migrator:proof-only@postgres/proof',
  AARAST_DB_RUNTIME_DATABASE_URL: 'postgresql://runtime:proof-only@postgres/proof',
  JWT_ACCESS_SECRET: 'a'.repeat(64), AUTH_LOGIN_THROTTLE_PEPPER: 'b'.repeat(64),
};

function allNodes(value) {
  if (!value || typeof value !== 'object') return [];
  return [value, ...Object.values(value).flatMap(allNodes)];
}

test('direct IP uses public short-lived ACME, no-SNI selection, and the existing API upstream', () => {
  const args = ['run', '--rm', '--network', 'none'];
  for (const key of ['AARAST_API_HOST', 'AARAST_ADMIN_HOST', 'AARAST_SITE_HOST', 'AARAST_DIRECT_API_IP']) {
    args.push('-e', `${key}=${env[key]}`);
  }
  args.push('-v', `${resolve('deploy/aws/Caddyfile')}:/etc/caddy/Caddyfile:ro`, image,
    'caddy', 'adapt', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile');
  const c = JSON.parse(execFileSync('docker', args, { encoding: 'utf8' }));
  const nodes = allNodes(c);
  const policy = (c.apps.tls?.automation?.policies ?? []).find((x) => x.subjects?.includes(ip));
  assert.ok(policy, 'The public IP needs its own certificate automation policy');
  assert.equal(policy.issuers.length, 1);
  assert.equal(policy.issuers[0].module, 'acme');
  assert.equal(policy.issuers[0].ca, 'https://acme-v02.api.letsencrypt.org/directory');
  assert.equal(policy.issuers[0].profile, 'shortlived');
  assert.equal(policy.issuers[0].challenges['tls-alpn'].disabled, true);
  assert.ok(nodes.some((x) => x.default_sni === ip), 'IP clients may omit TLS SNI');
  const route = nodes.find((x) => x.match?.some((m) => m.host?.includes(ip)));
  assert.ok(route);
  const upstreams = allNodes(route).filter((x) => x.handler === 'reverse_proxy').flatMap((x) => x.upstreams);
  assert.deepEqual(upstreams, [{ dial: 'backend:3000' }]);
  for (const host of [env.AARAST_API_HOST, env.AARAST_ADMIN_HOST, env.AARAST_SITE_HOST]) {
    assert.ok(nodes.some((x) => x.host?.includes(host)), `Existing host ${host} must remain`);
  }
});

test('Compose supplies the direct IP explicitly and rejects absent configuration', () => {
  const args = ['compose', '-f', 'deploy/aws/compose.yml', 'config', '--format', 'json'];
  const c = JSON.parse(execFileSync('docker', args, { env, encoding: 'utf8' }));
  assert.equal(c.services.caddy.environment.AARAST_DIRECT_API_IP, ip);
  assert.equal(c.services.caddy.image, `caddy:2.10-alpine@${image}`);
  assert.equal(c.services.caddy.mem_limit, '100663296');
  const absent = { ...env };
  delete absent.AARAST_DIRECT_API_IP;
  const result = spawnSync('docker', args, { env: absent, encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /AARAST_DIRECT_API_IP/);
});

test('existing protected env is extended once; invalid or changed IP never alters it', () => {
  const script = resolve('deploy/aws/host/prepare-env.sh');
  assert.match(readFileSync(script, 'utf8'), /AARAST_DIRECT_API_IP/, 'The host provisioner must persist the direct API IP');
  const root = mkdtempSync(join(tmpdir(), 'aarast-direct-ip-'));
  const file = join(root, 'protected.env');
  const original = 'JWT_ACCESS_SECRET=proof-existing-value\nPOSTGRES_OWNER_PASSWORD=proof-existing-value\n';
  const bash = process.platform === 'win32' ? 'C:/Program Files/Git/bin/bash.exe' : 'bash';
  let prefix = '';
  if (process.platform === 'win32') {
    const bin = join(root, 'bin');
    mkdirSync(bin);
    const python = execFileSync('python', ['-c', 'import sys; print(sys.executable)'], { encoding: 'utf8' }).trim().replaceAll('\\', '/');
    writeFileSync(join(bin, 'python3'), `#!/bin/sh\nexec "${python}" "$@"\n`);
    const bashBin = bin.replaceAll('\\', '/').replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`);
    prefix = `export PATH="${bashBin}:$PATH"; `;
  }
  function invoke(value) {
    return spawnSync(bash, ['-c', `${prefix}exec bash "$1" proof.example.org proof-media eu-central-1 operator@proof.example.org "$2"`,
      'proof', script.replaceAll('\\', '/'), value], {
      env: { ...process.env, AARAST_ENV_FILE: file.replaceAll('\\', '/') }, encoding: 'utf8',
    });
  }
  try {
    writeFileSync(file, original);
    for (const invalid of ['127.0.0.1', '10.0.0.1', '999.1.1.1', 'https://3.121.198.183', '::1']) {
      assert.notEqual(invoke(invalid).status, 0, invalid);
      assert.equal(readFileSync(file, 'utf8'), original);
    }
    const first = invoke(ip);
    assert.equal(first.status, 0, first.stderr || first.stdout);
    const extended = readFileSync(file, 'utf8');
    assert.ok(extended.startsWith(original));
    assert.equal(extended.match(/^AARAST_DIRECT_API_IP=/gm).length, 1);
    assert.equal(invoke(ip).status, 0);
    assert.equal(readFileSync(file, 'utf8'), extended);
    assert.notEqual(invoke('1.1.1.1').status, 0);
    assert.equal(readFileSync(file, 'utf8'), extended);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
