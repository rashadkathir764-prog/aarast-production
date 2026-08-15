import 'reflect-metadata';

import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';

const backendRoot = process.cwd();
const sourceRoot = join(backendRoot, 'src');

function source(relativePath: string): string {
  return readFileSync(join(sourceRoot, relativePath), 'utf8');
}

function moduleClass(relativePath: string, className: string): Function {
  const absolutePath = join(sourceRoot, relativePath);
  assert.equal(existsSync(absolutePath), true, `${relativePath} must exist`);
  return require(absolutePath)[className] as Function;
}

function metadataNames(module: Function, key: string): string[] {
  return ((Reflect.getMetadata(key, module) as Function[] | undefined) ?? [])
    .map((entry) => entry.name)
    .sort();
}

test('Task 8 creates Messaging and Notifications full modules and retires final legacy metadata', () => {
  for (const relativePath of [
    'modules/messaging/messaging.module.ts',
    'modules/messaging/internal/messaging-conversations.internal.module.ts',
    'modules/notifications/notifications.module.ts',
    'modules/notifications/internal/notifications-lifecycle.internal.module.ts',
    'modules/notifications/internal/push-installations.internal.module.ts',
  ]) {
    assert.equal(existsSync(join(sourceRoot, relativePath)), true, relativePath);
  }
  for (const relativePath of [
    'conversations/conversations.module.ts',
    'notifications/notifications.module.ts',
    'push/push.module.ts',
  ]) {
    assert.equal(existsSync(join(sourceRoot, relativePath)), false, relativePath);
  }
  assert.equal(
    require('node:crypto').createHash('sha256')
      .update(readFileSync(join(sourceRoot, 'conversations/conversation-realtime.module.ts')))
      .digest('hex'),
    'ed448193983c06def85097b34444853d9f6c8db8fd5f71d6ff94a74517d913a5',
  );
});

test('Task 8 AppModule imports all thirteen full contexts and no retired module', () => {
  const app = source('app.module.ts');
  const contextModules = [
    'IdentityModule', 'PlanningModule', 'FinanceModule', 'CollaborationModule',
    'TasksModule', 'GuestsModule', 'MarketplaceModule', 'MessagingModule',
    'NotificationsModule', 'CatalogModule', 'MediaModule', 'InsightsModule',
    'BackofficeModule',
  ];
  for (const name of contextModules) assert.match(app, new RegExp(`\\b${name}\\b`));
  assert.match(app, /from ["']\.\/modules\/messaging\/messaging\.module["']/);
  assert.match(app, /from ["']\.\/modules\/notifications\/notifications\.module["']/);
  assert.doesNotMatch(app, /from ["']\.\/(?:conversations|notifications|push)\/.+\.module["']/);
});

test('Task 8 Messaging metadata owns conversation controllers and providers exactly once', () => {
  const full = moduleClass('modules/messaging/messaging.module.ts', 'MessagingModule');
  const internal = moduleClass(
    'modules/messaging/internal/messaging-conversations.internal.module.ts',
    'MessagingConversationsInternalModule',
  );
  assert.deepEqual(
    metadataNames(full, MODULE_METADATA.CONTROLLERS),
    ['ConversationsController', 'QuoteRequestConversationsController'],
  );
  assert.deepEqual(
    metadataNames(internal, MODULE_METADATA.PROVIDERS),
    ['ConversationsGateway', 'ConversationsService'],
  );
});

test('Task 8 Notifications metadata owns both controllers and private lifecycle providers', () => {
  const full = moduleClass('modules/notifications/notifications.module.ts', 'NotificationsModule');
  const lifecycle = moduleClass(
    'modules/notifications/internal/notifications-lifecycle.internal.module.ts',
    'NotificationsLifecycleInternalModule',
  );
  const installations = moduleClass(
    'modules/notifications/internal/push-installations.internal.module.ts',
    'PushInstallationsInternalModule',
  );
  assert.deepEqual(
    metadataNames(full, MODULE_METADATA.CONTROLLERS),
    ['NotificationsController', 'PushController'],
  );
  assert.deepEqual(
    metadataNames(lifecycle, MODULE_METADATA.PROVIDERS),
    ['NotificationRemindersScheduler'],
  );
  assert.deepEqual(
    metadataNames(installations, MODULE_METADATA.PROVIDERS),
    ['PushInstallationsService'],
  );
});

test('Task 8 preserves one realtime global and removes legacy PushModule reachability', () => {
  const notifications = source('modules/notifications/notifications.module.ts');
  const app = source('app.module.ts');
  assert.doesNotMatch(notifications, /PushModule/);
  assert.doesNotMatch(app, /PushModule/);
  const realtime = source('conversations/conversation-realtime.module.ts');
  assert.match(realtime, /@Global\(\)/);
  assert.equal((realtime.match(/@Global\(\)/g) ?? []).length, 1);
});

test('Task 8 activates the strict manifest while retaining immutable initial ledgers', () => {
  const manifest = JSON.parse(
    readFileSync(join(backendRoot, 'architecture/r3-context-boundaries.json'), 'utf8'),
  ) as Record<string, unknown>;
  assert.equal(manifest.stage, 'strict');
  assert.deepEqual(manifest.remainingDuplicateProviders, []);
  assert.deepEqual(manifest.remainingPlatformDebts, []);
  assert.deepEqual(manifest.remainingRetiredLegacyProviderEdges, []);
  assert.equal((manifest.initialDuplicateProviders as unknown[]).length, 3);
  assert.equal((manifest.initialPlatformDebts as unknown[]).length, 6);
  assert.equal((manifest.initialRetiredLegacyProviderEdges as unknown[]).length, 163);
});

test('Task 8 strict scanner reports no duplicate, platform, retired, cycle, or illegal edge', () => {
  const scanner = require('../scripts/architecture/r3-context-scan.cjs') as {
    scanR3Contexts: (options: Record<string, unknown>) => {
      diagnostics: unknown[];
      counts: Record<string, number>;
    };
  };
  const result = scanner.scanR3Contexts({
    repoRoot: join(backendRoot, '..'),
    backendRoot,
    manifestPath: join(backendRoot, 'architecture/r3-context-boundaries.json'),
    stage: 'strict',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.remainingDuplicateProviders, 0);
  assert.equal(result.counts.remainingPlatformDebts, 0);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 0);
  assert.equal(result.counts.forwardRef, 0);
  assert.equal(result.counts.globals, 2);
  assert.equal(result.counts.nestModuleCycles, 0);
  assert.equal(result.counts.illegalEdges, 0);
});

test('Task 8 final dependency baseline equals the live candidate and only approved R3 removals', () => {
  const repositoryRoot = join(backendRoot, '..');
  const temporaryRoot = mkdtempSync(join(tmpdir(), 'aarast-r3-baseline-'));
  const candidatePath = join(temporaryRoot, 'dependency.json');
  try {
    const cli = join(
      backendRoot,
      'node_modules/dependency-cruiser/bin/dependency-cruise.mjs',
    );
    const generated = spawnSync(process.execPath, [
      cli,
      '--config', join(backendRoot, '.dependency-cruiser.cjs'),
      '--output-type', 'baseline',
      '--output-to', candidatePath,
      'src',
    ], { cwd: backendRoot, encoding: 'utf8' });
    assert.equal(generated.status, 0, generated.stderr);

    const baseRef = '6b06eb096aca8cc6684d365d16e05d4cd8529898';
    const base = JSON.parse(execFileSync('git', [
      'show', `${baseRef}:backend/.dependency-cruiser-known-violations.json`,
    ], { cwd: repositoryRoot, encoding: 'utf8' })) as DependencyRecord[];
    const tracked = JSON.parse(readFileSync(
      join(backendRoot, '.dependency-cruiser-known-violations.json'),
      'utf8',
    )) as DependencyRecord[];
    const candidate = JSON.parse(readFileSync(candidatePath, 'utf8')) as DependencyRecord[];
    assert.deepEqual(tracked, candidate);

    const manifest = JSON.parse(readFileSync(
      join(backendRoot, 'architecture/r3-context-boundaries.json'),
      'utf8',
    )) as { initialRetiredLegacyProviderEdges: Array<{ key: string }> };
    const approved = new Set(manifest.initialRetiredLegacyProviderEdges.map(({ key }) => key));
    for (const key of [
      'src/platform/config/runtime-environment.ts|src/auth/jwt-secret.ts',
      'src/platform/health/readiness.service.ts|src/media/media-storage.service.ts',
      'src/platform/outbox/outbox.dispatcher.ts|src/conversations/conversation-realtime.publisher.ts',
      'src/platform/outbox/outbox.dispatcher.ts|src/push/push-delivery.service.ts',
      'src/platform/outbox/outbox.module.ts|src/conversations/conversation-realtime.module.ts',
      'src/platform/outbox/outbox.module.ts|src/push/push.module.ts',
      'src/dashboard/dashboard.contracts.ts|src/contribution-history/contribution-history.contracts.ts',
      'src/dashboard/dashboard.service.ts|src/contribution-history/contribution-history.contracts.ts',
    ]) approved.add(key);
    assert.equal(approved.size, 171);

    const recordKey = (record: DependencyRecord): string => (
      `${record.rule.name}|${record.from}|${record.to}`
    );
    const endpointKey = (record: DependencyRecord): string => `${record.from}|${record.to}`;
    const candidateByKey = new Map(candidate.map((record) => [recordKey(record), record]));
    const baseByKey = new Map(base.map((record) => [recordKey(record), record]));
    assert.equal(candidateByKey.size, candidate.length);
    assert.equal(baseByKey.size, base.length);
    assert.deepEqual(
      base.filter((record) => !candidateByKey.has(recordKey(record)))
        .map(endpointKey).sort(),
      [...approved].sort(),
    );
    assert.deepEqual(
      candidate.filter((record) => !baseByKey.has(recordKey(record))),
      [],
    );
    for (const record of candidate) {
      assert.deepEqual(record, baseByKey.get(recordKey(record)));
    }
  } finally {
    rmSync(temporaryRoot, { recursive: true, force: true });
  }
});

interface DependencyRecord {
  from: string;
  to: string;
  rule: { name: string };
  [key: string]: unknown;
}
