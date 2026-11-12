export const PUSH_DELIVERY_PORT = Symbol('PUSH_DELIVERY_PORT');

export interface PushDeliveryPort {
  dispatchNotification(notificationId: string): Promise<void>;
  /**
   * D112 (Q-11): lets go of the push registrations [userId] made before
   * [revokedAt], the moment all its sessions were ended.
   */
  releaseUserInstallations(userId: string, revokedAt: Date): Promise<void>;
}
