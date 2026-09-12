import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";
import { recordConversationEvent } from "../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent,
};
import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { HttpException } from '@nestjs/common';
import {
  AppRole,
  ConversationScope,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { ConversationsService } from '../src/conversations/conversations.service';
import { acceptQuoteOfferInTransaction } from '../src/marketplace/quote-offer-acceptance';
import { ProviderDashboardService } from '../src/provider-dashboard/provider-dashboard.service';

const providerUserId = '11111111-1111-4111-8111-111111111111';
const providerId = '22222222-2222-4222-8222-222222222222';
const categoryId = '33333333-3333-4333-8333-333333333333';
const serviceId = '44444444-4444-4444-8444-444444444444';
const quoteRequestId = '55555555-5555-4555-8555-555555555555';
const conversationId = '66666666-6666-4666-8666-666666666666';
const requesterUserId = '77777777-7777-4777-8777-777777777777';
const imageId = '88888888-8888-4888-8888-888888888889';
const packageId = '99999999-9999-4999-8999-999999999998';
const quoteOfferId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab';
const privateContactName = 'Private Quote Requester';
const privateContactPhone = '+967700000001';
const now = new Date('2026-07-26T00:00:00.000Z');
const city = {
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  nameAr: 'صنعاء',
  nameEn: 'Sanaa',
  countryCode: 'YE',
  sortOrder: 1,
  isActive: true,
  createdAt: now,
  updatedAt: now,
};

const currentProvider = {
  id: providerUserId,
  name: 'Provider Owner',
  appName: null,
  phone: '+967700000002',
  email: null,
  role: UserRole.PROVIDER,
  adminRole: null,
  appRole: AppRole.PROVIDER,
  status: UserStatus.ACTIVE,
  phoneVerifiedAt: now,
  lastLoginAt: now,
  avatarUrl: null,
  appAvatarUrl: null,
  locale: 'ar',
  activeWeddingPlanId: null,
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: now,
  createdAt: now,
  updatedAt: now,
} as any;

const requester = {
  id: requesterUserId,
  name: privateContactName,
  appName: null,
  phone: privateContactPhone,
  role: UserRole.USER,
  avatarUrl: null,
  appAvatarUrl: null,
};

const category = {
  id: categoryId,
  nameAr: 'قاعات',
  nameEn: 'Venues',
  slug: 'venues',
  icon: null,
  sortOrder: 1,
  isActive: true,
  createdAt: now,
  updatedAt: now,
};

function providerFor(status: ProviderStatus) {
  return {
    id: providerId,
    userId: providerUserId,
    cityId: city.id,
    primaryCategoryId: categoryId,
    businessName: 'Provider Business',
    ownerName: null,
    phone: '+967700000003',
    whatsapp: null,
    email: null,
    description: null,
    address: null,
    latitude: null,
    longitude: null,
    logoUrl: null,
    coverUrl: null,
    status,
    reviewNote: null,
    reviewedAt: null,
    reviewedById: null,
    isFeatured: false,
    ratingAverage: { toString: () => '0' },
    ratingCount: 0,
    createdAt: now,
    updatedAt: now,
    city,
    primaryCategory: category,
  };
}

function quoteRecord() {
  return {
    id: quoteRequestId,
    conversationId,
    userId: requesterUserId,
    user: requester,
    weddingPlanId: null,
    weddingPlan: null,
    providerId,
    serviceId: null,
    service: null,
    eventDate: null,
    location: null,
    cityId: null,
    guestCount: null,
    contactName: privateContactName,
    contactPhone: privateContactPhone,
    contactNormalizedPhone: privateContactPhone,
    message: 'Private quote details',
    budgetMin: null,
    budgetMax: null,
    status: QuoteRequestStatus.SENT,
    offers: [],
    acceptedAt: null,
    rejectedAt: null,
    cancelledAt: null,
    createdAt: now,
    updatedAt: now,
  };
}

function createProviderDashboard(status: ProviderStatus) {
  const provider = providerFor(status);
  const prisma: any = {
    $queryRaw: async (query: {
      strings?: readonly string[];
      values?: readonly unknown[];
    }) => {
      const sql = query.strings?.join('') ?? '';
      if (sql.includes('FROM "User"')) {
        const requestedUserIds = [...new Set(query.values ?? [])]
          .filter(
            (value): value is string =>
              value === providerUserId || value === requesterUserId,
          )
          .sort();
        return requestedUserIds.map((id) => ({
          id,
          status: UserStatus.ACTIVE,
        }));
      }
      if (sql.includes('FROM "Provider"')) {
        return [{ id: providerId }];
      }
      if (sql.includes('FROM "ProviderCategory"')) {
        return [{ id: categoryId }];
      }
      return [];
    },
    provider: {
      findUnique: async () => provider,
      update: async ({ data }: any) => ({ ...provider, ...data }),
    },
    providerCategory: {
      findFirst: async () => category,
      count: async () => 1,
    },
    providerService: {
      create: async ({ data }: any) => ({
        id: serviceId,
        ...data,
        description: data.description ?? null,
        basePrice: data.basePrice ?? null,
        priceUnit: data.priceUnit ?? null,
        cityId: data.cityId ?? null,
        currency: data.currency ?? 'YER',
        isActive: true,
        isFeatured: false,
        category,
        city: null,
        images: [],
        createdAt: now,
        updatedAt: now,
      }),
    },
    quoteRequest: {
      findMany: async () => [quoteRecord()],
      findUnique: async () => quoteRecord(),
    },
    quoteOffer: {
      findUnique: async () => ({
        id: quoteOfferId,
        providerId,
        quoteRequest: {
          userId: requesterUserId,
          weddingPlanId: null,
          conversationId,
        },
      }),
    },
  };
  prisma.$transaction = async (operation: (client: any) => Promise<unknown>) =>
    operation(prisma);
  return new ProviderDashboardService(
    prisma as any,
    {} as any,
    {
      verifyPublicMediaUrl: async (
        _currentUser: unknown,
        url: string,
      ) => url,
    } as any, lifecycle,
  );
}

function conversationRecord(status: ProviderStatus) {
  return {
    id: conversationId,
    scope: ConversationScope.ACCOUNT,
    weddingPlanId: null,
    accountRequesterUserId: requesterUserId,
    providerId,
    provider: {
      id: providerId,
      userId: providerUserId,
      businessName: 'Provider Business',
      logoUrl: null,
      status,
      user: {
        id: providerUserId,
        name: currentProvider.name,
        appName: null,
        role: UserRole.PROVIDER,
        appRole: AppRole.PROVIDER,
        avatarUrl: null,
        appAvatarUrl: null,
      },
    },
    weddingPlan: null,
    accountRequester: {
      id: requesterUserId,
      name: privateContactName,
      appName: null,
      role: UserRole.USER,
      appRole: AppRole.WEDDING_USER,
      avatarUrl: null,
      appAvatarUrl: null,
    },
    participants: [
      {
        id: '88888888-8888-4888-8888-888888888888',
        conversationId,
        userId: providerUserId,
        lastReadAt: null,
        mutedAt: null,
        revokedAt: null,
        createdAt: now,
        updatedAt: now,
        user: {
          id: providerUserId,
          name: currentProvider.name,
          appName: null,
          role: UserRole.PROVIDER,
          appRole: AppRole.PROVIDER,
          avatarUrl: null,
          appAvatarUrl: null,
        },
      },
      {
        id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        conversationId,
        userId: requesterUserId,
        lastReadAt: null,
        mutedAt: null,
        revokedAt: null,
        createdAt: now,
        updatedAt: now,
        user: {
          id: requesterUserId,
          name: requester.name,
          appName: null,
          role: UserRole.USER,
          appRole: AppRole.WEDDING_USER,
          avatarUrl: null,
          appAvatarUrl: null,
        },
      },
    ],
    quoteRequests: [quoteRecord()],
    messages: [],
    _count: { quoteRequests: 1 },
    lastActivityAt: now,
    customerSideBlockedAt: null,
    customerSideBlockedById: null,
    providerSideBlockedAt: null,
    closedAt: null,
    createdAt: now,
    updatedAt: now,
  };
}

function createConversations(status: ProviderStatus) {
  const conversation = conversationRecord(status);
  const sentMessage = {
    id: '99999999-9999-4999-8999-999999999999',
    conversationId,
    senderUserId: providerUserId,
    body: 'رسالة تشغيلية',
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
    sender: {
      id: providerUserId,
      name: currentProvider.name,
      appName: null,
      role: UserRole.PROVIDER,
      avatarUrl: null,
      appAvatarUrl: null,
    },
    attachments: [],
  };
  const tx = {
    $queryRaw: async (query: { strings?: readonly string[] }) => {
      const sql = query.strings?.join('') ?? '';
      if (sql.includes('FROM "User"')) {
        return [{ id: providerUserId, status: UserStatus.ACTIVE }];
      }
      if (sql.includes('FROM "WeddingPlan"')) {
        return [{ id: 'plan-1' }];
      }
      if (sql.includes('FROM "Provider"')) {
        return [{ id: providerId }];
      }
      if (sql.includes('FROM "ConversationParticipant"')) {
        return [{ id: 'participant-provider' }];
      }
      return [{ id: conversationId }];
    },
    provider: {
      findUnique: async () => providerFor(status),
    },
    conversation: {
      findUnique: async () => conversation,
      update: async () => conversation,
    },
    conversationParticipant: {
      createMany: async () => ({ count: 1 }),
      updateMany: async () => ({ count: 1 }),
      findMany: async () => [],
    },
    chatMessage: {
      create: async () => sentMessage,
    },
    notificationPreference: {
      findMany: async () => [],
    },
  };
  const prisma = {
    provider: {
      findUnique: async () => providerFor(status),
    },
    conversation: {
      findUnique: async () => conversation,
      findUniqueOrThrow: async () => conversation,
      findMany: async ({ where, select }: any) => {
        const requiresActiveProvider = JSON.stringify(where).includes(
          `"status":"${ProviderStatus.ACTIVE}"`,
        );
        if (status !== ProviderStatus.ACTIVE && requiresActiveProvider) {
          return [];
        }
        if (select) {
          return [
            {
              id: conversationId,
              provider: { userId: providerUserId },
            },
          ];
        }
        return [conversation];
      },
    },
    conversationParticipant: {
      createMany: async () => ({ count: 1 }),
      updateMany: async () => ({ count: 1 }),
    },
    $queryRaw: async () => [],
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  return new ConversationsService(
    prisma as any,
    { createNotificationInTransaction: async () => undefined } as any,
    {
      message: () => undefined,
      activityAvailable: () => undefined,
      revokeConversationAccess: () => undefined,
    } as any,
    {} as any,
    { enqueue: async () => undefined } as any,
  );
}

async function outcome<T>(operation: () => Promise<T>) {
  try {
    return { ok: true as const, value: await operation() };
  } catch (error) {
    return { ok: false as const, error };
  }
}

function exposesPrivateContact(value: unknown): boolean {
  const serialized = JSON.stringify(value);
  return (
    serialized.includes(privateContactName) ||
    serialized.includes(privateContactPhone)
  );
}

function errorCode(error: unknown): unknown {
  if (!(error instanceof HttpException)) return undefined;
  const response = error.getResponse();
  return typeof response === 'object' && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

function expectDenied(
  label: string,
  result: Awaited<ReturnType<typeof outcome>>,
  expectedCode: string,
  violations: string[],
) {
  if (result.ok) {
    violations.push(`${label}: operation succeeded`);
    return;
  }
  if (errorCode(result.error) !== expectedCode) {
    violations.push(
      `${label}: expected ${expectedCode}, received ${String(errorCode(result.error))}`,
    );
  }
}

test('only ACTIVE providers can perform provider operations or receive quote/contact PII', async () => {
  const violations: string[] = [];
  const inactiveStatuses = [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.SUSPENDED,
    ProviderStatus.REJECTED,
  ];

  for (const status of inactiveStatuses) {
    const dashboard = createProviderDashboard(status);
    const conversations = createConversations(status);
    const dashboardOperations: Array<{
      label: string;
      run: () => Promise<unknown>;
    }> = [
      {
        label: 'summary',
        run: () => dashboard.getSummary(currentProvider),
      },
      {
        label: 'service list',
        run: () => dashboard.findServices(currentProvider),
      },
      {
        label: 'service create',
        run: () =>
          dashboard.createService(currentProvider, {
            categoryId,
            title: 'Operational service',
          }),
      },
      {
        label: 'service detail',
        run: () => dashboard.findService(currentProvider, serviceId),
      },
      {
        label: 'service update',
        run: () =>
          dashboard.updateService(currentProvider, serviceId, {
            title: 'Updated operational service',
          }),
      },
      {
        label: 'service deactivate',
        run: () => dashboard.deactivateService(currentProvider, serviceId),
      },
      {
        label: 'service image create',
        run: () =>
          dashboard.createServiceImage(currentProvider, serviceId, {
            imageUrl: 'https://media.example.test/service.jpg',
          }),
      },
      {
        label: 'service image update',
        run: () =>
          dashboard.updateServiceImage(currentProvider, serviceId, imageId, {
            altText: 'Updated image',
          }),
      },
      {
        label: 'service image delete',
        run: () =>
          dashboard.deleteServiceImage(currentProvider, serviceId, imageId),
      },
      {
        label: 'package list',
        run: () => dashboard.findPackages(currentProvider),
      },
      {
        label: 'package create',
        run: () =>
          dashboard.createPackage(currentProvider, {
            title: 'Operational package',
          }),
      },
      {
        label: 'package update',
        run: () =>
          dashboard.updatePackage(currentProvider, packageId, {
            title: 'Updated operational package',
          }),
      },
      {
        label: 'package deactivate',
        run: () => dashboard.deactivatePackage(currentProvider, packageId),
      },
      {
        label: 'quote list',
        run: () => dashboard.findQuoteRequests(currentProvider),
      },
      {
        label: 'quote detail',
        run: () =>
          dashboard.findQuoteRequest(currentProvider, quoteRequestId),
      },
      {
        label: 'quote status update',
        run: () =>
          dashboard.updateQuoteRequestStatus(
            currentProvider,
            quoteRequestId,
            { status: QuoteRequestStatus.REJECTED },
          ),
      },
      {
        label: 'quote offer create',
        run: () =>
          dashboard.createQuoteOffer(currentProvider, quoteRequestId, {
            message: 'Operational offer',
            amount: '1000',
            currency: 'YER',
          }),
      },
      {
        label: 'quote offer update',
        run: () =>
          dashboard.updateQuoteOffer(currentProvider, quoteOfferId, {
            message: 'Updated operational offer',
          }),
      },
      {
        label: 'review list',
        run: () => dashboard.findReviews(currentProvider),
      },
    ];
    for (const operation of dashboardOperations) {
      expectDenied(
        `${status}: ${operation.label}`,
        await outcome(operation.run),
        'PROVIDER_NOT_ACTIVE',
        violations,
      );
    }

    const inbox = await outcome(() =>
      conversations.list(currentProvider),
    );
    if (
      !inbox.ok ||
      inbox.value.items.length !== 0 ||
      exposesPrivateContact(inbox.value)
    ) {
      violations.push(
        `${status}: provider inbox did not exclude customer conversations`,
      );
    }

    const conversation = await outcome(() =>
      conversations.get(currentProvider, conversationId),
    );
    expectDenied(
      `${status}: conversation API`,
      conversation,
      'PROVIDER_NOT_ACTIVE',
      violations,
    );

    const messageSend = await outcome(() =>
      conversations.send(currentProvider, conversationId, {
        body: 'رسالة تشغيلية',
      }),
    );
    expectDenied(
      `${status}: provider conversation send`,
      messageSend,
      'PROVIDER_NOT_ACTIVE',
      violations,
    );
  }

  const activeDashboard = createProviderDashboard(ProviderStatus.ACTIVE);
  const activeConversations = createConversations(ProviderStatus.ACTIVE);
  const activeServiceWrite = await outcome(() =>
    activeDashboard.createService(currentProvider, {
      categoryId,
      title: 'Operational service',
    }),
  );
  if (!activeServiceWrite.ok) {
    violations.push('ACTIVE: provider service creation was rejected');
  }

  const activeProviderQuotes = await outcome(() =>
    activeDashboard.findQuoteRequests(currentProvider),
  );
  if (
    !activeProviderQuotes.ok ||
    !exposesPrivateContact(activeProviderQuotes.value)
  ) {
    violations.push('ACTIVE: provider quote contact PII was unavailable');
  }

  const activeConversation = await outcome(() =>
    activeConversations.get(currentProvider, conversationId),
  );
  if (
    !activeConversation.ok ||
    !exposesPrivateContact(activeConversation.value)
  ) {
    violations.push('ACTIVE: conversation contact PII was unavailable');
  }

  const activeInbox = await outcome(() =>
    activeConversations.list(currentProvider),
  );
  if (
    !activeInbox.ok ||
    activeInbox.value.items.length !== 1 ||
    !exposesPrivateContact(activeInbox.value)
  ) {
    violations.push('ACTIVE: provider inbox customer data was unavailable');
  }

  const activeMessageSend = await outcome(() =>
    activeConversations.send(currentProvider, conversationId, {
      body: 'رسالة تشغيلية',
    }),
  );
  if (!activeMessageSend.ok) {
    violations.push('ACTIVE: provider conversation send was rejected');
  }

  assert.deepEqual(violations, []);
});

test('provider profile remains visible while terminal states are read-only', async () => {
  const violations: string[] = [];
  const editableStatuses: ProviderStatus[] = [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.ACTIVE,
  ];
  const readOnlyStatuses: ProviderStatus[] = [
    ProviderStatus.SUSPENDED,
    ProviderStatus.REJECTED,
  ];

  for (const status of [...editableStatuses, ...readOnlyStatuses]) {
    const dashboard = createProviderDashboard(status);
    const profile = await outcome(() => dashboard.getProfile(currentProvider));
    if (!profile.ok || profile.value.status !== status) {
      violations.push(`${status}: provider profile was not readable`);
    }

    const update = await outcome(() =>
      dashboard.updateProfile(currentProvider, {
        businessName: 'Updated Provider Business',
      }),
    );
    if (editableStatuses.includes(status)) {
      if (!update.ok) {
        violations.push(`${status}: editable provider profile was rejected`);
      }
    } else {
      expectDenied(
        `${status}: provider profile update`,
        update,
        'PROVIDER_PROFILE_READ_ONLY',
        violations,
      );
    }
  }

  assert.deepEqual(violations, []);
});

test('customer history stays readable but canSend reflects provider lifecycle', async () => {
  for (const status of [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.SUSPENDED,
    ProviderStatus.REJECTED,
  ]) {
    const conversations = createConversations(status);
    const response = await conversations.get(
      { ...currentProvider, ...requester, appRole: AppRole.WEDDING_USER } as any,
      conversationId,
    );
    assert.equal(response.canSend, false, status);
  }

  const active = await createConversations(ProviderStatus.ACTIVE).get(
    { ...currentProvider, ...requester, appRole: AppRole.WEDDING_USER } as any,
    conversationId,
  );
  assert.equal(active.canSend, true);
});

test('a customer cannot accept an offer after the provider becomes inactive', async () => {
  let businessWrites = 0;
  const offerId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const currentOffer = {
    id: offerId,
    quoteRequestId,
    providerId,
    title: null,
    message: 'Offer',
    amount: new Prisma.Decimal('1000'),
    currency: 'YER',
    validUntil: null,
    status: QuoteOfferStatus.PENDING,
    createdAt: now,
    updatedAt: now,
    provider: {
      businessName: 'Provider Business',
      userId: providerUserId,
    },
    weddingCosts: [{ id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' }],
    quoteRequest: {
      id: quoteRequestId,
      conversationId,
      userId: requesterUserId,
      providerId,
      weddingPlanId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      serviceId: null,
      status: QuoteRequestStatus.RESPONDED,
      weddingPlan: {
        id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        ownerUserId: requesterUserId,
        currency: 'YER',
      },
      service: null,
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(' ')
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: requesterUserId, status: 'ACTIVE' },
          { id: providerUserId, status: 'ACTIVE' },
        ];
      }
      if (sql.includes('FROM "Provider"')) {
        return [{ id: providerId }];
      }
      if (sql.includes('AS "quoteRequestId"')) {
        return [{ quoteRequestId }];
      }
      if (sql.includes('FROM "QuoteOffer"')) {
        return [{ id: offerId }];
      }
      return [{ id: conversationId }];
    },
    quoteOffer: {
      findUnique: async () => currentOffer,
      updateMany: async () => {
        businessWrites += 1;
        throw new Error('offer transition should not be reached');
      },
    },
    provider: {
      findUnique: async () => ({
        id: providerId,
        userId: providerUserId,
        status: ProviderStatus.SUSPENDED,
      }),
    },
  };

  const result = await outcome(() =>
    acceptQuoteOfferInTransaction(
      {
        $transaction: async (operation: (client: any) => Promise<unknown>) =>
          operation(tx),
      } as any,
      lifecycle, {
        assertProviderAndMoneyManageableInTransaction: async () => ({
          plan: {
            id: currentOffer.quoteRequest.weddingPlanId,
            status: 'PLANNING',
          },
          isOwner: true,
          sharedMember: null,
        }),
      } as any,
      {} as any,
      {
        id: offerId,
        weddingPlanId: currentOffer.quoteRequest.weddingPlanId,
        currentUser: {
          ...currentProvider,
          ...requester,
          appRole: AppRole.WEDDING_USER,
        } as any,
      },
    ),
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(errorCode(result.error), 'PROVIDER_NOT_ACTIVE');
  }
  assert.equal(businessWrites, 0);
});
