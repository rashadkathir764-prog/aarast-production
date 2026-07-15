import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const {
  normalizeYemeniPhone,
  phoneVariants,
  throttleSubjectHash,
  validatePassword,
} = require('../scripts/prod/provision-admin.cjs');

test('admin provisioning normalizes Yemeni local and international phones', () => {
  assert.equal(normalizeYemeniPhone('777123456'), '+967777123456');
  assert.equal(normalizeYemeniPhone('+967 777 123 456'), '+967777123456');
  assert.throws(() => normalizeYemeniPhone('123'), /Yemeni mobile number/);
});

test('admin provisioning recognizes the legacy local phone variant', () => {
  assert.deepEqual(phoneVariants('+967777123456'), [
    '+967777123456',
    '777123456',
  ]);
});

test('admin provisioning rejects weak or bcrypt-truncated passwords', () => {
  assert.throws(() => validatePassword('short123'), /12 to 72/);
  assert.throws(() => validatePassword('letters-only-password'), /letters and digits/);
  assert.throws(() => validatePassword(`A1${'x'.repeat(71)}`), /12 to 72/);
  assert.doesNotThrow(() => validatePassword('Aarast-admin-2026'));
});

test('admin provisioning throttle hash is deterministic and peppered', () => {
  const first = throttleSubjectHash('+967777123456', 'pepper-a');
  const second = throttleSubjectHash('+967777123456', 'pepper-a');
  const other = throttleSubjectHash('+967777123456', 'pepper-b');
  assert.equal(first, second);
  assert.notEqual(first, other);
  assert.equal(first.length, 64);
  assert.throws(
    () => throttleSubjectHash('+967777123456', ''),
    /AUTH_LOGIN_THROTTLE_PEPPER/,
  );
});

test('production backend image includes the admin provisioning operation', () => {
  const dockerfile = readFileSync('Dockerfile', 'utf8');
  assert.match(
    dockerfile,
    /COPY scripts\/prod\/provision-admin\.cjs \.\/scripts\/prod\/provision-admin\.cjs/,
  );
  assert.match(
    dockerfile,
    /COPY --from=build \/app\/scripts\/prod\/provision-admin\.cjs \.\/scripts\/prod\/provision-admin\.cjs/,
  );
});
