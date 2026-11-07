#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');

/**
 * Onboarding + Active Plan Smoke Test
 * Covers authenticated onboarding, /api/v1 compatibility paths, real category
 * creation, active plan selection, and basic invalid input guards.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9677${suffix}`;
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

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method,
      headers,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes('passwordHash');
}

async function run() {
  console.log('\nOnboarding + Active Plan Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let accessToken = null;
  let userId = null;
  let activePlanId = null;
  let secondPlanId = null;

  {
    const res = await registerVerified(request, {
      name: 'Onboarding Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /api/v1/auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register returns user id', typeof res.body?.user?.id === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    accessToken = res.body?.accessToken;
    userId = res.body?.user?.id;
  }

  {
    const res = await request('GET', '/api/v1/me', null, accessToken);
    check('GET /api/v1/me - HTTP 200', res.status === 200);
    check('GET /api/v1/me returns current user', res.body?.id === userId);
    check('GET /api/v1/me does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('GET /api/v1/wedding-plans/active before onboarding - HTTP 200', res.status === 200);
    check('active plan before onboarding is empty', res.body === null || res.body === '');
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      persona: 'GROOM',
      location: {
        governorate: 'Sanaa',
        city: 'Sanaa',
        district: 'Old City',
      },
      weddingDate: '2026-12-20T00:00:00.000Z',
      priorities: ['budget', 'tasks', 'providers'],
      estimatedBudget: '1500000',
      currency: 'YER',
      selectedCategories: ['Hall', 'Food', 'Photography'],
    }, accessToken);
    check('POST /api/v1/onboarding/complete - HTTP 201', res.status === 201);
    check('onboarding returns user', res.body?.user?.id === userId);
    check('onboarding returns activeWeddingPlan', typeof res.body?.activeWeddingPlan?.id === 'string');
    check('onboarding sets activeWeddingPlanId', res.body?.user?.activeWeddingPlanId === res.body?.activeWeddingPlan?.id);
    check('onboarding persists persona', res.body?.activeWeddingPlan?.persona === 'GROOM');
    check('onboarding persists city from location', res.body?.activeWeddingPlan?.city === 'Sanaa');
    check('onboarding persists priorities', Array.isArray(res.body?.activeWeddingPlan?.priorities) && res.body.activeWeddingPlan.priorities.length === 3);
    check('onboarding creates real budget categories', Array.isArray(res.body?.budgetCategories) && res.body.budgetCategories.length === 3);
    check('onboarding does not expose passwordHash', !hasPasswordHash(res.body));
    activePlanId = res.body?.activeWeddingPlan?.id;
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans', null, accessToken);
    check('GET /api/v1/wedding-plans - HTTP 200', res.status === 200);
    check('accessible plans response is array', Array.isArray(res.body));
    check('accessible plans include onboarding plan', Array.isArray(res.body) && res.body.some((plan) => plan.id === activePlanId));
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('GET /api/v1/wedding-plans/active after onboarding - HTTP 200', res.status === 200);
    check('active plan matches onboarding plan', res.body?.id === activePlanId);
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Second Smoke Wedding Plan',
      city: 'Aden',
      selectedCategories: ['Decoration'],
    }, accessToken);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('second plan has id', typeof res.body?.id === 'string');
    secondPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${secondPlanId}/set-active`, null, accessToken);
    check('POST /api/v1/wedding-plans/:id/set-active - HTTP 201', res.status === 201);
    check('set-active returns selected plan', res.body?.id === secondPlanId);
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('active plan changes after set-active', res.body?.id === secondPlanId);
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      estimatedBudget: '-5',
      selectedCategories: ['Invalid Budget Category'],
    }, accessToken);
    check('negative onboarding budget returns 400', res.status === 400);
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
    });
    check('onboarding without token returns 401', res.status === 401);
  }

  await importLocalPlanChecks(accessToken);

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

/**
 * Saving a plan kept on the phone into the account (S9), on a real database:
 * RA-BE-63 (a reminder above what is left), RA-BE-64 (a plan past the old
 * caps and past the default body limit), RA-BE-65 (a retry with other content
 * is refused, the same content in another order is the same save) and
 * RA-BE-83 (two guests on one number are both kept).
 */
async function importLocalPlanChecks(accessToken) {
  const migrationId = `guest-plan-smoke-${timestamp}`;
  const guests = Array.from({ length: 1200 }, (_, index) => ({
    name: `ضيف رقم ${index + 1} من أهل العريس`,
    phone: `+96777${String(1000000 + index).slice(-7)}`,
    side: 'GROOM',
  }));
  guests.push({ name: 'أبو محمد', phone: '+967771234500', side: 'FAMILY' });
  guests.push({ name: 'أم محمد', phone: '+967771234500', side: 'FAMILY' });
  const plan = {
    clientMigrationId: migrationId,
    path: 'USER',
    persona: 'GROOM',
    title: 'عرس الاستيراد',
    city: 'صنعاء',
    currency: 'YER',
    selectedCategories: ['القاعة', 'التصوير'],
    costs: [
      {
        // A reminder of 500,000 written first, then 800,000 paid straight on
        // the agreement: 200,000 left, the reminder above it (RA-BE-63).
        title: 'قاعة الفرح',
        totalAmount: '1000000',
        categoryName: 'القاعة',
        payments: [{ amount: '800000', paidAt: '2026-11-01T09:00:00.000Z' }],
        paymentSchedules: [{ amount: '500000', dueDate: '2026-12-01T00:00:00.000Z' }],
      },
      {
        // Paid in full: the pending reminder does not survive it (R4).
        title: 'المصور',
        totalAmount: '300000',
        categoryName: 'التصوير',
        payments: [{ amount: '300000', paidAt: '2026-11-02T09:00:00.000Z' }],
        paymentSchedules: [{ amount: '100000', dueDate: '2026-12-05T00:00:00.000Z' }],
      },
    ],
    tasks: Array.from({ length: 350 }, (_, index) => ({ title: `مهمة ${index + 1}` })),
    guests,
  };
  const bodyBytes = Buffer.byteLength(JSON.stringify(plan));
  check(`import body is past the default 100kb (${bodyBytes} bytes)`, bodyBytes > 100 * 1024);

  let importedPlanId = null;
  {
    const res = await request('POST', '/api/v1/onboarding/import-local', plan, accessToken);
    check('POST /api/v1/onboarding/import-local (1202 guests, 350 tasks) - HTTP 201', res.status === 201);
    check('import is not a replay the first time', res.body?.alreadyImported === false);
    check('import takes every guest', res.body?.imported?.guests === 1202);
    check('import takes every task', res.body?.imported?.tasks === 350);
    check('import keeps only the reminder still owed', res.body?.imported?.paymentSchedules === 1);
    importedPlanId = res.body?.activeWeddingPlan?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${importedPlanId}/costs`, null, accessToken);
    const costs = Array.isArray(res.body) ? res.body : res.body?.items ?? [];
    const hall = costs.find((cost) => cost.title === 'قاعة الفرح');
    const schedules = hall
      ? await request('GET', `/api/v1/costs/${hall.id}/payment-schedules`, null, accessToken)
      : null;
    const scheduleList = Array.isArray(schedules?.body) ? schedules.body : schedules?.body?.items ?? [];
    const schedule = scheduleList.find((item) => item.status === 'PENDING');
    check('the hall reminder keeps the amount written (500,000)', Number(schedule?.amount) === 500000);
    check('the hall reminder asks for what is left (200,000)', Number(schedule?.amountDue) === 200000);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${importedPlanId}/guests`, null, accessToken);
    const list = Array.isArray(res.body) ? res.body : res.body?.items ?? [];
    const father = list.find((guest) => guest.name === 'أبو محمد');
    const mother = list.find((guest) => guest.name === 'أم محمد');
    check('two guests on one number: the first keeps the number', father?.phone === '+967771234500');
    check('two guests on one number: the second is kept, its number noted', mother !== undefined
      && !mother.phone && String(mother.notes ?? '').includes('+967771234500'));
  }

  {
    // The same save again, its lists read back in another order.
    const replay = { ...plan, guests: [...plan.guests].reverse(), tasks: [...plan.tasks].reverse() };
    const res = await request('POST', '/api/v1/onboarding/import-local', replay, accessToken);
    check('the same plan again is a replay - HTTP 201', res.status === 201 && res.body?.alreadyImported === true);
    check('the replay answers with the same plan', res.body?.activeWeddingPlan?.id === importedPlanId);
  }

  {
    // The first answer was lost, then the plan changed on the phone.
    const changed = { ...plan, guests: [...plan.guests, { name: 'ضيف أُضيف بعدين', side: 'FRIEND' }] };
    const res = await request('POST', '/api/v1/onboarding/import-local', changed, accessToken);
    check('the same id with other content - HTTP 409', res.status === 409);
    check('the refusal carries LOCAL_PLAN_SAVED_BEFORE', res.body?.code === 'LOCAL_PLAN_SAVED_BEFORE');
    check('the refusal is in Arabic', /[\u0600-\u06FF]/u.test(String(res.body?.message ?? '')));
    const guestsAfter = await request('GET', `/api/v1/wedding-plans/${importedPlanId}/guests`, null, accessToken);
    const listAfter = Array.isArray(guestsAfter.body) ? guestsAfter.body : guestsAfter.body?.items ?? [];
    check('the refused save changed nothing in the account', listAfter.length === 1202);
  }

  {
    // A large body without a session is read at the default limit only.
    const res = await request('POST', '/api/v1/onboarding/import-local', plan);
    check('a large anonymous body is refused before it is read (413)', res.status === 413);
  }
}

run().catch((err) => {
  console.error('Onboarding active plan smoke error:', err.message);
  process.exit(1);
});
