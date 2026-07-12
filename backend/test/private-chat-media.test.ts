import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ForbiddenException } from '@nestjs/common';
import { ConversationsService } from '../src/conversations/conversations.service';

const conversation = {
  id: 'conversation-1',
  closedAt: null,
  quoteRequestId: 'quote-1',
  quoteRequest: {
    userId: 'requester-1',
    provider: { userId: 'provider-1' },
  },
  participants: [
    { userId: 'requester-1', blockedAt: null },
    { userId: 'provider-1', blockedAt: null },
  ],
};

function serviceFor(userCanReadAttachment = true) {
  let signedCount = 0;
  let messageQueryCount = 0;
  const prisma = {
    conversation: { findUnique: async () => conversation },
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
            createdAt: new Date('2026-07-10T12:00:00.000Z'),
            sender: { id: 'requester-1', name: 'Requester', avatarUrl: null },
            attachments: [
              {
                id: 'attachment-1',
                storageKey: 'chat-image/requester-1/private.webp',
                contentType: 'image/webp',
                byteSize: 100,
                createdAt: new Date('2026-07-10T12:00:00.000Z'),
              },
            ],
          },
        ];
      },
    },
  };
  const media = {
    verifyUpload: async (_current: unknown, key: string) => ({
      key,
      contentType: 'image/webp',
      byteSize: 128,
    }),
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
      {} as never,
      media as never,
      {} as never,
    ),
    signedCount: () => signedCount,
    messageQueryCount: () => messageQueryCount,
  };
}

test('a non-participant cannot mint or enumerate private chat media links', async () => {
  const harness = serviceFor();
  await assert.rejects(
    harness.service.downloadAttachment(
      { id: 'stranger-1' } as never,
      'conversation-1',
      'attachment-1',
    ),
    ForbiddenException,
  );
  await assert.rejects(
    harness.service.messages({ id: 'stranger-1' } as never, 'conversation-1'),
    ForbiddenException,
  );
  assert.equal(harness.signedCount(), 0);
  assert.equal(harness.messageQueryCount(), 0);
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
