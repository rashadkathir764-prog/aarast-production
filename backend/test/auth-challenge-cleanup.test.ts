import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { AuthChallengeCleanupScheduler } from "../src/auth/auth-challenge-cleanup.scheduler";

test("one replica removes only security state older than the retention window", async () => {
  const whereClauses: unknown[] = [];
  const scheduler = new AuthChallengeCleanupScheduler({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [{ locked: true }],
        adminLoginChallenge: {
          deleteMany: async ({ where }: any) => {
            whereClauses.push(where);
            return { count: 2 };
          },
        },
        adminPasswordResetChallenge: {
          deleteMany: async ({ where }: any) => {
            whereClauses.push(where);
            return { count: 3 };
          },
        },
        otpCode: {
          deleteMany: async ({ where }: any) => {
            whereClauses.push(where);
            return { count: 5 };
          },
        },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredSecurityState(), 10);
  assert.equal(whereClauses.length, 3);
  for (const where of whereClauses) {
    assert.ok((where as any).expiresAt.lt instanceof Date);
  }
});

test("challenge cleanup skips when another replica owns the lock", async () => {
  let deletes = 0;
  const scheduler = new AuthChallengeCleanupScheduler({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [{ locked: false }],
        adminLoginChallenge: { deleteMany: async () => deletes++ },
        adminPasswordResetChallenge: { deleteMany: async () => deletes++ },
        otpCode: { deleteMany: async () => deletes++ },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredSecurityState(), null);
  assert.equal(deletes, 0);
});
