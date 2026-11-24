import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  isConversationBlocked,
  lockConversationForShare,
  lockConversationForUpdate,
} from '../src/conversations/conversation-lifecycle';
import {
  CONVERSATION_LIFECYCLE_IMPLEMENTATION,
  ConversationLifecycleInternalModule,
  ConversationLifecycleService,
} from '../src/modules/messaging/internal/conversation-lifecycle.internal.module';
import { MODULE_METADATA } from '@nestjs/common/constants';

// Marketplace and the provider dashboard used to lock the conversation row
// of a quote themselves (a raw join from the request or offer). The row is
// messaging's: the lifecycle port locks it on the caller's transaction and
// reports whether it exists; the callers keep their conversation -> request
// -> offer order.

function client(rows: Array<{ id: string }>) {
  const calls: Array<{ sql: string; values: unknown[] }> = [];
  const tx = {
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => {
      calls.push({ sql: query.strings.join('?').replace(/\s+/g, ' ').trim(), values: query.values });
      return rows;
    },
  } as any;
  return { tx, calls };
}

test('the conversation row is locked for update or for share by id and its presence reported', async () => {
  const present = client([{ id: 'conversation-1' }]);
  assert.equal(await lockConversationForUpdate(present.tx, 'conversation-1'), true);
  assert.equal(await lockConversationForShare(present.tx, 'conversation-1'), true);
  assert.deepEqual(present.calls, [
    { sql: 'SELECT "id" FROM "Conversation" WHERE "id" = ? FOR UPDATE', values: ['conversation-1'] },
    { sql: 'SELECT "id" FROM "Conversation" WHERE "id" = ? FOR SHARE', values: ['conversation-1'] },
  ]);

  const missing = client([]);
  assert.equal(await lockConversationForUpdate(missing.tx, 'conversation-9'), false);
  assert.equal(await lockConversationForShare(missing.tx, 'conversation-9'), false);
});

test('the lifecycle implementation binds the locks next to the two lifecycle operations', () => {
  const providers = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, ConversationLifecycleInternalModule) as Array<unknown>;
  assert.deepEqual(providers, [
    ConversationLifecycleService,
    { provide: CONVERSATION_LIFECYCLE_IMPLEMENTATION, useExisting: ConversationLifecycleService },
  ]);
  assert.deepEqual(
    Object.getOwnPropertyNames(ConversationLifecycleService.prototype).filter((name) => name !== 'constructor').sort(),
    [
      'ensureConversationContext',
      'findConversationProviderId',
      'isConversationBlockedInTransaction',
      'lockConversationForShareInTransaction',
      'lockConversationForUpdateInTransaction',
      'recordConversationEvent',
    ],
  );
});

// RA-BE-169: whether either side stopped the conversation, read on the
// caller's transaction (after its share lock) by the quote writes it stops.
test('a conversation reads as blocked when either side blocked it', async () => {
  const at = new Date('2026-11-24T10:00:00Z');
  const customer = client([{ customerSideBlockedAt: at, providerSideBlockedAt: null }] as any);
  assert.equal(await isConversationBlocked(customer.tx, 'conversation-1'), true);
  assert.deepEqual(customer.calls, [
    {
      sql: 'SELECT "customerSideBlockedAt", "providerSideBlockedAt" FROM "Conversation" WHERE "id" = ?',
      values: ['conversation-1'],
    },
  ]);
  const provider = client([{ customerSideBlockedAt: null, providerSideBlockedAt: at }] as any);
  assert.equal(await isConversationBlocked(provider.tx, 'conversation-1'), true);
  const open = client([{ customerSideBlockedAt: null, providerSideBlockedAt: null }] as any);
  assert.equal(await isConversationBlocked(open.tx, 'conversation-1'), false);
  assert.equal(await isConversationBlocked(client([]).tx, 'conversation-9'), false);
});
