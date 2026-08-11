import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminService } from '../src/admin/admin.service';

test('admin dashboard totalCities counts active cities only', async () => {
  const zeroCountModel = { count: async () => 0 };
  const city = {
    count: async (args?: { where?: { isActive?: boolean } }) =>
      args?.where?.isActive === true ? 1 : 2,
  };
  const prisma = new Proxy(
    {
      city,
      $transaction: async (operations: Array<Promise<unknown>>) =>
        Promise.all(operations),
    } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? zeroCountModel,
    },
  );
  const service = new AdminService(
    prisma as any,
    {} as any,
    {} as any,
  );

  const result = await service.getDashboardStats();

  assert.equal(result.totalCities, 1);
});
