import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test, { after, before } from 'node:test';
import { AdminAuditController } from '../src/admin/admin-audit.controller';
import { AdminAuditService } from '../src/admin/admin-audit.service';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import {
  AdminAdministrativeCatalogController,
  AdminReferenceCatalogsController,
  CatalogsController,
  DistrictLocalitiesController,
} from '../src/catalogs/catalogs.controller';
import { AdministrativeCatalogService } from '../src/catalogs/administrative-catalog.service';
import { ReferenceCatalogService } from '../src/catalogs/reference-catalog.service';
import {
  AdminPermission,
  permissionsForAdminRole,
} from '../src/modules/backoffice/domain/admin-permissions';
import { type TestApp, startHttpApp } from './support/http-app';

// RA-TS-28, third part: EVERY route of the admin back office and of the
// catalogs, over HTTP, through the real controller, guards, passport strategy
// and global pipes (support/http-app.ts). The table below is the list of the
// routes; the last test reads the controllers' source and fails when a route
// is in a controller and not in the table (or the reverse), so a new admin
// route cannot ship without its guard row.
//
// For each admin route: no session 401; the couple's session 403; each of
// the four admin roles is let through exactly when `permissionsForAdminRole`
// gives it the permission the route needs, and refused 403 otherwise (the
// four roles together tell a READ from a WRITE swapped by mistake); an
// allowed call reaches the service once, with the acting admin first on a
// write and the id of the path in its arguments.

type Role = 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT';
const ROLES: Role[] = ['SUPER_ADMIN', 'OPERATIONS', 'MODERATOR', 'SUPPORT'];
const UUID = '3f8e2d6a-9b1c-4e57-8a42-5c0d7e91b2f3';
const P = AdminPermission;

type Row = {
  method: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
  /** The route as the controller declares it, `:id` and the like. */
  route: string;
  permission: AdminPermission;
  service: string;
  body?: unknown;
  /** Bodies the pipes must refuse before the service is reached. */
  bad?: unknown[];
};

const long = (n: number) => 'ا'.repeat(n);

const ADMIN_ROUTES: Row[] = [
  // dashboard and reports
  { method: 'GET', route: '/admin/dashboard/stats', permission: P.DASHBOARD_READ, service: 'getDashboardStats' },
  { method: 'GET', route: '/admin/reports/success', permission: P.REPORTS_READ, service: 'getSuccessReport' },
  { method: 'GET', route: '/admin/reports/overview', permission: P.REPORTS_READ, service: 'getReportsOverview' },
  { method: 'GET', route: '/admin/audit-logs', permission: P.AUDIT_READ, service: 'list' },
  // provider applications and reviews
  { method: 'GET', route: '/admin/providers/applications', permission: P.PROVIDERS_READ, service: 'listProviderApplications' },
  { method: 'GET', route: '/admin/providers/applications/:id', permission: P.PROVIDERS_READ, service: 'getProviderApplication' },
  { method: 'PATCH', route: '/admin/providers/:id/approve', permission: P.PROVIDERS_WRITE, service: 'approveProvider' },
  { method: 'PATCH', route: '/admin/providers/:id/reject', permission: P.PROVIDERS_WRITE, service: 'rejectProvider', body: { reason: 'الوثائق ناقصة' }, bad: [{ reason: long(2001) }, { reason: 5 }, { other: 1 }] },
  { method: 'PATCH', route: '/admin/providers/:id/request-changes', permission: P.PROVIDERS_WRITE, service: 'requestProviderChanges', body: { note: 'عدّل الوصف', fieldNotes: [{ field: 'CITY', note: 'المدينة غلط' }] }, bad: [{ note: long(2001) }, { fieldNotes: [{ field: 'COLOUR', note: 'x' }] }, { fieldNotes: [{ field: 'CITY', note: '' }] }, { fieldNotes: 'CITY' }] },
  { method: 'GET', route: '/admin/providers/:id/review-history', permission: P.PROVIDERS_READ, service: 'getProviderReviewHistory' },
  { method: 'GET', route: '/admin/provider-claims', permission: P.PROVIDERS_READ, service: 'listClaimRequests' },
  { method: 'POST', route: '/admin/provider-claims/:id/approve', permission: P.PROVIDERS_WRITE, service: 'approveClaimRequest' },
  { method: 'POST', route: '/admin/provider-claims/:id/reject', permission: P.PROVIDERS_WRITE, service: 'rejectClaimRequest', body: { note: 'الملكية غير مثبتة' }, bad: [{ note: long(1001) }, { note: 5 }] },
  // featured placement
  { method: 'GET', route: '/admin/featured-periods', permission: P.PROVIDERS_READ, service: 'listFeaturedPeriods' },
  { method: 'GET', route: '/admin/featured-periods/summary', permission: P.PROVIDERS_READ, service: 'getFeaturedSummary' },
  { method: 'POST', route: '/admin/providers/:id/featured-periods', permission: P.PROVIDERS_WRITE, service: 'grantFeaturedPeriod', body: { endsOn: '2030-01-31', startsOn: '2030-01-01' }, bad: [{}, { endsOn: '31/01/2030' }, { endsOn: '2030-01-31T00:00:00Z' }, { endsOn: '2030-01-31', startsOn: 'soon' }, { endsOn: '2030-01-31', note: long(501) }] },
  { method: 'POST', route: '/admin/featured-periods/:id/end', permission: P.PROVIDERS_WRITE, service: 'endFeaturedPeriod', body: { note: 'طلب المزود' }, bad: [{ note: long(501) }, { note: 3 }] },
  // provider state
  { method: 'PATCH', route: '/admin/providers/:id/suspend', permission: P.PROVIDERS_WRITE, service: 'suspendProvider', body: { reason: 'شكاوى' }, bad: [{ reason: long(2001) }] },
  { method: 'PATCH', route: '/admin/providers/:id/activate', permission: P.PROVIDERS_WRITE, service: 'activateProvider' },
  { method: 'PATCH', route: '/admin/providers/:id/verify', permission: P.PROVIDERS_WRITE, service: 'setProviderVerified' },
  { method: 'PATCH', route: '/admin/providers/:id/unverify', permission: P.PROVIDERS_WRITE, service: 'setProviderVerified' },
  { method: 'POST', route: '/admin/providers', permission: P.PROVIDERS_WRITE, service: 'createListedProvider', body: { businessName: 'قاعة الريان', phone: '777123456', cityId: 'city-1', categoryId: 'cat-1' }, bad: [{}, { businessName: long(161), phone: '777123456', cityId: 'c', categoryId: 'k' }, { businessName: 'x', phone: '7'.repeat(33), cityId: 'c', categoryId: 'k' }, { businessName: 'x', phone: '777', cityId: 'c' }, { businessName: 'x', phone: '777', cityId: 'c', categoryId: 'k', description: long(4001) }, { businessName: 'x', phone: '777', cityId: 'c', categoryId: 'k', address: long(301) }] },
  { method: 'GET', route: '/admin/providers', permission: P.PROVIDERS_READ, service: 'listProviders' },
  { method: 'GET', route: '/admin/providers/:id', permission: P.PROVIDERS_READ, service: 'getProvider' },
  // services
  { method: 'GET', route: '/admin/services', permission: P.SERVICES_READ, service: 'listServices' },
  { method: 'POST', route: '/admin/services', permission: P.SERVICES_WRITE, service: 'createService', body: { providerId: 'p-1', categoryId: 'c-1', title: 'تصوير الزفة', currency: 'YER' }, bad: [{ title: long(161) }, { description: long(2001) }, { priceUnit: long(121) }, { currency: 'YEMENI-RIAL' }, { isActive: 'yes' }, { colour: 'red' }] },
  { method: 'PATCH', route: '/admin/services/:id', permission: P.SERVICES_WRITE, service: 'updateService', body: { title: 'تصوير الزفة' }, bad: [{ title: long(161) }, { isActive: 1 }] },
  { method: 'DELETE', route: '/admin/services/:id', permission: P.SERVICES_WRITE, service: 'deleteService' },
  // reviews and portfolio
  { method: 'GET', route: '/admin/reviews', permission: P.REVIEWS_READ, service: 'listReviews' },
  { method: 'PATCH', route: '/admin/reviews/:id/status', permission: P.REVIEWS_WRITE, service: 'updateReviewStatus', body: { status: 'HIDDEN' }, bad: [{}, { status: 7 }] },
  { method: 'PATCH', route: '/admin/reviews/:id/reply-status', permission: P.REVIEWS_WRITE, service: 'updateReviewReplyStatus', body: { status: 'HIDDEN' }, bad: [{}, { status: ['HIDDEN'] }] },
  { method: 'DELETE', route: '/admin/reviews/:id', permission: P.REVIEWS_WRITE, service: 'hideReview' },
  { method: 'GET', route: '/admin/portfolio-items', permission: P.PROVIDERS_READ, service: 'listPortfolioItems' },
  { method: 'PATCH', route: '/admin/portfolio-items/:id/decision', permission: P.REVIEWS_WRITE, service: 'decidePortfolioItem', body: { decision: 'APPROVE' }, bad: [{}, { decision: 'MAYBE' }, { decision: 'REJECT', reason: long(401) }] },
  // provider profile changes and bookings
  { method: 'GET', route: '/admin/provider-profile-changes', permission: P.PROVIDERS_READ, service: 'listProfileChanges' },
  { method: 'PATCH', route: '/admin/provider-profile-changes/:id/decision', permission: P.PROVIDERS_WRITE, service: 'decideProfileChange', body: { decision: 'APPROVE' }, bad: [{}, { decision: 'MAYBE' }, { decision: 'REJECT', reason: long(401) }] },
  { method: 'GET', route: '/admin/bookings', permission: P.PROVIDERS_READ, service: 'listBookings' },
  { method: 'GET', route: '/admin/bookings/:id', permission: P.PROVIDERS_READ, service: 'getBooking' },
  // reports inbox
  { method: 'GET', route: '/admin/conversation-reports', permission: P.CONVERSATION_REPORTS_READ, service: 'listConversationReports' },
  { method: 'PATCH', route: '/admin/conversation-reports/:id/status', permission: P.CONVERSATION_REPORTS_WRITE, service: 'updateConversationReportStatus', body: { status: 'REVIEWED', note: 'تمت المراجعة' }, bad: [{}, { status: 'REVIEWED', note: 5 }] },
  { method: 'GET', route: '/admin/assistant-reports', permission: P.CONVERSATION_REPORTS_READ, service: 'listAssistantAnswerReports' },
  { method: 'PATCH', route: '/admin/assistant-reports/:id/resolve', permission: P.CONVERSATION_REPORTS_WRITE, service: 'resolveAssistantAnswerReport' },
  // categories and cities
  { method: 'GET', route: '/admin/provider-categories', permission: P.CATALOG_READ, service: 'listCategories' },
  { method: 'POST', route: '/admin/provider-categories', permission: P.CATALOG_WRITE, service: 'createCategory', body: { nameAr: 'تصوير' }, bad: [{}, { nameAr: long(161) }, { nameAr: 'x', sortOrder: 1.5 }] },
  { method: 'PATCH', route: '/admin/provider-categories/:id', permission: P.CATALOG_WRITE, service: 'updateCategory', body: { nameAr: 'تصوير' }, bad: [{}, { nameAr: 'x', isActive: 'yes' }] },
  { method: 'DELETE', route: '/admin/provider-categories/:id', permission: P.CATALOG_WRITE, service: 'deleteCategory' },
  { method: 'GET', route: '/admin/cities', permission: P.CATALOG_READ, service: 'listCities' },
  { method: 'POST', route: '/admin/cities', permission: P.CATALOG_WRITE, service: 'createCity', body: { nameAr: 'عدن' }, bad: [{}, { nameAr: long(161) }, { nameAr: 'x', countryCode: 'YEMEN-XXX' }] },
  { method: 'PATCH', route: '/admin/cities/:id', permission: P.CATALOG_WRITE, service: 'updateCity', body: { nameAr: 'صنعاء' }, bad: [{}, { nameAr: 'x', sortOrder: -1_000_001 }] },
  { method: 'DELETE', route: '/admin/cities/:id', permission: P.CATALOG_WRITE, service: 'deleteCity' },
  // users and data requests
  { method: 'GET', route: '/admin/users', permission: P.USERS_READ, service: 'listUsers' },
  { method: 'PATCH', route: '/admin/users/:id/activate', permission: P.USERS_WRITE, service: 'activateUser' },
  { method: 'PATCH', route: '/admin/users/:id/disable', permission: P.USERS_WRITE, service: 'disableUser', body: { reason: 'إساءة استخدام' }, bad: [{}, { reason: '' }, { reason: long(501) }, { reason: 5 }] },
  { method: 'GET', route: '/admin/users/:id', permission: P.USERS_READ, service: 'getUser' },
  { method: 'GET', route: '/admin/data-requests', permission: P.USERS_READ, service: 'listDataRequests' },
  { method: 'POST', route: '/admin/data-requests/:id/restore', permission: P.USERS_WRITE, service: 'restoreAccountDeletion' },
  // reference catalogs
  { method: 'GET', route: '/admin/reference-catalogs', permission: P.CATALOG_READ, service: 'listAdminCatalogs' },
  { method: 'GET', route: '/admin/reference-catalogs/:catalogKey', permission: P.CATALOG_READ, service: 'getAdminCatalog' },
  { method: 'POST', route: '/admin/reference-catalogs/:catalogKey/items', permission: P.CATALOG_WRITE, service: 'createItem', body: { nameAr: 'قاعة', sortOrder: 3, metadata: { providerCategorySlugs: ['halls'] } }, bad: [{ nameAr: long(161) }, { key: 'k'.repeat(121) }, { sortOrder: 2_000_000 }, { showForGroom: 'yes' }, { metadata: 'text' }, { isActive: 1 }, { surprise: true }] },
  { method: 'PATCH', route: '/admin/reference-catalogs/:catalogKey/items/:id', permission: P.CATALOG_WRITE, service: 'updateItem', body: { nameAr: 'قاعة كبيرة' }, bad: [{ icon: 'i'.repeat(81) }, { groupSubtitleAr: long(241) }] },
  { method: 'POST', route: '/admin/reference-catalogs/:catalogKey/items/:id/publish', permission: P.CATALOG_WRITE, service: 'publishItem', body: { revision: 4 }, bad: [{ revision: 0 }, { revision: 1.5 }, { revision: 1_000_001 }, { revision: '4' }] },
  { method: 'DELETE', route: '/admin/reference-catalogs/:catalogKey/items/:id', permission: P.CATALOG_WRITE, service: 'disableItem' },
  // governorates, districts, localities
  { method: 'GET', route: '/admin/governorates', permission: P.CATALOG_READ, service: 'listGovernorates' },
  { method: 'POST', route: '/admin/governorates', permission: P.CATALOG_WRITE, service: 'createGovernorate', body: { code: 'YE-SA', nameAr: 'صنعاء', latitude: 15.35, longitude: 44.2 }, bad: [{ code: 'c'.repeat(41) }, { nameAr: long(161) }, { latitude: 91 }, { longitude: -181 }, { latitude: '15' }, { sortOrder: 0.5 }] },
  { method: 'PATCH', route: '/admin/governorates/:id', permission: P.CATALOG_WRITE, service: 'updateGovernorate', body: { nameAr: 'عدن' }, bad: [{ isActive: 'no' }, { latitude: -91 }] },
  { method: 'DELETE', route: '/admin/governorates/:id', permission: P.CATALOG_WRITE, service: 'disableGovernorate' },
  { method: 'GET', route: '/admin/governorates/:id/districts', permission: P.CATALOG_READ, service: 'listDistricts' },
  { method: 'POST', route: '/admin/governorates/:id/districts', permission: P.CATALOG_WRITE, service: 'createDistrict', body: { nameAr: 'السبعين' }, bad: [{ nameAr: long(161) }, { governorateId: 5 }, { longitude: 200 }] },
  { method: 'PATCH', route: '/admin/districts/:id', permission: P.CATALOG_WRITE, service: 'updateDistrict', body: { nameAr: 'الوحدة' }, bad: [{ nameAr: long(161) }, { sortOrder: -2_000_000 }] },
  { method: 'DELETE', route: '/admin/districts/:id', permission: P.CATALOG_WRITE, service: 'disableDistrict' },
  { method: 'GET', route: '/admin/districts/:id/localities', permission: P.CATALOG_READ, service: 'listLocalities' },
  { method: 'POST', route: '/admin/districts/:id/localities', permission: P.CATALOG_WRITE, service: 'createLocality', body: { nameAr: 'حدة', type: 'NEIGHBORHOOD' }, bad: [{ type: 'PLANET' }, { nameAr: long(161) }, { districtId: 5 }, { parentId: 5 }] },
  { method: 'PATCH', route: '/admin/localities/:id', permission: P.CATALOG_WRITE, service: 'updateLocality', body: { nameAr: 'الجراف' }, bad: [{ type: 'PLANET' }, { latitude: 100 }] },
  { method: 'DELETE', route: '/admin/localities/:id', permission: P.CATALOG_WRITE, service: 'disableLocality' },
];

// Routes with no session at all (public catalogs), listed so the completeness
// test counts them; their own checks are in the tests further down.
const PUBLIC_ROUTES = [
  'GET /api/v1/catalogs/bootstrap',
  'GET /api/v1/districts/:id/localities',
];

type Call = { method: string; args: unknown[] };
const calls: Call[] = [];
const called = (method: string) => calls.filter((call) => call.method === method);
const reset = () => {
  calls.length = 0;
};

function recorderFor(type: { prototype: object }) {
  return Object.fromEntries(
    Object.getOwnPropertyNames(type.prototype)
      .filter((name) => name !== 'constructor')
      .map((name) => [
        name,
        async (...args: unknown[]) => {
          calls.push({ method: name, args });
          return { ok: true };
        },
      ]),
  );
}

let app: TestApp;

before(async () => {
  app = await startHttpApp(
    [
      AdminController,
      AdminAuditController,
      CatalogsController,
      DistrictLocalitiesController,
      AdminReferenceCatalogsController,
      AdminAdministrativeCatalogController,
    ],
    [
      { provide: AdminService, useValue: recorderFor(AdminService) },
      { provide: AdminAuditService, useValue: recorderFor(AdminAuditService) },
      { provide: ReferenceCatalogService, useValue: recorderFor(ReferenceCatalogService) },
      { provide: AdministrativeCatalogService, useValue: recorderFor(AdministrativeCatalogService) },
    ],
  );
});

after(async () => {
  await app.close();
});

const adminAs = (role: Role) => app.tokenFor({ id: `admin-${role}`, adminRole: role }, 'admin');
const concrete = (route: string) =>
  route.replace(':catalogKey', 'money-items').replace(/:id/g, UUID);

for (const row of ADMIN_ROUTES) {
  test(`${row.method} ${row.route}: ${row.permission}, and nobody without it`, async () => {
    reset();
    const path = concrete(row.route);
    const send = (token?: string, body: unknown = row.body) =>
      app.request(row.method, path, { token, body });

    assert.equal((await send()).status, 401, 'no session');
    assert.equal((await send(app.tokenFor({ id: 'user-1' }))).status, 403, 'the couple\'s session');
    assert.equal(called(row.service).length, 0, 'refusals never reach the service');

    let reached = 0;
    for (const role of ROLES) {
      const holds = permissionsForAdminRole(role).includes(row.permission);
      const response = await send(adminAs(role));
      if (!holds) {
        assert.equal(response.status, 403, `${role} lacks ${row.permission}`);
        assert.equal(called(row.service).length, reached, `${role} refused before the service`);
        continue;
      }
      assert.ok(response.status >= 200 && response.status < 300, `${role} holds ${row.permission}: ${response.status}`);
      reached += 1;
      assert.equal(called(row.service).length, reached, `${role} reached ${row.service}`);
      const args = called(row.service)[reached - 1].args;
      if (row.method !== 'GET') {
        assert.equal((args[0] as { id: string }).id, `admin-${role}`, 'the acting admin');
      }
      if (row.route.includes(':id')) {
        assert.ok(args.includes(UUID), 'the id of the path reaches the service');
      }
    }
    assert.ok(reached > 0, 'some role holds the permission');

    // The checks of the body come after the guards, and before the service.
    const writer = ROLES.find((role) => permissionsForAdminRole(role).includes(row.permission))!;
    const before = called(row.service).length;
    for (const bad of row.bad ?? []) {
      assert.equal(
        (await send(adminAs(writer), bad)).status,
        400,
        `${JSON.stringify(bad).slice(0, 60)}`,
      );
    }
    assert.equal(called(row.service).length, before, 'a refused body never reaches the service');
  });
}

test('the verify and unverify routes say which way they set it', async () => {
  reset();
  const ops = adminAs('OPERATIONS');
  await app.request('PATCH', `/admin/providers/${UUID}/verify`, { token: ops });
  await app.request('PATCH', `/admin/providers/${UUID}/unverify`, { token: ops });
  assert.deepEqual(called('setProviderVerified').map((call) => call.args[2]), [true, false]);
});

test('the audit log reads only a page, a limit, a day and a phase it knows', async () => {
  reset();
  const root = adminAs('SUPER_ADMIN');
  for (const bad of ['page=abc', 'limit=-1', 'from=yesterday', 'to=12/12/2030', 'phase=SOMETIME', `action=${'a'.repeat(161)}`, 'unknown=1']) {
    assert.equal((await app.request('GET', `/admin/audit-logs?${bad}`, { token: root })).status, 400, bad);
  }
  assert.equal(called('list').length, 0);
  const ok = await app.request('GET', '/admin/audit-logs?page=2&limit=50&from=2030-01-01&to=2030-01-31&action=provider.suspend', { token: root });
  assert.equal(ok.status, 200);
  assert.equal((called('list')[0].args[0] as { page: string }).page, '2');
});

test('admin: a catalog item publishes the revision the page was reading', async () => {
  reset();
  const ops = adminAs('OPERATIONS');
  await app.request('POST', `/admin/reference-catalogs/money-items/items/${UUID}/publish`, { token: ops, body: { revision: 4 } });
  assert.deepEqual(called('publishItem')[0].args.slice(1), ['money-items', UUID, 4]);
  await app.request('POST', `/admin/reference-catalogs/money-items/items/${UUID}/publish`, { token: ops, body: {} });
  assert.equal(called('publishItem')[1].args[3], undefined);
});

// ---------------------------------------------------------------- public catalogs

test('the catalog bootstrap is public and takes only a version of 128 characters at most', async () => {
  reset();
  assert.equal((await app.request('GET', '/api/v1/catalogs/bootstrap')).status, 200);
  assert.equal((await app.request('GET', '/api/v1/catalogs/bootstrap?version=v7')).status, 200);
  assert.deepEqual(called('getBootstrap').map((call) => call.args), [[undefined], ['v7']]);
  assert.equal((await app.request('GET', `/api/v1/catalogs/bootstrap?version=${'v'.repeat(129)}`)).status, 400);
  assert.equal((await app.request('GET', '/api/v1/catalogs/bootstrap?other=1')).status, 400);
  assert.equal(called('getBootstrap').length, 2);
});

test('a district\'s localities are public, for the district in the path', async () => {
  reset();
  assert.equal((await app.request('GET', `/api/v1/districts/${UUID}/localities`)).status, 200);
  assert.deepEqual(called('listPublicLocalities').map((call) => call.args), [[UUID]]);
});

// ---------------------------------------------------------------- the list

test('every route of the admin and catalogs controllers is in the table above', () => {
  const files = [
    'src/admin/admin.controller.ts',
    'src/admin/admin-audit.controller.ts',
    'src/catalogs/catalogs.controller.ts',
  ];
  const found = new Set<string>();
  for (const file of files) {
    let prefix = '';
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      const controller = line.match(/^@Controller\('([^']*)'\)/);
      if (controller) prefix = controller[1];
      const route = line.match(/^\s*@(Get|Post|Put|Patch|Delete)\((?:'([^']*)')?\)/);
      if (route) {
        const path = `/${prefix}/${route[2] ?? ''}`.replace(/\/+/g, '/').replace(/\/$/, '');
        found.add(`${route[1].toUpperCase()} ${path.replace(/:\w+/g, ':p')}`);
      }
    }
  }
  const listed = new Set(
    [
      ...ADMIN_ROUTES.map((row) => `${row.method} ${row.route}`),
      ...PUBLIC_ROUTES,
    ].map((entry) => entry.replace(/:\w+/g, ':p')),
  );
  assert.deepEqual([...found].filter((entry) => !listed.has(entry)), [], 'routes with no row');
  assert.deepEqual([...listed].filter((entry) => !found.has(entry)), [], 'rows with no route');
  assert.equal(listed.size, ADMIN_ROUTES.length + PUBLIC_ROUTES.length, 'no row twice');
  assert.ok(found.size >= 75, `the scan found the routes (${found.size})`);
});
