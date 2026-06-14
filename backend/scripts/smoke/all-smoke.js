#!/usr/bin/env node
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

const smokeScripts = [
  ['smoke:health', 'health-smoke.js'],
  ['smoke:auth', 'auth-smoke.js'],
  ['smoke:wedding-plan', 'wedding-plan-smoke.js'],
  ['smoke:budget-expense', 'budget-expense-smoke.js'],
  ['smoke:debt-installment', 'debt-installment-smoke.js'],
  ['smoke:task-timeline', 'task-timeline-smoke.js'],
  ['smoke:sharing', 'sharing-smoke.js'],
  ['smoke:otp-profile', 'otp-profile-smoke.js'],
  ['smoke:marketplace', 'marketplace-smoke.js'],
  ['smoke:provider-dashboard', 'provider-dashboard-smoke.js'],
];

const results = [];

console.log('\nAarast Backend Smoke: All');
console.log(`Target: ${process.env.SMOKE_BASE_URL ?? 'default script base URLs'}\n`);

for (const [script, fileName] of smokeScripts) {
  console.log(`===== ${script} =====`);
  const result = spawnSync(process.execPath, [path.join(__dirname, fileName)], {
    env: process.env,
    stdio: 'inherit',
  });

  const passed = result.status === 0;
  results.push({ script, passed, status: result.status ?? 1 });
  console.log(`RESULT ${script} ${passed ? 'PASS' : 'FAIL'} (${result.status ?? 1})\n`);

  if (!passed) break;
}

console.log('Smoke: All Summary');
for (const result of results) {
  console.log(`${result.passed ? 'PASS' : 'FAIL'} - ${result.script}`);
}

const failed = results.filter((result) => !result.passed);
console.log(`Overall Result: ${failed.length === 0 ? 'PASS' : 'FAIL'}`);

if (failed.length > 0 || results.length !== smokeScripts.length) {
  process.exit(1);
}
