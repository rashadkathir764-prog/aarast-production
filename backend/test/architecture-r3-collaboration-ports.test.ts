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

function interfaceMethods(path: string, name: string): string[] {
  const file = ts.createSourceFile(
    path,
    requiredSource(path),
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

test('Task 3 publishes the exact collaboration port surfaces', () => {
  assert.deepEqual(
    interfaceMethods(
      'modules/collaboration/public/collaboration-permission.port.ts',
      'CollaborationPermissionPort',
    ),
    [
      'assertGuestManageableInTransaction',
      'assertMemberManageable',
      'assertMemberManageableInTransaction',
      'assertMoneyManageable',
      'assertMoneyManageableForUpdateInTransaction',
      'assertMoneyManageableInTransaction',
      'assertMoneyReadable',
      'assertMoneyReadableInTransaction',
      'assertPlanManageableForUpdateInTransaction',
      'assertPlanReadable',
      'assertPlanReadableForUserUpdateInTransaction',
      'assertPlanReadableInTransaction',
      'assertProviderAndMoneyManageableInTransaction',
      'assertProviderManageable',
      'assertProviderManageableInTransaction',
      'assertTaskManageableInTransaction',
      'canManageGuests',
      'canManageMembers',
      'canManageMoney',
      'canManagePlan',
      'canManageProviders',
      'canManageTasks',
      'canViewMoney',
      'livePlanAuthorizationWhere',
    ],
  );
  assert.deepEqual(
    interfaceMethods(
      'modules/collaboration/public/collaboration-history.port.ts',
      'CollaborationHistoryPort',
    ),
    [
      'ensureTenureInTransaction',
      'recordForContextInTransaction',
      'recordInTransaction',
      'summary',
    ],
  );
  assert.deepEqual(
    interfaceMethods(
      'modules/collaboration/public/collaboration-scope.port.ts',
      'CollaborationScopePort',
    ),
    ['qualifyingEntityIds', 'qualifyingEntityIdsInTransaction'],
  );
});

test('Task 3 leaves alias public tokens to one owner implementation', async () => {
  const {
    CollaborationPermissionPublicModule,
  } = require('../src/modules/collaboration/public/collaboration-permission-public.module');
  const {
    COLLABORATION_PERMISSION_PORT,
  } = require('../src/modules/collaboration/public/collaboration-permission.port');
  const {
    CollaborationHistoryPublicModule,
  } = require('../src/modules/collaboration/public/collaboration-history-public.module');
  const {
    COLLABORATION_HISTORY_PORT,
  } = require('../src/modules/collaboration/public/collaboration-history.port');
  const {
    CollaborationScopePublicModule,
  } = require('../src/modules/collaboration/public/collaboration-scope-public.module');
  const {
    COLLABORATION_SCOPE_PORT,
  } = require('../src/modules/collaboration/public/collaboration-scope.port');
  const { PermissionService } = require('../src/sharing/permission.service');
  const {
    ContributionHistoryService,
  } = require('../src/contribution-history/contribution-history.service');
  const {
    ContributorScopeService,
  } = require('../src/contribution-history/contributor-scope.service');

  class CollaborationPortTestModule {}
  Module({
    imports: [
      CollaborationPermissionPublicModule,
      CollaborationHistoryPublicModule,
      CollaborationScopePublicModule,
    ],
  })(CollaborationPortTestModule);
  const { PrismaService } = require('../src/platform/database/prisma.service');
  const originalInit = PrismaService.prototype.onModuleInit;
  const originalDestroy = PrismaService.prototype.onModuleDestroy;
  PrismaService.prototype.onModuleInit = async () => undefined;
  PrismaService.prototype.onModuleDestroy = async () => undefined;
  let context: Awaited<ReturnType<typeof NestFactory.createApplicationContext>> | undefined;
  try {
    context = await NestFactory.createApplicationContext(
      CollaborationPortTestModule,
      { logger: false },
    );
    assert.equal(
      context.get(COLLABORATION_PERMISSION_PORT, { strict: false }),
      context.get(PermissionService, { strict: false }),
    );
    assert.equal(
      context.get(COLLABORATION_HISTORY_PORT, { strict: false }),
      context.get(ContributionHistoryService, { strict: false }),
    );
    assert.equal(
      context.get(COLLABORATION_SCOPE_PORT, { strict: false }),
      context.get(ContributorScopeService, { strict: false }),
    );
  } finally {
    await context?.close();
    PrismaService.prototype.onModuleInit = originalInit;
    PrismaService.prototype.onModuleDestroy = originalDestroy;
  }
});

test('Task 3 foreign consumers no longer import collaboration implementations', () => {
  const foreignConsumers = [
    'budget-categories/budget-categories.service.ts',
    'contexts/contexts.service.ts',
    'dashboard/dashboard-contributor-scope.ts',
    'dashboard/dashboard.service.ts',
    'guests/guests.service.ts',
    'marketplace/marketplace-contributor-quote-scope.ts',
    'marketplace/marketplace-write-locks.ts',
    'marketplace/marketplace.service.ts',
    'marketplace/quote-offer-acceptance.ts',
    'marketplace/quote-offer-rejection.ts',
    'marketplace/quote-request-cancellation.ts',
    'marketplace/quote-request-creation.ts',
    'money/money-budget.service.ts',
    'money/money-summary.service.ts',
    'notifications/notifications.service.ts',
    'provider-dashboard/provider-dashboard.service.ts',
    'tasks/tasks.service.ts',
    'timeline/timeline.service.ts',
    'users/users.service.ts',
    'wedding-costs/wedding-costs.service.ts',
    'wedding-plans/wedding-plans.service.ts',
  ];
  for (const path of foreignConsumers) {
    const text = source(path);
    assert.doesNotMatch(
      text,
      /from\s+['"]\.\.\/sharing\/permission\.service['"]|from\s+['"]\.\.\/contribution-history\/(?:contribution-history|contributor-scope)\.service['"]/,
      path,
    );
  }
  assert.match(source('sharing/sharing.service.ts'), /PermissionService/);
  assert.match(source('sharing/sharing.service.ts'), /ContributionHistoryService/);
});

test('Task 3 removes the notifications PermissionService duplicate', () => {
  const notificationsModule = source('notifications/notifications.module.ts');
  const notificationsInternal = source(
    'modules/notifications/internal/notifications-service.internal.module.ts',
  );
  assert.match(notificationsInternal, /CollaborationPermissionPublicModule/);
  assert.doesNotMatch(notificationsModule, /providers:[\s\S]*PermissionService/);
});

test('Task 3 advances the live manifest and exact retirement counts', () => {
  const manifest = JSON.parse(
    readFileSync(join(process.cwd(), 'architecture/r3-context-boundaries.json'), 'utf8'),
  ) as { stage: string };
  assert.equal(manifest.stage, 'task-6');
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
    stage: 'task-6',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.remainingDuplicateProviders, 2);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 2);
});
