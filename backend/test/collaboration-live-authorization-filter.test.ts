import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';
import { PlanReadService } from '../src/modules/planning/internal/plan-read.service';
import {
  NEVER_MATCHING_ROW_FILTER,
  type PlanAccessContext,
} from '../src/modules/collaboration/public/collaboration-permission.port';

// The final live read used to embed `weddingPlan: { is: livePlanAuthorizationWhere(...) }`
// in its own SQL statement. The owners now evaluate the same predicate — current
// ownership (planning) or the same membership row with every required flag
// (collaboration) — and the caller applies the result to its own table: nothing
// when it still holds, a never-matching filter otherwise, so the final statement
// returns exactly what the embedded join returned.

function contexts() {
  const plan = { id: 'plan-1', ownerUserId: 'owner-1' };
  const owner = { plan, isOwner: true, sharedMember: null } as unknown as PlanAccessContext;
  const member = {
    plan,
    isOwner: false,
    sharedMember: { id: 'member-a', weddingPlanId: 'plan-1', userId: 'contributor-a', canViewMoney: true },
  } as unknown as PlanAccessContext;
  return { owner, member };
}

test('an owner is live while planning still records the plan under that owner', async () => {
  const { owner } = contexts();
  const calls: unknown[] = [];
  const client = {
    weddingPlan: {
      findFirst: async (args: unknown) => {
        calls.push(args);
        return calls.length === 1 ? { id: 'plan-1', ownerUserId: 'owner-1' } : null;
      },
    },
  } as any;
  const service = new PermissionService(client, new PlanReadService());

  assert.deepEqual(await service.liveAuthorizationFilter(client, owner, 'owner-1'), {});
  assert.deepEqual(await service.liveAuthorizationFilter(client, owner, 'owner-1'), NEVER_MATCHING_ROW_FILTER);
  assert.deepEqual(calls, [
    { where: { id: 'plan-1', ownerUserId: 'owner-1' } },
    { where: { id: 'plan-1', ownerUserId: 'owner-1' } },
  ]);
});

test('a member is live while the same membership row still carries every required flag', async () => {
  const { member } = contexts();
  const calls: unknown[] = [];
  const client = {
    sharedMember: {
      findFirst: async (args: unknown) => {
        calls.push(args);
        return calls.length === 1 ? { id: 'member-a' } : null;
      },
    },
  } as any;
  const service = new PermissionService(client, new PlanReadService());

  assert.deepEqual(
    await service.liveAuthorizationFilter(client, member, 'contributor-a', ['canViewMoney', 'canManageMoney']),
    {},
  );
  assert.deepEqual(
    await service.liveAuthorizationFilter(client, member, 'contributor-a'),
    NEVER_MATCHING_ROW_FILTER,
  );
  assert.deepEqual(calls, [
    {
      where: { id: 'member-a', weddingPlanId: 'plan-1', userId: 'contributor-a', canViewMoney: true, canManageMoney: true },
      select: { id: true },
    },
    { where: { id: 'member-a', weddingPlanId: 'plan-1', userId: 'contributor-a' }, select: { id: true } },
  ]);
});

test('a context whose membership belongs to another user is rejected before any read, as before', async () => {
  const { member } = contexts();
  const service = new PermissionService({} as any, new PlanReadService());
  await assert.rejects(
    () => service.liveAuthorizationFilter({} as any, member, 'someone-else'),
    NotFoundException,
  );
  await assert.rejects(
    () => service.liveAuthorizationFilter({} as any, { ...member, sharedMember: null }, 'contributor-a'),
    NotFoundException,
  );
});

test('the never-matching filter is an empty id list so Prisma returns no rows for any model', () => {
  assert.deepEqual(NEVER_MATCHING_ROW_FILTER, { id: { in: [] } });
});

// Tasks used to lock the assignee's membership row itself (`SELECT ... FROM
// "SharedMember" ... FOR SHARE`) before reading it; the member row is
// collaboration's, so the lock-and-read is one port call on the caller's
// transaction.
test('the assignee membership is locked for share and read on the same transaction', async () => {
  const calls: Array<[string, unknown]> = [];
  const member = { id: 'member-a', weddingPlanId: 'plan-1', userId: 'contributor-a', canManageTasks: true };
  const tx = {
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => {
      calls.push(['$queryRaw', { sql: query.strings.join('?').replace(/\s+/g, ' ').trim(), values: query.values }]);
      return [{ id: member.id }];
    },
    sharedMember: {
      findUnique: async (args: unknown) => { calls.push(['findUnique', args]); return member; },
    },
  } as any;
  const service = new PermissionService({} as any, new PlanReadService());

  assert.equal(await service.lockMembershipForShareInTransaction(tx, 'plan-1', 'contributor-a'), member);
  assert.deepEqual(calls, [
    ['$queryRaw', {
      sql: 'SELECT "id" FROM "SharedMember" WHERE "weddingPlanId" = ? AND "userId" = ? FOR SHARE',
      values: ['plan-1', 'contributor-a'],
    }],
    ['findUnique', { where: { weddingPlanId_userId: { weddingPlanId: 'plan-1', userId: 'contributor-a' } } }],
  ]);
});
