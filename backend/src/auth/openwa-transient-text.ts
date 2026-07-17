import { readBoundedJson } from '../common/http/bounded-json-response';
import { loadOpenWaOtpConfig, OpenWaOtpConfig } from './openwa-otp-config';

export class OpenWaTransientDeliveryUncertainError extends Error {
  constructor() {
    super('OpenWA transient delivery outcome is uncertain');
    this.name = 'OpenWaTransientDeliveryUncertainError';
  }
}

export class OpenWaTransientDeliveryRejectedError extends Error {
  constructor(status?: number) {
    super(
      status == null
        ? 'OpenWA transient delivery was rejected'
        : `OpenWA transient delivery failed with HTTP ${status}`,
    );
    this.name = 'OpenWaTransientDeliveryRejectedError';
  }
}

export interface OpenWaTransientTextInput {
  phone: string;
  text: string;
}

interface OpenWaTransientResponse {
  messageId?: unknown;
  timestamp?: unknown;
  deliveryStatus?: unknown;
  code?: unknown;
}

/**
 * Sends one individual, short-lived machine message through Aarast's hardened
 * OpenWA contract. The recipient and body never enter the normal OpenWA
 * message store, hooks, webhooks, sockets, or application logs.
 */
export async function sendOpenWaTransientText(
  input: OpenWaTransientTextInput,
  config: OpenWaOtpConfig = loadOpenWaOtpConfig(),
  fetchImplementation: typeof fetch = fetch,
): Promise<void> {
  const digits = input.phone.replace(/\D/g, '');
  if (!/^[1-9]\d{7,14}$/.test(digits)) {
    throw new OpenWaTransientDeliveryRejectedError();
  }
  if (!input.text.trim() || input.text.length > 512) {
    throw new OpenWaTransientDeliveryRejectedError();
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs);
  const sessionId = encodeURIComponent(config.sessionId);

  try {
    let response: Response;
    try {
      response = await fetchImplementation(
        `${config.baseUrl}/api/sessions/${sessionId}/messages/send-transient-text`,
        {
          method: 'POST',
          headers: {
            'X-API-Key': config.apiKey,
            'Content-Type': 'application/json',
          },
          redirect: 'error',
          signal: controller.signal,
          body: JSON.stringify({
            chatId: `${digits}@c.us`,
            text: input.text,
          }),
        },
      );
    } catch {
      // The connection can disappear after WhatsApp accepted the message.
      throw new OpenWaTransientDeliveryUncertainError();
    }

    if (!response.ok) {
      if (response.status >= 500) {
        const code = await readSafeDeliveryCode(response);
        if (code === 'NOT_ATTEMPTED' || code === 'REJECTED') {
          throw new OpenWaTransientDeliveryRejectedError(response.status);
        }
        // A proxy/transport 5xx can arrive after OpenWA accepted the message.
        // Only OpenWA's two explicit definitive codes are safe to reject;
        // unknown, malformed, and DELIVERY_UNCERTAIN responses retain the OTP.
        throw new OpenWaTransientDeliveryUncertainError();
      }
      throw new OpenWaTransientDeliveryRejectedError(response.status);
    }

    let payload: OpenWaTransientResponse;
    try {
      payload = await readBoundedJson<OpenWaTransientResponse>(response);
    } catch {
      throw new OpenWaTransientDeliveryUncertainError();
    }
    if (
      typeof payload.messageId !== 'string' ||
      !payload.messageId.trim() ||
      typeof payload.timestamp !== 'number' ||
      !Number.isFinite(payload.timestamp) ||
      payload.timestamp <= 0 ||
      payload.deliveryStatus !== 'SENT'
    ) {
      throw new OpenWaTransientDeliveryUncertainError();
    }
  } finally {
    clearTimeout(timeout);
  }
}

async function readSafeDeliveryCode(response: Response): Promise<string | null> {
  try {
    const payload = await readBoundedJson<OpenWaTransientResponse>(response);
    return typeof payload.code === 'string' ? payload.code : null;
  } catch {
    return null;
  }
}
