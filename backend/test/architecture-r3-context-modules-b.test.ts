import 'reflect-metadata';

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';

const sourceRoot = join(process.cwd(), 'src');

const fullModules = [
  'modules/marketplace/marketplace.module.ts',
  'modules/catalog/catalog.module.ts',
  'modules/media/media.module.ts',
  'modules/insights/insights.module.ts',
  'modules/backoffice/backoffice.module.ts',
] as const;

const retiredModules = [
  'marketplace/marketplace.module.ts',
  'provider-dashboard/provider-dashboard.module.ts',
  'catalogs/catalogs.module.ts',
  'media/media.module.ts',
  'dashboard/dashboard.module.ts',
  'timeline/timeline.module.ts',
  'admin/admin.module.ts',
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
    .sort();
}

test('Task 7 activates the five remaining business modules and retires legacy metadata', () => {
  for (const path of fullModules) {
    assert.equal(existsSync(join(sourceRoot, path)), true, `${path} must exist`);
  }
  for (const path of retiredModules) {
    assert.equal(existsSync(join(sourceRoot, path)), false, `${path} must be retired`);
  }
});

test('Task 7 AppModule composes the five contexts without legacy module imports', () => {
  const app = source('app.module.ts');
  for (const name of [
    'MarketplaceModule',
    'CatalogModule',
    'MediaModule',
    'InsightsModule',
    'BackofficeModule',
  ]) {
    assert.match(app, new RegExp(`\\b${name}\\b`));
  }
  for (const path of retiredModules) {
    const importPath = path.replace(/\.module\.ts$/, '.module');
    assert.doesNotMatch(
      app,
      new RegExp(`from ["']\\./${importPath.replace(/[./-]/g, '\\$&')}["']`),
    );
  }
});

test('Task 7 full modules preserve the exact controller ownership', () => {
  const expected = new Map<string, string[]>([
    ['modules/marketplace/marketplace.module.ts#MarketplaceModule', [
      'ApiV1QuoteOffersController', 'ApiV1QuoteRequestsController',
      'ApiV1WeddingPlanQuoteRequestsController', 'CitiesController',
      'GovernoratesController', 'MeBookingsController', 'MeMarketplaceController',
      'ProviderApplicationController', 'ProviderBookingsController',
      'ProviderCategoriesController',
      'ProviderDashboardController', 'ProvidersController', 'ReviewsController',
      'ServicesController',
    ]],
    ['modules/catalog/catalog.module.ts#CatalogModule', [
      'AdminAdministrativeCatalogController', 'AdminReferenceCatalogsController',
      'CatalogsController', 'DistrictLocalitiesController',
    ]],
    ['modules/media/media.module.ts#MediaModule', ['MediaController']],
    ['modules/insights/insights.module.ts#InsightsModule', [
      'DashboardController', 'TimelineController', 'WeddingPlanDashboardController',
    ]],
    ['modules/backoffice/backoffice.module.ts#BackofficeModule', [
      'AdminAuditController', 'AdminController',
    ]],
  ]);
  for (const [key, names] of expected) {
    const [path, className] = key.split('#');
    assert.deepEqual(
      metadataNames(moduleClass(path, className), MODULE_METADATA.CONTROLLERS),
      names.sort(),
    );
  }
});

test('Task 7 owner-private leaves register each remaining application service once', () => {
  const expected = new Map<string, string[]>([
    // The ownership program added marketplace's private relations service:
    // it attaches catalog's, planning's, identity's and finance's rows to
    // marketplace's own rows through their ports (its includes are gone).
    // Bookings and the provider calendar (V1 checklist 4.6) add BookingsService.
    ['modules/marketplace/internal/marketplace-services.internal.module.ts#MarketplaceServicesInternalModule', [
      'BookingsService', 'MarketplaceRelationsService', 'MarketplaceService', 'ProviderDashboardService',
    ]],
    ['modules/catalog/internal/catalog-services.internal.module.ts#CatalogServicesInternalModule', [
      'AdministrativeCatalogService', 'ReferenceCatalogService',
    ]],
    // Insights owns no tables: the ownership program added its private
    // InsightsReadPorts holder of the owner ports the dashboard and
    // timeline compose (their direct reads are gone).
    ['modules/insights/internal/insights-services.internal.module.ts#InsightsServicesInternalModule', [
      'DashboardService', 'InsightsReadPorts', 'TimelineService',
    ]],
    // The back office owns only its audit log: the ownership program added
    // its private AdminOwners holder of the owners' admin ports (the admin
    // service's and executor's direct reads and writes are gone).
    ['modules/backoffice/internal/backoffice-services.internal.module.ts#BackofficeServicesInternalModule', [
      'AdminAuditService', 'AdminOwners', 'AdminService',
    ]],
  ]);
  for (const [key, names] of expected) {
    const [path, className] = key.split('#');
    assert.deepEqual(
      metadataNames(moduleClass(path, className), MODULE_METADATA.PROVIDERS),
      names.sort(),
    );
  }
});

test('Task 7 keeps Admin guards controller-local and never registers or exports them', () => {
  const guardOrder = /@UseGuards\(JwtSessionGuard, AdminGuard, AdminPermissionGuard\)/g;
  const sources = [
    source('admin/admin.controller.ts'),
    source('admin/admin-audit.controller.ts'),
    source('catalogs/catalogs.controller.ts'),
  ];
  assert.equal(sources.reduce((count, value) => count + (value.match(guardOrder)?.length ?? 0), 0), 4);

  for (const path of [
    'modules/catalog/catalog.module.ts',
    'modules/catalog/internal/catalog-services.internal.module.ts',
    'modules/backoffice/backoffice.module.ts',
    'modules/backoffice/internal/backoffice-services.internal.module.ts',
  ]) {
    const value = source(path);
    assert.doesNotMatch(value, /providers\s*:\s*\[[^\]]*Admin(?:Permission)?Guard/s, path);
    assert.doesNotMatch(value, /exports\s*:\s*\[[^\]]*Admin(?:Permission)?Guard/s, path);
  }
  assert.equal(existsSync(join(sourceRoot, 'modules/backoffice/public/admin-guards-public.module.ts')), false);
});

test('Task 7 advances the manifest and retires duplicate providers and remaining legacy edges', () => {
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
