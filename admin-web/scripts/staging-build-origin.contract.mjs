import assert from 'node:assert/strict';
import { test } from 'node:test';
import { requireBuildApiOrigin } from './staging-build-origin.mjs';

test('staging Admin requires its own explicit API origin', () => {
  assert.throws(() => requireBuildApiOrigin('staging', undefined), /explicit/);
  assert.throws(() => requireBuildApiOrigin('staging', 'https://aarast-api.shadowgardn.com'), /distinct/);
  assert.throws(() => requireBuildApiOrigin('staging', 'http://api.staging.example.com'), /HTTPS/);
  assert.equal(requireBuildApiOrigin('staging', 'https://api.staging.example.com'),
    'https://api.staging.example.com');
});
