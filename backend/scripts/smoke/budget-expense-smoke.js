#!/usr/bin/env node
'use strict';

/**
 * Budget + Expense Smoke Test
 * Tests the first financial backend slice without creating future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3127';
const timestamp = Date.now();
const TEST_PHONE = `+9673${timestamp.toString().slice(-7)}`;
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
  console.log('\nBudget + Expense Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let token = null;
  let weddingPlanId = null;
  let categoryId = null;
  let expenseId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'Budget Expense Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    token = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/wedding-plans', {
      title: 'Budget Expense Smoke Plan',
      city: 'Sanaa',
    }, token);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/budget-categories`, {
      name: 'Hall',
      targetAmount: '1000000.00',
    }, token);
    check('POST budget category - HTTP 201', res.status === 201);
    check('created category has id', typeof res.body?.id === 'string');
    check('created category belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created category targetAmount is string', res.body?.targetAmount === '1000000');
    check('budget category does not expose passwordHash', !hasPasswordHash(res.body));
    categoryId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/budget-categories`, null, token);
    check('GET budget categories - HTTP 200', res.status === 200);
    check('budget category list is array', Array.isArray(res.body));
    check('budget category list includes created category', Array.isArray(res.body) && res.body.some((category) => category.id === categoryId));
    check('budget category list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/budget-categories/${categoryId}`, {
      name: 'Updated Hall',
      targetAmount: '1200000.00',
    }, token);
    check('PATCH budget category - HTTP 200', res.status === 200);
    check('updated category name changed', res.body?.name === 'Updated Hall');
    check('updated category belongs to same plan', res.body?.weddingPlanId === weddingPlanId);
    check('updated category does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/expenses`, {
      title: 'Hall Deposit',
      amount: '250000.00',
      budgetCategoryId: categoryId,
      status: 'PAID',
      expenseDate: '2026-12-01T00:00:00.000Z',
      note: 'Smoke expense',
    }, token);
    check('POST expense - HTTP 201', res.status === 201);
    check('created expense has id', typeof res.body?.id === 'string');
    check('created expense belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created expense belongs to category', res.body?.budgetCategoryId === categoryId);
    check('created expense status is PAID', res.body?.status === 'PAID');
    check('created expense amount is string', res.body?.amount === '250000');
    check('expense does not expose passwordHash', !hasPasswordHash(res.body));
    expenseId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/expenses`, null, token);
    check('GET expenses - HTTP 200', res.status === 200);
    check('expense list is array', Array.isArray(res.body));
    check('expense list includes created expense', Array.isArray(res.body) && res.body.some((expense) => expense.id === expenseId));
    check('expense list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/expenses/summary`, null, token);
    check('GET expense summary - HTTP 200', res.status === 200);
    check('summary totalPaid is correct', res.body?.totalPaid === '250000.00');
    check('summary countPaid is correct', res.body?.countPaid === 1);
    check('summary countPlanned is zero', res.body?.countPlanned === 0);
    check('summary countCancelled is zero', res.body?.countCancelled === 0);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/expenses/${expenseId}`, {
      title: 'Updated Hall Expense',
      amount: '300000.00',
      status: 'PLANNED',
      note: 'Updated smoke expense',
    }, token);
    check('PATCH expense - HTTP 200', res.status === 200);
    check('updated expense title changed', res.body?.title === 'Updated Hall Expense');
    check('updated expense amount changed', res.body?.amount === '300000');
    check('updated expense status changed', res.body?.status === 'PLANNED');
    check('updated expense does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/expenses/${expenseId}`, null, token);
    check('DELETE expense - HTTP 200', res.status === 200);
    check('deleted expense id returned', res.body?.id === expenseId);
    check('delete expense response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/budget-categories/${categoryId}`, null, token);
    check('DELETE budget category - HTTP 200', res.status === 200);
    check('deleted category id returned', res.body?.id === categoryId);
    check('delete category response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/expenses`);
    check('GET expenses without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Budget + Expense smoke error:', err.message);
  process.exit(1);
});