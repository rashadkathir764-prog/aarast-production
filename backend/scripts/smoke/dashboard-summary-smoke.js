#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Dashboard Summary Smoke Test
 * Verifies /api/v1/wedding-plans/:planId/dashboard-summary uses real records,
 * blocks unauthorized access, and hides private finance totals from a viewer.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+9675${suffix}`;
const VIEWER_PHONE = `+9676${suffix}`;
const UNRELATED_PHONE = `+9679${suffix}`;
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
      path: `${url.pathname}${url.search}`,
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

function dateOffsetIso(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  date.setHours(10, 0, 0, 0);
  return date.toISOString();
}

async function registerUser(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, userId: res.body?.user?.id };
}

async function createOptionalQuote(planId, token) {
  const providersRes = await request('GET', '/api/v1/providers?limit=1');
  const provider = providersRes.body?.items?.[0];
  if (!provider?.id) return false;

  const quoteRes = await request('POST', `/api/v1/providers/${provider.id}/quote-requests`, {
    weddingPlanId: planId,
    eventDate: dateOffsetIso(30),
    guestCount: 120,
    message: 'Dashboard summary smoke quote',
  }, token);
  check('optional quote create - HTTP 201', quoteRes.status === 201);
  return quoteRes.status === 201;
}

async function run() {
  console.log('\nDashboard Summary Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Viewer phone: ${VIEWER_PHONE}`);
  console.log(`Unrelated phone: ${UNRELATED_PHONE}\n`);

  const owner = await registerUser('Dashboard Owner', OWNER_PHONE);
  const viewer = await registerUser('Dashboard Viewer', VIEWER_PHONE);
  const unrelated = await registerUser('Dashboard Unrelated', UNRELATED_PHONE);

  let planId = null;
  let payableCostId = null;
  let quoteCreated = false;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Dashboard Summary Plan',
      city: 'Sanaa',
      weddingDate: dateOffsetIso(45),
      estimatedBudget: '2000',
    }, owner.token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('created plan has id', typeof res.body?.id === 'string');
    planId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, owner.token);
    check('empty summary - HTTP 200', res.status === 200);
    check('empty summary plan id matches', res.body?.planId === planId);
    check('empty summary has real zero tasks', res.body?.totalTasks === 0);
    check('empty summary has real zero guests', res.body?.guestCount === 0);
    check('empty summary budget comes from plan', res.body?.budgetTotal === '2000.00');
    check('empty summary marks account-backed data', res.body?.accountBacked === true && res.body?.dataScope === 'ACCOUNT_BACKED');
    check('empty summary confirmed cost is zero', res.body?.confirmedCostTotal === '0.00');
    check('empty summary paid total is zero', res.body?.paidTotal === '0.00');
    check('empty summary outstanding total is zero', res.body?.outstandingTotal === '0.00');
    check('empty summary importantItems is array', Array.isArray(res.body?.importantItems));
    check('empty summary planProviders is array', Array.isArray(res.body?.planProviders));
    check('empty summary importantNotifications is array', Array.isArray(res.body?.importantNotifications));
    check('empty summary generatedAt exists', typeof res.body?.generatedAt === 'string');
    check('empty summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const categoryRes = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Hall',
      allocatedAmount: '800',
    }, owner.token);
    check('owner creates budget category - HTTP 201', categoryRes.status === 201);
    check('budget category has id', typeof categoryRes.body?.id === 'string');

    const paidCostRes = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      title: 'Paid hall deposit',
      totalAmount: '300',
      initialPaymentAmount: '300',
      budgetCategoryId: categoryRes.body?.id,
    }, owner.token);
    check('owner creates categorized paid cost - HTTP 201', paidCostRes.status === 201);
    check('paid cost is fully paid', paidCostRes.body?.status === 'PAID');

    const payableCostRes = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryRes.body?.id,
      partyName: 'Family Support',
      title: 'Family support cost',
      totalAmount: '500',
      initialPaymentAmount: '100',
    }, owner.token);
    check('owner creates partially paid cost - HTTP 201', payableCostRes.status === 201);
    check('partially paid cost status is derived', payableCostRes.body?.status === 'PARTIALLY_PAID');
    payableCostId = payableCostRes.body?.id;

    const scheduleRes = await request('POST', `/api/v1/costs/${payableCostId}/payment-schedules`, {
      amount: '200',
      dueDate: dateOffsetIso(0),
    }, owner.token);
    check('owner creates due payment schedule - HTTP 201', scheduleRes.status === 201);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Done task',
      dueDate: dateOffsetIso(0),
      status: 'DONE',
      priority: 'MEDIUM',
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Today task',
      dueDate: dateOffsetIso(0),
      status: 'TODO',
      priority: 'HIGH',
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Overdue task',
      dueDate: dateOffsetIso(-1),
      status: 'TODO',
      priority: 'HIGH',
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/guests`, {
      name: 'Confirmed Guest',
      phone: '+967700000001',
      status: 'CONFIRMED',
      seatsCount: 1,
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/guests`, {
      name: 'Pending Guest',
      status: 'PENDING',
      seatsCount: 2,
    }, owner.token);
    quoteCreated = await createOptionalQuote(planId, owner.token);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, owner.token);
    check('populated summary - HTTP 200', res.status === 200);
    check('summary confirmedCostTotal is calculated once', res.body?.confirmedCostTotal === '800.00');
    check('summary paidTotal is calculated from the ledger', res.body?.paidTotal === '400.00');
    check('summary outstandingTotal is calculated', res.body?.outstandingTotal === '400.00');
    check('summary remainingBudget subtracts confirmed costs once', res.body?.remainingBudget === '1200.00');
    check('summary duePaymentSchedulesCount is calculated', res.body?.duePaymentSchedulesCount === 1);
    check('summary totalTasks is calculated', res.body?.totalTasks === 3);
    check('summary completedTasks is calculated', res.body?.completedTasks === 1);
    check('summary progressPercentage is calculated', res.body?.progressPercentage === 33);
    check('summary todayTasks is calculated', res.body?.todayTasks === 1);
    check('summary overdueTasks is calculated', res.body?.overdueTasks === 1);
    check('summary guestCount is calculated', res.body?.guestCount === 2);
    check('summary confirmedGuests is calculated', res.body?.confirmedGuests === 1);
    check('summary incompleteGuestsCount is calculated', res.body?.incompleteGuestsCount === 1);
    check('summary quoteRequestsCount is real', res.body?.quoteRequestsCount === (quoteCreated ? 1 : 0));
    check('summary providerCount stays zero before plan-provider model', res.body?.providerCount === 0);
    check('summary acceptedProvidersCount mirrors real links', res.body?.acceptedProvidersCount === 0);
    check('summary quote breakdown is explicit', typeof res.body?.quoteStatusBreakdown?.pending === 'number' && typeof res.body?.quoteStatusBreakdown?.offered === 'number');
    check('summary financialWarnings is array', Array.isArray(res.body?.financialWarnings));
    check('summary importantItems includes overdue task', res.body?.importantItems?.some((item) => item.type === 'TASK_OVERDUE'));
    check('summary importantItems includes due payment schedule', res.body?.importantItems?.some((item) => item.type === 'PAYMENT_SCHEDULE_DUE'));
    check('summary planProviders is array', Array.isArray(res.body?.planProviders));
    check('summary importantNotifications is array', Array.isArray(res.body?.importantNotifications));
    check('summary currentUserRole is OWNER', res.body?.currentUserRole === 'OWNER');
    check('summary owner can view and manage money', res.body?.permissions?.canViewMoney === true && res.body?.permissions?.canManageMoney === true);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/members`, {
      userId: viewer.userId,
      role: 'VIEWER',
    }, owner.token);
    check('owner adds viewer member - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, viewer.token);
    check('viewer summary - HTTP 200', res.status === 200);
    check('viewer role is included', res.body?.currentUserRole === 'VIEWER');
    check('viewer money permissions are false', res.body?.permissions?.canViewMoney === false && res.body?.permissions?.canManageMoney === false);
    check('viewer budget is hidden', res.body?.budgetTotal === null);
    check('viewer confirmed costs are hidden', res.body?.confirmedCostTotal === null);
    check('viewer paid total is hidden', res.body?.paidTotal === null);
    check('viewer outstanding total is hidden', res.body?.outstandingTotal === null);
    check('viewer due payment schedules are hidden', res.body?.duePaymentSchedulesCount === null);
    check('viewer importantItems hides payment schedule details', !res.body?.importantItems?.some((item) => item.type === 'PAYMENT_SCHEDULE_DUE'));
    check('viewer still sees non-finance task count', res.body?.totalTasks === 3);
    check('viewer still sees guest count', res.body?.guestCount === 2);
    check('viewer still sees incomplete guest count', res.body?.incompleteGuestsCount === 1);
    check('viewer summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`);
    check('summary without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, unrelated.token);
    check('unrelated user cannot read summary', res.status === 404);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Dashboard summary smoke error:', err.message);
  process.exit(1);
});
