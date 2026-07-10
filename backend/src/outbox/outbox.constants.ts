export const OutboxEventTypes = {
  conversationMessageAvailable: 'CONVERSATION_MESSAGE_AVAILABLE',
  notificationCreated: 'NOTIFICATION_CREATED',
} as const;

export type OutboxEventType =
  (typeof OutboxEventTypes)[keyof typeof OutboxEventTypes];
