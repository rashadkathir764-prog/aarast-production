import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpPurpose } from '@prisma/client';
import { AuthController } from '../src/modules/identity/api/auth.controller';

test('every OTP-producing auth route forwards the trusted request IP', async () => {
  const calls: Array<{ method: string; ip?: string }> = [];
  const authService = {
    startRegistration: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'register', ip: context.ip });
    },
    startAdminLogin: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'admin-login', ip: context.ip });
      return { mfaRequired: true };
    },
    requestOtp: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'otp', ip: context.ip });
    },
    requestPasswordReset: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'password-reset', ip: context.ip });
    },
    requestAdminPasswordReset: async (
      _dto: unknown,
      context: { ip?: string },
    ) => {
      calls.push({ method: 'admin-password-reset', ip: context.ip });
    },
  };
  const controller = new AuthController(authService as any);
  const request = { ip: '203.0.113.10' } as any;

  await controller.register(
    { name: 'Test', phone: '777123456' },
    request,
  );
  await controller.startAdminLogin(
    { phone: '777123456', password: 'secret123' },
    request,
    undefined,
    {} as any,
  );
  await controller.requestOtp(
    { phone: '777123456', purpose: OtpPurpose.VERIFY_PHONE },
    request,
  );
  await controller.requestPasswordReset({ phone: '777123456' }, request);
  await controller.requestAdminPasswordReset(
    { phone: '777123456' },
    request,
  );

  assert.deepEqual(calls, [
    { method: 'register', ip: '203.0.113.10' },
    { method: 'admin-login', ip: '203.0.113.10' },
    { method: 'otp', ip: '203.0.113.10' },
    { method: 'password-reset', ip: '203.0.113.10' },
    { method: 'admin-password-reset', ip: '203.0.113.10' },
  ]);
});

test('every OTP-producing and OTP-verifying route carries the per-IP throttle of its family', () => {
  // The invite OTP routes dispatch and verify one-time codes exactly like
  // the auth routes; they rely on the same dispatch quota and must carry the
  // same per-IP request ceiling (the global throttler is 1000/min by default).
  // The metadata keys are not re-exported by the package index.
  const { THROTTLER_LIMIT, THROTTLER_TTL } = require('@nestjs/throttler/dist/throttler.constants');
  const { ApiV1InviteAccessController } = require('../src/modules/collaboration/api/sharing.controller');
  const limitOf = (prototype: object, method: string) => ({
    limit: Reflect.getMetadata(`${THROTTLER_LIMIT}default`, (prototype as any)[method]),
    ttl: Reflect.getMetadata(`${THROTTLER_TTL}default`, (prototype as any)[method]),
  });
  const expected: Array<[object, string, number]> = [
    [AuthController.prototype, 'requestOtp', 20],
    [AuthController.prototype, 'verifyOtp', 30],
    [AuthController.prototype, 'register', 10],
    [AuthController.prototype, 'requestPasswordReset', 10],
    [ApiV1InviteAccessController.prototype, 'requestOtp', 20],
    [ApiV1InviteAccessController.prototype, 'verifyOtp', 30],
  ];
  for (const [prototype, method, limit] of expected) {
    assert.deepEqual(limitOf(prototype, method), { limit, ttl: 60_000 }, `${(prototype as any).constructor.name}.${method}`);
  }
});
