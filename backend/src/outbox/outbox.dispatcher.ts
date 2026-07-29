import { Injectable, Optional } from "@nestjs/common";
import { OutboxEvent, Prisma } from "@prisma/client";
import { ConversationRealtimePublisher } from "../conversations/conversation-realtime.publisher";
import { PushDeliveryService } from "../push/push-delivery.service";
import { OutboxEventTypes } from "./outbox.constants";

@Injectable()
export class OutboxDispatcher {
  constructor(
    private readonly realtime: ConversationRealtimePublisher,
    @Optional() private readonly pushDelivery?: PushDeliveryService,
  ) {}

  async dispatch(event: OutboxEvent): Promise<void> {
    const payload = jsonObject(event.payload);
    switch (event.type) {
      case OutboxEventTypes.conversationMessageAvailable: {
        const conversationId = requiredText(payload, "conversationId");
        const messageId = requiredText(payload, "messageId");
        await this.realtime.dispatchMessageAvailable(conversationId, {
          conversationId,
          messageId,
        });
        return;
      }
      case OutboxEventTypes.conversationActivityAvailable: {
        const conversationId = requiredText(payload, "conversationId");
        const activityKind = requiredText(payload, "activityKind");
        const activity = {
          conversationId,
          activityKind,
          ...(typeof payload.messageId === "string"
            ? { messageId: payload.messageId }
            : {}),
          ...(typeof payload.eventId === "string"
            ? { eventId: payload.eventId }
            : {}),
        };
        await this.realtime.dispatchActivityAvailable(
          conversationId,
          activity,
          activityKind === "EVENT",
        );
        return;
      }
      case OutboxEventTypes.notificationCreated: {
        const userId = requiredText(payload, "userId");
        const notificationId = requiredText(payload, "notificationId");
        await this.realtime.dispatchNotificationAvailable(userId, {
          notificationId,
        });
        return;
      }
      case OutboxEventTypes.pushNotificationRequested: {
        const notificationId = requiredText(payload, "notificationId");
        if (!this.pushDelivery) {
          const error = new Error("PushDeliveryUnavailable");
          error.name = "PushDeliveryUnavailable";
          throw error;
        }
        await this.pushDelivery.dispatchNotification(notificationId);
        return;
      }
      case OutboxEventTypes.conversationAccessRevoked: {
        const userId = requiredText(payload, "userId");
        const conversationIds = requiredTextArray(payload, "conversationIds");
        await this.realtime.dispatchConversationAccessRevoked(
          userId,
          conversationIds,
        );
        return;
      }
      case OutboxEventTypes.userSessionsRevoked: {
        await this.realtime.dispatchUserSessionsRevoked(
          requiredText(payload, "userId"),
        );
        return;
      }
      case OutboxEventTypes.sessionRevoked: {
        await this.realtime.dispatchSessionRevoked(
          requiredText(payload, "sessionId"),
        );
        return;
      }
      default:
        throw new Error("UnsupportedOutboxEventType");
    }
  }
}

function requiredTextArray(value: Prisma.JsonObject, key: string): string[] {
  const values = value[key];
  if (
    !Array.isArray(values) ||
    values.length === 0 ||
    values.some((item) => typeof item !== "string" || item.trim().length === 0)
  ) {
    throw new Error("InvalidOutboxPayload");
  }
  return [...new Set(values.map((item) => (item as string).trim()))].sort();
}

function jsonObject(value: Prisma.JsonValue): Prisma.JsonObject {
  if (value == null || Array.isArray(value) || typeof value !== "object") {
    throw new Error("InvalidOutboxPayload");
  }
  return value;
}

function requiredText(value: Prisma.JsonObject, key: string): string {
  const text = value[key];
  if (typeof text !== "string" || text.trim().length === 0) {
    throw new Error("InvalidOutboxPayload");
  }
  return text.trim();
}
