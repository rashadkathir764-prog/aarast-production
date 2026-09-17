import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import type { Prisma } from '@prisma/client';
import {
  MESSAGING_ERASURE_IMPLEMENTATION,
  MESSAGING_PARTICIPATION_IMPLEMENTATION,
  MessagingPortsInternalModule,
} from '../src/modules/messaging/internal/messaging-ports.internal.module';
import { MessagingErasureService } from '../src/modules/messaging/internal/messaging-erasure.service';
import { MessagingParticipationService } from '../src/modules/messaging/internal/messaging-participation.service';
import { MessagingParticipationPublicModule } from '../src/modules/messaging/public/messaging-participation-public.module';
import { MESSAGING_PARTICIPATION_PORT } from '../src/modules/messaging/public/messaging-participation.port';

// Collaboration used to grant and revoke a member's provider-conversation
// participation by querying messaging's conversation tables and joining the
// provider and plan rows itself. That is messaging's decision now: it reads
// its own conversations, asks marketplace and planning for the provider
// accounts and the plan owner, and never touches the conversations of the
// provider the member owns or of the plan the member owns.

const conversations = [
  { id: 'conversation-1', providerId: 'provider-1' },
  { id: 'conversation-2', providerId: 'provider-2' },
];

function harness(rows: Array<{ id: string; providerId: string }>) {
  const calls: Array<[string, unknown]> = [];
  const tx = {
    conversation: {
      findMany: async (args: unknown) => { calls.push(['conversation.findMany', args]); return rows; },
    },
    conversationParticipant: {
      updateMany: async (args: unknown) => { calls.push(['participant.updateMany', args]); return { count: rows.length }; },
      createMany: async (args: unknown) => { calls.push(['participant.createMany', args]); return { count: rows.length }; },
    },
  } as unknown as Prisma.TransactionClient;
  const providers = {
    getProviders: async (client: unknown, ids: readonly string[]) => {
      assert.equal(client, tx);
      calls.push(['providers.getProviders', [...ids]]);
      return [
        { id: 'provider-1', userId: 'provider-user-1' },
        { id: 'provider-2', userId: 'provider-user-2' },
      ];
    },
  };
  const plans = {
    getPlan: async (client: unknown, id: string) => {
      assert.equal(client, tx);
      calls.push(['plans.getPlan', id]);
      return { id, ownerUserId: 'owner-1' };
    },
  };
  const service = new MessagingParticipationService(providers as any, plans as any);
  return { tx, calls, service };
}

test('granting participation restores and creates the member rows for every plan conversation without reading the owners', async () => {
  const { tx, calls, service } = harness(conversations);

  const changed = await service.setPlanConversationParticipationInTransaction(tx, 'plan-1', 'member-1', true);

  assert.deepEqual(changed, ['conversation-1', 'conversation-2']);
  assert.deepEqual(calls, [
    ['conversation.findMany', { where: { weddingPlanId: 'plan-1' }, select: { id: true, providerId: true } }],
    ['participant.updateMany', {
      where: { userId: 'member-1', conversationId: { in: ['conversation-1', 'conversation-2'] } },
      data: { revokedAt: null },
    }],
    ['participant.createMany', {
      data: [
        { conversationId: 'conversation-1', userId: 'member-1' },
        { conversationId: 'conversation-2', userId: 'member-1' },
      ],
      skipDuplicates: true,
    }],
  ]);
});

test('revoking participation skips the conversations of the provider the member owns', async () => {
  const { tx, calls, service } = harness(conversations);

  const changed = await service.setPlanConversationParticipationInTransaction(tx, 'plan-1', 'provider-user-2', false);

  assert.deepEqual(changed, ['conversation-1']);
  assert.deepEqual(calls.slice(1, 3), [
    ['providers.getProviders', ['provider-1', 'provider-2']],
    ['plans.getPlan', 'plan-1'],
  ]);
  const [, revoke] = calls[3] as [string, { where: Record<string, unknown>; data: { revokedAt: Date } }];
  assert.deepEqual(revoke.where, {
    userId: 'provider-user-2',
    conversationId: { in: ['conversation-1'] },
    revokedAt: null,
  });
  assert.ok(revoke.data.revokedAt instanceof Date);
  assert.equal(calls.length, 4);
});

test('revoking participation never touches the conversations of the plan the member owns', async () => {
  const { tx, calls, service } = harness(conversations);

  const changed = await service.setPlanConversationParticipationInTransaction(tx, 'plan-1', 'owner-1', false);

  assert.deepEqual(changed, []);
  assert.deepEqual(calls.map(([name]) => name), [
    'conversation.findMany',
    'providers.getProviders',
    'plans.getPlan',
  ]);
});

test('a plan without conversations changes nothing and reads no owner row', async () => {
  const { tx, calls, service } = harness([]);

  assert.deepEqual(await service.setPlanConversationParticipationInTransaction(tx, 'plan-1', 'member-1', false), []);
  assert.deepEqual(await service.setPlanConversationParticipationInTransaction(tx, 'plan-1', 'member-1', true), []);
  assert.deepEqual(calls.map(([name]) => name), ['conversation.findMany', 'conversation.findMany']);
});

test('the messaging participation public module exposes only its port token bound to the internal implementation', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(MessagingParticipationPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: MESSAGING_PARTICIPATION_PORT, useExisting: MESSAGING_PARTICIPATION_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(MessagingParticipationPublicModule, MODULE_METADATA.EXPORTS), [MESSAGING_PARTICIPATION_PORT]);
  assert.deepEqual(metadata(MessagingPortsInternalModule, MODULE_METADATA.PROVIDERS), [
    MessagingErasureService,
    MessagingParticipationService,
    { provide: MESSAGING_ERASURE_IMPLEMENTATION, useExisting: MessagingErasureService },
    { provide: MESSAGING_PARTICIPATION_IMPLEMENTATION, useExisting: MessagingParticipationService },
  ]);
});
