export const OTP_CAPACITY_READINESS_PORT = Symbol('OTP_CAPACITY_READINESS_PORT');

/**
 * How close the app is to its daily WhatsApp-code limit (J1-19, RA-BE-02):
 * the readiness check reports it so the uptime alarm warns before sign-ups
 * stop. Identity owns the quota; the composition root binds it here, as it
 * binds media.
 */
export interface OtpCapacityReadinessPort {
  capacity(): Promise<'up' | 'near_limit' | 'exhausted'>;
}
