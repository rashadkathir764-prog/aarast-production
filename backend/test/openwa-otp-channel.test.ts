import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpDeliveryUncertainError } from '../src/platform/otp-transport/otp-delivery';
import { OpenWaOtpChannel } from '../src/platform/otp-transport/openwa-otp.channel';
import { loadOpenWaOtpConfig } from '../src/platform/otp-transport/openwa-otp-config';
import { OpenWaTransientDeliveryRejectedError } from '../src/platform/otp-transport/openwa-transient-text';
import { validateRuntimeEnvironment } from '../src/platform/config/runtime-environment';
import { createStrongRuntimeJwtSecret } from './support/runtime-secrets';
import { getJwtSecret } from '../src/auth/jwt-secret';

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
