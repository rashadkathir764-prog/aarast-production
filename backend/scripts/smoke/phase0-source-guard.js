#!/usr/bin/env node
'use strict';

const { readFileSync, readdirSync } = require('fs');
const { join, resolve } = require('path');

const backendRoot = resolve(__dirname, '..', '..');
const repositoryRoot = resolve(backendRoot, '..');
const managedRunner = 'scripts/smoke/run-isolated-smoke.js';
const externalNonDatabaseSmoke = new Set(['smoke:openwa-otp']);

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function assertOfficialMutatingScriptsUseManagedRunner(scripts) {
  for (const [name, command] of Object.entries(scripts)) {
    const isManagedMutatingCommand =
      (name === 'smoke' || name.startsWith('smoke:')) &&
      !externalNonDatabaseSmoke.has(name);
    if (!isManagedMutatingCommand && name !== 'load:test') continue;
    if (!command.includes(managedRunner)) {
      throw new Error(`${name} must use the managed isolated smoke runner.`);
    }
  }
}

function assertNoUnsafeDatabaseTargets(source, label) {
  if (/\b(?:prisma\s+)?migrate\s+reset\b|\bprisma\s+db\s+push\b/i.test(source)) {
    throw new Error(`${label} contains a destructive Prisma command.`);
  }
  if (/postgres(?:ql)?:\/\/[^\s'"`]+\/(?:aarast|aarast_dev)(?:[?/'"`]|$)/i.test(source)) {
    throw new Error(`${label} contains a permanent Aarast database target.`);
  }
}

function smokeSourceFiles() {
  return readdirSync(join(backendRoot, 'scripts', 'smoke'), { withFileTypes: true })
    .filter((entry) => entry.isFile() && /\.js$/.test(entry.name))
    .map((entry) => join(backendRoot, 'scripts', 'smoke', entry.name));
}

function main() {
  const backendPackage = readJson(join(backendRoot, 'package.json'));
  const adminPackage = readJson(join(repositoryRoot, 'admin-web', 'package.json'));
  assertOfficialMutatingScriptsUseManagedRunner(backendPackage.scripts);
  if (!adminPackage.scripts['smoke:admin-runtime']?.includes(managedRunner)) {
    throw new Error('Admin runtime smoke must use the managed isolated smoke runner.');
  }

  const sources = [
    ...smokeSourceFiles(),
    join(backendRoot, 'scripts', 'load', 'load-test.js'),
    join(repositoryRoot, 'admin-web', 'scripts', 'admin-runtime-smoke.mjs'),
  ];
  for (const sourcePath of sources) {
    assertNoUnsafeDatabaseTargets(
      readFileSync(sourcePath, 'utf8'),
      sourcePath.slice(repositoryRoot.length + 1),
    );
  }

  console.log('PASS - Phase 0 source guard: managed test commands and database targets are safe.');
}

if (require.main === module) main();

module.exports = {
  assertNoUnsafeDatabaseTargets,
  assertOfficialMutatingScriptsUseManagedRunner,
};
