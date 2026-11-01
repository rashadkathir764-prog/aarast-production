import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { Prisma } from '@prisma/client';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { catalogWithoutMoneyLinks } from './support/owner-ports';
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
  assert.equal(await new FinancePortService(catalogWithoutMoneyLinks).findCostForAcceptedOffer(tx, 'offer-1'), null);
  assert.deepEqual(calls, [
    ['weddingCost.findFirst', { where: { quoteOfferId: 'offer-1' }, include: weddingCostResponseInclude }],
  ]);
});

test('the costs linked to a set of offers are read by offer id, none for an empty set', async () => {
  const calls: unknown[] = [];
  const client = {
    weddingCost: {
      findMany: async (args: unknown) => {
        calls.push(args);
        const money = {
          budgetCategoryId: 'item-1',
          totalAmount: new Prisma.Decimal(550000),
          paidAmount: new Prisma.Decimal(100000),
          status: 'PARTIALLY_PAID',
        };
        return [
          { id: 'cost-1', quoteOfferId: 'offer-1', ...money, payments: [{ paidAt: new Date('2026-12-12T00:00:00Z') }] },
          { id: 'cost-2', quoteOfferId: null, ...money, payments: [] },
        ];
      },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new FinancePortService(catalogWithoutMoneyLinks);

  assert.deepEqual(await service.listCostsForOffers(client, []), []);
  // B-18: the item and the three totals, never the payments themselves.
  assert.deepEqual(await service.listCostsForOffers(client, ['offer-1', 'offer-2']), [
    {
      id: 'cost-1',
      quoteOfferId: 'offer-1',
      budgetCategoryId: 'item-1',
      totalAmount: new Prisma.Decimal(550000),
      paidAmount: new Prisma.Decimal(100000),
      status: 'PARTIALLY_PAID',
      lastPaidAt: new Date('2026-12-12T00:00:00Z'),
    },
  ]);
  assert.deepEqual(calls, [
    {
      where: { quoteOfferId: { in: ['offer-1', 'offer-2'] } },
      select: {
        id: true,
        quoteOfferId: true,
        budgetCategoryId: true,
        totalAmount: true,
        paidAmount: true,
        status: true,
        payments: {
          where: { entryType: 'PAYMENT', reversedBy: null },
          orderBy: { paidAt: 'desc' },
          take: 1,
          select: { paidAt: true },
        },
      },
    },
  ]);
});

test('an accepted offer creates its cost under the matching plan category', async () => {
  const hall = { id: 'cat-hall', name: 'صالة الأفراح', normalizedName: 'صالة الأفراح' };
  const { tx, calls } = harness([hall]);
  const created = await new FinancePortService(catalogWithoutMoneyLinks).createCostFromAcceptedOffer(tx, {
    weddingPlanId: 'plan-1',
    providerId: 'provider-1',
    quoteOfferId: 'offer-1',
    title: 'قاعة',
    amount: new Prisma.Decimal('2500'),
    providerCategoryName: 'قاعات',
  });
  assert.equal(created.id, 'cost-1');
  assert.deepEqual(calls, [
    // G38: the plan's items in their own order, so the first fit is stable.
    ['budgetCategory.findMany', {
      // C1: an offer is wedding money, never the groom's mahr item.
      where: { weddingPlanId: 'plan-1', kind: 'WEDDING' },
      select: { id: true, name: true, normalizedName: true },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    }],
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
  await new FinancePortService(catalogWithoutMoneyLinks).createCostFromAcceptedOffer(tx, {
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
