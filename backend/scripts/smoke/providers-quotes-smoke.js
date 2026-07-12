#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Providers + Quotes APIs Smoke Test
 * Covers /api/v1 provider profile, services, plan quote requests, offers,
 * accept/reject, and plan-provider linking without payments or bookings.
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
const suffix = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const PROVIDER_PHONE = `+96760${suffix}`;
const CUSTOMER_PHONE = `+96761${suffix}`;
const OUTSIDER_PHONE = `+96762${suffix}`;
const TEST_PASSWORD = 'SmokeTest123!';
const PROVIDER_BUSINESS_NAME = `Phase8 Provider Business ${suffix}`;

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
        res.on('data', (chunk) => { data += chunk; });
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
        nameAr: 'Phase8 Smoke City',
        countryCode: 'YE',
      },
    },
    update: { isActive: true },
    create: {
      nameAr: 'Phase8 Smoke City',
      nameEn: 'Phase8 Smoke City',
      countryCode: 'YE',
      isActive: true,
      sortOrder: 8,
    },
  });

  const category = await prisma.providerCategory.upsert({
    where: { slug: 'phase8-smoke-category' },
    update: { isActive: true },
    create: {
      nameAr: 'Phase8 Smoke Category',
      nameEn: 'Phase8 Smoke Category',
      slug: 'phase8-smoke-category',
      icon: 'sparkles',
      isActive: true,
      sortOrder: 8,
    },
  });

  return { city, category };
}

async function register(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, user: res.body?.user };
}

async function run() {
  console.log('\nProviders + Quotes APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Provider phone: ${PROVIDER_PHONE}`);
  console.log(`Customer phone: ${CUSTOMER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const reference = await ensureReferenceData();
  const providerUser = await register('Phase8 Provider', PROVIDER_PHONE);
  const customer = await register('Phase8 Customer', CUSTOMER_PHONE);
  const outsider = await register('Phase8 Outsider', OUTSIDER_PHONE);

  let providerId = null;
  let serviceId = null;
  let planId = null;
  let quoteId = null;
  let offerId = null;
  let rejectedOfferId = null;

  {
    const res = await request('POST', '/api/v1/provider/apply', {
      businessName: PROVIDER_BUSINESS_NAME,
      phone: PROVIDER_PHONE,
      cityId: reference.city.id,
      categoryIds: [reference.category.id],
      description: 'Phase8 provider profile',
    }, providerUser.token);
    check('POST /api/v1/provider/apply - HTTP 201', res.status === 201);
    check('provider profile has id', typeof res.body?.id === 'string');
    check('provider profile starts pending', res.body?.status === 'PENDING');
    check('provider profile does not expose passwordHash', !hasPasswordHash(res.body));
    providerId = requireResponseId('POST /api/v1/provider/apply', res);
  }

  {
    const res = await request('GET', '/api/v1/provider/me/profile', null, providerUser.token);
    check('GET /api/v1/provider/me/profile - HTTP 200', res.status === 200);
    check('provider me id matches', res.body?.id === providerId);
  }

  {
    const res = await request('PATCH', '/api/v1/provider/me/profile', {
      ownerName: 'Phase8 Owner',
      whatsapp: PROVIDER_PHONE,
    }, providerUser.token);
    check('PATCH /api/v1/provider/me/profile - HTTP 200', res.status === 200);
    check('provider ownerName updated', res.body?.ownerName === 'Phase8 Owner');
  }

  {
    const res = await request('POST', '/api/v1/provider/me/services', {
      categoryId: reference.category.id,
      title: 'Phase8 Service',
      description: 'Phase8 service description',
      basePrice: '250000.00',
      priceUnit: 'event',
      cityId: reference.city.id,
    }, providerUser.token);
    check('POST /api/v1/provider/me/services - HTTP 201', res.status === 201);
    check('provider service has id', typeof res.body?.id === 'string');
    serviceId = requireResponseId('POST /api/v1/provider/me/services', res);
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/services/${serviceId}`, {
      title: 'Phase8 Service Updated',
    }, providerUser.token);
    check('PATCH /api/v1/provider/me/services/:id - HTTP 200', res.status === 200);
    check('provider service updated', res.body?.title === 'Phase8 Service Updated');
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  {
    const res = await request('GET', '/api/v1/provider-categories');
    check('GET /api/v1/provider-categories - HTTP 200', res.status === 200);
    check('provider categories include fixture', Array.isArray(res.body) && res.body.some((item) => item.id === reference.category.id));
  }

  {
    const search = encodeURIComponent(PROVIDER_BUSINESS_NAME);
    const res = await request('GET', `/api/v1/providers?search=${search}&limit=100`);
    check('GET /api/v1/providers - HTTP 200', res.status === 200);
    check('provider listing is paginated', Array.isArray(res.body?.items));
    check('provider listing includes active provider', res.body?.items?.some((item) => item.id === providerId));
  }

  {
    const res = await request('GET', `/api/v1/providers/${providerId}`);
    check('GET /api/v1/providers/:id - HTTP 200', res.status === 200);
    check('provider detail id matches', res.body?.id === providerId);
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Phase8 Quote Plan',
      city: 'Sanaa',
      estimatedBudget: '900000.00',
    }, customer.token);
    check('customer creates plan - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/quote-requests`, {
      providerId,
      serviceId,
      cityId: reference.city.id,
      guestCount: 120,
      message: 'Need a quote for Phase8',
      budgetMin: '200000.00',
      budgetMax: '400000.00',
    }, customer.token);
    check('POST /api/v1 plan quote request - HTTP 201', res.status === 201);
    check('quote belongs to plan', res.body?.weddingPlanId === planId);
    check('quote belongs to provider', res.body?.providerId === providerId);
    quoteId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/quote-requests`, null, customer.token);
    check('GET /api/v1 plan quote requests - HTTP 200', res.status === 200);
    check('plan quote list includes quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/api/v1/quote-requests/${quoteId}`, null, customer.token);
    check('GET /api/v1/quote-requests/:id - HTTP 200', res.status === 200);
    check('quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('GET', '/api/v1/provider/me/quote-requests', null, providerUser.token);
    check('GET /api/v1/provider/me/quote-requests - HTTP 200', res.status === 200);
    check('provider quote list includes quote', Array.isArray(res.body) && res.body.some((quote) => quote.id === quoteId));
  }

  {
    const res = await request('GET', `/api/v1/provider/me/quote-requests/${quoteId}`, null, providerUser.token);
    check('GET /api/v1/provider/me/quote-requests/:id - HTTP 200', res.status === 200);
    check('provider quote detail id matches', res.body?.id === quoteId);
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${quoteId}/offers`, {
      title: 'Phase8 Offer',
      message: 'Offer details for Phase8',
      amount: '300000.00',
      validUntil: '2026-12-31T00:00:00.000Z',
    }, providerUser.token);
    check('POST /api/v1 provider quote offer - HTTP 201', res.status === 201);
    check('offer has id', typeof res.body?.id === 'string');
    check('offer starts pending', res.body?.status === 'PENDING');
    offerId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/quote-offers/${offerId}`, {
      amount: '320000.00',
    }, providerUser.token);
    check('PATCH /api/v1/provider/me/quote-offers/:id - HTTP 200', res.status === 200);
    check('offer amount updated', res.body?.amount === '320000');
  }

  {
    const res = await request('GET', `/api/v1/quote-requests/${quoteId}`, null, customer.token);
    check('quote detail includes offers', Array.isArray(res.body?.offers) && res.body.offers.some((offer) => offer.id === offerId));
  }

  {
    const res = await request('PATCH', `/api/v1/quote-offers/${offerId}/accept`, null, customer.token);
    check('PATCH /api/v1/quote-offers/:id/accept - HTTP 200', res.status === 200);
    check('accepted offer status is ACCEPTED', res.body?.offer?.status === 'ACCEPTED');
    check('accept creates plan provider link', res.body?.planProviderLink?.providerId === providerId);
    check('accept declares no automatic finance record', res.body?.automaticFinancialRecordCreated === false);
    check('accept returns financial suggestion', res.body?.financialSuggestion?.recommendedAction === 'CREATE_FINANCIAL_COMMITMENT');
    check('accept returns next actions', Array.isArray(res.body?.nextActions) && res.body.nextActions.includes('createFinancialCommitment') && res.body.nextActions.includes('recordPayment'));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, customer.token);
    check('dashboard providerCount reflects accepted offer', res.status === 200 && res.body?.providerCount === 1);
  }

  {
    const res = await request('PATCH', `/api/v1/provider/me/quote-offers/${offerId}`, {
      amount: '330000.00',
    }, providerUser.token);
    check('provider cannot update accepted offer', res.status === 409);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/quote-requests`, {
      providerId,
      serviceId,
      message: 'Need another quote for rejection',
    }, customer.token);
    check('second quote create - HTTP 201', res.status === 201);
    const secondQuoteId = res.body?.id;
    const offer = await request('POST', `/api/v1/provider/me/quote-requests/${secondQuoteId}/offers`, {
      message: 'Rejectable offer',
      amount: '200000.00',
    }, providerUser.token);
    check('second offer create - HTTP 201', offer.status === 201);
    rejectedOfferId = offer.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/quote-offers/${rejectedOfferId}/reject`, null, customer.token);
    check('PATCH /api/v1/quote-offers/:id/reject - HTTP 200', res.status === 200);
    check('rejected offer status is REJECTED', res.body?.status === 'REJECTED');
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/quote-requests`, null, outsider.token);
    check('outsider cannot list plan quotes', res.status === 404);
  }

  {
    const res = await request('GET', '/api/v1/provider/me/quote-requests');
    check('provider quote requests without token returns 401', res.status === 401);
  }

  {
    const res = await request('DELETE', `/api/v1/provider/me/services/${serviceId}`, null, providerUser.token);
    check('DELETE /api/v1/provider/me/services/:id - HTTP 200', res.status === 200);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run()
  .catch((err) => {
    console.error('Providers quotes smoke error:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
