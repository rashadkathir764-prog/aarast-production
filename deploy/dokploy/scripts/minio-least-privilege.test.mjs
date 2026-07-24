import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const productionCompose = readFileSync(
  new URL('../docker-compose.yml', import.meta.url),
  'utf8',
);
const localCompose = readFileSync(
  new URL('../../../docker-compose.yml', import.meta.url),
  'utf8',
);
const initScript = readFileSync(
  new URL('../../media/init.sh', import.meta.url),
  'utf8',
);
const policySource = readFileSync(
  new URL('../../media/backend-policy.sh', import.meta.url),
  'utf8',
);
const mediaStorage = readFileSync(
  new URL('../../../backend/src/media/media-storage.service.ts', import.meta.url),
  'utf8',
);

function serviceBlock(compose, name, nextName) {
  const boundary = nextName ? `^  ${nextName}:\\n` : '^volumes:\\n';
  const body = compose.match(
    new RegExp(
      `^  ${name}:\\n(?<body>[\\s\\S]*?)(?=${boundary})`,
      'm',
    ),
  )?.groups?.body;
  assert.ok(body, `missing ${name} service block`);
  return body;
}

test('Backend receives only a dedicated MinIO service account', () => {
  for (const compose of [localCompose, productionCompose]) {
    const media = serviceBlock(compose, 'media', 'media-init');
    const init = serviceBlock(
      compose,
      'media-init',
      compose === localCompose ? 'backend' : 'postgres-backup',
    );
    const backend = serviceBlock(
      compose,
      'backend',
      compose === localCompose ? null : 'admin-web',
    );

    assert.match(media, /MINIO_ROOT_USER:/);
    assert.match(media, /MINIO_ROOT_PASSWORD:/);
    assert.match(init, /MINIO_ROOT_USER:/);
    assert.match(init, /MINIO_ROOT_PASSWORD:/);
    assert.match(init, /AARAST_MEDIA_ACCESS_KEY_ID:/);
    assert.match(init, /AARAST_MEDIA_SECRET_ACCESS_KEY:/);
    assert.match(backend, /AARAST_MEDIA_ACCESS_KEY_ID:/);
    assert.match(backend, /AARAST_MEDIA_SECRET_ACCESS_KEY:/);
    assert.doesNotMatch(backend, /MINIO_ROOT_(?:USER|PASSWORD)/);
  }
});

test('service account policy is limited to the application bucket prefixes', () => {
  assert.match(policySource, /"Version":"2012-10-17"/);
  assert.deepEqual(
    [...new Set(policySource.match(/s3:[A-Za-z]+/g) ?? [])].sort(),
    [
      's3:DeleteObject',
      's3:GetBucketLocation',
      's3:GetObject',
      's3:PutObject',
    ],
  );
  assert.match(policySource, /arn:aws:s3:::%s/);
  for (const prefix of [
    'user-avatar',
    'provider-logo',
    'provider-cover',
    'service-image',
    'chat-image',
  ]) {
    assert.match(policySource, new RegExp(`${prefix}/\\*`));
  }
  assert.doesNotMatch(
    policySource,
    /s3:(?:CreateBucket|DeleteBucket|ListAllMyBuckets|PutBucketPolicy|CreateUser)/,
  );
  assert.doesNotMatch(policySource, /"Resource":"\*"/);
});

test('initializer is idempotent and keeps chat media private', () => {
  assert.match(initScript, /mc admin user svcacct info/);
  assert.match(initScript, /mc admin user svcacct add/);
  assert.match(initScript, /mc admin user svcacct edit/);
  assert.equal(
    (
      initScript.match(
        /--description "Aarast Backend bucket-prefix access" >\/dev\/null/g,
      ) ?? []
    ).length,
    2,
  );
  assert.match(initScript, /mc anonymous set none/);
  assert.match(initScript, /user-avatar/);
  assert.match(initScript, /provider-logo/);
  assert.match(initScript, /provider-cover/);
  assert.match(initScript, /service-image/);
  assert.match(initScript, /mc anonymous set none[^]*chat-image/);
});

test('readiness checks bucket existence without granting object listing', () => {
  assert.match(mediaStorage, /GetBucketLocationCommand/);
  assert.doesNotMatch(mediaStorage, /HeadBucketCommand/);
  assert.doesNotMatch(policySource, /s3:ListBucket/);
});
