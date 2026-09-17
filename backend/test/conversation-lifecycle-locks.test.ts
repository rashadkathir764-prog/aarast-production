import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
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
      'lockConversationForShareInTransaction',
      'lockConversationForUpdateInTransaction',
      'recordConversationEvent',
    ],
  );
});
