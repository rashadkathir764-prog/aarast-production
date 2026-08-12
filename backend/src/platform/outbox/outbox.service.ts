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

@Injectable()
export class OutboxService {
  async enqueue(
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
}
