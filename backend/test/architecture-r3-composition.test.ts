import 'reflect-metadata';

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import ts from 'typescript';

const sourceRoot = join(process.cwd(), 'src');

function source(path: string): string {
  return readFileSync(join(sourceRoot, path), 'utf8');
}

function exportedInterfaceMethods(path: string, name: string): string[] {
  const file = ts.createSourceFile(
    path,
    source(path),
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  const declaration = file.statements.find(
    (statement): statement is ts.InterfaceDeclaration =>
      ts.isInterfaceDeclaration(statement) && statement.name.text === name,
  );
  assert.ok(declaration, `${name} must be declared in ${path}`);
  return declaration.members
    .filter(ts.isMethodSignature)
    .map((member) => member.name.getText(file))
    .sort();
}

function requireTask2File(path: string): string {
  const absolutePath = join(sourceRoot, path);
  assert.equal(existsSync(absolutePath), true, `${path} must exist`);
  return source(path);
}

test('Task 2 moves the exact Identity session types without a compatibility path', () => {
  assert.equal(
    existsSync(join(sourceRoot, 'auth/authenticated-user.interface.ts')),
    false,
  );
  const identityTypes = requireTask2File(
    'modules/identity/public/identity-session.types.ts',
  );
  assert.match(identityTypes, /export interface AuthenticatedUser/);
  assert.match(
    identityTypes,
    /export type JwtSessionScope\s*=\s*['"]application['"]\s*\|\s*['"]admin['"]/,
  );
  assert.doesNotMatch(
    source('modules/identity/public/jwt-payload.interface.ts'),
    /type JwtSessionScope/,
  );

  const legacyImports: string[] = [];
  const scan = (path: string) => {
    const text = readFileSync(path, 'utf8');
    const file = ts.createSourceFile(
      path,
      text,
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.TS,
    );
    if (
      file.statements.some(
        (statement) =>
          ts.isImportDeclaration(statement) &&
          ts.isStringLiteral(statement.moduleSpecifier) &&
          /authenticated-user\.interface/.test(statement.moduleSpecifier.text),
      )
    ) {
      legacyImports.push(path);
    }
  };
  const walk = (directory: string) => {
    for (const entry of require('node:fs').readdirSync(directory, {
      withFileTypes: true,
    })) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (/\.(?:ts|tsx)$/.test(entry.name)) scan(path);
    }
  };
  walk(sourceRoot);
  walk(join(process.cwd(), 'test'));
  assert.deepEqual(legacyImports, []);
});

// After the R12C closure the Task 2 surfaces are the frozen minimum the
// closed R3 law keeps present; the owner may add methods for later phases.
const closed = Boolean(require(join(process.cwd(), 'scripts', 'architecture', 'modular-monolith-closure.cjs')).readClosure(join(process.cwd(), '..')));

function assertSurface(actual: string[], frozen: string[]): void {
  if (closed) {
    assert.deepEqual(frozen.filter((method) => !actual.includes(method)), []);
    return;
  }
  assert.deepEqual(actual, frozen);
}

test('Task 2 public ports expose only the frozen foreign-consumer surface', () => {
  assertSurface(
    exportedInterfaceMethods(
      'modules/messaging/public/messaging-realtime.port.ts',
      'MessagingRealtimePort',
    ),
    [
      'disconnectSession',
      'disconnectUser',
      'dispatchActivityAvailable',
      'dispatchConversationAccessRevoked',
      'dispatchMessageAvailable',
      'dispatchNotificationAvailable',
      'dispatchSessionRevoked',
      'dispatchUserSessionsRevoked',
      'revokeConversationAccess',
    ],
  );
  assertSurface(
    exportedInterfaceMethods(
      'modules/media/public/media-storage.port.ts',
      'MediaStoragePort',
    ),
    [
      'checkReadiness',
      'consumePublicMediaUrl',
      'consumeUpload',
      'createDownloadUrl',
      'lockAccountDeletionBoundary',
      'scheduleAllOwnedMediaDeletion',
      'scheduleApplicationIdentityMediaDeletion',
      'scheduleTargetDeletion',
      'verifyPublicMediaUrl',
      'verifyUpload',
    ],
  );
  assertSurface(
    exportedInterfaceMethods(
      'modules/notifications/public/push-delivery.port.ts',
      'PushDeliveryPort',
    ),
    ['dispatchNotification'],
  );
  const capability = requireTask2File(
    'modules/notifications/public/push-capability.port.ts',
  );
  assert.match(capability, /readonly enabled\s*:\s*boolean/);
});

test('Task 2 leaves bind public Symbols to one owner implementation with useExisting', () => {
  const expectations = [
    [
      'modules/messaging/internal/messaging-realtime.internal.module.ts',
      'MESSAGING_REALTIME_IMPLEMENTATION',
      'ConversationRealtimePublisher',
    ],
    [
      'modules/messaging/public/messaging-realtime-public.module.ts',
      'MESSAGING_REALTIME_PORT',
      'MESSAGING_REALTIME_IMPLEMENTATION',
    ],
    [
      'modules/media/internal/media-storage.internal.module.ts',
      'MEDIA_STORAGE_IMPLEMENTATION',
      'MediaStorageService',
    ],
    [
      'modules/media/public/media-storage-public.module.ts',
      'MEDIA_STORAGE_PORT',
      'MEDIA_STORAGE_IMPLEMENTATION',
    ],
    [
      'modules/notifications/internal/push-transport.internal.module.ts',
      'PUSH_DELIVERY_IMPLEMENTATION',
      'PushDeliveryService',
    ],
    [
      'modules/notifications/internal/push-transport.internal.module.ts',
      'PUSH_CAPABILITY_IMPLEMENTATION',
      'FirebasePushClient',
    ],
    [
      'modules/notifications/public/push-delivery-public.module.ts',
      'PUSH_DELIVERY_PORT',
      'PUSH_DELIVERY_IMPLEMENTATION',
    ],
    [
      'modules/notifications/public/push-capability-public.module.ts',
      'PUSH_CAPABILITY_PORT',
      'PUSH_CAPABILITY_IMPLEMENTATION',
    ],
  ] as const;
  for (const [path, provide, existing] of expectations) {
    const text = requireTask2File(path);
    assert.match(
      text,
      new RegExp(
        `provide\\s*:\\s*${provide}[\\s\\S]*?useExisting\\s*:\\s*${existing}`,
      ),
      path,
    );
  }

  assert.equal(
    readFileSync(
      join(sourceRoot, 'conversations/conversation-realtime.module.ts'),
      'utf8',
    ),
    [
      "import { Module } from '@nestjs/common';",
      "import { ConversationRealtimePublisher } from './conversation-realtime.publisher';",
      '',
      '@Module({',
      '  providers: [ConversationRealtimePublisher],',
      '  exports: [ConversationRealtimePublisher],',
      '})',
      'export class ConversationRealtimeModule {}',
      '',
    ].join('\n'),
  );
});

test('Task 2 public tokens resolve to the exact single legacy instances', async () => {
  const {
    MessagingRealtimePublicModule,
  } = require('../src/modules/messaging/public/messaging-realtime-public.module');
  const {
    MESSAGING_REALTIME_PORT,
  } = require('../src/modules/messaging/public/messaging-realtime.port');
  const {
    MESSAGING_REALTIME_IMPLEMENTATION,
  } = require('../src/modules/messaging/internal/messaging-realtime.implementation-token');
  const {
    ConversationRealtimePublisher,
  } = require('../src/conversations/conversation-realtime.publisher');
  const {
    MediaStoragePublicModule,
  } = require('../src/modules/media/public/media-storage-public.module');
  const {
    MEDIA_STORAGE_PORT,
  } = require('../src/modules/media/public/media-storage.port');
  const { MediaStorageService } = require('../src/media/media-storage.service');
  const {
    PushDeliveryPublicModule,
  } = require('../src/modules/notifications/public/push-delivery-public.module');
  const {
    PUSH_DELIVERY_PORT,
  } = require('../src/modules/notifications/public/push-delivery.port');
  const {
    PushCapabilityPublicModule,
  } = require('../src/modules/notifications/public/push-capability-public.module');
  const {
    PUSH_CAPABILITY_PORT,
  } = require('../src/modules/notifications/public/push-capability.port');
  const { PushDeliveryService } = require('../src/modules/notifications/infrastructure/push-delivery.service');
  const { FirebasePushClient } = require('../src/push/firebase-push.client');

  class Task2SingletonTestModule {}
  Module({
    imports: [
      MessagingRealtimePublicModule,
      MediaStoragePublicModule,
      PushDeliveryPublicModule,
      PushCapabilityPublicModule,
    ],
  })(Task2SingletonTestModule);
  const { PrismaService } = require('../src/platform/database/prisma.service');
  const originalInit = PrismaService.prototype.onModuleInit;
  const originalDestroy = PrismaService.prototype.onModuleDestroy;
  PrismaService.prototype.onModuleInit = async () => undefined;
  PrismaService.prototype.onModuleDestroy = async () => undefined;
  let context: Awaited<ReturnType<typeof NestFactory.createApplicationContext>>
    | undefined;
  try {
    context = await NestFactory.createApplicationContext(
      Task2SingletonTestModule,
      { logger: false },
    );
    assert.equal(
      context.get(MESSAGING_REALTIME_PORT, { strict: false }),
      context.get(ConversationRealtimePublisher, { strict: false }),
    );
    assert.equal(
      context.get(MESSAGING_REALTIME_IMPLEMENTATION, { strict: false }),
      context.get(ConversationRealtimePublisher, { strict: false }),
    );
    assert.equal(
      context.get(MEDIA_STORAGE_PORT, { strict: false }),
      context.get(MediaStorageService, { strict: false }),
    );
    assert.equal(
      context.get(PUSH_DELIVERY_PORT, { strict: false }),
      context.get(PushDeliveryService, { strict: false }),
    );
    assert.equal(
      context.get(PUSH_CAPABILITY_PORT, { strict: false }),
      context.get(FirebasePushClient, { strict: false }),
    );
  } finally {
    await context?.close();
    PrismaService.prototype.onModuleInit = originalInit;
    PrismaService.prototype.onModuleDestroy = originalDestroy;
  }
});

test('Task 2 migrates only the eight frozen foreign provider consumers', () => {
  const expectations = new Map<string, [string[], string[]]>([
    [
      'admin/admin.service.ts',
      [['MESSAGING_REALTIME_PORT'], ['ConversationRealtimePublisher']],
    ],
    [
      'modules/identity/internal/auth/auth.service.ts',
      [['MESSAGING_REALTIME_PORT'], ['ConversationRealtimePublisher']],
    ],
    [
      'modules/collaboration/internal/sharing.service.ts',
      [['MESSAGING_REALTIME_PORT'], ['ConversationRealtimePublisher']],
    ],
    [
      'modules/identity/internal/profile/users.service.ts',
      [
        ['MESSAGING_REALTIME_PORT', 'MEDIA_STORAGE_PORT', 'PUSH_CAPABILITY_PORT'],
        ['ConversationRealtimePublisher', 'MediaStorageService', 'FirebasePushClient'],
      ],
    ],
    [
      'conversations/conversations.service.ts',
      [['MEDIA_STORAGE_PORT'], ['MediaStorageService']],
    ],
    [
      'provider-dashboard/provider-dashboard.service.ts',
      [['MEDIA_STORAGE_PORT'], ['MediaStorageService']],
    ],
    [
      'platform/health/readiness.service.ts',
      [['MEDIA_READINESS_PORT'], ['MediaStorageService']],
    ],
    [
      'platform/outbox/outbox.dispatcher.ts',
      [
        ['OUTBOX_REALTIME_SINK', 'OUTBOX_PUSH_SINK'],
        ['ConversationRealtimePublisher', 'PushDeliveryService'],
      ],
    ],
  ]);
  for (const [path, [tokens, concreteNames]] of expectations) {
    const text = source(path);
    for (const concreteName of concreteNames) {
      assert.doesNotMatch(text, new RegExp(`\\b${concreteName}\\b`), path);
    }
    for (const token of tokens) {
      assert.match(text, new RegExp(`@Inject\\(${token}\\)`), `${path}: ${token}`);
    }
  }
});

test('Task 2 composes Outbox runtime and readiness at the exact root seams', () => {
  assert.equal(existsSync(join(sourceRoot, 'platform/outbox/outbox.module.ts')), false);
  const core = requireTask2File('platform/outbox/outbox-core.module.ts');
  assert.match(core, /providers:\s*\[\s*OutboxService\s*,\s*OutboxCleanupScheduler\s*\]/);
  assert.doesNotMatch(core, /OutboxDispatcher|OutboxWorker|conversations|push/);

  const runtime = requireTask2File(
    'application-composition/application-outbox-runtime.module.ts',
  );
  assert.match(runtime, /OutboxCoreModule/);
  assert.match(runtime, /MessagingRealtimePublicModule/);
  assert.match(runtime, /PushDeliveryPublicModule/);
  assert.match(runtime, /provide:\s*OUTBOX_REALTIME_SINK[\s\S]*useExisting:\s*MESSAGING_REALTIME_PORT/);
  assert.match(runtime, /provide:\s*OUTBOX_PUSH_SINK[\s\S]*useExisting:\s*PUSH_DELIVERY_PORT/);
  assert.match(runtime, /OutboxDispatcher/);
  assert.match(runtime, /OutboxWorker/);

  const app = source('app.module.ts');
  assert.match(app, /ApplicationOutboxRuntimeModule/);
  assert.match(app, /MediaStoragePublicModule/);
  assert.match(
    app,
    /provide:\s*MEDIA_READINESS_PORT[\s\S]*useExisting:\s*MEDIA_STORAGE_PORT/,
  );
  assert.doesNotMatch(app, /OutboxModule/);
});

test('Task 2 push reachability is preserved through the strict Notifications owner', () => {
  assert.equal(existsSync(join(sourceRoot, 'push/push.module.ts')), false);
  const notifications = source('modules/notifications/notifications.module.ts');
  assert.match(notifications, /controllers:\s*\[NotificationsController, PushController\]/);
  assert.match(notifications, /PushInstallationsInternalModule/);
  assert.doesNotMatch(notifications, /FirebasePushClient|PushDeliveryService|PushModule/);

  const installations = source(
    'modules/notifications/internal/push-installations.internal.module.ts',
  );
  assert.match(installations, /providers:\s*\[PushInstallationsService\]/);
  const transport = source('modules/notifications/internal/push-transport.internal.module.ts');
  assert.match(transport, /FirebasePushClient/);
  assert.match(transport, /PushDeliveryService/);
});

test('R3 manifest and CLI enforce the live strict stage', () => {
  const manifest = JSON.parse(
    readFileSync(
      join(process.cwd(), 'architecture/r3-context-boundaries.json'),
      'utf8',
    ),
  ) as { stage: string };
  assert.equal(manifest.stage, 'strict');

  const scanner = require('../scripts/architecture/r3-context-scan.cjs') as {
    scanR3Contexts: (options: Record<string, unknown>) => {
      diagnostics: unknown[];
      counts: Record<string, number>;
    };
    runCli: (options: Record<string, unknown>) => number;
  };
  const result = scanner.scanR3Contexts({
    repoRoot: join(process.cwd(), '..'),
    backendRoot: process.cwd(),
    manifestPath: join(
      process.cwd(),
      'architecture/r3-context-boundaries.json',
    ),
    stage: 'strict',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.remainingPlatformDebts, 0);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 0);

  const output: string[] = [];
  assert.equal(
    scanner.runCli({
      argv: ['--check', '--stage', 'strict'],
      scan: () => result,
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }),
    0,
  );
  assert.match(output.join('\n'), /PASS - R3 contexts/);
});
