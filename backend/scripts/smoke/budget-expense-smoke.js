#!/usr/bin/env node
'use strict';

const { registerVerified } = require('./verified-registration');

/**
 * Budget + Expense Smoke Test
 * Tests the first financial backend slice without creating future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+96730${suffix}`;
const BUDGET_VIEWER_PHONE = `+96731${suffix}`;
const EXPENSE_VIEWER_PHONE = `+96732${suffix}`;
const FINANCE_MANAGER_PHONE = `+96733${suffix}`;
const UNRELATED_PHONE = `+96734${suffix}`;
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
  console.log('\nBudget + Expense Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Budget viewer phone: ${BUDGET_VIEWER_PHONE}`);
  console.log(`Expense viewer phone: ${EXPENSE_VIEWER_PHONE}`);
  console.log(`Finance manager phone: ${FINANCE_MANAGER_PHONE}`);
  console.log(`Unrelated phone: ${UNRELATED_PHONE}\n`);

  let ownerToken = null;
  let budgetViewerToken = null;
  let budgetViewerUserId = null;
  let expenseViewerToken = null;
  let expenseViewerUserId = null;
  let financeManagerToken = null;
  let financeManagerUserId = null;
  let unrelatedToken = null;
  let weddingPlanId = null;
  let categoryId = null;
  let managerCategoryId = null;
  let expenseId = null;
  let managerExpenseId = null;

  {
    const owner = await register('Budget Expense Smoke Owner', OWNER_PHONE);
    check('owner register - HTTP 201', owner.status === 201);
    check('owner register returns token', typeof owner.token === 'string');
    check('owner register does not expose passwordHash', !hasPasswordHash(owner.body));
    ownerToken = owner.token;
  }

  {
    const budgetViewer = await register('Budget Viewer Smoke Member', BUDGET_VIEWER_PHONE);
    check('budget viewer register - HTTP 201', budgetViewer.status === 201);
    check('budget viewer register returns token', typeof budgetViewer.token === 'string');
    check('budget viewer has user id', typeof budgetViewer.user?.id === 'string');
    check('budget viewer register does not expose passwordHash', !hasPasswordHash(budgetViewer.body));
    budgetViewerToken = budgetViewer.token;
    budgetViewerUserId = budgetViewer.user?.id;
  }

  {
    const expenseViewer = await register('Expense Viewer Smoke Member', EXPENSE_VIEWER_PHONE);
    check('expense viewer register - HTTP 201', expenseViewer.status === 201);
    check('expense viewer register returns token', typeof expenseViewer.token === 'string');
    check('expense viewer has user id', typeof expenseViewer.user?.id === 'string');
    check('expense viewer register does not expose passwordHash', !hasPasswordHash(expenseViewer.body));
    expenseViewerToken = expenseViewer.token;
    expenseViewerUserId = expenseViewer.user?.id;
  }

  {
    const financeManager = await register('Finance Manager Smoke Member', FINANCE_MANAGER_PHONE);
    check('finance manager register - HTTP 201', financeManager.status === 201);
    check('finance manager register returns token', typeof financeManager.token === 'string');
    check('finance manager has user id', typeof financeManager.user?.id === 'string');
    check('finance manager register does not expose passwordHash', !hasPasswordHash(financeManager.body));
    financeManagerToken = financeManager.token;
    financeManagerUserId = financeManager.user?.id;
  }

  {
    const unrelated = await register('Unrelated Budget Expense User', UNRELATED_PHONE);
    check('unrelated user register - HTTP 201', unrelated.status === 201);
    check('unrelated user register returns token', typeof unrelated.token === 'string');
    check('unrelated user register does not expose passwordHash', !hasPasswordHash(unrelated.body));
    unrelatedToken = unrelated.token;
  }

  {
    const res = await request('POST', '/api/v1/wedding-plans', {
      title: 'Budget Expense Smoke Plan',
      city: 'Sanaa',
    }, ownerToken);
    check('POST /api/v1/wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: budgetViewerUserId,
      role: 'VIEWER',
      canViewBudget: true,
      canViewExpenses: false,
      canViewFinancialRecords: false,
      canManageTasks: false,
      canManageFinancialRecords: false,
    }, ownerToken);
    check('owner grants budget read permission - HTTP 201', res.status === 201);
    check('budget read permission enabled', res.body?.canViewBudget === true);
    check('budget permission response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: expenseViewerUserId,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: true,
      canViewFinancialRecords: false,
      canManageTasks: false,
      canManageFinancialRecords: false,
    }, ownerToken);
    check('owner grants expense read permission - HTTP 201', res.status === 201);
    check('expense read permission enabled', res.body?.canViewExpenses === true);
    check('expense permission response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/members`, {
      userId: financeManagerUserId,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: false,
      canViewFinancialRecords: false,
      canManageTasks: false,
      canManageFinancialRecords: true,
    }, ownerToken);
    check('owner grants financial management permission - HTTP 201', res.status === 201);
    check('financial management permission enabled', res.body?.canManageFinancialRecords === true);
    check('financial management response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, {
      name: 'Hall',
      targetAmount: '1000000.00',
    }, ownerToken);
    check('POST budget category - HTTP 201', res.status === 201);
    check('created category has id', typeof res.body?.id === 'string');
    check('created category belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created category targetAmount is string', res.body?.targetAmount === '1000000');
    check('budget category does not expose passwordHash', !hasPasswordHash(res.body));
    categoryId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, null, ownerToken);
    check('GET budget categories - HTTP 200', res.status === 200);
    check('budget category list is array', Array.isArray(res.body));
    check('budget category list includes created category', Array.isArray(res.body) && res.body.some((category) => category.id === categoryId));
    check('budget category list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, null, budgetViewerToken);
    check('budget viewer reads budget categories - HTTP 200', res.status === 200);
    check('budget viewer sees created category', Array.isArray(res.body) && res.body.some((category) => category.id === categoryId));
    check('budget viewer category list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, {
      name: 'Shared Managed Category',
      targetAmount: '150000.00',
    }, financeManagerToken);
    check('finance manager creates budget category - HTTP 201', res.status === 201);
    check('finance manager-created category has id', typeof res.body?.id === 'string');
    check('finance manager-created category belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('finance manager-created category does not expose passwordHash', !hasPasswordHash(res.body));
    managerCategoryId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/budget-categories/${managerCategoryId}`, {
      name: 'Updated Shared Managed Category',
    }, financeManagerToken);
    check('finance manager updates budget category - HTTP 200', res.status === 200);
    check('finance manager-updated category name changed', res.body?.name === 'Updated Shared Managed Category');
    check('finance manager-updated category does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/budget-categories`, null, unrelatedToken);
    check('unrelated user cannot read budget categories', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/budget-categories/${categoryId}`, {
      name: 'Updated Hall',
      targetAmount: '1200000.00',
    }, ownerToken);
    check('PATCH budget category - HTTP 200', res.status === 200);
    check('updated category name changed', res.body?.name === 'Updated Hall');
    check('updated category belongs to same plan', res.body?.weddingPlanId === weddingPlanId);
    check('updated category does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, {
      title: 'Hall Deposit',
      amount: '250000.00',
      budgetCategoryId: categoryId,
      status: 'PAID',
      expenseDate: '2026-12-01T00:00:00.000Z',
      note: 'Smoke expense',
    }, ownerToken);
    check('POST expense - HTTP 201', res.status === 201);
    check('created expense has id', typeof res.body?.id === 'string');
    check('created expense belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created expense belongs to category', res.body?.budgetCategoryId === categoryId);
    check('created expense status is PAID', res.body?.status === 'PAID');
    check('created expense amount is string', res.body?.amount === '250000');
    check('expense does not expose passwordHash', !hasPasswordHash(res.body));
    expenseId = res.body?.id;
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, null, ownerToken);
    check('GET expenses - HTTP 200', res.status === 200);
    check('expense list is array', Array.isArray(res.body));
    check('expense list includes created expense', Array.isArray(res.body) && res.body.some((expense) => expense.id === expenseId));
    check('expense list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses/summary`, null, ownerToken);
    check('GET expense summary - HTTP 200', res.status === 200);
    check('summary totalPaid is correct', res.body?.totalPaid === '250000.00');
    check('summary countPaid is correct', res.body?.countPaid === 1);
    check('summary countPlanned is zero', res.body?.countPlanned === 0);
    check('summary countCancelled is zero', res.body?.countCancelled === 0);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, null, expenseViewerToken);
    check('expense viewer reads expenses - HTTP 200', res.status === 200);
    check('expense viewer sees created expense', Array.isArray(res.body) && res.body.some((expense) => expense.id === expenseId));
    check('expense viewer list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses/summary`, null, expenseViewerToken);
    check('expense viewer reads expense summary - HTTP 200', res.status === 200);
    check('expense viewer summary totalPaid is correct', res.body?.totalPaid === '250000.00');
    check('expense viewer summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, {
      title: 'Shared Managed Expense',
      amount: '50000.00',
      budgetCategoryId: managerCategoryId,
      status: 'PAID',
      note: 'Finance manager smoke expense',
    }, financeManagerToken);
    check('finance manager creates expense - HTTP 201', res.status === 201);
    check('finance manager-created expense has id', typeof res.body?.id === 'string');
    check('finance manager-created expense belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('finance manager-created expense does not expose passwordHash', !hasPasswordHash(res.body));
    managerExpenseId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/api/v1/expenses/${managerExpenseId}`, {
      title: 'Updated Shared Managed Expense',
      amount: '75000.00',
    }, financeManagerToken);
    check('finance manager updates expense - HTTP 200', res.status === 200);
    check('finance manager-updated expense title changed', res.body?.title === 'Updated Shared Managed Expense');
    check('finance manager-updated expense amount changed', res.body?.amount === '75000');
    check('finance manager-updated expense does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses`, null, unrelatedToken);
    check('unrelated user cannot read expenses', res.status === 404);
  }

  {
    const res = await request('PATCH', `/api/v1/expenses/${expenseId}`, {
      title: 'Updated Hall Expense',
      amount: '300000.00',
      status: 'PAID',
      note: 'Updated smoke expense',
    }, ownerToken);
    check('PATCH expense - HTTP 200', res.status === 200);
    check('updated expense title changed', res.body?.title === 'Updated Hall Expense');
    check('updated expense amount changed', res.body?.amount === '300000');
    check('updated expense status stays paid', res.body?.status === 'PAID');
    check('updated expense does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/expenses/${managerExpenseId}`, null, financeManagerToken);
    check('finance manager deletes expense - HTTP 200', res.status === 200);
    check('finance manager-deleted expense id returned', res.body?.id === managerExpenseId);
    check('finance manager delete expense response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/budget-categories/${managerCategoryId}`, null, financeManagerToken);
    check('finance manager deletes budget category - HTTP 200', res.status === 200);
    check('finance manager-deleted category id returned', res.body?.id === managerCategoryId);
    check('finance manager delete category response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/expenses/${expenseId}`, null, ownerToken);
    check('DELETE expense - HTTP 200', res.status === 200);
    check('deleted expense id returned', res.body?.id === expenseId);
    check('delete expense response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/api/v1/budget-categories/${categoryId}`, null, ownerToken);
    check('DELETE budget category - HTTP 200', res.status === 200);
    check('deleted category id returned', res.body?.id === categoryId);
    check('delete category response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/api/v1/wedding-plans/${weddingPlanId}/expenses`);
    check('GET expenses without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Budget + Expense smoke error:', err.message);
  process.exit(1);
});
