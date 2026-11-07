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
const OWNER_PHONE = `+9675${suffix}`;
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
      },
    }));

  await prisma.provider.update({
    where: { id: provider.id },
    data: {
      cityId: city.id,
      primaryCategoryId: category.id,
      status: ProviderStatus.ACTIVE,
      // Every run starts from a listing nobody claimed (V1 4.18).
      userId: null,
    },
  });

  // A placement covering now (B-43) on a listing nobody claimed: the
  // placement rule does not show it (D54).
  const now = Date.now();
  await prisma.providerFeaturedPeriod.deleteMany({ where: { providerId: provider.id } });
  await prisma.providerFeaturedPeriod.create({
    data: {
      providerId: provider.id,
      startsAt: new Date(now - 24 * 60 * 60 * 1000),
      endsAt: new Date(now + 30 * 24 * 60 * 60 * 1000),
      note: 'smoke fixture',
      grantedById: 'smoke-marketplace',
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

/**
 * G40: every production category's providers are found from the money item
 * its accepted offers land in. One listed provider per category, then a
 * groom's and a bride's plan with their starter items: each category the
 * persona sees is listed under exactly one item of the money summary (or
 * none, when only the «أخرى» acceptance creates would take it), and the
 * directory searched with that item's `providerCategoryIds` finds it.
 */
async function checkBudgetItemSearch(fixture) {
  const production = (
    await prisma.providerCategory.findMany({
      where: { isActive: true, NOT: { slug: fixture.category.slug } },
      orderBy: { sortOrder: 'asc' },
    })
  );
  check('G40: the production catalog is present', production.length >= 39);
  const providerByCategory = new Map();
  for (const [index, category] of production.entries()) {
    const phone = `+96777${String(index).padStart(7, '0')}`;
    const provider =
      (await prisma.provider.findFirst({ where: { phone } })) ??
      (await prisma.provider.create({
        data: {
          cityId: fixture.city.id,
          primaryCategoryId: category.id,
          businessName: `سموك ${category.nameAr}`,
          phone,
          status: ProviderStatus.ACTIVE,
        },
      }));
    const listed = await prisma.providerService.findFirst({
      where: { providerId: provider.id, categoryId: category.id, isActive: true },
    });
    if (!listed) {
      await prisma.providerService.create({
        data: {
          providerId: provider.id,
          categoryId: category.id,
          cityId: fixture.city.id,
          title: `خدمة ${category.nameAr}`,
          basePrice: '100000',
          priceUnit: 'package',
          isActive: true,
        },
      });
    }
    providerByCategory.set(category.id, provider.id);
  }

  const bootstrap = await request('GET', '/api/v1/catalogs/bootstrap');
  const starter =
    bootstrap.body?.catalogs?.find((catalog) => catalog.key === 'money.starter.categories')
      ?.items ?? [];

  for (const [persona, digit] of [['GROOM', '3'], ['BRIDE', '4']]) {
    const phone = `+967${digit}${suffix}`;
    const registered = await registerVerified(request, {
      name: `G40 ${persona}`,
      phone,
      password: TEST_PASSWORD,
    });
    const token = registered.body?.accessToken;
    const names = starter
      .filter((item) => item.metadata?.persona === persona)
      .filter((item) => !item.key.endsWith('-mahr'))
      .map((item) => item.nameAr)
      .slice(0, 25);
    const onboarded = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      persona,
      location: { governorate: 'Sanaa', city: 'Sanaa', district: 'Old City' },
      weddingDate: '2027-01-21T00:00:00.000Z',
      priorities: ['providers'],
      estimatedBudget: '7000000',
      currency: 'YER',
      selectedCategories: names,
    }, token);
    const planId = onboarded.body?.activeWeddingPlan?.id;
    if (onboarded.status !== 201) {
      console.log(`  G40 ${persona} onboarding: ${registered.status} ${onboarded.status} ${JSON.stringify(onboarded.body?.message ?? onboarded.body?.code ?? null)}`);
    }
    check(`G40 ${persona}: a plan with its starter items`, onboarded.status === 201 && names.length > 10);
    const summary = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, token);
    const items = summary.body?.categories ?? [];
    check(
      `G40 ${persona}: every item carries providerCategoryIds`,
      items.length > 0 && items.every((item) => Array.isArray(item.providerCategoryIds)),
    );
    const shown = production.filter((category) =>
      persona === 'GROOM' ? category.showForGroom : category.showForBride,
    );
    let found = 0;
    let unplaced = 0;
    const missing = [];
    for (const category of shown) {
      const holders = items.filter((item) => item.providerCategoryIds.includes(category.id));
      if (holders.length === 0) {
        unplaced += 1;
        continue;
      }
      if (holders.length !== 1) {
        missing.push(`${category.slug}: ${holders.length} items`);
        continue;
      }
      const ids = holders[0].providerCategoryIds;
      const page = await request(
        'GET',
        `/api/v1/providers?categoryIds=${ids.join(',')}&limit=100`,
      );
      if (page.body?.items?.some((provider) => provider.id === providerByCategory.get(category.id))) {
        found += 1;
      } else {
        missing.push(`${category.slug} from «${holders[0].name}»`);
      }
    }
    if (missing.length) console.log(`  G40 ${persona} missing: ${missing.join('; ')}`);
    check(
      `G40 ${persona}: each category's providers are found from its item (${found} found, ${unplaced} only in «أخرى»)`,
      missing.length === 0 && found > 0,
    );
    const hidden = production.filter((category) => !shown.includes(category));
    check(
      `G40 ${persona}: no item searches a category hidden from it`,
      hidden.every((category) =>
        items.every((item) => !item.providerCategoryIds.includes(category.id)),
      ),
    );
  }

  const both = await request(
    'GET',
    `/api/v1/providers?categoryId=${fixture.category.id}&categoryIds=${fixture.category.id}`,
  );
  check('G40: categoryId with categoryIds - HTTP 400', both.status === 400);
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
    // The fixture is a listing nobody claimed with a placement written
    // straight into the table: the placement rule (D54) shows it on claimed
    // listings only, so it is listed as an ordinary provider, never «مميز».
    const res = await request('GET', `/api/v1/providers?cityId=${fixture.city.id}&categoryId=${fixture.category.id}&featured=false`);
    check('GET /api/v1/providers - HTTP 200', res.status === 200);
    check('providers response is paginated', Array.isArray(res.body?.items));
    check('providers include active fixture', res.body?.items?.some((provider) => provider.id === fixture.provider.id));
    const provider = res.body?.items?.find((item) => item.id === fixture.provider.id);
    check('an unclaimed listing is never featured', provider?.isFeatured === false && provider?.featuredUntil === null);
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
    // RA-BE-09: typed as people type it (ه for ة, no spaces, a tatweel), the
    // search still finds «خدمة سموك للسوق», as the phone's copy does.
    const res = await request('GET', `/api/v1/providers?search=${encodeURIComponent('خدمه سـموكللسوق')}`);
    check('provider search folds the spelling - HTTP 200', res.status === 200);
    check('provider search folds the spelling finds fixture', res.body?.items?.some((provider) => provider.id === fixture.provider.id));
    const services = await request('GET', `/api/v1/services?search=${encodeURIComponent('خدمه سموك')}`);
    check('service search folds the spelling finds fixture', services.body?.items?.some((service) => service.id === fixture.service.id));
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

  const quoteBody = {
    serviceId: fixture.service.id,
    cityId: fixture.city.id,
    guestCount: 120,
    message: 'Smoke quote request',
    budgetMin: '50000',
    budgetMax: '150000',
  };

  {
    // V1 4.18: a listing nobody claimed takes no quote request.
    const quotesBefore = await prisma.quoteRequest.count({ where: { providerId: fixture.provider.id } });
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/quote-requests`, quoteBody, token);
    check('unclaimed provider quote request - HTTP 409', res.status === 409);
    check('unclaimed provider quote request uses PROVIDER_NOT_CLAIMED', res.body?.code === 'PROVIDER_NOT_CLAIMED');
    check(
      'unclaimed provider quote request writes nothing',
      await prisma.quoteRequest.count({ where: { providerId: fixture.provider.id } }) === quotesBefore,
    );
  }

  // The listing's owner signs in and holds it (the claim flow itself is
  // proven by smoke:provider-claim).
  let ownerToken = null;
  {
    const res = await registerVerified(request, {
      name: 'Marketplace Smoke Provider Owner',
      phone: OWNER_PHONE,
      password: TEST_PASSWORD,
    });
    check('provider owner register - HTTP 201', res.status === 201);
    ownerToken = res.body?.accessToken;
    await prisma.provider.update({
      where: { id: fixture.provider.id },
      data: { userId: res.body?.user?.id },
    });
  }

  {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/quote-requests`, quoteBody, token);
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

  // F10: a customer reviews a provider only after a confirmed booking whose
  // day has passed (403 REVIEW_REQUIRES_COMPLETED_BOOKING before that).
  const reviewBody = { rating: 5, comment: 'Smoke review' };
  const expectReviewRefused = async (label) => {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/reviews`, reviewBody, token);
    check(`${label} - HTTP 403`, res.status === 403);
    check(`${label} uses REVIEW_REQUIRES_COMPLETED_BOOKING`, res.body?.code === 'REVIEW_REQUIRES_COMPLETED_BOOKING');
  };

  await expectReviewRefused('review without a booking');

  // A booking follows an offer accepted inside a wedding plan.
  const dayOffset = Number(suffix) % 3000;
  let planId = null;
  let planQuoteId = null;
  let offerId = null;
  let bookingId = null;
  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Marketplace smoke booking plan',
      city: 'Sanaa',
      estimatedBudget: '900000.00',
    }, token);
    check('customer creates booking plan - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/quote-requests`, {
      providerId: fixture.provider.id,
      ...quoteBody,
    }, token);
    check('customer creates plan quote - HTTP 201', res.status === 201);
    planQuoteId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${planQuoteId}/offers`, {
      message: 'Marketplace smoke offer',
      amount: '100000',
      currency: 'YER',
      // B-07: what the price covers, and the delivery days (B-23).
      lines: [
        { label: 'ألبوم 40 صورة', kind: 'INCLUDED' },
        { label: 'الطباعة', kind: 'EXCLUDED' },
        { label: 'فيديو درون', kind: 'EXTRA', amount: '80000' },
      ],
      deliveryDays: 30,
    }, ownerToken);
    check('provider owner offers on plan quote - HTTP 201', res.status === 201);
    check('B-07 the offer keeps its three lines', res.body?.lines?.length === 3);
    check('B-07 the extra keeps its price', res.body?.lines?.[2]?.amount === '80000');
    check('B-07 the offer keeps its delivery days', res.body?.deliveryDays === 30);
    offerId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${planQuoteId}/offers`, {
      message: 'x', amount: '1', currency: 'YER',
      lines: [{ label: 'x', kind: 'INCLUDED', amount: '5' }],
    }, ownerToken);
    check('B-07 a price on an included line is refused', res.status === 400 || res.status === 409);
  }

  {
    const res = await request('PATCH', `/api/v1/quote-offers/${offerId}/accept`, null, token);
    check('customer accepts the offer - HTTP 200', res.status === 200);
  }

  {
    const day = new Date(Date.now() + (60 + dayOffset) * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const res = await request('POST', `/api/v1/me/quote-requests/${planQuoteId}/booking`, { eventDate: day }, token);
    check('customer requests booking - HTTP 201', res.status === 201);
    bookingId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/bookings/${bookingId}/confirm`, {}, ownerToken);
    check('provider owner confirms booking - HTTP 200', res.status === 200);
    check('booking status is CONFIRMED', res.body?.status === 'CONFIRMED');
  }

  // B-24: the customer moves the wedding; the provider takes the new day,
  // then declines a second move, which leaves the booking where it was.
  let movedDay = null;
  {
    movedDay = new Date(Date.now() + (75 + dayOffset) * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const res = await request('POST', `/api/v1/me/bookings/${bookingId}/change`, { eventDate: movedDay, note: 'أجّلنا العرس' }, token);
    check('B-24 customer asks to move the booking - HTTP 201', res.status === 201);
    check('B-24 the change waits for the provider', res.body?.change?.status === 'PENDING' && res.body?.change?.toDate === movedDay);
    const again = await request('POST', `/api/v1/me/bookings/${bookingId}/change`, { eventDate: movedDay }, token);
    check('B-24 a second change while one waits - HTTP 409', again.status === 409 && again.body?.code === 'BOOKING_CHANGE_CHANGE_PENDING');
    const accepted = await request('POST', `/api/v1/provider/me/booking-changes/${res.body?.change?.id}/accept`, {}, ownerToken);
    check('B-24 provider takes the new day - HTTP 201', accepted.status === 201);
    check('B-24 the booking moved', accepted.body?.eventDate === movedDay && accepted.body?.change?.status === 'ACCEPTED');
  }
  {
    const otherDay = new Date(Date.now() + (80 + dayOffset) * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const res = await request('POST', `/api/v1/me/bookings/${bookingId}/change`, { eventDate: otherDay }, token);
    const declined = await request('POST', `/api/v1/provider/me/booking-changes/${res.body?.change?.id}/decline`, { reason: 'عندنا عرس ذاك اليوم' }, ownerToken);
    check('B-24 provider declines a new day - HTTP 201', declined.status === 201);
    check('B-24 the booking keeps its day', declined.body?.eventDate === movedDay && declined.body?.change?.status === 'DECLINED');
  }
  {
    const res = await request('POST', `/api/v1/provider/me/bookings/${bookingId}/complete`, {}, ownerToken);
    check('B-22 «تم» before the day - HTTP 409', res.status === 409 && res.body?.code === 'BOOKING_OUTCOME_TOO_EARLY');
  }

  await expectReviewRefused('review before the booking day');

  // B-22 and B-23: the day came; the provider says «تم», delivers, and the
  // customer confirms. Only the clock is a fixture step.
  if (bookingId) {
    const now = new Date();
    const yesterday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 1));
    await prisma.booking.update({ where: { id: bookingId }, data: { eventDate: yesterday } });
    const early = await request('POST', `/api/v1/provider/me/bookings/${bookingId}/delivery`, { link: 'https://example.com/album' }, ownerToken);
    check('B-23 delivery before «تم» - HTTP 409', early.status === 409 && early.body?.code === 'BOOKING_DELIVERY_NOT_COMPLETED');
    const done = await request('POST', `/api/v1/provider/me/bookings/${bookingId}/complete`, {}, ownerToken);
    check('B-22 provider says «تم» - HTTP 201', done.status === 201 && done.body?.completedAt != null);
    check('B-23 the due day follows the offer\'s 30 days', typeof done.body?.deliveryDueAt === 'string');
    const twice = await request('POST', `/api/v1/provider/me/bookings/${bookingId}/not-happened`, { reason: 'FORCE_MAJEURE' }, ownerToken);
    check('B-22 a second word - HTTP 409', twice.status === 409 && twice.body?.code === 'BOOKING_OUTCOME_ALREADY_DECIDED');
    const delivered = await request('POST', `/api/v1/provider/me/bookings/${bookingId}/delivery`, { link: 'https://example.com/album', note: 'الصور كاملة' }, ownerToken);
    check('B-23 provider delivers - HTTP 201', delivered.status === 201 && delivered.body?.deliveredAt != null);
    const confirmed = await request('POST', `/api/v1/me/bookings/${bookingId}/delivery/confirm`, {}, token);
    check('B-23 customer confirms the delivery - HTTP 201', confirmed.status === 201 && confirmed.body?.deliveryConfirmedAt != null);
  }

  // The day passes: the only fixture step, since HTTP cannot move the clock.
  if (bookingId) {
    const now = new Date();
    const pastDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 2 - dayOffset));
    await prisma.booking.update({ where: { id: bookingId }, data: { eventDate: pastDay } });

    // RA-BE-46: «ما صار» closed the review for every reason, «ما حضرنا» too,
    // so a provider who did not come shut out the review of not coming. The
    // reason the provider gave decides: the customer's absence closes it,
    // the provider's own absence leaves it open. Set as rows: the outcome is
    // recorded once, and «تم» is already on this booking.
    const saved = await prisma.booking.findUnique({ where: { id: bookingId } });
    await prisma.booking.update({
      where: { id: bookingId },
      data: { completedAt: null, notHappenedAt: new Date(), notHappenedReason: 'CUSTOMER_NO_SHOW' },
    });
    await expectReviewRefused('review after «ما صار» because the customer did not come');
    await prisma.booking.update({
      where: { id: bookingId },
      data: { notHappenedReason: 'WE_DID_NOT_ATTEND' },
    });
    const notCome = await request('POST', `/api/v1/providers/${fixture.provider.id}/reviews`, { rating: 1 }, token);
    check('RA-BE-46 the provider who did not come can be reviewed - HTTP 201', notCome.status === 201);
    await request('DELETE', `/api/v1/reviews/${notCome.body?.id}`, null, token);
    await prisma.booking.update({
      where: { id: bookingId },
      data: { completedAt: saved?.completedAt ?? null, notHappenedAt: null, notHappenedReason: null },
    });
  }

  {
    const res = await request('POST', `/api/v1/providers/${fixture.provider.id}/reviews`, reviewBody, token);
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

  // RA-ST-05: anyone but its author reports a review (here the provider it
  // reviews), once; an empty reason is refused; it goes with its review.
  {
    const own = await request('POST', `/api/v1/reviews/${reviewId}/report`, { reason: 'كلام مسيء' }, token);
    check('RA-ST-05 the author cannot report their own review - HTTP 400', own.status === 400);
    const empty = await request('POST', `/api/v1/reviews/${reviewId}/report`, { reason: '  ' }, ownerToken);
    check('RA-ST-05 an empty reason is refused - HTTP 400', empty.status === 400);
    const first = await request('POST', `/api/v1/reviews/${reviewId}/report`, { reason: 'ما حجز عندي أصلًا' }, ownerToken);
    check('RA-ST-05 the provider reports the review - HTTP 201', first.status === 201 && first.body?.reported === true);
    const again = await request('POST', `/api/v1/reviews/${reviewId}/report`, { reason: 'كلام كاذب' }, ownerToken);
    check('RA-ST-05 a second report by the same account - HTTP 201', again.status === 201);
    const reports = await prisma.reviewReport.findMany({ where: { reviewId } });
    check('RA-ST-05 one open report per reporter, with the latest reason', reports.length === 1 && reports[0].reason === 'كلام كاذب' && reports[0].resolvedAt === null);
  }

  {
    const res = await request('DELETE', `/api/v1/reviews/${reviewId}`, null, token);
    check('DELETE /api/v1/reviews/:id - HTTP 200', res.status === 200);
    check('review delete response', res.body?.deleted === true);
    check('RA-ST-05 the reports go with their review', (await prisma.reviewReport.count({ where: { reviewId } })) === 0);
  }

  // B-05: the provider declines a request with its reason; the customer
  // reads it. B-11: the customer turns an offer down with a reason; the
  // provider reads it.
  {
    const declinedQuote = await request('POST', `/api/v1/providers/${fixture.provider.id}/quote-requests`, quoteBody, token);
    const declined = await request('PATCH', `/api/v1/provider/me/quote-requests/${declinedQuote.body?.id}/status`, {
      status: 'REJECTED',
      declineReason: 'BUSY_THAT_DAY',
      declineMessage: 'نعتذر، ما نقدر ذاك اليوم.',
    }, ownerToken);
    check('B-05 provider declines with a reason - HTTP 200', declined.status === 200);
    const read = await request('GET', `/api/v1/me/quote-requests/${declinedQuote.body?.id}`, null, token);
    check('B-05 the customer reads the reason', read.body?.declineReason === 'BUSY_THAT_DAY');

    const rejectedQuote = await request('POST', `/api/v1/providers/${fixture.provider.id}/quote-requests`, quoteBody, token);
    const offer = await request('POST', `/api/v1/provider/me/quote-requests/${rejectedQuote.body?.id}/offers`, {
      message: 'Smoke offer to reject', amount: '200000', currency: 'YER',
    }, ownerToken);
    const rejected = await request('PATCH', `/api/v1/quote-offers/${offer.body?.id}/reject`, { reason: 'PRICE' }, token);
    check('B-11 customer rejects with a reason - HTTP 200', rejected.status === 200);
    const seen = await request('GET', `/api/v1/provider/me/quote-requests/${rejectedQuote.body?.id}`, null, ownerToken);
    check('B-11 the provider reads the reason', seen.body?.offers?.some((item) => item.rejectReason === 'PRICE'));
  }

  await checkBudgetItemSearch(fixture);

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
