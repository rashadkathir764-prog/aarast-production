const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const bcryptjs = require('bcryptjs');

const backendRoot = path.resolve(__dirname, '..', '..');
const envPath = path.join(backendRoot, '.env');

function loadEnvFileIfNeeded() {
  if (process.env.DATABASE_URL || !fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const equalsIndex = trimmed.indexOf('=');
    if (equalsIndex === -1) continue;
    const key = trimmed.slice(0, equalsIndex).trim();
    let value = trimmed.slice(equalsIndex + 1).trim();
    if (!key || process.env[key] !== undefined) continue;
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

async function main() {
  loadEnvFileIfNeeded();
  if (process.env.NODE_ENV === 'production') {
    throw new Error('dev:create-admin is forbidden in production.');
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  const phone = process.env.DEV_ADMIN_PHONE?.trim();
  const password = process.env.DEV_ADMIN_PASSWORD;
  const name = process.env.DEV_ADMIN_NAME?.trim() || 'Local Admin';
  if (!phone || !/^\+[1-9]\d{7,14}$/.test(phone)) {
    throw new Error('DEV_ADMIN_PHONE must be an international E.164 number.');
  }
  if (!password || password.length < 12) {
    throw new Error('DEV_ADMIN_PASSWORD must contain at least 12 characters.');
  }

  const prisma = new PrismaClient();
  const passwordHash = await bcryptjs.hash(password, 10);
  try {
    const admin = await prisma.user.upsert({
      where: { phone },
      create: {
        phone,
        name,
        role: 'ADMIN',
        adminRole: 'SUPER_ADMIN',
        status: 'ACTIVE',
        phoneVerifiedAt: new Date(),
        passwordHash,
      },
      update: {
        name,
        role: 'ADMIN',
        adminRole: 'SUPER_ADMIN',
        status: 'ACTIVE',
        phoneVerifiedAt: new Date(),
        passwordHash,
      },
    });
    await prisma.refreshToken.updateMany({
      where: { userId: admin.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    console.log('Local SUPER_ADMIN is ready; existing sessions were revoked.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
