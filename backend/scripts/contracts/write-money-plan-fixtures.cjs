#!/usr/bin/env node
'use strict';

// Writes mobile/test/fixtures/money_plan_fixtures.json: the server's money
// tab answers for fixed plans, which the phone's copy must match
// (test/money-plan-fixtures.test.ts). Runs the same on Windows and Linux.

const { spawnSync } = require('node:child_process');
const path = require('node:path');

const backendRoot = path.resolve(__dirname, '..', '..');
const result = spawnSync(
  process.execPath,
  ['--test', '-r', 'ts-node/register', 'test/money-plan-fixtures.test.ts'],
  {
    cwd: backendRoot,
    stdio: 'inherit',
    env: { ...process.env, WRITE_MONEY_PLAN_FIXTURES: '1' },
    windowsHide: true,
  },
);
process.exit(result.status ?? 1);
