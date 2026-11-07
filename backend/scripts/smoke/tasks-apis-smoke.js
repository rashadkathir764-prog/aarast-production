#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');

/**
 * Tasks APIs Smoke Test
 * Covers /api/v1 task CRUD, checklist CRUD, assignment, summary, and auth guards.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-5)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+9672${suffix}`;
const MEMBER_PHONE = `+9673${suffix}`;
const OUTSIDER_PHONE = `+9670${suffix}`;
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

const { riyadhDateOffsetIso: dateOffsetIso } = require('./smoke-utils');

async function registerUser(name, phone) {
  const res = await registerVerified(request, {
    name,
    phone,
    password: TEST_PASSWORD,
  });
  check(`${name} register - HTTP 201`, res.status === 201);
  check(`${name} register returns token`, typeof res.body?.accessToken === 'string');
  check(`${name} register has user id`, typeof res.body?.user?.id === 'string');
  check(`${name} register does not expose passwordHash`, !hasPasswordHash(res.body));
  return { token: res.body?.accessToken, userId: res.body?.user?.id, phone };
}

async function run() {
  console.log('\nTasks APIs Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Member phone: ${MEMBER_PHONE}`);
  console.log(`Outsider phone: ${OUTSIDER_PHONE}\n`);

  const owner = await registerUser('Tasks Owner', OWNER_PHONE);
  const member = await registerUser('Tasks Member', MEMBER_PHONE);
  const outsider = await registerUser('Tasks Outsider', OUTSIDER_PHONE);

  let planId = null;
  let taskId = null;
  let todayTaskId = null;
  let checklistItemId = null;

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Tasks APIs Plan',
      city: 'Sanaa',
      weddingDate: dateOffsetIso(60),
    }, owner.token);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    planId = res.body?.id;
  }

  {
    // RA-BE-42: the member joins by accepting an invite (P5).
    const res = await inviteAndAccept(request, {
      planId,
      inviterToken: owner.token,
      member,
      // D52 (J2-05): «يشوف بس» manages nothing; a task-capable member is a helper.
      access: { role: 'HELPER', canManageTasks: true },
    });
    check('owner adds task-capable member - HTTP 201', res.status === 201);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Book hall',
      description: 'Choose a hall',
      dueDate: dateOffsetIso(-1),
      responsibleName: 'Hall coordinator',
      responsiblePhone: '+967777123456',
      responsibleSource: 'manual',
      status: 'TODO',
      priority: 'URGENT',
    }, owner.token);
    check('POST /api/v1 tasks - HTTP 201', res.status === 201);
    check('created task has id', typeof res.body?.id === 'string');
    check('created task priority supports URGENT', res.body?.priority === 'URGENT');
    check('created task keeps manual responsible name', res.body?.responsibleName === 'Hall coordinator');
    check('created task keeps optional responsible phone', res.body?.responsiblePhone === '+967777123456');
    check('created task keeps responsible source', res.body?.responsibleSource === 'manual');
    taskId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/tasks/${taskId}`, null, owner.token);
    check('GET /api/v1/tasks/:id - HTTP 200', res.status === 200);
    check('task get-by-id matches', res.body?.id === taskId);
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}`, {
      status: 'IN_PROGRESS',
      title: 'Book main hall',
    }, owner.token);
    check('PATCH /api/v1/tasks/:id - HTTP 200', res.status === 200);
    check('task title updated', res.body?.title === 'Book main hall');
    check('task status updated', res.body?.status === 'IN_PROGRESS');
  }

  {
    const res = await request('POST', `/api/v1/tasks/${taskId}/checklist`, {
      title: 'Call hall owner',
      sortOrder: 1,
    }, owner.token);
    check('POST checklist item - HTTP 201', res.status === 201);
    check('checklist item has id', typeof res.body?.id === 'string');
    checklistItemId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}/checklist/${checklistItemId}`, {
      isDone: true,
      title: 'Called hall owner',
    }, owner.token);
    check('PATCH checklist item - HTTP 200', res.status === 200);
    check('checklist item is done', res.body?.isDone === true);
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}/assign`, {
      assigneeUserId: member.userId,
    }, owner.token);
    check('PATCH task assign - HTTP 200', res.status === 200);
    check('task assignee is member', res.body?.assigneeUserId === member.userId);
    check('participant assignment clears manual responsible name', res.body?.responsibleName === null);
    check('participant assignment clears manual responsible phone', res.body?.responsiblePhone === null);
    check('participant assignment clears manual responsible source', res.body?.responsibleSource === null);
  }

  {
    const res = await request('PATCH', `/api/v1/tasks/${taskId}/assign`, {
      assigneeUserId: outsider.userId,
    }, owner.token);
    check('cannot assign outside plan', res.status === 400);
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Today task',
      dueDate: dateOffsetIso(0),
      status: 'TODO',
      priority: 'HIGH',
    }, member.token);
    check('task-capable member creates task - HTTP 201', res.status === 201);
    todayTaskId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Done task',
      dueDate: dateOffsetIso(3),
      status: 'DONE',
      priority: 'LOW',
    }, owner.token);
    check('owner creates done task - HTTP 201', res.status === 201);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/tasks/summary`, null, owner.token);
    check('GET task summary - HTTP 200', res.status === 200);
    check('summary totalTasks is real', res.body?.totalTasks === 3);
    check('summary total alias is stable', res.body?.total === 3);
    check('summary completedTasks is real', res.body?.completedTasks === 1);
    check('summary completed alias is stable', res.body?.completed === 1);
    check('summary overdueTasks is real', res.body?.overdueTasks === 1);
    check('summary overdue alias is stable', res.body?.overdue === 1);
    check('summary todayTasks is real', res.body?.todayTasks === 1);
    check('summary dueToday alias is stable', res.body?.dueToday === 1);
    check('summary pendingInProgress is real', res.body?.pendingInProgress === 2);
    check('summary highPriority is real', res.body?.highPriority === 2);
    check('summary assigneeSummary is explicit', res.body?.assigneeSummary?.assignedCount === 1);
    check('summary byPriority includes URGENT', res.body?.byPriority?.URGENT === 1);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/tasks/${taskId}/checklist/${checklistItemId}`, null, owner.token);
    check('DELETE checklist item - HTTP 200', res.status === 200);
  }

  {
    const res = await request('DELETE', `/api/v1/tasks/${todayTaskId}`, null, owner.token);
    check('DELETE task - HTTP 200', res.status === 200);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`);
    check('tasks without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, outsider.token);
    check('outsider cannot list plan tasks', res.status === 404);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Tasks APIs smoke error:', err.message);
  process.exit(1);
});
