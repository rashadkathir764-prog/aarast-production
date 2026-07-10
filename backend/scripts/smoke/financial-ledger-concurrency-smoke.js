'use strict';

const http = require('http');
const { registerVerified } = require('./verified-registration');

const BASE_URL = process.env.SMOKE_BASE_URL || 'http://127.0.0.1:3115';
const TEST_PASSWORD = 'SmokePass123!';
const suffix = `${Date.now()}`.slice(-8);
const TEST_PHONE = `+9677${suffix}`;
let passed = 0;
let failed = 0;

function check(name, condition) {
  if (condition) {
    passed++;
    console.log(`PASS - ${name}`);
  } else {
    failed++;
    console.log(`FAIL - ${name}`);
  }
}

function request(method, path, body, token, requestId) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined || body === null ? null : JSON.stringify(body);
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers: {
          Accept: 'application/json',
          ...(payload
            ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }
            : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(requestId ? { 'X-Client-Request-Id': requestId } : {}),
        },
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

async function run() {
  console.log('\nFinancial Ledger Concurrency Smoke');
  console.log(`Target: ${BASE_URL}\n`);

  const registration = await registerVerified(request, {
    name: 'Financial Concurrency Smoke',
    phone: TEST_PHONE,
    password: TEST_PASSWORD,
  });
  check('verified finance user registration succeeds', registration.status === 201);
  const token = registration.body?.accessToken;
  if (!token) throw new Error(`registration setup failed with HTTP ${registration.status}`);

  const plan = await request('POST', '/api/v1/wedding-plans', {
    title: 'Immutable Ledger Smoke Plan',
    city: 'Sanaa',
    estimatedBudget: '1000',
  }, token);
  check('financial smoke plan created', plan.status === 201 && typeof plan.body?.id === 'string');
  if (!plan.body?.id) throw new Error(`plan setup failed with HTTP ${plan.status}`);

  const category = await request(
    'POST',
    `/api/v1/wedding-plans/${plan.body.id}/budget-categories`,
    { name: 'Ledger', targetAmount: '1000' },
    token,
  );
  check('financial smoke category created', category.status === 201 && typeof category.body?.id === 'string');
  if (!category.body?.id) throw new Error(`category setup failed with HTTP ${category.status}`);

  const commitment = await request(
    'POST',
    `/api/v1/wedding-plans/${plan.body.id}/financial-commitments`,
    {
      budgetCategoryId: category.body.id,
      title: 'Concurrency commitment',
      totalAmount: '500',
    },
    token,
  );
  check('financial commitment created', commitment.status === 201 && typeof commitment.body?.id === 'string');
  if (!commitment.body?.id) throw new Error(`commitment setup failed with HTTP ${commitment.status}`);

  const installment = await request(
    'POST',
    `/api/v1/financial-commitments/${commitment.body.id}/installments`,
    { amount: '200', status: 'PENDING' },
    token,
  );
  check('pending financial installment created', installment.status === 201 && typeof installment.body?.id === 'string');
  if (!installment.body?.id) throw new Error(`installment setup failed with HTTP ${installment.status}`);

  const payResults = await Promise.all([
    request('PATCH', `/api/v1/financial-installments/${installment.body.id}/pay`, {}, token, `pay-a-${suffix}`),
    request('PATCH', `/api/v1/financial-installments/${installment.body.id}/pay`, {}, token, `pay-b-${suffix}`),
  ]);
  check('both concurrent pay calls finish without server error', payResults.every((item) => item.status === 200));
  check('both concurrent pay calls return PAID', payResults.every((item) => item.body?.status === 'PAID'));

  let records = await request(
    'GET',
    `/api/v1/wedding-plans/${plan.body.id}/financial-payment-records`,
    null,
    token,
  );
  if (!Array.isArray(records.body)) throw new Error(`payment list failed with HTTP ${records.status}`);
  const installmentPayments = records.body.filter(
    (entry) => entry.financialInstallmentId === installment.body.id && entry.entryType === 'PAYMENT',
  );
  check('concurrent pay creates exactly one installment payment entry', installmentPayments.length === 1);
  check('the installment payment is reversible before reversal', installmentPayments[0]?.reversible === true);

  let refreshedCommitment = await request(
    'GET',
    `/api/v1/financial-commitments/${commitment.body.id}`,
    null,
    token,
  );
  check('concurrent pay increments commitment exactly once', Number(refreshedCommitment.body?.paidAmount) === 200);

  const paymentId = installmentPayments[0].id;
  const reverseResults = await Promise.all([
    request('DELETE', `/api/v1/financial-payment-records/${paymentId}`, null, token, `reverse-a-${suffix}`),
    request('DELETE', `/api/v1/financial-payment-records/${paymentId}`, null, token, `reverse-b-${suffix}`),
  ]);
  check('both concurrent reversal calls are idempotent', reverseResults.every((item) => item.status === 200 && item.body?.reversed === true));

  records = await request(
    'GET',
    `/api/v1/wedding-plans/${plan.body.id}/financial-payment-records`,
    null,
    token,
  );
  const reversals = records.body.filter(
    (entry) => entry.entryType === 'REVERSAL' && entry.reversalOfId === paymentId,
  );
  const original = records.body.find((entry) => entry.id === paymentId);
  check('concurrent reversal creates exactly one compensating entry', reversals.length === 1);
  check('original payment remains in immutable history', Boolean(original));
  check('original payment points to its reversal and cannot be reversed again', original?.reversedById === reversals[0]?.id && original?.reversible === false);

  refreshedCommitment = await request(
    'GET',
    `/api/v1/financial-commitments/${commitment.body.id}`,
    null,
    token,
  );
  check('reversal restores commitment paid amount to zero', Number(refreshedCommitment.body?.paidAmount) === 0);

  const installments = await request(
    'GET',
    `/api/v1/financial-commitments/${commitment.body.id}/installments`,
    null,
    token,
  );
  const reversedInstallment = installments.body.find((item) => item.id === installment.body.id);
  check('reversal reopens the linked installment', reversedInstallment?.status === 'PENDING' && reversedInstallment?.paidAt === null);

  const deleteHistoricInstallment = await request(
    'DELETE',
    `/api/v1/financial-installments/${installment.body.id}`,
    null,
    token,
  );
  check('installment with payment history cannot be deleted', deleteHistoricInstallment.status === 400);

  const reverseAReversal = await request(
    'DELETE',
    `/api/v1/financial-payment-records/${reversals[0].id}`,
    null,
    token,
  );
  check('a reversal entry cannot itself be reversed', reverseAReversal.status === 400);

  const raceCommitment = await request(
    'POST',
    `/api/v1/wedding-plans/${plan.body.id}/financial-commitments`,
    {
      budgetCategoryId: category.body.id,
      title: 'Pay versus total update race',
      totalAmount: '500',
    },
    token,
  );
  const raceInstallment = await request(
    'POST',
    `/api/v1/financial-commitments/${raceCommitment.body.id}/installments`,
    { amount: '200', status: 'PENDING' },
    token,
  );
  check('balance-update race fixture created', raceCommitment.status === 201 && raceInstallment.status === 201);
  if (!raceCommitment.body?.id || !raceInstallment.body?.id) {
    throw new Error('balance-update race fixture failed');
  }

  const balanceRace = await Promise.all([
    request('PATCH', `/api/v1/financial-installments/${raceInstallment.body.id}/pay`, {}, token, `balance-pay-${suffix}`),
    request('PATCH', `/api/v1/financial-commitments/${raceCommitment.body.id}`, { totalAmount: '100' }, token, `balance-total-${suffix}`),
  ]);
  const raceStatuses = balanceRace.map((item) => item.status).sort();
  check('pay versus invalid total update serializes to one success and one rejection', raceStatuses[0] === 200 && raceStatuses[1] === 400);
  check('balance-update race never returns HTTP 500', balanceRace.every((item) => item.status < 500));

  const raceCommitmentState = await request(
    'GET',
    `/api/v1/financial-commitments/${raceCommitment.body.id}`,
    null,
    token,
  );
  const raceInstallmentState = await request(
    'GET',
    `/api/v1/financial-commitments/${raceCommitment.body.id}/installments`,
    null,
    token,
  );
  const finalRaceInstallment = raceInstallmentState.body.find(
    (item) => item.id === raceInstallment.body.id,
  );
  const finalPaid = Number(raceCommitmentState.body?.paidAmount);
  const finalTotal = Number(raceCommitmentState.body?.totalAmount);
  check('balance-update race preserves paid <= total', finalPaid >= 0 && finalPaid <= finalTotal);
  check(
    'installment status agrees with the serialized balance outcome',
    (finalPaid === 200 && finalTotal === 500 && finalRaceInstallment?.status === 'PAID') ||
      (finalPaid === 0 && finalTotal === 100 && finalRaceInstallment?.status === 'PENDING'),
  );

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Financial ledger concurrency smoke error:', error.message);
  process.exit(1);
});
