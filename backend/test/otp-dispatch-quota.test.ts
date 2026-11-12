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
      return [{ count: next.count, windowStartedAt: next.windowStartedAt }];
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

// D112 (Q-14), the owner's word: the refusal says which limit was reached
// and how long is left. It said «طلبات رمز التحقق كثيرة. حاول لاحقًا» for a
// minute's wait and for a day's alike, and the phone could only say «انتظر
// شوي» (RA-MO-110).
function refusal(error: unknown) {
  assert.ok(error instanceof HttpException);
  assert.equal(error.getStatus(), 429);
  return error.getResponse() as {
    code: string;
    message: string;
    retryAfterSeconds: number;
  };
}

test('the minute between two codes is said as a minute', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '150' },
    async () => {
      const harness = createHarness();
      await harness.service.consume('+967777123456');
      harness.advance(20_000);
      const said = refusal(
        await harness.service.consume('+967777123456').then(
          () => null,
          (error: unknown) => error,
        ),
      );
      assert.equal(said.code, 'OTP_LIMIT_COOLDOWN');
      assert.equal(said.retryAfterSeconds, 40);
      assert.equal(said.message, 'يتاح رمز جديد بعد دقيقة.');
    },
  );
});

test('the hour limit names five codes and the minutes left', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '150' },
    async () => {
      const harness = createHarness();
      for (let sent = 0; sent < 5; sent += 1) {
        await harness.service.consume('+967777123456');
        harness.advance(2 * 60_000);
      }
      // Ten minutes in; the hour's window began with the first code.
      const said = refusal(
        await harness.service.consume('+967777123456').then(
          () => null,
          (error: unknown) => error,
        ),
      );
      assert.equal(said.code, 'OTP_LIMIT_PHONE_HOUR');
      assert.equal(said.retryAfterSeconds, 50 * 60);
      assert.equal(
        said.message,
        'هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 50 دقيقة.',
      );
    },
  );
});

test('the day limit names ten codes and the hours left', async () => {
  await withEnvironment(
    { NODE_ENV: 'test', OTP_GLOBAL_DAILY_LIMIT: '150' },
    async () => {
      const harness = createHarness();
      for (let sent = 0; sent < 10; sent += 1) {
        await harness.service.consume('+967777123456');
        // Past the hour's window each time, so only the day's count grows.
        harness.advance(61 * 60_000);
      }
      const said = refusal(
        await harness.service.consume('+967777123456').then(
          () => null,
          (error: unknown) => error,
        ),
      );
      assert.equal(said.code, 'OTP_LIMIT_PHONE_DAY');
      // 610 minutes in: 13 hours and 50 minutes left, said as 14 hours.
      assert.equal(said.retryAfterSeconds, (24 * 60 - 610) * 60);
      assert.equal(
        said.message,
        'هذا الرقم طلب 10 رموز اليوم. يتاح رمز جديد بعد 14 ساعة.',
      );
    },
  );
});

// D112 (Q-5), my choice where the owner left it to me: a number's 5 an hour
// and 10 a day were counted for whoever asked, with no sign-in. One stranger
// asking ten times closed a victim out of their own account for a day. The
// allowance is now per number per address, under a higher ceiling for the
// number itself (the WhatsApp sender still has to be kept from a ban).
test('Q-5: a stranger using up a number does not close its owner out', async () => {
  await withEnvironment(
    {
      NODE_ENV: 'production',
      AUTH_LOGIN_THROTTLE_PEPPER: 'test-pepper-with-more-than-32-characters',
      OTP_GLOBAL_DAILY_LIMIT: '150',
    },
    async () => {
      const harness = createHarness();
      const victim = '+967777123456';
      for (let sent = 0; sent < 10; sent += 1) {
        await harness.service.consume(victim, { ip: '203.0.113.10' });
        harness.advance(61 * 60_000);
      }
      // The stranger's own allowance for this number is spent, by its limit.
      const said = refusal(
        await harness.service.consume(victim, { ip: '203.0.113.10' }).then(
          () => null,
          (error: unknown) => error,
        ),
      );
      assert.equal(said.code, 'OTP_LIMIT_PHONE_DAY');
      // The owner, from their own address, still gets a code.
      await assert.doesNotReject(() =>
        harness.service.consume(victim, { ip: '198.51.100.7' }),
      );
    },
  );
});

test('Q-5: the number keeps a ceiling across every address', async () => {
  await withEnvironment(
    {
      NODE_ENV: 'production',
      AUTH_LOGIN_THROTTLE_PEPPER: 'test-pepper-with-more-than-32-characters',
      OTP_GLOBAL_DAILY_LIMIT: '150',
    },
    async () => {
      const harness = createHarness();
      const victim = '+967777123456';
      // Fifteen codes in half an hour, each from another address: none of
      // them near its own allowance.
      for (let sent = 0; sent < 15; sent += 1) {
        await harness.service.consume(victim, { ip: `203.0.113.${sent + 1}` });
        harness.advance(2 * 60_000);
      }
      const said = refusal(
        await harness.service.consume(victim, { ip: '198.51.100.7' }).then(
          () => null,
          (error: unknown) => error,
        ),
      );
      assert.equal(said.code, 'OTP_LIMIT_PHONE_CEILING');
      assert.equal(said.retryAfterSeconds, 30 * 60);
      assert.equal(
        said.message,
        'طلبات رموز كثيرة على هذا الرقم. يتاح رمز جديد بعد 30 دقيقة.',
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
      // D112 (Q-5): two more rows, the number's allowance at this address
      // (an hour's and a day's) beside the number's own ceilings.
      assert.equal(harness.rows.size, 8);
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
