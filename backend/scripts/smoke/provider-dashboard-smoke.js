#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Provider Dashboard Smoke Test
 * Creates a provider application through HTTP, manages provider-owned catalog
 * records, then uses a local Prisma fixture update to mark the provider ACTIVE
 * so quote/review dashboard reads can be exercised.
 */

const {
  configureSmokeDatabaseUrl,
  requireResponseId,
} = require('./smoke-utils');
configureSmokeDatabaseUrl();

const http = require('http');
const {
  NotificationPriority,
  NotificationType,
  PrismaClient,
  ProviderStatus,
} = require('@prisma/client');
const { uploadVerifiedImage } = require('./verified-media-upload');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const PROVIDER_PHONE = `+9677${suffix}`;
const CUSTOMER_PHONE = `+9678${suffix}`;
const TEST_PASSWORD = 'SmokeTest123!';

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed++;
  } else {
    console.log(`FAIL - ${label}`);
    failed++;
  }
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const bodyStr = body ? JSON.stringify(body) : undefined;
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            resolve({
              status: res.statusCode,
              body: JSON.parse(data),
              headers: res.headers,
            });
          } catch {
            resolve({ status: res.statusCode, body: data, headers: res.headers });
          }
        });
      },
    );

    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function ensureReferenceData() {
  const city = await prisma.city.upsert({
    where: {
      nameAr_countryCode: {
        nameAr: 'عدن',
        countryCode: 'YE',
      },
    },
    create: {
      nameAr: 'عدن',
      nameEn: 'Aden',
      countryCode: 'YE',
      sortOrder: 20,
      isActive: true,
    },
    update: { isActive: true, sortOrder: 20 },
  });

  const category = await prisma.providerCategory.upsert({
    where: { slug: 'smoke-provider-dashboard-category' },
    create: {
      nameAr: 'تصنيف لوحة المزود',
      nameEn: 'Provider Dashboard Smoke',
      slug: 'smoke-provider-dashboard-category',
      sortOrder: 998,
      isActive: true,
    },
    update: { isActive: true },
  });

  return { city, category };
}

async function register(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  return res;
}

async function run() {
  console.log('\nProvider Dashboard Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Provider phone: ${PROVIDER_PHONE}`);
  console.log(`Customer phone: ${CUSTOMER_PHONE}\n`);

  const reference = await ensureReferenceData();
  let providerToken = null;
  let providerUserId = null;
  let customerToken = null;
  let providerId = null;
  let serviceId = null;
  let imageId = null;
  let packageId = null;
  let quoteId = null;
  let conversationId = null;
  let offerId = null;
  let reviewId = null;
  let providerQuoteNotificationId = null;
  let generalNotificationId = null;

  {
    const res = await register('Provider Smoke User', PROVIDER_PHONE);
    check('provider register - HTTP 201', res.status === 201);
    check('provider register returns token', typeof res.body?.accessToken === 'string');
    providerToken = res.body?.accessToken;
    providerUserId = res.body?.user?.id;
  }

  {
    const res = await request('POST', '/api/v1/provider/apply', {
      businessName: 'لوحة مزود سموك',
      phone: PROVIDER_PHONE,
      cityId: reference.city.id,
      categoryIds: [reference.category.id],
      description: 'طلب مزود لاختبار لوحة المزود.',
    }, providerToken);
    check('POST /api/v1/provider/apply - HTTP 201', res.status === 201);
    check('provider apply status is PENDING', res.body?.status === 'PENDING');
    check('provider apply does not expose passwordHash', !hasPasswordHash(res.body));
    providerId = requireResponseId('POST /api/v1/provider/apply', res);
  }

  {
    const res = await request('GET', '/api/v1/provider/me/profile', null, providerToken);
    check('GET /api/v1/provider/me/profile - HTTP 200', res.status === 200);
    check('provider profile id matches', res.body?.id === providerId);
  }

  {
    const res = await request('PATCH', '/api/v1/provider/me/profile', {
      ownerName: 'مالك سموك',
      whatsapp: PROVIDER_PHONE,
      address: 'عنوان سموك',
      latitude: '12.7855',
      longitude: '45.0187',
    }, providerToken);
    check('PATCH /api/v1/provider/me/profile - HTTP 200', res.status === 200);
    check('provider ownerName updated', res.body?.ownerName === 'مالك سموك');
  }

  {
    const res = await request('GET', '/api/v1/provider/me/summary', null, providerToken);
    check('PENDING provider summary is denied - HTTP 403', res.status === 403);
    check('PENDING provider summary uses PROVIDER_NOT_ACTIVE', res.body?.code === 'PROVIDER_NOT_ACTIVE');
  }

  {
    const res = await request('GET', '/api/v1/provider/me/services', null, providerToken);
    check('PENDING provider services are denied - HTTP 403', res.status === 403);
    check('PENDING provider services use PROVIDER_NOT_ACTIVE', res.body?.code === 'PROVIDER_NOT_ACTIVE');
  }

  {
    const res = await request('POST', '/api/v1/provider/me/services', {
      categoryId: reference.category.id,
      title: 'Pending provider service must not persist',
      basePrice: '125000',
    }, providerToken);
    check('PENDING provider service create is denied - HTTP 403', res.status === 403);
    check('PENDING provider service create uses PROVIDER_NOT_ACTIVE', res.body?.code === 'PROVIDER_NOT_ACTIVE');
    check(
      'PENDING provider service create writes nothing',
      await prisma.providerService.count({ where: { providerId } }) === 0,
    );
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  {
    const res = await request('GET', '/api/v1/provider/me/summary', null, providerToken);
    check('GET /api/v1/provider/me/summary - HTTP 200', res.status === 200);
    check('summary starts with zero services', res.body?.servicesCount === 0);
  }

  {
    const res = await request('POST', '/api/v1/provider/me/services', {
      categoryId: reference.category.id,
      title: 'Invalid oversized provider service',
      basePrice: '9999999999999',
    }, providerToken);
    check('oversized provider service price - HTTP 400', res.status === 400);
    check(
      'oversized provider service price writes nothing',
      await prisma.providerService.count({ where: { providerId } }) === 0,
    );
  }

  {
    const res = await request('POST', '/api/v1/provider/me/services', {
      categoryId: reference.category.id,
      title: 'خدمة لوحة المزود',
      description: 'خدمة لاختبار إدارة المزود.',
      basePrice: '125000',
      priceUnit: 'package',
      cityId: reference.city.id,
    }, providerToken);
    check('POST /api/v1/provider/me/services - HTTP 201', res.status === 201);
    check('created service has id', typeof res.body?.id === 'string');
    serviceId = requireResponseId('POST /api/v1/provider/me/services', res);
  }

  {
    const res = await request('GET', '/api/v1/provider/me/services', null, providerToken);
    check('GET /api/v1/provider/me/services - HTTP 200', res.status === 200);
    check('services include created service', Array.isArray(res.body) && res.body.some((service) => service.id === serviceId));
  }

  {
    const res = await request('GET', `/api/v1/provider/me/services/${serviceId}`, null, providerToken);
    check('GET /api/v1/provider/me/services/:id - HTTP 200', res.status === 200);
    check('service detail id matches', res.body?.id === serviceId);
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/services/${serviceId}`, {
      title: 'خدمة لوحة المزود المحدثة',
      basePrice: '130000',
    }, providerToken);
    check('PATCH /api/v1/provider/me/services/:id - HTTP 200', res.status === 200);
    check('service title updated', res.body?.title === 'خدمة لوحة المزود المحدثة');
  }

  {
    const media = await uploadVerifiedImage({
      request,
      token: providerToken,
      purpose: 'service-image',
      fileName: 'provider-service-smoke.png',
      contentType: 'image/png',
    });
    check('service image presign succeeds', media.presign.status === 201);
    check('service image byte upload succeeds', media.upload?.ok === true);
    check('service image verification succeeds', media.verify?.status === 201);
    const verifiedKey = media.verify?.body?.key;
    const verifiedTicket = verifiedKey
      ? await prisma.mediaUploadTicket.findUnique({ where: { key: verifiedKey } })
      : null;
    check(
      'service image has a durable unconsumed upload ticket',
      verifiedTicket?.status === 'VERIFIED' && verifiedTicket.consumedAt === null,
    );
    const res = await request('POST', `/api/v1/provider/me/services/${serviceId}/images`, {
      imageUrl: media.verify?.body?.publicUrl,
      altText: 'صورة خدمة سموك',
      sortOrder: 1,
    }, providerToken);
    check('POST /api/v1/provider/me/services/:id/images - HTTP 201', res.status === 201);
    check('created image has id', typeof res.body?.id === 'string');
    const consumedTicket = verifiedKey
      ? await prisma.mediaUploadTicket.findUnique({ where: { key: verifiedKey } })
      : null;
    check(
      'persisting the service image consumes its durable ticket',
      consumedTicket?.consumedAt instanceof Date,
    );
    imageId = res.body?.id;
  }

  if (imageId) {
    const res = await request('PATCH', `/api/v1/provider/me/services/${serviceId}/images/${imageId}`, {
      altText: 'صورة خدمة سموك محدثة',
      sortOrder: 2,
    }, providerToken);
    check('PATCH service image - HTTP 200', res.status === 200);
    check('image sortOrder updated', res.body?.sortOrder === 2);
  }

  if (imageId) {
    const res = await request('DELETE', `/api/v1/provider/me/services/${serviceId}/images/${imageId}`, null, providerToken);
    check('DELETE service image - HTTP 200', res.status === 200);
    check('image delete response', res.body?.deleted === true);
  }

  {
    const res = await request('POST', '/api/v1/provider/me/packages', {
      serviceId,
      title: 'Invalid precision provider package',
      price: '10.999',
    }, providerToken);
    check('over-precision provider package price - HTTP 400', res.status === 400);
    check(
      'over-precision provider package price writes nothing',
      await prisma.providerPackage.count({ where: { providerId } }) === 0,
    );
  }

  {
    const res = await request('POST', '/api/v1/provider/me/packages', {
      serviceId,
      title: 'باقة لوحة المزود',
      description: 'باقة لاختبار لوحة المزود.',
      price: '130000',
      items: ['خدمة', 'تنسيق'],
    }, providerToken);
    check('POST /api/v1/provider/me/packages - HTTP 201', res.status === 201);
    check('created package has id', typeof res.body?.id === 'string');
    packageId = res.body?.id;
  }

  {
    const res = await request('GET', '/api/v1/provider/me/packages', null, providerToken);
    check('GET /api/v1/provider/me/packages - HTTP 200', res.status === 200);
    check('packages include created package', Array.isArray(res.body) && res.body.some((item) => item.id === packageId));
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/packages/${packageId}`, {
      title: 'باقة لوحة المزود المحدثة',
      price: '135000',
    }, providerToken);
    check('PATCH /api/v1/provider/me/packages/:id - HTTP 200', res.status === 200);
    check('package title updated', res.body?.title === 'باقة لوحة المزود المحدثة');
  }

  {
    const res = await register('Provider Customer Smoke User', CUSTOMER_PHONE);
    check('customer register - HTTP 201', res.status === 201);
    customerToken = res.body?.accessToken;
  }

  {
    const res = await request('POST', `/api/v1/providers/${providerId}/quote-requests`, {
      serviceId,
      cityId: reference.city.id,
      guestCount: 80,
      message: 'Provider dashboard quote smoke',
    }, customerToken);
    check('customer creates quote for provider - HTTP 201', res.status === 201);
    check('quote providerId matches', res.body?.providerId === providerId);
    quoteId = res.body?.id;
    const storedQuote = quoteId
      ? await prisma.quoteRequest.findUnique({
          where: { id: quoteId },
          select: { conversationId: true },
        })
      : null;
    conversationId = storedQuote?.conversationId ?? null;
    check(
      'quote has a durable provider conversation',
      typeof conversationId === 'string',
    );
  }

  {
    const providerQuoteNotification = await prisma.notification.findFirst({
      where: {
        userId: providerUserId,
        entityType: 'quote_request',
        entityId: quoteId,
        routeTarget: '/provider/dashboard',
      },
      orderBy: { createdAt: 'desc' },
    });
    check(
      'active provider receives the quote notification',
      typeof providerQuoteNotification?.id === 'string',
    );
    check(
      'provider quote notification is explicitly provider-scoped',
      providerQuoteNotification?.data?.recipientAudience === 'PROVIDER',
    );
    const serializedProviderQuoteNotification = JSON.stringify(
      providerQuoteNotification ?? {},
    );
    check(
      'provider quote notification does not duplicate customer name',
      !serializedProviderQuoteNotification.includes(
        'Provider Customer Smoke User',
      ),
    );
    check(
      'provider quote notification does not duplicate customer phone',
      !serializedProviderQuoteNotification.includes(CUSTOMER_PHONE),
    );
    check(
      'provider quote notification does not duplicate quote message',
      !serializedProviderQuoteNotification.includes(
        'Provider dashboard quote smoke',
      ),
    );
    providerQuoteNotificationId = providerQuoteNotification?.id ?? null;

    const generalNotification = await prisma.notification.create({
      data: {
        userId: providerUserId,
        type: NotificationType.GENERAL,
        priority: NotificationPriority.NORMAL,
        title: 'Provider multi-context smoke',
        body: 'This account notification must survive provider suspension.',
        dedupeKey: `${providerUserId}:provider-dashboard-general:${suffix}`,
      },
    });
    generalNotificationId = generalNotification.id;
  }

  {
    const res = await request(
      'GET',
      '/api/v1/notifications?limit=50',
      null,
      providerToken,
    );
    check('ACTIVE provider notifications - HTTP 200', res.status === 200);
    check(
      'ACTIVE provider notification list includes quote alert',
      res.body?.items?.some(
        (notification) => notification.id === providerQuoteNotificationId,
      ) === true,
    );
    check(
      'ACTIVE provider notification list includes general account alert',
      res.body?.items?.some(
        (notification) => notification.id === generalNotificationId,
      ) === true,
    );
  }

  {
    const res = await request('GET', '/api/v1/provider/me/quote-requests', null, providerToken);
    check('GET /api/v1/provider/me/quote-requests - HTTP 200', res.status === 200);
    check('provider quotes include customer quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/api/v1/provider/me/quote-requests/${quoteId}`, null, providerToken);
    check('GET /api/v1/provider/me/quote-requests/:id - HTTP 200', res.status === 200);
    check('provider quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/quote-requests/${quoteId}/status`, {
      status: 'VIEWED',
    }, providerToken);
    check('PATCH provider quote status - HTTP 200', res.status === 200);
    check('provider quote status updated', res.body?.status === 'VIEWED');
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${quoteId}/offers`, {
      message: 'Invalid oversized provider offer',
      amount: '9999999999999',
    }, providerToken);
    check('oversized provider offer amount - HTTP 400', res.status === 400);
    check(
      'oversized provider offer writes nothing',
      await prisma.quoteOffer.count({ where: { quoteRequestId: quoteId } }) === 0,
    );
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${quoteId}/offers`, {
      message: 'Provider dashboard valid offer',
      amount: '140000',
      currency: 'YER',
    }, providerToken);
    check('POST provider quote offer - HTTP 201', res.status === 201);
    offerId = requireResponseId('POST provider quote offer', res);
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/quote-offers/${offerId}`, {
      amount: '10.999',
    }, providerToken);
    check('over-precision provider offer update - HTTP 400', res.status === 400);
    const storedOffer = await prisma.quoteOffer.findUnique({
      where: { id: offerId },
      select: { amount: true },
    });
    check(
      'invalid provider offer update preserves prior amount',
      storedOffer?.amount?.toString() === '140000',
    );
  }

  {
    const res = await request('POST', `/api/v1/providers/${providerId}/reviews`, {
      rating: 5,
      comment: 'Provider dashboard review smoke',
    }, customerToken);
    check('customer review provider - HTTP 201', res.status === 201);
    reviewId = res.body?.id;
  }

  {
    const res = await request('GET', '/api/v1/provider/me/reviews', null, providerToken);
    check('GET /api/v1/provider/me/reviews - HTTP 200', res.status === 200);
    check('provider reviews include customer review', Array.isArray(res.body) && res.body.some((review) => review.id === reviewId));
    check('provider reviews hide every customer phone', Array.isArray(res.body) && res.body.every((review) => !Object.hasOwn(review.user ?? {}, 'phone')));
  }

  {
    const res = await request('DELETE', `/api/v1/provider/me/packages/${packageId}`, null, providerToken);
    check('DELETE /api/v1/provider/me/packages/:id - HTTP 200', res.status === 200);
    check('package deactivated', res.body?.isActive === false);
  }

  {
    const res = await request('DELETE', `/api/v1/provider/me/services/${serviceId}`, null, providerToken);
    check('DELETE /api/v1/provider/me/services/:id - HTTP 200', res.status === 200);
    check('service deactivated', res.body?.isActive === false);
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.SUSPENDED },
  });

  {
    const res = await request('GET', '/api/v1/provider/me/profile', null, providerToken);
    check('SUSPENDED provider profile remains readable - HTTP 200', res.status === 200);
    check('SUSPENDED provider profile exposes current status', res.body?.status === 'SUSPENDED');
  }

  {
    const res = await request('PATCH', '/api/v1/provider/me/profile', {
      ownerName: 'Suspended provider must not update',
    }, providerToken);
    check('SUSPENDED provider profile update is denied - HTTP 403', res.status === 403);
    check(
      'SUSPENDED provider profile update uses PROVIDER_PROFILE_READ_ONLY',
      res.body?.code === 'PROVIDER_PROFILE_READ_ONLY',
    );
  }

  {
    const res = await request('GET', '/api/v1/provider/me/summary', null, providerToken);
    check('SUSPENDED provider summary is denied - HTTP 403', res.status === 403);
    check('SUSPENDED provider summary uses PROVIDER_NOT_ACTIVE', res.body?.code === 'PROVIDER_NOT_ACTIVE');
  }

  {
    const res = await request('GET', '/api/v1/provider/me/quote-requests', null, providerToken);
    check('SUSPENDED provider quote data is denied - HTTP 403', res.status === 403);
    check('SUSPENDED provider quote data uses PROVIDER_NOT_ACTIVE', res.body?.code === 'PROVIDER_NOT_ACTIVE');
  }

  {
    const res = await request(
      'GET',
      '/api/v1/notifications?limit=50',
      null,
      providerToken,
    );
    check('SUSPENDED provider notification list - HTTP 200', res.status === 200);
    check(
      'notification inbox disables shared/browser caching',
      res.headers?.['cache-control'] === 'private, no-store',
    );
    check(
      'SUSPENDED provider notification list hides provider quote alert',
      res.body?.items?.every(
        (notification) => notification.id !== providerQuoteNotificationId,
      ) === true,
    );
    check(
      'SUSPENDED provider notification list preserves general account alert',
      res.body?.items?.some(
        (notification) => notification.id === generalNotificationId,
      ) === true,
    );
  }

  if (providerQuoteNotificationId) {
    const res = await request(
      'GET',
      `/api/v1/notifications/${providerQuoteNotificationId}`,
      null,
      providerToken,
    );
    check(
      'SUSPENDED provider cannot open hidden quote notification - HTTP 403',
      res.status === 403,
    );
    check(
      'hidden provider quote notification uses PROVIDER_NOT_ACTIVE',
      res.body?.code === 'PROVIDER_NOT_ACTIVE',
    );
  }

  {
    const res = await request(
      'PATCH',
      '/api/v1/notifications/read-all',
      null,
      providerToken,
    );
    check('SUSPENDED provider mark visible notifications read - HTTP 200', res.status === 200);
    const [providerQuoteNotification, generalNotification] = await Promise.all([
      providerQuoteNotificationId
        ? prisma.notification.findUnique({
            where: { id: providerQuoteNotificationId },
          })
        : null,
      generalNotificationId
        ? prisma.notification.findUnique({ where: { id: generalNotificationId } })
        : null,
    ]);
    check(
      'bulk read does not mutate hidden provider quote notification',
      providerQuoteNotification?.readAt === null,
    );
    check(
      'bulk read still mutates visible general account notification',
      generalNotification?.readAt instanceof Date,
    );
  }

  if (conversationId) {
    const listRes = await request(
      'GET',
      '/api/v1/conversations',
      null,
      providerToken,
    );
    check('SUSPENDED provider conversation list - HTTP 200', listRes.status === 200);
    check(
      'SUSPENDED provider inbox excludes provider-side conversation',
      listRes.body?.items?.every(
        (conversation) => conversation.id !== conversationId,
      ) === true,
    );

    const directRes = await request(
      'GET',
      `/api/v1/conversations/${conversationId}`,
      null,
      providerToken,
    );
    check(
      'SUSPENDED provider direct conversation read - HTTP 403',
      directRes.status === 403,
    );
    check(
      'SUSPENDED provider direct conversation uses PROVIDER_NOT_ACTIVE',
      directRes.body?.code === 'PROVIDER_NOT_ACTIVE',
    );
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run()
  .catch((err) => {
    console.error('Provider dashboard smoke error:', err.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
