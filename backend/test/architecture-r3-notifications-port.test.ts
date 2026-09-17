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

function requiredSource(path: string): string {
  assert.equal(existsSync(join(sourceRoot, path)), true, `${path} must exist`);
  return source(path);
}

function sourceFile(path: string): ts.SourceFile {
  return ts.createSourceFile(
    path,
    requiredSource(path),
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
}

function interfaceMethods(path: string, name: string): string[] {
  const file = sourceFile(path);
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

function exportedTypeNames(path: string): string[] {
  return sourceFile(path).statements
    .filter(
      (statement): statement is
        | ts.InterfaceDeclaration
        | ts.TypeAliasDeclaration =>
        (ts.isInterfaceDeclaration(statement) ||
          ts.isTypeAliasDeclaration(statement)) &&
        statement.modifiers?.some(
          (modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword,
        ) === true,
    )
    .map((statement) => statement.name.text)
    .sort();
}

test('Task 4 publishes the exact notifications service contract and signature types', () => {
  const path = 'modules/notifications/public/notifications.port.ts';
  // The R3 surface is the frozen five; the ownership program added the
  // provider-message preference read messaging used to run on the
  // notification preference table itself. Frozen surfaces stay, may grow.
  assert.deepEqual(interfaceMethods(path, 'NotificationsPort'), [
    'createNotificationInTransaction',
    'listProviderMessagePreferences',
    'notifyTaskDue',
    'purgeMoneyForMember',
    'resolveProviderUpdateRecipientInTransaction',
    'visibilityWhereForUser',
  ]);
  // The visibility filter the port returns is declared by its exact keys
  // (plan, money, entity and provider clauses) so the ownership scan can
  // prove the notification reads that carry it; the client aliases stay.
  assert.deepEqual(exportedTypeNames(path), [
    'CreateNotificationInput',
    'EntityVisibilityWhere',
    'MoneyVisibilityWhere',
    'NotificationCreateClient',
    'NotificationPurgeClient',
    'NotificationResponse',
    'NotificationVisibilityClient',
    'NotificationVisibilityWhere',
    'NotificationsPort',
    'PlanVisibilityWhere',
    'ProviderAudienceWhere',
    'ProviderExclusionClause',
    'ProviderMessagePreference',
    'ProviderVisibilityWhere',
    'ScopedEntityClause',
  ]);
});

test('Task 4 public token aliases the exact existing NotificationsService singleton', async () => {
  const {
    NotificationsPublicModule,
  } = require('../src/modules/notifications/public/notifications-public.module');
  const {
    NOTIFICATIONS_PORT,
  } = require('../src/modules/notifications/public/notifications.port');
  const {
    NotificationsService,
  } = require('../src/notifications/notifications.service');
  const { PrismaService } = require('../src/platform/database/prisma.service');

  class NotificationsPortTestModule {}
  Module({ imports: [NotificationsPublicModule] })(NotificationsPortTestModule);
  const originalInit = PrismaService.prototype.onModuleInit;
  const originalDestroy = PrismaService.prototype.onModuleDestroy;
  PrismaService.prototype.onModuleInit = async () => undefined;
  PrismaService.prototype.onModuleDestroy = async () => undefined;
  let context: Awaited<ReturnType<typeof NestFactory.createApplicationContext>> | undefined;
  try {
    context = await NestFactory.createApplicationContext(
      NotificationsPortTestModule,
      { logger: false },
    );
    assert.equal(
      context.get(NOTIFICATIONS_PORT, { strict: false }),
      context.get(NotificationsService, { strict: false }),
    );
  } finally {
    await context?.close();
    PrismaService.prototype.onModuleInit = originalInit;
    PrismaService.prototype.onModuleDestroy = originalDestroy;
  }
});

test('Task 4 migrates the exact foreign service and type consumers', () => {
  const consumers = [
    'admin/admin.service.ts',
    'conversations/conversations.service.ts',
    'dashboard/dashboard.service.ts',
    'marketplace/marketplace.service.ts',
    'marketplace/quote-notifications.ts',
    'marketplace/quote-offer-acceptance.ts',
    'marketplace/quote-offer-rejection.ts',
    'marketplace/quote-request-creation.ts',
    'provider-dashboard/provider-dashboard.service.ts',
    'modules/collaboration/internal/sharing.service.ts',
    'tasks/tasks.service.ts',
  ];
  for (const path of consumers) {
    const text = source(path);
    assert.doesNotMatch(
      text,
      /from\s+['"]\.\.\/notifications\/notifications\.service['"]|from\s+['"]\.\.\/\.\.\/notifications\/notifications\.service['"]/,
      path,
    );
    assert.match(text, /notifications\/public\/notifications\.port/);
  }
});

test('Task 4 Notifications public imports remain on the strict owner leaves', () => {
  const modules = [
    'modules/backoffice/internal/backoffice-services.internal.module.ts',
    'modules/messaging/internal/messaging-conversations.internal.module.ts',
    'modules/insights/internal/insights-services.internal.module.ts',
    'modules/marketplace/internal/marketplace-services.internal.module.ts',
    'modules/collaboration/internal/collaboration-services.internal.module.ts',
    'modules/tasks/internal/tasks-service.internal.module.ts',
  ];
  for (const path of modules) {
    const text = source(path);
    assert.doesNotMatch(text, /notifications\/notifications\.module/);
    assert.match(text, /NotificationsPublicModule/);
  }
});

test('Task 4 keeps controllers and the reminder scheduler only in the owner full module', () => {
  const full = source('modules/notifications/notifications.module.ts');
  const lifecycle = source(
    'modules/notifications/internal/notifications-lifecycle.internal.module.ts',
  );
  const internal = requiredSource(
    'modules/notifications/internal/notifications-service.internal.module.ts',
  );
  const publicModule = requiredSource(
    'modules/notifications/public/notifications-public.module.ts',
  );
  assert.match(full, /NotificationsInternalModule/);
  assert.match(full, /NotificationsLifecycleInternalModule/);
  assert.match(full, /NotificationsController/);
  assert.match(lifecycle, /NotificationRemindersScheduler/);
  assert.doesNotMatch(internal, /NotificationRemindersScheduler|NotificationsController/);
  assert.doesNotMatch(publicModule, /NotificationRemindersScheduler|NotificationsController|NotificationsService/);
});

test('Task 4 advances the live manifest and exact retirement counts', () => {
  const manifest = JSON.parse(
    readFileSync(join(process.cwd(), 'architecture/r3-context-boundaries.json'), 'utf8'),
  ) as { stage: string };
  assert.equal(manifest.stage, 'strict');
  const scanner = require('../scripts/architecture/r3-context-scan.cjs') as {
    scanR3Contexts: (options: Record<string, unknown>) => {
      diagnostics: unknown[];
      counts: Record<string, number>;
    };
  };
  const result = scanner.scanR3Contexts({
    repoRoot: join(process.cwd(), '..'),
    backendRoot: process.cwd(),
    manifestPath: join(process.cwd(), 'architecture/r3-context-boundaries.json'),
    stage: 'strict',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.remainingDuplicateProviders, 0);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 0);
});
