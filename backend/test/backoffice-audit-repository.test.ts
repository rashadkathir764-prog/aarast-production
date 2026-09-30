import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminAuditPhase } from '@prisma/client';
import { PrismaAdminAuditLogRepository } from '../src/modules/backoffice/infrastructure/prisma-admin-audit-log.repository';

test('audit list keeps count and selected page in one Prisma array transaction', async () => {
  const calls: Array<{ operation: string; args: any }> = [];
  let transactionCalls = 0;
  const selected = [{ id: 'audit-1' }];
  const prisma = {
    adminAuditLog: {
      count: (args: any) => {
        calls.push({ operation: 'count', args });
        return Promise.resolve(3);
      },
      findMany: (args: any) => {
        calls.push({ operation: 'findMany', args });
        return Promise.resolve(selected);
      },
    },
    $transaction: async (operations: Array<Promise<unknown>>) => {
      transactionCalls++;
      return Promise.all(operations);
    },
  };
  const repository = new PrismaAdminAuditLogRepository(prisma as any);

  const result = await repository.list({
    action: ' APPROVE ', actorUserId: ' admin-1 ', phase: AdminAuditPhase.SUCCEEDED,
    from: '2026-09-01T00:00:00.000Z', to: '2026-09-29T00:00:00.000Z',
  } as any, 2, 20);

  assert.deepEqual(result, { total: 3, items: selected });
  assert.equal(transactionCalls, 1);
  assert.deepEqual(calls.map((call) => call.operation), ['count', 'findMany']);
  assert.deepEqual(calls[0].args.where, calls[1].args.where);
  assert.deepEqual(calls[1].args.orderBy, [{ createdAt: 'desc' }, { id: 'desc' }]);
  assert.equal(calls[1].args.skip, 20);
  assert.equal(calls[1].args.take, 20);
  assert.equal(calls[1].args.select.requestId, true);
});
