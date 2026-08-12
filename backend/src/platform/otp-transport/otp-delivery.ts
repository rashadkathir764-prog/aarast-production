export interface OtpDeliveryResult {
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
  deliveryStatus: 'LOCAL_DEV' | 'DELIVERED' | 'PENDING';
  /**
   * Populated ONLY by the local dev channel so the mobile dev build can
   * show the code. Production channels must never echo the code back in
   * an HTTP response.
   */
  echoCode?: string;
  message?: string;
}

/**
 * The provider may have accepted the message, but Aarast did not receive a
 * trustworthy acknowledgement. Callers must keep the OTP usable: retrying
 * immediately could send two valid-looking codes and invalidate the first.
 */
export class OtpDeliveryUncertainError extends Error {
  constructor() {
    super('OTP delivery outcome is uncertain');
    this.name = 'OtpDeliveryUncertainError';
  }
}
