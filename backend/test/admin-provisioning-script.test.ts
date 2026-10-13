import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const {
  applicationIdentityForProvisioning,
  normalizeYemeniPhone,
  phoneVariants,
  selectProvisioningIdentity,
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

test('admin provisioning fails closed when canonical and legacy identities both exist', () => {
  const canonical = { id: 'canonical' };
  const legacy = { id: 'legacy' };

  assert.equal(selectProvisioningIdentity([]), null);
  assert.equal(selectProvisioningIdentity([canonical]), canonical);
  assert.throws(
    () => selectProvisioningIdentity([canonical, legacy]),
    /Duplicate canonical and legacy administrator identities/,
  );
});

test('admin provisioning checks every phone variant before mutating in a serializable transaction', () => {
  const source = readFileSync('scripts/prod/provision-admin.cjs', 'utf8');

  assert.match(source, /user\.findMany/);
  assert.match(source, /phone:\s*\{\s*in:\s*\[canonicalPhone,\s*legacyLocalPhone\]/);
  assert.match(source, /selectProvisioningIdentity/);
  assert.match(
    source,
    /isolationLevel:\s*Prisma\.TransactionIsolationLevel\.Serializable/,
  );
  assert.doesNotMatch(
    source,
    /findUnique\([\s\S]*?\)\s*\?\?\s*[\s\S]*?findUnique\(/,
  );
});

test('admin provisioning uses the application password rule and the bcrypt limit', () => {
  assert.throws(() => validatePassword('12345'), /at least 6/);
  assert.throws(() => validatePassword(`A1${'x'.repeat(71)}`), /72 UTF-8 bytes/);
  assert.throws(() => validatePassword(`A1${'ش'.repeat(36)}`), /72 UTF-8 bytes/);
  // Digits only, letters only, any case: the owner's decision (2026-10-13).
  assert.doesNotThrow(() => validatePassword('123456'));
  assert.doesNotThrow(() => validatePassword('abcdef'));
  assert.doesNotThrow(() => validatePassword('Aarast-admin-2026'));
});

test('admin provisioning throttle hash is deterministic and peppered', () => {
  const first = throttleSubjectHash('+967777123456', 'pepper-a');
  const second = throttleSubjectHash('+967777123456', 'pepper-a');
  const other = throttleSubjectHash('+967777123456', 'pepper-b');
  assert.equal(first, second);
  assert.notEqual(first, other);
  assert.equal(
    first,
    createHmac('sha256', 'pepper-a')
      .update('v2:admin:+967777123456', 'utf8')
      .digest('hex'),
  );
  assert.equal(first.length, 64);
  assert.throws(
    () => throttleSubjectHash('+967777123456', ''),
    /AUTH_LOGIN_THROTTLE_PEPPER/,
  );
});

test('promoting an application user preserves a separate application identity', () => {
  const application = applicationIdentityForProvisioning({
    role: 'USER',
    passwordHash: 'application-password-hash',
    appPasswordHash: null,
    name: 'Wedding User',
    appName: null,
    email: 'wedding@example.test',
    appEmail: null,
    avatarUrl: 'https://media.test/wedding.webp',
    appAvatarUrl: null,
  });
  assert.deepEqual(application, {
    appPasswordHash: 'application-password-hash',
    appName: 'Wedding User',
    appEmail: 'wedding@example.test',
    appAvatarUrl: 'https://media.test/wedding.webp',
  });
  assert.deepEqual(
    applicationIdentityForProvisioning({ role: 'ADMIN' }),
    {},
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

test('admin provisioning revokes every administrator recovery artifact', () => {
  const source = readFileSync('scripts/prod/provision-admin.cjs', 'utf8');
  assert.match(source, /adminLoginChallenge\.deleteMany/);
  assert.match(source, /adminPasswordResetChallenge\.deleteMany/);
  assert.match(
    source,
    /purpose:\s*\{\s*in:\s*\['ADMIN_LOGIN',\s*'ADMIN_RESET_PASSWORD'\]/,
  );
  assert.match(source, /otpCode\.updateMany/);
});
