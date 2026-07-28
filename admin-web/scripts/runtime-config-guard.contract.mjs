import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (relativePath) =>
  readFileSync(new URL(relativePath, import.meta.url), 'utf8');

const buildConfig = read('./build-config-smoke.mjs');
const dockerfile = read('../Dockerfile');
const nginx = read('../nginx.conf');
const runtimeGuard = read('./runtime-config-guard.sh');

test('the admin image binds build API origin to runtime CSP origin', () => {
  assert.match(buildConfig, /aarast-build-config\.json/);
  assert.match(buildConfig, /apiOrigin/);
  assert.match(runtimeGuard, /aarast-build-config\.json/);
  assert.match(runtimeGuard, /API_ORIGIN/);
  assert.match(runtimeGuard, /build API origin does not match runtime API origin/);
  assert.match(dockerfile, /runtime-config-guard\.sh/);
});

test('the runtime guard rejects private origins and CORS drift', () => {
  assert.match(runtimeGuard, /ADMIN_PUBLIC_ORIGIN/);
  assert.match(runtimeGuard, /CORS_ORIGINS/);
  assert.match(runtimeGuard, /public HTTPS origin/);
  assert.match(runtimeGuard, /not present in CORS_ORIGINS/);
});

test('the nginx runtime is immutable and sends the complete security headers', () => {
  assert.match(
    dockerfile,
    /^FROM nginx:[^@\s]+@sha256:[a-f0-9]{64} AS runtime$/m,
  );
  assert.match(nginx, /server_tokens off;/);
  assert.equal(
    (nginx.match(/add_header Strict-Transport-Security/g) ?? []).length,
    2,
  );
});
