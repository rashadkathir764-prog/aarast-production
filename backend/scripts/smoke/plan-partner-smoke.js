#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const {
  isPendingDeletion,
  purgePendingAccounts,
  requestAccountDeletion,
} = require('./account-grace');

/**
 * Plan partner smoke (V1 checklist 4.10), through the HTTP stack: the owner
 * invites the bride as a partner and a relative as family. The partner sees
 * the whole plan (every cost, the money summary, every task) like the owner,
 * but never the owner's private funding sources and loans; the relative sees
 * only what they added. Private costs and tasks stay with their account, can
 * be shared later but never hidden after the fact, and leave with the
 * account when it is deleted.
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

    // Private costs: the bride's private cost stays hers alone.
    const secret = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryId, title: 'Bride secret', totalAmount: '700', isPrivate: true,
    }, bride.token);
    check('the partner records a private cost', secret.status === 201 && secret.body?.isPrivate === true);
    check('the owner does not see the partner private cost', !(await costTitles(planId, owner.token)).includes('Bride secret'));
    check('the partner sees her private cost', (await costTitles(planId, bride.token)).includes('Bride secret'));
    const ownerGet = await request('GET', `/api/v1/costs/${secret.body?.id}`, null, owner.token);
    check('the owner cannot open it by id', ownerGet.status === 404);
    const ownerEdit = await request('PATCH', `/api/v1/costs/${secret.body?.id}`, { title: 'Peek' }, owner.token);
    check('nor change it', ownerEdit.status === 404);
    const ownerSummary = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, owner.token);
    check('the owner totals leave it out', Number(ownerSummary.body?.costs?.total) === 5000);
    const brideSummaryWithSecret = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, bride.token);
    check('the partner totals include it', Number(brideSummaryWithSecret.body?.costs?.total) === 5700);
    const ownerCategories = await request('GET', `/api/v1/wedding-plans/${planId}/budget-categories`, null, owner.token);
    const hall = (Array.isArray(ownerCategories.body) ? ownerCategories.body : ownerCategories.body?.items ?? []).find((category) => category.id === categoryId);
    check('the owner category counts leave it out', hall?.costsCount === 2);
    const ownerDashboard = await request('GET', `/api/v1/wedding-plans/${planId}/dashboard-summary`, null, owner.token);
    const findKey = (value, key) => {
      if (!value || typeof value !== 'object') return undefined;
      if (key in value) return value[key];
      for (const child of Object.values(value)) {
        const found = findKey(child, key);
        if (found !== undefined) return found;
      }
      return undefined;
    };
    check(
      'the owner dashboard does not count it',
      ownerDashboard.status === 200 && Number(findKey(ownerDashboard.body, 'confirmedCostTotal')) === 5000,
    );

    const familyPrivate = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: familyCategory.body?.id, title: 'Family private', totalAmount: '10', isPrivate: true,
    }, family.token);
    check('a relative cannot record a private cost', familyPrivate.status === 403 && familyPrivate.body?.code === 'COST_PRIVACY_NOT_ALLOWED');

    const ownerCosts = await request('GET', `/api/v1/wedding-plans/${planId}/costs`, null, owner.token);
    const hallCost = (Array.isArray(ownerCosts.body) ? ownerCosts.body : ownerCosts.body?.items ?? []).find((cost) => cost.title === 'Owner hall');
    const hideShared = await request('PATCH', `/api/v1/costs/${hallCost?.id}`, { isPrivate: true }, bride.token);
    check('a shared cost never becomes private', hideShared.status === 400 && hideShared.body?.code === 'COST_PRIVACY_AT_CREATION_ONLY');

    const shared = await request('PATCH', `/api/v1/costs/${secret.body?.id}`, { isPrivate: false }, bride.token);
    check('the partner can share her private cost', shared.status === 200 && shared.body?.isPrivate === false);
    check('then the owner sees it', (await costTitles(planId, owner.token)).includes('Bride secret'));

    const brideTasks = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, bride.token);
    const brideTaskTitles = (Array.isArray(brideTasks.body) ? brideTasks.body : brideTasks.body?.items ?? []).map((task) => task.title);
    check('the partner sees the owner tasks', brideTaskTitles.includes('Owner task'));
    const familyTasks = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, family.token);
    const familyTaskTitles = (Array.isArray(familyTasks.body) ? familyTasks.body : familyTasks.body?.items ?? []).map((task) => task.title);
    check('the relative does not see the owner tasks', !familyTaskTitles.includes('Owner task'));

    // Private tasks (V1 checklist 4.10).
    const taskTitles = async (token) => {
      const response = await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, token);
      return (Array.isArray(response.body) ? response.body : response.body?.items ?? []).map((task) => task.title);
    };
    const secretTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Bride secret task', dueDate: new Date(Date.now() + 2 * 86400000).toISOString(), isPrivate: true,
    }, bride.token);
    check('the partner keeps a private task', secretTask.status === 201 && secretTask.body?.isPrivate === true);
    check('the partner sees her private task', (await taskTitles(bride.token)).includes('Bride secret task'));
    check('the owner does not see it', !(await taskTitles(owner.token)).includes('Bride secret task'));
    const ownerTaskGet = await request('GET', `/api/v1/tasks/${secretTask.body?.id}`, null, owner.token);
    check('the owner cannot open it by id', ownerTaskGet.status === 404);
    const ownerTaskEdit = await request('PATCH', `/api/v1/tasks/${secretTask.body?.id}`, { title: 'seen' }, owner.token);
    check('nor change it', ownerTaskEdit.status === 404);
    const ownerChecklist = await request('POST', `/api/v1/tasks/${secretTask.body?.id}/checklist`, { title: 'peek' }, owner.token);
    check('nor add to its checklist', ownerChecklist.status === 404);
    const brideChecklist = await request('POST', `/api/v1/tasks/${secretTask.body?.id}/checklist`, { title: 'Fitting' }, bride.token);
    check('the partner adds to her private task checklist', brideChecklist.status === 201);
    const ownerTaskSummary = await request('GET', `/api/v1/wedding-plans/${planId}/tasks/summary`, null, owner.token);
    const brideTaskSummary = await request('GET', `/api/v1/wedding-plans/${planId}/tasks/summary`, null, bride.token);
    check(
      'the owner task counts leave it out',
      ownerTaskSummary.status === 200 && brideTaskSummary.body?.totalTasks === ownerTaskSummary.body?.totalTasks + 1,
    );
    const familyTaskSummary = await request('GET', `/api/v1/wedding-plans/${planId}/tasks/summary`, null, family.token);
    check(
      'the app offers a private task to the owner and the partner only',
      ownerTaskSummary.body?.canKeepPrivateTask === true &&
        brideTaskSummary.body?.canKeepPrivateTask === true &&
        familyTaskSummary.body?.canKeepPrivateTask === false,
    );
    const assignAway = await request('PATCH', `/api/v1/tasks/${secretTask.body?.id}/assign`, { assigneeUserId: owner.userId }, bride.token);
    check('a private task is not assigned to another account', assignAway.status === 400 && assignAway.body?.code === 'TASK_PRIVATE_ASSIGNMENT');
    const familyPrivateTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'Family private task', isPrivate: true }, family.token);
    check('a relative cannot keep a private task', familyPrivateTask.status === 403 && familyPrivateTask.body?.code === 'TASK_PRIVACY_NOT_ALLOWED');
    const ownerTask = (await request('GET', `/api/v1/wedding-plans/${planId}/tasks`, null, owner.token)).body;
    const ownerTaskId = (Array.isArray(ownerTask) ? ownerTask : ownerTask?.items ?? []).find((task) => task.title === 'Owner task')?.id;
    const hideTask = await request('PATCH', `/api/v1/tasks/${ownerTaskId}`, { isPrivate: true }, owner.token);
    check('a shared task never becomes private', hideTask.status === 400 && hideTask.body?.code === 'TASK_PRIVACY_AT_CREATION_ONLY');
    const sharedTask = await request('PATCH', `/api/v1/tasks/${secretTask.body?.id}`, { isPrivate: false }, bride.token);
    check('the partner can share her private task', sharedTask.status === 200 && sharedTask.body?.isPrivate === false);
    check('then the owner sees it', (await taskTitles(owner.token)).includes('Bride secret task'));

    // What the partner still keeps private leaves with her account: a
    // private cost with a payment and a schedule, and a private task.
    const keptCost = await request('POST', `/api/v1/wedding-plans/${planId}/costs`, {
      budgetCategoryId: categoryId, title: 'Bride kept secret', totalAmount: '400', isPrivate: true,
    }, bride.token);
    const keptPayment = await request('POST', `/api/v1/costs/${keptCost.body?.id}/payments`, { amount: '100' }, bride.token, randomUUID());
    const keptSchedule = await request('POST', `/api/v1/costs/${keptCost.body?.id}/payment-schedules`, {
      amount: '300', dueDate: new Date(Date.now() + 5 * 86400000).toISOString(),
    }, bride.token, randomUUID());
    const keptTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, { title: 'Bride kept task', isPrivate: true }, bride.token);
    check(
      'the partner keeps a private cost with a payment and a schedule, and a private task',
      keptCost.status === 201 && keptPayment.status === 201 && keptSchedule.status === 201 && keptTask.status === 201,
    );
    const brideAsked = await requestAccountDeletion(request, bride.token);
    check('the partner asks to delete her account', isPendingDeletion(brideAsked));
    const brideGone = await purgePendingAccounts();
    check(
      'after the 30 days the partner account goes with her private money and tasks',
      brideGone.erased === 1 && brideGone.failures.length === 0,
    );
    bride.token = null;
    const ownerAfter = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, owner.token);
    check('the owner plan still reads after the partner left', ownerAfter.status === 200 && Number(ownerAfter.body?.costs?.total) === 5700);
  } finally {
    for (const [label, account] of [['family', family], ['bride', bride], ['owner', owner]]) {
      if (!account.token) continue;
      const response = await requestAccountDeletion(request, account.token);
      check(`${label} fixture account asks to be deleted`, isPendingDeletion(response));
    }
    const cleanup = await purgePendingAccounts();
    check('the fixture accounts are erased', cleanup.failures.length === 0);
  }

  console.log(`Overall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Plan partner smoke error:', error.message);
  process.exit(1);
});
