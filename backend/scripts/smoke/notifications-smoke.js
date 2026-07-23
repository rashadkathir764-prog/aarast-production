#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3124';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+96773${suffix}`;
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
      res.on('data', (chunk) => {
        data += chunk;
      });
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
  console.log('\nNotifications Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let accessToken = null;
  let planId = null;
  let notificationId = null;

  {
    const res = await registerVerified(request, {
      name: 'Notifications Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /api/v1/auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    accessToken = res.body?.accessToken;
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Notifications Smoke Plan',
      city: 'Sanaa',
      weddingDate: '2026-12-20T00:00:00.000Z',
      estimatedBudget: '1000000',
    }, accessToken);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    const due = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Notifications Smoke Task',
      dueDate: due,
      priority: 'HIGH',
    }, accessToken);
    check('POST /api/v1/wedding-plans/:id/tasks - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', `/api/v1/notifications?weddingPlanId=${planId}`, null, accessToken);
    check('GET /api/v1/notifications - HTTP 200', res.status === 200);
    const notifications = res.body?.items;
    check('notifications response is paginated', Array.isArray(notifications));
    check('notifications page metadata is present', typeof res.body?.total === 'number');
    check(
      'generated task notification exists',
      Array.isArray(notifications) && notifications.some((item) => item.type === 'TASK_DUE_SOON'),
    );
    check('notifications do not expose passwordHash', !hasPasswordHash(res.body));
    notificationId = Array.isArray(notifications) ? notifications[0]?.id : null;
  }

  {
    const res = await request('GET', `/api/v1/notifications/unread-count?weddingPlanId=${planId}`, null, accessToken);
    check('GET /api/v1/notifications/unread-count - HTTP 200', res.status === 200);
    check('unread count is numeric', typeof res.body?.count === 'number');
    check('unread count sees generated notification', res.body?.count >= 1);
  }

  {
    const res = await request('PATCH', `/api/v1/notifications/${notificationId}/read`, null, accessToken);
    check('PATCH /api/v1/notifications/:id/read - HTTP 200', res.status === 200);
    check('mark read sets readAt', typeof res.body?.readAt === 'string');
  }

  {
    const res = await request('PATCH', `/api/v1/notifications/read-all?weddingPlanId=${planId}`, null, accessToken);
    check('PATCH /api/v1/notifications/read-all - HTTP 200', res.status === 200);
    check('read-all returns updated count', typeof res.body?.updated === 'number');
  }

  {
    const res = await request('DELETE', `/api/v1/notifications/${notificationId}`, null, accessToken);
    check('DELETE /api/v1/notifications/:id - HTTP 200', res.status === 200);
    check('delete response marks deleted', res.body?.deleted === true);
  }

  {
    const res = await request('GET', '/api/v1/notifications');
    check('GET /api/v1/notifications without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Notifications smoke error:', err.message);
  process.exit(1);
});
