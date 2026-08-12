import { OtpDeliveryResult, OtpDeliveryUncertainError } from './otp-delivery';
import { loadOpenWaOtpConfig, OpenWaOtpConfig } from './openwa-otp-config';
import {
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from './openwa-transient-text';

/**
 * Temporary MVP channel backed by the Aarast-hardened OpenWA fork.
 *
 * This intentionally calls only `send-transient-text`. The upstream
 * `send-text` route persists message bodies and must never receive OTPs.
 */
export class OpenWaOtpChannel {
  constructor(
    private readonly configSource: OpenWaOtpConfig | (() => OpenWaOtpConfig) =
      loadOpenWaOtpConfig,
    private readonly fetchImplementation: typeof fetch = fetch,
  ) {
    // Fail fast so AuthService classifies a missing/invalid credential as an
    // unavailable channel before it creates and consumes an OTP record. The
    // source is still resolved again for every delivery so an atomic rotation
    // is adopted without restarting the backend.
    this.resolveConfig();
  }

  async deliver(
    phone: string,
    code: string,
    _purpose: string,
  ): Promise<OtpDeliveryResult> {
    // The bootstrap replaces a directory-mounted credential file atomically.
    // Resolve it for every operation so a long-running backend adopts the new
    // key without a restart or a stale environment copy.
    const config = this.resolveConfig();
    try {
      await sendOpenWaTransientText(
        {
          phone,
          text: `رمز التحقق في اعّرست: ${code}\nلا تشارك هذا الرمز مع أي شخص.`,
        },
        config,
        this.fetchImplementation,
      );
      return { delivery: 'WHATSAPP', deliveryStatus: 'DELIVERED' };
    } catch (error) {
      if (error instanceof OpenWaTransientDeliveryUncertainError) {
        throw new OtpDeliveryUncertainError();
      }
      throw error;
    }
  }

  private resolveConfig(): OpenWaOtpConfig {
    return typeof this.configSource === 'function'
      ? this.configSource()
      : this.configSource;
  }
}
