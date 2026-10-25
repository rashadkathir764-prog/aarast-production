#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');

/**
 * B5 mahr smoke (C1): the groom's mahr is his agreement with the bride's
 * family, a MAHR item outside the wedding budget; the bride's mahr is money
 * coming in, MAHR funding sources. Recorded once, from a06 at onboarding or
 * from b01's step; private money: a member without money rights never reads
 * it, and the bride's funding stays hers.
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

async function register(name, value) {
  const response = await registerVerified(request, {
    name,
    phone: value,
    password: TEST_PASSWORD,
  });
  check(`${name} registers`, response.status === 201);
  return { token: response.body?.accessToken, userId: response.body?.user?.id };
}

async function cleanupAccount(label, token) {
  if (!token) return;
  const response = await request('DELETE', '/api/v1/users/me', null, token, randomUUID());
  check(`${label} fixture account is cleaned`, response.status === 200 && response.body?.deleted === true);
}

function inDays(days) {
  const date = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

async function onboard(token, persona, extra = {}) {
  const response = await request('POST', '/api/v1/onboarding/complete', {
    path: 'USER',
    persona,
    title: `Mahr smoke ${persona}`,
    city: 'صنعاء',
    estimatedBudget: '7000000',
    currency: 'YER',
    selectedCategories: ['القاعة'],
    ...extra,
  }, token);
  return response;
}

async function run() {
  console.log('\nMahr Smoke Report (B5)');
  console.log(`Target: ${BASE_URL}\n`);
  const accounts = [];
  try {
    const groom = await register('Mahr groom', phone(11));
    const bride = await register('Mahr bride', phone(12));
    const family = await register('Mahr family without money', phone(13));
    const partner = await register('Mahr partner with money', phone(14));
    const helper = await register('Mahr helper owner', phone(15));
    accounts.push(
      ['family', family.token],
      ['partner', partner.token],
      ['helper', helper.token],
      ['bride', bride.token],
      ['groom', groom.token],
    );
    if (![groom, bride, family, partner, helper].every((account) => account.token)) {
      throw new Error('registration setup failed');
    }

    const restDay = inDays(21);
    // a06 at onboarding: the groom's agreement with the bride's family.
    const groomPlan = await onboard(groom.token, 'GROOM', {
      mahr: { total: '3000000', settled: '2000000', remainingDueDate: restDay },
    });
    check('the groom saves his plan with the mahr', groomPlan.status === 201);
    const groomPlanId = groomPlan.body?.activeWeddingPlan?.id;
    if (!groomPlanId) throw new Error('groom plan setup failed');

    const groomMoney = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/money-summary`, null, groom.token);
    const mahr = groomMoney.body?.mahr;
    check('the groom pays the mahr', mahr?.side === 'PAYS');
    check('his mahr reads 3,000,000 agreed, 2,000,000 handed over, 1,000,000 left',
      mahr?.total === '3000000' && mahr?.settled === '2000000' && mahr?.remaining === '1000000');
    check('the rest is due on its day', typeof mahr?.nextDueAt === 'string' && mahr.nextDueAt.startsWith(restDay));
    check('his agreements count the mahr', groomMoney.body?.costs?.total === '3000000' && groomMoney.body?.costs?.paid === '2000000');
    check('the wedding budget does not (C1)',
      groomMoney.body?.budget?.confirmedCost === '0' && groomMoney.body?.budget?.remaining === '7000000');
    const mahrItem = (groomMoney.body?.categories ?? []).find((item) => item.kind === 'MAHR');
    check('the mahr is its own item outside the budget', mahrItem?.name === 'المهر' && mahrItem?.allocatedAmount === null);

    const again = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/mahr`, { total: '3000000' }, groom.token);
    check('the mahr is recorded once', again.status === 409 && again.body?.code === 'MAHR_ALREADY_RECORDED');

    const allocate = await request('PATCH', `/api/v1/budget-categories/${mahrItem?.categoryId}`, { allocatedAmount: '500000' }, groom.token);
    check('the mahr item takes no allocation', allocate.status === 400 && allocate.body?.code === 'MAHR_OUTSIDE_BUDGET');

    const replace = await request('PUT', `/api/v1/wedding-plans/${groomPlanId}/money-budget`, {
      totalBudget: '7000000',
      currency: 'YER',
      categories: [],
    }, groom.token);
    check('replacing the budget leaves the mahr item',
      replace.status === 200 && replace.body?.summary?.mahr?.total === '3000000' &&
      (replace.body?.categories ?? []).every((item) => item.name !== 'المهر'));

    // Privacy: a member without money rights never reads the mahr.
    const familyMember = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/members`, {
      userId: family.userId,
      role: 'FAMILY',
      canViewMoney: false,
      canManageMoney: false,
    }, groom.token);
    check('the groom adds family without money rights', familyMember.status === 201);
    const familyMoney = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/money-summary`, null, family.token);
    check('family without money rights cannot read the mahr', familyMoney.status !== 200 && !JSON.stringify(familyMoney.body ?? '').includes('3000000'));
    const familyView = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/plan-view`, null, family.token);
    check('the plan view carries no mahr amount', familyView.status === 200 && !JSON.stringify(familyView.body).includes('3000000'));

    // The bride receives it: money coming in, from b01's step.
    const bridePlan = await onboard(bride.token, 'BRIDE');
    const bridePlanId = bridePlan.body?.activeWeddingPlan?.id;
    check('the bride saves her plan', bridePlan.status === 201 && typeof bridePlanId === 'string');
    const tooMuch = await request('POST', `/api/v1/wedding-plans/${bridePlanId}/mahr`, { total: '3000000', settled: '3000001' }, bride.token);
    check('received above the mahr is refused', tooMuch.status === 400);
    const brideMahr = await request('POST', `/api/v1/wedding-plans/${bridePlanId}/mahr`, {
      total: '3000000',
      settled: '2000000',
      remainingDueDate: restDay,
    }, bride.token);
    check('the bride records her mahr', brideMahr.status === 201 && brideMahr.body?.mahr?.side === 'RECEIVES');
    check('her mahr is money in: 2,000,000 received, 1,000,000 promised',
      brideMahr.body?.funding?.received === '2000000' && brideMahr.body?.funding?.pledged === '1000000');
    check('her costs do not count the mahr', brideMahr.body?.costs?.total === '0');
    const sources = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/funding-sources`, null, bride.token);
    const mahrSources = (sources.body ?? []).filter((source) => source.kind === 'MAHR');
    check('her «من وين» lists the mahr received and its rest with its day',
      mahrSources.length === 2 &&
      mahrSources.some((source) => source.status === 'RECEIVED' && source.amount === '2000000') &&
      mahrSources.some((source) => source.status === 'PLEDGED' && source.amount === '1000000' &&
        typeof source.expectedAt === 'string' && source.expectedAt.startsWith(restDay)));

    const partnerMember = await request('POST', `/api/v1/wedding-plans/${bridePlanId}/members`, {
      userId: partner.userId,
      role: 'GROOM',
      canViewMoney: true,
      canManageMoney: true,
    }, bride.token);
    check('the bride adds her partner with money rights', partnerMember.status === 201);
    const partnerMoney = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, partner.token);
    check('her mahr stays hers: the partner reads money without it',
      partnerMoney.status === 200 && partnerMoney.body?.mahr === null && partnerMoney.body?.funding === null);

    // A plan without a groom's or a bride's persona has no mahr side.
    const helperPlan = await onboard(helper.token, 'HELPER');
    const helperPlanId = helperPlan.body?.activeWeddingPlan?.id;
    const helperMahr = await request('POST', `/api/v1/wedding-plans/${helperPlanId}/mahr`, { total: '1000000' }, helper.token);
    check('a helper\'s plan takes no mahr', helperMahr.status === 409 && helperMahr.body?.code === 'MAHR_NOT_FOR_PLAN');

    // The groom hands over the rest on its day: the mahr is complete.
    const costs = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/costs`, null, groom.token);
    const mahrCost = (costs.body?.items ?? costs.body ?? []).find((cost) => cost.budgetCategoryId === mahrItem?.categoryId);
    const schedules = await request('GET', `/api/v1/costs/${mahrCost?.id}/payment-schedules`, null, groom.token);
    const rest = (schedules.body?.items ?? schedules.body ?? [])[0];
    const pay = await request('POST', `/api/v1/payment-schedules/${rest?.id}/pay`, {}, groom.token, randomUUID());
    check('the groom records handing over the rest', pay.status === 201 || pay.status === 200);
    const done = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/money-summary`, null, groom.token);
    check('his mahr is complete (y08)', done.body?.mahr?.complete === true && done.body?.mahr?.remaining === '0');
  } catch (error) {
    check(`mahr smoke completes without error: ${error.message}`, false);
  } finally {
    for (const [label, token] of accounts) {
      await cleanupAccount(label, token);
    }
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run();
