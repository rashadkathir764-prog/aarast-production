import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpPurpose } from '@prisma/client';
import { AuthController } from '../src/auth/auth.controller';

test('every OTP-producing auth route forwards the trusted request IP', async () => {
  const calls: Array<{ method: string; ip?: string }> = [];
  const authService = {
    startRegistration: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'register', ip: context.ip });
    },
    startAdminLogin: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'admin-login', ip: context.ip });
    },
    requestOtp: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'otp', ip: context.ip });
    },
    requestPasswordReset: async (_dto: unknown, context: { ip?: string }) => {
      calls.push({ method: 'password-reset', ip: context.ip });
    },
  };
  const controller = new AuthController(authService as any);
  const request = { ip: '203.0.113.10' } as any;

  await controller.register(
    { name: 'Test', phone: '777123456', password: 'secret123' },
    request,
  );
  await controller.startAdminLogin(
    { phone: '777123456', password: 'secret123' },
    request,
  );
  await controller.requestOtp(
    { phone: '777123456', purpose: OtpPurpose.VERIFY_PHONE },
    request,
  );
  await controller.requestPasswordReset({ phone: '777123456' }, request);

  assert.deepEqual(calls, [
    { method: 'register', ip: '203.0.113.10' },
    { method: 'admin-login', ip: '203.0.113.10' },
    { method: 'otp', ip: '203.0.113.10' },
    { method: 'password-reset', ip: '203.0.113.10' },
  ]);
});
