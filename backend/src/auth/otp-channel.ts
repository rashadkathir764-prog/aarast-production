import { randomInt } from 'crypto';
import {
  loadWhatsAppOtpConfig,
  WhatsAppOtpConfig,
} from './whatsapp-otp-config';
import { loadOpenWaOtpConfig, OpenWaOtpConfig } from './openwa-otp-config';
import { readBoundedJson } from '../common/http/bounded-json-response';

export interface OtpDeliveryResult {
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
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
 * Production channels must send the code out-of-band and never echo it.
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

export class WhatsAppOtpChannel implements OtpChannel {
  constructor(
    private readonly config: WhatsAppOtpConfig = loadWhatsAppOtpConfig(),
    private readonly fetchImplementation: typeof fetch = fetch,
  ) {}

  generateCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  async deliver(
    phone: string,
    code: string,
    _purpose: string,
  ): Promise<OtpDeliveryResult> {
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
        throw new Error(`WhatsApp OTP delivery failed with HTTP ${response.status}`);
      }

      const payload = (await response.json()) as {
        messages?: Array<{ id?: unknown }>;
      };
      if (typeof payload.messages?.[0]?.id !== 'string') {
        throw new Error('WhatsApp OTP delivery returned no message id');
      }

      return { delivery: 'WHATSAPP' };
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
    private readonly config: OpenWaOtpConfig = loadOpenWaOtpConfig(),
    private readonly fetchImplementation: typeof fetch = fetch,
  ) {}

  generateCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
  }

  async deliver(
    phone: string,
    code: string,
    _purpose: string,
  ): Promise<OtpDeliveryResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.timeoutMs);
    const sessionId = encodeURIComponent(this.config.sessionId);

    try {
      const response = await this.fetchImplementation(
        `${this.config.baseUrl}/api/sessions/${sessionId}/messages/send-transient-text`,
        {
          method: 'POST',
          headers: {
            'X-API-Key': this.config.apiKey,
            'Content-Type': 'application/json',
          },
          redirect: 'error',
          signal: controller.signal,
          body: JSON.stringify({
            chatId: `${phone.replace(/\D/g, '')}@c.us`,
            text: `رمز التحقق في اعّرست: ${code}\nلا تشارك هذا الرمز مع أي شخص.`,
          }),
        },
      );

      if (!response.ok) {
        throw new Error(`OpenWA OTP delivery failed with HTTP ${response.status}`);
      }
      const payload = await readBoundedJson<{ messageId?: unknown }>(response);
      if (typeof payload.messageId !== 'string' || !payload.messageId.trim()) {
        throw new Error('OpenWA OTP delivery returned no message id');
      }

      return { delivery: 'WHATSAPP' };
    } finally {
      clearTimeout(timeout);
    }
  }
}
