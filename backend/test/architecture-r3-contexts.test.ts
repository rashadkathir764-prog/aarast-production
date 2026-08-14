import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const manifestPath = path.join(backendRoot, 'architecture', 'r3-context-boundaries.json');
const scannerPath = path.join(backendRoot, 'scripts', 'architecture', 'r3-context-scan.cjs');
const temporaryRoots: string[] = [];

type Scanner = {
  scanR3Contexts(options: Record<string, unknown>): any;
  scanR3SourceLaws(options: Record<string, unknown>): any;
  collectR3DecoratorInventory(options: Record<string, unknown>): any;
  validateR3ContextManifest(value: unknown): any;
  validateR3ScanResult(value: unknown): any;
  runCli(dependencies: Record<string, unknown>): number;
};

function scanner(): Scanner {
  return require(scannerPath) as Scanner;
}

function loadManifest() {
  return JSON.parse(readFileSync(manifestPath, 'utf8'));
}

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function fixtureProject(files: Record<string, string>) {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-contexts-'));
  temporaryRoots.push(root);
  write(root, 'backend/tsconfig.json', `${JSON.stringify({
    compilerOptions: {
      module: 'commonjs',
      moduleResolution: 'node',
      target: 'ES2022',
      experimentalDecorators: true,
      strict: false,
      skipLibCheck: true,
    },
    include: ['src/**/*.ts'],
  }, null, 2)}\n`);
  write(root, 'backend/node_modules/@nestjs/common/index.d.ts', [
    'export declare function Module(metadata: any): ClassDecorator;',
    'export declare function Global(): ClassDecorator;',
    'export declare function Injectable(): ClassDecorator;',
    'export declare function Controller(prefix?: string): ClassDecorator;',
    'export declare function Get(route?: string): MethodDecorator;',
    'export declare function UseGuards(...guards: unknown[]): ClassDecorator & MethodDecorator;',
    'export declare function forwardRef(callback: () => unknown): unknown;',
  ].join('\n'));
  for (const [relativePath, content] of Object.entries(files)) write(root, relativePath, content);
  return { repoRoot: root, backendRoot: path.join(root, 'backend') };
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('the canonical R3 manifest freezes the exact inventory ledgers', () => {
  const manifest = scanner().validateR3ContextManifest(loadManifest());
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.baseRevision, '6b06eb096aca8cc6684d365d16e05d4cd8529898');
  assert.equal(manifest.stage, 'inventory');
  assert.deepEqual(manifest.contexts, [
    'identity', 'planning', 'finance', 'collaboration', 'tasks', 'guests',
    'marketplace', 'messaging', 'notifications', 'catalog', 'media', 'insights',
    'backoffice',
  ]);
  assert.equal(manifest.legacyModules.length, 27);
  assert.equal(manifest.crossContextInjections.length, 43);
  assert.equal(manifest.compositionDependencies.length, 6);
  assert.equal(manifest.providerContracts.length, 10);
  assert.equal(manifest.decoratorRuntimeReferences.length, 23);
  assert.equal(manifest.adminGuardMetadata.length, 4);
  assert.equal(manifest.runtimeDecoratorValueReferences.length, 26);
  assert.equal(manifest.lifecycleProviders.length, 10);
  assert.equal(manifest.initialRetiredLegacyProviderEdges.length, 163);
  assert.deepEqual(
    Object.fromEntries([2, 3, 4, 5, 7].map((task) => [
      task,
      manifest.initialRetiredLegacyProviderEdges.filter(
        (edge: { retirementTask: number }) => edge.retirementTask === task,
      ).length,
    ])),
    { 2: 67, 3: 62, 4: 18, 5: 14, 7: 2 },
  );
  assert.deepEqual(manifest.initialDuplicateProviders, [
    'AdminGuard', 'AdminPermissionGuard', 'PermissionService',
  ]);
  assert.deepEqual(manifest.remainingDuplicateProviders, manifest.initialDuplicateProviders);
  assert.equal(manifest.initialPlatformDebts.length, 6);
  assert.deepEqual(manifest.remainingPlatformDebts, manifest.initialPlatformDebts);
  assert.deepEqual(
    manifest.remainingRetiredLegacyProviderEdges,
    manifest.initialRetiredLegacyProviderEdges.map((edge: { key: string }) => edge.key),
  );
});

test('the frozen injection, decorator, and lifecycle identities are exact and unique', () => {
  const manifest = scanner().validateR3ContextManifest(loadManifest());
  const injectionKeys = manifest.crossContextInjections.map(
    (edge: any) => `${edge.source}|${edge.parameter}|${edge.target}`,
  );
  assert.equal(new Set(injectionKeys).size, 43);
  assert.ok(injectionKeys.includes(
    'backend/src/sharing/invite-access.service.ts|auth|AuthService',
  ));
  assert.ok(injectionKeys.includes(
    'backend/src/users/users.service.ts|firebasePush|FirebasePushClient',
  ));
  assert.equal(
    manifest.decoratorRuntimeReferences.filter((item: any) => item.symbol === 'JwtAuthGuard').length,
    20,
  );
  assert.equal(
    manifest.decoratorRuntimeReferences.filter((item: any) => item.symbol === 'JwtSessionGuard').length,
    3,
  );
  assert.equal(
    manifest.runtimeDecoratorValueReferences.filter((item: any) => item.symbol === 'CurrentUser').length,
    22,
  );
  assert.equal(
    manifest.runtimeDecoratorValueReferences.filter(
      (item: any) => item.symbol === 'RequireAdminPermission',
    ).length,
    3,
  );
  assert.ok(manifest.runtimeDecoratorValueReferences.some(
    (item: any) => item.symbol === 'ADMIN_PERMISSIONS_KEY',
  ));
  assert.deepEqual(
    manifest.lifecycleProviders.map((item: any) => item.className),
    [
      'AuthChallengeCleanupScheduler',
      'ConversationsGateway',
      'IdempotencyCleanupScheduler',
      'LoginThrottleCleanupScheduler',
      'MediaUploadCleanupScheduler',
      'NotificationRemindersScheduler',
      'OtpDispatchQuotaCleanupScheduler',
      'OutboxCleanupScheduler',
      'OutboxDispatcher',
      'OutboxWorker',
    ],
  );
});

test('the live TypeScript inventory equals the canonical inventory manifest', () => {
  const result = scanner().scanR3Contexts({
    repoRoot,
    backendRoot,
    manifestPath,
    stage: 'inventory',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.deepEqual(result.counts, {
    contexts: 13,
    legacyModules: 27,
    crossContextInjections: 43,
    compositionDependencies: 6,
    initialDuplicateProviders: 3,
    remainingDuplicateProviders: 3,
    initialPlatformDebts: 6,
    remainingPlatformDebts: 6,
    initialRetiredLegacyProviderEdges: 163,
    remainingRetiredLegacyProviderEdges: 163,
    forwardRef: 0,
    globals: 2,
    nestModuleCycles: 0,
    illegalEdges: 0,
  });
});

test('I1 live orchestration executes source laws and permits only exact approved duplicate identities', () => {
  let calls = 0;
  const duplicate = (
    provider: string,
    declarationPath: string,
    registrationPath: string,
  ) => ({
    kind: 'duplicate-provider',
    path: registrationPath,
    line: 1,
    provider,
    declarationPath,
  });
  const result = scanner().scanR3Contexts({
    repoRoot,
    backendRoot,
    manifestPath,
    stage: 'inventory',
    sourceLawScan: () => {
      calls += 1;
      return {
        modules: [],
        diagnostics: [
          duplicate('AdminGuard', 'backend/src/admin/admin.guard.ts', 'backend/src/admin/admin.module.ts'),
          duplicate('AdminGuard', 'backend/src/admin/admin.guard.ts', 'backend/src/catalogs/catalogs.module.ts'),
          duplicate('AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts', 'backend/src/admin/admin.module.ts'),
          duplicate('AdminPermissionGuard', 'backend/src/admin/admin-permission.guard.ts', 'backend/src/catalogs/catalogs.module.ts'),
          duplicate('PermissionService', 'backend/src/sharing/permission.service.ts', 'backend/src/sharing/sharing.module.ts'),
          duplicate('PermissionService', 'backend/src/sharing/permission.service.ts', 'backend/src/notifications/notifications.module.ts'),
          duplicate('AttackerService', 'backend/src/tasks/attacker.service.ts', 'backend/src/modules/tasks/internal/tasks.module.ts'),
        ],
      };
    },
  });
  assert.equal(calls, 1);
  assert.deepEqual(result.diagnostics, [{
    kind: 'duplicate-provider',
    path: 'backend/src/modules/tasks/internal/tasks.module.ts',
    line: 1,
  }]);
});

test('same-count manifest identity drift is rejected against live source and the baseline', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-manifest-drift-'));
  temporaryRoots.push(root);
  const manifest = loadManifest();
  manifest.crossContextInjections[0] = {
    ...manifest.crossContextInjections[0],
    target: 'AttackerService',
  };
  manifest.decoratorRuntimeReferences[0] = {
    ...manifest.decoratorRuntimeReferences[0],
    source: 'backend/src/tasks/attacker.controller.ts',
  };
  manifest.decoratorRuntimeReferences.sort((left: any, right: any) => {
    const leftKey = `${left.source}|${left.symbol}`;
    const rightKey = `${right.source}|${right.symbol}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  manifest.lifecycleProviders[0] = {
    ...manifest.lifecycleProviders[0],
    path: 'backend/src/tasks/attacker.scheduler.ts',
  };
  const driftPath = path.join(root, 'manifest.json');
  writeFileSync(driftPath, `${JSON.stringify(manifest)}\n`, 'utf8');
  const result = scanner().scanR3Contexts({
    repoRoot,
    backendRoot,
    manifestPath: driftPath,
    stage: 'inventory',
  });
  assert.ok(result.diagnostics.some((item: any) => item.kind === 'inventory-drift'));
});

test('inventory-stage immutable ledgers reject same-count substitutions', () => {
  const manifest = loadManifest();
  assert.throws(() => scanner().validateR3ContextManifest({
    ...manifest,
    initialDuplicateProviders: ['AdminGuard', 'AdminPermissionGuard', 'AttackerService'],
    remainingDuplicateProviders: ['AdminGuard', 'AdminPermissionGuard', 'AttackerService'],
  }), /duplicate provider/i);
  assert.throws(() => scanner().validateR3ContextManifest({
    ...manifest,
    initialPlatformDebts: [...manifest.initialPlatformDebts.slice(0, 5), 'attacker-debt'],
    remainingPlatformDebts: [...manifest.initialPlatformDebts.slice(0, 5), 'attacker-debt'],
  }), /platform debt/i);
});

test('I3 deeply validates nested manifest data and rejects noncanonical same-count records', () => {
  const nestedProxy = loadManifest();
  nestedProxy.legacyModules[0] = new Proxy(nestedProxy.legacyModules[0], {});
  assert.throws(() => scanner().validateR3ContextManifest(nestedProxy), /plain object/i);

  const nestedAccessor = loadManifest();
  Object.defineProperty(nestedAccessor.providerContracts[0], 'token', {
    get: () => 'IDENTITY_AUTH_PORT', enumerable: true,
  });
  assert.throws(() => scanner().validateR3ContextManifest(nestedAccessor), /accessor|data property/i);

  const nestedSparse = loadManifest();
  nestedSparse.providerContracts[0].consumers = new Array(1);
  assert.throws(() => scanner().validateR3ContextManifest(nestedSparse), /dense/i);

  const oversized = loadManifest();
  oversized.legacyModules[0].className = 'A'.repeat(5000);
  assert.throws(() => scanner().validateR3ContextManifest(oversized), /length|oversized/i);

  const duplicate = loadManifest();
  duplicate.providerContracts[1] = structuredClone(duplicate.providerContracts[0]);
  assert.throws(() => scanner().validateR3ContextManifest(duplicate), /duplicate|canonical/i);

  const reordered = loadManifest();
  [reordered.lifecycleProviders[0], reordered.lifecycleProviders[1]] = [
    reordered.lifecycleProviders[1], reordered.lifecycleProviders[0],
  ];
  assert.throws(() => scanner().validateR3ContextManifest(reordered), /canonical|order/i);
});

test('I3 recursively rejects nested Proxy arrays and accessor-backed array data', () => {
  const nestedArrayProxy = loadManifest();
  nestedArrayProxy.providerContracts[0].methods = new Proxy(
    nestedArrayProxy.providerContracts[0].methods,
    {},
  );
  assert.throws(
    () => scanner().validateR3ContextManifest(nestedArrayProxy),
    /plain|proxy|data/i,
  );

  const accessorIndex = loadManifest();
  const methods = [...accessorIndex.providerContracts[0].methods];
  Object.defineProperty(methods, '0', {
    get: () => accessorIndex.providerContracts[0].methods[0],
    enumerable: true,
  });
  accessorIndex.providerContracts[0].methods = methods;
  assert.throws(
    () => scanner().validateR3ContextManifest(accessorIndex),
    /accessor|data property/i,
  );

  const hiddenTrap = loadManifest();
  Object.defineProperty(hiddenTrap.providerContracts[0].methods, 'trap', {
    get: () => 'not plain data',
  });
  assert.throws(
    () => scanner().validateR3ContextManifest(hiddenTrap),
    /accessor|data property|plain/i,
  );
});

test('I3 same-count contract, composition, context-root, and Admin guard substitutions fail live', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r3-deep-drift-'));
  temporaryRoots.push(root);
  const manifest = loadManifest();
  manifest.contextRoots[0].legacyRoots[0] = 'attacker-root';
  manifest.providerContracts[0].token = 'ATTACKER_PORT';
  manifest.compositionDependencies[0].key = 'attacker-composition';
  manifest.adminGuardMetadata[0].guards[0] = 'AttackerGuard';
  const driftPath = path.join(root, 'manifest.json');
  writeFileSync(driftPath, `${JSON.stringify(manifest)}\n`, 'utf8');
  assert.throws(() => scanner().scanR3Contexts({
    repoRoot,
    backendRoot,
    manifestPath: driftPath,
    stage: 'inventory',
  }), /context root|provider contract|composition|guard|canonical/i);
});

test('I5 every frozen public token records at least one exact present consumer', () => {
  const manifest = scanner().validateR3ContextManifest(loadManifest());
  for (const contract of manifest.providerContracts) {
    assert.ok(contract.consumers.length > 0, `${contract.token} has no present consumer`);
    for (const consumer of contract.consumers) {
      assert.match(consumer.source, /^backend\/src\/.+\.ts$/);
      assert.match(consumer.kind, /^(constructor-injection|function-parameter|type-only|pure-function)$/);
    }
  }
});

test('I6 ledgers retire monotonically only at their declared task', () => {
  const initial = loadManifest();
  const taskForDuplicate: Record<string, number> = {
    AdminGuard: 7,
    AdminPermissionGuard: 7,
    PermissionService: 3,
  };
  const taskForPlatform: Record<string, number> = {
    'runtime-jwt-secret': 5,
    'readiness-media-storage': 2,
    'outbox-dispatcher-realtime': 2,
    'outbox-dispatcher-push': 2,
    'outbox-module-realtime': 2,
    'outbox-module-push': 2,
  };
  const atTask = (task: number) => ({
    ...structuredClone(initial),
    stage: `task-${task}`,
    remainingDuplicateProviders: initial.initialDuplicateProviders.filter(
      (item: string) => taskForDuplicate[item] > task,
    ),
    remainingPlatformDebts: initial.initialPlatformDebts.filter(
      (item: string) => taskForPlatform[item] > task,
    ),
    remainingRetiredLegacyProviderEdges: initial.initialRetiredLegacyProviderEdges
      .filter((item: any) => item.retirementTask > task)
      .map((item: any) => item.key),
  });
  assert.doesNotThrow(() => scanner().validateR3ContextManifest(atTask(2)));
  assert.doesNotThrow(() => scanner().validateR3ContextManifest(atTask(3)));

  const early = atTask(2);
  early.remainingPlatformDebts = [];
  assert.throws(() => scanner().validateR3ContextManifest(early), /early|task|platform/i);

  const late = atTask(2);
  late.remainingPlatformDebts.push('readiness-media-storage');
  assert.throws(() => scanner().validateR3ContextManifest(late), /late|task|platform/i);

  const unscheduled = atTask(2);
  unscheduled.remainingDuplicateProviders = ['AdminPermissionGuard', 'PermissionService'];
  assert.throws(() => scanner().validateR3ContextManifest(unscheduled), /early|task|duplicate/i);

  const renamed = atTask(2);
  renamed.remainingRetiredLegacyProviderEdges[0] = 'attacker|renamed';
  assert.throws(() => scanner().validateR3ContextManifest(renamed), /retired|renamed|task/i);
});

test('Nest decorators resolve through direct, aliased, and namespace symbols', () => {
  const options = fixtureProject({
    'backend/src/modules/tasks/internal/direct.module.ts': [
      "import { Module } from '@nestjs/common';",
      '@Module({ providers: [] })',
      'export class DirectModule {}',
    ].join('\n'),
    'backend/src/modules/guests/internal/alias.module.ts': [
      "import { Module as NestModule } from '@nestjs/common';",
      '@NestModule({ providers: [] })',
      'export class AliasModule {}',
    ].join('\n'),
    'backend/src/modules/media/internal/namespace.module.ts': [
      "import * as Nest from '@nestjs/common';",
      '@Nest.Module({ providers: [] })',
      'export class NamespaceModule {}',
    ].join('\n'),
  });
  const result = scanner().scanR3SourceLaws(options);
  assert.equal(result.modules.length, 3);
  assert.deepEqual(result.diagnostics, []);
});

test('spreads and computed or non-object Nest metadata fail closed', () => {
  const options = fixtureProject({
    'backend/src/modules/tasks/internal/bad.module.ts': [
      "import { Module } from '@nestjs/common';",
      'const providers = [];',
      "const key = 'providers';",
      '@Module({ ...{ providers }, [key]: providers })',
      'export class BadModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws(options).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('unresolved-nest-metadata'));
});

test('duplicate providers, hollow tokens, and concrete public exports fail closed', () => {
  const options = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/modules/tasks/internal/a.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      '@Module({ providers: [TaskService] })',
      'export class AModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/internal/b.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      '@Module({ providers: [TaskService] })',
      'export class BModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ providers: [], exports: [TASK_PORT, TaskService] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws(options).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('duplicate-provider'));
  assert.ok(kinds.includes('hollow-public-token'));
  assert.ok(kinds.includes('concrete-public-export'));
});

test('I2 aliases and namespaces cannot hide duplicate provider identity', () => {
  const options = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/modules/tasks/internal/a.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      '@Module({ providers: [TaskService] })',
      'export class AModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/internal/b.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService as AliasService } from '../../../tasks/task.service';",
      '@Module({ providers: [AliasService] })',
      'export class BModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/internal/c.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import * as Tasks from '../../../tasks/task.service';",
      '@Module({ providers: [Tasks.TaskService] })',
      'export class CModule {}',
    ].join('\n'),
  });
  const duplicates = scanner().scanR3SourceLaws(options).diagnostics.filter(
    (item: any) => item.kind === 'duplicate-provider',
  );
  assert.equal(duplicates.length, 3);
  assert.ok(duplicates.every((item: any) => item.provider === 'TaskService'));
  assert.ok(duplicates.every((item: any) => item.declarationPath.endsWith('/tasks/task.service.ts')));
});

test('foreign internal/full/concrete and cross-public runtime imports fail while type-only is legal', () => {
  const options = fixtureProject({
    'backend/src/modules/guests/public/types.ts': 'export interface GuestView { id: string }\n',
    'backend/src/modules/guests/public/guests-public.module.ts': 'export class GuestsPublicModule {}\n',
    'backend/src/modules/guests/internal/private.ts': 'export class GuestService {}\n',
    'backend/src/modules/guests/guests.module.ts': 'export class GuestsModule {}\n',
    'backend/src/modules/tasks/public/legal.ts': [
      "import type { GuestView } from '../../guests/public/types';",
      'export interface TaskView { guest: GuestView }',
    ].join('\n'),
    'backend/src/modules/tasks/public/runtime.ts': "import '../../guests/public/guests-public.module';\n",
    'backend/src/modules/tasks/internal/bad.ts': [
      "import '../../guests/internal/private';",
      "import '../../guests/guests.module';",
    ].join('\n'),
  });
  const result = scanner().scanR3SourceLaws(options);
  assert.equal(result.diagnostics.filter((item: any) => item.kind === 'illegal-boundary-import').length, 3);
  assert.equal(result.diagnostics.some((item: any) => item.path.endsWith('/legal.ts')), false);
});

test('application composition may import platform and business public modules only', () => {
  const options = fixtureProject({
    'backend/src/platform/outbox/core.ts': 'export const core = true;\n',
    'backend/src/modules/tasks/public/task-public.module.ts': 'export class TaskPublicModule {}\n',
    'backend/src/tasks/private.ts': 'export const privateTask = true;\n',
    'backend/src/application-composition/good.ts': [
      "import '../platform/outbox/core';",
      "import '../modules/tasks/public/task-public.module';",
    ].join('\n'),
    'backend/src/application-composition/bad.ts': "import '../tasks/private';\n",
    'backend/src/platform/bad.ts': "import '../application-composition/good';\n",
    'backend/src/tasks/bad.ts': "import '../application-composition/good';\n",
  });
  const result = scanner().scanR3SourceLaws(options);
  assert.equal(result.diagnostics.filter((item: any) => item.kind === 'illegal-composition-import').length, 3);
});

test('PublicModule bindings require paired internal tokens and exact useExisting', () => {
  const options = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/internal/task.internal.module.ts': 'export class TaskInternalModule {}\n',
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      "import { TaskInternalModule } from '../internal/task.internal.module';",
      "import { TASK_IMPLEMENTATION } from '../internal/task.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({',
      '  imports: [TaskInternalModule],',
      '  providers: [',
      '    { provide: TASK_PORT, useClass: TaskService },',
      '    { provide: TASK_IMPLEMENTATION, useFactory: () => new TaskService() },',
      '  ],',
      '  exports: [TASK_PORT],',
      '})',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws(options).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('public-binding-not-use-existing'));
  assert.ok(kinds.includes('public-imports-concrete'));
  assert.ok(kinds.includes('implementation-token-misuse'));
});

test('a public port cannot alias a same-shaped implementation token from another owner', () => {
  const options = fixtureProject({
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/guests/internal/guest.implementation-token.ts': "export const GUEST_IMPLEMENTATION = Symbol('GUEST_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { GUEST_IMPLEMENTATION } from '../../guests/internal/guest.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({',
      '  providers: [{ provide: TASK_PORT, useExisting: GUEST_IMPLEMENTATION }],',
      '  exports: [TASK_PORT],',
      '})',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws(options).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('public-binding-not-use-existing'));
  assert.ok(kinds.includes('illegal-boundary-import'));
});

test('I2 public bindings prove the owner-private Symbol, paired internal module, and legal site', () => {
  const valid = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/internal/task.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      "import { TASK_IMPLEMENTATION } from './task.implementation-token';",
      '@Module({ providers: [TaskService, { provide: TASK_IMPLEMENTATION, useExisting: TaskService }], exports: [TASK_IMPLEMENTATION] })',
      'export class TaskInternalModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskInternalModule } from '../internal/task.internal.module';",
      "import { TASK_IMPLEMENTATION as Implementation } from '../internal/task.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ imports: [TaskInternalModule], providers: [{ provide: TASK_PORT, useExisting: Implementation }], exports: [TASK_PORT] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const validKinds = scanner().scanR3SourceLaws(valid).diagnostics.map((item: any) => item.kind);
  assert.equal(validKinds.includes('public-binding-not-use-existing'), false);
  assert.equal(validKinds.includes('hollow-public-token'), false);

  const invalid = fixtureProject({
    'backend/src/modules/tasks/internal/task.internal.module.ts': 'export class TaskInternalModule {}\n',
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ providers: [{ provide: TASK_PORT, useExisting: TASK_IMPLEMENTATION }], exports: [TASK_PORT] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const invalidKinds = scanner().scanR3SourceLaws(invalid).diagnostics.map((item: any) => item.kind);
  assert.ok(invalidKinds.includes('public-binding-not-use-existing'));

  const decoy = fixtureProject({
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/internal/decoy.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      '@Module({})',
      'export class DecoyInternalModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { DecoyInternalModule } from '../internal/decoy.internal.module';",
      "import { TASK_IMPLEMENTATION } from '../internal/task.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ imports: [DecoyInternalModule], providers: [{ provide: TASK_PORT, useExisting: TASK_IMPLEMENTATION }], exports: [TASK_PORT] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const decoyKinds = scanner().scanR3SourceLaws(decoy).diagnostics.map((item: any) => item.kind);
  assert.ok(decoyKinds.includes('public-binding-not-use-existing'));
});

test('I2 public bindings require the exact manifest implementation registered and reachable once', () => {
  const contract = [{ token: 'TASK_PORT', implementations: ['TaskService'] }];
  const absentRegistration = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/internal/task.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskService } from '../../../tasks/task.service';",
      "import { TASK_IMPLEMENTATION } from './task.implementation-token';",
      '@Module({ providers: [{ provide: TASK_IMPLEMENTATION, useExisting: TaskService }], exports: [TASK_IMPLEMENTATION] })',
      'export class TaskInternalModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskInternalModule } from '../internal/task.internal.module';",
      "import { TASK_IMPLEMENTATION } from '../internal/task.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ imports: [TaskInternalModule], providers: [{ provide: TASK_PORT, useExisting: TASK_IMPLEMENTATION }], exports: [TASK_PORT] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const absentKinds = scanner().scanR3SourceLaws({
    ...absentRegistration,
    providerContracts: contract,
  }).diagnostics.map((item: any) => item.kind);
  assert.ok(absentKinds.includes('public-binding-not-use-existing'));

  const wrongSameOwnerTarget = fixtureProject({
    'backend/src/tasks/task.service.ts': 'export class TaskService {}\n',
    'backend/src/tasks/wrong-task.service.ts': 'export class WrongTaskService {}\n',
    'backend/src/modules/tasks/internal/task.implementation-token.ts': "export const TASK_IMPLEMENTATION = Symbol('TASK_IMPLEMENTATION');\n",
    'backend/src/modules/tasks/internal/task.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { WrongTaskService } from '../../../tasks/wrong-task.service';",
      "import { TASK_IMPLEMENTATION } from './task.implementation-token';",
      '@Module({ providers: [WrongTaskService, { provide: TASK_IMPLEMENTATION, useExisting: WrongTaskService }], exports: [TASK_IMPLEMENTATION] })',
      'export class TaskInternalModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/public/task-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TaskInternalModule } from '../internal/task.internal.module';",
      "import { TASK_IMPLEMENTATION } from '../internal/task.implementation-token';",
      "export const TASK_PORT = Symbol('TASK_PORT');",
      '@Module({ imports: [TaskInternalModule], providers: [{ provide: TASK_PORT, useExisting: TASK_IMPLEMENTATION }], exports: [TASK_PORT] })',
      'export class TaskPublicModule {}',
    ].join('\n'),
  });
  const wrongKinds = scanner().scanR3SourceLaws({
    ...wrongSameOwnerTarget,
    providerContracts: contract,
  }).diagnostics.map((item: any) => item.kind);
  assert.ok(wrongKinds.includes('public-binding-not-use-existing'));
});

test('I2 canonical access-token verifier accepts only the exact external JwtService path', () => {
  const contract = [{
    token: 'IDENTITY_ACCESS_TOKEN_VERIFIER',
    implementations: ['JwtService'],
  }];
  const commonFiles = {
    'backend/node_modules/@nestjs/jwt/index.d.ts': [
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }',
      'export declare class JwtModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/access-token-verifier.port.ts':
      "export const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');\n",
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class IdentityAuthInternalModule {}',
    ].join('\n'),
  };
  const valid = fixtureProject({
    ...commonFiles,
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({',
      '  imports: [IdentityAuthInternalModule],',
      '  providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }],',
      '  exports: [IDENTITY_ACCESS_TOKEN_VERIFIER],',
      '})',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const validKinds = scanner().scanR3SourceLaws({
    ...valid,
    providerContracts: contract,
  }).diagnostics.map((item: any) => item.kind);
  assert.equal(validKinds.includes('public-binding-not-use-existing'), false);
  assert.equal(validKinds.includes('concrete-public-export'), false);
  assert.equal(validKinds.includes('hollow-public-token'), false);

  const wrongExternal = fixtureProject({
    ...commonFiles,
    'backend/node_modules/@attacker/jwt/index.d.ts':
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }\n',
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@attacker/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({',
      '  imports: [IdentityAuthInternalModule],',
      '  providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }],',
      '  exports: [IDENTITY_ACCESS_TOKEN_VERIFIER],',
      '})',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const wrongKinds = scanner().scanR3SourceLaws({
    ...wrongExternal,
    providerContracts: contract,
  }).diagnostics.map((item: any) => item.kind);
  assert.ok(wrongKinds.includes('public-binding-not-use-existing'));
});

test('I2 rejects duplicate canonical access-token public bindings globally', () => {
  const options = fixtureProject({
    'backend/node_modules/@nestjs/jwt/index.d.ts': [
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }',
      'export declare class JwtModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/access-token-verifier.port.ts':
      "export const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');\n",
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class IdentityAuthInternalModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/duplicate-identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class DuplicateIdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const diagnostics = scanner().scanR3SourceLaws({
    ...options,
    providerContracts: [{ token: 'IDENTITY_ACCESS_TOKEN_VERIFIER', implementations: ['JwtService'] }],
  }).diagnostics;
  assert.equal(diagnostics.filter((item: any) => item.kind === 'public-binding-not-use-existing').length, 2);
});

test('I2 rejects distinct same-name public Symbol declarations as one manifest contract', () => {
  const options = fixtureProject({
    'backend/node_modules/@nestjs/jwt/index.d.ts': [
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }',
      'export declare class JwtModule {}',
    ].join('\n'),
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class IdentityAuthInternalModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/duplicate-identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class DuplicateIdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const diagnostics = scanner().scanR3SourceLaws({
    ...options,
    providerContracts: [{ token: 'IDENTITY_ACCESS_TOKEN_VERIFIER', implementations: ['JwtService'] }],
  }).diagnostics;
  assert.equal(diagnostics.filter((item: any) => item.kind === 'public-binding-not-use-existing').length, 2);
});

test('I2 rejects an extra owner-internal JwtModule bridge anywhere in the graph', () => {
  const options = fixtureProject({
    'backend/node_modules/@nestjs/jwt/index.d.ts': [
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }',
      'export declare class JwtModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/access-token-verifier.port.ts':
      "export const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');\n",
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class IdentityAuthInternalModule {}',
    ].join('\n'),
    'backend/src/modules/identity/internal/duplicate-jwt.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class DuplicateJwtInternalModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws({
    ...options,
    providerContracts: [{ token: 'IDENTITY_ACCESS_TOKEN_VERIFIER', implementations: ['JwtService'] }],
  }).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('public-binding-not-use-existing'));
});

test('I2 resolves the canonical external package instead of trusting a path substring', () => {
  const options = fixtureProject({
    'backend/node_modules/@nestjs/jwt/index.d.ts': [
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }',
      'export declare class JwtModule {}',
    ].join('\n'),
    'backend/node_modules/@attacker/jwt/node_modules/@nestjs/jwt/index.d.ts':
      'export declare class JwtService { verifyAsync<T extends object>(token: string): Promise<T>; }\n',
    'backend/src/modules/identity/public/access-token-verifier.port.ts':
      "export const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol('IDENTITY_ACCESS_TOKEN_VERIFIER');\n",
    'backend/src/modules/identity/internal/identity-auth.internal.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [JwtModule], exports: [JwtModule] })',
      'export class IdentityAuthInternalModule {}',
    ].join('\n'),
    'backend/src/modules/identity/public/identity-auth-public.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { JwtService } from '@attacker/jwt/node_modules/@nestjs/jwt';",
      "import { IdentityAuthInternalModule } from '../internal/identity-auth.internal.module';",
      "import { IDENTITY_ACCESS_TOKEN_VERIFIER } from './access-token-verifier.port';",
      '@Module({ imports: [IdentityAuthInternalModule], providers: [{ provide: IDENTITY_ACCESS_TOKEN_VERIFIER, useExisting: JwtService }], exports: [IDENTITY_ACCESS_TOKEN_VERIFIER] })',
      'export class IdentityAuthPublicModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws({
    ...options,
    providerContracts: [{ token: 'IDENTITY_ACCESS_TOKEN_VERIFIER', implementations: ['JwtService'] }],
  }).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('public-binding-not-use-existing'));
});

test('I4 decorator inventory follows actual checker-resolved use down to controller method and route', () => {
  const options = fixtureProject({
    'backend/src/auth/jwt-auth.guard.ts': 'export class JwtAuthGuard {}\n',
    'backend/src/auth/current-user.decorator.ts': 'export function CurrentUser(): ParameterDecorator { return () => undefined; }\n',
    'backend/src/admin/admin.guard.ts': 'export class AdminGuard {}\n',
    'backend/src/admin/admin-permission.guard.ts': 'export class AdminPermissionGuard {}\n',
    'backend/src/auth/jwt-session.guard.ts': 'export class JwtSessionGuard {}\n',
    'backend/src/tasks/task.controller.ts': [
      "import { Controller, Get, UseGuards } from '@nestjs/common';",
      "import { JwtAuthGuard as Guard } from '../auth/jwt-auth.guard';",
      "import { CurrentUser } from '../auth/current-user.decorator';",
      "@Controller('tasks')",
      'export class TaskController {',
      "  @UseGuards(Guard)",
      "  @Get(':id')",
      '  read(@CurrentUser() user: unknown) { return user; }',
      '}',
    ].join('\n'),
    'backend/src/tasks/unused.controller.ts': [
      "import { Controller } from '@nestjs/common';",
      "import { JwtAuthGuard } from '../auth/jwt-auth.guard';",
      "@Controller('unused') export class UnusedController {}",
      'void JwtAuthGuard;',
    ].join('\n'),
    'backend/src/tasks/fake-decorators.ts': [
      'export class JwtAuthGuard {}',
      'export function CurrentUser(): ParameterDecorator { return () => undefined; }',
    ].join('\n'),
    'backend/src/tasks/fake.controller.ts': [
      "import { Controller, Get, UseGuards } from '@nestjs/common';",
      "import { JwtAuthGuard, CurrentUser } from './fake-decorators';",
      "@Controller('fake') export class FakeController {",
      '  @UseGuards(JwtAuthGuard) @Get() read(@CurrentUser() user: unknown) { return user; }',
      '}',
    ].join('\n'),
    'backend/src/admin/admin.controller.ts': [
      "import { Controller, Get, UseGuards } from '@nestjs/common';",
      "import { JwtSessionGuard } from '../auth/jwt-session.guard';",
      "import { AdminGuard } from './admin.guard';",
      "import { AdminPermissionGuard } from './admin-permission.guard';",
      "@UseGuards(JwtSessionGuard, AdminGuard, AdminPermissionGuard)",
      "@Controller('admin')",
      'export class AdminController { @Get() list() {} }',
    ].join('\n'),
  });
  const result = scanner().collectR3DecoratorInventory(options);
  assert.deepEqual(result.decoratorRuntimeReferences.map((item: any) => item.symbol), [
    'JwtSessionGuard', 'JwtAuthGuard',
  ]);
  const taskGuard = result.decoratorRuntimeReferences.find((item: any) => item.symbol === 'JwtAuthGuard');
  assert.equal(taskGuard.uses[0].controllerClass, 'TaskController');
  assert.equal(taskGuard.uses[0].method, 'read');
  assert.equal(taskGuard.uses[0].routePrefix, 'tasks');
  assert.equal(taskGuard.uses[0].routeMethod, 'GET');
  assert.equal(taskGuard.uses[0].routePath, ':id');
  assert.equal(result.decoratorRuntimeReferences.some(
    (item: any) => item.source.endsWith('/unused.controller.ts'),
  ), false);
  assert.equal(result.decoratorRuntimeReferences.some(
    (item: any) => item.source.endsWith('/fake.controller.ts'),
  ), false);
  const currentUser = result.runtimeDecoratorValueReferences.find(
    (item: any) => item.symbol === 'CurrentUser',
  );
  assert.equal(currentUser.uses[0].controllerClass, 'TaskController');
  assert.equal(currentUser.uses[0].method, 'read');
  assert.equal(currentUser.uses[0].parameterIndex, 0);
  assert.equal(result.runtimeDecoratorValueReferences.some(
    (item: any) => item.source.endsWith('/fake.controller.ts'),
  ), false);
  assert.deepEqual(result.adminGuardMetadata, [{
    source: 'backend/src/admin/admin.controller.ts',
    controllerClass: 'AdminController',
    routePrefix: 'admin',
    guards: ['JwtSessionGuard', 'AdminGuard', 'AdminPermissionGuard'],
  }]);
});

test('forwardRef, unknown contexts, and Nest module cycles fail closed', () => {
  const options = fixtureProject({
    'backend/src/modules/unknown/public/value.ts': 'export const value = true;\n',
    'backend/src/modules/tasks/internal/a.module.ts': [
      "import { Module, forwardRef } from '@nestjs/common';",
      "import { BModule } from './b.module';",
      '@Module({ imports: [BModule, forwardRef(() => BModule)] })',
      'export class AModule {}',
    ].join('\n'),
    'backend/src/modules/tasks/internal/b.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { AModule } from './a.module';",
      '@Module({ imports: [AModule] })',
      'export class BModule {}',
    ].join('\n'),
  });
  const kinds = scanner().scanR3SourceLaws(options).diagnostics.map((item: any) => item.kind);
  assert.ok(kinds.includes('unknown-context'));
  assert.ok(kinds.includes('forward-ref'));
  assert.ok(kinds.includes('nest-module-cycle'));
});

test('manifest and result boundaries reject proxies, accessors, sparse arrays, and duplicates', () => {
  const { validateR3ContextManifest, validateR3ScanResult } = scanner();
  const manifest = loadManifest();
  assert.throws(() => validateR3ContextManifest(new Proxy(manifest, {})), /plain object/);
  const accessor = { ...manifest } as Record<string, unknown>;
  Object.defineProperty(accessor, 'stage', { get: () => 'inventory', enumerable: true });
  assert.throws(() => validateR3ContextManifest(accessor), /accessor|data property/);
  const sparse = { ...manifest, contexts: new Array(13) };
  assert.throws(() => validateR3ContextManifest(sparse), /dense/);
  const duplicate = { ...manifest, contexts: [...manifest.contexts, manifest.contexts[0]] };
  assert.throws(() => validateR3ContextManifest(duplicate), /duplicate|contexts/);
  assert.throws(() => validateR3ScanResult(new Proxy({ diagnostics: [], counts: {} }, {})), /plain object/);
});

test('mixed valid and invalid scan data is rejected atomically and the CLI is non-reflective', () => {
  const output: string[] = [];
  const exitCode = scanner().runCli({
    argv: ['--check', '--stage', 'inventory'],
    scan: () => ({
      diagnostics: [
        { kind: 'forward-ref', path: 'backend/src/tasks/a.ts', line: 1 },
        { kind: 'attacker-kind', path: 'C:\\private\\secret.ts', line: 2 },
      ],
      counts: {},
    }),
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => output.push(message),
  });
  assert.equal(exitCode, 2);
  assert.deepEqual(output, ['ERROR - R3 context scan failed']);
  assert.doesNotMatch(output.join('\n'), /private|attacker|secret/i);
});
