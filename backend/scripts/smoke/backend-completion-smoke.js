#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Backend Completion Smoke Test
 * Runs one end-to-end mobile backend journey across onboarding, active plan,
 * dashboard, money, tasks, guests, providers, quote offers, and notifications.
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
const suffix = `${Date.now().toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+96770${suffix}`;
const PROVIDER_PHONE = `+96771${suffix}`;
const OUTSIDER_PHONE = `+96772${suffix}`;
const TEST_PASSWORD = 'SmokeTest123!';
const PROVIDER_BUSINESS_NAME = `Backend Completion Provider Business ${suffix}`;

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

function dateOffsetIso(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  date.setHours(10, 0, 0, 0);
  return date.toISOString();
}

async function ensureReferenceData() {
  const city = await prisma.city.upsert({
    where: {
      nameAr_countryCode: {
        nameAr: 'Backend Completion Smoke City',
        countryCode: 'YE',
      },
    },
    update: { isActive: true },
    create: {
      nameAr: 'Backend Completion Smoke City',
      nameEn: 'Backend Completion Smoke City',
      countryCode: 'YE',
      isActive: true,
      sortOrder: 10,
    },
  });

  const category = await prisma.providerCategory.upsert({
    where: { slug: 'backend-completion-smoke-category' },
    update: { isActive: true },
    create: {
      nameAr: 'Backend Completion Smoke Category',
      nameEn: 'Backend Completion Smoke Category',
      slug: 'backend-completion-smoke-category',
      icon: 'check-circle',
      isActive: true,
      sortOrder: 10,
    },
  });

  return { city, category };
}

async function register(name, phone) {
  let currentPhone = phone;
  let res = null;
  for (let attempt = 0; attempt < 5; attempt++) {
    res = await registerVerified(request, {
      name,
      phone: currentPhone,
      password: TEST_PASSWORD,
    });
    if (res.status === 201) break;
    currentPhone = `${phone.slice(0, -7)}${Date.now().toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
  }

  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register returns user id`, typeof res.body?.user?.id === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, user: res.body?.user, phone: currentPhone };
}

async function run() {
  console.log('\nBackend Completion Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Provider phone: ${PROVIDER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const reference = await ensureReferenceData();

  {
    const res = await request('GET', '/health');
    check('GET /health - HTTP 200', res.status === 200);
  }

  const owner = await register('Backend Completion Owner', OWNER_PHONE);
  const providerUser = await register('Backend Completion Provider', PROVIDER_PHONE);
  const outsider = await register('Backend Completion Outsider', OUTSIDER_PHONE);

  let planId = null;
  let categoryId = null;
  let costId = null;
  let paymentScheduleId = null;
  let taskId = null;
  let checklistItemId = null;
  let groupId = null;
  let providerId = null;
  let serviceId = null;
  let quoteId = null;
  let offerId = null;
  let notificationId = null;

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      persona: 'GROOM',
      location: {
        governorate: 'Sanaa',
        city: 'Sanaa',
        district: 'Old City',
      },
      weddingDate: dateOffsetIso(120),
      priorities: ['budget', 'tasks', 'guests', 'providers'],
      estimatedBudget: '2000000',
      currency: 'YER',
      selectedCategories: ['Hall', 'Photography'],
    }, owner.token);
    check('POST /api/v1/onboarding/complete - HTTP 201', res.status === 201);
    check('onboarding returns active plan id', typeof res.body?.activeWeddingPlan?.id === 'string');
    check('onboarding sets activeWeddingPlanId', res.body?.user?.activeWeddingPlanId === res.body?.activeWeddingPlan?.id);
    check('onboarding does not expose passwordHash', !hasPasswordHash(res.body));
    planId = res.body?.activeWeddingPlan?.id;
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, owner.token);
    check('GET /api/v1/wedding-plans/active - HTTP 200', res.status === 200);
    check('active plan matches onboarding plan', res.body?.id === planId);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Completion Hall',
      allocatedAmount: '800000',
    }, owner.token);
    check('POST budget category - HTTP 201', res.status === 201);
    categoryId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryId,
      title: 'Completion paid cost',
      totalAmount: '250000',
      initialPaymentAmount: '250000',
    }, owner.token);
    check('POST fully paid cost - HTTP 201', res.status === 201);
    check('created fully paid cost has id', typeof res.body?.id === 'string');
    check('created fully paid cost status is PAID', res.body?.status === 'PAID');
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryId,
      partyName: 'Completion Party',
      partyPhone: '+967733333333',
      title: 'Completion scheduled cost',
      totalAmount: '300000',
      initialPaymentAmount: '50000',
    }, owner.token);
    check('POST scheduled cost - HTTP 201', res.status === 201);
    check('scheduled cost starts partially paid', res.body?.status === 'PARTIALLY_PAID');
    costId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/costs/${costId}/payment-schedules`, {
      amount: '100000',
      dueDate: dateOffsetIso(0),
    }, owner.token);
    check('POST payment schedule - HTTP 201', res.status === 201);
    check('created payment schedule is pending', res.body?.status === 'PENDING');
    paymentScheduleId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/payment-schedules/${paymentScheduleId}/pay`, {}, owner.token);
    check('POST payment schedule pay - HTTP 201', res.status === 201);
    check('schedule payment links to schedule', res.body?.payment?.paymentScheduleId === paymentScheduleId);
    check('schedule payment amount is preserved', Number(res.body?.payment?.amount) === 100000);
    check('schedule payment returns paid schedule', res.body?.schedule?.id === paymentScheduleId && res.body?.schedule?.status === 'PAID');
  }

  {
    const res = await request('GET', `/api/v1/costs/${costId}/payment-schedules`, null, owner.token);
    const paidSchedule = Array.isArray(res.body)
      ? res.body.find((schedule) => schedule.id === paymentScheduleId)
      : null;
    check('GET cost payment schedules - HTTP 200', res.status === 200);
    check('payment schedule becomes paid', paidSchedule?.status === 'PAID');
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, owner.token);
    check('GET money-summary - HTTP 200', res.status === 200);
    check('money summary confirmed cost is calculated', Number(res.body?.budget?.confirmedCost) === 550000);
    check('money summary paid total includes both costs', Number(res.body?.costs?.paid) === 400000);
    check('money summary outstanding is calculated', Number(res.body?.costs?.outstanding) === 150000);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Completion task',
      dueDate: dateOffsetIso(0),
      status: 'TODO',
      priority: 'URGENT',
    }, owner.token);
    check('POST task - HTTP 201', res.status === 201);
    taskId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/tasks/${taskId}/checklist`, {
      title: 'Completion checklist item',
      sortOrder: 1,
    }, owner.token);
    check('POST task checklist item - HTTP 201', res.status === 201);
    checklistItemId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}/checklist/${checklistItemId}`, {
      isDone: true,
    }, owner.token);
    check('PATCH task checklist item - HTTP 200', res.status === 200);
    check('checklist item is done', res.body?.isDone === true);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/tasks/summary`, null, owner.token);
    check('GET tasks summary - HTTP 200', res.status === 200);
    check('tasks summary counts task', res.body?.totalTasks === 1);
    check('tasks summary counts today task', res.body?.todayTasks === 1);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guest-groups`, {
      name: 'Completion Guests',
      sortOrder: 1,
    }, owner.token);
    check('POST guest group - HTTP 201', res.status === 201);
    groupId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/guests/bulk`, {
      items: [
        {
          name: 'Completion Confirmed Guest',
          phone: `+96773${suffix}`,
          groupId,
          side: 'GROOM',
          attendanceStatus: 'CONFIRMED',
          seatsCount: 2,
          companionsCount: 1,
        },
        {
          name: 'Completion Pending Guest',
          phone: `+96774${suffix}`,
          groupId,
          side: 'BRIDE',
          attendanceStatus: 'PENDING',
          seatsCount: 1,
        },
      ],
    }, owner.token);
    check('POST guests bulk - HTTP 201', res.status === 201);
    check('bulk guests creates two records', Array.isArray(res.body?.created) && res.body.created.length === 2);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/guests/summary`, null, owner.token);
    check('GET guests summary - HTTP 200', res.status === 200);
    check('guests summary counts guests', res.body?.totalGuests === 2);
    check('guests summary counts confirmed guests', res.body?.confirmedGuests === 1);
  }

  {
    const res = await request('POST', '/api/v1/provider/apply', {
      businessName: PROVIDER_BUSINESS_NAME,
      phone: providerUser.phone,
      cityId: reference.city.id,
      categoryIds: [reference.category.id],
      description: 'Provider used by backend completion smoke.',
    }, providerUser.token);
    check('POST provider profile - HTTP 201', res.status === 201);
    providerId = requireResponseId('POST provider profile', res);
  }

  {
    const res = await request('POST', '/api/v1/provider/me/services', {
      categoryId: reference.category.id,
      title: 'Backend Completion Service',
      basePrice: '350000',
      priceUnit: 'event',
      cityId: reference.city.id,
    }, providerUser.token);
    check('POST provider service - HTTP 201', res.status === 201);
    serviceId = requireResponseId('POST provider service', res);
  }

  await prisma.provider.update({
    where: { id: providerId },
    data: { status: ProviderStatus.ACTIVE },
  });

  {
    const search = encodeURIComponent(PROVIDER_BUSINESS_NAME);
    const res = await request('GET', `/api/v1/providers?search=${search}&limit=100`, null, owner.token);
    check('GET providers - HTTP 200', res.status === 200);
    check('providers include active completion provider', res.body?.items?.some((item) => item.id === providerId));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/quote-requests`, {
      providerId,
      serviceId,
      cityId: reference.city.id,
      guestCount: 120,
      message: 'Backend completion quote request',
      budgetMin: '250000',
      budgetMax: '450000',
    }, owner.token);
    check('POST plan quote request - HTTP 201', res.status === 201);
    quoteId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/provider/me/quote-requests/${quoteId}/offers`, {
      title: 'Backend Completion Offer',
      message: 'Backend completion offer body',
      amount: '360000',
      validUntil: dateOffsetIso(45),
    }, providerUser.token);
    check('POST provider quote offer - HTTP 201', res.status === 201);
    offerId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/notifications?weddingPlanId=${planId}`, null, owner.token);
    check('GET plan notifications - HTTP 200', res.status === 200);
    const notification = Array.isArray(res.body?.items)
      ? res.body.items.find((item) => item.type === 'QUOTE_OFFER_RECEIVED' && item.data?.quoteRequestId === quoteId)
      : null;
    check('quote offer notification exists', typeof notification?.id === 'string');
    check('notifications do not expose passwordHash', !hasPasswordHash(res.body));
    notificationId = notification?.id;
  }

  {
    const res = await request('GET', `/api/v1/notifications/${notificationId}`, null, owner.token);
    check('GET notification by id - HTTP 200', res.status === 200);
    check('notification id matches', res.body?.id === notificationId);
  }

  {
    const res = await request('GET', `/api/v1/notifications/${notificationId}`, null, outsider.token);
    check('outsider cannot read owner notification', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/quote-offers/${offerId}/accept`, null, owner.token);
    check('PATCH quote offer accept - HTTP 200', res.status === 200);
    check('accept creates provider link', res.body?.planProviderLink?.providerId === providerId);
    check('accept declares automatic cost', res.body?.automaticCostCreated === true);
    check('accept returns the automatic cost', typeof res.body?.weddingCost?.id === 'string');
    check('accept exposes the linked cost', res.body?.costSuggestion?.suggestedAction === 'VIEW_COST');
    check('accept exposes next actions', Array.isArray(res.body?.nextActions) && res.body.nextActions.includes('viewCost'));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, owner.token);
    check('GET dashboard summary - HTTP 200', res.status === 200);
    check('dashboard providerCount is real', res.body?.providerCount === 1);
    check('dashboard task count is real', res.body?.totalTasks === 1);
    check('dashboard guest count is real', res.body?.guestCount === 2);
    check('dashboard finance is visible to owner', res.body?.budgetTotal === '2000000.00');
    check('dashboard does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, outsider.token);
    check('outsider cannot read dashboard summary', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`);
    check('money summary without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run()
  .catch((err) => {
    console.error('Backend completion smoke error:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
