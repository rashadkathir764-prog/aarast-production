#!/usr/bin/env node
'use strict';

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
const { PrismaClient, ProviderStatus } = require('@prisma/client');

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
            resolve({ status: res.statusCode, body: JSON.parse(data) });
          } catch {
            resolve({ status: res.statusCode, body: data });
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
  const res = await request('POST', '/auth/register', {
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
  let customerToken = null;
  let providerId = null;
  let serviceId = null;
  let imageId = null;
  let packageId = null;
  let quoteId = null;
  let reviewId = null;

  {
    const res = await register('Provider Smoke User', PROVIDER_PHONE);
    check('provider register - HTTP 201', res.status === 201);
    check('provider register returns token', typeof res.body?.accessToken === 'string');
    providerToken = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/provider/apply', {
      businessName: 'لوحة مزود سموك',
      phone: PROVIDER_PHONE,
      cityId: reference.city.id,
      categoryIds: [reference.category.id],
      description: 'طلب مزود لاختبار لوحة المزود.',
    }, providerToken);
    check('POST /provider/apply - HTTP 201', res.status === 201);
    check('provider apply status is PENDING', res.body?.status === 'PENDING');
    check('provider apply does not expose passwordHash', !hasPasswordHash(res.body));
    providerId = requireResponseId('POST /provider/apply', res);
  }

  {
    const res = await request('GET', '/provider/me/profile', null, providerToken);
    check('GET /provider/me/profile - HTTP 200', res.status === 200);
    check('provider profile id matches', res.body?.id === providerId);
  }

  {
    const res = await request('PATCH', '/provider/me/profile', {
      ownerName: 'مالك سموك',
      whatsapp: PROVIDER_PHONE,
      address: 'عنوان سموك',
      latitude: '12.7855',
      longitude: '45.0187',
    }, providerToken);
    check('PATCH /provider/me/profile - HTTP 200', res.status === 200);
    check('provider ownerName updated', res.body?.ownerName === 'مالك سموك');
  }

  {
    const res = await request('GET', '/provider/me/summary', null, providerToken);
    check('GET /provider/me/summary - HTTP 200', res.status === 200);
    check('summary starts with zero services', res.body?.servicesCount === 0);
  }

  {
    const res = await request('POST', '/provider/me/services', {
      categoryId: reference.category.id,
      title: 'خدمة لوحة المزود',
      description: 'خدمة لاختبار إدارة المزود.',
      basePrice: '125000',
      priceUnit: 'package',
      cityId: reference.city.id,
    }, providerToken);
    check('POST /provider/me/services - HTTP 201', res.status === 201);
    check('created service has id', typeof res.body?.id === 'string');
    serviceId = requireResponseId('POST /provider/me/services', res);
  }

  {
    const res = await request('GET', '/provider/me/services', null, providerToken);
    check('GET /provider/me/services - HTTP 200', res.status === 200);
    check('services include created service', Array.isArray(res.body) && res.body.some((service) => service.id === serviceId));
  }

  {
    const res = await request('GET', `/provider/me/services/${serviceId}`, null, providerToken);
    check('GET /provider/me/services/:id - HTTP 200', res.status === 200);
    check('service detail id matches', res.body?.id === serviceId);
  }

  {
    const res = await request('PATCH', `/provider/me/services/${serviceId}`, {
      title: 'خدمة لوحة المزود المحدثة',
      basePrice: '130000',
    }, providerToken);
    check('PATCH /provider/me/services/:id - HTTP 200', res.status === 200);
    check('service title updated', res.body?.title === 'خدمة لوحة المزود المحدثة');
  }

  {
    const res = await request('POST', `/provider/me/services/${serviceId}/images`, {
      imageUrl: 'https://example.test/provider-service.jpg',
      altText: 'صورة خدمة سموك',
      sortOrder: 1,
    }, providerToken);
    check('POST /provider/me/services/:id/images - HTTP 201', res.status === 201);
    check('created image has id', typeof res.body?.id === 'string');
    imageId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/provider/me/services/${serviceId}/images/${imageId}`, {
      altText: 'صورة خدمة سموك محدثة',
      sortOrder: 2,
    }, providerToken);
    check('PATCH service image - HTTP 200', res.status === 200);
    check('image sortOrder updated', res.body?.sortOrder === 2);
  }

  {
    const res = await request('DELETE', `/provider/me/services/${serviceId}/images/${imageId}`, null, providerToken);
    check('DELETE service image - HTTP 200', res.status === 200);
    check('image delete response', res.body?.deleted === true);
  }

  {
    const res = await request('POST', '/provider/me/packages', {
      serviceId,
      title: 'باقة لوحة المزود',
      description: 'باقة لاختبار لوحة المزود.',
      price: '130000',
      items: ['خدمة', 'تنسيق'],
    }, providerToken);
    check('POST /provider/me/packages - HTTP 201', res.status === 201);
    check('created package has id', typeof res.body?.id === 'string');
    packageId = res.body?.id;
  }

  {
    const res = await request('GET', '/provider/me/packages', null, providerToken);
    check('GET /provider/me/packages - HTTP 200', res.status === 200);
    check('packages include created package', Array.isArray(res.body) && res.body.some((item) => item.id === packageId));
  }

  {
    const res = await request('PATCH', `/provider/me/packages/${packageId}`, {
      title: 'باقة لوحة المزود المحدثة',
      price: '135000',
    }, providerToken);
    check('PATCH /provider/me/packages/:id - HTTP 200', res.status === 200);
    check('package title updated', res.body?.title === 'باقة لوحة المزود المحدثة');
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  {
    const res = await register('Provider Customer Smoke User', CUSTOMER_PHONE);
    check('customer register - HTTP 201', res.status === 201);
    customerToken = res.body?.accessToken;
  }

  {
    const res = await request('POST', `/providers/${providerId}/quote-requests`, {
      serviceId,
      cityId: reference.city.id,
      guestCount: 80,
      message: 'Provider dashboard quote smoke',
    }, customerToken);
    check('customer creates quote for provider - HTTP 201', res.status === 201);
    check('quote providerId matches', res.body?.providerId === providerId);
    quoteId = res.body?.id;
  }

  {
    const res = await request('GET', '/provider/me/quote-requests', null, providerToken);
    check('GET /provider/me/quote-requests - HTTP 200', res.status === 200);
    check('provider quotes include customer quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/provider/me/quote-requests/${quoteId}`, null, providerToken);
    check('GET /provider/me/quote-requests/:id - HTTP 200', res.status === 200);
    check('provider quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('PATCH', `/provider/me/quote-requests/${quoteId}/status`, {
      status: 'VIEWED',
    }, providerToken);
    check('PATCH provider quote status - HTTP 200', res.status === 200);
    check('provider quote status updated', res.body?.status === 'VIEWED');
  }

  {
    const res = await request('POST', `/providers/${providerId}/reviews`, {
      rating: 5,
      comment: 'Provider dashboard review smoke',
    }, customerToken);
    check('customer review provider - HTTP 201', res.status === 201);
    reviewId = res.body?.id;
  }

  {
    const res = await request('GET', '/provider/me/reviews', null, providerToken);
    check('GET /provider/me/reviews - HTTP 200', res.status === 200);
    check('provider reviews include customer review', Array.isArray(res.body) && res.body.some((review) => review.id === reviewId));
  }

  {
    const res = await request('DELETE', `/provider/me/packages/${packageId}`, null, providerToken);
    check('DELETE /provider/me/packages/:id - HTTP 200', res.status === 200);
    check('package deactivated', res.body?.isActive === false);
  }

  {
    const res = await request('DELETE', `/provider/me/services/${serviceId}`, null, providerToken);
    check('DELETE /provider/me/services/:id - HTTP 200', res.status === 200);
    check('service deactivated', res.body?.isActive === false);
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
