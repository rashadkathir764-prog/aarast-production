import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { AuthChallengeCleanupScheduler } from "../src/modules/identity/internal/auth/auth-challenge-cleanup.scheduler";

test("one replica removes only security state older than the retention window", async () => {
  const whereClauses: unknown[] = [];
  let refreshWhere: unknown;
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
        refreshToken: {
          deleteMany: async ({ where }: any) => {
            refreshWhere = where;
            return { count: 7 };
          },
        },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredSecurityState(), 17);
  assert.equal(whereClauses.length, 3);
  for (const where of whereClauses) {
    assert.ok((where as any).expiresAt.lt instanceof Date);
  }
  const refresh = refreshWhere as {
    OR: Array<{
      expiresAt?: { lt: Date };
      revokedAt?: null | { not: null; lt: Date };
    }>;
  };
  assert.equal(refresh.OR.length, 2);
  assert.equal(refresh.OR[0].revokedAt, null);
  assert.ok(refresh.OR[0].expiresAt?.lt instanceof Date);
  assert.deepEqual(refresh.OR[1].revokedAt?.not, null);
  assert.ok(refresh.OR[1].revokedAt?.lt instanceof Date);
  const challengeCutoff = (whereClauses[0] as any).expiresAt.lt.getTime();
  const refreshCutoff = refresh.OR[0].expiresAt!.lt.getTime();
  assert.ok(
    challengeCutoff - refreshCutoff >= 28 * 24 * 60 * 60 * 1_000,
    "refresh sessions retain at least four weeks more history than challenges",
  );
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
        refreshToken: { deleteMany: async () => deletes++ },
      }),
  } as any);

  assert.equal(await scheduler.removeExpiredSecurityState(), null);
  assert.equal(deletes, 0);
});
