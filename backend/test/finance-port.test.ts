import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { Prisma } from '@prisma/client';
import { FinancePortService } from '../src/modules/finance/internal/finance-port.service';
import {
  FINANCE_IMPLEMENTATION,
  FinancePortInternalModule,
} from '../src/modules/finance/internal/finance-port.internal.module';
import { FinancePublicModule } from '../src/modules/finance/public/finance-public.module';
import { FINANCE_PORT } from '../src/modules/finance/public/finance.port';
import { weddingCostResponseInclude } from '../src/modules/finance/public/wedding-cost.presenter';

// Quote acceptance used to run these statements itself inside its serializable
// transaction. They now run in finance, on the same transaction, in the same
// order: read the plan's categories, match the provider category (or the
// `أخرى` fallback, created when missing), create the cost.

function harness(categories: Array<{ id: string; name: string; normalizedName: string }>) {
  const calls: Array<[string, unknown]> = [];
  const tx = {
    weddingCost: {
      findFirst: async (args: unknown) => { calls.push(['weddingCost.findFirst', args]); return null; },
      create: async (args: unknown) => { calls.push(['weddingCost.create', args]); return { id: 'cost-1', budgetCategory: { name: 'x' }, _count: { payments: 0, paymentSchedules: 0 } }; },
    },
    budgetCategory: {
      findMany: async (args: unknown) => { calls.push(['budgetCategory.findMany', args]); return categories; },
      upsert: async (args: unknown) => { calls.push(['budgetCategory.upsert', args]); return { id: 'other-1', name: 'أخرى', normalizedName: 'أخرى' }; },
    },
  } as unknown as Prisma.TransactionClient;
  return { tx, calls };
}

test('the accepted-offer cost is looked up by the offer it links to', async () => {
  const { tx, calls } = harness([]);
  assert.equal(await new FinancePortService().findCostForAcceptedOffer(tx, 'offer-1'), null);
  assert.deepEqual(calls, [
    ['weddingCost.findFirst', { where: { quoteOfferId: 'offer-1' }, include: weddingCostResponseInclude }],
  ]);
});

test('an accepted offer creates its cost under the matching plan category', async () => {
  const hall = { id: 'cat-hall', name: 'صالة الأفراح', normalizedName: 'صالة الأفراح' };
  const { tx, calls } = harness([hall]);
  const created = await new FinancePortService().createCostFromAcceptedOffer(tx, {
    weddingPlanId: 'plan-1',
    providerId: 'provider-1',
    quoteOfferId: 'offer-1',
    title: 'قاعة',
    amount: new Prisma.Decimal('2500'),
    providerCategoryName: 'قاعات',
  });
  assert.equal(created.id, 'cost-1');
  assert.deepEqual(calls, [
    ['budgetCategory.findMany', { where: { weddingPlanId: 'plan-1' }, select: { id: true, name: true, normalizedName: true } }],
    ['weddingCost.create', {
      data: {
        weddingPlanId: 'plan-1',
        budgetCategoryId: 'cat-hall',
        providerId: 'provider-1',
        quoteOfferId: 'offer-1',
        title: 'قاعة',
        totalAmount: new Prisma.Decimal('2500'),
        paidAmount: new Prisma.Decimal(0),
      },
      include: weddingCostResponseInclude,
    }],
  ]);
});

test('without a matching category the cost falls back to أخرى, created when the plan has none', async () => {
  const { tx, calls } = harness([{ id: 'cat-food', name: 'ضيافة', normalizedName: 'ضيافة' }]);
  await new FinancePortService().createCostFromAcceptedOffer(tx, {
    weddingPlanId: 'plan-1',
    providerId: 'provider-1',
    quoteOfferId: 'offer-1',
    title: 'Something',
    amount: new Prisma.Decimal('10'),
    providerCategoryName: null,
  });
  assert.equal(calls[1][0], 'budgetCategory.upsert');
  assert.deepEqual(calls[1][1], {
    where: { weddingPlanId_normalizedName: { weddingPlanId: 'plan-1', normalizedName: 'أخرى' } },
    update: {},
    create: { weddingPlanId: 'plan-1', name: 'أخرى', normalizedName: 'أخرى' },
    select: { id: true, name: true, normalizedName: true },
  });
  assert.equal((calls[2][1] as { data: { budgetCategoryId: string } }).data.budgetCategoryId, 'other-1');
});

test('the finance public module exposes only the port token bound to the internal implementation', () => {
  assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.PROVIDERS, FinancePublicModule), [
    { provide: FINANCE_PORT, useExisting: FINANCE_IMPLEMENTATION },
  ]);
  assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.EXPORTS, FinancePublicModule), [FINANCE_PORT]);
  assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.IMPORTS, FinancePublicModule), [FinancePortInternalModule]);
  assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.PROVIDERS, FinancePortInternalModule), [
    FinancePortService,
    { provide: FINANCE_IMPLEMENTATION, useExisting: FinancePortService },
  ]);
});
