import {
  ConversationEventType,
  ConversationScope,
  CostPaymentType,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  NotificationType,
  OnboardingPath,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  UserRole,
  UserStatus,
  WeddingCostStatus,
  WeddingPersona,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.ALLOW_PRODUCTION_SEED !== 'true') {
    throw new Error('Refusing to run seed in production without ALLOW_PRODUCTION_SEED=true');
  }

  const cities = await seedCities();
  const categories = await seedCategories();
  await seedDemoProviders(cities, categories);
  await seedBackendCompletionDemo(cities, categories);
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
  const primaryCategoryId = input.services[0]?.categoryId;
  const provider =
    (await prisma.provider.findFirst({ where: { phone: input.phone } })) ??
    (await prisma.provider.create({
      data: {
        cityId: input.cityId,
        primaryCategoryId,
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
      primaryCategoryId,
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

async function seedBackendCompletionDemo(
  cities: Record<string, string>,
  categories: Record<string, string>,
) {
  const passwordHash = await bcrypt.hash('AarastDev123!', 10);
  const user = await prisma.user.upsert({
    where: { phone: '+967700999001' },
    create: {
      name: 'Aarast Backend Demo User',
      phone: '+967700999001',
      email: 'backend-demo@aarast.local',
      passwordHash,
      role: UserRole.USER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
      locale: 'ar',
      onboardingPath: OnboardingPath.USER,
      persona: WeddingPersona.GROOM,
      onboardingCompletedAt: new Date(),
    },
    update: {
      name: 'Aarast Backend Demo User',
      status: UserStatus.ACTIVE,
      onboardingPath: OnboardingPath.USER,
      persona: WeddingPersona.GROOM,
      onboardingCompletedAt: new Date(),
    },
  });

  const providerUser = await prisma.user.upsert({
    where: { phone: '+967700999002' },
    create: {
      name: 'Aarast Backend Demo Provider',
      phone: '+967700999002',
      email: 'backend-provider@aarast.local',
      passwordHash,
      role: UserRole.PROVIDER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
      locale: 'ar',
      onboardingPath: OnboardingPath.PROVIDER,
      onboardingCompletedAt: new Date(),
    },
    update: {
      name: 'Aarast Backend Demo Provider',
      role: UserRole.PROVIDER,
      status: UserStatus.ACTIVE,
      onboardingPath: OnboardingPath.PROVIDER,
      onboardingCompletedAt: new Date(),
    },
  });

  const plan =
    (await prisma.weddingPlan.findFirst({
      where: {
        ownerUserId: user.id,
        title: 'Aarast Backend Completion Demo Plan',
      },
    })) ??
    (await prisma.weddingPlan.create({
      data: {
        ownerUserId: user.id,
        title: 'Aarast Backend Completion Demo Plan',
        city: 'Sanaa',
        location: {
          governorate: 'Sanaa',
          city: 'Sanaa',
        },
        weddingDate: new Date('2026-12-31T00:00:00.000Z'),
        priorities: ['budget', 'tasks', 'guests', 'providers'],
        estimatedBudget: '1500000',
        currency: 'YER',
        onboardingPath: OnboardingPath.USER,
        persona: WeddingPersona.GROOM,
        onboardingCompletedAt: new Date(),
        status: WeddingPlanStatus.PLANNING,
      },
    }));

  await prisma.weddingPlan.update({
    where: { id: plan.id },
    data: {
      city: 'Sanaa',
      weddingDate: new Date('2026-12-31T00:00:00.000Z'),
      priorities: ['budget', 'tasks', 'guests', 'providers'],
      estimatedBudget: '1500000',
      currency: 'YER',
      status: WeddingPlanStatus.PLANNING,
    },
  });

  await prisma.user.update({
    where: { id: user.id },
    data: { activeWeddingPlanId: plan.id },
  });

  const budgetCategory = await upsertBudgetCategory(
    plan.id,
    'Backend Completion Hall',
    '600000',
  );
  const cost = await upsertWeddingCost(
    plan.id,
    budgetCategory.id,
  );
  await upsertCostPayment(cost.id);
  await upsertPaymentSchedule(cost.id);
  const task = await upsertTask(plan.id, user.id);
  await upsertTaskChecklistItem(task.id);
  const guestGroup = await upsertGuestGroup(plan.id);
  await upsertGuest(plan.id, guestGroup.id);

  const provider = await upsertBackendCompletionProvider(
    providerUser.id,
    cities.Sanaa,
    categories['wedding-halls'],
  );
  const service = await upsertBackendCompletionService(
    provider.id,
    categories['wedding-halls'],
    cities.Sanaa,
  );
  const quoteRequest = await upsertBackendCompletionQuoteRequest(
    user.id,
    plan.id,
    provider.id,
    service.id,
    cities.Sanaa,
  );
  const quoteOffer = await upsertBackendCompletionQuoteOffer(
    quoteRequest.id,
    provider.id,
  );
  await upsertBackendCompletionProviderLink(
    plan.id,
    provider.id,
    quoteRequest.id,
    quoteOffer.id,
  );
  await upsertBackendCompletionNotification(user.id, plan.id, quoteRequest.id, quoteOffer.id);
}

async function upsertBudgetCategory(
  weddingPlanId: string,
  name: string,
  allocatedAmount: string,
) {
  const normalizedName = name.trim().replace(/\s+/g, ' ').toLowerCase();
  const existing = await prisma.budgetCategory.findFirst({
    where: { weddingPlanId, name },
  });
  if (existing) {
    return prisma.budgetCategory.update({
      where: { id: existing.id },
      data: { name, normalizedName, allocatedAmount },
    });
  }
  return prisma.budgetCategory.create({
    data: { weddingPlanId, name, normalizedName, allocatedAmount },
  });
}

async function upsertWeddingCost(
  weddingPlanId: string,
  budgetCategoryId: string,
) {
  const title = 'Backend Completion Hall Cost';
  const existing = await prisma.weddingCost.findFirst({
    where: { weddingPlanId, title },
  });
  const data = {
    budgetCategoryId,
    partyName: 'Backend Completion Party',
    partyPhone: '+967700999003',
    totalAmount: '120000',
    paidAmount: '40000',
    dueDate: new Date('2026-11-30T00:00:00.000Z'),
    agreementDate: new Date(),
    status: WeddingCostStatus.PARTIALLY_PAID,
    note: 'Seeded by backend completion seed',
  };
  if (existing) {
    return prisma.weddingCost.update({ where: { id: existing.id }, data });
  }
  return prisma.weddingCost.create({
    data: { weddingPlanId, title, ...data },
  });
}

async function upsertCostPayment(weddingCostId: string) {
  const note = 'Backend Completion Initial Payment';
  const existing = await prisma.costPayment.findFirst({
    where: { weddingCostId, note, entryType: CostPaymentType.PAYMENT },
  });
  const data = {
    amount: '40000',
    entryType: CostPaymentType.PAYMENT,
    paidAt: new Date(),
    note,
  };
  if (existing) {
    return prisma.costPayment.update({ where: { id: existing.id }, data });
  }
  return prisma.costPayment.create({ data: { weddingCostId, ...data } });
}

async function upsertPaymentSchedule(weddingCostId: string) {
  const note = 'Backend Completion Payment Schedule';
  const existing = await prisma.paymentSchedule.findFirst({
    where: { weddingCostId, note },
  });
  const data = {
    amount: '80000',
    dueDate: new Date('2026-11-30T00:00:00.000Z'),
    paidAt: null,
    status: PaymentScheduleStatus.PENDING,
    note,
  };
  if (existing) {
    return prisma.paymentSchedule.update({
      where: { id: existing.id },
      data,
    });
  }
  return prisma.paymentSchedule.create({ data: { weddingCostId, ...data } });
}

async function upsertTask(weddingPlanId: string, assigneeUserId: string) {
  const existing = await prisma.weddingTask.findFirst({
    where: { weddingPlanId, title: 'Backend Completion Checklist Task' },
  });
  const data = {
    assigneeUserId,
    description: 'Seeded task for full backend completion smoke.',
    dueDate: new Date('2026-10-01T00:00:00.000Z'),
    taskCategory: 'backend-completion',
    status: WeddingTaskStatus.IN_PROGRESS,
    priority: WeddingTaskPriority.HIGH,
  };
  if (existing) {
    return prisma.weddingTask.update({ where: { id: existing.id }, data });
  }
  return prisma.weddingTask.create({
    data: { weddingPlanId, title: 'Backend Completion Checklist Task', ...data },
  });
}

async function upsertTaskChecklistItem(taskId: string) {
  const existing = await prisma.weddingTaskChecklistItem.findFirst({
    where: { taskId, title: 'Backend Completion Checklist Item' },
  });
  const data = { isDone: false, sortOrder: 1 };
  if (existing) {
    return prisma.weddingTaskChecklistItem.update({
      where: { id: existing.id },
      data,
    });
  }
  return prisma.weddingTaskChecklistItem.create({
    data: { taskId, title: 'Backend Completion Checklist Item', ...data },
  });
}

async function upsertGuestGroup(weddingPlanId: string) {
  const existing = await prisma.guestGroup.findFirst({
    where: { weddingPlanId, name: 'Backend Completion Guests' },
  });
  const data = { notes: 'Seeded guest group', sortOrder: 1 };
  if (existing) {
    return prisma.guestGroup.update({ where: { id: existing.id }, data });
  }
  return prisma.guestGroup.create({
    data: { weddingPlanId, name: 'Backend Completion Guests', ...data },
  });
}

async function upsertGuest(weddingPlanId: string, groupId: string) {
  const existing = await prisma.guest.findFirst({
    where: { weddingPlanId, normalizedPhone: '700999004' },
  });
  const data = {
    groupId,
    name: 'Backend Completion Guest',
    normalizedName: 'backend completion guest',
    phone: '+967700999004',
    normalizedPhone: '700999004',
    side: GuestSide.FAMILY,
    status: GuestStatus.CONFIRMED,
    invitationStatus: GuestInvitationStatus.SENT,
    attendanceStatus: GuestAttendanceStatus.CONFIRMED,
    seatsCount: 2,
    companionsCount: 1,
    notes: 'Seeded guest',
  };
  if (existing) {
    return prisma.guest.update({ where: { id: existing.id }, data });
  }
  return prisma.guest.create({ data: { weddingPlanId, ...data } });
}

async function upsertBackendCompletionProvider(
  userId: string,
  cityId: string,
  primaryCategoryId: string,
) {
  const provider =
    (await prisma.provider.findUnique({ where: { userId } })) ??
    (await prisma.provider.create({
      data: {
        userId,
        cityId,
        primaryCategoryId,
        businessName: 'Aarast Backend Demo Provider',
        ownerName: 'Backend Provider Owner',
        phone: '+967700999002',
        whatsapp: '+967700999002',
        description: 'Seeded active provider for backend completion.',
        status: ProviderStatus.ACTIVE,
        isFeatured: true,
      },
    }));

  return prisma.provider.update({
    where: { id: provider.id },
    data: {
      cityId,
      primaryCategoryId,
      businessName: 'Aarast Backend Demo Provider',
      ownerName: 'Backend Provider Owner',
      phone: '+967700999002',
      whatsapp: '+967700999002',
      description: 'Seeded active provider for backend completion.',
      status: ProviderStatus.ACTIVE,
      isFeatured: true,
    },
  });
}

async function upsertBackendCompletionService(
  providerId: string,
  categoryId: string,
  cityId: string,
) {
  const existing = await prisma.providerService.findFirst({
    where: { providerId, title: 'Backend Completion Provider Service' },
  });
  const data = {
    categoryId,
    description: 'Seeded service for backend completion.',
    basePrice: '300000',
    priceUnit: 'event',
    currency: 'YER',
    cityId,
    isActive: true,
    isFeatured: true,
  };
  if (existing) {
    return prisma.providerService.update({ where: { id: existing.id }, data });
  }
  return prisma.providerService.create({
    data: { providerId, title: 'Backend Completion Provider Service', ...data },
  });
}

async function upsertBackendCompletionQuoteRequest(
  userId: string,
  weddingPlanId: string,
  providerId: string,
  serviceId: string,
  cityId: string,
) {
  const existing = await prisma.quoteRequest.findFirst({
    where: { weddingPlanId, providerId, message: 'Backend completion seeded quote' },
  });
  const data = {
    userId,
    providerId,
    serviceId,
    eventDate: new Date('2026-12-31T00:00:00.000Z'),
    cityId,
    guestCount: 120,
    message: 'Backend completion seeded quote',
    budgetMin: '250000',
    budgetMax: '450000',
    status: QuoteRequestStatus.ACCEPTED,
  };
  let conversation = await prisma.conversation.findFirst({
    where: { scope: ConversationScope.PLAN, weddingPlanId, providerId },
    select: { id: true },
  });
  if (!conversation) {
    const provider = await prisma.provider.findUnique({
      where: { id: providerId },
      select: { userId: true },
    });
    conversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.PLAN,
        weddingPlanId,
        providerId,
        createdByUserId: userId,
        participants: {
          create: [
            { userId },
            ...(provider?.userId && provider.userId !== userId
              ? [{ userId: provider.userId }]
              : []),
          ],
        },
      },
      select: { id: true },
    });
  }
  const quote = existing
    ? await prisma.quoteRequest.update({
        where: { id: existing.id },
        data: { ...data, conversationId: conversation.id },
      })
    : await prisma.quoteRequest.create({
        data: { weddingPlanId, conversationId: conversation.id, ...data },
      });
  await prisma.conversationEvent.upsert({
    where: { dedupeKey: `quote-request:${quote.id}:created` },
    update: {},
    create: {
      conversationId: conversation.id,
      quoteRequestId: quote.id,
      actorUserId: userId,
      type: ConversationEventType.QUOTE_REQUEST_CREATED,
      occurredAt: quote.createdAt,
      dedupeKey: `quote-request:${quote.id}:created`,
      data: { status: QuoteRequestStatus.SENT },
    },
  });
  return quote;
}

async function upsertBackendCompletionQuoteOffer(
  quoteRequestId: string,
  providerId: string,
) {
  const existing = await prisma.quoteOffer.findFirst({
    where: { quoteRequestId, providerId, message: 'Backend completion seeded offer' },
  });
  const data = {
    title: 'Backend Completion Offer',
    message: 'Backend completion seeded offer',
    amount: '320000',
    currency: 'YER',
    validUntil: new Date('2026-12-01T00:00:00.000Z'),
    status: QuoteOfferStatus.ACCEPTED,
  };
  if (existing) {
    return prisma.quoteOffer.update({ where: { id: existing.id }, data });
  }
  return prisma.quoteOffer.create({
    data: { quoteRequestId, providerId, ...data },
  });
}

async function upsertBackendCompletionProviderLink(
  weddingPlanId: string,
  providerId: string,
  quoteRequestId: string,
  quoteOfferId: string,
) {
  return prisma.planProviderLink.upsert({
    where: {
      weddingPlanId_providerId: {
        weddingPlanId,
        providerId,
      },
    },
    update: {
      quoteRequestId,
      quoteOfferId,
      status: PlanProviderLinkStatus.ACTIVE,
    },
    create: {
      weddingPlanId,
      providerId,
      quoteRequestId,
      quoteOfferId,
      status: PlanProviderLinkStatus.ACTIVE,
    },
  });
}

async function upsertBackendCompletionNotification(
  userId: string,
  weddingPlanId: string,
  quoteRequestId: string,
  quoteOfferId: string,
) {
  return prisma.notification.upsert({
    where: {
      dedupeKey: `${userId}:backend-completion:quote-offer`,
    },
    update: {
      readAt: null,
      data: {
        quoteRequestId,
        quoteOfferId,
        weddingPlanId,
      },
    },
    create: {
      userId,
      weddingPlanId,
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      title: 'Backend completion quote offer',
      body: 'A seeded quote offer is ready for the backend completion demo.',
      data: {
        quoteRequestId,
        quoteOfferId,
        weddingPlanId,
      },
      dedupeKey: `${userId}:backend-completion:quote-offer`,
    },
  });
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
