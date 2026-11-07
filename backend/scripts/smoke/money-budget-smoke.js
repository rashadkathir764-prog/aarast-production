#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');
const { eraseFixtureAccount } = require('./account-grace');

/**
 * Canonical money budget + costs smoke.
 *
 * Exercises the canonical pre-launch money domain only:
 * money budget, categories, wedding costs, append-only payments, and the
 * unified canViewMoney/canManageMoney permission boundary.
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
    console.log(`PASS - ${label}`);
    passed++;
  } else {
    console.log(`FAIL - ${label}`);
    failed++;
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
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
      },
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

function hasSensitiveAuthData(value) {
  const serialized = JSON.stringify(value);
  return serialized.includes('passwordHash') || serialized.includes('refreshTokenHash');
}

async function register(name, value) {
  const response = await registerVerified(request, {
    name,
    phone: value,
    password: TEST_PASSWORD,
  });
  check(`${name} registration succeeds`, response.status === 201);
  check(`${name} registration returns an access token`, typeof response.body?.accessToken === 'string');
  check(`${name} registration does not expose auth secrets`, !hasSensitiveAuthData(response.body));
  return {
    token: response.body?.accessToken,
    userId: response.body?.user?.id,
    phone: value,
  };
}

async function cleanupAccount(label, token) {
  if (!token) return;
  check(`${label} fixture account is cleaned`, await eraseFixtureAccount(request, token));
}

async function run() {
  console.log('\nMoney Budget + Costs Smoke Report');
  console.log(`Target: ${BASE_URL}\n`);

  const accounts = [];
  try {
    const owner = await register('Money budget owner', phone(1));
    const viewer = await register('Money budget viewer', phone(2));
    const manager = await register('Money budget manager', phone(3));
    const unrelated = await register('Money unrelated user', phone(4));
    accounts.push(
      ['viewer', viewer.token],
      ['manager', manager.token],
      ['unrelated', unrelated.token],
      ['owner', owner.token],
    );

    if (!owner.token || !viewer.token || !manager.token || !unrelated.token) {
      throw new Error('registration setup failed');
    }

    const plan = await request('POST', '/api/v1/wedding-plans', {
      title: 'Unified money budget smoke plan',
      city: 'Sanaa',
    }, owner.token);
    check('money smoke plan is created', plan.status === 201 && typeof plan.body?.id === 'string');
    const planId = plan.body?.id;
    if (!planId) throw new Error(`plan setup failed with HTTP ${plan.status}`);

    // RA-BE-42: participants join by accepting an invite (P5).
    const viewerMember = await inviteAndAccept(request, {
      planId,
      inviterToken: owner.token,
      member: viewer,
      access: { role: 'VIEWER', canViewMoney: true },
    });
    check('owner grants unified money read permission', viewerMember.status === 201 && viewerMember.body?.canViewMoney === true);

    const managerMember = await inviteAndAccept(request, {
      planId,
      inviterToken: owner.token,
      member: manager,
      // D52 (J2-05): «يشوف بس» manages no money; the money manager is one.
      access: { role: 'FINANCE_MANAGER', canViewMoney: true, canManageMoney: true },
    });
    check(
      'owner grants unified money management permission',
      managerMember.status === 201 &&
        managerMember.body?.canViewMoney === true &&
        managerMember.body?.canManageMoney === true,
    );

    const emptyBudget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      { totalBudget: '1000000', currency: 'YER', categories: [] },
      owner.token,
    );
    check(
      'owner can save a budget before adding categories',
      emptyBudget.status === 200 && emptyBudget.body?.categories?.length === 0,
    );

    const hallClientId = randomUUID();
    const attireClientId = randomUUID();
    const budget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      {
        totalBudget: '1000000',
        currency: 'YER',
        categories: [
          { clientId: hallClientId, name: 'Hall', allocatedAmount: '600000' },
          { clientId: attireClientId, name: 'Attire', allocatedAmount: '300000' },
        ],
      },
      owner.token,
    );
    check('owner atomically saves the money budget', budget.status === 200);
    check('money budget returns its canonical summary', budget.body?.summary?.budget?.total === '1000000');
    check('money budget returns both saved categories', budget.body?.categories?.length === 2);
    check(
      'money budget maps local category UUIDs to server ids',
      typeof budget.body?.idMap?.[hallClientId] === 'string' &&
        typeof budget.body?.idMap?.[attireClientId] === 'string',
    );
    const hallCategoryId = budget.body?.idMap?.[hallClientId];
    const attireCategoryId = budget.body?.idMap?.[attireClientId];
    if (!hallCategoryId || !attireCategoryId) throw new Error('money budget setup failed');

    const viewerBudget = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      viewer.token,
    );
    check('money viewer reads the unified summary', viewerBudget.status === 200);
    check('money viewer receives read-only permissions', viewerBudget.body?.permissions?.canViewMoney === true && viewerBudget.body?.permissions?.canManageMoney === false);

    const viewerBudgetWrite = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      {
        totalBudget: '1000000',
        currency: 'YER',
        categories: [
          { id: hallCategoryId, name: 'Hall', allocatedAmount: '600000' },
          { id: attireCategoryId, name: 'Attire', allocatedAmount: '300000' },
        ],
      },
      viewer.token,
    );
    // RA-BE-40: a member's refused write says why (403); 404 «the plan was
    // not found» told a member their plan was gone.
    check(
      'read-only money viewer cannot replace the budget',
      viewerBudgetWrite.status === 403 && viewerBudgetWrite.body?.code === 'SECTION_PERMISSION_MISSING',
    );

    const managerBudget = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      {
        totalBudget: '1000000',
        currency: 'YER',
        categories: [
          { id: hallCategoryId, name: 'Wedding hall', allocatedAmount: '650000' },
          { id: attireCategoryId, name: 'Attire', allocatedAmount: '300000' },
        ],
      },
      manager.token,
    );
    check('contributor cannot replace the owner plan budget', managerBudget.status === 404);

    const cost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: hallCategoryId,
        title: 'Hall agreement',
        totalAmount: '400000',
        initialPaymentAmount: '250000',
        partyName: 'External hall',
        agreementDate: new Date().toISOString(),
      },
      owner.token,
    );
    check('owner creates a wedding cost with an initial payment', cost.status === 201 && typeof cost.body?.id === 'string');
    check('rejected contributor budget update leaves the owner category unchanged', cost.body?.budgetCategoryId === hallCategoryId && cost.body?.categoryName === 'Hall');
    check('created cost reports paid and remaining balances', cost.body?.paidAmount === '250000' && cost.body?.remainingAmount === '150000');
    const costId = cost.body?.id;
    if (!costId) throw new Error('cost setup failed');

    const rejectUsedCategoryDeletion = await request(
      'PUT',
      `/api/v1/wedding-plans/${planId}/money-budget`,
      { totalBudget: '1000000', currency: 'YER', categories: [] },
      owner.token,
    );
    check(
      'empty category replacement cannot delete a category used by a cost',
      rejectUsedCategoryDeletion.status === 409,
    );

    const listForViewer = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/costs`,
      null,
      viewer.token,
    );
    check('money viewer reads paginated costs', listForViewer.status === 200 && Array.isArray(listForViewer.body?.items));
    check('money viewer cannot see an owner-created cost outside their contribution scope', !listForViewer.body?.items?.some((item) => item.id === costId));

    const viewerCostWrite = await request(
      'PATCH',
      `/api/v1/costs/${costId}`,
      { title: 'Forbidden viewer update' },
      viewer.token,
    );
    // RA-BE-40: refused with its reason, as above.
    check(
      'read-only money viewer cannot edit a cost',
      viewerCostWrite.status === 403 && viewerCostWrite.body?.code === 'SECTION_PERMISSION_MISSING',
    );

    const managerCategory = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/budget-categories`,
      { name: 'Manager category' },
      manager.token,
    );
    check(
      'money contributor creates an isolated category',
      managerCategory.status === 201 && typeof managerCategory.body?.id === 'string',
    );
    const managerCategoryId = managerCategory.body?.id;
    if (!managerCategoryId) throw new Error('manager category setup failed');

    const managerCategories = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/budget-categories`,
      null,
      manager.token,
    );
    check(
      'money contributor sees only their own category',
      managerCategories.status === 200 &&
        managerCategories.body?.length === 1 &&
        managerCategories.body?.[0]?.id === managerCategoryId,
    );

    const managerCost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        budgetCategoryId: managerCategoryId,
        title: 'Temporary manager cost',
        totalAmount: '100000',
      },
      manager.token,
    );
    check('money contributor creates a cost in their own category', managerCost.status === 201 && typeof managerCost.body?.id === 'string');
    const managerCostId = managerCost.body?.id;
    if (!managerCostId) throw new Error('manager cost setup failed');

    const managerCostUpdate = await request(
      'PATCH',
      `/api/v1/costs/${managerCostId}`,
      { title: 'Updated manager cost', totalAmount: '120000' },
      manager.token,
    );
    check('money manager updates a cost', managerCostUpdate.status === 200 && managerCostUpdate.body?.totalAmount === '120000');

    const managerCostDelete = await request(
      'DELETE',
      `/api/v1/costs/${managerCostId}`,
      null,
      manager.token,
    );
    check('a cost without ledger history can be deleted', managerCostDelete.status === 200 && managerCostDelete.body?.deleted === true);

    const payment = await request(
      'POST',
      `/api/v1/costs/${costId}/payments`,
      { amount: '50000', method: 'cash', note: 'Smoke payment' },
      owner.token,
    );
    check('owner records an append-only cost payment', payment.status === 201 && payment.body?.entryType === 'PAYMENT');
    check('payment inherits plan, category, and cost', payment.body?.weddingPlanId === planId && payment.body?.budgetCategoryId === hallCategoryId && payment.body?.costId === costId);
    const paymentId = payment.body?.id;
    if (!paymentId) throw new Error('payment setup failed');

    const reversal = await request(
      'POST',
      `/api/v1/cost-payments/${paymentId}/reverse`,
      { reason: 'Smoke reversal' },
      owner.token,
    );
    check('payment is reversed with a compensating ledger entry', reversal.status === 201 && reversal.body?.entryType === 'REVERSAL' && reversal.body?.reversalOfId === paymentId);

    const refreshedCost = await request('GET', `/api/v1/costs/${costId}`, null, owner.token);
    check('payment reversal restores the cost balance', refreshedCost.status === 200 && refreshedCost.body?.paidAmount === '250000');

    const summary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      owner.token,
    );
    check('unified summary reflects one active cost', summary.status === 200 && summary.body?.costs?.count === 1);
    check('unified summary counts confirmed, paid, and outstanding once', summary.body?.costs?.total === '400000' && summary.body?.costs?.paid === '250000' && summary.body?.costs?.outstanding === '150000');
    check('unified summary reports the remaining general budget', summary.body?.budget?.remaining === '600000');
    check('unified summary does not expose auth secrets', !hasSensitiveAuthData(summary.body));

    const unrelatedSummary = await request(
      'GET',
      `/api/v1/wedding-plans/${planId}/money-summary`,
      null,
      unrelated.token,
    );
    check('unrelated user cannot discover money data', unrelatedSummary.status === 404);

    const noAuth = await request('GET', `/api/v1/wedding-plans/${planId}/costs`);
    check('costs require authentication', noAuth.status === 401);

    // RA-BE-29: «0» meant no allocation in the budget replace and a zero one
    // here, which read the item over budget as soon as it held anything.
    const zeroItem = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Zero allocation item',
      allocatedAmount: '0',
    }, owner.token);
    check('an allocation of 0 is no allocation, as in the budget replace',
      zeroItem.status === 201 && zeroItem.body?.allocatedAmount === null);

    // RA-BE-28: an item the budget replace leaves out is deleted; its tasks
    // kept waiting on it, never to finish by themselves again.
    const dropItem = await request('POST', `/api/v1/wedding-plans/${planId}/budget-categories`, {
      name: 'Item to drop',
    }, owner.token);
    const dropTask = await request('POST', `/api/v1/wedding-plans/${planId}/tasks`, {
      title: 'Book the dropped item',
      linkedBudgetCategoryId: dropItem.body?.id,
    }, owner.token);
    const before = await request('GET', `/api/v1/wedding-plans/${planId}/money-summary`, null, owner.token);
    const kept = (before.body?.categories ?? [])
      .filter((item) => item.kind !== 'MAHR' && item.categoryId !== dropItem.body?.id)
      .map((item) => ({ id: item.categoryId, name: item.name, allocatedAmount: item.allocatedAmount }));
    const replaced = await request('PUT', `/api/v1/wedding-plans/${planId}/money-budget`, {
      totalBudget: '1000000',
      currency: 'YER',
      categories: kept,
    }, owner.token);
    const unlinkedTask = await request('GET', `/api/v1/tasks/${dropTask.body?.id}`, null, owner.token);
    check('a task of an item the replace drops waits on nothing gone',
      dropTask.status === 201 && replaced.status === 200 &&
      unlinkedTask.status === 200 && unlinkedTask.body?.linkedBudgetCategoryId === null);
  } finally {
    for (const [label, token] of accounts) {
      try {
        await cleanupAccount(label, token);
      } catch (error) {
        check(`${label} fixture account cleanup completes`, false);
        console.error(`Cleanup warning (${label}): ${error.message}`);
      }
    }
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Money budget + costs smoke error:', error.message);
  process.exit(1);
});
