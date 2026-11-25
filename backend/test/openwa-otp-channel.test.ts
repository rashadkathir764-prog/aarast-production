import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpDeliveryUncertainError } from '../src/platform/otp-transport/otp-delivery';
import { OpenWaOtpChannel } from '../src/platform/otp-transport/openwa-otp.channel';
import { loadOpenWaOtpConfig } from '../src/platform/otp-transport/openwa-otp-config';
import { OpenWaTransientDeliveryRejectedError } from '../src/platform/otp-transport/openwa-transient-text';
import { validateRuntimeEnvironment } from '../src/platform/config/runtime-environment';
import { createStrongRuntimeJwtSecret } from './support/runtime-secrets';
import { getJwtSecret } from '../src/modules/identity/internal/auth/jwt-secret';

const strongRuntimeJwtSecret = createStrongRuntimeJwtSecret();
const { normalizeBaseUrl, buildHistoryUrl } = require('../scripts/smoke/openwa-otp-smoke.js') as {
  normalizeBaseUrl: (value: string) => string;
  buildHistoryUrl: (baseUrl: string, sessionId: string) => string;
};

const config = {
  baseUrl: 'http://openwa:3000',
  sessionId: 'aarast-otp',
  apiKey: 'a-secure-openwa-api-key-for-tests-only',
  timeoutMs: 2_000,
};

test('OpenWA OTP uses only the transient route and never echoes the code', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const channel = new OpenWaOtpChannel(config, async (url, init) => {
    capturedUrl = url.toString();
    capturedInit = init;
    return new Response(
      JSON.stringify({
        messageId: 'wa-message-id',
        timestamp: 1706868000,
        deliveryStatus: 'DELIVERED',
      }),
      {
        status: 201,
        headers: { 'content-type': 'application/json' },
      },
    );
  });

  const result = await channel.deliver('+967777123456', '654321', 'REGISTER');
  assert.deepEqual(result, {
    delivery: 'WHATSAPP',
    deliveryStatus: 'DELIVERED',
  });
  assert.equal(
    capturedUrl,
    'http://openwa:3000/api/sessions/aarast-otp/messages/send-transient-text',
  );
  assert.equal(capturedUrl.includes(config.apiKey), false);
  assert.equal(capturedInit?.redirect, 'error');
  assert.equal(capturedInit?.headers instanceof Headers, false);
  assert.equal((capturedInit?.headers as Record<string, string>)['X-API-Key'], config.apiKey);
  const body = JSON.parse(capturedInit?.body as string);
  assert.equal(body.chatId, '967777123456@c.us');
  assert.match(body.text, /654321/);
  assert.equal('code' in result, false);
});

// RA-MO-360: the text said «لا تشارك» (the groom's word to a bride too), not
// how long the code lives, nor what it is for.
async function sentText(
  purpose: string,
  env: Record<string, string | undefined> = {},
): Promise<string> {
  const previous = process.env.OTP_EXPIRES_MINUTES;
  if ('OTP_EXPIRES_MINUTES' in env) {
    if (env.OTP_EXPIRES_MINUTES === undefined) delete process.env.OTP_EXPIRES_MINUTES;
    else process.env.OTP_EXPIRES_MINUTES = env.OTP_EXPIRES_MINUTES;
  }
  try {
    let text = '';
    const channel = new OpenWaOtpChannel(config, async (_url, init) => {
      text = JSON.parse(init?.body as string).text;
      return new Response(
        JSON.stringify({
          messageId: 'wa-message-id',
          timestamp: 1706868000,
          deliveryStatus: 'DELIVERED',
        }),
        { status: 201, headers: { 'content-type': 'application/json' } },
      );
    });
    await channel.deliver('+967777123456', '654321', purpose);
    return text;
  } finally {
    if (previous === undefined) delete process.env.OTP_EXPIRES_MINUTES;
    else process.env.OTP_EXPIRES_MINUTES = previous;
  }
}

test('OpenWA OTP text names the action, the five minutes and speaks to both genders', async () => {
  const actions: Record<string, string> = {
    REGISTER: 'لإنشاء حسابك',
    LOGIN: 'لتسجيل الدخول',
    VERIFY_PHONE: 'لتوثيق رقمك',
    RESET_PASSWORD: 'لاستعادة كلمة المرور',
    CURRENT_PHONE_PROOF: 'لتأكيد رقمك الحالي',
    INVITE_ACCESS: 'لقبول الدعوة',
    ADMIN_LOGIN: 'لدخول الإدارة',
    ADMIN_RESET_PASSWORD: 'لاستعادة كلمة مرور الإدارة',
  };
  const seen = new Set<string>();
  for (const [purpose, action] of Object.entries(actions)) {
    const text = await sentText(purpose, { OTP_EXPIRES_MINUTES: undefined });
    assert.ok(text.includes('654321'), purpose);
    assert.ok(text.includes(action), `${purpose}: ${text}`);
    assert.ok(text.includes('5 دقائق'), `${purpose}: ${text}`);
    assert.ok(text.includes('اعّرست'), purpose);
    // The masculine «لا تشارك» of the old text; the neutral «لا تعطيه لأحد».
    assert.doesNotMatch(text, /تشارك|أعرست/, purpose);
    assert.ok(text.includes('لا تعطيه لأحد'), `${purpose}: ${text}`);
    seen.add(text);
  }
  assert.equal(seen.size, Object.keys(actions).length, 'each action has its own text');
});

test('OpenWA OTP text says the lifetime the code really has', async () => {
  assert.ok((await sentText('LOGIN', { OTP_EXPIRES_MINUTES: '10' })).includes('10 دقائق'));
  assert.ok((await sentText('LOGIN', { OTP_EXPIRES_MINUTES: '15' })).includes('15 دقيقة'));
  assert.ok((await sentText('LOGIN', { OTP_EXPIRES_MINUTES: '2' })).includes('دقيقتين'));
  // Out of range falls back to the default, as the stored expiry does.
  assert.ok((await sentText('LOGIN', { OTP_EXPIRES_MINUTES: 'abc' })).includes('5 دقائق'));
});

test('OpenWA OTP requires a complete acknowledgement on every 2xx response', async () => {
  for (const body of [
    JSON.stringify({ queued: true }),
    JSON.stringify({ messageId: 'wa-message-id' }),
    JSON.stringify({ timestamp: 1706868000, deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: '   ', timestamp: 1706868000, deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: 'wa-message-id', timestamp: 1706868000, deliveryStatus: 'QUEUED' }),
    JSON.stringify({ messageId: 'wa-message-id', deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: 'wa-message-id', timestamp: null, deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: 'wa-message-id', timestamp: '1706868000', deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: 'wa-message-id', timestamp: 0, deliveryStatus: 'SENT' }),
    JSON.stringify({ messageId: 'wa-message-id', timestamp: -1, deliveryStatus: 'SENT' }),
    '{"messageId":"wa-message-id","timestamp":1e400,"deliveryStatus":"SENT"}',
  ]) {
    const channel = new OpenWaOtpChannel(
      config,
      async () =>
        new Response(body, {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
    );
    await assert.rejects(
      () => channel.deliver('+967777123456', '654321', 'REGISTER'),
      (error: unknown) => error instanceof OtpDeliveryUncertainError,
    );
  }
});

test('OpenWA OTP keeps explicit and unknown 5xx outcomes plus transport breaks active', async () => {
  for (const fetchImplementation of [
    async () =>
      new Response(JSON.stringify({ code: 'DELIVERY_UNCERTAIN' }), {
        status: 503,
        headers: { 'content-type': 'application/json' },
      }),
    async () => new Response('<html>bad gateway</html>', { status: 502 }),
    async () =>
      new Response(JSON.stringify({ code: 'UNKNOWN' }), {
        status: 503,
        headers: { 'content-type': 'application/json' },
      }),
    async () => {
      throw new TypeError('socket closed');
    },
  ]) {
    const channel = new OpenWaOtpChannel(config, fetchImplementation);
    await assert.rejects(
      () => channel.deliver('+967777123456', '654321', 'REGISTER'),
      (error: unknown) => error instanceof OtpDeliveryUncertainError,
    );
  }
});

test('OpenWA OTP treats only explicit definitive 5xx outcomes as rejected', async () => {
  for (const payload of [{ code: 'NOT_ATTEMPTED' }, { code: 'REJECTED' }]) {
    const channel = new OpenWaOtpChannel(
      config,
      async () =>
        new Response(JSON.stringify(payload), {
          status: 503,
          headers: { 'content-type': 'application/json' },
        }),
    );
    await assert.rejects(
      () => channel.deliver('+967777123456', '654321', 'REGISTER'),
      (error: unknown) =>
        error instanceof OpenWaTransientDeliveryRejectedError &&
        /HTTP 503/.test(error.message),
    );
  }
});

test('OpenWA OTP keeps definitive provider 4xx failures distinct', async () => {
  const channel = new OpenWaOtpChannel(
    config,
    async () => new Response('', { status: 401 }),
  );
  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) =>
      error instanceof Error &&
      !(error instanceof OtpDeliveryUncertainError) &&
      /HTTP 401/.test(error.message),
  );
});

for (const status of [408, 425, 499]) {
  test(`OpenWA OTP HTTP ${status} transport response is uncertain`, async () => {
    const channel = new OpenWaOtpChannel(
      config,
      async () => new Response(null, { status }),
    );
    await assert.rejects(
      () => channel.deliver('+967777123456', '654321', 'REGISTER'),
      (error: unknown) => error instanceof OtpDeliveryUncertainError,
    );
  });
}

test('OpenWA config accepts internal HTTP and rejects unsafe public HTTP', () => {
  assert.equal(
    loadOpenWaOtpConfig({
      OPENWA_BASE_URL: 'http://openwa:3000/',
      OPENWA_SESSION_ID: config.sessionId,
      OPENWA_API_KEY: config.apiKey,
    }).baseUrl,
    'http://openwa:3000',
  );
  assert.equal(
    loadOpenWaOtpConfig({
      OPENWA_BASE_URL: 'http://aarast-openwa-otp:2785',
      OPENWA_SESSION_ID: config.sessionId,
      OPENWA_API_KEY: config.apiKey,
    }).baseUrl,
    'http://aarast-openwa-otp:2785',
  );
  assert.throws(
    () =>
      loadOpenWaOtpConfig({
        OPENWA_BASE_URL: 'http://public.example.com',
        OPENWA_SESSION_ID: config.sessionId,
        OPENWA_API_KEY: config.apiKey,
      }),
    /HTTPS or an internal HTTP service address/,
  );
  assert.throws(
    () =>
      loadOpenWaOtpConfig({
        OPENWA_BASE_URL: 'https://openwa.example.com/prefix',
        OPENWA_SESSION_ID: config.sessionId,
        OPENWA_API_KEY: config.apiKey,
      }),
    /must not contain a path/,
  );
  assert.throws(
    () =>
      loadOpenWaOtpConfig({
        OPENWA_BASE_URL: 'http://openwa:3000',
        OPENWA_SESSION_ID: config.sessionId,
        OPENWA_API_KEY: 'contains whitespace and is not a safe header',
      }),
    /not configured securely/,
  );
});

test('OpenWA production mode fails closed when its private contract is incomplete', () => {
  assert.throws(
    () =>
      validateRuntimeEnvironment({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://example',
        JWT_SECRET: strongRuntimeJwtSecret,
        AUTH_LOGIN_THROTTLE_PEPPER: 'a-separate-login-throttle-test-secret',
        CONTRIBUTION_ACTOR_REF_SECRET: 'a-separate-contribution-actor-ref-test-secret',
        AUTH_OTP_MODE: 'openwa',
      }, getJwtSecret),
    /OpenWA OTP is missing required environment variables/,
  );
});

test('runtime rejects a malformed OTP global safety ceiling before boot', () => {
  assert.throws(
    () =>
      validateRuntimeEnvironment({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://example',
        JWT_SECRET: strongRuntimeJwtSecret,
        AUTH_LOGIN_THROTTLE_PEPPER: 'a-separate-login-throttle-test-secret',
        CONTRIBUTION_ACTOR_REF_SECRET: 'a-separate-contribution-actor-ref-test-secret',
        AUTH_OTP_MODE: 'disabled',
        OTP_GLOBAL_DAILY_LIMIT: '0',
      }, getJwtSecret),
    /OTP_GLOBAL_DAILY_LIMIT/,
  );
});

test('OpenWA OTP rejects oversized provider responses', async () => {
  const channel = new OpenWaOtpChannel(
    config,
    async () =>
      new Response(
        JSON.stringify({
          messageId: 'x'.repeat(5_000),
          timestamp: 1706868000,
          deliveryStatus: 'SENT',
        }),
        {
          status: 201,
          headers: { 'content-type': 'application/json' },
        },
      ),
  );
  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) => error instanceof OtpDeliveryUncertainError,
  );
});

test('OpenWA OTP smoke rejects plaintext public origins', () => {
  assert.throws(
    () => normalizeBaseUrl('http://openwa.example.com'),
    /HTTPS or an internal HTTP service address/,
  );
  assert.equal(
    normalizeBaseUrl('http://aarast-openwa-otp:2785'),
    'http://aarast-openwa-otp:2785',
  );
  assert.equal(normalizeBaseUrl('https://openwa.example.com'), 'https://openwa.example.com');
});

test('OpenWA OTP smoke history audit keeps the recipient out of the URL', () => {
  const url = buildHistoryUrl('https://openwa.example.com', 'session-1');
  assert.equal(url, 'https://openwa.example.com/api/sessions/session-1/messages?limit=1000');
  assert.doesNotMatch(url, /chatId|967700000001|@c\.us/);
});
