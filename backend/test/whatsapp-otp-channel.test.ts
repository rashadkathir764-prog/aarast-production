import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpDeliveryUncertainError } from '../src/platform/otp-transport/otp-delivery';
import { WhatsAppOtpChannel } from '../src/platform/otp-transport/whatsapp-otp.channel';
import { loadWhatsAppOtpConfig } from '../src/platform/otp-transport/whatsapp-otp-config';
import { validateRuntimeEnvironment } from '../src/platform/config/runtime-environment';
import { createStrongRuntimeJwtSecret } from './support/runtime-secrets';
import { getJwtSecret } from '../src/modules/identity/internal/auth/jwt-secret';

const strongRuntimeJwtSecret = createStrongRuntimeJwtSecret();
const config = {
  apiVersion: 'v23.0',
  phoneNumberId: '123456789',
  accessToken: 'test-access-token-that-is-long-enough',
  templateName: 'aarast_authentication_code',
  templateLanguage: 'ar',
  timeoutMs: 2_000,
};

test('WhatsApp OTP uses the approved template endpoint and never echoes the code', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const channel = new WhatsAppOtpChannel(config, async (url, init) => {
    capturedUrl = url.toString();
    capturedInit = init;
    return new Response(JSON.stringify({ messages: [{ id: 'wamid.test' }] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  });

  const result = await channel.deliver('+967777123456', '654321', 'REGISTER');
  assert.deepEqual(result, {
    delivery: 'WHATSAPP',
    deliveryStatus: 'PENDING',
  });
  assert.equal(capturedUrl, 'https://graph.facebook.com/v23.0/123456789/messages');
  const body = JSON.parse(capturedInit?.body as string);
  assert.equal(body.to, '967777123456');
  assert.equal(body.template.name, 'aarast_authentication_code');
  assert.equal(body.template.components[0].parameters[0].text, '654321');
  assert.equal(body.template.components[1].parameters[0].text, '654321');
  assert.equal('code' in result, false);
});

test('WhatsApp OTP timeout is uncertain and never exposes the request payload', async () => {
  const channel = new WhatsAppOtpChannel(
    { ...config, timeoutMs: 5 },
    async (_url, init) =>
      await new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener(
          'abort',
          () => reject(new DOMException('request aborted', 'AbortError')),
          { once: true },
        );
      }),
  );

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) => {
      assert.ok(error instanceof OtpDeliveryUncertainError);
      assert.doesNotMatch(error.message, /654321|967777123456/);
      return true;
    },
  );
});

test('WhatsApp OTP connection failure is uncertain', async () => {
  const channel = new WhatsAppOtpChannel(config, async () => {
    throw new TypeError('network connection failed');
  });

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'LOGIN'),
    (error: unknown) => error instanceof OtpDeliveryUncertainError,
  );
});

test('WhatsApp OTP 5xx response is uncertain and does not expose its body', async () => {
  const channel = new WhatsAppOtpChannel(
    config,
    async () =>
      new Response('{"provider_detail":"sensitive-provider-body"}', {
        status: 503,
        headers: { 'content-type': 'application/json' },
      }),
  );

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'RESET_PASSWORD'),
    (error: unknown) => {
      assert.ok(error instanceof OtpDeliveryUncertainError);
      assert.doesNotMatch(error.message, /sensitive-provider-body|654321/);
      return true;
    },
  );
});

test('WhatsApp OTP explicit 4xx response remains a definitive rejection', async () => {
  const channel = new WhatsAppOtpChannel(
    config,
    async () =>
      new Response('{"provider_detail":"sensitive-provider-body"}', {
        status: 400,
        headers: { 'content-type': 'application/json' },
      }),
  );

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.ok(!(error instanceof OtpDeliveryUncertainError));
      assert.match(error.message, /rejected with HTTP 400/);
      assert.doesNotMatch(error.message, /sensitive-provider-body|654321/);
      return true;
    },
  );
});

for (const status of [408, 425, 499]) {
  test(`WhatsApp OTP HTTP ${status} transport response is uncertain`, async () => {
    const channel = new WhatsAppOtpChannel(
      config,
      async () => new Response(null, { status }),
    );

    await assert.rejects(
      () => channel.deliver('+967777123456', '654321', 'REGISTER'),
      (error: unknown) => error instanceof OtpDeliveryUncertainError,
    );
  });
}

test('WhatsApp OTP malformed 2xx acceptance is uncertain', async () => {
  const channel = new WhatsAppOtpChannel(
    config,
    async () =>
      new Response(JSON.stringify({ messages: [{ id: '   ' }] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
  );

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) => error instanceof OtpDeliveryUncertainError,
  );
});

test('WhatsApp OTP oversized accepted response is uncertain', async () => {
  const channel = new WhatsAppOtpChannel(
    config,
    async () =>
      new Response(
        JSON.stringify({ messages: [{ id: 'x'.repeat(5_000) }] }),
        {
          status: 200,
          headers: { 'content-type': 'application/json' },
        },
      ),
  );

  await assert.rejects(
    () => channel.deliver('+967777123456', '654321', 'REGISTER'),
    (error: unknown) => error instanceof OtpDeliveryUncertainError,
  );
});

test('WhatsApp mode fails configuration validation before boot when incomplete', () => {
  assert.throws(
    () =>
      validateRuntimeEnvironment({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://example',
        JWT_SECRET: strongRuntimeJwtSecret,
        AUTH_LOGIN_THROTTLE_PEPPER: 'a-separate-login-throttle-test-secret',
        AUTH_OTP_MODE: 'whatsapp',
      }, getJwtSecret),
    /WhatsApp OTP is missing required environment variables/,
  );
});

test('production rejects dev OTP mode and accepts complete WhatsApp configuration', () => {
  assert.throws(
    () =>
      validateRuntimeEnvironment({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://example',
        JWT_SECRET: strongRuntimeJwtSecret,
      }, getJwtSecret),
    /AUTH_OTP_MODE is required in production/,
  );

  assert.throws(
    () =>
      validateRuntimeEnvironment({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://example',
        JWT_SECRET: strongRuntimeJwtSecret,
        AUTH_OTP_MODE: 'dev',
      }, getJwtSecret),
    /forbidden in production/,
  );

  assert.doesNotThrow(() =>
    validateRuntimeEnvironment({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgresql://example',
      JWT_SECRET: strongRuntimeJwtSecret,
      AUTH_LOGIN_THROTTLE_PEPPER: 'a-separate-login-throttle-test-secret',
      AUTH_OTP_MODE: 'whatsapp',
      WHATSAPP_GRAPH_API_VERSION: config.apiVersion,
      WHATSAPP_PHONE_NUMBER_ID: config.phoneNumberId,
      WHATSAPP_ACCESS_TOKEN: config.accessToken,
      WHATSAPP_OTP_TEMPLATE_NAME: config.templateName,
      WHATSAPP_OTP_TEMPLATE_LANGUAGE: config.templateLanguage,
      INVITE_PUBLIC_ORIGIN: 'https://site.example.test',
    }, getJwtSecret),
  );
});

// RA-OP-11: production names the origin of the invite and RSVP links.
test('production requires a public HTTPS invite origin', () => {
  const production = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://example',
    JWT_SECRET: strongRuntimeJwtSecret,
    AUTH_LOGIN_THROTTLE_PEPPER: 'a-separate-login-throttle-test-secret',
    AUTH_OTP_MODE: 'disabled',
  };
  assert.throws(
    () => validateRuntimeEnvironment(production, getJwtSecret),
    /INVITE_PUBLIC_ORIGIN is required in production/,
  );
  for (const origin of [
    'http://site.example.test',
    'site.example.test',
    'https://site.example.test/invites',
  ]) {
    assert.throws(
      () => validateRuntimeEnvironment({ ...production, INVITE_PUBLIC_ORIGIN: origin }, getJwtSecret),
      /INVITE_PUBLIC_ORIGIN must be a public HTTPS origin/,
      origin,
    );
  }
  assert.doesNotThrow(() =>
    validateRuntimeEnvironment(
      { ...production, INVITE_PUBLIC_ORIGIN: 'https://3-121-198-183.sslip.io' },
      getJwtSecret,
    ),
  );
  // Outside production the services keep their own fallback.
  assert.doesNotThrow(() =>
    validateRuntimeEnvironment({ ...production, NODE_ENV: 'development' }, getJwtSecret),
  );
});

test('WhatsApp config never accepts placeholders as a real channel', () => {
  assert.throws(() =>
    loadWhatsAppOtpConfig({
      WHATSAPP_GRAPH_API_VERSION: 'latest',
      WHATSAPP_PHONE_NUMBER_ID: 'not-an-id',
      WHATSAPP_ACCESS_TOKEN: 'placeholder',
      WHATSAPP_OTP_TEMPLATE_NAME: 'Invalid Name',
      WHATSAPP_OTP_TEMPLATE_LANGUAGE: 'invalid-language',
    }),
  );
});
