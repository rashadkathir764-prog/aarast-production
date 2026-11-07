import assert from 'node:assert/strict';
import { test } from 'node:test';
import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AdminCategoryDto, AdminCityDto } from '../src/admin/dto/admin-catalog.dto';
import { AdminReviewActionDto } from '../src/admin/dto/admin-review-action.dto';
import { AdminServiceDto } from '../src/admin/dto/admin-service.dto';

// RA-AD-16: the back office's own writes took text of any length. A city's
// Arabic name sits in a unique btree index, whose row stops near 2.7 KB, so a
// long one was the database's error, a 500; a provider's refusal reason was
// stored and pushed with no limit while the same note under «اطلب تعديل»
// stopped at 2000. Each field now says its length, and the panel's box
// stops at the same number.

async function refused<T extends object>(Dto: new () => T, payload: Record<string, unknown>) {
  return (await validate(plainToInstance(Dto, payload))).map((error) => error.property);
}

const cases: Array<[string, new () => object, Record<string, unknown>, string, number]> = [
  ['city', AdminCityDto, { nameAr: 'صنعاء' }, 'nameAr', 160],
  ['city', AdminCityDto, { nameAr: 'صنعاء' }, 'nameEn', 160],
  ['city', AdminCityDto, { nameAr: 'صنعاء' }, 'countryCode', 8],
  ['category', AdminCategoryDto, { nameAr: 'القاعات' }, 'nameAr', 160],
  ['category', AdminCategoryDto, { nameAr: 'القاعات' }, 'nameEn', 160],
  ['category', AdminCategoryDto, { nameAr: 'القاعات' }, 'slug', 120],
  ['category', AdminCategoryDto, { nameAr: 'القاعات' }, 'icon', 80],
  ['service', AdminServiceDto, {}, 'title', 160],
  ['service', AdminServiceDto, {}, 'description', 2000],
  ['service', AdminServiceDto, {}, 'priceUnit', 120],
  ['service', AdminServiceDto, {}, 'currency', 8],
  ['provider decision', AdminReviewActionDto, {}, 'reason', 2000],
  ['provider decision', AdminReviewActionDto, {}, 'note', 2000],
];

for (const [name, Dto, base, field, limit] of cases) {
  test(`a ${name}'s ${field} stops at ${limit} characters`, async () => {
    assert.deepEqual(await refused(Dto, { ...base, [field]: 'ا'.repeat(limit) }), []);
    assert.deepEqual(await refused(Dto, { ...base, [field]: 'ا'.repeat(limit + 1) }), [field]);
  });
}
