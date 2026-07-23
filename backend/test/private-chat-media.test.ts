import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotFoundException } from '@nestjs/common';
import { ConversationScope, UserRole } from '@prisma/client';
import { ConversationsService } from '../src/conversations/conversations.service';

const identity = (id: string, name: string) => ({
  id,
  name,
  appName: null,
  role: UserRole.USER,
  avatarUrl: null,
  appAvatarUrl: null,
  appRole: 'WEDDING_USER',
});

const createdAt = new Date('2026-07-10T12:00:00.000Z');
const conversation = {
  id: 'conversation-1',
  scope: ConversationScope.ACCOUNT,
  weddingPlanId: null,
  accountRequesterUserId: 'requester-1',
  providerId: 'provider-ref-1',
  createdByUserId: 'requester-1',
  lastActivityAt: createdAt,
  closedAt: null,
  customerSideBlockedAt: null,
  customerSideBlockedById: null,
  providerSideBlockedAt: null,
  createdAt,
  updatedAt: createdAt,
  provider: {
    id: 'provider-ref-1',
    userId: 'provider-1',
    businessName: 'Provider',
    logoUrl: null,
    user: identity('provider-1', 'Provider'),
  },
  weddingPlan: null,
  accountRequester: identity('requester-1', 'Requester'),
  participants: [
    {
      id: 'participant-requester',
      conversationId: 'conversation-1',
      userId: 'requester-1',
      joinedAt: createdAt,
      revokedAt: null,
      lastReadAt: null,
      mutedAt: null,
      createdAt,
      updatedAt: createdAt,
      user: identity('requester-1', 'Requester'),
    },
    {
      id: 'participant-provider',
      conversationId: 'conversation-1',
      userId: 'provider-1',
      joinedAt: createdAt,
      revokedAt: null,
      lastReadAt: null,
      mutedAt: null,
      createdAt,
      updatedAt: createdAt,
      user: identity('provider-1', 'Provider'),
    },
  ],
  quoteRequests: [],
  messages: [],
  _count: { quoteRequests: 1 },
};

function serviceFor(userCanReadAttachment = true) {
  let signedCount = 0;
  let messageQueryCount = 0;
  let revokedCount = 0;
  const prisma = {
    conversation: {
      findUnique: async () => conversation,
      findUniqueOrThrow: async () => conversation,
    },
    conversationParticipant: {
      updateMany: async ({ data }: { data: { revokedAt?: Date | null } }) => {
        if (data.revokedAt) revokedCount += 1;
        return { count: 1 };
      },
      createMany: async () => ({ count: 0 }),
    },
    $transaction: async (operations: Array<Promise<unknown>>) => Promise.all(operations),
    chatAttachment: {
      findFirst: async () =>
        userCanReadAttachment
          ? { storageKey: 'chat-image/requester-1/private.webp' }
          : null,
    },
    chatMessage: {
      findMany: async () => {
        messageQueryCount += 1;
        return [
          {
            id: 'message-1',
            conversationId: 'conversation-1',
            senderUserId: 'requester-1',
            body: 'private',
            editedAt: null,
            deletedAt: null,
            createdAt,
            updatedAt: createdAt,
            sender: identity('requester-1', 'Requester'),
            attachments: [
              {
                id: 'attachment-1',
                storageKey: 'chat-image/requester-1/private.webp',
                contentType: 'image/webp',
                byteSize: 100,
                createdAt,
              },
            ],
          },
        ];
      },
    },
  };
  const media = {
    createDownloadUrl: async () => {
      signedCount += 1;
      return {
        downloadUrl: 'https://storage.example.test/private?X-Amz-Expires=120',
        expiresInSeconds: 120,
        expiresAt: new Date('2026-07-10T12:02:00.000Z'),
      };
    },
  };
  return {
    service: new ConversationsService(
      prisma as never,
      {} as never,
      { revokeConversationAccess() {} } as never,
      media as never,
      {} as never,
    ),
    signedCount: () => signedCount,
    messageQueryCount: () => messageQueryCount,
    revokedCount: () => revokedCount,
  };
}

test('a non-participant receives 404 and cannot mint or enumerate private chat media links', async () => {
  const harness = serviceFor();
  await assert.rejects(
    harness.service.downloadAttachment(
      { id: 'stranger-1' } as never,
      'conversation-1',
      'attachment-1',
    ),
    NotFoundException,
  );
  await assert.rejects(
    harness.service.messages({ id: 'stranger-1' } as never, 'conversation-1'),
    NotFoundException,
  );
  assert.equal(harness.signedCount(), 0);
  assert.equal(harness.messageQueryCount(), 0);
  assert.equal(harness.revokedCount(), 2);
});

test('an authorized participant receives only a short-lived URL, never storageKey', async () => {
  const harness = serviceFor();
  const page = await harness.service.messages(
    { id: 'requester-1' } as never,
    'conversation-1',
  );
  const attachment = page.items[0]?.attachments[0];
  assert.equal(attachment?.url.includes('X-Amz-Expires=120'), true);
  assert.equal('storageKey' in (attachment ?? {}), false);
  assert.equal(harness.signedCount(), 1);

  const refreshed = await harness.service.downloadAttachment(
    { id: 'requester-1' } as never,
    'conversation-1',
    'attachment-1',
  );
  assert.equal(refreshed.expiresInSeconds, 120);
  assert.equal(harness.signedCount(), 2);
});
