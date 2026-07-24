#!/usr/bin/env node
'use strict';

const { existsSync, readFileSync, readdirSync } = require('fs');
const { join, resolve } = require('path');

const backendRoot = resolve(__dirname, '..', '..');
const repositoryRoot = resolve(backendRoot, '..');
const managedRunner = 'scripts/smoke/run-isolated-smoke.js';
const externalOpenwaCommand = 'node scripts/smoke/openwa-otp-smoke.js';
const sourceExtensions = new Set(['.js', '.ts', '.mjs', '.cjs']);

const managedCommandArguments = new Map([
  ['smoke', 'health-smoke.js auth-smoke.js'],
  ['smoke:health', 'health-smoke.js'],
  ['smoke:auth', 'auth-smoke.js'],
  ['smoke:auth-verification', 'auth-verification-smoke.js'],
  ['smoke:wedding-plan', 'wedding-plan-smoke.js'],
  ['smoke:onboarding-active-plan', 'onboarding-active-plan-smoke.js'],
  ['smoke:dashboard-summary', 'dashboard-summary-smoke.js'],
  ['smoke:money-apis', 'money-apis-smoke.js'],
  ['smoke:financial-ledger-concurrency', 'financial-ledger-concurrency-smoke.js'],
  ['smoke:money-budget', 'money-budget-smoke.js'],
  ['smoke:money-routes', 'money-route-contract-smoke.js'],
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
  ['smoke:provider-dashboard', 'provider-dashboard-smoke.js'],
  ['smoke:ux-backend-support', 'ux-backend-support-smoke.js'],
  ['smoke:ux-c4-c7', 'ux-c4-c7-smoke.js'],
  ['smoke:backend-completion', 'backend-completion-smoke.js'],
  ['smoke:account-deletion', 'account-deletion-smoke.ts'],
  ['smoke:phase0-fixtures', 'phase0-fixtures-smoke.js'],
  ['smoke:all', 'all-smoke.js'],
  ['load:test', '--load-test'],
]);

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function expectedManagedCommand(name) {
  const argumentsText = managedCommandArguments.get(name);
  return argumentsText ? `node ${managedRunner} ${argumentsText}` : null;
}

function assertOfficialMutatingScriptsUseManagedRunner(scripts) {
  for (const [name, command] of Object.entries(scripts)) {
    if (name === 'smoke:openwa-otp') continue;
    if (!(name === 'smoke' || name.startsWith('smoke:') || name === 'load:test')) continue;
    const expected = expectedManagedCommand(name);
    if (!expected || command !== expected) {
      throw new Error(`${name} must use the exact managed command without a prefix, suffix, pipeline, or extra argument.`);
    }
  }
}

function assertNoUnsafeDatabaseTargets(source, label) {
  if (/\b(?:prisma\s+)?migrate\s+reset\b|\bprisma\s+db\s+push\b/i.test(source)) {
    throw new Error(`${label} contains a destructive Prisma command.`);
  }

  for (const databaseUrl of extractPostgresUrls(source)) {
    let parsed;
    try {
      parsed = new URL(databaseUrl);
    } catch {
      continue;
    }
    const databaseName = decodeURIComponent(parsed.pathname).replace(/^\/+|\/+$/g, '');
    if (databaseName === 'aarast' || databaseName === 'aarast_dev') {
      throw new Error(`${label} contains a permanent Aarast database target.`);
    }
  }
}

function extractPostgresUrls(source) {
  return [...source.matchAll(/(?:^|[^A-Za-z0-9_:\/])((?:postgres|postgresql):\/\/[^\s'"`\\]+)/gi)]
    .map((match) => match[1]);
}

function collectFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const filePath = join(directory, entry.name);
    if (entry.isDirectory()) return collectFiles(filePath);
    const extension = entry.name.slice(entry.name.lastIndexOf('.'));
    return sourceExtensions.has(extension) ? [filePath] : [];
  });
}

function collectGuardedSourceFiles() {
  return [
    ...collectFiles(join(backendRoot, 'scripts', 'smoke')),
    ...collectFiles(join(backendRoot, 'scripts', 'load')),
    ...collectFiles(join(repositoryRoot, 'admin-web', 'scripts')),
  ];
}

function assertExternalOpenwaSmokeContract(command, source) {
  if (command !== externalOpenwaCommand) {
    throw new Error('OpenWA smoke must use the exact external command with no chained command.');
  }
  if (
    !/const requiredConfirmation = ['"]I_ACCEPT_REAL_WHATSAPP_SEND['"]/.test(source) ||
    !/OPENWA_SMOKE_CONFIRM\s*!==\s*requiredConfirmation/.test(source)
  ) {
    throw new Error('OpenWA external mutation requires the explicit confirmation guard.');
  }
  if (/\b(?:DATABASE_URL|SMOKE_DATABASE_URL|PrismaClient|@prisma\/client|postgres(?:ql)?)\b/i.test(source)) {
    throw new Error('OpenWA external mutation must not use a database.');
  }
}

function main() {
  const backendPackage = readJson(join(backendRoot, 'package.json'));
  const adminPackage = readJson(join(repositoryRoot, 'admin-web', 'package.json'));
  assertOfficialMutatingScriptsUseManagedRunner(backendPackage.scripts);
  assertExternalOpenwaSmokeContract(
    backendPackage.scripts['smoke:openwa-otp'],
    readFileSync(join(backendRoot, 'scripts', 'smoke', 'openwa-otp-smoke.js'), 'utf8'),
  );
  if (adminPackage.scripts['smoke:admin-runtime'] !== `node ../backend/${managedRunner} --admin-runtime`) {
    throw new Error('Admin runtime smoke must use the exact managed isolated smoke command.');
  }

  for (const sourcePath of collectGuardedSourceFiles()) {
    assertNoUnsafeDatabaseTargets(
      readFileSync(sourcePath, 'utf8'),
      sourcePath.slice(repositoryRoot.length + 1),
    );
  }

  console.log('PASS - Phase 0 source guard: exact managed commands, external OpenWA contract, and database targets are safe.');
}

if (require.main === module) main();

module.exports = {
  assertExternalOpenwaSmokeContract,
  assertNoUnsafeDatabaseTargets,
  assertOfficialMutatingScriptsUseManagedRunner,
  collectGuardedSourceFiles,
  extractPostgresUrls,
};
