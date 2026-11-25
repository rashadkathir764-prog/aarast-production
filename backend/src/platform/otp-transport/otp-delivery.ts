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

/**
 * How long a code lives, in whole minutes: the one reading of
 * `OTP_EXPIRES_MINUTES` (default 5, at most 60), shared by the identity
 * module that stores the expiry and the channel that tells the person.
 */
export function otpValidMinutes(
  env: Readonly<Record<string, string | undefined>> = process.env,
): number {
  const configured = Number(env.OTP_EXPIRES_MINUTES ?? 5);
  if (!Number.isFinite(configured) || configured < 1) return 5;
  return Math.min(Math.floor(configured), 60);
}

/** «دقيقة», «دقيقتين», «5 دقائق», «50 دقيقة»: the count the way it is said. */
export function otpMinutesWords(minutes: number): string {
  if (minutes === 1) return 'دقيقة';
  if (minutes === 2) return 'دقيقتين';
  return minutes <= 10 ? `${minutes} دقائق` : `${minutes} دقيقة`;
}
