#!/usr/bin/env node
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');
const { assertManagedSmokeEnvironment } = require('./smoke-utils');

assertManagedSmokeEnvironment(process.env);

const smokeScripts = [
  ['smoke:health', 'health-smoke.js'],
  ['smoke:auth', 'auth-smoke.js'],
  ['smoke:auth-verification', 'auth-verification-smoke.js'],
  ['smoke:wedding-plan', 'wedding-plan-smoke.js'],
  ['smoke:onboarding-active-plan', 'onboarding-active-plan-smoke.js'],
  ['smoke:dashboard-summary', 'dashboard-summary-smoke.js'],
  ['smoke:money-routes', 'money-route-contract-smoke.js'],
  ['smoke:money-apis', 'money-apis-smoke.js'],
  ['smoke:financial-ledger-concurrency', 'financial-ledger-concurrency-smoke.js'],
  ['smoke:money-budget', 'money-budget-smoke.js'],
  ['smoke:tasks-apis', 'tasks-apis-smoke.js'],
  ['smoke:task-timeline', 'task-timeline-smoke.js'],
  ['smoke:sharing', 'sharing-smoke.js'],
  ['smoke:sharing-roles', 'sharing-roles-smoke.js'],
  ['smoke:sharing-security', 'sharing-security-smoke.js'],
  ['smoke:notifications', 'notifications-smoke.js'],
  ['smoke:notifications-apis', 'notifications-apis-smoke.js'],
  ['smoke:guests', 'guests-smoke.js'],
  ['smoke:guests-apis', 'guests-apis-smoke.js'],
  ['smoke:otp-profile', 'otp-profile-smoke.js'],
  ['smoke:marketplace', 'marketplace-smoke.js'],
  ['smoke:providers-quotes', 'providers-quotes-smoke.js'],
  ['smoke:quote-stability', 'quote-stability-smoke.js'],
  ['smoke:conversation-unification', 'conversation-unification-smoke.js'],
  ['smoke:private-chat-media', 'private-chat-media-smoke.js'],
  [
    'smoke:account-deletion',
    'account-deletion-smoke.ts',
    ['ts-node/register'],
  ],
  ['smoke:booking', 'booking-smoke.ts', ['ts-node/register']],
  ['smoke:guest-rsvp', 'guest-rsvp-smoke.ts', ['ts-node/register']],
  ['smoke:provider-claim', 'provider-claim-smoke.ts', ['ts-node/register']],
  ['smoke:provider-lifecycle', 'provider-lifecycle-smoke.ts', ['ts-node/register']],
  ['smoke:cost-receipts', 'cost-receipts-smoke.js'],
  ['smoke:phone-change', 'phone-change-smoke.js'],
  ['smoke:task-shift', 'task-shift-smoke.js'],
  ['smoke:plan-partner', 'plan-partner-smoke.js'],
  ['smoke:assistant', 'assistant-smoke.js'],
  ['smoke:provider-dashboard', 'provider-dashboard-smoke.js'],
  ['smoke:ux-backend-support', 'ux-backend-support-smoke.js'],
  ['smoke:ux-c4-c7', 'ux-c4-c7-smoke.js'],
  ['smoke:backend-completion', 'backend-completion-smoke.js'],
];

const results = [];
const smokeBaseUrl = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';

console.log('\nAarast Backend Smoke: All');
console.log(`Target: ${smokeBaseUrl}\n`);

for (const [index, [script, fileName, preloads = []]] of smokeScripts.entries()) {
  console.log(`===== ${script} =====`);
  const result = spawnSync(process.execPath, [
    '-r',
    path.join(__dirname, 'smoke-isolation-hook.js'),
    '-r',
    path.join(__dirname, 'smoke-client-ip-hook.js'),
    ...preloads.flatMap((preload) => ['-r', require.resolve(preload)]),
    path.join(__dirname, fileName),
  ], {
    env: {
      ...process.env,
      SMOKE_BASE_URL: smokeBaseUrl,
      SMOKE_CLIENT_IP: `198.18.0.${index + 1}`,
    },
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
