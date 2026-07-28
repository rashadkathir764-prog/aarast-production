#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const { readdirSync } = require('fs');
const { join, resolve } = require('path');
const {
  assertProtectedArtifactsUnchanged,
  captureProtectedArtifactSnapshot,
} = require('./smoke/phase0-git-cleanliness');

const backendRoot = resolve(__dirname, '..');
const preflightTestFiles = [
  'test/legacy-finance-removal.test.ts',
  'test/canonical-api-routes.test.ts',
  'test/admin-app-identity.test.ts',
  'test/invite-delivery.test.ts',
  'test/phase0-guards.test.ts',
];

function discoverTopLevelTestFiles() {
  return readdirSync(join(backendRoot, 'test'), {
    withFileTypes: true,
  })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.test.ts'))
    .map((entry) => `test/${entry.name}`)
    .sort();
}

function buildTestBatches(testFiles = discoverTopLevelTestFiles()) {
  const testFileSet = new Set(testFiles);
  const missingPreflight = preflightTestFiles.filter(
    (filePath) => !testFileSet.has(filePath),
  );
  if (missingPreflight.length > 0) {
    throw new Error(
      `Backend test preflight is missing ${missingPreflight.length} required file(s).`,
    );
  }
  const mainTestFiles = testFiles
    .filter((filePath) => !preflightTestFiles.includes(filePath))
    .sort();
  if (mainTestFiles.length === 0) {
    throw new Error('Backend main test batch must not be empty.');
  }
  return [[...preflightTestFiles], mainTestFiles];
}

function main(argumentsList = process.argv.slice(2)) {
  if (argumentsList.length > 0) {
    throw new Error(
      'The guarded backend test runner does not accept command-line test files or options.',
    );
  }

  const testBatches = buildTestBatches();
  const baseline = captureProtectedArtifactSnapshot();
  let testExitCode = 0;
  let testError = null;
  for (const testFiles of testBatches) {
    const result = spawnSync(
      process.execPath,
      ['--test', '-r', 'ts-node/register', ...testFiles],
      {
        cwd: backendRoot,
        env: process.env,
        shell: false,
        stdio: 'inherit',
        windowsHide: true,
      },
    );
    if (result.error) {
      testError = result.error;
      testExitCode = 1;
      break;
    }
    if (result.status !== 0) {
      testExitCode = result.status ?? 1;
      break;
    }
  }

  let cleanlinessError = null;
  try {
    assertProtectedArtifactsUnchanged(baseline);
    console.log(
      'PASS - Phase 0 test cleanliness: protected artifacts were unchanged during this test run.',
    );
  } catch (error) {
    cleanlinessError = error;
    console.error(error instanceof Error ? error.message : String(error));
  }

  if (testError) throw testError;
  if (cleanlinessError || testExitCode !== 0) {
    process.exitCode = testExitCode || 1;
  }
}

if (require.main === module) main();

module.exports = {
  buildTestBatches,
  discoverTopLevelTestFiles,
  main,
};
