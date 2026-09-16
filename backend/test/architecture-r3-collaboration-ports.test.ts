import 'reflect-metadata';

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import ts from 'typescript';

const sourceRoot = join(process.cwd(), 'src');
const forbiddenCollaborationImplementationImport =
  /from\s+['"]\.\.\/sharing\/permission\.service['"]|from\s+['"](?:\.\.\/)+(?:modules\/)?collaboration\/internal\/(?:contribution-history|contributor-scope)\.service['"]/;

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

// After the R12C closure the Task 3 surfaces are the frozen minimum the
// closed R3 law keeps present; the owner may add methods for later phases.
const closed = Boolean(require(join(process.cwd(), 'scripts', 'architecture', 'modular-monolith-closure.cjs')).readClosure(join(process.cwd(), '..')));

function assertSurface(actual: string[], frozen: string[]): void {
  if (closed) {
    assert.deepEqual(frozen.filter((method) => !actual.includes(method)), []);
    return;
  }
  assert.deepEqual(actual, frozen);
}

test('Task 3 publishes the exact collaboration port surfaces', () => {
  assertSurface(
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
  assertSurface(
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
  assertSurface(
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
  const { PermissionService } = require('../src/modules/collaboration/internal/permission.service');
  const {
    ContributionHistoryService,
  } = require('../src/modules/collaboration/internal/contribution-history.service');
  const {
    ContributorScopeService,
  } = require('../src/modules/collaboration/internal/contributor-scope.service');

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
    'modules/identity/internal/profile/contexts.service.ts',
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
    'modules/identity/internal/profile/users.service.ts',
    'wedding-costs/wedding-costs.service.ts',
    'wedding-plans/wedding-plans.service.ts',
  ];
  for (const path of foreignConsumers) {
    const text = source(path);
    assert.doesNotMatch(
      text,
      forbiddenCollaborationImplementationImport,
      path,
    );
  }
  assert.match(source('modules/collaboration/internal/sharing.service.ts'), /PermissionService/);
  assert.match(source('modules/collaboration/internal/sharing.service.ts'), /ContributionHistoryService/);
});

test('Task 3 foreign-consumer guard catches final contribution implementation imports', () => {
  assert.throws(
    () => assert.doesNotMatch(
      'import { ContributionHistoryService } from "../modules/collaboration/internal/contribution-history.service";',
      forbiddenCollaborationImplementationImport,
    ),
    /expected to not match/u,
  );
  assert.throws(
    () => assert.doesNotMatch(
      'import { ContributorScopeService } from "../modules/collaboration/internal/contributor-scope.service";',
      forbiddenCollaborationImplementationImport,
    ),
    /expected to not match/u,
  );
});

test('Task 3 removes the notifications PermissionService duplicate', () => {
  const notificationsModule = source('modules/notifications/notifications.module.ts');
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
