export const OutboxEventTypes = {
  conversationMessageAvailable: 'CONVERSATION_MESSAGE_AVAILABLE',
  conversationActivityAvailable: 'CONVERSATION_ACTIVITY_AVAILABLE',
  notificationCreated: 'NOTIFICATION_CREATED',
  conversationAccessRevoked: 'CONVERSATION_ACCESS_REVOKED',
  userSessionsRevoked: 'USER_SESSIONS_REVOKED',
  sessionRevoked: 'SESSION_REVOKED',
} as const;

export type OutboxEventType =
  (typeof OutboxEventTypes)[keyof typeof OutboxEventTypes];
