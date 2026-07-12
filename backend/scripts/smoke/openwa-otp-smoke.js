const { randomBytes } = require('node:crypto');

const requiredConfirmation = 'I_ACCEPT_REAL_WHATSAPP_SEND';

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function request(url, apiKey, init = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  try {
    return await fetch(url, {
      ...init,
      redirect: 'error',
      signal: controller.signal,
      headers: {
        'X-API-Key': apiKey,
        ...(init.body ? { 'Content-Type': 'application/json' } : {}),
        ...init.headers,
      },
    });
  } finally {
    clearTimeout(timeout);
  }
}

function normalizeBaseUrl(value) {
  const parsed = new URL(value);
  if (
    parsed.username ||
    parsed.password ||
    parsed.search ||
    parsed.hash ||
    parsed.pathname !== '/'
  ) {
    throw new Error('OPENWA_BASE_URL is invalid for the smoke gate');
  }
  if (!isAllowedOpenWaUrl(parsed)) {
    throw new Error('OPENWA_BASE_URL must use HTTPS or an internal HTTP service address');
  }
  return parsed.toString().replace(/\/$/, '');
}

function isAllowedOpenWaUrl(url) {
  if (url.protocol === 'https:') return true;
  if (url.protocol !== 'http:') return false;
  const hostname = url.hostname.toLowerCase();
  return (
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname === '::1' ||
    /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(hostname) ||
    hostname.endsWith('.internal') ||
    hostname.endsWith('.local') ||
    /^10\./.test(hostname) ||
    /^192\.168\./.test(hostname) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(hostname)
  );
}

function buildHistoryUrl(baseUrl, sessionId) {
  // Keep the recipient out of the audited request target. A dedicated OTP session must have no
  // ordinary persisted messages, so a bounded session-wide scan is the stronger privacy proof.
  return `${baseUrl}/api/sessions/${sessionId}/messages?limit=1000`;
}

async function readBoundedText(response, maxBytes = 1_048_576) {
  if (!response.body) return '';
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let total = 0;
  let text = '';
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        throw new Error('Message history response exceeded the smoke limit');
      }
      text += decoder.decode(value, { stream: true });
    }
    return text + decoder.decode();
  } finally {
    reader.releaseLock();
  }
}

async function main() {
  if (process.env.OPENWA_SMOKE_CONFIRM !== requiredConfirmation) {
    throw new Error(
      `Refusing a real WhatsApp send. Set OPENWA_SMOKE_CONFIRM=${requiredConfirmation}`,
    );
  }
  const baseUrl = normalizeBaseUrl(required('OPENWA_BASE_URL'));
  const sessionId = encodeURIComponent(required('OPENWA_SESSION_ID'));
  const apiKey = required('OPENWA_API_KEY');
  const auditApiKey = required('OPENWA_AUDIT_API_KEY');
  const phone = required('OPENWA_SMOKE_PHONE').replace(/\D/g, '');
  if (!/^\d{10,15}$/.test(phone)) throw new Error('OPENWA_SMOKE_PHONE is invalid');
  const chatId = `${phone}@c.us`;
  const marker = `AARAST-OTP-SMOKE-${Date.now()}-${randomBytes(6).toString('hex')}`;

  const readiness = await request(
    `${baseUrl}/api/sessions/${sessionId}/otp-readiness`,
    apiKey,
  );
  if (!readiness.ok) throw new Error(`OpenWA OTP readiness failed: HTTP ${readiness.status}`);
  const readinessBody = await readiness.json();
  if (readinessBody.ready !== true || readinessBody.transientText !== true) {
    throw new Error('OpenWA OTP transport is not ready');
  }

  const delivery = await request(
    `${baseUrl}/api/sessions/${sessionId}/messages/send-transient-text`,
    apiKey,
    {
      method: 'POST',
      body: JSON.stringify({ chatId, text: marker }),
    },
  );
  if (!delivery.ok) throw new Error(`Transient delivery failed: HTTP ${delivery.status}`);
  const deliveryBody = await delivery.json();
  if (typeof deliveryBody.messageId !== 'string' || !deliveryBody.messageId) {
    throw new Error('Transient delivery returned no message id');
  }

  await new Promise((resolve) => setTimeout(resolve, 2_000));
  const history = await request(
    buildHistoryUrl(baseUrl, sessionId),
    auditApiKey,
  );
  if (!history.ok) throw new Error(`Message history check failed: HTTP ${history.status}`);
  const historyText = await readBoundedText(history);
  if (historyText.includes(marker)) {
    throw new Error('SECURITY FAILURE: transient OTP marker was persisted in message history');
  }

  console.log('PASS openwa transient delivery and history non-persistence');
}

if (require.main === module) {
  main().catch((error) => {
    const safeMessage = error instanceof Error ? error.message : 'OpenWA OTP smoke failed';
    console.error(safeMessage.replace(/AARAST-OTP-SMOKE-[A-Za-z0-9-]+/g, '[REDACTED]'));
    process.exitCode = 1;
  });
}

module.exports = { normalizeBaseUrl, buildHistoryUrl };
