#!/usr/bin/env node
'use strict';

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');

/**
 * Canonical money API smoke.
 * Covers budget replacement, costs, payment schedules, append-only payments,
 * reversals, cancellation, summary truth, auth, and money permissions.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokeTest123!';
const phoneSeed = Number(`${Date.now()}`.slice(-8));

let passed = 0;
let failed = 0;

function phone(offset) {
  return `+9677${String((phoneSeed + offset) % 100000000).padStart(8, '0')}`;
}

function check(label, condition) {
  if (condition) {
    passed++;
    console.log(`PASS - ${label}`);
  } else {
    failed++;
    console.log(`FAIL - ${label}`);
  }
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json' };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
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

function dateOffsetIso(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  date.setUTCHours(9, 0, 0, 0);
  return date.toISOString();
}

function hasSensitiveAuthData(value) {
  const serialized = JSON.stringify(value);
  return serialized.includes('passwordHash') || serialized.includes('refreshTokenHash');
}

async function register(name, value) {
  const response = await registerVerified(request, {
    name,
    phone: value,
    password: TEST_PASSWORD,
  });
  check(`${name} registration succeeds`, response.status === 201);
  check(`${name} registration returns an access token`, typeof response.body?.accessToken === 'string');
  check(`${name} registration does not expose auth secrets`, !hasSensitiveAuthData(response.body));
  return {
    token: response.body?.accessToken,
    userId: response.body?.user?.id,
  };
}

async function cleanupAccount(label, token) {
  if (!token) return;
  const response = await request('DELETE', '/api/v1/users/me', null, token);
  check(`${label} fixture account is cleaned`, response.status === 200 && response.body?.deleted === true);
}

async function run() {
  console.log('\nCanonical Money APIs Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);

  const accounts = [];
  try {
    const owner = await register('Money API owner', phone(11));
    const viewer = await register('Money API viewer', phone(12));
    accounts.push(['viewer', viewer.token], ['owner', owner.token]);
    if (!owner.token || !viewer.token || !viewer.userId) {
      throw new Error('registration setup failed');
    }

    const plan = await request('POST', '/api/v1/wedding-plans', {
      title: 'Canonical money API plan',
      city: 'Sanaa',
    }, owner.token);
    check('money API plan is created', plan.status === 201 && typeof plan.body?.id === 'string');
    const planId = plan.body?.id;
    if (!planId) throw new Error(`plan setup failed with HTTP ${plan.status}`);

    const categoryClientId = randomUUID();
    const budget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      {
        totalBudget: '1200',
        currency: 'YER',
        categories: [
          { clientId: categoryClientId, name: 'Hall', allocatedAmount: '1100' },
        ],
      },
      owner.token,
    );
    check('canonical money budget is created', budget.status === 200);
    check('budget response has summary, categories, and id map', budget.body?.summary?.budget?.total === '1200' && budget.body?.categories?.length === 1 && typeof budget.body?.idMap?.[categoryClientId] === 'string');
    const categoryId = budget.body?.idMap?.[categoryClientId];
    if (!categoryId) throw new Error('budget setup failed');

    const cost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Hall agreement',
        totalAmount: '500',
      },
      owner.token,
    );
    check('canonical wedding cost is created', cost.status === 201 && typeof cost.body?.id === 'string');
    check('new cost starts unpaid and open', cost.body?.paidAmount === '0' && cost.body?.remainingAmount === '500' && cost.body?.status === 'OPEN');
    check('wedding cost exposes no redundant due date', !Object.prototype.hasOwnProperty.call(cost.body ?? {}, 'dueDate'));
    const costId = cost.body?.id;
    if (!costId) throw new Error('cost setup failed');

    const getCost = await request('GET', `/api/v1/costs/${costId}`, null, owner.token);
    check('cost get-by-id returns the canonical record', getCost.status === 200 && getCost.body?.id === costId);

    const updateCost = await request(
      'PATCH',
      `/api/v1/costs/${costId}`,
      { title: 'Updated hall agreement', note: 'Updated by canonical smoke' },
      owner.token,
    );
    check('cost update persists canonical fields', updateCost.status === 200 && updateCost.body?.title === 'Updated hall agreement');

    const invalidCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Invalid negative cost',
        totalAmount: '-1',
      },
      owner.token,
    );
    check('negative cost amount is rejected', invalidCost.status === 400);
    const costWithLegacyDueDate = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Legacy due date must be rejected',
        totalAmount: '10',
        dueDate: dateOffsetIso(5),
      },
      owner.token,
    );
    check('legacy wedding-cost dueDate is rejected', costWithLegacyDueDate.status === 400);

    const reminderOnlyCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: categoryId,
        title: 'Reminder-only cost',
        totalAmount: '400',
      },
      owner.token,
    );
    const reminderOnlyCostId = reminderOnlyCost.body?.id;
    check('reminder-only cost is created', reminderOnlyCost.status === 201 && typeof reminderOnlyCostId === 'string');
    const reminderA = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      { amount: '300', dueDate: dateOffsetIso(4) },
      owner.token,
    );
    const reminderB = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      { amount: '300', dueDate: dateOffsetIso(8) },
      owner.token,
    );
    check('reminders do not reserve or divide the outstanding balance', reminderA.status === 201 && reminderB.status === 201);
    const reminderWarningSummary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      owner.token,
    );
    const reminderWarning = reminderWarningSummary.body?.warnings?.find(
      (item) => item.type === 'PAYMENT_SCHEDULE_DUE_SOON',
    );
    check(
      'overlapping reminder warning exposes count without a misleading amount',
      reminderWarningSummary.status === 200 &&
        reminderWarning?.count === 2 &&
        reminderWarning?.amount === null,
    );
    const oversizedReminder = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      { amount: '400.01', dueDate: dateOffsetIso(12) },
      owner.token,
    );
    check('each reminder is still bounded by the current remaining cost', oversizedReminder.status === 400);
    const settlingPayment = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/payments`,
      { amount: '400', paidAt: dateOffsetIso(0) },
      owner.token,
    );
    check('a direct payment can settle a cost despite pending reminders', settlingPayment.status === 201 && settlingPayment.body?.amount === '400');
    const cancelledReminders = await request(
      'GET',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      null,
      owner.token,
    );
    check(
      'settling a cost cancels every pending reminder',
      cancelledReminders.status === 200 &&
        cancelledReminders.body?.length === 2 &&
        cancelledReminders.body.every((item) => item.status === 'CANCELLED'),
    );
    const reopenReminderOnlyCost = await request(
      'POST',
      `/api/v1/cost-payments/${settlingPayment.body?.id}/reverse`,
      { reason: 'Remove reminder-only smoke fixture from active totals' },
      owner.token,
    );
    check('settling payment can be reversed for cleanup', reopenReminderOnlyCost.status === 201);
    const cancelReminderOnlyCost = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/cancel`,
      {},
      owner.token,
    );
    check('reminder-only smoke cost can be cancelled after reversal', cancelReminderOnlyCost.status === 201 && cancelReminderOnlyCost.body?.status === 'CANCELLED');

    const schedule = await request(
      'POST',
      `/api/v1/costs/${costId}/payment-schedules`,
      {
        amount: '200',
        dueDate: dateOffsetIso(2),
        note: 'First scheduled payment',
      },
      owner.token,
    );
    check('payment schedule is created under its cost', schedule.status === 201 && typeof schedule.body?.id === 'string' && schedule.body?.costId === costId);
    check('new payment schedule is pending', schedule.body?.status === 'PENDING' && schedule.body?.paidAt === null);
    const scheduleId = schedule.body?.id;
    if (!scheduleId) throw new Error('payment schedule setup failed');

    const schedules = await request(
      'GET',
      `/api/v1/costs/${costId}/payment-schedules`,
      null,
      owner.token,
    );
    check('cost payment schedules are listed', schedules.status === 200 && schedules.body?.some((item) => item.id === scheduleId));

    const updateSchedule = await request(
      'PATCH',
      `/api/v1/payment-schedules/${scheduleId}`,
      { dueDate: dateOffsetIso(3), note: 'Updated payment date' },
      owner.token,
    );
    check('pending payment schedule can be updated', updateSchedule.status === 200 && updateSchedule.body?.note === 'Updated payment date');

    const dueSchedules = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/payment-schedules/due`,
      null,
      owner.token,
    );
    check('due window includes the upcoming schedule', dueSchedules.status === 200 && dueSchedules.body?.some((item) => item.id === scheduleId));

    const payment = await request(
      'POST',
      `/api/v1/payment-schedules/${scheduleId}/pay`,
      { paidAt: dateOffsetIso(0), method: 'cash', note: 'Scheduled payment smoke' },
      owner.token,
    );
    check('paying a schedule creates one canonical payment', payment.status === 201 && payment.body?.entryType === 'PAYMENT' && payment.body?.paymentScheduleId === scheduleId);
    const paymentId = payment.body?.id;
    if (!paymentId) throw new Error('scheduled payment setup failed');

    const paidCost = await request('GET', `/api/v1/costs/${costId}`, null, owner.token);
    check('schedule payment updates the cost balance', paidCost.status === 200 && paidCost.body?.paidAmount === '200' && paidCost.body?.status === 'PARTIALLY_PAID');

    const planPayments = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/cost-payments?page=1&limit=20`,
      null,
      owner.token,
    );
    check('plan payments use the canonical paginated response', planPayments.status === 200 && Array.isArray(planPayments.body?.items));
    check('plan payments include the scheduled payment', planPayments.body?.items?.some((item) => item.id === paymentId));

    const paymentDetails = await request('GET', `/api/v1/cost-payments/${paymentId}`, null, owner.token);
    check('payment get-by-id returns its inherited context', paymentDetails.status === 200 && paymentDetails.body?.costId === costId && paymentDetails.body?.categoryName === 'Hall');

    const summary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      owner.token,
    );
    check('money summary exposes the canonical budget', summary.status === 200 && summary.body?.budget?.total === '1200' && summary.body?.budget?.allocated === '1100');
    check('money summary counts cost and payment exactly once', summary.body?.costs?.total === '500' && summary.body?.costs?.paid === '200' && summary.body?.costs?.outstanding === '300');
    check('money summary counts the paid schedule', summary.body?.paymentSchedules?.paidCount === 1 && summary.body?.paymentSchedules?.upcomingCount === 0);
    check('money summary has stable arrays and no auth secrets', Array.isArray(summary.body?.categories) && Array.isArray(summary.body?.warnings) && !hasSensitiveAuthData(summary.body));

    const reversal = await request(
      'POST',
      `/api/v1/cost-payments/${paymentId}/reverse`,
      { reason: 'Canonical smoke correction' },
      owner.token,
    );
    check('payment reversal creates an immutable compensating entry', reversal.status === 201 && reversal.body?.entryType === 'REVERSAL' && reversal.body?.reversalOfId === paymentId);

    const reopenedSchedules = await request(
      'GET',
      `/api/v1/costs/${costId}/payment-schedules`,
      null,
      owner.token,
    );
    const reopened = reopenedSchedules.body?.find((item) => item.id === scheduleId);
    check('reversal reopens its linked payment schedule', reopenedSchedules.status === 200 && reopened?.status === 'PENDING' && reopened?.paidAt === null);

    const cancelSchedule = await request(
      'POST',
      `/api/v1/payment-schedules/${scheduleId}/cancel`,
      {},
      owner.token,
    );
    check('reopened schedule can be explicitly cancelled', cancelSchedule.status === 201 && cancelSchedule.body?.status === 'CANCELLED');

    const deleteHistoricSchedule = await request(
      'DELETE',
      `/api/v1/payment-schedules/${scheduleId}`,
      null,
      owner.token,
    );
    check('schedule with immutable ledger history cannot be deleted', deleteHistoricSchedule.status === 409);

    const cancelCost = await request('POST', `/api/v1/costs/${costId}/cancel`, {}, owner.token);
    check('zero-balance cost can be cancelled without deleting history', cancelCost.status === 201 && cancelCost.body?.status === 'CANCELLED');

    const summaryAfterCancel = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      owner.token,
    );
    check('cancelled cost no longer contributes to active money totals', summaryAfterCancel.status === 200 && summaryAfterCancel.body?.costs?.count === 0 && summaryAfterCancel.body?.costs?.total === '0');

    const addViewer = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/members`,
      { userId: viewer.userId, role: 'VIEWER', canViewMoney: false, canManageMoney: false },
      owner.token,
    );
    check('owner adds a member without money permission', addViewer.status === 201);

    const hiddenSummary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      viewer.token,
    );
    check('member without money permission cannot discover the summary', hiddenSummary.status === 404);

    for (const [label, method, path, body] of [
      ['cost detail', 'GET', `/api/v1/costs/${costId}`, null],
      ['payment detail', 'GET', `/api/v1/cost-payments/${paymentId}`, null],
      ['schedule detail', 'GET', `/api/v1/payment-schedules/${scheduleId}`, null],
      ['cost payment write', 'POST', `/api/v1/costs/${costId}/payments`, { amount: '1' }],
      ['schedule payment write', 'POST', `/api/v1/payment-schedules/${scheduleId}/pay`, {}],
      ['payment reversal write', 'POST', `/api/v1/cost-payments/${paymentId}/reverse`, { reason: 'Denied smoke' }],
    ]) {
      const denied = await request(method, path, body, viewer.token);
      check(`member without money permission cannot access ${label}`, denied.status === 404);
    }

    for (const [label, path] of [
      ['plan expenses', `/api/v1/wedding-plans/${planId}/expenses`],
      ['plan commitments', `/api/v1/wedding-plans/${planId}/financial-commitments`],
      ['plan payment records', `/api/v1/wedding-plans/${planId}/financial-payment-records`],
      ['plan installments', `/api/v1/wedding-plans/${planId}/financial-installments/due`],
    ]) {
      const removed = await request('GET', path, null, owner.token);
      check(`removed ${label} endpoint stays absent`, removed.status === 404);
    }

    const noAuth = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`);
    check('money summary requires authentication', noAuth.status === 401);
  } finally {
    for (const [label, token] of accounts) {
      try {
        await cleanupAccount(label, token);
      } catch (error) {
        check(`${label} fixture account cleanup completes`, false);
        console.error(`Cleanup warning (${label}): ${error.message}`);
      }
    }
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Canonical money APIs smoke error:', error.message);
  process.exit(1);
});
