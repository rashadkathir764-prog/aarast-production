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

/**
 * D112 (Q-11), RA-BE-133: a new password ends every other session of the
 * account and keeps the caller's own, so its sockets are ended one session
 * at a time ([enqueueSessionRevoked]) and its phones' push registrations
 * here: every one made before now goes, except the caller's own phone's
 * ([keepInstallationFid]) when it named it.
 */
export async function enqueuePushInstallationsReleased(
  client: RevocationOutboxClient,
  userId: string,
  keepInstallationFid: string | null,
): Promise<void> {
  await client.outboxEvent.create({
    data: {
      type: OutboxEventTypes.pushInstallationsReleased,
      aggregateType: 'user',
      aggregateId: userId,
      payload: keepInstallationFid
        ? { userId, keepInstallationFid }
        : { userId },
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
