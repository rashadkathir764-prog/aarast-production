#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Task + Timeline Smoke Test
 * Tests the task/timeline backend slice without creating sharing or future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9675${suffix}`;
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
  console.log('\nTask + Timeline Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let token = null;
  let weddingPlanId = null;
  let taskId = null;
  let debtId = null;
  let installmentId = null;

  {
    const res = await registerVerified(request, {
      name: 'Task Timeline Smoke User',
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
      title: 'Task Timeline Smoke Plan',
      city: 'Sanaa',
      weddingDate: '2026-12-25T00:00:00.000Z',
    }, token);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('created wedding plan has weddingDate', typeof res.body?.weddingDate === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/tasks`, {
      title: 'Confirm wedding hall',
      description: 'Call the hall manager',
      dueDate: '2026-12-05T00:00:00.000Z',
      status: 'TODO',
      priority: 'HIGH',
    }, token);
    check('POST task - HTTP 201', res.status === 201);
    check('created task has id', typeof res.body?.id === 'string');
    check('created task belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created task title matches', res.body?.title === 'Confirm wedding hall');
    check('created task status is TODO', res.body?.status === 'TODO');
    check('created task priority is HIGH', res.body?.priority === 'HIGH');
    check('task does not expose passwordHash', !hasPasswordHash(res.body));
    taskId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/tasks`, null, token);
    check('GET tasks - HTTP 200', res.status === 200);
    check('task list is array', Array.isArray(res.body));
    check('task list includes created task', Array.isArray(res.body) && res.body.some((task) => task.id === taskId));
    check('task list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/tasks/${taskId}`, {
      title: 'Updated hall confirmation',
      description: 'Confirm final date',
      status: 'IN_PROGRESS',
      priority: 'MEDIUM',
    }, token);
    check('PATCH task - HTTP 200', res.status === 200);
    check('updated task title changed', res.body?.title === 'Updated hall confirmation');
    check('updated task status changed', res.body?.status === 'IN_PROGRESS');
    check('updated task priority changed', res.body?.priority === 'MEDIUM');
    check('updated task does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/debts`, {
      creditorName: 'Timeline Vendor',
      title: 'Timeline debt',
      totalAmount: '300000.00',
      paidAmount: '50000.00',
      dueDate: '2026-12-12T00:00:00.000Z',
      status: 'OPEN',
    }, token);
    check('POST debt for timeline - HTTP 201', res.status === 201);
    check('timeline debt has id', typeof res.body?.id === 'string');
    check('timeline debt does not expose passwordHash', !hasPasswordHash(res.body));
    debtId = res.body?.id;
  }

  {
    const res = await request('POST', `/debts/${debtId}/installments`, {
      amount: '100000.00',
      dueDate: '2026-12-15T00:00:00.000Z',
      status: 'PENDING',
    }, token);
    check('POST installment for timeline - HTTP 201', res.status === 201);
    check('timeline installment has id', typeof res.body?.id === 'string');
    check('timeline installment does not expose passwordHash', !hasPasswordHash(res.body));
    installmentId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/timeline`, null, token);
    check('GET timeline - HTTP 200', res.status === 200);
    check('timeline includes weddingDate', typeof res.body?.weddingDate === 'string');
    check('timeline upcomingTasks is array', Array.isArray(res.body?.upcomingTasks));
    check('timeline includes upcoming task', Array.isArray(res.body?.upcomingTasks) && res.body.upcomingTasks.some((task) => task.id === taskId));
    check('timeline dueDebts is array', Array.isArray(res.body?.dueDebts));
    check('timeline includes due debt', Array.isArray(res.body?.dueDebts) && res.body.dueDebts.some((debt) => debt.id === debtId));
    check('timeline dueInstallments is array', Array.isArray(res.body?.dueInstallments));
    check('timeline includes due installment', Array.isArray(res.body?.dueInstallments) && res.body.dueInstallments.some((installment) => installment.id === installmentId));
    check('timeline does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/tasks/${taskId}`, null, token);
    check('DELETE task - HTTP 200', res.status === 200);
    check('deleted task id returned', res.body?.id === taskId);
    check('delete task response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/tasks`);
    check('GET tasks without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/timeline`);
    check('GET timeline without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Task + Timeline smoke error:', err.message);
  process.exit(1);
});
