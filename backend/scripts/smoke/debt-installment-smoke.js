#!/usr/bin/env node
'use strict';

/**
 * Debt + Installment Smoke Test
 * Tests the debt/installment backend slice without creating future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3127';
const timestamp = Date.now();
const TEST_PHONE = `+9674${timestamp.toString().slice(-7)}`;
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
  console.log('\nDebt + Installment Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let token = null;
  let weddingPlanId = null;
  let debtId = null;
  let installmentId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'Debt Installment Smoke User',
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
      title: 'Debt Installment Smoke Plan',
      city: 'Sanaa',
    }, token);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/debts`, {
      creditorName: 'Wedding Hall Vendor',
      title: 'Hall remaining balance',
      totalAmount: '500000.00',
      paidAmount: '100000.00',
      dueDate: '2026-12-10T00:00:00.000Z',
      status: 'PARTIALLY_PAID',
      note: 'Smoke debt',
    }, token);
    check('POST debt - HTTP 201', res.status === 201);
    check('created debt has id', typeof res.body?.id === 'string');
    check('created debt belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created debt totalAmount is string', res.body?.totalAmount === '500000');
    check('created debt paidAmount is string', res.body?.paidAmount === '100000');
    check('created debt status is PARTIALLY_PAID', res.body?.status === 'PARTIALLY_PAID');
    check('debt does not expose passwordHash', !hasPasswordHash(res.body));
    debtId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`, null, token);
    check('GET debts - HTTP 200', res.status === 200);
    check('debt list is array', Array.isArray(res.body));
    check('debt list includes created debt', Array.isArray(res.body) && res.body.some((debt) => debt.id === debtId));
    check('debt list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts/summary`, null, token);
    check('GET debt summary - HTTP 200', res.status === 200);
    check('summary totalDebt is correct', res.body?.totalDebt === '500000.00');
    check('summary totalPaid is correct', res.body?.totalPaid === '100000.00');
    check('summary remainingDebt is correct', res.body?.remainingDebt === '400000.00');
    check('summary countPartiallyPaid is correct', res.body?.countPartiallyPaid === 1);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/debts/${debtId}`, {
      creditorName: 'Updated Vendor',
      title: 'Updated debt',
      totalAmount: '600000.00',
      paidAmount: '150000.00',
      status: 'OPEN',
      note: 'Updated smoke debt',
    }, token);
    check('PATCH debt - HTTP 200', res.status === 200);
    check('updated debt creditor changed', res.body?.creditorName === 'Updated Vendor');
    check('updated debt title changed', res.body?.title === 'Updated debt');
    check('updated debt totalAmount changed', res.body?.totalAmount === '600000');
    check('updated debt status changed', res.body?.status === 'OPEN');
    check('updated debt does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/debts/${debtId}/installments`, {
      amount: '200000.00',
      dueDate: '2026-12-15T00:00:00.000Z',
      status: 'PENDING',
      note: 'Smoke installment',
    }, token);
    check('POST installment - HTTP 201', res.status === 201);
    check('created installment has id', typeof res.body?.id === 'string');
    check('created installment belongs to debt', res.body?.debtId === debtId);
    check('created installment amount is string', res.body?.amount === '200000');
    check('created installment status is PENDING', res.body?.status === 'PENDING');
    check('installment does not expose passwordHash', !hasPasswordHash(res.body));
    installmentId = res.body?.id;
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`, null, token);
    check('GET installments - HTTP 200', res.status === 200);
    check('installment list is array', Array.isArray(res.body));
    check('installment list includes created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('installment list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/installments/due`, null, token);
    check('GET due installments - HTTP 200', res.status === 200);
    check('due installment list is array', Array.isArray(res.body));
    check('due installment list includes created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('due installment list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/installments/${installmentId}`, {
      amount: '250000.00',
      status: 'PAID',
      paidAt: '2026-12-16T00:00:00.000Z',
      note: 'Updated smoke installment',
    }, token);
    check('PATCH installment - HTTP 200', res.status === 200);
    check('updated installment amount changed', res.body?.amount === '250000');
    check('updated installment status changed', res.body?.status === 'PAID');
    check('updated installment paidAt exists', typeof res.body?.paidAt === 'string');
    check('updated installment does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/installments/${installmentId}`, null, token);
    check('DELETE installment - HTTP 200', res.status === 200);
    check('deleted installment id returned', res.body?.id === installmentId);
    check('delete installment response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/debts/${debtId}`, null, token);
    check('DELETE debt - HTTP 200', res.status === 200);
    check('deleted debt id returned', res.body?.id === debtId);
    check('delete debt response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`);
    check('GET debts without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`);
    check('GET installments without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Debt + Installment smoke error:', err.message);
  process.exit(1);
});
