#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Marketplace Smoke Test
 * Seeds a local ACTIVE provider fixture through Prisma, then verifies public
 * marketplace and authenticated user actions through HTTP only.
 */

const { configureSmokeDatabaseUrl } = require('./smoke-utils');
configureSmokeDatabaseUrl();

const http = require('http');
const { PrismaClient, ProviderStatus } = require('@prisma/client');

const prisma = new PrismaClient();
const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9676${suffix}`;
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
        primaryCategoryId: category.id,
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
      primaryCategoryId: category.id,
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
    const res = await registerVerified(request, {
      name: 'Marketplace Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /api/v1/auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    token = res.body?.accessToken;
  }

  {
    const res = await request('GET', '/api/v1/cities');
    check('GET /api/v1/cities - HTTP 200', res.status === 200);
    check('cities response is array', Array.isArray(res.body));
    check('cities include fixture city', Array.isArray(res.body) && res.body.some((city) => city.id === fixture.city.id));
  }

  let capitalGovernorateId;
  {
    const res = await request('GET', '/api/v1/governorates');
    check('GET /api/v1/governorates - HTTP 200', res.status === 200);
    check('governorates response contains the 22 official first-level units', Array.isArray(res.body) && res.body.length === 22);
    const capitalGovernorate = res.body?.find((governorate) => governorate.code === 'YE13');
    capitalGovernorateId = capitalGovernorate?.id;
    check('governorates preserve the Arabic name for Amanat Al Asimah', capitalGovernorate?.nameAr === 'أمانة العاصمة');
    check(
      'governorates report all 335 active districts',
      res.body?.reduce((total, governorate) => total + (governorate.districtsCount ?? 0), 0) === 335,
    );
  }

  {
    const res = await request('GET', `/api/v1/governorates/${capitalGovernorateId}/districts`);
    check('GET /api/v1/governorates/:id/districts - HTTP 200', res.status === 200);
    check(
      'Amanat Al Asimah returns its 12 source-defined districts',
      Array.isArray(res.body) && res.body.length === 12,
    );
    check(
      'districts preserve their parent and Arabic names',
      res.body?.every((district) => district.governorateId === capitalGovernorateId) &&
        res.body?.some((district) => district.nameAr === 'صنعاء القديمه'),
    );
  }

  {
    const res = await request('GET', '/api/v1/provider-categories');
    check('GET /api/v1/provider-categories - HTTP 200', res.status === 200);
    check('categories response is array', Array.isArray(res.body));
    check('categories include fixture category', Array.isArray(res.body) && res.body.some((category) => category.id === fixture.category.id));
    check(
      'categories expose server-owned groom and bride audience flags',
      res.body?.every(
        (category) => typeof category.showForGroom === 'boolean' && typeof category.showForBride === 'boolean',
      ),
    );
    check(
      'every active category belongs to at least one wedding persona',
      res.body?.every((category) => category.showForGroom || category.showForBride),
    );
    const catalogBySlug = new Map(
      Array.isArray(res.body)
        ? res.body.map((category) => [category.slug, category])
        : [],
    );
    check(
      'canonical category names survive legacy bootstrap IDs',
      catalogBySlug.get('wedding-halls')?.nameAr === '\u0635\u0627\u0644\u0629' &&
        catalogBySlug.get('catering')?.nameAr === '\u0648\u062c\u0628\u0627\u062a' &&
        catalogBySlug.get('dance-troupe')?.nameAr ===
          '\u0641\u0631\u0642\u0629 \u0631\u0642\u0635' &&
        catalogBySlug.get('refrigerators')?.nameAr ===
          '\u062b\u0644\u0627\u062c\u0629',
    );
    check(
      'legacy Arabic-slug duplicate categories are not active',
      ![
        '\u0645\u0631\u0627\u0642\u0635\u0629',
        '\u0635\u0627\u0644\u0629',
        '\u0643\u0648\u0634\u0629',
        '\u0632\u064a\u0646\u0629',
        '\u0641\u0646\u0627\u0646',
        '\u0645\u0646\u0634\u062f',
        '\u0645\u0632\u0645\u0627\u0631',
        '\u0645\u0628\u0631\u0639',
      ].some((slug) => catalogBySlug.has(slug)),
    );
  }

  {
    const res = await request('GET', `/api/v1/providers?cityId=${fixture.city.id}&categoryId=${fixture.category.id}&featured=true`);
    check('GET /api/v1/providers - HTTP 200', res.status === 200);
    check('providers response is paginated', Array.isArray(res.body?.items));
    check('providers include active fixture', res.body?.items?.some((provider) => provider.id === fixture.provider.id));
    const provider = res.body?.items?.find((item) => item.id === fixture.provider.id);
    check('provider list includes primary category', provider?.primaryCategory?.id === fixture.category.id);
    check('provider list includes active service summary', provider?.serviceSummary?.activeCount >= 1 && provider.serviceSummary.titles?.includes('خدمة سموك للسوق'));
    check('provider list includes published price range', provider?.serviceSummary?.minPrice === '100000' && provider?.serviceSummary?.maxPrice === '100000');
    check('providers response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/providers?search=${encodeURIComponent('خدمة سموك للسوق')}`);
    check('provider search by active service - HTTP 200', res.status === 200);
    check('provider search by active service finds fixture', res.body?.items?.some((provider) => provider.id === fixture.provider.id));
  }

  {
    const res = await request('GET', `/api/v1/providers/${fixture.provider.id}`);
    check('GET /api/v1/providers/:id - HTTP 200', res.status === 200);
    check('provider detail id matches', res.body?.id === fixture.provider.id);
  }

  {
    const res = await request('GET', `/api/v1/providers/${fixture.provider.id}/services`);
    check('GET /api/v1/providers/:id/services - HTTP 200', res.status === 200);
    check('provider services include fixture', Array.isArray(res.body) && res.body.some((service) => service.id === fixture.service.id));
  }

  {
    const res = await request('GET', `/api/v1/services?providerId=${fixture.provider.id}&minPrice=1&maxPrice=200000`);
    check('GET /api/v1/services - HTTP 200', res.status === 200);
    check('services response is paginated', Array.isArray(res.body?.items));
    check('services include fixture', res.body?.items?.some((service) => service.id === fixture.service.id));
  }

  {
    const res = await request('GET', `/api/v1/services/${fixture.service.id}`);
    check('GET /api/v1/services/:id - HTTP 200', res.status === 200);
    check('service detail id matches', res.body?.id === fixture.service.id);
  }

  {
    const res = await request('GET', `/api/v1/providers/${fixture.provider.id}/packages`);
    check('GET /api/v1/providers/:id/packages - HTTP 200', res.status === 200);
    check('provider packages response is array', Array.isArray(res.body));
  }

  {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/favorite`, null, token);
    check('POST /api/v1/providers/:id/favorite - HTTP 201', res.status === 201);
    check('favorite providerId matches', res.body?.providerId === fixture.provider.id);
  }

  {
    const res = await request('GET', '/api/v1/me/favorite-providers', null, token);
    check('GET /api/v1/me/favorite-providers - HTTP 200', res.status === 200);
    check('favorites include fixture', Array.isArray(res.body) && res.body.some((favorite) => favorite.providerId === fixture.provider.id));
  }

  {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/quote-requests`, {
      serviceId: fixture.service.id,
      cityId: fixture.city.id,
      guestCount: 120,
      message: 'Smoke quote request',
      budgetMin: '50000',
      budgetMax: '150000',
    }, token);
    check('POST /api/v1/providers/:id/quote-requests - HTTP 201', res.status === 201);
    check('quote request providerId matches', res.body?.providerId === fixture.provider.id);
    quoteId = res.body?.id;
  }

  {
    const res = await request('GET', '/api/v1/me/quote-requests', null, token);
    check('GET /api/v1/me/quote-requests - HTTP 200', res.status === 200);
    check('my quote requests include created quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/api/v1/me/quote-requests/${quoteId}`, null, token);
    check('GET /api/v1/me/quote-requests/:id - HTTP 200', res.status === 200);
    check('quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('PATCH', `/api/v1/me/quote-requests/${quoteId}/cancel`, null, token);
    check('PATCH /api/v1/me/quote-requests/:id/cancel - HTTP 200', res.status === 200);
    check('quote status is CANCELLED', res.body?.status === 'CANCELLED');
  }

  {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/reviews`, {
      rating: 5,
      comment: 'Smoke review',
    }, token);
    check('POST /api/v1/providers/:id/reviews - HTTP 201', res.status === 201);
    check('review rating saved', res.body?.rating === 5);
    check('created review hides reviewer phone', !Object.hasOwn(res.body?.user ?? {}, 'phone'));
    reviewId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/reviews/${reviewId}`, {
      rating: 4,
      comment: 'Updated smoke review',
    }, token);
    check('PATCH /api/v1/reviews/:id - HTTP 200', res.status === 200);
    check('review rating updated', res.body?.rating === 4);
    check('updated review hides reviewer phone', !Object.hasOwn(res.body?.user ?? {}, 'phone'));
  }

  {
    const res = await request('GET', `/api/v1/providers/${fixture.provider.id}/reviews`);
    check('GET /api/v1/providers/:id/reviews - HTTP 200', res.status === 200);
    check('provider reviews include created review', Array.isArray(res.body) && res.body.some((review) => review.id === reviewId));
    check('public reviews hide every reviewer phone', Array.isArray(res.body) && res.body.every((review) => !Object.hasOwn(review.user ?? {}, 'phone')));
  }

  {
    const res = await request('DELETE', `/api/v1/reviews/${reviewId}`, null, token);
    check('DELETE /api/v1/reviews/:id - HTTP 200', res.status === 200);
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
