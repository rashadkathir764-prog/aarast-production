#!/usr/bin/env node
'use strict';

/**
 * Onboarding + Active Plan Smoke Test
 * Covers authenticated onboarding, /api/v1 compatibility paths, real category
 * creation, active plan selection, and basic invalid input guards.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const TEST_PHONE = `+9677${suffix}`;
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
  console.log('\nOnboarding + Active Plan Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test phone: ${TEST_PHONE}\n`);

  let accessToken = null;
  let userId = null;
  let activePlanId = null;
  let secondPlanId = null;

  {
    const res = await request('POST', '/auth/register', {
      name: 'Onboarding Smoke User',
      phone: TEST_PHONE,
      password: TEST_PASSWORD,
    });
    check('POST /auth/register - HTTP 201', res.status === 201);
    check('register returns accessToken', typeof res.body?.accessToken === 'string');
    check('register returns user id', typeof res.body?.user?.id === 'string');
    check('register does not expose passwordHash', !hasPasswordHash(res.body));
    accessToken = res.body?.accessToken;
    userId = res.body?.user?.id;
  }

  {
    const res = await request('GET', '/api/v1/me', null, accessToken);
    check('GET /api/v1/me - HTTP 200', res.status === 200);
    check('GET /api/v1/me returns current user', res.body?.id === userId);
    check('GET /api/v1/me does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('GET /api/v1/wedding-plans/active before onboarding - HTTP 200', res.status === 200);
    check('active plan before onboarding is empty', res.body === null || res.body === '');
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      persona: 'GROOM',
      location: {
        governorate: 'Sanaa',
        city: 'Sanaa',
        district: 'Old City',
      },
      weddingDate: '2026-12-20T00:00:00.000Z',
      priorities: ['budget', 'tasks', 'providers'],
      estimatedBudget: '1500000',
      currency: 'YER',
      selectedCategories: ['Hall', 'Food', 'Photography'],
    }, accessToken);
    check('POST /api/v1/onboarding/complete - HTTP 201', res.status === 201);
    check('onboarding returns user', res.body?.user?.id === userId);
    check('onboarding returns activeWeddingPlan', typeof res.body?.activeWeddingPlan?.id === 'string');
    check('onboarding sets activeWeddingPlanId', res.body?.user?.activeWeddingPlanId === res.body?.activeWeddingPlan?.id);
    check('onboarding persists persona', res.body?.activeWeddingPlan?.persona === 'GROOM');
    check('onboarding persists city from location', res.body?.activeWeddingPlan?.city === 'Sanaa');
    check('onboarding persists priorities', Array.isArray(res.body?.activeWeddingPlan?.priorities) && res.body.activeWeddingPlan.priorities.length === 3);
    check('onboarding creates real budget categories', Array.isArray(res.body?.budgetCategories) && res.body.budgetCategories.length === 3);
    check('onboarding does not expose passwordHash', !hasPasswordHash(res.body));
    activePlanId = res.body?.activeWeddingPlan?.id;
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans', null, accessToken);
    check('GET /api/v1/wedding-plans - HTTP 200', res.status === 200);
    check('accessible plans response is array', Array.isArray(res.body));
    check('accessible plans include onboarding plan', Array.isArray(res.body) && res.body.some((plan) => plan.id === activePlanId));
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('GET /api/v1/wedding-plans/active after onboarding - HTTP 200', res.status === 200);
    check('active plan matches onboarding plan', res.body?.id === activePlanId);
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Second Smoke Wedding Plan',
      city: 'Aden',
      selectedCategories: ['Decoration'],
    }, accessToken);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('second plan has id', typeof res.body?.id === 'string');
    secondPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${secondPlanId}/set-active`, null, accessToken);
    check('POST /api/v1/wedding-plans/:id/set-active - HTTP 201', res.status === 201);
    check('set-active returns selected plan', res.body?.id === secondPlanId);
  }

  {
    const res = await request('GET', '/api/v1/wedding-plans/active', null, accessToken);
    check('active plan changes after set-active', res.body?.id === secondPlanId);
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
      estimatedBudget: '-5',
      selectedCategories: ['Invalid Budget Category'],
    }, accessToken);
    check('negative onboarding budget returns 400', res.status === 400);
  }

  {
    const res = await request('POST', '/api/v1/onboarding/complete', {
      path: 'USER',
    });
    check('onboarding without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Onboarding active plan smoke error:', err.message);
  process.exit(1);
});
