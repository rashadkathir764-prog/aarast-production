import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { ConversationScope, UserRole } from '@prisma/client';
import { ConversationsService } from '../src/conversations/conversations.service';

const currentUser = { id: 'user-1', name: 'User One' };
const userIdentity = (id: string, name: string, appRole = 'WEDDING_USER') => ({
  id,
  name,
  appName: null,
  role: UserRole.USER,
  avatarUrl: null,
  appAvatarUrl: null,
  appRole,
});

function conversationRecord(
  id: string,
  lastActivityAt: Date,
  createdAt: Date,
  ownerUserId = currentUser.id,
) {
  const providerUserId = `provider-user-${id}`;
  return {
    id,
    scope: ConversationScope.PLAN,
    weddingPlanId: 'plan-1',
    accountRequesterUserId: null,
    providerId: `provider-${id}`,
    createdByUserId: ownerUserId,
    lastActivityAt,
    closedAt: null,
    customerSideBlockedAt: null,
    customerSideBlockedById: null,
    providerSideBlockedAt: null,
    createdAt,
    updatedAt: lastActivityAt,
    provider: {
      id: `provider-${id}`,
      userId: providerUserId,
      businessName: `Provider ${id}`,
      logoUrl: null,
      user: userIdentity(providerUserId, `Provider ${id}`, 'PROVIDER'),
    },
    weddingPlan: {
      id: 'plan-1',
      title: 'Plan',
      ownerUserId,
      sharedMembers: [],
    },
    accountRequester: null,
    participants: [
      {
        id: `participant-${id}-owner`,
        conversationId: id,
        userId: ownerUserId,
        joinedAt: createdAt,
        revokedAt: null,
        lastReadAt: null,
        mutedAt: null,
        createdAt,
        updatedAt: createdAt,
        user: userIdentity(ownerUserId, 'User One'),
      },
      {
        id: `participant-${id}-provider`,
        conversationId: id,
        userId: providerUserId,
        joinedAt: createdAt,
        revokedAt: null,
        lastReadAt: null,
        mutedAt: null,
        createdAt,
        updatedAt: createdAt,
        user: userIdentity(providerUserId, `Provider ${id}`, 'PROVIDER'),
      },
    ],
    quoteRequests: [],
    messages: [],
    _count: { quoteRequests: 2 },
  };
}

function compareConversations(
  left: ReturnType<typeof conversationRecord>,
  right: ReturnType<typeof conversationRecord>,
) {
  const activity = right.lastActivityAt.getTime() - left.lastActivityAt.getTime();
  if (activity !== 0) return activity;
  const created = right.createdAt.getTime() - left.createdAt.getTime();
  if (created !== 0) return created;
  return right.id.localeCompare(left.id);
}

function basePrisma(records: ReturnType<typeof conversationRecord>[]) {
  let candidateQueryCount = 0;
  let hydratedQueryCount = 0;
  let unreadAggregateCount = 0;
  let lastOrderBy: unknown;
  const prisma = {
    conversation: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        records.find((record) => record.id === where.id) ?? null,
      findUniqueOrThrow: async ({ where }: { where: { id: string } }) => {
        const record = records.find((candidate) => candidate.id === where.id);
        if (!record) throw new Error('missing');
        return record;
      },
      findFirst: async ({ where }: { where: Record<string, unknown> }) => {
        const id = JSON.stringify(where).match(/conversation-[a-z-]+/)?.[0];
        const record = records.find((candidate) => candidate.id === id);
        return record?.weddingPlan.ownerUserId === currentUser.id ? record : null;
      },
      findMany: async (args: Record<string, any>) => {
        if (args.select) {
          candidateQueryCount += 1;
          lastOrderBy = args.orderBy;
          const accessible = records
            .filter((record) => record.weddingPlan.ownerUserId === currentUser.id)
            .sort(compareConversations);
          const cursorIndex = args.cursor
            ? accessible.findIndex((record) => record.id === args.cursor.id)
            : -1;
          const start = args.cursor ? cursorIndex + (args.skip ?? 0) : 0;
          return accessible.slice(start, start + args.take).map((record) => ({
            id: record.id,
            provider: { userId: record.provider.userId },
          }));
        }
        hydratedQueryCount += 1;
        return records
          .filter((record) => args.where.id.in.includes(record.id))
          .sort(compareConversations);
      },
    },
    conversationParticipant: {
      updateMany: async () => ({ count: 1 }),
      createMany: async () => ({ count: 0 }),
    },
    $transaction: async (operations: Array<Promise<unknown>>) => Promise.all(operations),
    $queryRaw: async () => {
      unreadAggregateCount += 1;
      return [];
    },
  };
  return {
    prisma,
    candidateQueryCount: () => candidateQueryCount,
    hydratedQueryCount: () => hydratedQueryCount,
    unreadAggregateCount: () => unreadAggregateCount,
    lastOrderBy: () => lastOrderBy,
  };
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
    conversationRecord(
      'conversation-older',
      new Date('2026-07-11T10:00:00.000Z'),
      new Date('2026-07-11T07:00:00.000Z'),
    ),
    conversationRecord(
      'conversation-foreign',
      new Date('2026-07-11T14:00:00.000Z'),
      new Date('2026-07-11T14:00:00.000Z'),
      'foreign-user',
    ),
  ];
  const harness = basePrisma(records);
  return {
    ...harness,
    service: new ConversationsService(
      harness.prisma as never,
      {} as never,
      { revokeConversationAccess() {} } as never,
      {} as never,
      {} as never,
    ),
  };
}

function messageRecord(id: string, createdAt: Date, conversationId = 'chat-1') {
  return {
    id,
    conversationId,
    senderUserId: 'provider-user-chat-1',
    body: id,
    editedAt: null,
    deletedAt: null,
    createdAt,
    updatedAt: createdAt,
    sender: userIdentity('provider-user-chat-1', 'Provider'),
    attachments: [],
  };
}

function messageHarness() {
  const accessConversation = conversationRecord(
    'chat-1',
    new Date('2026-07-11T12:06:00.000Z'),
    new Date('2026-07-11T12:00:00.000Z'),
  );
  accessConversation.provider.userId = 'provider-user-chat-1';
  accessConversation.provider.user = userIdentity('provider-user-chat-1', 'Provider');
  accessConversation.participants[1]!.userId = 'provider-user-chat-1';
  const messages = [
    messageRecord('message-6', new Date('2026-07-11T12:06:00.000Z')),
    messageRecord('message-5', new Date('2026-07-11T12:05:00.000Z')),
    messageRecord('message-4', new Date('2026-07-11T12:04:00.000Z')),
    messageRecord('message-3', new Date('2026-07-11T12:03:00.000Z')),
    messageRecord('message-2', new Date('2026-07-11T12:02:00.000Z')),
    messageRecord('message-1', new Date('2026-07-11T12:01:00.000Z')),
    messageRecord('message-foreign', new Date('2026-07-11T12:07:00.000Z'), 'chat-2'),
  ];
  let messageQueryCount = 0;
  const prisma = {
    conversation: {
      findUnique: async () => accessConversation,
      findUniqueOrThrow: async () => accessConversation,
    },
    conversationParticipant: {
      updateMany: async () => ({ count: 1 }),
      createMany: async () => ({ count: 0 }),
    },
    $transaction: async (operations: Array<Promise<unknown>>) => Promise.all(operations),
    chatMessage: {
      findFirst: async ({ where }: { where: Record<string, any> }) =>
        messages.find(
          (message) =>
            message.id === where.id &&
            message.conversationId === where.conversationId &&
            message.deletedAt === where.deletedAt,
        ) ?? null,
      findMany: async ({ where, take, cursor, skip = 0 }: Record<string, any>) => {
        messageQueryCount += 1;
        const sorted = messages
          .filter(
            (message) =>
              message.conversationId === where.conversationId &&
              message.deletedAt === where.deletedAt,
          )
          .sort((left, right) => {
            const created = right.createdAt.getTime() - left.createdAt.getTime();
            return created !== 0 ? created : right.id.localeCompare(left.id);
          });
        const cursorIndex = cursor
          ? sorted.findIndex((message) => message.id === cursor.id)
          : -1;
        const start = cursor ? cursorIndex + skip : 0;
        return sorted.slice(start, start + take);
      },
    },
  };
  return {
    service: new ConversationsService(
      prisma as never,
      {} as never,
      { revokeConversationAccess() {} } as never,
      {} as never,
      {} as never,
    ),
    messageQueryCount: () => messageQueryCount,
  };
}

test('conversation inbox returns ordered cursor pages without duplicate plan/provider rows', async () => {
  const harness = conversationHarness();
  const first = await harness.service.list(currentUser as never, undefined, '2');
  const second = await harness.service.list(currentUser as never, first.nextCursor ?? undefined, '2');
  assert.deepEqual(first.items.map((item) => item.id), [
    'conversation-newest',
    'conversation-tie-b',
  ]);
  assert.deepEqual(second.items.map((item) => item.id), [
    'conversation-tie-a',
    'conversation-older',
  ]);
  assert.equal(new Set([...first.items, ...second.items].map((item) => item.id)).size, 4);
  assert.deepEqual(harness.lastOrderBy(), [
    { lastActivityAt: 'desc' },
    { createdAt: 'desc' },
    { id: 'desc' },
  ]);
  assert.equal(harness.candidateQueryCount(), 2);
  assert.equal(harness.hydratedQueryCount(), 2);
  assert.equal(harness.unreadAggregateCount(), 2, 'one unread aggregate per inbox page');
});

test('conversation detail hydrates an authorized plan owner and provider summary', async () => {
  const harness = conversationHarness();
  const conversation = await harness.service.get(currentUser as never, 'conversation-newest');
  assert.equal(conversation.scope, ConversationScope.PLAN);
  assert.equal(conversation.quoteRequestCount, 2);
  assert.equal(conversation.provider.businessName, 'Provider conversation-newest');
  assert.equal(conversation.permissions.canManageProviders, true);
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
  assert.equal(harness.candidateQueryCount(), 0);
});

test('message history returns chronological cursor pages without duplicates', async () => {
  const harness = messageHarness();
  const first = await harness.service.messages(currentUser as never, 'chat-1', undefined, '2');
  const second = await harness.service.messages(
    currentUser as never,
    'chat-1',
    first.nextCursor ?? undefined,
    '2',
  );
  assert.deepEqual(first.items.map((item) => item.id), ['message-5', 'message-6']);
  assert.deepEqual(second.items.map((item) => item.id), ['message-3', 'message-4']);
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
  assert.equal(harness.messageQueryCount(), 0);
});
