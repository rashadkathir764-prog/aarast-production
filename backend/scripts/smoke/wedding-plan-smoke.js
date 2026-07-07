#!/usr/bin/env node
'use strict';

/**
 * WeddingPlan Smoke Test
 * Tests protected WeddingPlan endpoints without creating future product modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3124';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9672${suffix}`;
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
  console.log('\nWeddingPlan Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let accessToken = null;
  let userId = null;
  let planId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'WeddingPlan Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    accessToken = res.body?.accessToken;
    userId = res.body?.user?.id;
  }

  {
    const res = await request('POST', '/wedding-plans', {
      title: 'Smoke Wedding Plan',
      city: 'Sanaa',
      weddingDate: '2026-12-20T00:00:00.000Z',
      estimatedBudget: '1500000.50',
    }, accessToken);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    check('created plan has id', typeof res.body?.id === 'string');
    check('created plan has expected title', res.body?.title === 'Smoke Wedding Plan');
    check('created plan has ownerUserId', res.body?.ownerUserId === userId);
    check('created plan status defaults to PLANNING', res.body?.status === 'PLANNING');
    check('created plan currency defaults to YER', res.body?.currency === 'YER');
    check('created plan does not expose passwordHash', !hasPasswordHash(res.body));
    planId = res.body?.id;
  }

  {
    const res = await request('GET', '/wedding-plans/my', null, accessToken);
    check('GET /wedding-plans/my - HTTP 200', res.status === 200);
    check('my plans response is array', Array.isArray(res.body));
    check('my plans includes created plan', Array.isArray(res.body) && res.body.some((plan) => plan.id === planId));
    check('my plans do not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${planId}`, null, accessToken);
    check('GET /wedding-plans/:id - HTTP 200', res.status === 200);
    check('get plan returns correct id', res.body?.id === planId);
    check('get plan returns ownerUserId', res.body?.ownerUserId === userId);
    check('get plan does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/wedding-plans/${planId}`, {
      title: 'Updated Smoke Wedding Plan',
      city: 'Aden',
    }, accessToken);
    check('PATCH /wedding-plans/:id - HTTP 200', res.status === 200);
    check('updated plan title changed', res.body?.title === 'Updated Smoke Wedding Plan');
    check('updated plan city changed', res.body?.city === 'Aden');
    check('updated plan ownerUserId unchanged', res.body?.ownerUserId === userId);
    check('updated plan does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/wedding-plans/${planId}/archive`, null, accessToken);
    check('PATCH /wedding-plans/:id/archive - HTTP 200', res.status === 200);
    check('archived plan status is ARCHIVED', res.body?.status === 'ARCHIVED');
    check('archived plan does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/wedding-plans/my');
    check('GET /wedding-plans/my without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('WeddingPlan smoke error:', err.message);
  process.exit(1);
});
