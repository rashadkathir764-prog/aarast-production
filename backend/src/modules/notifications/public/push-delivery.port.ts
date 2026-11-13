export const PUSH_DELIVERY_PORT = Symbol('PUSH_DELIVERY_PORT');

export interface PushDeliveryPort {
  dispatchNotification(notificationId: string): Promise<void>;
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
}
