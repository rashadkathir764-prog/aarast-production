import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { OtpDispatchQuotaService } from '../src/modules/identity/internal/auth/otp-dispatch-quota.service';
import type { PrismaService } from '../src/platform/database/prisma.service';

// J1-19, RA-BE-02: the app-wide rolling-day quota of WhatsApp codes warns at
// 80% of OTP_GLOBAL_DAILY_LIMIT and is exhausted at the limit, read from the
// same row the quota counts in.

const saved = process.env.OTP_GLOBAL_DAILY_LIMIT;
afterEach(() => {
  if (saved === undefined) delete process.env.OTP_GLOBAL_DAILY_LIMIT;
  else process.env.OTP_GLOBAL_DAILY_LIMIT = saved;
});

const now = new Date('2026-11-07T12:00:00Z');

function serviceWith(row: { count: number; windowStartedAt: Date } | null) {
  const asked: unknown[] = [];
  const prisma = {
    otpDispatchQuota: {
      findUnique: async (args: unknown) => {
        asked.push(args);
        return row;
      },
    },
  } as unknown as PrismaService;
  return { service: new OtpDispatchQuotaService(prisma, () => now), asked };
}

test('the capacity follows the share of the daily limit used', async () => {
  process.env.OTP_GLOBAL_DAILY_LIMIT = '150';
  const recent = new Date(now.getTime() - 60 * 60_000);
  const cases: Array<[number, string]> = [
    [0, 'up'],
    [119, 'up'],
    [120, 'near_limit'],
    [149, 'near_limit'],
    [150, 'exhausted'],
  ];
  for (const [count, expected] of cases) {
    const { service } = serviceWith({ count, windowStartedAt: recent });
    assert.equal(await service.capacity(), expected, `${count} of 150`);
  }
});

test('a window that has passed counts nothing, as the next code restarts it', async () => {
  process.env.OTP_GLOBAL_DAILY_LIMIT = '150';
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60_000);
  assert.equal(await serviceWith({ count: 150, windowStartedAt: dayAgo }).service.capacity(), 'up');
  assert.equal(await serviceWith(null).service.capacity(), 'up');
});

test('the capacity reads the global quota row the dispatch counts in', async () => {
  process.env.OTP_GLOBAL_DAILY_LIMIT = '10';
  const { service, asked } = serviceWith(null);
  await service.capacity();
  assert.deepEqual(asked, [
    {
      where: {
        scope_subjectHash: {
          scope: 'GLOBAL_DAY',
          subjectHash: OtpDispatchQuotaService.subjectHash('GLOBAL_DAY', 'aarast-otp'),
        },
      },
      select: { count: true, windowStartedAt: true },
    },
  ]);
});
