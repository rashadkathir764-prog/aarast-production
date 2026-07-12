import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { ConversationsService } from '../src/conversations/conversations.service';

const currentUser = {
  id: 'user-1',
  name: 'User One',
};

function conversationRecord(
  id: string,
  lastMessageAt: Date | null,
  createdAt: Date,
  participantUserId = currentUser.id,
) {
  return {
    id,
    quoteRequestId: `quote-${id}`,
    quoteRequest: {
      id: `quote-${id}`,
      userId: participantUserId,
      weddingPlanId: 'plan-1',
      provider: {
        id: `provider-${id}`,
        userId: `provider-user-${id}`,
        businessName: `Provider ${id}`,
        logoUrl: null,
      },
      service: null,
      weddingPlan: { id: 'plan-1', title: 'Plan' },
      user: { id: participantUserId, name: 'User One', avatarUrl: null },
    },
    participants: [
      {
        userId: participantUserId,
        lastReadAt: null,
        mutedAt: null,
        blockedAt: null,
        user: {
          id: participantUserId,
          name: 'User One',
          avatarUrl: null,
          appRole: 'USER',
        },
      },
      {
        userId: `provider-user-${id}`,
        lastReadAt: null,
        mutedAt: null,
        blockedAt: null,
        user: {
          id: `provider-user-${id}`,
          name: `Provider ${id}`,
          avatarUrl: null,
          appRole: 'PROVIDER',
        },
      },
    ],
    messages: [],
    lastMessageAt,
    closedAt: null,
    createdAt,
    updatedAt: lastMessageAt ?? createdAt,
  };
}

function compareConversations(
  left: ReturnType<typeof conversationRecord>,
  right: ReturnType<typeof conversationRecord>,
) {
  if (left.lastMessageAt && !right.lastMessageAt) return -1;
  if (!left.lastMessageAt && right.lastMessageAt) return 1;
  const activityOrder =
    (right.lastMessageAt?.getTime() ?? 0) - (left.lastMessageAt?.getTime() ?? 0);
  if (activityOrder !== 0) return activityOrder;
  const createdOrder = right.createdAt.getTime() - left.createdAt.getTime();
  if (createdOrder !== 0) return createdOrder;
  return right.id.localeCompare(left.id);
}

function conversationHarness() {
  const records = [
    conversationRecord(
      'conversation-newest',
      new Date('2026-07-11T12:00:00.000Z'),
      new Date('2026-07-11T09:00:00.000Z'),
    ),
    conversationRecord(
      'conversation-tie-b',
      new Date('2026-07-11T11:00:00.000Z'),
      new Date('2026-07-11T08:00:00.000Z'),
    ),
    conversationRecord(
      'conversation-tie-a',
      new Date('2026-07-11T11:00:00.000Z'),
      new Date('2026-07-11T08:00:00.000Z'),
    ),
    conversationRecord('conversation-empty-new', null, new Date('2026-07-11T13:00:00.000Z')),
    conversationRecord('conversation-empty-old', null, new Date('2026-07-11T10:00:00.000Z')),
    conversationRecord(
      'conversation-foreign',
      new Date('2026-07-11T14:00:00.000Z'),
      new Date('2026-07-11T14:00:00.000Z'),
      'foreign-user',
    ),
  ];
  let listQueryCount = 0;
  let lastOrderBy: unknown;
  const prisma = {
    conversation: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        records.find((record) => record.id === where.id) ?? null,
      findFirst: async ({ where }: { where: Record<string, any> }) =>
        records.find(
          (record) =>
            record.id === where.id &&
            record.participants.some(
              (participant) => participant.userId === where.participants.some.userId,
            ),
        ) ?? null,
      findMany: async ({ where, orderBy, take, cursor, skip = 0 }: Record<string, any>) => {
        listQueryCount += 1;
        lastOrderBy = orderBy;
        const sorted = records
          .filter((record) =>
            record.participants.some(
              (participant) => participant.userId === where.participants.some.userId,
            ),
          )
          .sort(compareConversations);
        const cursorIndex = cursor ? sorted.findIndex((record) => record.id === cursor.id) : -1;
        const start = cursor ? cursorIndex + skip : 0;
        return sorted.slice(start, start + take);
      },
    },
    chatMessage: { count: async () => 0 },
  };
  return {
    service: new ConversationsService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    ),
    listQueryCount: () => listQueryCount,
    lastOrderBy: () => lastOrderBy,
  };
}

function messageRecord(id: string, createdAt: Date, conversationId = 'chat-1') {
  return {
    id,
    conversationId,
    senderUserId: 'provider-user-1',
    body: id,
    deletedAt: null,
    createdAt,
    sender: { id: 'provider-user-1', name: 'Provider', avatarUrl: null },
    attachments: [],
  };
}

function messageHarness() {
  const accessConversation = {
    id: 'chat-1',
    quoteRequestId: 'quote-1',
    closedAt: null,
    quoteRequest: {
      userId: currentUser.id,
      provider: { userId: 'provider-user-1' },
    },
    participants: [
      { userId: currentUser.id, blockedAt: null },
      { userId: 'provider-user-1', blockedAt: null },
    ],
  };
  const messages = [
    messageRecord('message-6', new Date('2026-07-11T12:06:00.000Z')),
    messageRecord('message-5', new Date('2026-07-11T12:05:00.000Z')),
    messageRecord('message-4', new Date('2026-07-11T12:04:00.000Z')),
    messageRecord('message-3', new Date('2026-07-11T12:03:00.000Z')),
    messageRecord('message-2', new Date('2026-07-11T12:02:00.000Z')),
    messageRecord('message-1', new Date('2026-07-11T12:01:00.000Z')),
    messageRecord('message-foreign', new Date('2026-07-11T12:07:00.000Z'), 'chat-2'),
  ];
  let listQueryCount = 0;
  const prisma = {
    conversation: { findUnique: async () => accessConversation },
    chatMessage: {
      findFirst: async ({ where }: { where: Record<string, any> }) =>
        messages.find(
          (message) =>
            message.id === where.id &&
            message.conversationId === where.conversationId &&
            message.deletedAt === where.deletedAt,
        ) ?? null,
      findMany: async ({ where, take, cursor, skip = 0 }: Record<string, any>) => {
        listQueryCount += 1;
        const sorted = messages
          .filter(
            (message) =>
              message.conversationId === where.conversationId &&
              message.deletedAt === where.deletedAt,
          )
          .sort((left, right) => {
            const createdOrder = right.createdAt.getTime() - left.createdAt.getTime();
            return createdOrder !== 0 ? createdOrder : right.id.localeCompare(left.id);
          });
        const cursorIndex = cursor ? sorted.findIndex((message) => message.id === cursor.id) : -1;
        const start = cursor ? cursorIndex + skip : 0;
        return sorted.slice(start, start + take);
      },
    },
  };
  return {
    service: new ConversationsService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    ),
    listQueryCount: () => listQueryCount,
  };
}

test('conversation inbox returns two ordered cursor pages without duplicates', async () => {
  const harness = conversationHarness();
  const first = await harness.service.list(currentUser as never, undefined, '2');
  const second = await harness.service.list(
    currentUser as never,
    first.nextCursor ?? undefined,
    '2',
  );

  assert.deepEqual(
    first.items.map((item) => item.id),
    ['conversation-newest', 'conversation-tie-b'],
  );
  assert.equal(first.nextCursor, 'conversation-tie-b');
  assert.deepEqual(
    second.items.map((item) => item.id),
    ['conversation-tie-a', 'conversation-empty-new'],
  );
  assert.equal(second.nextCursor, 'conversation-empty-new');
  assert.equal(new Set([...first.items, ...second.items].map((item) => item.id)).size, 4);
  assert.deepEqual(harness.lastOrderBy(), [
    { lastMessageAt: { sort: 'desc', nulls: 'last' } },
    { createdAt: 'desc' },
    { id: 'desc' },
  ]);
});

test('conversation detail hydrates one authorized direct route', async () => {
  const harness = conversationHarness();

  const conversation = await harness.service.get(currentUser as never, 'conversation-newest');

  assert.equal(conversation.id, 'conversation-newest');
  assert.ok(conversation.counterpart);
  assert.equal(conversation.counterpart.id, 'provider-user-conversation-newest');
});

test('conversation inbox rejects missing and foreign cursors before listing', async () => {
  const harness = conversationHarness();
  await assert.rejects(
    harness.service.list(currentUser as never, 'conversation-missing', '2'),
    BadRequestException,
  );
  await assert.rejects(
    harness.service.list(currentUser as never, 'conversation-foreign', '2'),
    BadRequestException,
  );
  assert.equal(harness.listQueryCount(), 0);
});

test('message history returns two chronological cursor pages without duplicates', async () => {
  const harness = messageHarness();
  const first = await harness.service.messages(currentUser as never, 'chat-1', undefined, '2');
  const second = await harness.service.messages(
    currentUser as never,
    'chat-1',
    first.nextCursor ?? undefined,
    '2',
  );

  assert.deepEqual(
    first.items.map((item) => item.id),
    ['message-5', 'message-6'],
  );
  assert.equal(first.nextCursor, 'message-5');
  assert.deepEqual(
    second.items.map((item) => item.id),
    ['message-3', 'message-4'],
  );
  assert.equal(second.nextCursor, 'message-3');
  assert.deepEqual(
    [...second.items, ...first.items].map((item) => item.id),
    ['message-3', 'message-4', 'message-5', 'message-6'],
  );
  assert.equal(new Set([...first.items, ...second.items].map((item) => item.id)).size, 4);
});

test('message history rejects missing and cross-conversation cursors', async () => {
  const harness = messageHarness();
  await assert.rejects(
    harness.service.messages(currentUser as never, 'chat-1', 'message-missing', '2'),
    BadRequestException,
  );
  await assert.rejects(
    harness.service.messages(currentUser as never, 'chat-1', 'message-foreign', '2'),
    BadRequestException,
  );
  assert.equal(harness.listQueryCount(), 0);
});
