import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import type { Prisma } from '@prisma/client';
import {
  CATALOG_READ_IMPLEMENTATION,
  CatalogReadInternalModule,
} from '../src/modules/catalog/internal/catalog-read.internal.module';
import { CatalogReadService } from '../src/modules/catalog/internal/catalog-read.service';
import { CatalogReadPublicModule } from '../src/modules/catalog/public/catalog-read-public.module';
import { CATALOG_READ_PORT } from '../src/modules/catalog/public/catalog-read.port';

// Marketplace, provider-dashboard and backoffice used to include catalog's
// city, category, governorate and district rows in their own queries. Catalog
// serves them through this port on the caller's client; the statements are
// the ones the consumers ran, moved to their owner.

const order = [{ sortOrder: 'asc' }, { nameAr: 'asc' }];

function client() {
  const calls: Array<[string, unknown]> = [];
  const record = (name: string, result: unknown) => async (args: unknown) => { calls.push([name, args]); return result; };
  const tx = {
    city: {
      findMany: record('city.findMany', [{ id: 'city-1' }]),
      findFirst: record('city.findFirst', { id: 'city-1' }),
    },
    providerCategory: {
      findMany: record('category.findMany', [{ id: 'category-1' }]),
      findFirst: record('category.findFirst', { id: 'category-1' }),
      count: record('category.count', 2),
    },
    governorate: {
      findMany: record('governorate.findMany', [{ id: 'gov-1', _count: { districts: 3 } }]),
      findFirst: record('governorate.findFirst', { id: 'gov-1' }),
    },
    district: { findMany: record('district.findMany', [{ id: 'district-1' }]) },
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => {
      calls.push(['$queryRaw', { sql: query.strings.join('?').replace(/\s+/g, ' ').trim(), values: query.values }]);
      return query.values[0] === 'city-1' ? [{ id: 'city-1' }] : [{ id: 'category-1' }, { id: 'category-2' }];
    },
  } as unknown as Prisma.TransactionClient;
  return { tx, calls };
}

test('the catalog read port lists the active catalogs in their display order', async () => {
  const { tx, calls } = client();
  const service = new CatalogReadService();

  assert.deepEqual(await service.listActiveCities(tx), [{ id: 'city-1' }]);
  assert.deepEqual(await service.listActiveCategories(tx), [{ id: 'category-1' }]);
  assert.deepEqual(await service.listActiveGovernorates(tx), [{ id: 'gov-1', _count: { districts: 3 } }]);
  assert.deepEqual(await service.findActiveGovernorate(tx, 'gov-1'), { id: 'gov-1' });
  assert.deepEqual(await service.listActiveDistricts(tx, 'gov-1'), [{ id: 'district-1' }]);

  assert.deepEqual(calls, [
    ['city.findMany', { where: { isActive: true }, orderBy: order }],
    ['category.findMany', { where: { isActive: true }, orderBy: order }],
    ['governorate.findMany', {
      where: { isActive: true },
      orderBy: order,
      include: { _count: { select: { districts: { where: { isActive: true } } } } },
    }],
    ['governorate.findFirst', { where: { id: 'gov-1', isActive: true }, select: { id: true } }],
    ['district.findMany', { where: { governorateId: 'gov-1', isActive: true }, orderBy: order }],
  ]);
});

test('the catalog read port reads rows by id and active rows by id without a statement for an empty id list', async () => {
  const { tx, calls } = client();
  const service = new CatalogReadService();

  assert.deepEqual(await service.getCities(tx, []), []);
  assert.deepEqual(await service.getCategories(tx, []), []);
  assert.equal(await service.countActiveCategories(tx, []), 0);
  assert.deepEqual(await service.getCities(tx, ['city-1', 'city-2']), [{ id: 'city-1' }]);
  assert.deepEqual(await service.getCategories(tx, ['category-1']), [{ id: 'category-1' }]);
  assert.deepEqual(await service.findActiveCity(tx, 'city-1'), { id: 'city-1' });
  assert.deepEqual(await service.findActiveCategory(tx, 'category-1'), { id: 'category-1' });
  assert.equal(await service.countActiveCategories(tx, ['category-1', 'category-2']), 2);

  assert.deepEqual(calls, [
    ['city.findMany', { where: { id: { in: ['city-1', 'city-2'] } } }],
    ['category.findMany', { where: { id: { in: ['category-1'] } } }],
    ['city.findFirst', { where: { id: 'city-1', isActive: true } }],
    ['category.findFirst', { where: { id: 'category-1', isActive: true } }],
    ['category.count', { where: { id: { in: ['category-1', 'category-2'] }, isActive: true } }],
  ]);
});

test('the catalog read port locks a city or the categories for share before confirming they are active', async () => {
  const { tx, calls } = client();
  const service = new CatalogReadService();

  assert.deepEqual(await service.lockActiveCityForShareInTransaction(tx, 'city-1'), { id: 'city-1' });
  assert.equal(await service.lockActiveCategoriesForShareInTransaction(tx, ['category-2', 'category-1', 'category-2']), true);
  assert.equal(await service.lockActiveCategoriesForShareInTransaction(tx, []), true);

  assert.deepEqual(calls, [
    ['$queryRaw', { sql: 'SELECT "id" FROM "City" WHERE "id" = ? FOR SHARE', values: ['city-1'] }],
    ['city.findFirst', { where: { id: 'city-1', isActive: true } }],
    ['$queryRaw', {
      sql: 'SELECT "id" FROM "ProviderCategory" WHERE "id" = ANY(?::text[]) ORDER BY "id" ASC FOR SHARE',
      values: [['category-1', 'category-2']],
    }],
    ['category.count', { where: { id: { in: ['category-1', 'category-2'] }, isActive: true } }],
  ]);
});

test('a missing city row or a category row that is gone or inactive fails the lock closed', async () => {
  const calls: string[] = [];
  const tx = {
    $queryRaw: async () => { calls.push('lock'); return []; },
    city: { findFirst: async () => { calls.push('city'); return null; } },
    providerCategory: { count: async () => { calls.push('count'); return 0; } },
  } as unknown as Prisma.TransactionClient;
  const service = new CatalogReadService();

  assert.equal(await service.lockActiveCityForShareInTransaction(tx, 'city-9'), null);
  assert.equal(await service.lockActiveCategoriesForShareInTransaction(tx, ['category-9']), false);
  assert.deepEqual(calls, ['lock', 'lock']);
});

test('the catalog read public module exposes only its port token bound to the internal implementation', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(CatalogReadPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: CATALOG_READ_PORT, useExisting: CATALOG_READ_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(CatalogReadPublicModule, MODULE_METADATA.EXPORTS), [CATALOG_READ_PORT]);
  assert.deepEqual(metadata(CatalogReadInternalModule, MODULE_METADATA.PROVIDERS), [
    CatalogReadService,
    { provide: CATALOG_READ_IMPLEMENTATION, useExisting: CatalogReadService },
  ]);
});
