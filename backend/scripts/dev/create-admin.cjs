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

  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  const prisma = new PrismaClient();
  const phone = '770579680';
  const passwordHash = await bcryptjs.hash('Aarast@123456', 10);

  try {
    const admin = await prisma.user.upsert({
      where: { phone },
      create: {
        phone,
        name: 'عماد كثير',
        role: 'ADMIN',
        status: 'ACTIVE',
        passwordHash,
      },
      update: {
        name: 'عماد كثير',
        role: 'ADMIN',
        status: 'ACTIVE',
        passwordHash,
      },
    });

    console.log('Admin ready');
    console.log(`phone: ${admin.phone}`);
    console.log(`role: ${admin.role}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
