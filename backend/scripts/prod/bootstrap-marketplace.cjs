#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {
  OnboardingPath,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
} = require('@prisma/client');
const bcryptjs = require('bcryptjs');

const backendRoot = path.resolve(__dirname, '..', '..');
const envPath = path.join(backendRoot, '.env');

const providerPhone = process.env.AARAST_PROVIDER_TEST_PHONE || '776005503';
const providerPassword = process.env.AARAST_PROVIDER_TEST_PASSWORD;

const cities = [
  { nameAr: 'صنعاء', nameEn: 'Sanaa', sortOrder: 10 },
  { nameAr: 'عدن', nameEn: 'Aden', sortOrder: 20 },
  { nameAr: 'تعز', nameEn: 'Taiz', sortOrder: 30 },
  { nameAr: 'إب', nameEn: 'Ibb', sortOrder: 40 },
  { nameAr: 'الحديدة', nameEn: 'Hodeidah', sortOrder: 50 },
];

const categories = [
  { nameAr: 'الصالات', nameEn: 'Wedding Halls', slug: 'wedding-halls', icon: 'hall', sortOrder: 10 },
  { nameAr: 'التصوير', nameEn: 'Photography', slug: 'photography', icon: 'camera', sortOrder: 20 },
  { nameAr: 'الضيافة والعشاء', nameEn: 'Catering', slug: 'catering', icon: 'catering', sortOrder: 30 },
  { nameAr: 'الكوشة والديكور', nameEn: 'Stage And Decor', slug: 'stage-decor', icon: 'decor', sortOrder: 40 },
  { nameAr: 'الفساتين', nameEn: 'Dresses', slug: 'dresses', icon: 'dress', sortOrder: 50 },
  { nameAr: 'الصوت والإضاءة', nameEn: 'Sound And Lighting', slug: 'sound-lighting', icon: 'lighting', sortOrder: 60 },
];

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

function requireRuntimeConfig() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  if (!providerPassword) {
    throw new Error('AARAST_PROVIDER_TEST_PASSWORD is required.');
  }
}

async function upsertCities(prisma) {
  const saved = {};
  for (const city of cities) {
    saved[city.nameAr] = await prisma.city.upsert({
      where: {
        nameAr_countryCode: {
          nameAr: city.nameAr,
          countryCode: 'YE',
        },
      },
      create: {
        ...city,
        countryCode: 'YE',
        isActive: true,
      },
      update: {
        nameEn: city.nameEn,
        sortOrder: city.sortOrder,
        isActive: true,
      },
    });
  }
  return saved;
}

async function upsertCategories(prisma) {
  const saved = {};
  for (const category of categories) {
    saved[category.slug] = await prisma.providerCategory.upsert({
      where: { slug: category.slug },
      create: {
        ...category,
        isActive: true,
      },
      update: {
        nameAr: category.nameAr,
        nameEn: category.nameEn,
        icon: category.icon,
        sortOrder: category.sortOrder,
        isActive: true,
      },
    });
  }
  return saved;
}

async function upsertProviderUser(prisma) {
  const passwordHash = await bcryptjs.hash(providerPassword, 10);

  return prisma.user.upsert({
    where: { phone: providerPhone },
    create: {
      name: 'مورد أعرست التجريبي',
      phone: providerPhone,
      passwordHash,
      role: UserRole.PROVIDER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
      locale: 'ar',
      onboardingPath: OnboardingPath.PROVIDER,
      onboardingCompletedAt: new Date(),
    },
    update: {
      name: 'مورد أعرست التجريبي',
      passwordHash,
      role: UserRole.PROVIDER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
      locale: 'ar',
      onboardingPath: OnboardingPath.PROVIDER,
      onboardingCompletedAt: new Date(),
    },
  });
}

async function upsertProvider(prisma, user, city, category) {
  const existing = await prisma.provider.findFirst({
    where: {
      OR: [{ userId: user.id }, { phone: providerPhone }],
    },
  });

  const data = {
    userId: user.id,
    cityId: city.id,
    primaryCategoryId: category.id,
    businessName: 'مورد أعرست التجريبي للصالة',
    ownerName: 'فريق أعرست',
    phone: providerPhone,
    whatsapp: providerPhone,
    description:
      'ملف تجريبي للتحقق من مسار المورد وعرض الخدمات داخل أعرست. لا يمثل حجزا فعليا.',
    address: 'صنعاء',
    // Not featured: «مميز» is only a placement the back office records
    // after a real payment outside the app (B-43).
    status: ProviderStatus.ACTIVE,
  };

  if (!existing) {
    return prisma.provider.create({ data });
  }

  return prisma.provider.update({
    where: { id: existing.id },
    data,
  });
}

async function upsertProviderService(prisma, provider, city, category) {
  const existing = await prisma.providerService.findFirst({
    where: {
      providerId: provider.id,
      title: 'خدمة صالة تجريبية',
    },
  });

  const data = {
    providerId: provider.id,
    categoryId: category.id,
    cityId: city.id,
    title: 'خدمة صالة تجريبية',
    description:
      'خدمة مرجعية للتأكد من ظهور المورد في السوق ولوحة المورد. لا تعني دفعا أو حجزا مؤكدا.',
    basePrice: '300000',
    priceUnit: 'حجز مبدئي',
    currency: 'YER',
    isActive: true,
  };

  if (!existing) {
    return prisma.providerService.create({ data });
  }

  return prisma.providerService.update({
    where: { id: existing.id },
    data,
  });
}

async function main() {
  loadEnvFileIfNeeded();
  requireRuntimeConfig();

  const prisma = new PrismaClient();
  try {
    const savedCities = await upsertCities(prisma);
    const savedCategories = await upsertCategories(prisma);
    const user = await upsertProviderUser(prisma);
    const provider = await upsertProvider(
      prisma,
      user,
      savedCities['صنعاء'],
      savedCategories['wedding-halls'],
    );
    const service = await upsertProviderService(
      prisma,
      provider,
      savedCities['صنعاء'],
      savedCategories['wedding-halls'],
    );

    console.log('Marketplace bootstrap complete.');
    console.log(`cities: ${Object.keys(savedCities).length}`);
    console.log(`categories: ${Object.keys(savedCategories).length}`);
    console.log(`providerPhone: ${providerPhone}`);
    console.log(`providerStatus: ${provider.status}`);
    console.log(`serviceId: ${service.id}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
