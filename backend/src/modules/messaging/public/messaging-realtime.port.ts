export const MESSAGING_REALTIME_PORT = Symbol('MESSAGING_REALTIME_PORT');

export interface MessagingRealtimePort {
  revokeConversationAccess(userId: string, conversationIds: string[]): void;
  dispatchMessageAvailable(
    conversationId: string,
    event: unknown,
  ): Promise<void>;
  dispatchActivityAvailable(
    conversationId: string,
    event: unknown,
    includeLifecycleEvent: boolean,
  ): Promise<void>;
  dispatchNotificationAvailable(userId: string, event: unknown): Promise<void>;
  dispatchConversationAccessRevoked(
    userId: string,
    conversationIds: string[],
  ): Promise<void>;
  dispatchUserSessionsRevoked(userId: string): Promise<void>;
  dispatchSessionRevoked(sessionId: string): Promise<void>;
  disconnectUser(userId: string): void;
  disconnectSession(sessionId: string): void;
}
