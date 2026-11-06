export const OTP_CAPACITY_PORT = Symbol('OTP_CAPACITY_PORT');

/**
 * The app-wide daily WhatsApp-code quota (J1-19, RA-BE-02): `up` below the
 * warning share, `near_limit` from it, `exhausted` once no code can be sent
 * until the rolling day turns.
 */
export type OtpCapacity = 'up' | 'near_limit' | 'exhausted';

export interface OtpCapacityPort {
  capacity(): Promise<OtpCapacity>;
}
