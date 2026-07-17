import 'reflect-metadata';

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { afterEach, test } from 'node:test';
import { HttpException } from '@nestjs/common';
import { AuthErrorCode } from '../src/auth/auth-error';
import { InviteAccessService } from '../src/sharing/invite-access.service';
import {
  buildInvitationMessage,
  InvitationDeliveryService,
} from '../src/sharing/invitation-delivery.service';

const originalEnvironment = { ...process.env };
const originalFetch = globalThis.fetch;

afterEach(() => {
  process.env = { ...originalEnvironment };
  globalThis.fetch = originalFetch;
});

test('Aarast sends an invite through only the hardened transient OpenWA route', async () => {
  process.env.AUTH_OTP_MODE = 'openwa';
  process.env.OPENWA_BASE_URL = 'http://openwa:2785';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'a-secure-openwa-api-key-for-tests-only';
  const requests: Array<{ url: string; body: Record<string, unknown> }> = [];
  globalThis.fetch = (async (input, init) => {
    requests.push({
      url: input.toString(),
      body: JSON.parse(init?.body?.toString() ?? '{}') as Record<
        string,
        unknown
      >,
    });
    return new Response(
      JSON.stringify({
        messageId: 'wa-message-1',
        deliveryStatus: 'SENT',
      }),
      {
        status: 201,
        headers: { 'content-type': 'application/json' },
      },
    );
  }) as typeof fetch;

  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
  const result = await new InvitationDeliveryService().deliver(
    '+967777123456',
    token,
  );

  assert.deepEqual(result, { channel: 'WHATSAPP', status: 'SENT' });
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url,
    'http://openwa:2785/api/sessions/aarast-otp/messages/send-transient-text',
  );
  assert.equal(requests[0].body.chatId, '967777123456@c.us');
  assert.match(
    requests[0].body.text as string,
    new RegExp(`https://aarast\\.shadowgardn\\.com/invites/${token}`),
  );
  assert.doesNotMatch(requests[0].body.text as string, /رشاد|سارة|اسم الخطة/);
});

test('invite delivery maps explicit OpenWA outcomes without false success', async () => {
  process.env.AUTH_OTP_MODE = 'openwa';
  process.env.OPENWA_BASE_URL = 'http://openwa:2785';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'a-secure-openwa-api-key-for-tests-only';
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';

  for (const [payload, expectedStatus] of [
    [{ code: 'NOT_ATTEMPTED' }, 'UNAVAILABLE'],
    [{ code: 'REJECTED' }, 'UNAVAILABLE'],
    [{ code: 'DELIVERY_UNCERTAIN' }, 'UNCERTAIN'],
    [{ code: 'UNKNOWN' }, 'UNCERTAIN'],
  ] as const) {
    globalThis.fetch = (async () =>
      new Response(JSON.stringify(payload), {
        status: 503,
        headers: { 'content-type': 'application/json' },
      })) as typeof fetch;

    const result = await new InvitationDeliveryService().deliver(
      '+967777123456',
      token,
    );
    assert.deepEqual(result, {
      channel: 'WHATSAPP',
      status: expectedStatus,
    });
  }

  globalThis.fetch = (async () =>
    new Response(
      JSON.stringify({ messageId: 'wa-message-2', deliveryStatus: 'QUEUED' }),
      {
        status: 200,
        headers: { 'content-type': 'application/json' },
      },
    )) as typeof fetch;
  const ambiguousSuccess = await new InvitationDeliveryService().deliver(
    '+967777123456',
    token,
  );
  assert.deepEqual(ambiguousSuccess, {
    channel: 'WHATSAPP',
    status: 'UNCERTAIN',
  });
});

test('invite message is generic, private, and rejects an unsafe public origin', () => {
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
  const message = buildInvitationMessage(token);
  assert.match(message, /تحقق من رقم هاتفك/);
  assert.doesNotMatch(message, /\+967|777123456/);
  assert.throws(
    () =>
      buildInvitationMessage(token, {
        INVITE_PUBLIC_ORIGIN: 'http://example.com',
      }),
    /public HTTPS origin/,
  );
});

test('invite OTP is sent only when the bearer token and canonical phone match', async () => {
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
  const expectedHash = createHash('sha256').update(token).digest('hex');
  const authCalls: Array<Record<string, unknown>> = [];
  const service = new InviteAccessService(
    {
      planInvite: {
        findFirst: async ({ where }: any) =>
          where.tokenHash === expectedHash &&
          where.normalizedPhone === '+967777123456'
            ? { id: 'invite-1' }
            : null,
      },
    } as any,
    {
      requestOtp: async (dto: Record<string, unknown>) => {
        authCalls.push(dto);
        return { delivery: 'WHATSAPP' };
      },
    } as any,
  );

  const result = await service.requestOtp(
    token,
    { phone: '777 123 456' },
    { ip: '127.0.0.1' },
  );
  assert.deepEqual(result, { delivery: 'WHATSAPP' });
  assert.equal(authCalls.length, 1);
  assert.equal(authCalls[0].phone, '+967777123456');
  assert.equal(authCalls[0].purpose, 'LOGIN');

  await assert.rejects(
    () =>
      service.requestOtp(
        token,
        { phone: '777 999 999' },
        { ip: '127.0.0.1' },
      ),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      const response = error.getResponse() as { code?: string };
      assert.equal(response.code, AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE);
      return true;
    },
  );
  assert.equal(authCalls.length, 1);
});
