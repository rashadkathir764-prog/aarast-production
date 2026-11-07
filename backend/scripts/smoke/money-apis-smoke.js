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
