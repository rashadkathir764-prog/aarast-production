#!/usr/bin/env node
'use strict';

/**
 * Debt + Installment Smoke Test
 * Tests the debt/installment backend slice without creating future modules.
 */

const http = require('http');

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3127';
const timestamp = Date.now();
const suffix = `${timestamp.toString().slice(-4)}${Math.floor(Math.random() * 90 + 10)}`;
const OWNER_PHONE = `+96740${suffix}`;
const DEBT_VIEWER_PHONE = `+96741${suffix}`;
const FINANCE_MANAGER_PHONE = `+96742${suffix}`;
const UNRELATED_PHONE = `+96743${suffix}`;
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
  const res = await request('POST', '/auth/register', {
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
  console.log('\nDebt + Installment Smoke Report');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Owner phone: ${OWNER_PHONE}`);
  console.log(`Debt viewer phone: ${DEBT_VIEWER_PHONE}`);
  console.log(`Finance manager phone: ${FINANCE_MANAGER_PHONE}`);
  console.log(`Unrelated phone: ${UNRELATED_PHONE}\n`);

  let ownerToken = null;
  let debtViewerToken = null;
  let debtViewerUserId = null;
  let financeManagerToken = null;
  let financeManagerUserId = null;
  let unrelatedToken = null;
  let weddingPlanId = null;
  let debtId = null;
  let managerDebtId = null;
  let installmentId = null;
  let managerInstallmentId = null;

  {
    const owner = await register('Debt Installment Smoke Owner', OWNER_PHONE);
    check('owner register - HTTP 201', owner.status === 201);
    check('owner register returns token', typeof owner.token === 'string');
    check('owner register does not expose passwordHash', !hasPasswordHash(owner.body));
    ownerToken = owner.token;
  }

  {
    const debtViewer = await register('Debt Viewer Smoke Member', DEBT_VIEWER_PHONE);
    check('debt viewer register - HTTP 201', debtViewer.status === 201);
    check('debt viewer register returns token', typeof debtViewer.token === 'string');
    check('debt viewer has user id', typeof debtViewer.user?.id === 'string');
    check('debt viewer register does not expose passwordHash', !hasPasswordHash(debtViewer.body));
    debtViewerToken = debtViewer.token;
    debtViewerUserId = debtViewer.user?.id;
  }

  {
    const financeManager = await register('Debt Finance Manager Smoke Member', FINANCE_MANAGER_PHONE);
    check('finance manager register - HTTP 201', financeManager.status === 201);
    check('finance manager register returns token', typeof financeManager.token === 'string');
    check('finance manager has user id', typeof financeManager.user?.id === 'string');
    check('finance manager register does not expose passwordHash', !hasPasswordHash(financeManager.body));
    financeManagerToken = financeManager.token;
    financeManagerUserId = financeManager.user?.id;
  }

  {
    const unrelated = await register('Unrelated Debt Installment User', UNRELATED_PHONE);
    check('unrelated user register - HTTP 201', unrelated.status === 201);
    check('unrelated user register returns token', typeof unrelated.token === 'string');
    check('unrelated user register does not expose passwordHash', !hasPasswordHash(unrelated.body));
    unrelatedToken = unrelated.token;
  }

  {
    const res = await request('POST', '/wedding-plans', {
      title: 'Debt Installment Smoke Plan',
      city: 'Sanaa',
    }, ownerToken);
    check('POST /wedding-plans - HTTP 201', res.status === 201);
    check('created wedding plan has id', typeof res.body?.id === 'string');
    check('wedding plan does not expose passwordHash', !hasPasswordHash(res.body));
    weddingPlanId = res.body?.id;
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/shared-members`, {
      userId: debtViewerUserId,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: false,
      canViewDebts: true,
      canManageTasks: false,
      canManageFinancialRecords: false,
    }, ownerToken);
    check('owner grants debt read permission - HTTP 201', res.status === 201);
    check('debt read permission enabled', res.body?.canViewDebts === true);
    check('debt permission response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/shared-members`, {
      userId: financeManagerUserId,
      role: 'VIEWER',
      canViewBudget: false,
      canViewExpenses: false,
      canViewDebts: false,
      canManageTasks: false,
      canManageFinancialRecords: true,
    }, ownerToken);
    check('owner grants debt financial management permission - HTTP 201', res.status === 201);
    check('debt financial management permission enabled', res.body?.canManageFinancialRecords === true);
    check('debt financial management response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/debts`, {
      creditorName: 'Wedding Hall Vendor',
      title: 'Hall remaining balance',
      totalAmount: '500000.00',
      paidAmount: '100000.00',
      dueDate: '2026-12-10T00:00:00.000Z',
      status: 'PARTIALLY_PAID',
      note: 'Smoke debt',
    }, ownerToken);
    check('POST debt - HTTP 201', res.status === 201);
    check('created debt has id', typeof res.body?.id === 'string');
    check('created debt belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created debt totalAmount is string', res.body?.totalAmount === '500000');
    check('created debt paidAmount is string', res.body?.paidAmount === '100000');
    check('created debt status is PARTIALLY_PAID', res.body?.status === 'PARTIALLY_PAID');
    check('created debt without phone returns null', res.body?.creditorPhone === null);
    check('debt does not expose passwordHash', !hasPasswordHash(res.body));
    debtId = res.body?.id;
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`, null, ownerToken);
    check('GET debts - HTTP 200', res.status === 200);
    check('debt list is array', Array.isArray(res.body));
    check('debt list includes created debt', Array.isArray(res.body) && res.body.some((debt) => debt.id === debtId));
    check('debt list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts/summary`, null, ownerToken);
    check('GET debt summary - HTTP 200', res.status === 200);
    check('summary totalDebt is correct', res.body?.totalDebt === '500000.00');
    check('summary totalPaid is correct', res.body?.totalPaid === '100000.00');
    check('summary remainingDebt is correct', res.body?.remainingDebt === '400000.00');
    check('summary countPartiallyPaid is correct', res.body?.countPartiallyPaid === 1);
    check('summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`, null, debtViewerToken);
    check('debt viewer reads debts - HTTP 200', res.status === 200);
    check('debt viewer sees created debt', Array.isArray(res.body) && res.body.some((debt) => debt.id === debtId));
    check('debt viewer list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts/summary`, null, debtViewerToken);
    check('debt viewer reads debt summary - HTTP 200', res.status === 200);
    check('debt viewer summary remainingDebt is correct', res.body?.remainingDebt === '400000.00');
    check('debt viewer summary does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/wedding-plans/${weddingPlanId}/debts`, {
      creditorName: 'Shared Managed Vendor',
      creditorPhone: '  +967 777 123 456  ',
      title: 'Shared managed balance',
      totalAmount: '100000.00',
      paidAmount: '25000.00',
      status: 'PARTIALLY_PAID',
      note: 'Finance manager smoke debt',
    }, financeManagerToken);
    check('finance manager creates debt - HTTP 201', res.status === 201);
    check('finance manager-created debt has id', typeof res.body?.id === 'string');
    check('finance manager-created debt belongs to plan', res.body?.weddingPlanId === weddingPlanId);
    check('created debt phone is trimmed', res.body?.creditorPhone === '+967 777 123 456');
    check('finance manager-created debt does not expose passwordHash', !hasPasswordHash(res.body));
    managerDebtId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/debts/${managerDebtId}`, {
      title: 'Updated shared managed debt',
      totalAmount: '125000.00',
      creditorPhone: '  01 234 567  ',
    }, financeManagerToken);
    check('finance manager updates debt - HTTP 200', res.status === 200);
    check('finance manager-updated debt title changed', res.body?.title === 'Updated shared managed debt');
    check('finance manager-updated debt totalAmount changed', res.body?.totalAmount === '125000');
    check('updated debt phone is trimmed', res.body?.creditorPhone === '01 234 567');
    check('finance manager-updated debt does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('PATCH', `/debts/${managerDebtId}`, {
      creditorPhone: '   ',
    }, financeManagerToken);
    check('finance manager clears debt phone - HTTP 200', res.status === 200);
    check('blank debt phone is stored as null', res.body?.creditorPhone === null);
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`, null, unrelatedToken);
    check('unrelated user cannot read debts', res.status === 404);
  }

  {
    const res = await request('PATCH', `/debts/${debtId}`, {
      creditorName: 'Updated Vendor',
      creditorPhone: '  +967 733 456 789  ',
      title: 'Updated debt',
      totalAmount: '600000.00',
      paidAmount: '150000.00',
      status: 'OPEN',
      note: 'Updated smoke debt',
    }, ownerToken);
    check('PATCH debt - HTTP 200', res.status === 200);
    check('updated debt creditor changed', res.body?.creditorName === 'Updated Vendor');
    check('update adds and trims debt phone', res.body?.creditorPhone === '+967 733 456 789');
    check('updated debt title changed', res.body?.title === 'Updated debt');
    check('updated debt totalAmount changed', res.body?.totalAmount === '600000');
    check('updated debt status changed', res.body?.status === 'OPEN');
    check('updated debt does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/debts/${debtId}/installments`, {
      amount: '200000.00',
      dueDate: '2026-12-15T00:00:00.000Z',
      status: 'PENDING',
      note: 'Smoke installment',
    }, ownerToken);
    check('POST installment - HTTP 201', res.status === 201);
    check('created installment has id', typeof res.body?.id === 'string');
    check('created installment belongs to debt', res.body?.debtId === debtId);
    check('created installment amount is string', res.body?.amount === '200000');
    check('created installment status is PENDING', res.body?.status === 'PENDING');
    check('installment does not expose passwordHash', !hasPasswordHash(res.body));
    installmentId = res.body?.id;
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`, null, ownerToken);
    check('GET installments - HTTP 200', res.status === 200);
    check('installment list is array', Array.isArray(res.body));
    check('installment list includes created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('installment list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/installments/due`, null, ownerToken);
    check('GET due installments - HTTP 200', res.status === 200);
    check('due installment list is array', Array.isArray(res.body));
    check('due installment list includes created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('due installment list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`, null, debtViewerToken);
    check('debt viewer reads installments - HTTP 200', res.status === 200);
    check('debt viewer sees created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('debt viewer installment list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/installments/due`, null, debtViewerToken);
    check('debt viewer reads due installments - HTTP 200', res.status === 200);
    check('debt viewer due list includes created installment', Array.isArray(res.body) && res.body.some((installment) => installment.id === installmentId));
    check('debt viewer due list does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('POST', `/debts/${managerDebtId}/installments`, {
      amount: '50000.00',
      dueDate: '2026-12-20T00:00:00.000Z',
      status: 'PENDING',
      note: 'Finance manager smoke installment',
    }, financeManagerToken);
    check('finance manager creates installment - HTTP 201', res.status === 201);
    check('finance manager-created installment has id', typeof res.body?.id === 'string');
    check('finance manager-created installment belongs to debt', res.body?.debtId === managerDebtId);
    check('finance manager-created installment does not expose passwordHash', !hasPasswordHash(res.body));
    managerInstallmentId = res.body?.id;
  }

  {
    const res = await request('PATCH', `/installments/${managerInstallmentId}`, {
      amount: '60000.00',
      status: 'OVERDUE',
    }, financeManagerToken);
    check('finance manager updates installment - HTTP 200', res.status === 200);
    check('finance manager-updated installment amount changed', res.body?.amount === '60000');
    check('finance manager-updated installment status changed', res.body?.status === 'OVERDUE');
    check('finance manager-updated installment does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`, null, unrelatedToken);
    check('unrelated user cannot read installments', res.status === 404);
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/installments/due`, null, unrelatedToken);
    check('unrelated user cannot read due installments', res.status === 404);
  }

  {
    const res = await request('PATCH', `/installments/${installmentId}`, {
      amount: '250000.00',
      status: 'PAID',
      paidAt: '2026-12-16T00:00:00.000Z',
      note: 'Updated smoke installment',
    }, ownerToken);
    check('PATCH installment - HTTP 200', res.status === 200);
    check('updated installment amount changed', res.body?.amount === '250000');
    check('updated installment status changed', res.body?.status === 'PAID');
    check('updated installment paidAt exists', typeof res.body?.paidAt === 'string');
    check('updated installment does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/installments/${managerInstallmentId}`, null, financeManagerToken);
    check('finance manager deletes installment - HTTP 200', res.status === 200);
    check('finance manager-deleted installment id returned', res.body?.id === managerInstallmentId);
    check('finance manager delete installment response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/debts/${managerDebtId}`, null, financeManagerToken);
    check('finance manager deletes debt - HTTP 200', res.status === 200);
    check('finance manager-deleted debt id returned', res.body?.id === managerDebtId);
    check('finance manager delete debt response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/installments/${installmentId}`, null, ownerToken);
    check('DELETE installment - HTTP 200', res.status === 200);
    check('deleted installment id returned', res.body?.id === installmentId);
    check('delete installment response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('DELETE', `/debts/${debtId}`, null, ownerToken);
    check('DELETE debt - HTTP 200', res.status === 200);
    check('deleted debt id returned', res.body?.id === debtId);
    check('delete debt response does not expose passwordHash', !hasPasswordHash(res.body));
  }

  {
    const res = await request('GET', `/wedding-plans/${weddingPlanId}/debts`);
    check('GET debts without token returns 401', res.status === 401);
  }

  {
    const res = await request('GET', `/debts/${debtId}/installments`);
    check('GET installments without token returns 401', res.status === 401);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Debt + Installment smoke error:', err.message);
  process.exit(1);
});
