#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');
const { eraseFixtureAccount } = require('./account-grace');

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
    phone: value,
  };
}

async function cleanupAccount(label, token) {
  if (!token) return;
  check(`${label} fixture account is cleaned`, await eraseFixtureAccount(request, token));
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

    // RA-BE-09: an agreement is found by its title folded as the phone folds
    // it: «قاعه» (ه for ة, a tatweel) finds «اتفاق القاعة».
    const arabicCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      { budgetCategoryId: categoryId, title: 'اتفاق القاعة', totalAmount: '100' },
      owner.token,
    );
    const foldedSearch = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/costs?search=${encodeURIComponent('القـاعه')}`,
      null,
      owner.token,
    );
    check(
      'cost search folds the Arabic spelling',
      foldedSearch.status === 200
        && foldedSearch.body?.items?.length === 1
        && foldedSearch.body.items[0].id === arabicCost.body?.id,
    );
    await request('DELETE', `/api/v1/costs/${arabicCost.body?.id}`, null, owner.token);

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
      { amount: '300', dueDate: dateOffsetIso(5) },
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
    // RA-BE-25: a reminder the person cancelled by hand is not brought back.
    const reminderDropped = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      { amount: '50', dueDate: dateOffsetIso(6) },
      owner.token,
    );
    const droppedByHand = await request(
      'POST',
      `/api/v1/payment-schedules/${reminderDropped.body?.id}/cancel`,
      {},
      owner.token,
    );
    check('a reminder is cancelled by hand', droppedByHand.status === 201 && droppedByHand.body?.status === 'CANCELLED');
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
        cancelledReminders.body?.length === 3 &&
        cancelledReminders.body.every((item) => item.status === 'CANCELLED'),
    );
    const reopenReminderOnlyCost = await request(
      'POST',
      `/api/v1/cost-payments/${settlingPayment.body?.id}/reverse`,
      { reason: 'Remove reminder-only smoke fixture from active totals' },
      owner.token,
    );
    check('settling payment can be reversed for cleanup', reopenReminderOnlyCost.status === 201);
    // RA-BE-25: the agreement is owed again, so the reminders paying it in
    // full cancelled come back as they were; the one cancelled by hand stays.
    const backReminders = await request(
      'GET',
      `/api/v1/costs/${reminderOnlyCostId}/payment-schedules`,
      null,
      owner.token,
    );
    const backStatus = (id) => backReminders.body?.find?.((item) => item.id === id)?.status;
    check(
      'reversing the payment that settled the agreement brings its reminders back',
      backReminders.status === 200 &&
        backStatus(reminderA.body?.id) === 'PENDING' &&
        backStatus(reminderB.body?.id) === 'PENDING' &&
        backStatus(reminderDropped.body?.id) === 'CANCELLED',
    );
    const cancelReminderOnlyCost = await request(
      'POST',
      `/api/v1/costs/${reminderOnlyCostId}/cancel`,
      {},
      owner.token,
    );
    check('reminder-only smoke cost can be cancelled after reversal', cancelReminderOnlyCost.status === 201 && cancelReminderOnlyCost.body?.status === 'CANCELLED');

    // RA-BE-53: a straight payment leaves less than a reminder's amount. The
    // reminder read its whole amount as «the next payment» and paying it was
    // refused as above the remaining; it asks for, and pays, what is left.
    {
      const partly = await request(
        'POST',
        `/api/v1/wedding-plans/${planId}/costs`,
        { budgetCategoryId: categoryId, title: 'Reminder above what is left', totalAmount: '1000' },
        owner.token,
      );
      const partlyId = partly.body?.id;
      const reminder = await request(
        'POST',
        `/api/v1/costs/${partlyId}/payment-schedules`,
        { amount: '500', dueDate: dateOffsetIso(3) },
        owner.token,
      );
      const straight = await request(
        'POST',
        `/api/v1/costs/${partlyId}/payments`,
        { amount: '800', paidAt: dateOffsetIso(0) },
        owner.token,
      );
      check(
        'a reminder and a straight payment leave 200 owed',
        partly.status === 201 && reminder.status === 201 && straight.status === 201,
      );
      const listed = await request('GET', `/api/v1/costs/${partlyId}/payment-schedules`, null, owner.token);
      const listedReminder = listed.body?.find?.((item) => item.id === reminder.body?.id);
      check(
        'the reminder keeps its own amount and asks for what is left',
        listedReminder?.amount === '500' && listedReminder?.amountDue === '200',
      );
      const due = await request('GET', `/api/v1/wedding-plans/${planId}/payment-schedules/due`, null, owner.token);
      check(
        'the due list asks for what is left',
        due.body?.find?.((item) => item.id === reminder.body?.id)?.amountDue === '200',
      );
      // A second reminder of the same agreement also asks for up to 200; each
      // carries what the agreement owes, so the two together count 200, not
      // 400, on the phone's «الدفعات» total.
      const second = await request(
        'POST',
        `/api/v1/costs/${partlyId}/payment-schedules`,
        { amount: '150', dueDate: dateOffsetIso(5) },
        owner.token,
      );
      const dueBoth = await request('GET', `/api/v1/wedding-plans/${planId}/payment-schedules/due`, null, owner.token);
      const ofAgreement = (dueBoth.body ?? []).filter?.((item) => item.costId === partlyId) ?? [];
      check(
        'each reminder of one agreement carries what the agreement still owes',
        second.status === 201 && ofAgreement.length === 2
          && ofAgreement.every((item) => item.costRemainingAmount === '200'),
      );
      await request('DELETE', `/api/v1/payment-schedules/${second.body?.id}`, null, owner.token);
      // RA-BE-108: «الإيصالات» asks for every paid agreement's receipts at
      // once, and each request held its connection while waiting for a
      // second; on the live server's pool of 3 they all got 500 after 10 s.
      const receipts = await Promise.all(
        Array.from({ length: 9 }, () =>
          request('GET', `/api/v1/costs/${partlyId}/receipts`, null, owner.token),
        ),
      );
      check('nine receipt lists at once all open', receipts.every((res) => res.status === 200));
      const paid = await request(
        'POST',
        `/api/v1/payment-schedules/${reminder.body?.id}/pay`,
        { paidAt: dateOffsetIso(0) },
        owner.token,
      );
      check(
        'paying the reminder records what was left and settles the agreement',
        paid.status === 201 && paid.body?.payment?.amount === '200' && paid.body?.schedule?.status === 'PAID',
      );
      const settled = await request('GET', `/api/v1/costs/${partlyId}`, null, owner.token);
      check('the agreement is paid in full', settled.body?.status === 'PAID' && settled.body?.remainingAmount === '0');
      for (const payment of [paid.body?.payment?.id, straight.body?.id]) {
        await request('POST', `/api/v1/cost-payments/${payment}/reverse`, { reason: 'RA-BE-53 smoke cleanup' }, owner.token);
      }
      await request('POST', `/api/v1/costs/${partlyId}/cancel`, {}, owner.token);
    }

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
    check('paying a schedule creates one canonical payment', payment.status === 201 && payment.body?.payment?.entryType === 'PAYMENT' && payment.body?.payment?.paymentScheduleId === scheduleId);
    check('paying a schedule returns its paid schedule', payment.body?.schedule?.id === scheduleId && payment.body?.schedule?.status === 'PAID');
    const paymentId = payment.body?.payment?.id;
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

    // RA-BE-42: the member joins by accepting an invite (P5).
    const addViewer = await inviteAndAccept(request, {
      planId,
      inviterToken: owner.token,
      member: viewer,
      access: { role: 'VIEWER' },
    });
    check('owner adds a member without money permission', addViewer.status === 201);

    const hiddenSummary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      viewer.token,
    );
    check('member without money permission cannot discover the summary', hiddenSummary.status === 404);

    // RA-BE-40: a read stays 404 (money is not shown to this member), and a
    // write is refused 403 SECTION_PERMISSION_MISSING with its reason: the
    // writes expected 404, «the plan was not found», told a member their
    // plan was gone.
    for (const [label, method, path, body, refusal] of [
      ['cost detail', 'GET', `/api/v1/costs/${costId}`, null, '404'],
      ['payment detail', 'GET', `/api/v1/cost-payments/${paymentId}`, null, '404'],
      ['schedule detail', 'GET', `/api/v1/payment-schedules/${scheduleId}`, null, '404'],
      ['cost payment write', 'POST', `/api/v1/costs/${costId}/payments`, { amount: '1' }, '403:SECTION_PERMISSION_MISSING'],
      ['schedule payment write', 'POST', `/api/v1/payment-schedules/${scheduleId}/pay`, {}, '403:SECTION_PERMISSION_MISSING'],
      ['payment reversal write', 'POST', `/api/v1/cost-payments/${paymentId}/reverse`, { reason: 'Denied smoke' }, '403:SECTION_PERMISSION_MISSING'],
    ]) {
      const denied = await request(method, path, body, viewer.token);
      const answer = refusal === '404' ? `${denied.status}` : `${denied.status}:${denied.body?.code}`;
      check(`member without money permission cannot access ${label}`, answer === refusal);
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

    // R4: a task waits on its item or its payment, and ends and returns with it.
    const linkItem = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Task link item',
    }, owner.token);
    check('task link item is created', linkItem.status === 201);
    const refusedLink = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Linked elsewhere',
      linkedBudgetCategoryId: 'not-this-plan',
    }, owner.token);
    check('a task cannot link outside its plan', refusedLink.status === 400 && refusedLink.body?.code === 'TASK_LINK_NOT_IN_PLAN');
    const itemTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Book the item',
      linkedBudgetCategoryId: linkItem.body?.id,
    }, owner.token);
    check('a task waits on an item', itemTask.status === 201 && itemTask.body?.linkedBudgetCategoryId === linkItem.body?.id && itemTask.body?.status === 'TODO');
    const outside = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: linkItem.body?.id,
      title: 'Outside agreement',
      totalAmount: '50',
      partyName: 'Outside party',
    }, owner.token);
    check('an outside agreement books the item', outside.status === 201);
    const closedByItem = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('booking the item finishes its task', closedByItem.body?.status === 'DONE' && closedByItem.body?.autoClosedAt !== null);
    await request('POST', `/api/v1/costs/${outside.body?.id}/cancel`, {}, owner.token);
    const reopenedByItem = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('cancelling the agreement brings the task back', reopenedByItem.body?.status === 'TODO' && reopenedByItem.body?.autoClosedAt === null);

    // RA-BE-24: deleting an agreement did neither: the item read booked, so
    // «احجز القاعة» stayed done with nothing booked, and a task kept waiting
    // on a payment reminder that no longer existed. It now does as cancelling.
    const bookedAgain = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: linkItem.body?.id,
      title: 'Outside agreement again',
      totalAmount: '50',
      partyName: 'Outside party',
    }, owner.token);
    const closedAgain = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('booking the item again finishes its task again', bookedAgain.status === 201 && closedAgain.body?.status === 'DONE');

    // RA-BE-68 (D71): the person reopens the finished task by hand; editing
    // the agreement that booked the item closed it again on the next write.
    const reopenedOnPurpose = await request('PATCH', `/api/v1/tasks/${itemTask.body?.id}`, { status: 'TODO' }, owner.token);
    check('the person reopens the booked item\'s task', reopenedOnPurpose.status === 200 && reopenedOnPurpose.body?.status === 'TODO');
    const agreementEdited = await request('PATCH', `/api/v1/costs/${bookedAgain.body?.id}`, { note: 'Hall note' }, owner.token);
    const keptOpen = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('editing the agreement keeps the task the person reopened',
      agreementEdited.status === 200 && keptOpen.body?.status === 'TODO');
    const reminderOfDeleted = await request('POST', `/api/v1/costs/${bookedAgain.body?.id}/payment-schedules`, {
      amount: '20',
      dueDate: dateOffsetIso(5),
    }, owner.token);
    const reminderTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Pay the outside party',
      linkedScheduleId: reminderOfDeleted.body?.id,
    }, owner.token);
    const deletedAgreement = await request('DELETE', `/api/v1/costs/${bookedAgain.body?.id}`, null, owner.token);
    check('the agreement without payments is deleted', deletedAgreement.status === 200);
    const reopenedByDelete = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('deleting the agreement brings the item\'s task back',
      reopenedByDelete.body?.status === 'TODO' && reopenedByDelete.body?.autoClosedAt === null);
    const unlinkedByDelete = await request('GET', `/api/v1/tasks/${reminderTask.body?.id}`, null, owner.token);
    check('and its reminder\'s task waits on nothing gone',
      reminderTask.status === 201 && unlinkedByDelete.status === 200 && unlinkedByDelete.body?.linkedScheduleId === null);
    // That booking is gone, so the person's «no» went with it: the next one
    // finishes the task as before.
    const nextBooking = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: linkItem.body?.id,
      title: 'Outside agreement, third',
      totalAmount: '50',
      partyName: 'Outside party',
    }, owner.token);
    const closedByNext = await request('GET', `/api/v1/tasks/${itemTask.body?.id}`, null, owner.token);
    check('the next booking finishes the task the person had reopened',
      nextBooking.status === 201 && closedByNext.body?.status === 'DONE' && closedByNext.body?.autoClosedAt !== null);
    await request('POST', `/api/v1/costs/${nextBooking.body?.id}/cancel`, {}, owner.token);

    const linkedCost = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: linkItem.body?.id,
      title: 'Paid agreement',
      totalAmount: '100',
    }, owner.token);
    const linkedSchedule = await request('POST', `/api/v1/costs/${linkedCost.body?.id}/payment-schedules`, {
      amount: '40',
      dueDate: dateOffsetIso(3),
    }, owner.token);
    const paymentTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Pay the deposit',
      linkedScheduleId: linkedSchedule.body?.id,
    }, owner.token);
    check('a task waits on a payment and keeps its agreement', paymentTask.status === 201 && paymentTask.body?.linkedCostId === linkedCost.body?.id);
    const paidLink = await request('POST', `/api/v1/payment-schedules/${linkedSchedule.body?.id}/pay`, {
      paidAt: dateOffsetIso(0),
    }, owner.token);
    const closedByPayment = await request('GET', `/api/v1/tasks/${paymentTask.body?.id}`, null, owner.token);
    check('paying finishes the task', closedByPayment.body?.status === 'DONE');
    await request('POST', `/api/v1/cost-payments/${paidLink.body?.payment?.id}/reverse`, {
      reason: 'Task link smoke',
    }, owner.token);
    const reopenedByPayment = await request('GET', `/api/v1/tasks/${paymentTask.body?.id}`, null, owner.token);
    check('reversing the payment brings the task back', reopenedByPayment.body?.status === 'TODO');
    const reopenByHand = await request('PATCH', `/api/v1/tasks/${paymentTask.body?.id}`, { status: 'DONE' }, owner.token);
    check('a task closed by hand is not the link\'s to reopen', reopenByHand.body?.status === 'DONE' && reopenByHand.body?.autoClosedAt === null);


    // ---- The money tab (D103-D109), on its own plan --------------------
    const tab = await request('POST', '/api/v1/wedding-plans', { title: 'Money tab plan', city: 'Sanaa' }, owner.token);
    const tabId = tab.body?.id;
    if (!tabId) throw new Error(`money tab plan setup failed with HTTP ${tab.status}`);
    const ids = { hall: randomUUID(), food: randomUUID(), dress: randomUUID(), photo: randomUUID(), car: randomUUID() };
    // D109: estimates are free: they pass the 5,000 budget (6,400) with no
    // agreement yet, and need no allocation; the dress has an allocation only.
    const tabBudget = await request('PUT', `/api/v1/wedding-plans/${tabId}/money-budget`, {
      totalBudget: '5000',
      currency: 'YER',
      categories: [
        { clientId: ids.hall, name: 'Hall', estimatedAmount: '2000' },
        { clientId: ids.food, name: 'Food', estimatedAmount: '1600' },
        { clientId: ids.dress, name: 'Dress', allocatedAmount: '300' },
        { clientId: ids.photo, name: 'Photo', estimatedAmount: '2500' },
        { clientId: ids.car, name: 'Car' },
      ],
    }, owner.token);
    const cat = (key) => tabBudget.body?.idMap?.[ids[key]];
    check('D109: estimates are saved apart from allocations, and may pass the budget',
      tabBudget.status === 200
        && tabBudget.body?.categories?.find((item) => item.id === cat('hall'))?.estimatedAmount === '2000'
        && tabBudget.body?.categories?.find((item) => item.id === cat('dress'))?.allocatedAmount === '300');
    let tabSummary = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    check('D105: the early warning is the expected cost, before any agreement',
      tabSummary.body?.expected?.wedding?.expected === '6400'
        && tabSummary.body?.expected?.budgetLeft === '-1400'
        && tabSummary.body?.warnings?.some((warning) => warning.type === 'BUDGET_EXCEEDED' && warning.amount === '1400'));
    check('D109: an item with only an allocation is estimated by it; one with neither is unknown',
      tabSummary.body?.categories?.find((item) => item.categoryId === cat('dress'))?.estimateSource === 'ALLOCATION'
        && tabSummary.body?.expected?.wedding?.unknownCount === 1);
    // D93: a phone that does not know estimates replaces the budget and keeps them.
    const oldPhone = await request('PUT', `/api/v1/wedding-plans/${tabId}/money-budget`, {
      totalBudget: '5000',
      currency: 'YER',
      categories: ['hall', 'food', 'dress', 'photo', 'car'].map((key) => ({
        id: cat(key),
        name: key[0].toUpperCase() + key.slice(1),
        ...(key === 'dress' ? { allocatedAmount: '300' } : {}),
      })),
    }, owner.token);
    check('D109: a budget saved by a phone that sends no estimate keeps the estimates',
      oldPhone.status === 200
        && oldPhone.body?.categories?.find((item) => item.id === cat('food'))?.estimatedAmount === '1600');

    // D105: an agreement for a part keeps the rest of its item's estimate.
    const food = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('food'), title: 'Lunch', totalAmount: '700', estimateCover: 'PART', estimatePart: '600',
    }, owner.token);
    check('D105: a part agreement is saved with what it settles',
      food.status === 201 && food.body?.estimateCover === 'PART' && food.body?.estimatePart === '600' && food.body?.entryKind === 'AGREEMENT');
    // D107: an expense is paid in full the day it is recorded.
    const wrongExpense = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('dress'), title: 'Dress', totalAmount: '150', entryKind: 'EXPENSE', initialPaymentAmount: '100',
    }, owner.token);
    check('D107: an expense paid in part is refused, in Arabic', wrongExpense.status === 400 && wrongExpense.body?.code === 'FINANCE_EXPENSE_PAID_IN_FULL');
    const dress = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('dress'), title: 'Dress', totalAmount: '150', entryKind: 'EXPENSE',
    }, owner.token);
    check('D107: an expense is paid in full and settles a part of its item at its value',
      dress.status === 201 && dress.body?.entryKind === 'EXPENSE' && dress.body?.status === 'PAID'
        && dress.body?.paidAmount === '150' && dress.body?.estimateCover === 'PART' && dress.body?.estimatePart === null);
    const lockedExpense = await request('PATCH', `/api/v1/costs/${dress.body?.id}`, { totalAmount: '200' }, owner.token);
    check('D107: an expense\'s amount is its payment', lockedExpense.status === 400 && lockedExpense.body?.code === 'FINANCE_EXPENSE_AMOUNT_LOCKED');
    const hall = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('hall'), title: 'Hall', totalAmount: '1800',
    }, owner.token);
    const photo = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('photo'), title: 'Photo', totalAmount: '900', payer: 'FAMILY', payerName: 'الوالد',
    }, owner.token);
    tabSummary = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    const tabCat = (key) => tabSummary.body?.categories?.find((item) => item.categoryId === cat(key));
    check('D105: each item is expected at its agreements and the estimate they did not settle',
      tabCat('hall')?.expectedCost === '1800' && tabCat('food')?.expectedCost === '1700'
        && tabCat('dress')?.expectedCost === '300' && tabCat('photo')?.expectedCost === '900'
        && tabSummary.body?.expected?.wedding?.expected === '4700' && tabSummary.body?.expected?.budgetLeft === '300'
        && !tabSummary.body?.warnings?.some((warning) => warning.type === 'BUDGET_EXCEEDED'));

    // D106: a partial payment of a date lowers it, and its reversal gives it back.
    const s1 = await request('POST', `/api/v1/costs/${hall.body?.id}/payment-schedules`, { amount: '1000', dueDate: dateOffsetIso(10) }, owner.token);
    const s2 = await request('POST', `/api/v1/costs/${hall.body?.id}/payment-schedules`, { amount: '800', dueDate: dateOffsetIso(40) }, owner.token);
    const part = await request('POST', `/api/v1/payment-schedules/${s1.body?.id}/pay`, { amount: '300' }, owner.token, randomUUID());
    check('D106: paying less than a date asks lowers the date by it, in one go',
      part.status === 201 && part.body?.payment?.lowersScheduleId === s1.body?.id && part.body?.payment?.paymentScheduleId === null
        && part.body?.schedule?.status === 'PENDING' && part.body?.schedule?.amount === '700');
    tabSummary = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    const dueLine = tabSummary.body?.obligations?.find((line) => line.kind === 'DUE' && line.id === s1.body?.id);
    check('D106: the date says what was paid towards it',
      dueLine?.amount === '700' && dueLine?.scheduledAmount === '1000' && dueLine?.paidTowards === '300');
    const deleteWithPart = await request('DELETE', `/api/v1/payment-schedules/${s1.body?.id}`, null, owner.token);
    check('D106: a date with a partial payment is not deleted', deleteWithPart.status === 409 && deleteWithPart.body?.code === 'FINANCE_SCHEDULE_HAS_PAYMENTS');
    await request('POST', `/api/v1/cost-payments/${part.body?.payment?.id}/reverse`, { reason: 'Partial smoke' }, owner.token);
    const restored = await request('GET', `/api/v1/costs/${hall.body?.id}/payment-schedules`, null, owner.token);
    const restoredS1 = (restored.body?.items ?? restored.body ?? []).find?.((item) => item.id === s1.body?.id);
    check('D106: reversing the partial payment gives the date its amount back', restoredS1?.amount === '1000' && restoredS1?.status === 'PENDING');
    // D106: more than the date asks pays it, and the rest goes to the agreement.
    const over = await request('POST', `/api/v1/payment-schedules/${s1.body?.id}/pay`, { amount: '1200' }, owner.token, randomUUID());
    check('D106: paying more than a date asks pays the date and records the rest',
      over.status === 201 && over.body?.schedule?.status === 'PAID' && over.body?.payment?.amount === '1000'
        && over.body?.extraPayment?.amount === '200' && over.body?.extraPayment?.paymentScheduleId === null);
    const tooMuch = await request('POST', `/api/v1/payment-schedules/${s2.body?.id}/pay`, { amount: '700' }, owner.token, randomUUID());
    check('D106: never more than what is left on the agreement', tooMuch.status === 400 && tooMuch.body?.code === 'FINANCE_PAYMENT_EXCEEDS_REMAINING');

    // RA-BE-109: the second date asks 600 of its 800 now; moving its day was refused.
    const s2Due = new Date(s2.body?.dueDate).toISOString();
    const moved = await request('PATCH', `/api/v1/payment-schedules/${s2.body?.id}`, { dueDate: dateOffsetIso(45) }, owner.token);
    check('RA-BE-109: a date that asks less than its amount can be moved, and keeps its first day',
      moved.status === 200 && new Date(moved.body?.rescheduledFrom).toISOString() === s2Due && moved.body?.amountDue === '600');
    const reminded = await request('PATCH', `/api/v1/payment-schedules/${s2.body?.id}`, { remindAt: dateOffsetIso(44) }, owner.token);
    check('D106: a reminder day of its own moves only the reminder',
      reminded.status === 200 && reminded.body?.remindAt !== null && new Date(reminded.body?.dueDate).toISOString() === new Date(moved.body?.dueDate).toISOString());
    const afterDue = await request('PATCH', `/api/v1/payment-schedules/${s2.body?.id}`, { remindAt: dateOffsetIso(50) }, owner.token);
    const beforeToday = await request('PATCH', `/api/v1/payment-schedules/${s2.body?.id}`, { remindAt: dateOffsetIso(-2) }, owner.token);
    check('D106: the reminder day is between today and the due day',
      afterDue.status === 400 && afterDue.body?.code === 'FINANCE_REMINDER_DAY_OUT_OF_RANGE' && beforeToday.status === 400);
    const back = await request('PATCH', `/api/v1/payment-schedules/${s2.body?.id}`, { dueDate: s2Due }, owner.token);
    check('D106: moving back to its first day is not a reschedule, and the reminder goes back to the default',
      back.status === 200 && back.body?.rescheduledFrom === null && back.body?.remindAt === null);

    // D104, D108: the owner's money, and the family person by person.
    await request('POST', `/api/v1/wedding-plans/${tabId}/funding-sources`, { kind: 'SAVINGS', sourceName: 'My savings', amount: '1000' }, owner.token);
    const father = await request('POST', `/api/v1/wedding-plans/${tabId}/funding-sources`, {
      kind: 'FAMILY_SUPPORT', sourceName: 'Father support', contributorName: 'الوالد', amount: '500',
    }, owner.token);
    check('D108: a source names who gave it', father.status === 201 && father.body?.contributorName === 'الوالد');
    await request('POST', `/api/v1/wedding-plans/${tabId}/funding-sources`, {
      kind: 'FAMILY_SUPPORT', sourceName: 'Father promise', contributorName: '  الوالد ', amount: '800', status: 'PLEDGED', expectedAt: dateOffsetIso(20),
    }, owner.token);
    const loan = await request('POST', `/api/v1/wedding-plans/${tabId}/funding-sources`, { kind: 'LOAN', sourceName: 'Uncle', amount: '400' }, owner.token);
    const r1 = await request('POST', `/api/v1/funding-sources/${loan.body?.id}/repayments`, { amount: '100', dueDate: dateOffsetIso(5) }, owner.token);
    await request('POST', `/api/v1/funding-sources/${loan.body?.id}/repayments`, { amount: '200', dueDate: dateOffsetIso(60) }, owner.token);
    await request('PATCH', `/api/v1/loan-repayments/${r1.body?.repayments?.[0]?.id}`, { status: 'PAID' }, owner.token);
    tabSummary = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    // Received 1,900; his money paid 1,350 (the hall's 1,200, the dress 150);
    // he repaid 100 of the loan.
    check('D104: «معك» is received less his payments less his loan repayments',
      tabSummary.body?.funding?.availableCash === '450' && tabSummary.body?.funding?.loanRepaid === '100');
    check('D102: what is left is said on whom',
      tabSummary.body?.outstanding?.owner === '1300' && tabSummary.body?.outstanding?.others === '900');
    const coverage = tabSummary.body?.coverage;
    // On him: the hall's 600 (day 40), the loan's 200 (day 60), the lunch's
    // 700 (no day), the loan's 100 with no plan: 1,600. The father's 800 comes
    // on day 20. 450 + 800 − 600 − 200 − 700 − 100 = −350.
    check('D103: the coverage walks his money on its days, the promise on its day',
      coverage?.verdict === 'SHORT' && coverage?.cash === '450' && coverage?.total === '1600'
        && coverage?.pledgesCounted?.length === 1 && coverage?.withPledges?.deepest?.amount === '350'
        && coverage?.steps?.[0]?.kind === 'PLEDGE' && tabSummary.body?.funding?.shortfall === '350');
    check('D103: the photographer the father pays is not on him',
      !coverage?.steps?.some((step) => step.title === 'Photo'));
    check('D108: the father is one person: gave, promised, still owes',
      tabSummary.body?.family?.length === 1 && tabSummary.body.family[0].name === 'الوالد'
        && tabSummary.body.family[0].gave === '500' && tabSummary.body.family[0].promised === '800' && tabSummary.body.family[0].left === '900');
    // By month: the hall's 600 only (the loan's 200 is not a wedding due).
    // Undated: the lunch's 700 (his) and the photographer's 900 (the father's).
    check('D102: the wedding dues by month leave the loan out',
      (tabSummary.body?.duesByMonth?.months ?? []).reduce((sum, month) => sum + Number(month.amount), 0) === 600
        && tabSummary.body?.duesByMonth?.undated?.amount === '1600'
        && tabSummary.body?.duesByMonth?.undated?.ownerAmount === '700');
    check('D102: the loan\'s repayments are in the list, apart from the wedding dues',
      tabSummary.body?.obligations?.some((line) => line.kind === 'LOAN_REPAYMENT' && line.amount === '200')
        && tabSummary.body?.obligations?.some((line) => line.kind === 'LOAN_UNPLANNED' && line.amount === '100'));
    // D108: a gift recorded as «الوالدة» with no contributor named is hers,
    // the way the app asks «من مين؟» (sourcePerson).
    await request('POST', `/api/v1/wedding-plans/${tabId}/funding-sources`, {
      kind: 'GIFT', sourceName: ' الوالدة ', amount: '50',
    }, owner.token);
    const withMother = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    const mother = withMother.body?.family?.find((person) => person.name === 'الوالدة');
    check('D108: family support and gifts are from the one they were recorded as',
      mother?.gave === '50' && withMother.body?.family?.length === 2
        && withMother.body.family.some((person) => person.name === 'الوالد'));
    // The app sends a date's own amount with every edit («اتفقتوا على موعد
    // ثاني؟», «التذكير»); the same amount is not a change. A date with a
    // payment on it, paid then reversed or partly paid (D106), keeps its
    // amount, as it is not deleted.
    const rehearsal = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('hall'), title: 'Hall rehearsal', totalAmount: '500',
    }, owner.token);
    const once = await request('POST', `/api/v1/costs/${rehearsal.body?.id}/payment-schedules`, { amount: '500', dueDate: dateOffsetIso(15) }, owner.token);
    const paidOnce = await request('POST', `/api/v1/payment-schedules/${once.body?.id}/pay`, {}, owner.token, randomUUID());
    await request('POST', `/api/v1/cost-payments/${paidOnce.body?.payment?.id}/reverse`, { reason: 'Review smoke' }, owner.token);
    const appMove = await request('PATCH', `/api/v1/payment-schedules/${once.body?.id}`, { amount: '500', dueDate: dateOffsetIso(20), note: null }, owner.token);
    check('a date paid then reversed moves the way the app sends it, its own amount with it',
      paidOnce.status === 201 && appMove.status === 200 && appMove.body?.rescheduledFrom !== null);
    const appRemind = await request('PATCH', `/api/v1/payment-schedules/${once.body?.id}`, {
      amount: '500', dueDate: dateOffsetIso(20), note: null, remindAt: dateOffsetIso(18),
    }, owner.token);
    check('a date paid then reversed takes a reminder day the way the app sends it',
      appRemind.status === 200 && appRemind.body?.remindAt !== null);
    const onceAmount = await request('PATCH', `/api/v1/payment-schedules/${once.body?.id}`, { amount: '400' }, owner.token);
    check('a date paid then reversed keeps its amount',
      onceAmount.status === 409 && onceAmount.body?.code === 'FINANCE_SCHEDULE_HAS_PAYMENTS');
    const extra = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('hall'), title: 'Hall extra', totalAmount: '500',
    }, owner.token);
    const partDate = await request('POST', `/api/v1/costs/${extra.body?.id}/payment-schedules`, { amount: '500', dueDate: dateOffsetIso(15) }, owner.token);
    const partPaid = await request('POST', `/api/v1/payment-schedules/${partDate.body?.id}/pay`, { amount: '100' }, owner.token, randomUUID());
    const partAmount = await request('PATCH', `/api/v1/payment-schedules/${partDate.body?.id}`, { amount: '450' }, owner.token);
    check('D106: a partly paid date keeps its amount, so its reversal cannot ask more than agreed',
      partPaid.status === 201 && partAmount.status === 409 && partAmount.body?.code === 'FINANCE_SCHEDULE_HAS_PAYMENTS');
    const partMove = await request('PATCH', `/api/v1/payment-schedules/${partDate.body?.id}`, { amount: '400', dueDate: dateOffsetIso(25), note: null }, owner.token);
    await request('POST', `/api/v1/cost-payments/${partPaid.body?.payment?.id}/reverse`, { reason: 'Review smoke' }, owner.token);
    const extraDates = await request('GET', `/api/v1/costs/${extra.body?.id}/payment-schedules`, null, owner.token);
    const partBack = (extraDates.body?.items ?? extraDates.body ?? []).find?.((item) => item.id === partDate.body?.id);
    check('D106: a partly paid date moves the way the app sends it, and its reversal gives back what was agreed',
      partMove.status === 200 && partBack?.amount === '500' && partBack?.status === 'PENDING');
    // D105: the cover chosen again with no part is the agreement's own
    // amount, as the phone's copy writes it; a part alone keeps the cover.
    const album = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: cat('photo'), title: 'Album', totalAmount: '500', estimateCover: 'PART', estimatePart: '300',
    }, owner.token);
    const albumCleared = await request('PATCH', `/api/v1/costs/${album.body?.id}`, { totalAmount: '800', estimateCover: 'PART' }, owner.token);
    const albumPart = await request('PATCH', `/api/v1/costs/${album.body?.id}`, { estimatePart: '200' }, owner.token);
    check('D105: a part chosen again with no amount is the agreement\'s own amount; a part alone keeps the choice',
      album.body?.estimatePart === '300' && albumCleared.status === 200 && albumCleared.body?.estimatePart === null
        && albumPart.status === 200 && albumPart.body?.estimateCover === 'PART' && albumPart.body?.estimatePart === '200');
    // RA-BE-120: a part left empty follows the amount when it is corrected:
    // written as the amount, it stayed at the old figure and the item's
    // expected cost drifted.
    const veilItem = await request('POST', `/api/v1/wedding-plans/${tabId}/budget-categories`, { name: 'Veil', estimatedAmount: '1000' }, owner.token);
    const veil = await request('POST', `/api/v1/wedding-plans/${tabId}/costs`, {
      budgetCategoryId: veilItem.body?.id, title: 'Veil', totalAmount: '300', estimateCover: 'PART',
    }, owner.token);
    const veilFixed = await request('PATCH', `/api/v1/costs/${veil.body?.id}`, { totalAmount: '500' }, owner.token);
    const veilSummary = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, owner.token);
    const veilRow = veilSummary.body?.categories?.find((row) => row.categoryId === veilItem.body?.id);
    check('RA-BE-120: a part left empty follows the corrected amount',
      veil.status === 201 && veil.body?.estimatePart === null && veilFixed.status === 200
        && veilFixed.body?.estimatePart === null && String(veilRow?.estimateLeft) === '500');
    const viewerTab = await request('GET', `/api/v1/wedding-plans/${tabId}/money-summary`, null, viewer.token);
    check('the money tab is the plan\'s: a stranger reads nothing', viewerTab.status === 403 || viewerTab.status === 404);

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
