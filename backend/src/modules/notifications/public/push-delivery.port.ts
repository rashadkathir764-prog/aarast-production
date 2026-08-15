export const PUSH_DELIVERY_PORT = Symbol('PUSH_DELIVERY_PORT');

export interface PushDeliveryPort {
  dispatchNotification(notificationId: string): Promise<void>;
}
