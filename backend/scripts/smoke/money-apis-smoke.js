#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Money APIs Smoke Test
 * Covers /api/v1 money aliases, item read endpoints, installment pay, summary,
 * auth blocking, and finance-permission blocking.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+9674${suffix}`;
const VIEWER_PHONE = `+9678${suffix}`;
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
  date.setHours(9, 0, 0, 0);
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

async function run() {
  console.log('\nMoney APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Viewer phone: ${VIEWER_PHONE}\n`);

  const owner = await registerUser('Money Owner', OWNER_PHONE);
  const viewer = await registerUser('Money Viewer', VIEWER_PHONE);

  let planId = null;
  let categoryId = null;
  let expenseId = null;
  let debtId = null;
  let installmentId = null;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Money APIs Plan',
      city: 'Sanaa',
      estimatedBudget: '1200',
    }, owner.token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Hall',
      targetAmount: '1000',
    }, owner.token);
    check('POST /api/v1 budget category - HTTP 201', res.status === 201);
    check('budget category has id', typeof res.body?.id === 'string');
    categoryId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/budget-categories`, null, owner.token);
    check('GET /api/v1 budget categories - HTTP 200', res.status === 200);
    check('budget categories include created category', Array.isArray(res.body) && res.body.some((category) => category.id === categoryId));
  }

  {
    const res = await request('PATCH', `/api/v1/budget-categories/${categoryId}`, {
      name: 'Updated Hall',
      targetAmount: '1100',
    }, owner.token);
    check('PATCH /api/v1/budget-categories/:id - HTTP 200', res.status === 200);
    check('budget category updated', res.body?.name === 'Updated Hall');
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/expenses`, {
      title: 'Paid hall expense',
      budgetCategoryId: categoryId,
      amount: '300',
      status: 'PAID',
    }, owner.token);
    check('POST /api/v1 expense - HTTP 201', res.status === 201);
    check('expense has id', typeof res.body?.id === 'string');
    expenseId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/expenses/${expenseId}`, null, owner.token);
    check('GET /api/v1/expenses/:id - HTTP 200', res.status === 200);
    check('expense get-by-id matches', res.body?.id === expenseId);
  }

  {
    const res = await request('PATCH', `/api/v1/expenses/${expenseId}`, {
      amount: '350',
      note: 'Updated by money smoke',
    }, owner.token);
    check('PATCH /api/v1/expenses/:id - HTTP 200', res.status === 200);
    check('expense amount updated', res.body?.amount === '350');
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/expenses`, {
      title: 'Invalid negative expense',
      amount: '-1',
    }, owner.token);
    check('negative expense amount returns 400', res.status === 400);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/debts`, {
      creditorName: 'Family Lender',
      creditorPhone: '+967711111111',
      title: 'Money smoke debt',
      totalAmount: '500',
      paidAmount: '100',
      dueDate: dateOffsetIso(10),
      status: 'PARTIALLY_PAID',
    }, owner.token);
    check('POST /api/v1 debt - HTTP 201', res.status === 201);
    check('debt has id', typeof res.body?.id === 'string');
    debtId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/debts/${debtId}`, null, owner.token);
    check('GET /api/v1/debts/:id - HTTP 200', res.status === 200);
    check('debt get-by-id matches', res.body?.id === debtId);
  }

  {
    const res = await request('PATCH', `/api/v1/debts/${debtId}`, {
      title: 'Updated money smoke debt',
    }, owner.token);
    check('PATCH /api/v1/debts/:id - HTTP 200', res.status === 200);
    check('debt title updated', res.body?.title === 'Updated money smoke debt');
  }

  {
    const res = await request('POST', `/api/v1/debts/${debtId}/installments`, {
      amount: '200',
      dueDate: dateOffsetIso(0),
      status: 'PENDING',
    }, owner.token);
    check('POST /api/v1 installments - HTTP 201', res.status === 201);
    check('installment has id', typeof res.body?.id === 'string');
    installmentId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/debts/${debtId}/installments`, null, owner.token);
    check('GET /api/v1 debt installments - HTTP 200', res.status === 200);
    check('installments include created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
  }

  {
    const res = await request('PATCH', `/api/v1/installments/${installmentId}`, {
      note: 'Updated installment note',
    }, owner.token);
    check('PATCH /api/v1/installments/:id - HTTP 200', res.status === 200);
    check('installment note updated', res.body?.note === 'Updated installment note');
  }

  {
    const res = await request('PATCH', `/api/v1/installments/${installmentId}/pay`, null, owner.token);
    check('PATCH /api/v1/installments/:id/pay - HTTP 200', res.status === 200);
    check('paid installment status is PAID', res.body?.status === 'PAID');
    check('paid installment has paidAt', typeof res.body?.paidAt === 'string');
  }

  {
    const res = await request('GET', `/api/v1/debts/${debtId}`, null, owner.token);
    check('pay installment updates debt paidAmount', Number(res.body?.paidAmount) === 300);
    check('pay installment keeps debt partially paid', res.body?.status === 'PARTIALLY_PAID');
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, owner.token);
    check('GET /api/v1 money-summary - HTTP 200', res.status === 200);
    check('money summary budgetTotal is real', res.body?.budgetTotal === '1200.00');
    check('money summary totalBudget alias is stable', res.body?.totalBudget === '1200.00');
    check('money summary category target is real', res.body?.categoryTargetTotal === '1100.00');
    check('money summary spentTotal is real', res.body?.spentTotal === '350.00');
    check('money summary totalSpent alias is stable', res.body?.totalSpent === '350.00');
    check('money summary remainingBudget is real', res.body?.remainingBudget === '850.00');
    check('money summary debtTotal is real', res.body?.debtTotal === '500.00');
    check('money summary totalDebts alias is stable', res.body?.totalDebts === '500.00');
    check('money summary paidDebtTotal is real', res.body?.paidDebtTotal === '300.00');
    check('money summary unpaidDebtTotal is real', res.body?.unpaidDebtTotal === '200.00');
    check('money summary debtRemaining alias is stable', res.body?.debtRemaining === '200.00');
    check('money summary paid installments are counted', res.body?.paidInstallmentsCount === 1);
    check('money summary remaining installments are counted', res.body?.remainingInstallmentsCount === 0);
    check('money summary next installment is explicit when absent', res.body?.nextInstallment === null);
    check('money summary includes category summaries', Array.isArray(res.body?.categorySummaries) && res.body.categorySummaries[0]?.allocated === '1100.00');
    check('money summary financialWarnings is stable array', Array.isArray(res.body?.financialWarnings));
    check('money summary due count reflects paid installment', res.body?.dueInstallmentsCount === 0);
    check('money summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${planId}/shared-members`, {
      userId: viewer.userId,
      role: 'VIEWER',
    }, owner.token);
    check('owner adds non-finance viewer - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, viewer.token);
    check('non-finance viewer cannot read money-summary', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/expenses`);
    check('expenses without token returns 401', res.status === 401);
  }

  {
    const res = await request('DELETE', `/api/v1/expenses/${expenseId}`, null, owner.token);
    check('DELETE /api/v1/expenses/:id - HTTP 200', res.status === 200);
  }

  {
    const res = await request('DELETE', `/api/v1/installments/${installmentId}`, null, owner.token);
    check('DELETE /api/v1/installments/:id - HTTP 200', res.status === 200);
  }

  {
    const res = await request('DELETE', `/api/v1/debts/${debtId}`, null, owner.token);
    check('DELETE /api/v1/debts/:id - HTTP 200', res.status === 200);
  }

  {
    const res = await request('DELETE', `/api/v1/budget-categories/${categoryId}`, null, owner.token);
    check('DELETE /api/v1/budget-categories/:id - HTTP 200', res.status === 200);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Money APIs smoke error:', err.message);
  process.exit(1);
});
