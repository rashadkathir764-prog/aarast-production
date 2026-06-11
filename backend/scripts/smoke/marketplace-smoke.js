#!/usr/bin/env node
'use strict';

/**
 * Marketplace Smoke Test
 * Seeds a local ACTIVE provider fixture through Prisma, then verifies public
 * marketplace and authenticated user actions through HTTP only.
 */

if (process.env.SMOKE_DATABASE_URL) {
  process.env.DATABASE_URL = process.env.SMOKE_DATABASE_URL;
}

const http = require('http');
const { PrismaClient, ProviderStatus } = require('@prisma/client');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const TEST_PHONE = `+9676${timestamp.toString().slice(-7)}`;
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

async function ensureFixture() {
  const city = await prisma.city.upsert({
    where: {
      nameAr_countryCode: {
        nameAr: 'صنعاء',
        countryCode: 'YE',
      },
    },
    create: {
      nameAr: 'صنعاء',
      nameEn: 'Sanaa',
      countryCode: 'YE',
      sortOrder: 10,
      isActive: true,
    },
    update: { isActive: true, sortOrder: 10 },
  });

  const category = await prisma.providerCategory.upsert({
    where: { slug: 'smoke-marketplace-category' },
    create: {
      nameAr: 'تصنيف سموك',
      nameEn: 'Smoke Category',
      slug: 'smoke-marketplace-category',
      sortOrder: 999,
      isActive: true,
    },
    update: { isActive: true },
  });

  const phone = '+967700909090';
  const provider =
    (await prisma.provider.findFirst({ where: { phone } })) ??
    (await prisma.provider.create({
      data: {
        cityId: city.id,
        businessName: 'مزود سموك للسوق',
        phone,
        whatsapp: phone,
        description: 'مزود نشط لاختبارات السوق.',
        status: ProviderStatus.ACTIVE,
        isFeatured: true,
      },
    }));

  await prisma.provider.update({
    where: { id: provider.id },
    data: {
      cityId: city.id,
      status: ProviderStatus.ACTIVE,
      isFeatured: true,
    },
  });

  const service =
    (await prisma.providerService.findFirst({
      where: { providerId: provider.id, title: 'خدمة سموك للسوق' },
    })) ??
    (await prisma.providerService.create({
      data: {
        providerId: provider.id,
        categoryId: category.id,
        cityId: city.id,
        title: 'خدمة سموك للسوق',
        description: 'خدمة نشطة لاختبارات السوق.',
        basePrice: '100000',
        priceUnit: 'package',
        isActive: true,
      },
    }));

  await prisma.providerService.update({
    where: { id: service.id },
    data: {
      categoryId: category.id,
      cityId: city.id,
      isActive: true,
      basePrice: '100000',
    },
  });

  const providerPackage =
    (await prisma.providerPackage.findFirst({
      where: { providerId: provider.id, title: 'باقة سموك للسوق' },
    })) ??
    (await prisma.providerPackage.create({
      data: {
        providerId: provider.id,
        serviceId: service.id,
        title: 'باقة سموك للسوق',
        price: '100000',
        isActive: true,
      },
    }));

  await prisma.providerPackage.update({
    where: { id: providerPackage.id },
    data: { serviceId: service.id, isActive: true },
  });

  return { city, category, provider, service };
}

async function run() {
  console.log('\nMarketplace Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  const fixture = await ensureFixture();
  let token = null;
  let quoteId = null;
  let reviewId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'Marketplace Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    token = res.body?.accessToken;
  }

  {
    const res = await request('GET', '/cities');
    check('GET /cities - HTTP 200', res.status === 200);
    check('cities response is array', Array.isArray(res.body));
    check('cities include fixture city', Array.isArray(res.body) && res.body.some((city) => city.id === fixture.city.id));
  }

  {
    const res = await request('GET', '/provider-categories');
    check('GET /provider-categories - HTTP 200', res.status === 200);
    check('categories response is array', Array.isArray(res.body));
    check('categories include fixture category', Array.isArray(res.body) && res.body.some((category) => category.id === fixture.category.id));
  }

  {
    const res = await request('GET', `/providers?cityId=${fixture.city.id}&categoryId=${fixture.category.id}&featured=true`);
    check('GET /providers - HTTP 200', res.status === 200);
    check('providers response is paginated', Array.isArray(res.body?.items));
    check('providers include active fixture', res.body?.items?.some((provider) => provider.id === fixture.provider.id));
    check('providers response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/providers/${fixture.provider.id}`);
    check('GET /providers/:id - HTTP 200', res.status === 200);
    check('provider detail id matches', res.body?.id === fixture.provider.id);
  }

  {
    const res = await request('GET', `/providers/${fixture.provider.id}/services`);
    check('GET /providers/:id/services - HTTP 200', res.status === 200);
    check('provider services include fixture', Array.isArray(res.body) && res.body.some((service) => service.id === fixture.service.id));
  }

  {
    const res = await request('GET', `/services?providerId=${fixture.provider.id}&minPrice=1&maxPrice=200000`);
    check('GET /services - HTTP 200', res.status === 200);
    check('services response is paginated', Array.isArray(res.body?.items));
    check('services include fixture', res.body?.items?.some((service) => service.id === fixture.service.id));
  }

  {
    const res = await request('GET', `/services/${fixture.service.id}`);
    check('GET /services/:id - HTTP 200', res.status === 200);
    check('service detail id matches', res.body?.id === fixture.service.id);
  }

  {
    const res = await request('GET', `/providers/${fixture.provider.id}/packages`);
    check('GET /providers/:id/packages - HTTP 200', res.status === 200);
    check('provider packages response is array', Array.isArray(res.body));
  }

  {
    const res = await request('POST', `/providers/${fixture.provider.id}/favorite`, null, token);
    check('POST /providers/:id/favorite - HTTP 201', res.status === 201);
    check('favorite providerId matches', res.body?.providerId === fixture.provider.id);
  }

  {
    const res = await request('GET', '/me/favorite-providers', null, token);
    check('GET /me/favorite-providers - HTTP 200', res.status === 200);
    check('favorites include fixture', Array.isArray(res.body) && res.body.some((favorite) => favorite.providerId === fixture.provider.id));
  }

  {
    const res = await request('POST', `/providers/${fixture.provider.id}/quote-requests`, {
      serviceId: fixture.service.id,
      cityId: fixture.city.id,
      guestCount: 120,
      message: 'Smoke quote request',
      budgetMin: '50000',
      budgetMax: '150000',
    }, token);
    check('POST /providers/:id/quote-requests - HTTP 201', res.status === 201);
    check('quote request providerId matches', res.body?.providerId === fixture.provider.id);
    quoteId = res.body?.id;
  }

  {
    const res = await request('GET', '/me/quote-requests', null, token);
    check('GET /me/quote-requests - HTTP 200', res.status === 200);
    check('my quote requests include created quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/me/quote-requests/${quoteId}`, null, token);
    check('GET /me/quote-requests/:id - HTTP 200', res.status === 200);
    check('quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('PATCH', `/me/quote-requests/${quoteId}/cancel`, null, token);
    check('PATCH /me/quote-requests/:id/cancel - HTTP 200', res.status === 200);
    check('quote status is CANCELLED', res.body?.status === 'CANCELLED');
  }

  {
    const res = await request('POST', `/providers/${fixture.provider.id}/reviews`, {
      rating: 5,
      comment: 'Smoke review',
    }, token);
    check('POST /providers/:id/reviews - HTTP 201', res.status === 201);
    check('review rating saved', res.body?.rating === 5);
    reviewId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/reviews/${reviewId}`, {
      rating: 4,
      comment: 'Updated smoke review',
    }, token);
    check('PATCH /reviews/:id - HTTP 200', res.status === 200);
    check('review rating updated', res.body?.rating === 4);
  }

  {
    const res = await request('GET', `/providers/${fixture.provider.id}/reviews`);
    check('GET /providers/:id/reviews - HTTP 200', res.status === 200);
    check('provider reviews include created review', Array.isArray(res.body) && res.body.some((review) => review.id === reviewId));
  }

  {
    const res = await request('DELETE', `/reviews/${reviewId}`, null, token);
    check('DELETE /reviews/:id - HTTP 200', res.status === 200);
    check('review delete response', res.body?.deleted === true);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run()
  .catch((err) => {
    console.error('Marketplace smoke error:', err.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
