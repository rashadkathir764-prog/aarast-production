#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');

/**
 * Task date shift smoke (V1 checklist 4.13), through the HTTP stack on
 * PostgreSQL: when the wedding moves, the owner moves the plan's open dated
 * tasks (due date and reminder) by the same days; done tasks and undated
 * tasks keep theirs, and nobody else can shift the plan.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokeTest123!';
const phoneSeed = Number(`${Date.now()}`.slice(-8));

let passed = 0;
let failed = 0;

function phone(offset) {
  return `+9677${String((phoneSeed + offset) % 100000000).padStart(8, '0')}`;
}

function check(label, condition) {
  if (condition) {
    passed++;
    console.log(`PASS - ${label}`);
  } else {
    failed++;
    console.log(`FAIL - ${label}`);
  }
}

function request(method, path, body, token, requestId) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json' };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    if (requestId) headers['X-Client-Request-Id'] = requestId;
    const req = http.request(
      { hostname: url.hostname, port: url.port, path: `${url.pathname}${url.search}`, method, headers },
      (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: data ? JSON.parse(data) : null });
          } catch {
            resolve({ status: res.statusCode, body: data });
          }
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function register(name, value) {
  const response = await registerVerified(request, { name, phone: value, password: TEST_PASSWORD });
  check(`${name} registration succeeds`, response.status === 201);
  return response.body?.accessToken;
}

async function createTask(planId, token, fields) {
  const response = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, fields, token);
  return response.body;
}

function day(value) {
  return value ? new Date(value).toISOString().slice(0, 10) : null;
}

async function run() {
  console.log('Task Date Shift Smoke Report');
  console.log(`Target: ${BASE_URL}`);

  const ownerToken = await register('Shift owner', phone(51));
  const strangerToken = await register('Shift stranger', phone(52));
  try {
    const plan = await request('POST', '/api/v1/wedding-plans', { title: 'Shift plan', city: 'Sanaa' }, ownerToken);
    const planId = plan.body?.id;
    const open = await createTask(planId, ownerToken, {
      title: 'Book the hall',
      dueDate: '2027-03-01T09:00:00.000Z',
      reminderAt: '2027-02-25T09:00:00.000Z',
    });
    const done = await createTask(planId, ownerToken, {
      title: 'Done task',
      dueDate: '2027-03-01T09:00:00.000Z',
      status: 'DONE',
    });
    const undated = await createTask(planId, ownerToken, { title: 'Undated task' });
    const shiftPath = `/api/v1/wedding-plans/${planId}/tasks/shift-due-dates`;

    const zero = await request('POST', shiftPath, { days: 0 }, ownerToken);
    check('a zero shift is refused', zero.status === 400);

    const stranger = await request('POST', shiftPath, { days: 30 }, strangerToken);
    check('someone outside the plan cannot shift it', stranger.status === 403 || stranger.status === 404);

    const shifted = await request('POST', shiftPath, { days: 30 }, ownerToken);
    check('the owner moves the open dated tasks', shifted.status === 200 && shifted.body?.shifted === 1);

    const openAfter = await request('GET', `/api/v1/tasks/${open?.id}`, null, ownerToken);
    check(
      'due date and reminder move by 30 days',
      day(openAfter.body?.dueDate) === '2027-03-31' && day(openAfter.body?.reminderAt) === '2027-03-27',
    );
    const doneAfter = await request('GET', `/api/v1/tasks/${done?.id}`, null, ownerToken);
    check('a done task keeps its date', day(doneAfter.body?.dueDate) === '2027-03-01');
    const undatedAfter = await request('GET', `/api/v1/tasks/${undated?.id}`, null, ownerToken);
    check('an undated task stays undated', undatedAfter.status === 200 && undatedAfter.body?.dueDate === null);

    const back = await request('POST', shiftPath, { days: -10 }, ownerToken);
    const openBack = await request('GET', `/api/v1/tasks/${open?.id}`, null, ownerToken);
    check('an earlier wedding moves them back', back.status === 200 && day(openBack.body?.dueDate) === '2027-03-21');
  } finally {
    for (const [label, token] of [['owner', ownerToken], ['stranger', strangerToken]]) {
      if (!token) continue;
      const response = await request('DELETE', '/api/v1/users/me', null, token, randomUUID());
      check(`${label} fixture account is cleaned`, response.status === 200);
    }
  }

  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Task date shift smoke error:', error.message);
  process.exit(1);
});
