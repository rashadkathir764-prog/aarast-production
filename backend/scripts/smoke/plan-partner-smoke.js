#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');

/**
 * Plan partner smoke (V1 checklist 4.10), through the HTTP stack: the owner
 * invites the bride as a partner and a relative as family. The partner sees
 * the whole plan (every cost, the money summary, every task) like the owner,
 * but never the owner's private funding sources and loans; the relative sees
 * only what they added.
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
  return { token: response.body?.accessToken, userId: response.body?.user?.id };
}

const MONEY_AND_TASKS = {
  canViewMoney: true,
  canManageMoney: true,
  canManageTasks: true,
  canManageGuests: true,
  canManageProviders: true,
};

async function join(planId, owner, member, role) {
  const invite = await request('POST', `/api/v1/wedding-plans/${planId}/invites`, {
    userId: member.userId, role, expiresInDays: 7, ...MONEY_AND_TASKS,
  }, owner.token);
  const accepted = await request('POST', `/api/v1/invites/${invite.body?.token}/accept`, null, member.token);
  check(`${role} joins the plan`, accepted.status === 201 && accepted.body?.member?.role === role);
}

async function addCost(planId, token, categoryId, title, totalAmount) {
  const response = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, { budgetCategoryId: categoryId, title, totalAmount }, token);
  if (response.status !== 201) console.log(`cost ${title} -> ${response.status} ${JSON.stringify(response.body).slice(0, 200)}`);
  return response.body?.id;
}

async function costTitles(planId, token) {
  const response = await request('GET', `/api/v1/wedding-plans/${planId}/costs`, null, token);
  const items = Array.isArray(response.body) ? response.body : response.body?.items ?? [];
  return items.map((item) => item.title).sort();
}

async function run() {
  console.log('Plan Partner Smoke Report');
  console.log(`Target: ${BASE_URL}`);

  const owner = await register('Partner owner', phone(61));
  const bride = await register('Partner bride', phone(62));
  const family = await register('Partner family', phone(63));
  try {
    const plan = await request('POST', '/api/v1/wedding-plans', { title: 'Partner plan', city: 'Sanaa' }, owner.token);
    const planId = plan.body?.id;
    const clientId = randomUUID();
    const budget = await request('PUT', `/api/v1/wedding-plans/${planId}/money-budget`, {
      totalBudget: '10000', currency: 'YER',
      categories: [{ clientId, name: 'Hall', allocatedAmount: '9000' }],
    }, owner.token);
    const categoryId = budget.body?.idMap?.[clientId];
    await addCost(planId, owner.token, categoryId, 'Owner hall', '3000');
    await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'Owner task' }, owner.token);
    const funding = await request('POST', `/api/v1/wedding-plans/${planId}/funding-sources`, {
      kind: 'LOAN', sourceName: 'Owner private loan', amount: '2000', status: 'RECEIVED',
    }, owner.token);
    check('the owner records a private loan', funding.status === 201);

    await join(planId, owner, bride, 'BRIDE');
    await join(planId, owner, family, 'FAMILY');
    await addCost(planId, bride.token, categoryId, 'Bride dress', '1500');
    // A relative works only in the categories they create.
    const familyCategory = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Family gifts', allocatedAmount: '600',
    }, family.token);
    await addCost(planId, family.token, familyCategory.body?.id, 'Family gift', '500');

    check('the owner sees every cost', JSON.stringify(await costTitles(planId, owner.token)) === JSON.stringify(['Bride dress', 'Family gift', 'Owner hall']));
    check('the partner sees every cost like the owner', JSON.stringify(await costTitles(planId, bride.token)) === JSON.stringify(['Bride dress', 'Family gift', 'Owner hall']));
    check('the relative sees only what they added', JSON.stringify(await costTitles(planId, family.token)) === JSON.stringify(['Family gift']));

    const brideSummary = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, bride.token);
    check('the partner money summary covers the whole plan', brideSummary.status === 200 && Number(brideSummary.body?.costs?.total) === 5000);
    check('the partner never sees the owner private loans', brideSummary.body?.funding == null);
    const familySummary = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, family.token);
    check('the relative summary covers only their own costs', Number(familySummary.body?.costs?.total) === 500);

    const brideTasks = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, bride.token);
    const brideTaskTitles = (Array.isArray(brideTasks.body) ? brideTasks.body : brideTasks.body?.items ?? []).map((task) => task.title);
    check('the partner sees the owner tasks', brideTaskTitles.includes('Owner task'));
    const familyTasks = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, family.token);
    const familyTaskTitles = (Array.isArray(familyTasks.body) ? familyTasks.body : familyTasks.body?.items ?? []).map((task) => task.title);
    check('the relative does not see the owner tasks', !familyTaskTitles.includes('Owner task'));
  } finally {
    for (const [label, account] of [['family', family], ['bride', bride], ['owner', owner]]) {
      if (!account.token) continue;
      const response = await request('DELETE', '/api/v1/users/me', null, account.token, randomUUID());
      check(`${label} fixture account is cleaned`, response.status === 200);
    }
  }

  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Plan partner smoke error:', error.message);
  process.exit(1);
});
