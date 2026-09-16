import type { Prisma } from '@prisma/client';

// Platform owns `OutboxEvent`. Account erasure removes the pending events
// of the notifications and conversations it deletes; the statement runs here.
export async function purgeOutboxEventsForAggregatesInTransaction(
  tx: Prisma.TransactionClient,
  aggregates: {
    notificationIds: readonly string[];
    conversationIds: readonly string[];
  },
): Promise<void> {
  if (
    aggregates.notificationIds.length === 0
    && aggregates.conversationIds.length === 0
  ) {
    return;
  }
  await tx.outboxEvent.deleteMany({
    where: {
      OR: [
        ...(aggregates.notificationIds.length > 0
          ? [
              {
                aggregateType: 'notification',
                aggregateId: { in: [...aggregates.notificationIds] },
              },
            ]
          : []),
        ...(aggregates.conversationIds.length > 0
          ? [
              {
                aggregateType: 'conversation',
                aggregateId: { in: [...aggregates.conversationIds] },
              },
            ]
          : []),
      ],
    },
  });
}
