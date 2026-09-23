import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import {
  AdminRole,
  NotificationPriority,
  NotificationType,
  Prisma,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from '@prisma/client';
import * as adminPresenter from '../src/admin/admin.presenter';
import { AdminService } from '../src/admin/admin.service';
import { adminService } from './support/owner-ports';

interface AdminPresenterHarness {
  toCityResponse(value: unknown): Record<string, unknown>;
  toCategoryResponse(value: unknown): Record<string, unknown>;
  toProviderResponse(value: unknown): Record<string, any>;
  toAdminServiceResponse(value: unknown): Record<string, any>;
  toAdminReviewResponse(value: unknown): Record<string, any>;
  toAdminNotificationResponse(value: unknown): Record<string, any>;
  toUserResponse(value: unknown): Record<string, any>;
  toSafeUser(value: unknown): Record<string, unknown>;
}

function currentPresenter(): AdminPresenterHarness {
  return adminPresenter as unknown as AdminPresenterHarness;
}

const createdAt = new Date('2026-07-01T08:00:00.000Z');
const updatedAt = new Date('2026-07-02T09:00:00.000Z');

test('admin extraction keeps DI, mutations and query builders inside AdminService', () => {
  const sourceRoot = resolve(__dirname, '../src/admin');
  const serviceSource = readFileSync(resolve(sourceRoot, 'admin.service.ts'), 'utf8');
  const presenterSource = readFileSync(resolve(sourceRoot, 'admin.presenter.ts'), 'utf8');
  const controllerSource = readFileSync(resolve(sourceRoot, 'admin.controller.ts'), 'utf8');
  const moduleSource = readFileSync(
    resolve(__dirname, '../src/modules/backoffice/internal/backoffice-services.internal.module.ts'),
    'utf8',
  );

  assert.ok(
    serviceSource.split(/\r?\n/).length <= 1250,
    'AdminService must stay within the post-extraction 1250-line boundary',
  );
  assert.match(serviceSource, /constructor\(\s*private readonly prisma: PrismaService,/);
  assert.match(serviceSource, /private async reviewProvider\(/);
  assert.match(serviceSource, /async disableUser\(/);
  assert.match(serviceSource, /this\.prisma\.\$transaction\(/);
  // The where builders moved to the owners (marketplace, notifications);
  // the service parses the query into the owners' declared filters.
  assert.match(serviceSource, /this\.owners\.marketplace\.listProviders\(/);
  assert.match(serviceSource, /private serviceFilter\(/);
  assert.match(serviceSource, /private notificationFilter\(/);
  assert.doesNotMatch(serviceSource, /private to[A-Za-z]+Response\(/);
  assert.doesNotMatch(
    presenterSource,
    /@nestjs|PrismaService|this\.prisma|\$transaction|WhereInput/,
  );
  assert.doesNotMatch(controllerSource, /admin\.presenter|admin\.contracts/);
  assert.doesNotMatch(moduleSource, /admin\.presenter|admin\.contracts/);
  assert.match(controllerSource, /constructor\(private readonly adminService: AdminService\)/);
  // AdminOwners holds the owners' ports the service and executor reach.
  assert.match(moduleSource, /providers:\s*\[AdminOwners,\s*AdminService,\s*AdminAuditService\]/);
});

test('admin report aggregation preserves totals, formatting and honesty flags', () => {
  const users = adminPresenter.toAdminUserReport({
    total: 20,
    active: 18,
    disabled: 2,
    admins: 2,
    providers: 3,
  });
  const reviews = adminPresenter.toAdminReviewReport({
    total: 4,
    published: 3,
    hidden: 1,
    pending: 0,
    averageRating: 4.25,
  });
  const quotes = adminPresenter.toAdminQuoteReport([
    { status: QuoteRequestStatus.SENT, count: 5 },
    { status: QuoteRequestStatus.ACCEPTED, count: 2 },
  ]);
  const generatedAt = new Date('2026-07-11T10:00:00.000Z');
  const from = new Date('2026-07-01T00:00:00.000Z');
  const overview = adminPresenter.toAdminReportsOverviewResponse({
    generatedAt,
    from,
    to: null,
    users,
    providers: {
      total: 3,
      pending: 1,
      active: 2,
      needsChanges: 0,
      suspended: 0,
      rejected: 0,
      featured: 1,
    },
    services: { total: 6, active: 5, disabled: 1, featured: 2 },
    reviews,
    quotes,
    notifications: { total: 9, unread: 2, archived: 1, high: 3, urgent: 1 },
    cities: 4,
    categories: 7,
    weddingPlans: 12,
  });

  assert.equal(users.regularUsers, 15);
  assert.equal(reviews.averageRating, '4.25');
  assert.equal(quotes.total, 7);
  assert.deepEqual(overview.range, { from, to: null });
  assert.deepEqual(overview.catalog, { cities: 4, categories: 7 });
  assert.deepEqual(overview.weddingPlans, { total: 12 });
  assert.equal(overview.generatedAt, generatedAt);
  assert.equal(overview.source, 'admin_operational_database');
  assert.equal(overview.paymentOrDepositDataIncluded, false);
});

test('admin catalog and user mappers preserve response allowlists', () => {
  const presenter = currentPresenter();
  const city = cityFixture();
  const category = categoryFixture();

  assert.deepEqual(presenter.toCityResponse(city), {
    id: 'city-1',
    nameAr: 'صنعاء',
    nameEn: 'Sanaa',
    countryCode: 'YE',
    isActive: true,
    sortOrder: 2,
    createdAt,
    updatedAt,
    providersCount: 3,
    servicesCount: 4,
  });
  assert.deepEqual(presenter.toCategoryResponse(category), {
    id: 'category-1',
    nameAr: 'قاعات',
    nameEn: 'Venues',
    slug: 'venues',
    icon: 'building',
    showForGroom: true,
    showForBride: false,
    isActive: true,
    sortOrder: 1,
    createdAt,
    updatedAt,
    providersCount: 5,
    servicesCount: 6,
  });

  const safeUser = presenter.toSafeUser({
    ...safeUserFixture(),
    passwordHash: 'must-never-leak',
    adminRole: 'SUPER_ADMIN',
  });
  assert.deepEqual(safeUser, safeUserFixture());
  assert.equal('passwordHash' in safeUser, false);
  assert.equal('adminRole' in safeUser, false);
});

test('admin provider mapper preserves nested shape and money serialization', () => {
  const response = currentPresenter().toProviderResponse(providerFixture());

  assert.deepEqual(Object.keys(response), [
    'id',
    'userId',
    'user',
    'cityId',
    'city',
    'primaryCategoryId',
    'primaryCategory',
    'businessName',
    'ownerName',
    'phone',
    'whatsapp',
    'email',
    'description',
    'address',
    'logoUrl',
    'coverUrl',
    'status',
    'reviewNote',
    'reviewedAt',
    'reviewedBy',
    'isFeatured',
    'ratingAverage',
    'ratingCount',
    'servicesCount',
    'packagesCount',
    'quoteRequestsCount',
    'reviewsCount',
    'services',
    'packages',
    'createdAt',
    'updatedAt',
  ]);
  assert.equal(response.ratingAverage, '4.75');
  assert.equal(response.servicesCount, 7);
  assert.equal(response.packagesCount, 2);
  assert.equal(response.services[0].basePrice, '1250.5');
  assert.equal(response.packages[0].price, '2500');
  assert.deepEqual(response.user, safeUserFixture());
  assert.equal('latitude' in response, false);
  assert.equal('longitude' in response, false);
});

test('admin service and review mappers preserve public shape and review privacy', () => {
  const presenter = currentPresenter();
  const provider = providerFixture();
  const service = serviceFixture();
  const serviceResponse = presenter.toAdminServiceResponse({
    ...service,
    provider,
  });

  assert.equal(serviceResponse.basePrice, '1250.5');
  assert.equal(serviceResponse.provider.businessName, 'قاعة النور');
  assert.deepEqual(serviceResponse.images[0], {
    id: 'image-1',
    serviceId: 'service-1',
    imageUrl: 'https://cdn.example.test/venue.webp',
    altText: 'قاعة',
    sortOrder: 0,
    createdAt,
  });

  const reviewResponse = presenter.toAdminReviewResponse({
    id: 'review-1',
    userId: 'user-1',
    providerId: provider.id,
    rating: 5,
    comment: 'خدمة ممتازة',
    status: ReviewStatus.PUBLISHED,
    createdAt,
    updatedAt,
    user: {
      id: 'user-1',
      name: 'مستخدم',
      phone: '+967777123456',
      email: 'private@example.test',
    },
    provider,
  });
  assert.deepEqual(reviewResponse.user, { id: 'user-1', name: 'مستخدم' });
  assert.equal('phone' in reviewResponse.user, false);
  assert.equal('email' in reviewResponse.user, false);
});

test('admin cannot reassign a service whose media belongs to another provider', async () => {
  let updateCalls = 0;
  const prisma: any = {
    $queryRaw: async (query: { strings?: readonly string[] }) => {
      const sql = query.strings?.join('') ?? '';
      if (sql.includes('FROM "User"')) {
        return [{
          id: 'admin-1',
          role: UserRole.ADMIN,
          adminRole: AdminRole.OPERATIONS,
          status: UserStatus.ACTIVE,
        }];
      }
      if (sql.includes('FROM "Provider"')) {
        return [{ id: 'provider-a' }];
      }
      return [];
    },
    providerService: {
      findUnique: async () => ({
        ...serviceFixture(),
        providerId: 'provider-a',
      }),
      update: async () => {
        updateCalls += 1;
        return { ...serviceFixture(), provider: providerFixture() };
      },
    },
    provider: {
      findUnique: async () => ({ id: 'provider-b' }),
    },
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const service = adminService(
    prisma as never,
    { disconnectUser: () => undefined } as never,
    { createNotificationInTransaction: async () => null } as never,
  );

  await assert.rejects(
    () =>
      service.updateService(
        { id: 'admin-1' } as any,
        'service-1',
        { providerId: 'provider-b' },
      ),
    BadRequestException,
  );
  assert.equal(updateCalls, 0);
});

test('admin notification mapper keeps financial privacy and masked identity', () => {
  const response = currentPresenter().toAdminNotificationResponse({
    id: 'notification-1',
    userId: 'user-1',
    weddingPlanId: 'plan-1',
    type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
    priority: NotificationPriority.HIGH,
    title: 'قسط 5000 ر.ي',
    body: 'ادفع للدائن الخاص',
    entityType: 'payment_schedule',
    entityId: 'schedule-1',
    routeTarget: '/wedding-plans/plan-1/money/costs/cost-1/schedules',
    data: { amount: '5000', creditor: 'private' },
    dedupeKey: null,
    readAt: null,
    archivedAt: null,
    createdAt,
    updatedAt,
    user: {
      id: 'user-1',
      name: 'مستخدم',
      phone: '+967 777 123 456',
    },
    weddingPlan: { id: 'plan-1', title: 'زفاف خاص', city: 'صنعاء' },
  });

  assert.equal(response.user.phoneMasked, '••••3456');
  assert.equal('phone' in response.user, false);
  assert.equal(response.title, 'إشعار مالي');
  assert.equal(response.body, 'تم إخفاء التفاصيل المالية لحماية خصوصية المستخدم.');
  assert.equal(response.weddingPlan, null);
  assert.equal(response.entityId, null);
  assert.equal(response.routeTarget, null);
  assert.equal(response.data, null);
  assert.equal(response.financialDetailsRedacted, true);
});

test('admin user mapper preserves provider summary without account internals', () => {
  const response = currentPresenter().toUserResponse({
    ...safeUserFixture(),
    passwordHash: 'must-never-leak',
    providerProfile: providerFixture(),
  });

  assert.deepEqual(Object.keys(response), [
    'id',
    'name',
    'phone',
    'email',
    'role',
    'status',
    'avatarUrl',
    'createdAt',
    'updatedAt',
    'provider',
  ]);
  assert.equal(response.provider.businessName, 'قاعة النور');
  assert.equal('passwordHash' in response, false);
  assert.equal('phone' in response.provider, false);
  assert.equal('whatsapp' in response.provider, false);
});

function safeUserFixture() {
  return {
    id: 'user-1',
    name: 'مدير الاختبار',
    phone: '+967777123456',
    email: 'admin@example.test',
    role: UserRole.ADMIN,
    status: UserStatus.ACTIVE,
    avatarUrl: 'https://cdn.example.test/avatar.webp',
    createdAt,
    updatedAt,
  };
}

function cityFixture() {
  return {
    id: 'city-1',
    nameAr: 'صنعاء',
    nameEn: 'Sanaa',
    countryCode: 'YE',
    isActive: true,
    sortOrder: 2,
    createdAt,
    updatedAt,
    _count: { providers: 3, services: 4 },
  };
}

function categoryFixture() {
  return {
    id: 'category-1',
    nameAr: 'قاعات',
    nameEn: 'Venues',
    slug: 'venues',
    icon: 'building',
    showForGroom: true,
    showForBride: false,
    isActive: true,
    sortOrder: 1,
    createdAt,
    updatedAt,
    _count: { providers: 5, services: 6 },
  };
}

function serviceFixture() {
  return {
    id: 'service-1',
    providerId: 'provider-1',
    categoryId: 'category-1',
    title: 'الباقة الذهبية',
    description: 'خدمة متكاملة',
    basePrice: new Prisma.Decimal('1250.50'),
    priceUnit: 'event',
    currency: 'YER',
    cityId: 'city-1',
    isActive: true,
    isFeatured: true,
    createdAt,
    updatedAt,
    category: categoryFixture(),
    city: cityFixture(),
    images: [
      {
        id: 'image-1',
        serviceId: 'service-1',
        imageUrl: 'https://cdn.example.test/venue.webp',
        altText: 'قاعة',
        sortOrder: 0,
        createdAt,
      },
    ],
  };
}

function providerFixture() {
  const service = serviceFixture();
  return {
    id: 'provider-1',
    userId: 'user-1',
    cityId: 'city-1',
    primaryCategoryId: 'category-1',
    businessName: 'قاعة النور',
    ownerName: 'مالك القاعة',
    phone: '+967777000111',
    whatsapp: '+967777000111',
    email: 'venue@example.test',
    description: 'قاعة زفاف',
    address: 'صنعاء',
    latitude: new Prisma.Decimal('15.3694'),
    longitude: new Prisma.Decimal('44.1910'),
    logoUrl: 'https://cdn.example.test/logo.webp',
    coverUrl: 'https://cdn.example.test/cover.webp',
    status: ProviderStatus.ACTIVE,
    reviewNote: null,
    reviewedAt: updatedAt,
    reviewedById: 'reviewer-1',
    isFeatured: true,
    ratingAverage: new Prisma.Decimal('4.75'),
    ratingCount: 18,
    createdAt,
    updatedAt,
    user: safeUserFixture(),
    reviewedBy: { ...safeUserFixture(), id: 'reviewer-1' },
    city: cityFixture(),
    primaryCategory: categoryFixture(),
    services: [service],
    packages: [
      {
        id: 'package-1',
        providerId: 'provider-1',
        serviceId: 'service-1',
        title: 'الباقة الكاملة',
        description: 'تفاصيل الباقة',
        price: new Prisma.Decimal('2500'),
        currency: 'YER',
        items: ['قاعة', 'ضيافة'],
        isActive: true,
        createdAt,
        updatedAt,
        service,
      },
    ],
    _count: {
      services: 7,
      packages: 2,
      quoteRequests: 9,
      reviews: 18,
    },
  };
}
