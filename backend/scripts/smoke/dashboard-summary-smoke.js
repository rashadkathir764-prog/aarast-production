#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');
const { riyadhDateOffsetIso } = require('./smoke-utils');

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

async function registerUser(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, userId: res.body?.user?.id, phone };
}

async function createOptionalQuote(planId, token) {
  const providersRes = await request('GET', '/api/v1/providers?limit=1');
  const provider = providersRes.body?.items?.[0];
  if (!provider?.id) return false;

  const quoteRes = await request('POST', `/api/v1/providers/${provider.id}/quote-requests`, {
    weddingPlanId: planId,
    eventDate: riyadhDateOffsetIso(30),
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
      weddingDate: riyadhDateOffsetIso(45),
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
      dueDate: riyadhDateOffsetIso(0),
    }, owner.token);
    check('owner creates due payment schedule - HTTP 201', scheduleRes.status === 201);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Done task',
      dueDate: riyadhDateOffsetIso(0),
      status: 'DONE',
      priority: 'MEDIUM',
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Today task',
      dueDate: riyadhDateOffsetIso(0),
      status: 'TODO',
      priority: 'HIGH',
    }, owner.token);
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Overdue task',
      dueDate: riyadhDateOffsetIso(-1),
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

  // The home's numbers agree with the lists they sum up (2026-11-08): a
  // cancelled task is not one of the plan's tasks, a guest's reply is the
  // one the guest list reads, and the wedding is counted in Sana'a days.
  {
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Cancelled task',
      dueDate: riyadhDateOffsetIso(3),
      status: 'CANCELLED',
      priority: 'LOW',
    }, owner.token);
    const guests = await request('GET', `/api/v1/wedding-plans/${planId}/guests`, null, owner.token);
    const list = Array.isArray(guests.body) ? guests.body : guests.body?.items ?? [];
    const pendingGuest = list.find((guest) => guest.name === 'Pending Guest');
    // The owner's form marks a guest confirmed by `status`.
    const marked = await request('PATCH', `/api/v1/guests/${pendingGuest?.id}`, { status: 'CONFIRMED' }, owner.token);
    check('owner marks a guest confirmed from the form - HTTP 200', marked.status === 200);
    check('the form\'s answer is the guest\'s reply', marked.body?.attendanceStatus === 'CONFIRMED');

    const home = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, owner.token);
    const guestSummary = await request('GET', `/api/v1/wedding-plans/${planId}/guests/summary`, null, owner.token);
    check('a cancelled task is not counted in the home\'s tasks', home.body?.totalTasks === 3);
    check('the home\'s progress leaves the cancelled task out', home.body?.progressPercentage === 33);
    check('the home counts the confirmed guests the guest list counts',
      home.body?.confirmedGuests === 2 && guestSummary.body?.confirmed === 2);
    check('the home counts the wedding in Sana\'a days', home.body?.daysRemaining === 45);
  }

  {
    // RA-BE-42: the viewer joins by accepting an invite (P5).
    const res = await inviteAndAccept(request, {
      planId,
      inviterToken: owner.token,
      member: viewer,
      access: { role: 'VIEWER' },
    });
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
    check('viewer without task permission receives zero task count', res.body?.totalTasks === 0);
    check('viewer without task permission receives zero completed tasks', res.body?.completedTasks === 0);
    check('viewer without task permission receives zero due tasks', res.body?.todayTasks === 0 && res.body?.overdueTasks === 0);
    check('viewer importantItems hides task details', !res.body?.importantItems?.some((item) => item.type === 'TASK_OVERDUE'));
    check('viewer without guest permission receives zero guest count', res.body?.guestCount === 0);
    check('viewer without guest permission receives zero confirmed guests', res.body?.confirmedGuests === 0);
    check('viewer without guest permission receives zero incomplete guests', res.body?.incompleteGuestsCount === 0);
    check('viewer summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    // RA-BE-91: a member's home held its connection while waiting for a
    // second; the pool is the live server's 3 (run-isolated-smoke.js), so a
    // few members opening the app together all got 500 after 10 s.
    const burst = await Promise.all(
      Array.from({ length: 9 }, () =>
        request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, viewer.token),
      ),
    );
    check('nine member homes at once all open', burst.every((res) => res.status === 200));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`);
    check('summary without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, unrelated.token);
    check('unrelated user cannot read summary', res.status === 404);
  }

  {
    // RA-BE-97: while the owner waits out the account's deletion (D63) the
    // plan is closed to its members. It is left out of the member's plans,
    // and their open plan reads as none; one such plan made the list 404.
    await request('POST', `/api/v1/wedding-plans/${planId}/set-active`, null, viewer.token);
    const asked = await request('POST', '/api/v1/users/me/deletion', { confirmWord: 'حذف' }, owner.token);
    check('the owner asks for the account\'s deletion', asked.status === 200 || asked.status === 201);
    const plans = await request('GET', '/api/v1/wedding-plans', null, viewer.token);
    check('the member\'s plans load without the closed plan',
      plans.status === 200 && Array.isArray(plans.body) && !plans.body.some((plan) => plan.id === planId));
    const active = await request('GET', '/api/v1/wedding-plans/active', null, viewer.token);
    check('the member\'s open plan reads as none, not 404',
      active.status === 200 && (active.body === null || active.body === ''));

    // RA-BE-102: «رجعت خطة» belongs to the plan. Once the owner asks again
    // the plan is closed, so that notice is neither listed nor counted: it
    // listed, counted, and opened as 404.
    const back = await request('DELETE', '/api/v1/users/me/deletion', null, owner.token);
    check('the owner takes the deletion back', back.status === 200);
    const reopened = await request('GET', '/api/v1/notifications?limit=50', null, viewer.token);
    const planNotice = (reopened.body?.items ?? []).find((item) => item.weddingPlanId === planId);
    check('the member is told the plan is back, on the plan', Boolean(planNotice));
    const again = await request('POST', '/api/v1/users/me/deletion', { confirmWord: 'حذف' }, owner.token);
    check('the owner asks again', again.status === 200 || again.status === 201);
    const list = await request('GET', '/api/v1/notifications?limit=50', null, viewer.token);
    const items = list.body?.items ?? [];
    // The invitation keeps its plan and stays the member's to read (it opens);
    // the plan's own notices go while it is closed.
    check('the closed plan\'s notice is not listed to the member',
      list.status === 200 && Boolean(planNotice) && !items.some((item) => item.id === planNotice.id));
    const opened = await Promise.all(
      items.map((item) => request('GET', `/api/v1/notifications/${item.id}`, null, viewer.token)),
    );
    check('every notice listed to the member opens', opened.every((res) => res.status === 200));
    const unread = await request('GET', '/api/v1/notifications/unread-count', null, viewer.token);
    check('the member\'s count is the unread notices listed',
      unread.status === 200 && unread.body?.count === items.filter((item) => !item.readAt).length);
    check('the plan\'s notice itself still reads as 404 while it is closed',
      (await request('GET', `/api/v1/notifications/${planNotice?.id}`, null, viewer.token)).status === 404);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Dashboard summary smoke error:', err.message);
  process.exit(1);
});
