import { Injectable } from '@nestjs/common';
import { OutboxEvent, Prisma } from '@prisma/client';
import { ConversationRealtimePublisher } from '../conversations/conversation-realtime.publisher';
import { OutboxEventTypes } from './outbox.constants';

@Injectable()
export class OutboxDispatcher {
  constructor(private readonly realtime: ConversationRealtimePublisher) {}

  async dispatch(event: OutboxEvent): Promise<void> {
    const payload = jsonObject(event.payload);
    switch (event.type) {
      case OutboxEventTypes.conversationMessageAvailable: {
        const conversationId = requiredText(payload, 'conversationId');
        const messageId = requiredText(payload, 'messageId');
        this.realtime.messageAvailable(conversationId, {
          conversationId,
          messageId,
        });
        return;
      }
      case OutboxEventTypes.conversationActivityAvailable: {
        const conversationId = requiredText(payload, 'conversationId');
        const activityKind = requiredText(payload, 'activityKind');
        const activity = {
          conversationId,
          activityKind,
          ...(typeof payload.messageId === 'string'
            ? { messageId: payload.messageId }
            : {}),
          ...(typeof payload.eventId === 'string'
            ? { eventId: payload.eventId }
            : {}),
        };
        if (activityKind === 'EVENT') {
          this.realtime.event(conversationId, activity);
        }
        this.realtime.activityAvailable(conversationId, activity);
        return;
      }
      case OutboxEventTypes.notificationCreated: {
        const userId = requiredText(payload, 'userId');
        const notificationId = requiredText(payload, 'notificationId');
        this.realtime.notificationAvailable(userId, { notificationId });
        return;
      }
      default:
        throw new Error('UnsupportedOutboxEventType');
    }
  }
}

function jsonObject(value: Prisma.JsonValue): Prisma.JsonObject {
  if (value == null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error('InvalidOutboxPayload');
  }
  return value;
}

function requiredText(value: Prisma.JsonObject, key: string): string {
  const text = value[key];
  if (typeof text !== 'string' || text.trim().length === 0) {
    throw new Error('InvalidOutboxPayload');
  }
  return text.trim();
}
