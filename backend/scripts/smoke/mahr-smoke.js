#!/usr/bin/env node
'use strict';

require('./smoke-isolation-hook');

const http = require('http');
const { randomUUID } = require('crypto');
const { registerVerified } = require('./verified-registration');
const { inviteAndAccept } = require('./invite-member');
const { eraseFixtureAccount } = require('./account-grace');

/**
 * B5 mahr smoke (C1): the groom's mahr is his agreement with the bride's
 * family, a MAHR item outside the wedding budget; the bride's mahr is money
 * coming in, MAHR funding sources. Recorded once, from a06 at onboarding or
 * from b01's step; private money: a member without money rights never reads
 * it, and the bride's funding stays hers. D59: an agreement never moves in
 * or out of the mahr item, mahr funding is the bride's only, what someone
 * else paid never leaves the owner's «معك», a late promise reads late, and a
 * deleted mahr agreement can be recorded again.
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
  return { token: response.body?.accessToken, userId: response.body?.user?.id, phone: value };
}

async function cleanupAccount(label, token) {
  if (!token) return;
  check(`${label} fixture account is cleaned`, await eraseFixtureAccount(request, token));
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
    // RA-BE-42: participants join by accepting an invite (P5).
    const familyMember = await inviteAndAccept(request, {
      planId: groomPlanId,
      inviterToken: groom.token,
      member: family,
      access: { role: 'FAMILY' },
    });
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

    // RA-BE-23: her mahr has no currency of its own, it reads in the plan's.
    // The lock counted agreements alone, so with none she could pick another
    // currency and her 2,000,000 riyals became 2,000,000 of it.
    const lockedSummary = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, bride.token);
    check('her plan reads its currency fixed once her mahr is in', lockedSummary.body?.currencyLocked === true);
    const relabel = await request('PUT', `/api/v1/wedding-plans/${bridePlanId}/money-budget`, {
      totalBudget: '7000000',
      currency: 'SAR',
      categories: [],
    }, bride.token, randomUUID());
    check('the currency does not change under her mahr',
      relabel.status === 409 && relabel.body?.code === 'FINANCE_CURRENCY_LOCKED');
    const still = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, bride.token);
    check('her mahr still reads in her currency',
      still.body?.currency === 'YER' && still.body?.funding?.received === '2000000');

    const partnerMember = await inviteAndAccept(request, {
      planId: bridePlanId,
      inviterToken: bride.token,
      member: partner,
      access: { role: 'GROOM', canViewMoney: true, canManageMoney: true },
    });
    check('the bride adds her partner with money rights', partnerMember.status === 201);
    const partnerMoney = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, partner.token);
    check('her mahr stays hers: the partner reads money without it',
      partnerMoney.status === 200 && partnerMoney.body?.mahr === null && partnerMoney.body?.funding === null);
    check('and is not told the plan holds private money (the lock is the owner\'s)',
      partnerMoney.body?.currencyLocked === null);

    // RA-BE-30: the budget replace answered every item's agreements count,
    // the partner's private ones too (V1 4.10), so the owner learnt they
    // exist. It counts what the owner reads.
    const brideItems = ((await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, bride.token))
      .body?.categories ?? []).filter((item) => item.kind !== 'MAHR');
    const privateCost = await request('POST', `/api/v1/wedding-plans/${bridePlanId}/costs`, {
      budgetCategoryId: brideItems[0]?.categoryId,
      title: 'هدية خاصة',
      totalAmount: '100000',
      isPrivate: true,
    }, partner.token, randomUUID());
    const brideReplace = await request('PUT', `/api/v1/wedding-plans/${bridePlanId}/money-budget`, {
      totalBudget: '7000000',
      currency: 'YER',
      categories: brideItems.map((item) => ({ id: item.categoryId, name: item.name, allocatedAmount: item.allocatedAmount })),
    }, bride.token, randomUUID());
    const countedItem = (brideReplace.body?.categories ?? []).find((item) => item.id === brideItems[0]?.categoryId);
    check(`the partner's private agreement is not counted to the owner (read ${countedItem?.costsCount})`,
      privateCost.status === 201 && brideReplace.status === 200 && countedItem?.costsCount === 0);

    // A plan without a groom's or a bride's persona has no mahr side.
    const helperPlan = await onboard(helper.token, 'HELPER');
    const helperPlanId = helperPlan.body?.activeWeddingPlan?.id;
    const helperMoney = await request('GET', `/api/v1/wedding-plans/${helperPlanId}/money-summary`, null, helper.token);
    check('a plan with no money yet keeps its currency open', helperMoney.body?.currencyLocked === false);
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

    // D59: an agreement stays on its side of the budget.
    const lunchItem = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/budget-categories`, {
      name: 'الغداء',
    }, groom.token);
    check('the groom adds a wedding item', lunchItem.status === 201);
    const lunch = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/costs`, {
      budgetCategoryId: lunchItem.body?.id,
      title: 'غداء العرس',
      totalAmount: '1000000',
      initialPaymentAmount: '400000',
      payer: 'FAMILY',
      payerName: 'الوالد',
    }, groom.token, randomUUID());
    check('the father\'s lunch is recorded with his first payment', lunch.status === 201);
    const intoMahr = await request('PATCH', `/api/v1/costs/${lunch.body?.id}`, {
      budgetCategoryId: mahrItem?.categoryId,
    }, groom.token);
    check('a wedding agreement cannot move into the mahr item', intoMahr.status === 409);
    const outOfMahr = await request('PATCH', `/api/v1/costs/${mahrCost?.id}`, {
      budgetCategoryId: lunchItem.body?.id,
    }, groom.token);
    check('the mahr agreement cannot move into a wedding item', outOfMahr.status === 409);

    // D59: what the father paid never leaves the groom's hands.
    const savings = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/funding-sources`, {
      kind: 'SAVINGS',
      sourceName: 'مدخراتي',
      amount: '5000000',
    }, groom.token);
    check('the groom records his savings', savings.status === 201);
    const split = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/money-summary`, null, groom.token);
    check('payments split by whose money paid: 3,000,000 his (the mahr), 400,000 the father\'s',
      split.body?.costs?.paid === '3400000' &&
      split.body?.costs?.paidByOwner === '3000000' &&
      split.body?.costs?.paidByOthers === '400000');
    check('«معك» is his savings less only what he paid: 2,000,000',
      split.body?.funding?.availableCash === '2000000' && split.body?.funding?.spent === '3000000');
    check('the father is a payer whose money is not the groom\'s',
      (split.body?.payers ?? []).some((group) =>
        group.payerName === 'الوالد' && group.ownerMoney === false && group.paid === '400000'));
    check('what is left counts every payment', split.body?.costs?.outstanding === '600000');
    const home = await request('GET', `/api/v1/wedding-plans/${groomPlanId}/dashboard-summary`, null, groom.token);
    check('the home reads the same money (one read)',
      home.body?.moneySummary?.paid === '3400000.00' &&
      home.body?.paidByOwner === '3000000.00' &&
      home.body?.paidByOthers === '400000.00' &&
      home.body?.moneySummary?.remainingBudget === '6000000.00');

    // D59: the mahr as money coming in is the bride's only.
    const groomMahrSource = await request('POST', `/api/v1/wedding-plans/${groomPlanId}/funding-sources`, {
      kind: 'MAHR',
      sourceName: 'المهر',
      amount: '1000000',
    }, groom.token);
    check('a groom\'s plan takes no mahr funding', groomMahrSource.status === 400);
    const brideRest = mahrSources.find((source) => source.status === 'PLEDGED');
    const retype = await request('PATCH', `/api/v1/funding-sources/${brideRest?.id}`, { kind: 'GIFT' }, bride.token);
    check('a mahr source keeps its kind', retype.status === 409);
    const latePromise = await request('POST', `/api/v1/wedding-plans/${bridePlanId}/funding-sources`, {
      kind: 'GIFT',
      sourceName: 'هدية',
      amount: '100000',
      status: 'PLEDGED',
      expectedAt: inDays(-3),
    }, bride.token);
    check('promised money past its day reads late («متأخر»)',
      latePromise.status === 201 && latePromise.body?.isOverdue === true);
    const becomeMahr = await request('PATCH', `/api/v1/funding-sources/${latePromise.body?.id}`, { kind: 'MAHR' }, bride.token);
    check('other money never becomes the mahr', becomeMahr.status === 409);
    const lateSummary = await request('GET', `/api/v1/wedding-plans/${bridePlanId}/money-summary`, null, bride.token);
    check('the summary counts the late promise', lateSummary.body?.funding?.overduePledges === 1);

    // D59: deleting the mahr agreement lets it be recorded again.
    const second = await register('Mahr groom again', phone(16));
    accounts.unshift(['second groom', second.token]);
    const secondPlan = await onboard(second.token, 'GROOM');
    const secondPlanId = secondPlan.body?.activeWeddingPlan?.id;
    const firstTry = await request('POST', `/api/v1/wedding-plans/${secondPlanId}/mahr`, { total: '2000000' }, second.token);
    check('the second groom records his mahr from b01', firstTry.status === 201 && firstTry.body?.mahr?.total === '2000000');
    const secondMahrItem = (firstTry.body?.categories ?? []).find((item) => item.kind === 'MAHR');
    const secondCosts = await request('GET', `/api/v1/wedding-plans/${secondPlanId}/costs`, null, second.token);
    const wrong = (secondCosts.body?.items ?? secondCosts.body ?? [])
      .find((cost) => cost.budgetCategoryId === secondMahrItem?.categoryId);
    const removed = await request('DELETE', `/api/v1/costs/${wrong?.id}`, null, second.token);
    check('he deletes the agreement he got wrong', removed.status === 200);
    const gone = await request('GET', `/api/v1/wedding-plans/${secondPlanId}/money-summary`, null, second.token);
    check('without its agreement the mahr reads as not recorded', gone.status === 200 && gone.body?.mahr === null);
    const reRecord = await request('POST', `/api/v1/wedding-plans/${secondPlanId}/mahr`, {
      total: '2500000',
      settled: '500000',
    }, second.token);
    const reItems = (reRecord.body?.categories ?? []).filter((item) => item.kind === 'MAHR');
    check('and records it again in the same item',
      reRecord.status === 201 && reRecord.body?.mahr?.total === '2500000' &&
      reItems.length === 1 && reItems[0].categoryId === secondMahrItem?.categoryId);

    // RA-BE-18: a groom who made an item «المهر» and put his agreement in it
    // is still asked «اتفقتوا على المهر؟» (no MAHR item yet). Recording it
    // turned his item into the mahr with his agreement and then added a
    // second agreement: 3,000,000 read as 6,000,000.
    const third = await register('Mahr groom with his own item', phone(17));
    accounts.unshift(['third groom', third.token]);
    const thirdPlan = await onboard(third.token, 'GROOM');
    const thirdPlanId = thirdPlan.body?.activeWeddingPlan?.id;
    const ownItem = await request('POST', `/api/v1/wedding-plans/${thirdPlanId}/budget-categories`, {
      name: 'المهر',
    }, third.token);
    const ownAgreement = await request('POST', `/api/v1/wedding-plans/${thirdPlanId}/costs`, {
      budgetCategoryId: ownItem.body?.id,
      title: 'مهر العروسة',
      totalAmount: '3000000',
    }, third.token, randomUUID());
    check('the third groom keeps his mahr in an item he named',
      ownItem.status === 201 && ownAgreement.status === 201);
    const asked = await request('GET', `/api/v1/wedding-plans/${thirdPlanId}/money-summary`, null, third.token);
    check('and is still asked to record the mahr', asked.status === 200 && asked.body?.mahr === null);
    const recorded = await request('POST', `/api/v1/wedding-plans/${thirdPlanId}/mahr`, { total: '3000000' }, third.token);
    const after = await request('GET', `/api/v1/wedding-plans/${thirdPlanId}/money-summary`, null, third.token);
    const thirdCosts = await request('GET', `/api/v1/wedding-plans/${thirdPlanId}/costs`, null, third.token);
    const agreements = thirdCosts.body?.items ?? thirdCosts.body ?? [];
    check(`recording it counts his agreement once: the mahr is 3,000,000, not 6,000,000 (read ${after.body?.mahr?.total}, ${agreements.length} agreements)`,
      recorded.status === 201 && after.body?.mahr?.total === '3000000' &&
      after.body?.costs?.total === '3000000' && agreements.length === 1);
    check('his item is the mahr item now, outside the budget (C1)',
      (after.body?.categories ?? []).some((item) => item.kind === 'MAHR' && item.categoryId === ownItem.body?.id));
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
