import { randomInt } from 'crypto';
import { OtpDeliveryResult } from '../../../../platform/otp-transport/otp-delivery';

/**
 * Seam for OTP delivery. AuthService owns generation/storage/verification;
 * channels only deliver identity-owned codes out-of-band.
 */
export interface OtpChannel {
  deliver(phone: string, code: string, purpose: string): Promise<OtpDeliveryResult>;
}

/** Local development bridge: fixed code, echoed in the response. */
export class DevEchoOtpChannel implements OtpChannel {
  constructor(private readonly fixedCode: string) {}

  deliver(): Promise<OtpDeliveryResult> {
    return Promise.resolve({
      delivery: 'LOCAL_DEV',
      deliveryStatus: 'LOCAL_DEV',
      echoCode: this.fixedCode,
      message: `رمز التحقق مؤقت للتجربة المحلية: ${this.fixedCode}`,
    });
  }
}

/** Identity-owned production code policy shared by every production transport. */
export function generateProductionOtpCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}
