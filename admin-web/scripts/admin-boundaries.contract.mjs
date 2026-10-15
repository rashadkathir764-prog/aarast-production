import assert from 'node:assert/strict';
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import * as boundaries from './admin-boundaries.mjs';

const owners = [
  'auth',
  'audit',
  'catalog',
  'dashboard',
  'moderation',
  'notifications',
  'providers',
  'users',
];

function requireBoundaryImplementation() {
  for (const name of [
    'parseAdminModuleSpecifiers',
    'resolveAdminSpecifier',
    'classifyAdminPath',
    'scanAdminBoundaries',
  ]) assert.equal(typeof boundaries[name], 'function', `${name} must exist`);
}

function testManifest(overrides = {}) {
  return {
    features: owners,
    allowedFeatureEdges: {
      auth: [],
      audit: [],
      catalog: ['auth', 'providers'],
      dashboard: ['auth', 'providers'],
      moderation: ['auth', 'providers'],
      notifications: ['auth'],
      providers: ['auth'],
      users: ['auth'],
    },
    appScreenAllowlist: ['features/auth/LoginPage.tsx'],
    compositionRoots: ['App.tsx', 'main.tsx', 'layout/**'],
    publicSurfaces: Object.fromEntries(owners.map((owner) => [owner, []])),
    publicSurfaceFirstTask: Object.fromEntries(owners.map((owner) => [owner, 99])),
    stages: {
      'task-1': {
        legacyRoots: { api: [], auth: [], components: [], pages: [] },
      },
      strict: {
        legacyRoots: { api: [], auth: [], components: [], pages: [] },
      },
    },
    sourceFates: [],
    createdTargets: [],
    ...overrides,
  };
}

function withFixture(files, callback, options = {}) {
  requireBoundaryImplementation();
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'aarast-admin-boundaries-'));
  const srcRoot = path.join(fixture, 'src');
  mkdirSync(srcRoot, { recursive: true });
  try {
    for (const [relativePath, sourceText] of Object.entries(files)) {
      const target = path.join(srcRoot, ...relativePath.split('/'));
      mkdirSync(path.dirname(target), { recursive: true });
      writeFileSync(target, sourceText, 'utf8');
    }
    return callback({ fixture, srcRoot });
  } finally {
    if (!options.retain) rmSync(fixture, { recursive: true, force: true });
  }
}

function scan(files, manifestOverrides = {}, stage = 'task-1') {
  return withFixture(files, ({ srcRoot }) => boundaries.scanAdminBoundaries({
    srcRoot,
    manifest: testManifest(manifestOverrides),
    stage,
  }));
}

function errorKinds(result) {
  return result.errors.map(({ kind }) => kind);
}

test('accepts same-feature imports', () => {
  const result = scan({
    'features/auth/api.ts': "export { value } from './value';\n",
    'features/auth/value.ts': 'export const value = 1;\n',
  });
  assert.deepEqual(result.errors, []);
});

test('accepts platform and design-system imports from a feature', () => {
  const result = scan({
    'features/auth/LoginPage.tsx': [
      "import { client } from '../../platform/api/client';",
      "import { Button } from '../../design_system/Button';",
      'export const LoginPage = () => Button(client);',
    ].join('\n'),
    'platform/api/client.ts': 'export const client = 1;\n',
    'design_system/Button.tsx': 'export const Button = (value) => value;\n',
  });
  assert.deepEqual(result.errors, []);
});

test('accepts only an allowed feature edge through owner api.ts', () => {
  const result = scan({
    'features/dashboard/view.ts': "import { user } from '../auth/api';\nexport { user };\n",
    'features/auth/api.ts': 'export const user = 1;\n',
  }, { publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, auth: 1 }, publicSurfaces: { ...testManifest().publicSurfaces, auth: ['user'] } });
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.edges, ['dashboard -> auth']);
});

test('rejects a deep cross-feature import', () => {
  const result = scan({
    'features/dashboard/view.ts': "import '../auth/private';\n",
    'features/auth/private.ts': 'export const hidden = true;\n',
  });
  assert.ok(errorKinds(result).includes('deep-cross-feature-import'));
});

test('rejects an undeclared feature edge', () => {
  const result = scan({
    'features/audit/view.ts': "import '../auth/api';\n",
    'features/auth/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(result).includes('undeclared-feature-edge'));
});

test('rejects providers importing catalog', () => {
  const result = scan({
    'features/providers/view.ts': "import '../catalog/api';\n",
    'features/catalog/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(result).includes('undeclared-feature-edge'));
});

test('rejects platform importing a feature', () => {
  const result = scan({
    'platform/api/client.ts': "import '../../features/auth/api';\n",
    'features/auth/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(result).includes('platform-dependency-violation'));
});

test('rejects design-system importing a feature or layout', () => {
  const featureResult = scan({
    'design_system/Button.tsx': "import '../features/auth/api';\n",
    'features/auth/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(featureResult).includes('design-system-dependency-violation'));
  const layoutResult = scan({
    'design_system/Button.tsx': "import '../layout/Sidebar';\n",
    'layout/Sidebar.tsx': 'export const Sidebar = 1;\n',
  });
  assert.ok(errorKinds(layoutResult).includes('design-system-dependency-violation'));
});

test('accepts exact App main layout composition roots', () => {
  const result = scan({
    'App.tsx': "import './features/auth/LoginPage';\nimport './features/auth/api';\n",
    'main.tsx': "import './features/auth/api';\n",
    'layout/AdminLayout.tsx': "import '../features/auth/api';\n",
    'features/auth/LoginPage.tsx': 'export const LoginPage = 1;\n',
    'features/auth/api.ts': 'export {};\n',
  });
  assert.deepEqual(result.errors, []);
});

test('accepts only the exact App screen-import allowlist', () => {
  const accepted = scan({
    'App.tsx': "import './features/auth/LoginPage';\n",
    'features/auth/LoginPage.tsx': 'export const LoginPage = 1;\n',
  });
  assert.deepEqual(accepted.errors, []);
  const rejected = scan({
    'App.tsx': "import './features/auth/OtherPage';\n",
    'features/auth/OtherPage.tsx': 'export const OtherPage = 1;\n',
  });
  assert.ok(errorKinds(rejected).includes('unapproved-app-screen-import'));
});

test('rejects an unlisted App screen and any screen import from main or layout', () => {
  for (const sourcePath of ['main.tsx', 'layout/AdminLayout.tsx']) {
    const specifier = sourcePath === 'main.tsx'
      ? './features/auth/LoginPage'
      : '../features/auth/LoginPage';
    const result = scan({
      [sourcePath]: `import '${specifier}';\n`,
      'features/auth/LoginPage.tsx': 'export const LoginPage = 1;\n',
    });
    assert.ok(errorKinds(result).includes('feature-screen-import-outside-app'), sourcePath);
  }
});

test('rejects an unapproved production composition root', () => {
  const result = scan({
    'bootstrap.ts': "import './features/auth/api';\n",
    'features/auth/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(result).includes('unknown-admin-zone'));
});

test('accepts exact test/contracts raw-source composition', () => {
  const result = scan({
    'test/contracts/Contract.test.ts': [
      "import auth from '../../features/auth/api.ts?raw';",
      "import users from '../../features/users/api.ts?raw';",
      'void auth; void users;',
    ].join('\n'),
    'features/auth/api.ts': 'export {};\n',
    'features/users/api.ts': 'export {};\n',
  });
  assert.deepEqual(result.errors, []);
});

test('rejects production imports from test/contracts', () => {
  const result = scan({
    'features/auth/api.ts': "import '../../test/contracts/Contract.test';\n",
    'test/contracts/Contract.test.ts': 'export {};\n',
  });
  assert.ok(errorKinds(result).includes('production-imports-test-contract'));
});

test('recognizes import type export-from import-equals require and dynamic import', () => {
  requireBoundaryImplementation();
  const records = boundaries.parseAdminModuleSpecifiers({
    relativePath: 'features/auth/all.ts',
    sourceText: [
      "import type { A } from './a';",
      "export { b } from './b';",
      "import c = require('./c');",
      "const d = require('./d');",
      "const e = import('./e');",
    ].join('\n'),
  });
  assert.deepEqual(records.map(({ kind }) => kind), [
    'import', 'export', 'import-equals', 'require', 'dynamic-import',
  ]);
  assert.equal(records[0].typeOnly, true);
  assert.equal(records.at(-1).dynamic, true);
});

test('rejects computed dynamic import and require specifiers', () => {
  for (const sourceText of [
    "const target = '../auth/api'; import(target);\n",
    "const target = '../auth/api'; require(target);\n",
  ]) {
    const result = scan({
      'features/audit/view.ts': sourceText,
      'features/auth/api.ts': 'export {};\n',
    });
    assert.ok(errorKinds(result).includes('computed-module-specifier'));
  }
});

test('rejects static and computed import.meta module loaders', () => {
  for (const sourceText of [
    "export const modules = import.meta.glob('../auth/*.ts', { eager: true });\n",
    "const pattern = '../auth/*.ts'; export const modules = import.meta['glob'](pattern);\n",
  ]) {
    const result = scan({ 'features/dashboard/DashboardPage.tsx': sourceText });
    assert.ok(errorKinds(result).includes('computed-module-specifier'));
  }
});

test('enforces graph rules for TypeScript import-type queries', () => {
  const records = boundaries.parseAdminModuleSpecifiers({
    relativePath: 'features/audit/view.ts',
    sourceText: "type Hidden = import('../auth/private').Hidden;\n",
  });
  assert.deepEqual(records.map(({ kind, typeOnly }) => [kind, typeOnly]), [['import-type', true]]);
  const result = scan({
    'features/audit/view.ts': "type Hidden = import('../auth/private').Hidden;\n",
    'features/auth/private.ts': 'export interface Hidden {}\n',
  });
  assert.ok(errorKinds(result).includes('deep-cross-feature-import'));
});

test('rejects unresolved relative imports', () => {
  const result = scan({ 'features/auth/api.ts': "import './missing';\n" });
  assert.ok(errorKinds(result).includes('unresolved-relative-import'));
});

test('rejects absolute traversal case symlink and junction escapes', () => {
  const absolute = scan({ 'features/auth/api.ts': "import 'C:/outside';\n" });
  assert.ok(errorKinds(absolute).includes('unsafe-first-party-specifier'));
  const traversal = scan({ 'features/auth/api.ts': "import '../../../outside';\n" });
  assert.ok(errorKinds(traversal).includes('relative-import-escape'));
  const caseMismatch = scan({
    'features/auth/api.ts': "import './value';\n",
    'features/auth/Value.ts': 'export const value = 1;\n',
  });
  assert.ok(errorKinds(caseMismatch).includes('case-mismatched-relative-import'));

  withFixture({ 'features/auth/api.ts': "import './linked/value';\n" }, ({ fixture, srcRoot }) => {
    const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-admin-outside-'));
    try {
      writeFileSync(path.join(outside, 'value.ts'), 'export {};\n', 'utf8');
      symlinkSync(outside, path.join(srcRoot, 'features', 'auth', 'linked'), process.platform === 'win32' ? 'junction' : 'dir');
      const result = boundaries.scanAdminBoundaries({ srcRoot, manifest: testManifest(), stage: 'task-1' });
      assert.ok(errorKinds(result).includes('relative-import-escape'));
      assert.doesNotMatch(JSON.stringify(result), new RegExp(outside.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
    } finally {
      rmSync(outside, { recursive: true, force: true });
      void fixture;
    }
  });
});

test('enforces exact stage legacy-root counts and file identities', () => {
  const manifest = {
    stages: {
      ...testManifest().stages,
      'task-1': { legacyRoots: { api: ['api/admin.ts'], auth: [], components: [], pages: [] } },
    },
  };
  assert.deepEqual(scan({ 'api/admin.ts': 'export {};\n' }, manifest).errors, []);
  const extra = scan({
    'api/admin.ts': 'export {};\n',
    'api/extra.ts': 'export {};\n',
  }, manifest);
  assert.ok(errorKinds(extra).includes('legacy-root-inventory-mismatch'));
  const nested = scan({
    'api/admin.ts': 'export {};\n',
    'api/nested/rogue.ts': 'export {};\n',
  }, manifest);
  assert.ok(errorKinds(nested).includes('legacy-root-inventory-mismatch'));
});

test('rejects wildcard and cross-feature public re-exports', () => {
  const wildcard = scan({
    'features/auth/api.ts': "export * from './private';\n",
    'features/auth/private.ts': 'export const hidden = 1;\n',
  }, { publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, auth: 1 } });
  assert.ok(errorKinds(wildcard).includes('wildcard-public-export'));

  const cross = scan({
    'features/auth/api.ts': "export { user } from '../users/api';\n",
    'features/users/api.ts': 'export const user = 1;\n',
  }, { publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, auth: 1 } });
  assert.ok(errorKinds(cross).includes('cross-feature-public-re-export'));

  const indirect = scan({
    'features/dashboard/api.ts': [
      "import type { AdminUser as AdminStats } from '../auth/api';",
      'export type { AdminStats };',
    ].join('\n'),
    'features/auth/api.ts': 'export interface AdminUser {}\n',
  }, {
    publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, dashboard: 1 },
    publicSurfaces: { ...testManifest().publicSurfaces, dashboard: ['AdminStats'] },
  });
  assert.ok(errorKinds(indirect).includes('cross-feature-public-re-export'));

  const valueImport = scan({
    'features/dashboard/api.ts': [
      "import { AdminUser } from '../auth/api';",
      'export type DashboardRecord = { user: AdminUser };',
    ].join('\n'),
    'features/auth/api.ts': 'export interface AdminUser {}\n',
  }, {
    publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, dashboard: 1 },
    publicSurfaces: { ...testManifest().publicSurfaces, dashboard: ['DashboardRecord'] },
  });
  assert.ok(errorKinds(valueImport).includes('cross-feature-public-re-export'));
});

test('accepts an allowed type-only Auth DTO composition from an owner api', () => {
  const result = scan({
    'features/users/api.ts': [
      "import type { AdminUser } from '../auth/api';",
      'export type AdminUserRecord = AdminUser & { provider?: { id: string } | null };',
    ].join('\n'),
    'features/auth/api.ts': 'export interface AdminUser { id: string }\n',
  }, {
    publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, users: 1 },
    publicSurfaces: { ...testManifest().publicSurfaces, users: ['AdminUserRecord'] },
  });
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.edges, ['users -> auth']);
});

test('rejects root-level and indirect type-only Auth forwarding shapes', () => {
  const cases = [
    {
      name: 'empty intersection',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export type Owner = AdminUser & {};',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'never union',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export type Owner = AdminUser | never;',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'masked export-list alias',
      source: [
        "import type { AdminUser as Base } from '../auth/api';",
        'type Alias = Base;',
        'export type Legal = Base & { provider?: { id: string } | null };',
        'export type { Alias };',
      ].join('\n'),
      symbols: ['Alias', 'Legal'],
    },
    {
      name: 'memberless interface extension',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export interface Owner extends AdminUser {}',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'conditional root forwarding',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export type Owner = AdminUser extends unknown ? { id: string } : never;',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'mapped root forwarding',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export type Owner = { [Key in keyof AdminUser]: AdminUser[Key] };',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'generic parameter shadows imported binding',
      source: [
        "import type { AdminUser } from '../auth/api';",
        'export type Owner<AdminUser> = { user: AdminUser };',
      ].join('\n'),
      symbols: ['Owner'],
    },
    {
      name: 'unused additional imported binding',
      source: [
        "import type { AdminUser, OtpDeliveryStatus } from '../auth/api';",
        'export type Owner = AdminUser & { provider?: { id: string } | null };',
      ].join('\n'),
      symbols: ['Owner'],
    },
  ];
  for (const candidate of cases) {
    const result = scan({
      'features/users/api.ts': candidate.source,
      'features/auth/api.ts': 'export interface AdminUser { id: string }\n',
    }, {
      publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, users: 1 },
      publicSurfaces: { ...testManifest().publicSurfaces, users: candidate.symbols },
    });
    assert.ok(
      errorKinds(result).includes('cross-feature-public-re-export'),
      candidate.name,
    );
  }
});

test('requires the exact Auth public surface from same-feature modules', () => {
  const apiSource = readFileSync(
    new URL('../src/features/auth/api.ts', import.meta.url),
    'utf8',
  );
  const authPublicSurface = [
    'startAdminLogin',
    'completeAdminLogin',
    'requestAdminPasswordReset',
    'confirmAdminPasswordReset',
    'restoreAdminSession',
    'logoutAdmin',
    'AdminUser',
    'OtpDeliveryStatus',
    'AdminLoginChallenge',
    'AdminPasswordResetChallenge',
    'AdminPermission',
    'hasAdminPermission',
    'AuthProvider',
    'useAuth',
    'Can',
    'RequireAdmin',
    'RequireAdminPermission',
  ];
  const result = scan({
    'features/auth/api.ts': apiSource,
    'features/auth/transport.ts': 'export {};\n',
    'features/auth/adminPermissions.ts': 'export {};\n',
    'features/auth/AuthProvider.tsx': 'export {};\n',
    'features/auth/Can.tsx': 'export {};\n',
    'features/auth/RequireAdmin.tsx': 'export {};\n',
    'features/auth/RequireAdminPermission.tsx': 'export {};\n',
  }, {
    publicSurfaceFirstTask: {
      ...testManifest().publicSurfaceFirstTask,
      auth: 1,
    },
    publicSurfaces: {
      ...testManifest().publicSurfaces,
      auth: authPublicSurface,
    },
  });

  assert.deepEqual(result.errors, []);
});

test('rejects default and namespace additions to an exact public surface', () => {
  const exact = {
    publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, auth: 1 },
    publicSurfaces: { ...testManifest().publicSurfaces, auth: [] },
  };
  for (const apiSource of [
    'export default 1;\n',
    "export * as extra from './private';\n",
  ]) {
    const result = scan({
      'features/auth/api.ts': apiSource,
      'features/auth/private.ts': 'export const hidden = 1;\n',
    }, exact);
    assert.ok(errorKinds(result).includes('public-surface-mismatch'));
  }
});

test('counts exported import-equals in an exact public surface', () => {
  const result = scan({
    'features/auth/api.ts': "export import Hidden = require('./private');\n",
    'features/auth/private.ts': 'export = 1;\n',
  }, {
    publicSurfaceFirstTask: { ...testManifest().publicSurfaceFirstTask, auth: 1 },
    publicSurfaces: { ...testManifest().publicSurfaces, auth: [] },
  });
  assert.ok(errorKinds(result).includes('public-surface-mismatch'));
});

test('rejects a junction or symlink used as an exact fate target', () => {
  withFixture({}, ({ srcRoot }) => {
    const outside = mkdtempSync(path.join(os.tmpdir(), 'aarast-admin-fate-outside-'));
    try {
      writeFileSync(path.join(outside, 'api.ts'), 'export {};\n', 'utf8');
      mkdirSync(path.join(srcRoot, 'features'), { recursive: true });
      symlinkSync(outside, path.join(srcRoot, 'features', 'auth'), process.platform === 'win32' ? 'junction' : 'dir');
      const manifest = testManifest({
        sourceFates: [{ source: 'api/admin.ts', target: 'features/auth/api.ts', action: 'move', targetTask: 1 }],
      });
      const result = boundaries.scanAdminBoundaries({ srcRoot, manifest, stage: 'task-1' });
      assert.ok(errorKinds(result).includes('unsafe-source-link'));
      assert.ok(errorKinds(result).includes('target-fate-mismatch'));
      assert.doesNotMatch(JSON.stringify(result), new RegExp(outside.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
    } finally {
      rmSync(outside, { recursive: true, force: true });
    }
  });
});

test('requires strict old-root absence', () => {
  const result = scan({ 'api/admin.ts': 'export {};\n' }, {}, 'strict');
  assert.ok(errorKinds(result).includes('legacy-root-inventory-mismatch'));
  const emptyRoot = withFixture({}, ({ srcRoot }) => {
    mkdirSync(path.join(srcRoot, 'api'), { recursive: true });
    return boundaries.scanAdminBoundaries({ srcRoot, manifest: testManifest(), stage: 'strict' });
  });
  assert.ok(errorKinds(emptyRoot).includes('legacy-root-inventory-mismatch'));
});

test('requires the exact Task 4 owner public surfaces', () => {
  const task4PublicSurfaces = {
    dashboard: ['AdminReport', 'AdminStats', 'getReportOverview', 'getStats'],
    users: [
      'AdminUserRecord',
      'UserProviderSummary',
      'activateUser',
      'disableUser',
      'getUser',
      'getUsers',
    ],
    providers: [
      'CityProjection',
      'ListedProviderInput',
      'ProviderApplication',
      'ProviderCategoryProjection',
      'ProviderPackageProjection',
      'ProviderQueryParams',
      'ProviderReference',
      'ProviderServiceProjection',
      'activateProvider',
      'approveProvider',
      'createListedProvider',
      'getProvider',
      'getProviderApplication',
      'getProviderApplications',
      'getProviders',
      'rejectProvider',
      'requestProviderChanges',
      'setProviderVerified',
      'suspendProvider',
    ],
  };
  const ownerSources = Object.fromEntries(
    Object.keys(task4PublicSurfaces).map((owner) => [
      `features/${owner}/api.ts`,
      readFileSync(new URL(`../src/features/${owner}/api.ts`, import.meta.url), 'utf8'),
    ]),
  );
  const result = scan({
    ...ownerSources,
    'features/auth/api.ts': 'export type AdminUser = { id: string };\n',
    'platform/api/client.ts': 'export const apiRequest = async () => ({});\n',
    'platform/api/query.ts': 'export const toQuery = () => \"\"; export type Paginated<T> = T;\n',
  }, {
    publicSurfaceFirstTask: {
      ...testManifest().publicSurfaceFirstTask,
      dashboard: 1,
      users: 1,
      providers: 1,
    },
    publicSurfaces: { ...testManifest().publicSurfaces, ...task4PublicSurfaces },
  });
  assert.deepEqual(result.errors, []);
});

test('rejects Task 4 Users to Providers and Providers to Catalog edges', () => {
  const usersToProviders = scan({
    'features/users/view.ts': "import '../providers/api';\n",
    'features/providers/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(usersToProviders).includes('undeclared-feature-edge'));

  const providersToCatalog = scan({
    'features/providers/view.ts': "import '../catalog/api';\n",
    'features/catalog/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(providersToCatalog).includes('undeclared-feature-edge'));
});

test('requires the exact Task 5 Catalog public surface and acyclic graph', () => {
  const catalogPublicSurface = [
    'AdministrativeLocality',
    'AdministrativeLocalityType',
    'AdministrativeLocationPayload',
    'CatalogPayload',
    'City',
    'District',
    'Governorate',
    'ProviderCategory',
    'ProviderService',
    'ReferenceCatalog',
    'ReferenceCatalogItem',
    'ReferenceCatalogItemPayload',
    'ReferenceCatalogRevision',
    'ReferenceCatalogSummary',
    'ServicePayload',
    'createCategory',
    'createCity',
    'createDistrict',
    'createGovernorate',
    'createLocality',
    'createReferenceCatalogItem',
    'createService',
    'deleteCategory',
    'deleteCity',
    'deleteService',
    'disableDistrict',
    'disableGovernorate',
    'disableLocality',
    'disableReferenceCatalogItem',
    'getCategories',
    'getCities',
    'getDistricts',
    'getGovernorates',
    'getLocalities',
    'getReferenceCatalog',
    'getReferenceCatalogs',
    'getServices',
    'publishReferenceCatalogItem',
    'updateCategory',
    'updateCity',
    'updateDistrict',
    'updateGovernorate',
    'updateLocality',
    'updateReferenceCatalogItem',
    'updateService',
  ];
  const catalogSource = readFileSync(
    new URL('../src/features/catalog/api.ts', import.meta.url),
    'utf8',
  );
  const result = scan({
    'features/catalog/api.ts': catalogSource,
    'features/auth/api.ts': 'export type AdminUser = { id: string };\n',
    'features/providers/api.ts': 'export type ProviderReference = { id: string };\n',
    'platform/api/client.ts': 'export const apiRequest = async () => ({});\n',
    'platform/api/query.ts': 'export const toQuery = () => ""; export type Paginated<T> = T;\n',
  }, {
    publicSurfaceFirstTask: {
      ...testManifest().publicSurfaceFirstTask,
      catalog: 1,
    },
    publicSurfaces: {
      ...testManifest().publicSurfaces,
      catalog: catalogPublicSurface,
    },
  });
  assert.deepEqual(result.errors, []);

  const allowed = scan({
    'features/catalog/view.ts': [
      "import '../auth/api';",
      "import '../providers/api';",
    ].join('\n'),
    'features/auth/api.ts': 'export {};\n',
    'features/providers/api.ts': 'export {};\n',
  });
  assert.deepEqual(allowed.errors, []);
  assert.deepEqual(allowed.edges, ['catalog -> auth', 'catalog -> providers']);

  const rejected = scan({
    'features/providers/view.ts': "import '../catalog/api';\n",
    'features/catalog/api.ts': 'export {};\n',
  });
  assert.ok(errorKinds(rejected).includes('undeclared-feature-edge'));
});

test('pins Task 5 Catalog loader injection and Provider request ordering', () => {
  const appSource = readFileSync(new URL('../src/App.tsx', import.meta.url), 'utf8');
  const applicationsSource = readFileSync(
    new URL('../src/features/providers/ProviderApplicationsPage.tsx', import.meta.url),
    'utf8',
  );
  const providersSource = readFileSync(
    new URL('../src/features/providers/ProvidersPage.tsx', import.meta.url),
    'utf8',
  );

  assert.match(
    appSource,
    /import\s*\{\s*getCategories,\s*getCities\s*\}\s*from '\.\/features\/catalog\/api';/,
  );
  assert.match(
    appSource,
    /<ProviderApplicationsPage\s+[\s\S]*?getCategories=\{getCategories\}[\s\S]*?getCities=\{getCities\}[\s\S]*?getStats=\{getStats\}[\s\S]*?\/>/,
  );
  assert.match(
    appSource,
    /<ProvidersPage\s+[\s\S]*?getCategories=\{getCategories\}[\s\S]*?getCities=\{getCities\}[\s\S]*?\/>/,
  );

  for (const source of [applicationsSource, providersSource]) {
    assert.doesNotMatch(source, /features\/catalog|\.\.\/catalog\/api/);
    assert.match(source, /getCities:\s*\(\)\s*=>\s*Promise<CityProjection\[\]>/);
    assert.match(
      source,
      /getCategories:\s*\(\)\s*=>\s*Promise<ProviderCategoryProjection\[\]>/,
    );
  }

  const applicationsRequests = applicationsSource.match(
    /Promise\.all\(\[([\s\S]*?)\]\)/,
  )?.[1];
  assert.ok(applicationsRequests);
  assert.ok(applicationsRequests.indexOf('getProviderApplications(') < applicationsRequests.indexOf('getCities()'));
  assert.ok(applicationsRequests.indexOf('getCities()') < applicationsRequests.indexOf('getCategories()'));
  assert.ok(applicationsRequests.indexOf('getCategories()') < applicationsRequests.indexOf('getStats()'));

  const providerRequests = providersSource.match(/Promise\.all\(\[([\s\S]*?)\]\)/)?.[1];
  assert.ok(providerRequests);
  assert.ok(providerRequests.indexOf('getProviders(') < providerRequests.indexOf('getCities()'));
  assert.ok(providerRequests.indexOf('getCities()') < providerRequests.indexOf('getCategories()'));
});

test('requires the exact Task 6 Moderation Notifications and Audit public surfaces', () => {
  const task6PublicSurfaces = {
    moderation: [
      'ConversationReport',
      'ProviderReview',
      'getConversationReports',
      'getReviews',
      'hideReview',
      'updateConversationReportStatus',
      'updateReviewStatus',
    ],
    notifications: [
      'AdminNotification',
      'archiveAdminNotification',
      'deleteAdminNotification',
      'getAdminNotifications',
      'getAdminUnreadNotificationCount',
      'markAdminNotificationRead',
    ],
    audit: ['AdminAuditLog', 'AdminAuditPhase', 'getAdminAuditLogs'],
  };
  const ownerSources = Object.fromEntries(
    Object.keys(task6PublicSurfaces).map((owner) => [
      `features/${owner}/api.ts`,
      readFileSync(new URL(`../src/features/${owner}/api.ts`, import.meta.url), 'utf8'),
    ]),
  );
  const result = scan({
    ...ownerSources,
    'features/auth/api.ts': 'export type AdminUser = { id: string };\n',
    'features/providers/api.ts': 'export type ProviderReference = { id: string };\n',
    'platform/api/client.ts': 'export const apiRequest = async () => ({});\n',
    'platform/api/query.ts': 'export const toQuery = () => ""; export type Paginated<T> = T;\n',
  }, {
    publicSurfaceFirstTask: {
      ...testManifest().publicSurfaceFirstTask,
      moderation: 1,
      notifications: 1,
      audit: 1,
    },
    publicSurfaces: { ...testManifest().publicSurfaces, ...task6PublicSurfaces },
  });
  assert.deepEqual(result.errors, []);
});

test('accepts only the Task 6 Moderation Notifications and Audit feature edges', () => {
  const allowed = scan({
    'features/moderation/view.ts': [
      "import '../auth/api';",
      "import '../providers/api';",
    ].join('\n'),
    'features/notifications/view.ts': "import '../auth/api';\n",
    'features/audit/view.ts': "import '../../platform/api/client';\n",
    'features/auth/api.ts': 'export {};\n',
    'features/providers/api.ts': 'export {};\n',
    'platform/api/client.ts': 'export {};\n',
  });
  assert.deepEqual(allowed.errors, []);
  assert.deepEqual(allowed.edges, [
    'moderation -> auth',
    'moderation -> providers',
    'notifications -> auth',
  ]);

  for (const [sourcePath, targetOwner] of [
    ['features/moderation/view.ts', 'notifications'],
    ['features/notifications/view.ts', 'providers'],
    ['features/audit/view.ts', 'auth'],
  ]) {
    const result = scan({
      [sourcePath]: `import '../${targetOwner}/api';\n`,
      [`features/${targetOwner}/api.ts`]: 'export {};\n',
    });
    assert.ok(errorKinds(result).includes('undeclared-feature-edge'));
  }
});
