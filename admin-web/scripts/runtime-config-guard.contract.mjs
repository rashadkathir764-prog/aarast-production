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

// RA-AD-21: provider photos live on the media store, not on the admin
// origin. The CSP lets the page draw them from that one origin, and the
// guard refuses to start without it, so a photo is never swapped for the
// placeholder in silence.
test('the CSP draws images from the media origin the runtime is given', () => {
  const policies = nginx.match(/Content-Security-Policy "[^"]*"/g) ?? [];
  assert.equal(policies.length, 2);
  for (const policy of policies) {
    assert.match(policy, /img-src 'self' data: \$\{MEDIA_ORIGIN\};/);
  }
  assert.match(runtimeGuard, /: "\$\{MEDIA_ORIGIN:\?MEDIA_ORIGIN is required\}"/);
  assert.match(runtimeGuard, /require_public_https_origin MEDIA_ORIGIN "\$MEDIA_ORIGIN"/);
});

test('every deployment gives the admin its media origin', () => {
  const awsCompose = read('../../deploy/aws/compose.yml');
  assert.match(
    awsCompose,
    /AARAST_MEDIA_PUBLIC_BASE_URL: https:\/\/\$\{AARAST_MEDIA_BUCKET\}\.s3\.\$\{AWS_REGION\}\.amazonaws\.com\n/,
  );
  assert.match(
    awsCompose,
    /MEDIA_ORIGIN: https:\/\/\$\{AARAST_MEDIA_BUCKET\}\.s3\.\$\{AWS_REGION\}\.amazonaws\.com\n/,
  );
  assert.match(
    read('../../deploy/staging/docker-compose.yml'),
    /MEDIA_ORIGIN: \$\{STAGING_MEDIA_ORIGIN:\?staging media origin required\}\n/,
  );
  assert.match(
    read('../../deploy/dokploy/docker-compose.yml'),
    /MEDIA_ORIGIN: \$\{AARAST_MEDIA_ORIGIN:\?AARAST_MEDIA_ORIGIN is required\}\n/,
  );
});
