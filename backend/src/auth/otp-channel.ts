export interface OtpDeliveryResult {
  delivery: 'LOCAL_DEV' | 'PROVIDER_PENDING' | 'WHATSAPP';
  /**
   * Populated ONLY by the local dev channel so the mobile dev build can
   * show the code. Production channels must never echo the code back in
   * an HTTP response.
   */
  echoCode?: string;
  message?: string;
}

/**
 * Seam for OTP delivery. AuthService owns generation/storage/verification;
 * a channel only produces the code format and delivers it out-of-band.
 * Production WhatsApp delivery intentionally remains unimplemented until the
 * approved Meta provider phase is started.
 */
export interface OtpChannel {
  generateCode(): string;
  deliver(
    phone: string,
    code: string,
    purpose: string,
  ): Promise<OtpDeliveryResult>;
}

/** Local development bridge: fixed code, echoed in the response. */
export class DevEchoOtpChannel implements OtpChannel {
  constructor(private readonly fixedCode: string) {}

  generateCode(): string {
    return this.fixedCode;
  }

  deliver(): Promise<OtpDeliveryResult> {
    return Promise.resolve({
      delivery: 'LOCAL_DEV',
      echoCode: this.fixedCode,
      message: `رمز التحقق مؤقت للتجربة المحلية: ${this.fixedCode}`,
    });
  }
}
