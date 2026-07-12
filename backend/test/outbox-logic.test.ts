import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { OutboxEvent } from '@prisma/client';
import { ConversationRealtimePublisher } from '../src/conversations/conversation-realtime.publisher';
import { OutboxEventTypes } from '../src/outbox/outbox.constants';
import { OutboxDispatcher } from '../src/outbox/outbox.dispatcher';
import { OutboxService } from '../src/outbox/outbox.service';
import { OutboxCleanupScheduler } from '../src/outbox/outbox-cleanup.scheduler';
import { outboxFailureCode, outboxRetryDelayMs } from '../src/outbox/outbox.worker';

function event(type: string, payload: OutboxEvent['payload']): OutboxEvent {
  const now = new Date('2026-07-10T10:00:00.000Z');
  return {
    id: 'event-1',
    type,
    aggregateType: null,
    aggregateId: null,
    payload,
    status: 'PROCESSING',
    attemptCount: 1,
    nextAttemptAt: now,
    lockedAt: now,
    lockedBy: 'worker-1',
    processedAt: null,
    lastError: null,
    createdAt: now,
    updatedAt: now,
  };
}

test('outbox enqueue writes the supplied transaction client', async () => {
  let data: unknown;
  const client = {
    outboxEvent: {
      create: async (input: unknown) => {
        data = input;
        return {};
      },
    },
  };
  await new OutboxService().enqueue(client as never, {
    type: OutboxEventTypes.notificationCreated,
    aggregateType: 'notification',
    aggregateId: 'notification-1',
    payload: { notificationId: 'notification-1', userId: 'user-1' },
  });
  assert.match(JSON.stringify(data), /notification-1/);
});

test('dispatcher publishes durable chat and notification availability', async () => {
  const calls: Array<[string, string, unknown]> = [];
  const realtime = {
    messageAvailable: (id: string, payload: unknown) => {
      calls.push(['message', id, payload]);
    },
    notificationAvailable: (id: string, payload: unknown) => {
      calls.push(['notification', id, payload]);
    },
  } as unknown as ConversationRealtimePublisher;
  const dispatcher = new OutboxDispatcher(realtime);

  await dispatcher.dispatch(
    event(OutboxEventTypes.conversationMessageAvailable, {
      conversationId: 'conversation-1',
      messageId: 'message-1',
    }),
  );
  await dispatcher.dispatch(
    event(OutboxEventTypes.notificationCreated, {
      notificationId: 'notification-1',
      userId: 'user-1',
    }),
  );

  assert.deepEqual(calls, [
    ['message', 'conversation-1', { conversationId: 'conversation-1', messageId: 'message-1' }],
    ['notification', 'user-1', { notificationId: 'notification-1' }],
  ]);
});

test('outbox retry is bounded and failure storage is redacted', () => {
  assert.equal(outboxRetryDelayMs(1), 1_000);
  assert.equal(outboxRetryDelayMs(4), 8_000);
  assert.equal(outboxRetryDelayMs(100), 128_000);
  const secret = new Error('postgres://user:secret@db/private');
  assert.equal(outboxFailureCode(secret), 'Error');
  assert.equal(outboxFailureCode(secret).includes('secret'), false);
});

test('outbox uses transactional inserts and cross-replica skip-locked claims', () => {
  const worker = readFileSync(join(process.cwd(), 'src/outbox/outbox.worker.ts'), 'utf8');
  const notifications = readFileSync(
    join(process.cwd(), 'src/notifications/notifications.service.ts'),
    'utf8',
  );
  const conversations = readFileSync(
    join(process.cwd(), 'src/conversations/conversations.service.ts'),
    'utf8',
  );
  const schema = readFileSync(join(process.cwd(), 'prisma/schema.prisma'), 'utf8');

  assert.match(worker, /FOR UPDATE SKIP LOCKED/);
  assert.match(worker, /status: terminal \? 'FAILED' : 'PENDING'/);
  assert.match(notifications, /\$transaction/);
  assert.match(notifications, /notificationCreated/);
  assert.match(conversations, /conversationMessageAvailable/);
  assert.match(schema, /model OutboxEvent/);
});

test('outbox cleanup removes only old processed delivery receipts', async () => {
  let where: unknown;
  const scheduler = new OutboxCleanupScheduler({
    $transaction: async (operation: (client: unknown) => unknown) =>
      operation({
        $queryRaw: async () => [{ locked: true }],
        outboxEvent: {
          deleteMany: async (args: { where: unknown }) => {
            where = args.where;
            return { count: 3 };
          },
        },
      }),
  } as never);

  assert.equal(await scheduler.removeProcessedReceipts(), 3);
  assert.deepEqual((where as { status: string }).status, 'PROCESSED');
  assert.ok((where as { processedAt: { lt: unknown } }).processedAt.lt instanceof Date);
  assert.equal(JSON.stringify(where).includes('FAILED'), false);
});
