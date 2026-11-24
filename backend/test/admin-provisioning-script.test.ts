import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const {
  applicationIdentityForProvisioning,
  normalizeYemeniPhone,
  parseAdminRole,
  phoneVariants,
  provisionAdminInTransaction,
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
  assert.match(source, /adminTrustedDevice\.updateMany/);
  assert.match(source, /adminPasswordResetChallenge\.deleteMany/);
  assert.match(
    source,
    /purpose:\s*\{\s*in:\s*\['ADMIN_LOGIN',\s*'ADMIN_RESET_PASSWORD'\]/,
  );
  assert.match(source, /otpCode\.updateMany/);
});

// RA-AD-24: production adds staff with the role their work needs, and a
// role can be changed later, without handing everyone SUPER_ADMIN.
type FakeUser = {
  id: string;
  phone: string;
  name: string;
  role: string;
  adminRole: string | null;
  status: string;
  passwordHash: string | null;
};

function fakeTransaction(users: FakeUser[]) {
  const writes: Array<{ id: string; data: Record<string, unknown> }> = [];
  const tx = {
    user: {
      findMany: async ({ where }: { where: { phone: { in: string[] } } }) =>
        users.filter((user) => where.phone.in.includes(user.phone)),
      count: async ({ where }: { where: Record<string, unknown> }) =>
        users.filter((user) =>
          Object.entries(where).every(
            ([key, value]) => (user as Record<string, unknown>)[key] === value,
          ),
        ).length,
      update: async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
        writes.push({ id: where.id, data });
        const user = users.find((row) => row.id === where.id)!;
        Object.assign(user, data);
        return user;
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        const user = { id: `new-${users.length}`, ...data } as FakeUser;
        users.push(user);
        writes.push({ id: user.id, data });
        return user;
      },
    },
    refreshToken: { updateMany: async () => ({ count: 0 }) },
    adminTrustedDevice: { updateMany: async () => ({ count: 0 }) },
    adminLoginChallenge: { deleteMany: async () => ({ count: 0 }) },
    adminPasswordResetChallenge: { deleteMany: async () => ({ count: 0 }) },
    otpCode: { updateMany: async () => ({ count: 0 }) },
    loginThrottle: { deleteMany: async () => ({ count: 0 }) },
  };
  return { tx, writes };
}

const superAdmin = (id: string, phone: string): FakeUser => ({
  id,
  phone,
  name: 'Owner',
  role: 'ADMIN',
  adminRole: 'SUPER_ADMIN',
  status: 'ACTIVE',
  passwordHash: 'owner-hash',
});

test('admin provisioning takes an explicit role and refuses anything else', () => {
  for (const role of ['SUPER_ADMIN', 'OPERATIONS', 'MODERATOR', 'SUPPORT']) {
    assert.equal(parseAdminRole(role), role);
  }
  assert.equal(parseAdminRole(' moderator '), 'MODERATOR');
  assert.throws(() => parseAdminRole(undefined), /PROVISION_ADMIN_ROLE must be one of/);
  assert.throws(() => parseAdminRole(''), /PROVISION_ADMIN_ROLE must be one of/);
  assert.throws(() => parseAdminRole('ADMIN'), /PROVISION_ADMIN_ROLE must be one of/);
});

test('admin provisioning creates a staff account with the role it was given', async () => {
  const { tx, writes } = fakeTransaction([]);
  await provisionAdminInTransaction(tx, {
    phone: '+967777123456',
    name: 'Moderation',
    adminRole: 'MODERATOR',
    passwordHash: 'hash',
    subjectHash: 'subject',
    now: new Date('2026-11-24T00:00:00Z'),
  });
  assert.equal(writes.length, 1);
  assert.equal(writes[0]!.data.role, 'ADMIN');
  assert.equal(writes[0]!.data.adminRole, 'MODERATOR');
  assert.equal(writes[0]!.data.passwordHash, 'hash');
});

test('a new account cannot be provisioned without a password', async () => {
  const { tx, writes } = fakeTransaction([]);
  await assert.rejects(
    provisionAdminInTransaction(tx, {
      phone: '+967777123456',
      name: null,
      adminRole: 'SUPPORT',
      passwordHash: null,
      subjectHash: 'subject',
      now: new Date(),
    }),
    /PROVISION_ADMIN_PASSWORD is required/,
  );
  assert.equal(writes.length, 0);
});

test('an existing administrator changes role and keeps password and name when none is given', async () => {
  const staff: FakeUser = {
    id: 'staff',
    phone: '+967777000001',
    name: 'Sara',
    role: 'ADMIN',
    adminRole: 'SUPPORT',
    status: 'ACTIVE',
    passwordHash: 'sara-hash',
  };
  const { tx, writes } = fakeTransaction([superAdmin('owner', '+967777000000'), staff]);
  await provisionAdminInTransaction(tx, {
    phone: '+967777000001',
    name: null,
    adminRole: 'OPERATIONS',
    passwordHash: null,
    subjectHash: 'subject',
    now: new Date(),
  });
  assert.equal(staff.adminRole, 'OPERATIONS');
  assert.equal(staff.passwordHash, 'sara-hash');
  assert.equal(staff.name, 'Sara');
  assert.equal('passwordHash' in writes[0]!.data, false);
});

test('the last active super administrator cannot be demoted', async () => {
  const owner = superAdmin('owner', '+967777000000');
  const { tx, writes } = fakeTransaction([owner]);
  await assert.rejects(
    provisionAdminInTransaction(tx, {
      phone: '+967777000000',
      name: null,
      adminRole: 'OPERATIONS',
      passwordHash: null,
      subjectHash: 'subject',
      now: new Date(),
    }),
    /last active super administrator/,
  );
  assert.equal(writes.length, 0);
  assert.equal(owner.adminRole, 'SUPER_ADMIN');

  const second = fakeTransaction([owner, superAdmin('other', '+967777000009')]);
  await provisionAdminInTransaction(second.tx, {
    phone: '+967777000000',
    name: null,
    adminRole: 'OPERATIONS',
    passwordHash: null,
    subjectHash: 'subject',
    now: new Date(),
  });
  assert.equal(owner.adminRole, 'OPERATIONS');
});
