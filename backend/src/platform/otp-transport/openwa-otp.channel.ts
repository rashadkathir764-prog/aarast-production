import {
  OtpDeliveryResult,
  OtpDeliveryUncertainError,
  otpMinutesWords,
  otpValidMinutes,
} from './otp-delivery';
import { loadOpenWaOtpConfig, OpenWaOtpConfig } from './openwa-otp-config';
import {
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from './openwa-transient-text';

/**
 * RA-MO-360: what a code is for, in words that fit a man and a woman alike
 * («لإنشاء حسابك», never a verb in one gender). A purpose the table does not
 * know is said as the plain check of the number.
 */
const ACTION_BY_PURPOSE: Readonly<Record<string, string>> = {
  REGISTER: 'لإنشاء حسابك',
  LOGIN: 'لتسجيل الدخول',
  VERIFY_PHONE: 'لتوثيق رقمك',
  RESET_PASSWORD: 'لاستعادة كلمة المرور',
  CURRENT_PHONE_PROOF: 'لتأكيد رقمك الحالي',
  INVITE_ACCESS: 'لقبول الدعوة',
  ADMIN_LOGIN: 'لدخول الإدارة',
  ADMIN_RESET_PASSWORD: 'لاستعادة كلمة مرور الإدارة',
};

function otpText(code: string, purpose: string): string {
  const action = ACTION_BY_PURPOSE[purpose] ?? 'للتحقق من رقمك';
  return (
    `رمز اعّرست ${action}: ${code}\n` +
    `صالح ${otpMinutesWords(otpValidMinutes())}. لا تعطيه لأحد.`
  );
}

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
    purpose: string,
  ): Promise<OtpDeliveryResult> {
    // The bootstrap replaces a directory-mounted credential file atomically.
    // Resolve it for every operation so a long-running backend adopts the new
    // key without a restart or a stale environment copy.
    const config = this.resolveConfig();
    try {
      await sendOpenWaTransientText(
        {
          phone,
          text: otpText(code, purpose),
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
