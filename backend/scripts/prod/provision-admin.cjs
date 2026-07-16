const { createHmac } = require('node:crypto');
const { Prisma, PrismaClient } = require('@prisma/client');
const bcryptjs = require('bcryptjs');

const confirmation = 'PROVISION_AARAST_ADMIN';

function normalizeYemeniPhone(value) {
  const compact = value.trim().replace(/[\s()-]/g, '');
  if (/^\+9677\d{8}$/.test(compact)) return compact;
  if (/^7\d{8}$/.test(compact)) return `+967${compact}`;
  throw new Error('PROVISION_ADMIN_PHONE must be a Yemeni mobile number.');
}

function phoneVariants(phone) {
  return [phone, phone.slice(4)];
}

function selectProvisioningIdentity(users) {
  if (users.length > 1) {
    throw new Error(
      'Duplicate canonical and legacy administrator identities detected; merge them before provisioning.',
    );
  }
  return users[0] ?? null;
}

function validatePassword(value) {
  if (value.length < 12 || value.length > 72) {
    throw new Error('PROVISION_ADMIN_PASSWORD must contain 12 to 72 characters.');
  }
  if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) {
    throw new Error('PROVISION_ADMIN_PASSWORD must contain letters and digits.');
  }
}

function throttleSubjectHash(phone, pepper) {
  if (!pepper) {
    throw new Error('AUTH_LOGIN_THROTTLE_PEPPER is required.');
  }
  return createHmac('sha256', pepper)
    .update(`v1:${phone}`, 'utf8')
    .digest('hex');
}

async function provisionAdmin(environment = process.env) {
  if (environment.PROVISION_ADMIN_CONFIRM !== confirmation) {
    throw new Error(`PROVISION_ADMIN_CONFIRM must equal ${confirmation}.`);
  }
  if (!environment.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  const phone = normalizeYemeniPhone(environment.PROVISION_ADMIN_PHONE ?? '');
  const password = environment.PROVISION_ADMIN_PASSWORD ?? '';
  validatePassword(password);
  const name = environment.PROVISION_ADMIN_NAME?.trim() || 'Aarast Admin';
  const subjectHash = throttleSubjectHash(
    phone,
    environment.AUTH_LOGIN_THROTTLE_PEPPER?.trim(),
  );
  const passwordHash = await bcryptjs.hash(password, 12);
  const prisma = new PrismaClient();

  try {
    await prisma.$transaction(
      async (tx) => {
        const [canonicalPhone, legacyLocalPhone] = phoneVariants(phone);
        const existing = selectProvisioningIdentity(
          await tx.user.findMany({
            where: {
              phone: { in: [canonicalPhone, legacyLocalPhone] },
            },
          }),
        );
        const user = existing
          ? await tx.user.update({
              where: { id: existing.id },
              data: {
                phone: canonicalPhone,
                name,
                role: 'ADMIN',
                adminRole: 'SUPER_ADMIN',
                status: 'ACTIVE',
                passwordHash,
              },
            })
          : await tx.user.create({
              data: {
                name,
                phone,
                role: 'ADMIN',
                adminRole: 'SUPER_ADMIN',
                status: 'ACTIVE',
                passwordHash,
              },
            });

        const now = new Date();
        await tx.refreshToken.updateMany({
          where: { userId: user.id, revokedAt: null },
          data: { revokedAt: now },
        });
        await tx.adminLoginChallenge.deleteMany({ where: { userId: user.id } });
        await tx.loginThrottle.deleteMany({ where: { subjectHash } });
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
    console.log('SUPER_ADMIN provisioned; previous sessions and challenges were revoked.');
  } catch (error) {
    if (error?.code === 'P2002' || error?.code === 'P2034') {
      throw new Error(
        'Administrator provisioning conflicted with another identity update; no changes were applied.',
      );
    }
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  provisionAdmin().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}

module.exports = {
  normalizeYemeniPhone,
  phoneVariants,
  provisionAdmin,
  selectProvisioningIdentity,
  throttleSubjectHash,
  validatePassword,
};
