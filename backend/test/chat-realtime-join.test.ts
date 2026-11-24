import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { ConversationScope, UserRole } from '@prisma/client';
import {
  REALTIME_JOINS_PER_MINUTE,
  REALTIME_READS_PER_MINUTE,
} from '../src/conversations/conversation-policy';
import { conversationsGateway, conversationsService } from './support/owner-ports';

// RA-BE-171: every `conversation:join` ran two serializable transactions
// with row locks, every reconnect re-joined every conversation, and
// neither `join` nor `read` had a rate limit.

const owner = { id: 'user-1', name: 'User One' };

const identity = (id: string, appRole = 'WEDDING_USER') => ({
  id,
  name: id,
  appName: null,
  role: UserRole.USER,
  avatarUrl: null,
  appAvatarUrl: null,
  appRole,
});

function participant(userId: string, revokedAt: Date | null = null) {
  const at = new Date('2026-11-01T10:00:00.000Z');
  return {
    id: `participant-${userId}`,
    conversationId: 'conversation-1',
    userId,
    joinedAt: at,
    revokedAt,
    lastReadAt: null,
    mutedAt: null,
    createdAt: at,
    updatedAt: at,
    user: identity(userId),
  };
}

function conversation(participants = [participant(owner.id), participant('provider-user')]) {
  const at = new Date('2026-11-01T10:00:00.000Z');
  return {
    id: 'conversation-1',
    scope: ConversationScope.PLAN,
    weddingPlanId: 'plan-1',
    accountRequesterUserId: null,
    providerId: 'provider-1',
    createdByUserId: owner.id,
    lastActivityAt: at,
    closedAt: null,
    customerSideBlockedAt: null,
    customerSideBlockedById: null,
    providerSideBlockedAt: null,
    createdAt: at,
    updatedAt: at,
    provider: {
      id: 'provider-1',
      userId: 'provider-user',
      businessName: 'Provider',
      logoUrl: null,
      status: 'ACTIVE',
      user: identity('provider-user', 'PROVIDER'),
    },
    weddingPlan: { id: 'plan-1', title: 'Plan', ownerUserId: owner.id, sharedMembers: [] },
    accountRequester: null,
    participants,
    quoteRequests: [],
    messages: [],
    _count: { quoteRequests: 0 },
  };
}

/** A client that answers reads and fails the test on any transaction, lock or write. */
function readOnlyClient(record: ReturnType<typeof conversation> | null) {
  const forbidden = (name: string) => async () => {
    throw new Error(`the join check must not call ${name}`);
  };
  let reads = 0;
  const prisma = {
    conversation: {
      findUnique: async () => {
        reads += 1;
        return record;
      },
    },
    conversationParticipant: {
      createMany: forbidden('conversationParticipant.createMany'),
      updateMany: forbidden('conversationParticipant.updateMany'),
    },
    $transaction: forbidden('$transaction'),
    $queryRaw: forbidden('$queryRaw'),
    $executeRaw: forbidden('$executeRaw'),
  };
  return { prisma, reads: () => reads };
}

function service(record: ReturnType<typeof conversation> | null) {
  const client = readOnlyClient(record);
  return {
    ...client,
    service: conversationsService(
      client.prisma,
      {},
      { revokeConversationAccess: forbiddenRealtime },
      {},
      {},
    ),
  };
}

function forbiddenRealtime(): never {
  throw new Error('the join check must not revoke anything');
}

test('RA-BE-171: the join check is one read, with no transaction, lock or write', async () => {
  const harness = service(conversation());

  assert.deepEqual(await harness.service.authorize(owner as never, 'conversation-1'), {
    conversationId: 'conversation-1',
  });
  assert.equal(harness.reads(), 1);
});

test('RA-BE-171: the read-only join check refuses who may not hear the room', async () => {
  await assert.rejects(
    service(null).service.authorize(owner as never, 'conversation-1'),
    NotFoundException,
  );
  await assert.rejects(
    service(conversation()).service.authorize(
      { id: 'stranger', name: 'Stranger' } as never,
      'conversation-1',
    ),
    NotFoundException,
  );
  await assert.rejects(
    service(
      conversation([
        participant(owner.id, new Date('2026-11-02T10:00:00.000Z')),
        participant('provider-user'),
      ]),
    ).service.authorize(owner as never, 'conversation-1'),
    NotFoundException,
    'a revoked participant does not join',
  );
});

function socket() {
  const rooms = new Set(['sock-1']);
  return {
    id: 'sock-1',
    data: {
      user: { id: owner.id, name: owner.name },
      sessionId: 'app-session',
    } as Record<string, unknown>,
    rooms,
    disconnected: 0,
    join: async (room: string) => {
      rooms.add(room);
    },
    leave: async (room: string) => {
      rooms.delete(room);
    },
    disconnect() {
      this.disconnected += 1;
    },
  };
}

function gateway() {
  const counts = { sessionReads: 0, authorize: 0, markRead: 0 };
  const instance = conversationsGateway(
    {},
    {
      refreshToken: {
        findFirst: async () => {
          counts.sessionReads += 1;
          return { id: 'app-session' };
        },
      },
    },
    {
      authorize: async (_user: unknown, conversationId: string) => {
        counts.authorize += 1;
        return { conversationId };
      },
      markRead: async (_user: unknown, conversationId: string) => {
        counts.markRead += 1;
        return { conversationId };
      },
    },
    { attach: () => undefined },
  );
  return { instance, counts };
}

test('RA-BE-171: a reconnect re-join of a room the socket holds checks nothing again', async () => {
  const { instance, counts } = gateway();
  const client = socket();

  await instance.join(client as never, { conversationId: 'conversation-1' });
  const checks = counts.authorize;
  const sessionReads = counts.sessionReads;
  const spent = (client.data.joinTimestamps as number[]).length;
  const rejoined = await instance.join(client as never, { conversationId: 'conversation-1' });

  assert.deepEqual(rejoined, { conversationId: 'conversation-1', joined: true });
  assert.equal(counts.authorize, checks, 'the held room needs no second access check');
  assert.equal(counts.sessionReads, sessionReads, 'nor a session read');
  assert.equal(
    (client.data.joinTimestamps as number[]).length,
    spent,
    'nor any of the join budget',
  );
});

test('RA-BE-171: joins are rate limited per socket, refused before any read', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: Date.parse('2026-11-24T10:00:00.000Z') });
  const { instance, counts } = gateway();
  const client = socket();

  for (let index = 0; index < REALTIME_JOINS_PER_MINUTE; index++) {
    await instance.join(client as never, { conversationId: `conversation-${index}` });
  }
  const sessionReads = counts.sessionReads;
  const checks = counts.authorize;
  await assert.rejects(
    instance.join(client as never, { conversationId: 'conversation-over' }),
    WsException,
  );
  assert.equal(counts.sessionReads, sessionReads, 'refused before the session read');
  assert.equal(counts.authorize, checks, 'refused before the access check');
  assert.equal(client.rooms.has('conversation:conversation-over'), false);

  // A room the socket already holds still answers once the budget is spent.
  assert.deepEqual(
    await instance.join(client as never, { conversationId: 'conversation-0' }),
    { conversationId: 'conversation-0', joined: true },
  );

  // Another socket of the same account keeps its own budget.
  await instance.join(socket() as never, { conversationId: 'conversation-over' });

  t.mock.timers.tick(60_000);
  await instance.join(client as never, { conversationId: 'conversation-over' });
  assert.equal(client.rooms.has('conversation:conversation-over'), true);
});

test('RA-BE-171: read receipts are rate limited per socket, refused before any read', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: Date.parse('2026-11-24T10:00:00.000Z') });
  const { instance, counts } = gateway();
  const client = socket();

  for (let index = 0; index < REALTIME_READS_PER_MINUTE; index++) {
    await instance.read(client as never, { conversationId: 'conversation-1' });
  }
  const sessionReads = counts.sessionReads;
  await assert.rejects(
    instance.read(client as never, { conversationId: 'conversation-1' }),
    WsException,
  );
  assert.equal(counts.sessionReads, sessionReads, 'refused before the session read');
  assert.equal(counts.markRead, REALTIME_READS_PER_MINUTE);

  t.mock.timers.tick(60_000);
  await instance.read(client as never, { conversationId: 'conversation-1' });
  assert.equal(counts.markRead, REALTIME_READS_PER_MINUTE + 1);
});
