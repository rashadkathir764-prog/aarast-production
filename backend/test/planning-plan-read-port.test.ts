import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import type { Prisma } from '@prisma/client';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';
import { PlanErasureService } from '../src/modules/planning/infrastructure/plan-erasure.service';
import {
  PLAN_ERASURE_IMPLEMENTATION,
  PLAN_READ_IMPLEMENTATION,
  PlanReadInternalModule,
} from '../src/modules/planning/internal/plan-read.internal.module';
import { PlanReadPublicModule } from '../src/modules/planning/public/plan-read-public.module';
import { PLAN_READ_PORT } from '../src/modules/planning/public/plan-read.port';

function sqlText(query: unknown): string {
  const strings = (query as { strings?: readonly string[] }).strings;
  assert.ok(Array.isArray(strings));
  return strings.join('?').replace(/\s+/g, ' ').trim();
}

test('the plan read port runs the owner queries on the client it is given', async () => {
  const calls: Array<[string, unknown]> = [];
  const row = { id: 'plan-1', ownerUserId: 'owner-1' };
  const client = {
    weddingPlan: {
      findUnique: async (args: unknown) => {
        calls.push(['findUnique', args]);
        return row;
      },
      findFirst: async (args: unknown) => {
        calls.push(['findFirst', args]);
        return null;
      },
      findMany: async (args: unknown) => {
        calls.push(['findMany', args]);
        return [row];
      },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new PlanReadService();

  assert.equal(await service.getPlan(client, 'plan-1'), row);
  assert.deepEqual(await service.getPlans(client, ['plan-1', 'plan-2']), [row]);
  assert.equal(await service.findOwnedPlan(client, 'plan-1', 'owner-2'), null);
  assert.deepEqual(await service.listOwnedPlans(client, 'owner-1'), [row]);
  assert.deepEqual(await service.listOwnedPlanIds(client, 'owner-1'), ['plan-1']);
  assert.deepEqual(await service.getPlans(client, []), []);

  assert.deepEqual(calls, [
    ['findUnique', { where: { id: 'plan-1' } }],
    ['findMany', { where: { id: { in: ['plan-1', 'plan-2'] } } }],
    ['findFirst', { where: { id: 'plan-1', ownerUserId: 'owner-2' } }],
    ['findMany', { where: { ownerUserId: 'owner-1' } }],
    ['findMany', { where: { ownerUserId: 'owner-1' }, select: { id: true } }],
  ]);
});

test('the plan lifecycle locks take the plan row with the same statements callers used', async () => {
  const statements: string[] = [];
  const tx = {
    $queryRaw: async (query: unknown) => {
      statements.push(sqlText(query));
      return [{ id: 'plan-1' }];
    },
  } as unknown as Prisma.TransactionClient;

  const service = new PlanReadService();
  assert.deepEqual(await service.lockPlanRowForShareInTransaction(tx, 'plan-1'), [{ id: 'plan-1' }]);
  assert.deepEqual(await service.lockPlanRowForUpdateInTransaction(tx, 'plan-1'), [{ id: 'plan-1' }]);
  assert.deepEqual(statements, [
    'SELECT "id" FROM "WeddingPlan" WHERE "id" = ? FOR SHARE',
    'SELECT "id" FROM "WeddingPlan" WHERE "id" = ? FOR UPDATE',
  ]);
});

test('the plan read public module exposes only the port token bound to the internal implementation', () => {
  const providers = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, PlanReadPublicModule);
  const exportsList = Reflect.getMetadata(MODULE_METADATA.EXPORTS, PlanReadPublicModule);
  const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, PlanReadPublicModule);
  assert.deepEqual(providers, [{ provide: PLAN_READ_PORT, useExisting: PLAN_READ_IMPLEMENTATION }]);
  assert.deepEqual(exportsList, [PLAN_READ_PORT]);
  assert.deepEqual(imports, [PlanReadInternalModule]);

  const internalProviders = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, PlanReadInternalModule);
  assert.deepEqual(internalProviders, [
    PlanReadService,
    PlanErasureService,
    { provide: PLAN_READ_IMPLEMENTATION, useExisting: PlanReadService },
    { provide: PLAN_ERASURE_IMPLEMENTATION, useExisting: PlanErasureService },
  ]);
});
