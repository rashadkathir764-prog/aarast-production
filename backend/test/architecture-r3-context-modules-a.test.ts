import 'reflect-metadata';

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';

const sourceRoot = join(process.cwd(), 'src');

const fullModules = [
  'modules/identity/identity.module.ts',
  'modules/planning/planning.module.ts',
  'modules/finance/finance.module.ts',
  'modules/collaboration/collaboration.module.ts',
  'modules/tasks/tasks.module.ts',
  'modules/guests/guests.module.ts',
] as const;

const retiredModules = [
  'auth/auth.module.ts',
  'users/users.module.ts',
  'me/me.module.ts',
  'contexts/contexts.module.ts',
  'wedding-plans/wedding-plans.module.ts',
  'onboarding/onboarding.module.ts',
  'money/money.module.ts',
  'budget-categories/budget-categories.module.ts',
  'wedding-costs/wedding-costs.module.ts',
  'sharing/sharing.module.ts',
  'contribution-history/contribution-history.module.ts',
  'tasks/tasks.module.ts',
  'guests/guests.module.ts',
] as const;

function source(path: string): string {
  return readFileSync(join(sourceRoot, path), 'utf8');
}

function moduleClass(path: string, name: string): Function {
  assert.equal(existsSync(join(sourceRoot, path)), true, `${path} must exist`);
  return require(join(sourceRoot, path))[name] as Function;
}

function metadataNames(module: Function, key: string): string[] {
  return ((Reflect.getMetadata(key, module) as Function[] | undefined) ?? [])
    .map((entry) => entry.name)
    .filter((name): name is string => Boolean(name))
    .sort();
}

test('Task 6 activates the six canonical full modules and retires legacy metadata', () => {
  for (const path of fullModules) {
    assert.equal(existsSync(join(sourceRoot, path)), true, `${path} must exist`);
  }
  for (const path of retiredModules) {
    assert.equal(existsSync(join(sourceRoot, path)), false, `${path} must be retired`);
  }
});

test('Task 6 AppModule composes the six contexts without legacy module imports', () => {
  const app = source('app.module.ts');
  for (const name of [
    'IdentityModule',
    'PlanningModule',
    'FinanceModule',
    'CollaborationModule',
    'TasksModule',
    'GuestsModule',
  ]) {
    assert.match(app, new RegExp(`\\b${name}\\b`));
  }
  for (const path of retiredModules) {
    assert.doesNotMatch(app, new RegExp(path.replace(/[.]/g, '\\.').replace('/module\\.ts', '')));
  }
});

test('Task 6 full modules preserve the exact controller ownership', () => {
  const expected = new Map<string, string[]>([
    ['modules/identity/identity.module.ts#IdentityModule', [
      // D63: the deletion request and its status (no immediate erasure), and
      // the one-time download of the account's data.
      'AccountDeletionStatusController', 'AuthController', 'ContextsController',
      'DataExportsController',
      'MeController', 'UsersController',
    ]],
    ['modules/planning/planning.module.ts#PlanningModule', [
      'OnboardingController', 'WeddingPlansController',
    ]],
    ['modules/finance/finance.module.ts#FinanceModule', [
      // Receipts (V1 checklist 4.4) add CostReceiptsController.
      'BudgetCategoriesController', 'CostPaymentsController', 'CostReceiptsController', 'CostsController',
      'FundingSourcesController', 'LoanRepaymentsController',
      'MoneySummaryController', 'PaymentSchedulesController',
      'WeddingPlanBudgetCategoriesController', 'WeddingPlanCostPaymentsController',
      'WeddingPlanCostsController', 'WeddingPlanFundingSourcesController',
      'WeddingPlanPaymentSchedulesController',
    ]],
    ['modules/collaboration/collaboration.module.ts#CollaborationModule', [
      'ApiV1InviteAcceptController', 'ApiV1InviteAccessController',
      'ApiV1InvitesController', 'ApiV1WeddingPlanInvitesController',
      'ApiV1WeddingPlanMembersController', 'ApiV1WeddingPlanPermissionsController',
      'ContributionHistoryController', 'SharedWeddingPlansController',
    ]],
    ['modules/tasks/tasks.module.ts#TasksModule', [
      'TasksController', 'WeddingPlanTasksController',
    ]],
    ['modules/guests/guests.module.ts#GuestsModule', [
      'GuestGroupsController', 'GuestInvitationLinksController', 'GuestsController',
      'PublicRsvpController',
      'WeddingPlanGuestGroupsController', 'WeddingPlanGuestsController',
    ]],
  ]);
  for (const [key, names] of expected) {
    const [path, className] = key.split('#');
    assert.deepEqual(metadataNames(moduleClass(path, className), MODULE_METADATA.CONTROLLERS), names.sort());
  }
});

test('Task 6 internal leaves own each non-public implementation exactly once', () => {
  const expected = new Map<string, string[]>([
    ['modules/identity/internal/identity-profile.internal.module.ts#IdentityProfileInternalModule', [
      // D63: the deletion grace, its hourly purge and the data download.
      'AccountDeletionPurgeScheduler', 'AccountDeletionService', 'ContextsService',
      'DataExportService', 'UsersService',
    ]],
    ['modules/planning/internal/planning-services.internal.module.ts#PlanningServicesInternalModule', ['OnboardingService', 'WeddingPlansService']],
    ['modules/planning/internal/planning-budget-write.internal.module.ts#PlanningBudgetWriteInternalModule', ['WeddingPlanBudgetWriter']],
    // Receipts (V1 checklist 4.4) add CostReceiptsService.
    ['modules/finance/internal/finance-services.internal.module.ts#FinanceServicesInternalModule', ['BudgetCategoriesService', 'CostReceiptsService', 'FundingSourcesService', 'MoneyBudgetService', 'MoneySummaryService', 'WeddingCostsService']],
    ['modules/collaboration/internal/collaboration-services.internal.module.ts#CollaborationServicesInternalModule', ['InvitationDeliveryService', 'InviteAccessService', 'SharingService']],
    ['modules/tasks/internal/tasks-service.internal.module.ts#TasksServiceInternalModule', ['TasksService']],
    ['modules/guests/internal/guests-service.internal.module.ts#GuestsServiceInternalModule', ['GuestsService']],
    ['modules/guests/internal/guests-rsvp.internal.module.ts#GuestsRsvpInternalModule', ['GuestRsvpService']],
  ]);
  for (const [key, names] of expected) {
    const [path, className] = key.split('#');
    assert.deepEqual(metadataNames(moduleClass(path, className), MODULE_METADATA.PROVIDERS), names.sort());
  }
});

test('Task 6 full modules export no concrete implementation classes', () => {
  for (const path of fullModules) {
    const pathParts = path.split('/');
    const className = pathParts[pathParts.length - 1]
      .replace('.ts', '')
      .split(/[.-]/)
      .map((part: string) => part[0].toUpperCase() + part.slice(1))
      .join('');
    const module = moduleClass(path, className);
    assert.deepEqual(metadataNames(module, MODULE_METADATA.EXPORTS), [], path);
  }
});

test('Task 6 advances the live manifest without retiring Task 7 edges early', () => {
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
  assert.equal(result.counts.remainingPlatformDebts, 0);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 0);
});
