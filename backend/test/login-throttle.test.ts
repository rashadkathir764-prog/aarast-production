import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException, HttpStatus } from "@nestjs/common";
import { LoginThrottleService } from "../src/modules/identity/internal/auth/login-throttle.service";
import { LoginThrottleCleanupScheduler } from "../src/modules/identity/internal/auth/login-throttle-cleanup.scheduler";

process.env.AUTH_LOGIN_THROTTLE_PEPPER =
  "test-only-login-throttle-pepper-with-32-bytes";

type ThrottleRow = {
  subjectHash: string;
  failedCount: number;
  windowStartedAt: Date;
  lockedUntil: Date | null;
  updatedAt: Date;
};

function harness() {
  const records = new Map<string, ThrottleRow>();
  const loginThrottle = {
    findUnique: async ({ where }: any) => records.get(where.subjectHash) ?? null,
    upsert: async ({ where, create, update }: any) => {
      const existing = records.get(where.subjectHash);
      if (existing) {
        const updated = { ...existing, ...update };
        records.set(where.subjectHash, updated);
        return { ...updated };
      }
      const row: ThrottleRow = {
        ...create,
        lockedUntil: null,
        updatedAt: new Date(),
      };
      records.set(where.subjectHash, row);
      return { ...row };
    },
    update: async ({ where, data }: any) => {
      const existing = records.get(where.subjectHash);
      assert.ok(existing);
      const updated = { ...existing, ...data, updatedAt: new Date() };
      records.set(where.subjectHash, updated);
      return { ...updated };
    },
    deleteMany: async ({ where }: any) => ({
      count: records.delete(where.subjectHash) ? 1 : 0,
    }),
  };
  const prisma = {
    loginThrottle,
    $transaction: async (operation: any) =>
      operation({ loginThrottle }),
  };
  return {
    service: new LoginThrottleService(prisma as any),
    records,
  };
}

test("login attempts are stored under a one-way account hash", async () => {
  const { service, records } = harness();
  const phone = "+967777123456";

  await service.reserveAttempt(phone);

  assert.equal(records.size, 1);
  const [subjectHash] = records.keys();
  assert.equal(subjectHash, LoginThrottleService.subjectHash(phone));
  assert.equal(subjectHash.length, 64);
  assert.doesNotMatch(subjectHash, /777123456/);
  assert.equal(records.get(subjectHash)?.failedCount, 1);

  process.env.AUTH_LOGIN_THROTTLE_PEPPER =
    "a-different-test-only-login-throttle-pepper";
  assert.notEqual(LoginThrottleService.subjectHash(phone), subjectHash);
  process.env.AUTH_LOGIN_THROTTLE_PEPPER =
    "test-only-login-throttle-pepper-with-32-bytes";
});

test("application attempts never lock the administrator realm", async () => {
  const { service } = harness();
  const phone = "+967777123456";
  for (let attempt = 0; attempt < 5; attempt += 1) {
    await service.reserveAttempt(phone, "application");
  }

  await assert.rejects(() => service.assertAllowed(phone, "application"));
  await assert.doesNotReject(() => service.assertAllowed(phone, "admin"));
  assert.notEqual(
    LoginThrottleService.subjectHash(phone, "application"),
    LoginThrottleService.subjectHash(phone, "admin"),
  );
});

test("one replica cleans expired and inactive throttle windows", async () => {
  let where: unknown;
  const scheduler = new LoginThrottleCleanupScheduler({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [{ locked: true }],
        loginThrottle: {
          deleteMany: async (args: any) => {
            where = args.where;
            return { count: 4 };
          },
        },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredWindows(), 4);
  assert.deepEqual(Object.keys(where as object), ["OR"]);
});

test("cleanup skips safely when another replica owns the lock", async () => {
  let deletes = 0;
  const scheduler = new LoginThrottleCleanupScheduler({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [{ locked: false }],
        loginThrottle: {
          deleteMany: async () => {
            deletes += 1;
            return { count: 0 };
          },
        },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredWindows(), null);
  assert.equal(deletes, 0);
});

test("the fifth admitted attempt locks every server replica for fifteen minutes", async () => {
  const { service } = harness();
  const phone = "+967777123456";
  for (let attempt = 0; attempt < 5; attempt += 1) {
    await service.reserveAttempt(phone);
  }

  await assert.rejects(
    () => service.assertAllowed(phone),
    (error: unknown) =>
      error instanceof HttpException &&
      error.getStatus() === HttpStatus.TOO_MANY_REQUESTS,
  );
  await assert.rejects(
    () => service.reserveAttempt(phone),
    (error: unknown) =>
      error instanceof HttpException &&
      error.getStatus() === HttpStatus.TOO_MANY_REQUESTS,
  );
});

test("successful authentication clears the durable attempt window", async () => {
  const { service, records } = harness();
  const phone = "+967777123456";
  await service.reserveAttempt(phone);

  await service.clear(phone);

  assert.equal(records.size, 0);
  await assert.doesNotReject(() => service.assertAllowed(phone));
});
