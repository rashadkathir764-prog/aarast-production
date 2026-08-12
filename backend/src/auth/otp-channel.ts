import { randomInt } from 'crypto';
import { loadWhatsAppOtpConfig, WhatsAppOtpConfig } from './whatsapp-otp-config';
import { loadOpenWaOtpConfig, OpenWaOtpConfig } from './openwa-otp-config';
import {
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from './openwa-transient-text';
import { readBoundedJson } from '../platform/http/bounded-json-response';

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

/** Meta explicitly rejected the request before accepting it for delivery. */
class OtpDeliveryRejectedError extends Error {
  constructor(status: number) {
    super(`WhatsApp OTP request was rejected with HTTP ${status}`);
    this.name = 'OtpDeliveryRejectedError';
  }
}

const META_AMBIGUOUS_HTTP_STATUSES = new Set([408, 425, 499]);

/**
 * Seam for OTP delivery. AuthService owns generation/storage/verification;
 * a channel only produces the code format and delivers it out-of-band.
 * Production channels must send the code out-of-band and never echo it.
 */
export interface OtpChannel {
  generateCode(): string;
  deliver(phone: string, code: string, purpose: string): Promise<OtpDeliveryResult>;
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
      deliveryStatus: 'LOCAL_DEV',
      echoCode: this.fixedCode,
      message: `رمز التحقق مؤقت للتجربة المحلية: ${this.fixedCode}`,
    });
  }
}

export class WhatsAppOtpChannel implements OtpChannel {
  constructor(
    private readonly config: WhatsAppOtpConfig = loadWhatsAppOtpConfig(),
    private readonly fetchImplementation: typeof fetch = fetch,
  ) {}

  generateCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  async deliver(phone: string, code: string, _purpose: string): Promise<OtpDeliveryResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await this.fetchImplementation(
        `https://graph.facebook.com/${this.config.apiVersion}/${this.config.phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.config.accessToken}`,
            'Content-Type': 'application/json',
          },
          redirect: 'error',
          signal: controller.signal,
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: phone.replace(/\D/g, ''),
            type: 'template',
            template: {
              name: this.config.templateName,
              language: { code: this.config.templateLanguage },
              components: [
                {
                  type: 'body',
                  parameters: [{ type: 'text', text: code }],
                },
                {
                  type: 'button',
                  sub_type: 'url',
                  index: '0',
                  parameters: [{ type: 'text', text: code }],
                },
              ],
            },
          }),
        },
      );

      if (!response.ok) {
        if (
          response.status >= 400 &&
          response.status < 500 &&
          !META_AMBIGUOUS_HTTP_STATUSES.has(response.status)
        ) {
          throw new OtpDeliveryRejectedError(response.status);
        }

        // A gateway/provider failure can happen after Meta accepted the body.
        // Treat every non-4xx response as ambiguous so the caller keeps the
        // already-created OTP usable instead of invalidating a code that may
        // still arrive.
        throw new OtpDeliveryUncertainError();
      }

      const payload = await readBoundedJson<{
        messages?: Array<{ id?: unknown }>;
      }>(response);
      if (
        typeof payload.messages?.[0]?.id !== 'string' ||
        payload.messages[0].id.trim().length === 0
      ) {
        throw new OtpDeliveryUncertainError();
      }

      // Meta's synchronous response proves API acceptance only. Device
      // delivery requires the asynchronous status webhook.
      return { delivery: 'WHATSAPP', deliveryStatus: 'PENDING' };
    } catch (error) {
      if (error instanceof OtpDeliveryRejectedError) {
        throw error;
      }
      if (error instanceof OtpDeliveryUncertainError) {
        throw error;
      }

      // AbortError, connection/DNS/TLS failures, malformed accepted responses,
      // and response-body read failures do not prove that Meta rejected the
      // request. Never include the provider response or request payload here.
      throw new OtpDeliveryUncertainError();
    } finally {
      clearTimeout(timeout);
    }
  }
}

/**
 * Temporary MVP channel backed by the Aarast-hardened OpenWA fork.
 *
 * This intentionally calls only `send-transient-text`. The upstream
 * `send-text` route persists message bodies and must never receive OTPs.
 */
export class OpenWaOtpChannel implements OtpChannel {
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

  generateCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  async deliver(phone: string, code: string, _purpose: string): Promise<OtpDeliveryResult> {
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
