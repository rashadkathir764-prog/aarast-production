#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');

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

  // RA-BE-42: nobody is added to a plan without accepting an invite (P5).
  // Adding by account id put any account in a plan unasked and told it
  // «انضفت لخطة …»; it is refused like adding by number, and adds no one.
  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: sharedUserId,
      role: 'VIEWER',
    }, ownerToken);
    check(
      'adding an account by its id is refused and adds no one',
      res.status === 400 && res.body?.code === 'ADD_BY_INVITE',
    );
    const before = await request('GET', `/api/v1/shared/wedding-plans`, null, sharedToken);
    check(
      'the account is in no plan it did not accept',
      before.status === 200 && Array.isArray(before.body) &&
        !before.body.some((plan) => plan.id === weddingPlanId),
    );
  }

  {
    const res = await inviteAndAccept(request, {
      planId: weddingPlanId,
      inviterToken: ownerToken,
      member: { phone: SHARED_PHONE, token: sharedToken },
      access: { role: 'VIEWER' },
    });
    check('owner adds shared member - HTTP 201', res.status === 201);
    check('shared member has id', typeof res.body?.id === 'string');
    check('shared member belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('shared member role is VIEWER', res.body?.role === 'VIEWER');
    check('shared member has no money permissions', res.body?.canViewMoney === false && res.body?.canManageMoney === false);
    check('shared member response includes safe user name', res.body?.user?.name === 'Sharing Smoke Member');
    check('shared member response includes safe user phone', res.body?.user?.phone === SHARED_PHONE);
    check('shared member response user fields are safe', hasOnlySafeSharedUserFields(res.body));
    check('shared member response does not expose passwordHash', !hasPasswordHash(res.body));
    sharedMemberId = res.body?.id;
  }

  // RA-BE-20: these checks used to add a member by number and read back the
  // account's name: «No registered user found» against a name told anyone
  // with a plan who holds a number, and added them with no invite. Whoever
  // holds a number joins by accepting an invite (P5); a registered number
  // and an unknown one are now answered alike, and nobody is added.
  {
    const answers = [];
    for (const phone of [SHARED_BY_PHONE, `+9677${String((Number(suffix) + 4321) % 100000000).padStart(8, '0')}`]) {
      const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
        phone,
        role: 'VIEWER',
        canViewMoney: false,
        canManageTasks: false,
        canManageMoney: false,
      }, ownerToken);
      answers.push(`${res.status}:${res.body?.code}`);
    }
    check(
      'adding by number is refused alike for a registered and an unknown number',
      answers.every((answer) => answer === '400:ADD_BY_INVITE'),
    );
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
    check('nobody was added by number', Array.isArray(res.body) && !res.body.some((member) => member.user?.phone === SHARED_BY_PHONE));
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
    // RA-BE-20: the number's holder was never added, so the plan is not theirs to see.
    const res = await request('GET', '/api/v1/shared/wedding-plans', null, sharedByPhoneToken);
    check('the number\'s holder lists shared wedding plans - HTTP 200', res.status === 200);
    check('the number\'s holder was not put in the plan', Array.isArray(res.body) && !res.body.some((plan) => plan.id === weddingPlanId));
    check('the number\'s holder plan list does not expose passwordHash', !hasPasswordHash(res.body));
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
    // RA-BE-40: a member's refused write says why (403); 404 «the plan was
    // not found» told a member their plan was gone.
    check(
      'shared VIEWER cannot update plan',
      res.status === 403 && res.body?.code === 'SECTION_PERMISSION_MISSING',
    );
  }

  {
    const res = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}/archive`, null, sharedToken);
    check(
      'shared VIEWER cannot archive plan',
      res.status === 403 && res.body?.code === 'SECTION_PERMISSION_MISSING',
    );
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/tasks`, {
      title: 'Blocked shared task',
    }, sharedToken);
    check(
      'shared VIEWER receives the stable task-permission denial before grant',
      res.status === 403 &&
        res.body?.code === 'TASK_PERMISSION_REVOKED' &&
        res.body?.message === 'لم تعد لديك صلاحية لتنفيذ هذه المهمة',
    );
  }

  {
    // J2-05, D80: a VIEWER edits nothing, so granting a section comes with
    // the role that may edit it.
    const refused = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedMemberId}`, {
      canManageTasks: true,
    }, ownerToken);
    check(
      'owner cannot grant task management to a VIEWER',
      refused.status === 400 && refused.body?.code === 'VIEWER_CANNOT_EDIT',
    );
    const res = await request('PATCH', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedMemberId}`, {
      role: 'HELPER',
      canManageTasks: true,
    }, ownerToken);
    check('owner grants task management - HTTP 200', res.status === 200);
    check('granted member role is HELPER', res.body?.role === 'HELPER');
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
    check('shared timeline hides payment schedules without permission', Array.isArray(res.body?.paymentSchedules) && res.body.paymentSchedules.length === 0);
    check('shared timeline does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/costs`, null, sharedToken);
    check('shared user cannot access costs without permission', res.status === 404);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/money-summary`, null, sharedToken);
    check('shared user cannot access money summary without permission', res.status === 404);
  }

  {
    const res = await request('DELETE', `/api/v1/wedding-plans/${weddingPlanId}/members/${sharedMemberId}`, null, ownerToken);
    check('owner removes shared member - HTTP 200', res.status === 200);
    check('removed shared member id returned', res.body?.id === sharedMemberId);
    check('remove shared member response does not expose passwordHash', !hasPasswordHash(res.body));
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
