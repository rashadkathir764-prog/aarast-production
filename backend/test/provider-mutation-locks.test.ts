import assert from 'node:assert/strict';
import test from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { ProviderStatus } from '@prisma/client';
import { lockOwnedProviderAfterUsersInTransaction } from '../src/provider-dashboard/provider-mutation-locks';

test('provider mutation takes the requested row lock before reading the profile', async () => {
  const events: string[] = [];
  const provider = { id: 'provider-1', userId: 'user-1', status: ProviderStatus.ACTIVE };
  const tx = {
    $queryRaw: async (query: { sql: string }) => {
      events.push(query.sql);
      return [{ id: provider.id }];
    },
    provider: {
      findUnique: async () => {
        events.push('findUnique');
        return provider;
      },
    },
  } as any;

  assert.equal(await lockOwnedProviderAfterUsersInTransaction(tx, 'user-1', 'OPERATIONAL'), provider);
  assert.match(events[0], /FROM "Provider"[\s\S]*FOR SHARE/);
  assert.equal(events[1], 'findUnique');
  events.length = 0;
  await lockOwnedProviderAfterUsersInTransaction(tx, 'user-1', 'OPERATIONAL', 'UPDATE');
  assert.match(events[0], /FROM "Provider"[\s\S]*FOR UPDATE/);
  assert.equal(events[1], 'findUnique');
});

test('provider mutation rejects a mismatched expected provider after locking', async () => {
  let profileRead = false;
  const tx = {
    $queryRaw: async () => [{ id: 'provider-1' }],
    provider: { findUnique: async () => { profileRead = true; } },
  } as any;
  await assert.rejects(
    lockOwnedProviderAfterUsersInTransaction(tx, 'user-1', 'PROFILE', 'SHARE', 'provider-2'),
    NotFoundException,
  );
  assert.equal(profileRead, false);
});
