import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { OutboxEventType } from './outbox.constants';

type OutboxClient = Pick<Prisma.TransactionClient, 'outboxEvent'>;

export interface EnqueueOutboxEvent {
  type: OutboxEventType;
  aggregateType?: string;
  aggregateId?: string;
  payload: Prisma.InputJsonObject;
}

// Platform owns `OutboxEvent`; the enqueue statement lives here for the
// injectable service and for the plain-function lifecycle helpers alike.
export async function enqueueOutboxEventInTransaction(
  client: OutboxClient,
  event: EnqueueOutboxEvent,
): Promise<void> {
  await client.outboxEvent.create({
    data: {
      type: event.type,
      aggregateType: event.aggregateType ?? null,
      aggregateId: event.aggregateId ?? null,
      payload: event.payload,
    },
  });
}

@Injectable()
export class OutboxService {
  async enqueue(
    client: OutboxClient,
    event: EnqueueOutboxEvent,
  ): Promise<void> {
    await enqueueOutboxEventInTransaction(client, event);
  }
}
