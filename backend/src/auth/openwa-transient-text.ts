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
        throw new OpenWaTransientDeliveryUncertainError();
      }
      throw new OpenWaTransientDeliveryRejectedError(response.status);
    }

    let payload: { messageId?: unknown };
    try {
      payload = await readBoundedJson<{ messageId?: unknown }>(response);
    } catch {
      throw new OpenWaTransientDeliveryUncertainError();
    }
    if (typeof payload.messageId !== 'string' || !payload.messageId.trim()) {
      throw new OpenWaTransientDeliveryUncertainError();
    }
  } finally {
    clearTimeout(timeout);
  }
}
