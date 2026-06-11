import { PrismaClient, ProviderStatus } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const cities = await seedCities();
  const categories = await seedCategories();
  await seedDemoProviders(cities, categories);
}

async function seedCities() {
  const rows = [
    { nameAr: 'صنعاء', nameEn: 'Sanaa', sortOrder: 10 },
    { nameAr: 'عدن', nameEn: 'Aden', sortOrder: 20 },
    { nameAr: 'تعز', nameEn: 'Taiz', sortOrder: 30 },
    { nameAr: 'إب', nameEn: 'Ibb', sortOrder: 40 },
    { nameAr: 'الحديدة', nameEn: 'Al Hudaydah', sortOrder: 50 },
    { nameAr: 'المكلا', nameEn: 'Mukalla', sortOrder: 60 },
  ];

  const result: Record<string, string> = {};
  for (const city of rows) {
    const saved = await prisma.city.upsert({
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
    result[city.nameEn] = saved.id;
  }

  return result;
}

async function seedCategories() {
  const rows = [
    {
      nameAr: 'الصالات والقاعات',
      nameEn: 'Wedding Halls',
      slug: 'wedding-halls',
      icon: 'building-2',
      sortOrder: 10,
    },
    {
      nameAr: 'التصوير',
      nameEn: 'Photography',
      slug: 'photography',
      icon: 'camera',
      sortOrder: 20,
    },
    {
      nameAr: 'الكوش والديكور',
      nameEn: 'Kosha And Decor',
      slug: 'kosha-decor',
      icon: 'sparkles',
      sortOrder: 30,
    },
    {
      nameAr: 'فنانين/فنانات',
      nameEn: 'Artists',
      slug: 'artists',
      icon: 'mic-2',
      sortOrder: 40,
    },
    {
      nameAr: 'مزمار/مزومل',
      nameEn: 'Mizmar',
      slug: 'mizmar',
      icon: 'music',
      sortOrder: 50,
    },
    {
      nameAr: 'ضيافة',
      nameEn: 'Hospitality',
      slug: 'hospitality',
      icon: 'coffee',
      sortOrder: 60,
    },
    {
      nameAr: 'فساتين وتجهيزات',
      nameEn: 'Dresses And Supplies',
      slug: 'dresses-supplies',
      icon: 'shirt',
      sortOrder: 70,
    },
    {
      nameAr: 'سيارات الزفة',
      nameEn: 'Wedding Cars',
      slug: 'wedding-cars',
      icon: 'car',
      sortOrder: 80,
    },
    {
      nameAr: 'مكياج وتجميل',
      nameEn: 'Beauty',
      slug: 'beauty',
      icon: 'brush',
      sortOrder: 90,
    },
  ];

  const result: Record<string, string> = {};
  for (const category of rows) {
    const saved = await prisma.providerCategory.upsert({
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
    result[category.slug] = saved.id;
  }

  return result;
}

async function seedDemoProviders(
  cities: Record<string, string>,
  categories: Record<string, string>,
) {
  await ensureDemoProvider({
    cityId: cities.Sanaa,
    businessName: 'قاعة السعادة للأفراح',
    ownerName: 'أمجد الحيمي',
    phone: '+967700100101',
    whatsapp: '+967700100101',
    description: 'قاعة أفراح مناسبة للخطوبة والزفاف مع باقات ضيافة يمنية.',
    address: 'شارع الستين، صنعاء',
    isFeatured: true,
    services: [
      {
        categoryId: categories['wedding-halls'],
        title: 'حجز قاعة زفاف',
        description: 'قاعة رئيسية مع تجهيزات الصوت والإضاءة.',
        basePrice: '450000',
        priceUnit: 'event',
        packageTitle: 'باقة القاعة والضيافة',
        packageItems: ['قاعة', 'ضيافة', 'تنسيق طاولات'],
      },
    ],
  });

  await ensureDemoProvider({
    cityId: cities.Aden,
    businessName: 'استوديو لحظات',
    ownerName: 'سارة العولقي',
    phone: '+967711200202',
    whatsapp: '+967711200202',
    description: 'تصوير حفلات وخطوبات مع مونتاج وتسليم رقمي.',
    address: 'كريتر، عدن',
    isFeatured: true,
    services: [
      {
        categoryId: categories.photography,
        title: 'تصوير فوتوغرافي وفيديو',
        description: 'تغطية الحفل بفريق تصوير ومونتاج مختصر.',
        basePrice: '180000',
        priceUnit: 'package',
        packageTitle: 'باقة التغطية الكاملة',
        packageItems: ['تصوير فوتوغرافي', 'فيديو', 'ملخص قصير'],
      },
    ],
  });

  await ensureDemoProvider({
    cityId: cities.Taiz,
    businessName: 'لمسة فرح للكوش والديكور',
    ownerName: 'منى الصبري',
    phone: '+967733300303',
    whatsapp: '+967733300303',
    description: 'تصميم كوش وديكور حفلات بألوان قابلة للتخصيص.',
    address: 'جولة سنان، تعز',
    isFeatured: false,
    services: [
      {
        categoryId: categories['kosha-decor'],
        title: 'كوشة وديكور حفل',
        description: 'تصميم كوشة مع تنسيق مدخل وطاولات.',
        basePrice: '220000',
        priceUnit: 'event',
        packageTitle: 'باقة الديكور الأساسية',
        packageItems: ['كوشة', 'مدخل', 'تنسيق طاولات'],
      },
    ],
  });
}

async function ensureDemoProvider(input: {
  cityId: string;
  businessName: string;
  ownerName: string;
  phone: string;
  whatsapp: string;
  description: string;
  address: string;
  isFeatured: boolean;
  services: Array<{
    categoryId: string;
    title: string;
    description: string;
    basePrice: string;
    priceUnit: string;
    packageTitle: string;
    packageItems: string[];
  }>;
}) {
  const provider =
    (await prisma.provider.findFirst({ where: { phone: input.phone } })) ??
    (await prisma.provider.create({
      data: {
        cityId: input.cityId,
        businessName: input.businessName,
        ownerName: input.ownerName,
        phone: input.phone,
        whatsapp: input.whatsapp,
        description: input.description,
        address: input.address,
        status: ProviderStatus.ACTIVE,
        isFeatured: input.isFeatured,
      },
    }));

  await prisma.provider.update({
    where: { id: provider.id },
    data: {
      cityId: input.cityId,
      businessName: input.businessName,
      ownerName: input.ownerName,
      whatsapp: input.whatsapp,
      description: input.description,
      address: input.address,
      status: ProviderStatus.ACTIVE,
      isFeatured: input.isFeatured,
    },
  });

  for (const serviceInput of input.services) {
    const service =
      (await prisma.providerService.findFirst({
        where: { providerId: provider.id, title: serviceInput.title },
      })) ??
      (await prisma.providerService.create({
        data: {
          providerId: provider.id,
          categoryId: serviceInput.categoryId,
          title: serviceInput.title,
          description: serviceInput.description,
          basePrice: serviceInput.basePrice,
          priceUnit: serviceInput.priceUnit,
          cityId: input.cityId,
          isActive: true,
        },
      }));

    await prisma.providerService.update({
      where: { id: service.id },
      data: {
        categoryId: serviceInput.categoryId,
        description: serviceInput.description,
        basePrice: serviceInput.basePrice,
        priceUnit: serviceInput.priceUnit,
        cityId: input.cityId,
        isActive: true,
      },
    });

    const existingPackage = await prisma.providerPackage.findFirst({
      where: {
        providerId: provider.id,
        title: serviceInput.packageTitle,
      },
    });

    if (existingPackage) {
      await prisma.providerPackage.update({
        where: { id: existingPackage.id },
        data: {
          serviceId: service.id,
          items: serviceInput.packageItems,
          isActive: true,
        },
      });
    } else {
      await prisma.providerPackage.create({
        data: {
          providerId: provider.id,
          serviceId: service.id,
          title: serviceInput.packageTitle,
          price: serviceInput.basePrice,
          items: serviceInput.packageItems,
          isActive: true,
        },
      });
    }
  }
}

main()
  .then(async () => {
    console.log('Aarast seed data is ready.');
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
