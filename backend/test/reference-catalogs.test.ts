import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { readLivePrismaSchema } from './support/live-prisma-schema';
import {
  MONEY_STARTER_CATALOG_KEY,
  moneyStarterDefaults,
  supportedCatalogIconKeys,
  systemCatalogs,
  TASK_STARTER_CATALOG_KEY,
  taskStarterDefaults,
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

// RA-MO-325 (Q-35, D124): the home and the honeymoon are the groom's to
// settle in a Yemeni wedding; the bride's list offers them but does not tick
// them for her. Her other recommended items are unchanged.
test("the bride's list offers the home and the honeymoon without recommending them", () => {
  const byKey = new Map(moneyStarterDefaults.map((item) => [item.key, item]));
  for (const key of ['bride-home', 'bride-honeymoon']) {
    const item = byKey.get(key);
    assert.ok(item, key);
    assert.equal(item.showForBride, true, key);
    assert.equal(item.isRecommended, false, key);
  }
  for (const key of ['groom-home', 'groom-honeymoon', 'bride-trousseau', 'bride-dress']) {
    assert.equal(byKey.get(key)?.isRecommended, true, key);
  }
});

test('task templates cover every role with a due offset before the wedding', () => {
  assert.deepEqual(
    systemCatalogs.map((catalog) => catalog.key),
    [MONEY_STARTER_CATALOG_KEY, TASK_STARTER_CATALOG_KEY],
  );
  const allKeys = systemCatalogs.flatMap((catalog) => catalog.items.map((item) => item.key));
  assert.equal(new Set(allKeys).size, allKeys.length, 'item keys are unique across catalogs');

  const personas = new Set(taskStarterDefaults.map((item) => item.metadata?.persona));
  assert.deepEqual([...personas].sort(), ['BRIDE', 'FAMILY', 'GROOM', 'SHARED']);
  for (const item of taskStarterDefaults) {
    const daysBefore = Number(item.metadata?.daysBefore);
    assert.ok(Number.isInteger(daysBefore) && daysBefore >= 0, item.key);
    assert.ok(supportedCatalogIconKeys.has(item.icon), item.key);
    const persona = item.metadata?.persona;
    assert.equal(item.showForGroom, persona !== 'BRIDE', item.key);
    // One shared task is the groom's alone: the bride has her own photographer.
    const brideHasHerOwn = item.key === 'task-shared-photo';
    assert.equal(item.showForBride, persona !== 'GROOM' && !brideHasHerOwn, item.key);
  }
  // The Yemeni essentials the client listed are offered as tasks.
  for (const word of ['المهر', 'الشرط', 'الشبكة', 'الكسوة', 'القات', 'الفنان', 'الزفة', 'مخدرة', 'النقش', 'الشقة', 'شهر العسل']) {
    assert.ok(
      taskStarterDefaults.some((item) => item.nameAr.includes(word)),
      word,
    );
  }
});

// RA-MO-325: the bride's own tasks hold her women's photographer, her kosha
// and her hospitality, appended so the sort orders before them stay.
test("the bride's tasks hold her photographer, her kosha and her hospitality", () => {
  const bride = taskStarterDefaults.filter((item) => item.groupKey === 'bride-tasks');
  const byKey = new Map(bride.map((item) => [item.key, item]));
  for (const [key, name, daysBefore] of [
    ['task-bride-photographer', 'حجز المصورة النسائية', '120'],
    ['task-bride-kosha', 'الاتفاق على الكوشة وديكور الصالة', '90'],
    ['task-bride-hospitality', 'الاتفاق على الضيافة والحلويات', '60'],
  ] as const) {
    const item = byKey.get(key);
    assert.equal(item?.nameAr, name, key);
    assert.equal(item?.metadata?.daysBefore, daysBefore, key);
    assert.equal(item?.isRecommended, true, key);
    assert.equal(item?.showForGroom, false, key);
  }
  // Appended: the eight before keep their place.
  assert.deepEqual(
    bride.slice(0, 8).map((item) => item.key),
    [
      'task-bride-hall', 'task-bride-dress', 'task-bride-coiffeur', 'task-bride-singer',
      'task-bride-naqsh', 'task-bride-subhia', 'task-bride-gold', 'task-bride-trousseau',
    ],
  );
});

test("a bride's plan is not offered the shared photographer beside her own", () => {
  // «حجز المصور» beside «حجز المصورة النسائية» was the same task twice.
  const shared = taskStarterDefaults.find((item) => item.key === 'task-shared-photo');
  assert.equal(shared?.showForGroom, true);
  assert.equal(shared?.showForBride, false);
  const sharedDate = taskStarterDefaults.find((item) => item.key === 'task-shared-date');
  assert.equal(sharedDate?.showForBride, true, 'the other shared tasks stay hers too');
  assert.equal(shared?.groupSubtitleAr, 'الأساسيات اللي يتفقون عليها.');
});

// A live database keeps the catalog rows it was seeded with (the seed's
// upsert updates nothing), so the default above reached new databases only.
// The data migration publishes the same change there, as an admin would: a
// new revision of every shared task still on the system's first revision,
// published, and the catalog's version raised so phones read it again. An
// item an admin edited (a revision past the first, or a draft) is left; a
// fresh database has no rows, and it does nothing.
test('the shared tasks change reaches a live catalog through a published revision', () => {
  const sql = read(
    'prisma/migrations/20261126120200_task_starter_shared_group_bride/migration.sql',
  ).replace(/\r\n/g, '\n');
  const shared = taskStarterDefaults.filter((item) => item.groupKey === 'shared-tasks');
  assert.ok(shared.length > 0);
  assert.match(sql, new RegExp(`"catalog"\\."key" = '${TASK_STARTER_CATALOG_KEY.replace('.', '\\.')}'`));
  for (const item of shared) assert.ok(sql.includes(`'${item.key}'`), item.key);
  // Untouched by an admin: on the first revision, published, with the old words.
  assert.match(sql, /"item"\."currentRevision" = 1/);
  assert.match(sql, /"item"\."publishedRevision" = 1/);
  assert.ok(sql.includes("'الأساسيات التي يتفق عليها الطرفان.'"));
  // The new revision says what the defaults say.
  assert.ok(sql.includes(`'${shared[0].groupSubtitleAr}'`));
  const notForBride = shared.filter((item) => !item.showForBride).map((item) => item.key);
  assert.deepEqual(notForBride, ['task-shared-photo']);
  assert.match(
    sql,
    /CASE WHEN "item"\."key" = 'task-shared-photo' THEN false ELSE "revision"\."showForBride" END/,
  );
  assert.match(sql, /"revision"\."revision" = 1/);
  assert.match(sql, /2, /);
  assert.match(sql, /SET "currentRevision" = 2, "publishedRevision" = 2/);
  assert.match(sql, /SET "version" = "version" \+ 1/);
  // Raised only when something was published (a fresh database: nothing).
  assert.match(sql, /AND EXISTS \(SELECT 1 FROM "published"\)/);
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
