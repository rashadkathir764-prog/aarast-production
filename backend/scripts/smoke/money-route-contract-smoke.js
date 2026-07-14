#!/usr/bin/env node
'use strict';

/**
 * Read-only route gate for environments where sending OTP is forbidden.
 * Existing canonical money routes must reach the auth guard (401), while every
 * removed prelaunch route must remain absent (404). No account or data is made.
 */

const BASE_URL = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';
const fixtureId = '00000000-0000-4000-8000-000000000001';

let passed = 0;
let failed = 0;

function check(label, condition, actual) {
  if (condition) {
    passed++;
    console.log(`PASS - ${label}`);
    return;
  }
  failed++;
  console.log(`FAIL - ${label} (HTTP ${actual})`);
}

async function status(method, path) {
  const response = await fetch(new URL(path, BASE_URL), {
    method,
    redirect: 'manual',
    headers: { Accept: 'application/json' },
  });
  await response.arrayBuffer();
  return response.status;
}

async function run() {
  console.log('\nCanonical Money Route Contract Smoke');
  console.log(`Target: ${BASE_URL}\n`);

  for (const path of ['/health', '/ready']) {
    const actual = await status('GET', path);
    check(`${path} is healthy`, actual === 200, actual);
  }

  for (const [method, path] of [
    ['GET', `/api/v1/wedding-plans/${fixtureId}/money-summary`],
    ['PUT', `/api/v1/wedding-plans/${fixtureId}/money-budget`],
    ['GET', `/api/v1/wedding-plans/${fixtureId}/budget-categories`],
    ['GET', `/api/v1/wedding-plans/${fixtureId}/costs`],
    ['POST', `/api/v1/wedding-plans/${fixtureId}/costs`],
    ['GET', `/api/v1/costs/${fixtureId}`],
    ['POST', `/api/v1/costs/${fixtureId}/payments`],
    ['GET', `/api/v1/costs/${fixtureId}/payment-schedules`],
    ['GET', `/api/v1/wedding-plans/${fixtureId}/cost-payments`],
    ['GET', `/api/v1/cost-payments/${fixtureId}`],
    ['GET', `/api/v1/wedding-plans/${fixtureId}/payment-schedules/due`],
    ['POST', `/api/v1/payment-schedules/${fixtureId}/pay`],
  ]) {
    const actual = await status(method, path);
    check(`canonical ${method} ${path} reaches auth`, actual === 401, actual);
  }

  for (const path of [
    `/api/v1/wedding-plans/${fixtureId}/expenses`,
    `/api/v1/wedding-plans/${fixtureId}/financial-commitments`,
    `/api/v1/wedding-plans/${fixtureId}/financial-payment-records`,
    `/api/v1/wedding-plans/${fixtureId}/financial-installments/due`,
  ]) {
    const actual = await status('GET', path);
    check(`removed GET ${path} stays absent`, actual === 404, actual);
  }

  console.log(`\nOverall Result: ${failed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

run().catch((error) => {
  console.error('Money route contract smoke error:', error.message);
  process.exit(1);
});
