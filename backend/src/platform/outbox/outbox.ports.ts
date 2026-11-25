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
  dispatchNotification(
    notificationId: string,
    alreadyDeliveredInstallationIds?: readonly string[],
  ): Promise<void>;
  /**
   * D112 (Q-11): the account's sessions were ended at [revokedAt]; its
   * push registrations made before then are let go, except [keepFid], the
   * phone that ended the others (RA-BE-133).
   */
  releaseUserInstallations(
    userId: string,
    revokedAt: Date,
    keepFid?: string,
  ): Promise<void>;
  /**
   * RA-MO-358: the application session [sessionId] ended; the push
   * registrations made under it go, and an account left with none has its
   * push off until a phone registers again.
   */
  releaseSessionInstallations(sessionId: string): Promise<void>;
  /**
   * RA-MO-358: the session [sessionId] was refreshed and carries on as
   * [nextSessionId]; its registrations follow it.
   */
  moveSessionInstallations(
    sessionId: string,
    nextSessionId: string,
  ): Promise<void>;
}
