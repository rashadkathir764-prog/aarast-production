import assert from 'node:assert/strict';
import test from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import {
  assertActiveMutationActorForUpdateInTransaction,
  lockUserLifecycleRowsForUpdateInTransaction,
  lockUserLifecycleRowsInTransaction,
} from '../src/modules/identity/public/user-lifecycle-lock';

test('user lifecycle locks retain sorted IDs and exact share/update modes', async () => {
  const calls: Array<{ text: string; values: unknown[] }> = [];
  const tx = {
    $queryRaw: async (sql: { sql: string; values: unknown[] }) => {
      calls.push({ text: sql.sql, values: sql.values });
      return [{ id: 'a', status: UserStatus.ACTIVE }];
    },
  } as any;

  await lockUserLifecycleRowsInTransaction(tx, ['b', 'a', 'b']);
  await lockUserLifecycleRowsForUpdateInTransaction(tx, ['b', 'a']);
  assert.equal(calls.length, 2);
  assert.match(calls[0].text, /ORDER BY "id" ASC\s+FOR SHARE/);
  assert.match(calls[1].text, /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.deepEqual(calls[0].values, ['a', 'b']);
  assert.deepEqual(calls[1].values, ['a', 'b']);
});

test('user lifecycle mutation actor must remain active after update lock', async () => {
  const tx = {
    $queryRaw: async () => [{ id: 'actor', status: UserStatus.DISABLED }],
  } as any;
  await assert.rejects(
    assertActiveMutationActorForUpdateInTransaction(tx, 'actor'),
    NotFoundException,
  );
});
