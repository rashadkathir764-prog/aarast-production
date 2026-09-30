import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import {
  findVisibleWeddingCost,
  listWeddingCosts,
  lockBudgetCategoriesForCost,
  lockWeddingCost,
} from '../src/modules/finance/infrastructure/wedding-costs.repository';

test('wedding cost reads use the caller transaction and preserve authorization filters', async () => {
  const calls: Array<{ operation: string; args: unknown }> = [];
  const tx = {
    weddingCost: {
      findMany: async (args: unknown) => {
        calls.push({ operation: 'findMany', args });
        return [];
      },
      findFirst: async (args: unknown) => {
        calls.push({ operation: 'findFirst', args });
        return null;
      },
    },
  } as unknown as Prisma.TransactionClient;

  const where = { weddingPlanId: 'plan-1', id: { in: ['cost-1'] } };
  await listWeddingCosts(tx, {
    where,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    skip: 10,
    take: 5,
  });
  await findVisibleWeddingCost(tx, { where: { ...where, id: 'cost-1' } });

  assert.deepEqual(calls, [
    {
      operation: 'findMany',
      args: {
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: 10,
        take: 5,
      },
    },
    {
      operation: 'findFirst',
      args: { where: { weddingPlanId: 'plan-1', id: 'cost-1' } },
    },
  ]);
});

test('cost locks keep category share and cost update locks on the same transaction', async () => {
  const events: string[] = [];
  const tx = {
    $queryRaw: async () => {
      events.push('lock');
      return [{ id: events.length === 1 ? 'cat-1' : 'cost-1' }];
    },
    weddingCost: {
      findUniqueOrThrow: async (args: unknown) => {
        events.push('read');
        assert.deepEqual(args, { where: { id: 'cost-1' } });
        return { id: 'cost-1' };
      },
    },
  } as unknown as Prisma.TransactionClient;

  assert.deepEqual(await lockBudgetCategoriesForCost(tx, ['cat-1'], 'plan-1'), ['cat-1']);
  assert.deepEqual(await lockWeddingCost(tx, 'cost-1'), { id: 'cost-1' });
  assert.deepEqual(events, ['lock', 'lock', 'read']);
});

test('a missing cost lock fails before any cost read', async () => {
  let read = false;
  const tx = {
    $queryRaw: async () => [],
    weddingCost: {
      findUniqueOrThrow: async () => {
        read = true;
      },
    },
  } as unknown as Prisma.TransactionClient;
  await assert.rejects(lockWeddingCost(tx, 'missing'), NotFoundException);
  assert.equal(read, false);
});
