import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { readLivePrismaSchema } from './support/live-prisma-schema';
import {
  moneyStarterDefaults,
  supportedCatalogIconKeys,
} from '../src/catalogs/reference-catalog.defaults';

const root = join(__dirname, '..');
const read = (path: string) => readFileSync(join(root, path), 'utf8');

test('money starter reference defaults are stable and audience-scoped', () => {
  assert.ok(moneyStarterDefaults.length >= 40);
  assert.equal(
    new Set(moneyStarterDefaults.map((item) => item.key)).size,
    moneyStarterDefaults.length,
  );
  assert.ok(moneyStarterDefaults.every((item) => item.nameAr.trim().length > 0));
  assert.ok(
    moneyStarterDefaults.every((item) =>
      supportedCatalogIconKeys.has(item.icon),
    ),
  );
  assert.ok(
    moneyStarterDefaults.some(
      (item) => item.showForGroom && !item.showForBride,
    ),
  );
  assert.ok(
    moneyStarterDefaults.some(
      (item) => item.showForBride && !item.showForGroom,
    ),
  );
  assert.ok(
    moneyStarterDefaults.some(
      (item) => !item.showForBride && !item.showForGroom,
    ),
  );
});

test('catalog publication separates drafts from the public bootstrap', () => {
  const schema = readLivePrismaSchema();
  const service = read('src/catalogs/reference-catalog.service.ts');
  const repository = read('src/modules/catalog/infrastructure/reference-catalog.repository.ts');

  assert.match(schema, /currentRevision\s+Int/);
  assert.match(schema, /publishedRevision\s+Int/);
  assert.match(schema, /@@unique\(\[itemId, revision\]\)/);
  assert.match(service, /this\.repository\.bootstrapRows\(this\.prisma\)/);
  assert.match(repository, /publishedRevision: \{ gt: 0 \}/);
  assert.match(
    service,
    /candidate\.revision === item\.publishedRevision/,
  );
  assert.match(service, /if \(!revision\?\.isActive\) return \[\]/);
  assert.match(service, /knownVersion\?\.trim\(\) === version/);
});

test('catalog and geography admin writes are permission gated and soft-disable', () => {
  const controller = read('src/catalogs/catalogs.controller.ts');
  const referenceService = read('src/catalogs/reference-catalog.service.ts');
  const geographyService = read(
    'src/catalogs/administrative-catalog.service.ts',
  );
  const referenceRepository = read('src/modules/catalog/infrastructure/reference-catalog.repository.ts');
  const geographyRepository = read('src/modules/catalog/infrastructure/administrative-catalog.repository.ts');

  assert.match(controller, /JwtSessionGuard, AdminGuard, AdminPermissionGuard/);
  assert.ok(
    (controller.match(/AdminPermission\.CATALOG_WRITE/g) ?? []).length >= 10,
  );
  assert.match(referenceService, /runAuthorizedAdminMutation/);
  assert.match(geographyService, /runAuthorizedAdminMutation/);
  assert.match(referenceService, /this\.repository\.createItem\(\s*tx,/);
  assert.match(referenceRepository, /tx\.referenceCatalogItem\.create\(/);
  assert.match(geographyService, /this\.repository\.disableGovernorate\(tx, id\)/);
  assert.match(geographyRepository, /tx\.governorate\.update\(\{ where: \{ id \}, data: \{ isActive: false \} \}\)/);
  assert.doesNotMatch(referenceService, /referenceCatalogItem\.delete/);
  assert.doesNotMatch(referenceRepository, /referenceCatalogItem\.delete/);
  assert.doesNotMatch(geographyService, /governorate\.delete/);
  assert.doesNotMatch(geographyService, /district\.delete/);
  assert.doesNotMatch(geographyService, /administrativeLocality\.delete/);
  assert.doesNotMatch(geographyRepository, /governorate\.delete|district\.delete|administrativeLocality\.delete/);
  assert.match(geographyService, /Locality hierarchy contains a cycle/);
});

test('public routes expose a versioned bootstrap and ordered localities', () => {
  const controller = read('src/catalogs/catalogs.controller.ts');
  const service = read('src/catalogs/administrative-catalog.service.ts');
  const repository = read('src/modules/catalog/infrastructure/administrative-catalog.repository.ts');

  assert.match(controller, /@Controller\('api\/v1\/catalogs'\)/);
  assert.match(controller, /@Get\('bootstrap'\)/);
  assert.match(controller, /@Controller\('api\/v1\/districts'\)/);
  assert.match(controller, /@Get\(':id\/localities'\)/);
  assert.match(service, /this\.repository\.findActiveDistrictWithGovernorate\(/);
  assert.match(service, /this\.repository\.listActiveLocalities\(this\.prisma, districtId\)/);
  assert.match(repository, /governorate: \{ isActive: true \}/);
  assert.match(repository, /where: \{ districtId, isActive: true \}/);
});
