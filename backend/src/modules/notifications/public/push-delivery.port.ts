export const PUSH_DELIVERY_PORT = Symbol('PUSH_DELIVERY_PORT');

export interface PushDeliveryPort {
  /**
   * Sends the notification to the account's phones, except those whose
   * installation ids are in [alreadyDeliveredInstallationIds] (reached by an
   * earlier try). When some phone failed for a reason worth retrying it
   * throws `PushDeliveryRetryRequired` carrying `deliveredInstallationIds`:
   * everyone reached so far, which the retry passes back (RA-BE-190).
   */
  dispatchNotification(
    notificationId: string,
    alreadyDeliveredInstallationIds?: readonly string[],
  ): Promise<void>;
  /**
   * D112 (Q-11): lets go of the push registrations [userId] made before
   * [revokedAt], the moment its sessions were ended, except [keepFid], the
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
