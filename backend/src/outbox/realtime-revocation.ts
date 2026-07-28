import { Prisma } from '@prisma/client';
import { OutboxEventTypes } from './outbox.constants';

type RevocationOutboxClient = Pick<Prisma.TransactionClient, 'outboxEvent'>;

export async function enqueueConversationAccessRevoked(
  client: RevocationOutboxClient,
  userId: string,
  conversationIds: readonly string[],
): Promise<void> {
  const ids = [...new Set(conversationIds)].sort();
  if (ids.length === 0) return;
  await client.outboxEvent.create({
    data: {
      type: OutboxEventTypes.conversationAccessRevoked,
      aggregateType: 'user',
      aggregateId: userId,
      payload: { userId, conversationIds: ids },
    },
  });
}

export async function enqueueUserSessionsRevoked(
  client: RevocationOutboxClient,
  userId: string,
): Promise<void> {
  await client.outboxEvent.create({
    data: {
      type: OutboxEventTypes.userSessionsRevoked,
      aggregateType: 'user',
      aggregateId: userId,
      payload: { userId },
    },
  });
}

export async function enqueueSessionRevoked(
  client: RevocationOutboxClient,
  sessionId: string,
): Promise<void> {
  await client.outboxEvent.create({
    data: {
      type: OutboxEventTypes.sessionRevoked,
      aggregateType: 'session',
      aggregateId: sessionId,
      payload: { sessionId },
    },
  });
}
