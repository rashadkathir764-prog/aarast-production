'use strict';

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokePass123!';
const suffix = `${Date.now()}`.slice(-8);
const TEST_PHONE = `+9677${suffix}`;

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    passed++;
    console.log(`PASS - ${label}`);
  } else {
    failed++;
    console.log(`FAIL - ${label}`);
  }
}

function request(method, path, body, token, requestId) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json' };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    if (requestId) headers['X-Client-Request-Id'] = requestId;

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
            resolve({ status: res.statusCode, body: data ? JSON.parse(data) : null });
          } catch {
            resolve({ status: res.statusCode, body: data });
          }
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function requireId(label, response) {
  const id = response.body?.id;
  if (typeof id === 'string' && id.length > 0) return id;
  throw new Error(`${label} setup failed with HTTP ${response.status}`);
}

async function run() {
  console.log('\nCanonical Financial Ledger Concurrency Smoke');
  console.log(`Target: ${BASE_URL}\n`);

  let token;
  try {
    const registration = await registerVerified(request, {
      name: 'Canonical financial concurrency smoke',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('verified money user registration succeeds', registration.status === 201);
    token = registration.body?.accessToken;
    if (!token) throw new Error(`registration setup failed with HTTP ${registration.status}`);

    const plan = await request('POST', '/api/v1/wedding-plans', {
      title: 'Canonical immutable ledger smoke plan',
      city: 'Sanaa',
    }, token);
    check('ledger smoke plan is created', plan.status === 201 && typeof plan.body?.id === 'string');
    const planId = requireId('plan', plan);

    const categoryClientId = randomUUID();
    const budget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      {
        totalBudget: '1000',
        currency: 'YER',
        categories: [
          { clientId: categoryClientId, name: 'Ledger', allocatedAmount: '1000' },
        ],
      },
      token,
    );
    check('ledger smoke money budget is created', budget.status === 200);
    const categoryId = budget.body?.idMap?.[categoryClientId];
    if (!categoryId) throw new Error('category setup failed');

    const cost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Concurrent schedule payment',
        totalAmount: '500',
      },
      token,
    );
    check('concurrency cost is created', cost.status === 201 && typeof cost.body?.id === 'string');
    const costId = requireId('cost', cost);

    const schedule = await request(
      'POST',
      `/api/v1/costs/${costId}/payment-schedules`,
      { amount: '200', dueDate: new Date().toISOString() },
      token,
    );
    check('pending schedule is created', schedule.status === 201 && schedule.body?.status === 'PENDING');
    const scheduleId = requireId('schedule', schedule);

    const payResults = await Promise.all([
      request('POST', `/api/v1/payment-schedules/${scheduleId}/pay`, {}, token, `schedule-pay-a-${suffix}`),
      request('POST', `/api/v1/payment-schedules/${scheduleId}/pay`, {}, token, `schedule-pay-b-${suffix}`),
    ]);
    check('both concurrent schedule-pay calls complete successfully', payResults.every((item) => item.status === 201));
    check('both concurrent calls resolve to the same payment', payResults[0].body?.id === payResults[1].body?.id && payResults.every((item) => item.body?.entryType === 'PAYMENT'));

    let ledger = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/cost-payments?page=1&limit=100`,
      null,
      token,
    );
    if (!Array.isArray(ledger.body?.items)) {
      throw new Error(`payment ledger list failed with HTTP ${ledger.status}`);
    }
    let entries = ledger.body.items;
    const schedulePayments = entries.filter(
      (entry) => entry.paymentScheduleId === scheduleId && entry.entryType === 'PAYMENT',
    );
    check('concurrent schedule pay creates exactly one payment entry', schedulePayments.length === 1);
    check('the original payment is reversible', schedulePayments[0]?.reversible === true);

    let refreshedCost = await request('GET', `/api/v1/costs/${costId}`, null, token);
    check('concurrent schedule pay increments paid amount exactly once', refreshedCost.status === 200 && refreshedCost.body?.paidAmount === '200');

    const paymentId = schedulePayments[0]?.id;
    if (!paymentId) throw new Error('concurrent payment was not recorded');
    const reverseResults = await Promise.all([
      request(
        'POST',
        `/api/v1/cost-payments/${paymentId}/reverse`,
        { reason: 'Concurrent correction A' },
        token,
        `reverse-a-${suffix}`,
      ),
      request(
        'POST',
        `/api/v1/cost-payments/${paymentId}/reverse`,
        { reason: 'Concurrent correction B' },
        token,
        `reverse-b-${suffix}`,
      ),
    ]);
    const reverseStatuses = reverseResults.map((item) => item.status).sort((a, b) => a - b);
    check('concurrent reversal produces one success and one conflict', reverseStatuses[0] === 201 && reverseStatuses[1] === 409);
    check('concurrent reversal never returns a server error', reverseResults.every((item) => item.status < 500));

    ledger = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/cost-payments?page=1&limit=100`,
      null,
      token,
    );
    entries = ledger.body?.items ?? [];
    const reversals = entries.filter(
      (entry) => entry.entryType === 'REVERSAL' && entry.reversalOfId === paymentId,
    );
    const original = entries.find((entry) => entry.id === paymentId);
    check('concurrent reversal creates exactly one compensating entry', reversals.length === 1);
    check('original payment remains in immutable history', Boolean(original));
    check('original payment points to its reversal and is no longer reversible', original?.reversedById === reversals[0]?.id && original?.reversible === false);

    refreshedCost = await request('GET', `/api/v1/costs/${costId}`, null, token);
    check('reversal restores cost paid amount to zero', refreshedCost.status === 200 && refreshedCost.body?.paidAmount === '0');

    const schedules = await request(
      'GET',
      `/api/v1/costs/${costId}/payment-schedules`,
      null,
      token,
    );
    const reopenedSchedule = schedules.body?.find((item) => item.id === scheduleId);
    check('reversal reopens the linked schedule', reopenedSchedule?.status === 'PENDING' && reopenedSchedule?.paidAt === null);

    const deleteHistoricSchedule = await request(
      'DELETE',
      `/api/v1/payment-schedules/${scheduleId}`,
      null,
      token,
    );
    check('schedule with ledger history cannot be deleted', deleteHistoricSchedule.status === 409);

    const reverseReversal = await request(
      'POST',
      `/api/v1/cost-payments/${reversals[0]?.id}/reverse`,
      { reason: 'A reversal cannot be reversed' },
      token,
    );
    check('a compensating reversal entry cannot itself be reversed', reverseReversal.status === 409);

    const raceCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Pay versus total update race',
        totalAmount: '500',
      },
      token,
    );
    const raceCostId = requireId('balance race cost', raceCost);
    const raceSchedule = await request(
      'POST',
      `/api/v1/costs/${raceCostId}/payment-schedules`,
      { amount: '200', dueDate: new Date().toISOString() },
      token,
    );
    const raceScheduleId = requireId('balance race schedule', raceSchedule);
    check('balance-update race fixtures are created', raceCost.status === 201 && raceSchedule.status === 201);

    const balanceRace = await Promise.all([
      request('POST', `/api/v1/payment-schedules/${raceScheduleId}/pay`, {}, token, `balance-pay-${suffix}`),
      request('PATCH', `/api/v1/costs/${raceCostId}`, { totalAmount: '100' }, token, `balance-total-${suffix}`),
    ]);
    const balanceStatuses = balanceRace.map((item) => item.status).sort((a, b) => a - b);
    const paymentWon = balanceRace[0].status === 201 && balanceRace[1].status === 400;
    const totalUpdateWon = balanceRace[0].status === 400 && balanceRace[1].status === 200;
    const balanceStatusIsValid = paymentWon || totalUpdateWon;
    check('pay versus total update serializes to one committed action and one rejection', balanceStatusIsValid);
    check('balance-update race never returns HTTP 500', balanceRace.every((item) => item.status < 500));

    const raceCostState = await request('GET', `/api/v1/costs/${raceCostId}`, null, token);
    const raceSchedules = await request(
      'GET',
      `/api/v1/costs/${raceCostId}/payment-schedules`,
      null,
      token,
    );
    const raceScheduleState = raceSchedules.body?.find((item) => item.id === raceScheduleId);
    check('balance race preserves paid <= total', Number(raceCostState.body?.paidAmount) <= Number(raceCostState.body?.totalAmount));
    const paidStateIsValid =
      paymentWon &&
      raceCostState.body?.paidAmount === '200' &&
      raceCostState.body?.totalAmount === '500' &&
      raceScheduleState?.status === 'PAID';
    const updatedStateIsValid =
      totalUpdateWon &&
      raceCostState.body?.paidAmount === '0' &&
      raceCostState.body?.totalAmount === '100' &&
      raceScheduleState?.status === 'PENDING';
    const balanceStateIsValid = paidStateIsValid || updatedStateIsValid;
    check('balance race state matches the action that committed first', balanceStateIsValid);
    if (!balanceStatusIsValid || !balanceStateIsValid) {
      console.error(
        `Balance race diagnostics: statuses=${balanceStatuses.join(',')} total=${raceCostState.body?.totalAmount ?? 'missing'} paid=${raceCostState.body?.paidAmount ?? 'missing'} schedule=${raceScheduleState?.status ?? 'missing'}`,
      );
    }

    const cancelRaceCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Payment versus cancellation race',
        totalAmount: '100',
      },
      token,
    );
    const cancelRaceCostId = requireId('cancel race cost', cancelRaceCost);
    const cancelRace = await Promise.all([
      request(
        'POST',
        `/api/v1/costs/${cancelRaceCostId}/payments`,
        { amount: '100' },
        token,
        `cancel-race-pay-${suffix}`,
      ),
      request(
        'POST',
        `/api/v1/costs/${cancelRaceCostId}/cancel`,
        {},
        token,
        `cancel-race-cancel-${suffix}`,
      ),
    ]);
    const cancelRaceStatuses = cancelRace.map((item) => item.status).sort((a, b) => a - b);
    check('payment versus cancellation commits one action and rejects the other', cancelRaceStatuses[0] === 201 && cancelRaceStatuses[1] === 409);
    check('payment-cancellation race never returns HTTP 500', cancelRace.every((item) => item.status < 500));

    const cancelRaceState = await request('GET', `/api/v1/costs/${cancelRaceCostId}`, null, token);
    check(
      'payment-cancellation race leaves a coherent final cost',
      (cancelRaceState.body?.status === 'CANCELLED' && cancelRaceState.body?.paidAmount === '0') ||
        (cancelRaceState.body?.status === 'PAID' && cancelRaceState.body?.paidAmount === '100'),
    );
  } finally {
    if (token) {
      try {
        const cleanup = await request('DELETE', '/api/v1/users/me', null, token);
        check('concurrency fixture account is cleaned', cleanup.status === 200 && cleanup.body?.deleted === true);
      } catch (error) {
        check('concurrency fixture account cleanup completes', false);
        console.error(`Cleanup warning: ${error.message}`);
      }
    }
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Canonical financial ledger concurrency smoke error:', error.message);
  process.exit(1);
});
