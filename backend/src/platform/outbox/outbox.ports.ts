export const OUTBOX_REALTIME_SINK = Symbol('OUTBOX_REALTIME_SINK');
export const OUTBOX_PUSH_SINK = Symbol('OUTBOX_PUSH_SINK');

export interface OutboxRealtimeSink {
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
}

export interface OutboxPushSink {
  dispatchNotification(notificationId: string): Promise<void>;
  /**
   * D112 (Q-11): the account's sessions were all ended at [revokedAt]; its
   * push registrations made before then are let go.
   */
  releaseUserInstallations(userId: string, revokedAt: Date): Promise<void>;
}
