import assert from 'node:assert/strict';
import { test } from 'node:test';
import { HttpException } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Module } from '@nestjs/common';
import { PrismaService } from '../src/platform/database/prisma.service';
import {
  OTP_DISPATCH_NOW,
  OtpDispatchQuotaService,
} from '../src/modules/identity/internal/auth/otp-dispatch-quota.service';

@Module({
  providers: [
    OtpDispatchQuotaService,
    { provide: PrismaService, useValue: {} },
    { provide: OTP_DISPATCH_NOW, useValue: () => new Date() },
  ],
})
class OtpQuotaWiringTestModule {}

interface StoredQuota {
  count: number;
  windowStartedAt: Date;
}

function createHarness(startedAt = new Date('2026-07-12T12:00:00.000Z')) {
  let current = startedAt;
  const rows = new Map<string, StoredQuota>();
  const tx = {
    $queryRawUnsafe: async (
      _query: string,
      scope: string,
      subjectHash: string,
      now: Date,
      resetBefore: Date,
    ) => {
      const key = `${scope}:${subjectHash}`;
      const existing = rows.get(key);
      const reset = !existing || existing.windowStartedAt <= resetBefore;
      const next = {
        count: reset ? 1 : existing.count + 1,
        windowStartedAt: reset ? now : existing.windowStartedAt,
      };
      rows.set(key, next);
      return [{ count: next.count }];
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => Promise<void>) => {
      const snapshot = new Map(rows);
      try {
        return await operation(tx);
      } catch (error) {
        rows.clear();
        for (const [key, value] of snapshot) rows.set(key, value);
        throw error;
      }
    },
  };
  return {
    rows,
    advance(milliseconds: number) {
      current = new Date(current.getTime() + milliseconds);
    },
    service: new OtpDispatchQuotaService(prisma as any, () => current),
  };
}

async function withEnvironment(
  values: Record<string, string | undefined>,
  action: () => Promise<void>,
) {
  const previous = new Map<string, string | undefined>();
  for (const [name, value] of Object.entries(values)) {
    previous.set(name, process.env[name]);
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
  try {
    await action();
  } finally {
    for (const [name, value] of previous) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

test('Nest resolves the OTP quota clock through an explicit provider token', async () => {
  const context = await NestFactory.createApplicationContext(
    OtpQuotaWiringTestModule,
    { logger: false },
  );
  try {
    assert.ok(context.get(OtpDispatchQuotaService));
  } finally {
    await context.close();
  }
});

test('OTP quota blocks an immediate resend and allows it after 60 seconds', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '150' },
    async () => {
      const harness = createHarness();
      await harness.service.consume('+967777123456', { ip: '203.0.113.10' });
      await assert.rejects(
        () => harness.service.consume('+967777123456', { ip: '203.0.113.10' }),
        (error: unknown) =>
          error instanceof HttpException && error.getStatus() === 429,
      );
      harness.advance(OtpDispatchQuotaService.phoneCooldownMs + 1);
      await assert.doesNotReject(() =>
        harness.service.consume('+967777123456', { ip: '203.0.113.10' }),
      );
    },
  );
});

test('OTP quota hashes every phone and IP subject before persistence', async () => {
  await withEnvironment(
    {
      NODE_ENV: 'production',
      AUTH_LOGIN_THROTTLE_PEPPER: 'test-pepper-with-more-than-32-characters',
      OTP_GLOBAL_DAILY_LIMIT: '150',
    },
    async () => {
      const harness = createHarness();
      await harness.service.consume('+967777123456', { ip: '203.0.113.10' });
      const keys = [...harness.rows.keys()].join('|');
      assert.equal(keys.includes('967777123456'), false);
      assert.equal(keys.includes('203.0.113.10'), false);
      assert.equal(harness.rows.size, 6);
    },
  );
});

test('RA-BE-55: one IPv6 network is one sender: rotating addresses inside its /64 does not dodge the address limits', async () => {
  await withEnvironment(
    {
      NODE_ENV: 'production',
      AUTH_LOGIN_THROTTLE_PEPPER: 'test-pepper-with-more-than-32-characters',
      OTP_GLOBAL_DAILY_LIMIT: '150',
    },
    async () => {
      const harness = createHarness();
      // Ten codes in ten minutes from one address are the most it gets.
      for (let index = 0; index < 10; index += 1) {
        await harness.service.consume(`+96777712${String(index).padStart(4, '0')}`, {
          ip: `2001:db8:abcd:12::${(index + 1).toString(16)}`,
        });
      }
      // The eleventh, from another address of the same network, was let
      // through as a new sender; the network counts as one.
      await assert.rejects(
        harness.service.consume('+967777129999', { ip: '2001:db8:abcd:12:ffff::99' }),
        (error: unknown) => error instanceof HttpException && error.getStatus() === 429,
      );
      // Another network is another sender.
      await harness.service.consume('+967777128888', { ip: '2001:db8:abcd:13::1' });
    },
  );
});

test('RA-BE-55: an IPv4 address written as IPv6 is the same address', async () => {
  await withEnvironment(
    {
      NODE_ENV: 'production',
      AUTH_LOGIN_THROTTLE_PEPPER: 'test-pepper-with-more-than-32-characters',
      OTP_GLOBAL_DAILY_LIMIT: '150',
    },
    async () => {
      const harness = createHarness();
      for (let index = 0; index < 10; index += 1) {
        await harness.service.consume(`+96777713${String(index).padStart(4, '0')}`, {
          ip: index % 2 === 0 ? '203.0.113.10' : '::ffff:203.0.113.10',
        });
      }
      await assert.rejects(
        harness.service.consume('+967777139999', { ip: '203.0.113.10' }),
        (error: unknown) => error instanceof HttpException && error.getStatus() === 429,
      );
    },
  );
});

test('OTP quota enforces the configured global daily safety ceiling', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '2' },
    async () => {
      const harness = createHarness();
      await harness.service.consume('+967777000001');
      harness.advance(OtpDispatchQuotaService.phoneCooldownMs + 1);
      await harness.service.consume('+967777000002');
      harness.advance(OtpDispatchQuotaService.phoneCooldownMs + 1);
      await assert.rejects(
        () => harness.service.consume('+967777000003'),
        (error: unknown) =>
          error instanceof HttpException && error.getStatus() === 429,
      );
    },
  );
});

test('OTP quota rejects an invalid global ceiling instead of silently disabling it', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '0' },
    async () => {
      const harness = createHarness();
      await assert.rejects(
        () => harness.service.consume('+967777000001'),
        (error: any) =>
          error.getStatus?.() === 503 &&
          error.getResponse?.().code === 'OTP_DELIVERY_UNAVAILABLE',
      );
    },
  );
});
