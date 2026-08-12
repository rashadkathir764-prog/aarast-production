import { readBoundedJson } from '../http/bounded-json-response';
import { OtpDeliveryResult, OtpDeliveryUncertainError } from './otp-delivery';
import { loadWhatsAppOtpConfig, WhatsAppOtpConfig } from './whatsapp-otp-config';

/** Meta explicitly rejected the request before accepting it for delivery. */
class OtpDeliveryRejectedError extends Error {
  constructor(status: number) {
    super(`WhatsApp OTP request was rejected with HTTP ${status}`);
    this.name = 'OtpDeliveryRejectedError';
  }
}

const META_AMBIGUOUS_HTTP_STATUSES = new Set([408, 425, 499]);

export class WhatsAppOtpChannel {
  constructor(
    private readonly config: WhatsAppOtpConfig = loadWhatsAppOtpConfig(),
    private readonly fetchImplementation: typeof fetch = fetch,
  ) {}

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
