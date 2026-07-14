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
  let costId = null;
  let paymentScheduleId = null;

  {
    const res = await registerVerified(request, {
      name: 'Task Timeline Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /api/v1/auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    token = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Task Timeline Smoke Plan',
      city: 'Sanaa',
      weddingDate: '2026-12-25T00:00:00.000Z',
    }, token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('created wedding plan has weddingDate', typeof res.body?.weddingDate === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, {
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
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, null, token);
    check('GET tasks - HTTP 200', res.status === 200);
    check('task list is array', Array.isArray(res.body));
    check('task list includes created task', Array.isArray(res.body) && res.body.some((task) => task.id === taskId));
    check('task list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}`, {
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
    const category = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, {
      name: 'Timeline costs',
    }, token);
    check('POST timeline category - HTTP 201', category.status === 201);
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/costs`, {
      budgetCategoryId: category.body?.id,
      partyName: 'Timeline Vendor',
      title: 'Timeline wedding cost',
      totalAmount: '300000.00',
      initialPaymentAmount: '50000.00',
      dueDate: '2026-12-12T00:00:00.000Z',
    }, token);
    check('POST cost for timeline - HTTP 201', res.status === 201);
    check('timeline cost has id', typeof res.body?.id === 'string');
    check('timeline cost does not expose passwordHash', !hasPasswordHash(res.body));
    costId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/costs/${costId}/payment-schedules`, {
      amount: '100000.00',
      dueDate: '2026-12-15T00:00:00.000Z',
    }, token);
    check('POST payment schedule for timeline - HTTP 201', res.status === 201);
    check('timeline payment schedule has id', typeof res.body?.id === 'string');
    check('timeline payment schedule does not expose passwordHash', !hasPasswordHash(res.body));
    paymentScheduleId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/timeline`, null, token);
    check('GET timeline - HTTP 200', res.status === 200);
    check('timeline includes weddingDate', typeof res.body?.weddingDate === 'string');
    check('timeline upcomingTasks is array', Array.isArray(res.body?.upcomingTasks));
    check('timeline includes upcoming task', Array.isArray(res.body?.upcomingTasks) && res.body.upcomingTasks.some((task) => task.id === taskId));
    check('timeline paymentSchedules is array', Array.isArray(res.body?.paymentSchedules));
    check('timeline includes payment schedule', Array.isArray(res.body?.paymentSchedules) && res.body.paymentSchedules.some((schedule) => schedule.id === paymentScheduleId && schedule.weddingCostId === costId));
    check('timeline does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/tasks/${taskId}`, null, token);
    check('DELETE task - HTTP 200', res.status === 200);
    check('deleted task id returned', res.body?.id === taskId);
    check('delete task response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/tasks`);
    check('GET tasks without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/timeline`);
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
