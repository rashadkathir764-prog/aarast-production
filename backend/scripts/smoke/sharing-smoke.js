#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Sharing / Permissions Smoke Test
 * Tests SharedMember APIs and basic shared access without creating future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3144';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+9676${suffix}`;
const SHARED_PHONE = `+9677${suffix}`;
const SHARED_BY_PHONE = `+9678${suffix}`;
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

function hasOnlySafeSharedUserFields(member) {
  const user = member?.user;
  if (!user || typeof user !== 'object') return false;
  const keys = Object.keys(user).sort();
  return JSON.stringify(keys) === JSON.stringify(['id', 'name', 'phone']);
}

async function register(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  return {
    status: res.status,
    token: res.body?.accessToken,
    user: res.body?.user,
    body: res.body,
  };
}

async function run() {
  console.log('\nSharing / Permissions Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Shared phone: ${SHARED_PHONE}\n`);
  console.log(`Shared-by-phone: ${SHARED_BY_PHONE}\n`);

  let ownerToken = null;
  let sharedToken = null;
  let sharedUserId = null;
  let sharedByPhoneToken = null;
  let weddingPlanId = null;
  let sharedMemberId = null;
  let sharedByPhoneMemberId = null;
  let taskId = null;

  {
    const owner = await register('Sharing Smoke Owner', OWNER_PHONE);
    check('owner register - HTTP 201', owner.status === 201);
    check('owner register returns token', typeof owner.token === 'string');
    check('owner register does not expose passwordHash', !hasPasswordHash(owner.body));
    ownerToken = owner.token;
  }

  {
    const shared = await register('Sharing Smoke Member', SHARED_PHONE);
    check('shared user register - HTTP 201', shared.status === 201);
    check('shared user register returns token', typeof shared.token === 'string');
    check('shared user register has id', typeof shared.user?.id === 'string');
    check('shared user register does not expose passwordHash', !hasPasswordHash(shared.body));
    sharedToken = shared.token;
    sharedUserId = shared.user?.id;
  }

  {
    const shared = await register('Sharing Smoke Phone Member', SHARED_BY_PHONE);
    check('shared-by-phone user register - HTTP 201', shared.status === 201);
    check('shared-by-phone user register returns token', typeof shared.token === 'string');
    check('shared-by-phone user register does not expose passwordHash', !hasPasswordHash(shared.body));
    sharedByPhoneToken = shared.token;
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Sharing Smoke Plan',
      city: 'Sanaa',
      weddingDate: '2026-12-30T00:00:00.000Z',
      estimatedBudget: '1500000.00',
    }, ownerToken);
    check('owner creates wedding plan - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('created wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: sharedUserId,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: false,
      canViewFinancialRecords: false,
      canManageTasks: false,
      canManageFinancialRecords: false,
    }, ownerToken);
    check('owner adds shared member - HTTP 201', res.status === 201);
    check('shared member has id', typeof res.body?.id === 'string');
    check('shared member belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('shared member role is VIEWER', res.body?.role === 'VIEWER');
    check('shared member has no financial permissions', res.body?.canViewExpenses === false && res.body?.canViewFinancialRecords === false);
    check('shared member response includes safe user name', res.body?.user?.name === 'Sharing Smoke Member');
    check('shared member response includes safe user phone', res.body?.user?.phone === SHARED_PHONE);
    check('shared member response user fields are safe', hasOnlySafeSharedUserFields(res.body));
    check('shared member response does not expose passwordHash', !hasPasswordHash(res.body));
    sharedMemberId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      phone: SHARED_BY_PHONE,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: false,
      canViewFinancialRecords: false,
      canManageTasks: false,
      canManageFinancialRecords: false,
    }, ownerToken);
    check('owner adds shared member by phone - HTTP 201', res.status === 201);
    check('phone-added shared member has id', typeof res.body?.id === 'string');
    check('phone-added shared member belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('phone-added shared member includes safe user name', res.body?.user?.name === 'Sharing Smoke Phone Member');
    check('phone-added shared member includes safe user phone', res.body?.user?.phone === SHARED_BY_PHONE);
    check('phone-added shared member user fields are safe', hasOnlySafeSharedUserFields(res.body));
    check('phone-added shared member response does not expose passwordHash', !hasPasswordHash(res.body));
    sharedByPhoneMemberId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: sharedUserId,
      phone: SHARED_BY_PHONE,
      role: 'VIEWER',
    }, ownerToken);
    check('owner cannot provide both userId and phone', res.status === 400);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/members`, null, ownerToken);
    check('owner lists shared members - HTTP 200', res.status === 200);
    check('shared member list includes member', Array.isArray(res.body) && res.body.some((member) => member.id === sharedMemberId));
    check('shared member list includes phone-added member', Array.isArray(res.body) && res.body.some((member) => member.id === sharedByPhoneMemberId));
    check('shared member list includes safe user display data', Array.isArray(res.body) && res.body.some((member) => member.user?.name === 'Sharing Smoke Member' && member.user?.phone === SHARED_PHONE));
    check('shared member list safe user fields only', Array.isArray(res.body) && res.body.every(hasOnlySafeSharedUserFields));
    check('shared member list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/api/v1/shared/wedding-plans', null, sharedToken);
    check('shared user lists shared wedding plans - HTTP 200', res.status === 200);
    check('shared plan list includes plan', Array.isArray(res.body) && res.body.some((plan) => plan.id === weddingPlanId));
    check('shared plan list includes role', Array.isArray(res.body) && res.body.some((plan) => plan.sharedMember?.role === 'VIEWER'));
    check('shared plan list does not expose owner object', !JSON.stringify(res.body).includes('"owner"'));
    check('shared plan list includes safe member display data', Array.isArray(res.body) && res.body.some((plan) => plan.sharedMember?.user?.phone === SHARED_PHONE));
    check('shared plan list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/api/v1/shared/wedding-plans', null, sharedByPhoneToken);
    check('phone-added shared user lists shared wedding plans - HTTP 200', res.status === 200);
    check('phone-added shared plan list includes plan', Array.isArray(res.body) && res.body.some((plan) => plan.id === weddingPlanId));
    check('phone-added shared plan list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}`, null, sharedToken);
    check('shared user reads basic plan - HTTP 200', res.status === 200);
    check('shared user reads correct plan id', res.body?.id === weddingPlanId);
    check('shared user cannot see estimatedBudget without permission', res.body?.estimatedBudget === null);
    check('shared plan read does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}`, {
      title: 'Shared user should not update',
    }, sharedToken);
    check('shared VIEWER cannot update plan', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}/archive`, null, sharedToken);
    check('shared VIEWER cannot archive plan', res.status === 404);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, {
      title: 'Blocked shared task',
    }, sharedToken);
    check('shared VIEWER cannot create task before permission', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedMemberId}`, {
      canManageTasks: true,
    }, ownerToken);
    check('owner grants task management - HTTP 200', res.status === 200);
    check('task management permission enabled', res.body?.canManageTasks === true);
    check('permission update does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, {
      title: 'Shared user can manage task',
      dueDate: '2026-12-10T00:00:00.000Z',
      priority: 'HIGH',
    }, sharedToken);
    check('shared user creates task with permission - HTTP 201', res.status === 201);
    check('shared-created task belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('shared-created task does not expose passwordHash', !hasPasswordHash(res.body));
    taskId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}`, {
      status: 'IN_PROGRESS',
    }, sharedToken);
    check('shared user updates task with permission - HTTP 200', res.status === 200);
    check('shared user updated task status', res.body?.status === 'IN_PROGRESS');
    check('shared task update does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, null, sharedToken);
    check('shared user lists tasks - HTTP 200', res.status === 200);
    check('shared task list includes task', Array.isArray(res.body) && res.body.some((task) => task.id === taskId));
    check('shared task list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/timeline`, null, sharedToken);
    check('shared user reads timeline - HTTP 200', res.status === 200);
    check('shared timeline includes tasks array', Array.isArray(res.body?.upcomingTasks));
    check('shared timeline hides due commitments without permission', Array.isArray(res.body?.dueCommitments) && res.body.dueCommitments.length === 0);
    check('shared timeline hides due installments without permission', Array.isArray(res.body?.dueInstallments) && res.body.dueInstallments.length === 0);
    check('shared timeline does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, null, sharedToken);
    check('shared user cannot access expenses without permission', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/financial-commitments`, null, sharedToken);
    check('shared user cannot access financial records without permission', res.status === 404);
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedMemberId}`, null, ownerToken);
    check('owner removes shared member - HTTP 200', res.status === 200);
    check('removed shared member id returned', res.body?.id === sharedMemberId);
    check('remove shared member response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedByPhoneMemberId}`, null, ownerToken);
    check('owner removes phone-added shared member - HTTP 200', res.status === 200);
    check('removed phone-added shared member id returned', res.body?.id === sharedByPhoneMemberId);
    check('remove phone-added shared member response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', '/api/v1/shared/wedding-plans', null, sharedToken);
    check('shared user no longer sees plan - HTTP 200', res.status === 200);
    check('removed plan not listed', Array.isArray(res.body) && !res.body.some((plan) => plan.id === weddingPlanId));
    check('post-removal shared plan list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/members`);
    check('unauthenticated sharing route returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Sharing smoke error:', err.message);
  process.exit(1);
});
