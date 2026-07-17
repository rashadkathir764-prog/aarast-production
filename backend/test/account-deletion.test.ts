import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ForbiddenException } from "@nestjs/common";
import { Prisma, UserRole } from "@prisma/client";
import { UsersService } from "../src/users/users.service";

const PLAN_CHILDREN = [
  "costPayment",
  "paymentSchedule",
  "weddingCost",
  "weddingTask",
  "guest",
  "guestGroup",
  "planProviderLink",
  "sharedMember",
  "planInvite",
  "budgetCategory",
];

function recordingTx(planIds: string[]) {
  const calls: string[] = [];
  const queries: Array<{ text: string; values: unknown[] }> = [];
  const del = (name: string) => ({
    deleteMany: async () => {
      calls.push(name);
      return { count: 1 };
    },
  });
  const tx: any = {
    $queryRaw: async (query: {
      strings?: readonly string[];
      values?: unknown[];
    }) => {
      const text = query.strings?.join("") ?? String(query);
      const values = query.values ?? [];
      queries.push({ text, values });
      if (text.includes('FROM "User"')) {
        calls.push("lockUser");
        return [{ id: "u1", role: UserRole.USER }];
      }
      if (text.includes('FROM "WeddingPlan"')) {
        calls.push("lockPlans");
        return [...planIds].sort().map((id) => ({ id }));
      }
      if (text.includes('FROM "WeddingCost"')) {
        calls.push("lockCosts");
        return planIds.map((id) => ({ id: `cost-${id}` }));
      }
      throw new Error(`Unexpected account-deletion lock query: ${text}`);
    },
    $executeRaw: async () => {
      calls.push("ledgerPurge");
      return 1;
    },
    weddingPlan: {
      deleteMany: async () => {
        calls.push("weddingPlan");
        return { count: planIds.length };
      },
    },
    provider: del("provider"),
    notification: {
      findMany: async () => [{ id: "notification-u1" }],
    },
    conversationParticipant: {
      findMany: async () => [{ conversationId: "conversation-u1" }],
    },
    outboxEvent: del("outboxEvent"),
    idempotencyKey: del("idempotencyKey"),
    otpCode: del("otpCode"),
    user: {
      delete: async () => {
        calls.push("user.delete");
        return {};
      },
    },
  };
  for (const child of PLAN_CHILDREN) tx[child] = del(child);
  return { tx, calls, queries };
}

const serviceFor = (
  tx: any,
  mediaStorage: any = {
    scheduleAllOwnedMediaDeletion: async () => [],
  },
) =>
  new UsersService(
    {
      user: { findUnique: async () => ({ role: UserRole.USER }) },
      $transaction: async (fn: any) => fn(tx),
    } as any,
    {} as any,
    mediaStorage,
  );

test("application account deletion can never erase an administrator identity", async () => {
  let transactions = 0;
  let mediaDeletes = 0;
  const service = new UsersService(
    {
      user: { findUnique: async () => ({ role: UserRole.ADMIN }) },
      $transaction: async () => {
        transactions += 1;
      },
    } as any,
    {} as any,
    {
      scheduleAllOwnedMediaDeletion: async () => {
        mediaDeletes += 1;
      },
    } as any,
  );

  await assert.rejects(
    () => service.deleteMe({ id: "admin", phone: null } as any),
    ForbiddenException,
  );
  assert.equal(transactions, 0);
  assert.equal(mediaDeletes, 0);
});

test("account deletion rolls back when durable media scheduling fails", async () => {
  const { tx, calls } = recordingTx([]);
  const svc = serviceFor(tx, {
    scheduleAllOwnedMediaDeletion: async () => {
      throw new Error("ticket scheduling unavailable");
    },
  });

  await assert.rejects(() => svc.deleteMe({ id: "u1", phone: null } as any));
  assert.deepEqual(calls, []);
});

test("account deletion clears plan children before plans and deletes the user last", async () => {
  const { tx, calls, queries } = recordingTx(["plan-2", "plan-1"]);
  const svc = serviceFor(tx);

  const result = await svc.deleteMe({
    id: "u1",
    phone: "+967700000000",
  } as any);
  assert.deepEqual(result, { deleted: true });

  const at = (name: string) => calls.indexOf(name);
  // Lock graph order is User -> ordered plans -> ordered costs -> payments.
  assert.ok(at("lockUser") < at("lockPlans"));
  assert.ok(at("lockPlans") < at("lockCosts"));
  assert.ok(at("lockCosts") < at("ledgerPurge"));
  assert.ok(at("lockCosts") < at("costPayment"));
  const planLock = queries.find((query) =>
    query.text.includes('FROM "WeddingPlan"'),
  );
  const costLock = queries.find((query) =>
    query.text.includes('FROM "WeddingCost"'),
  );
  assert.match(planLock?.text ?? "", /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.match(costLock?.text ?? "", /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.deepEqual(costLock?.values, ["plan-1", "plan-2"]);
  // The append-only ledger is unlocked only inside this transaction and
  // children are erased from ledger to category in dependency order.
  assert.ok(at("ledgerPurge") < at("costPayment"));
  assert.ok(at("costPayment") < at("paymentSchedule"));
  assert.ok(at("paymentSchedule") < at("weddingCost"));
  assert.ok(at("weddingCost") < at("budgetCategory"));
  // Every plan child is removed before the plan row itself.
  for (const child of PLAN_CHILDREN) {
    assert.ok(
      at(child) >= 0 && at(child) < at("weddingPlan"),
      `${child} before plan`,
    );
  }
  // Non-cascading rows are cleaned explicitly, and the user is deleted last.
  assert.ok(at("provider") >= 0);
  assert.ok(at("outboxEvent") >= 0 && at("outboxEvent") < at("user.delete"));
  assert.ok(at("idempotencyKey") >= 0);
  assert.ok(at("otpCode") >= 0);
  assert.ok(at("weddingPlan") < at("user.delete"));
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion with no owned plans still erases account-level data", async () => {
  const { tx, calls } = recordingTx([]);
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: "+967700000000" } as any);

  // No plan children or plan rows were touched.
  assert.equal(calls.includes("weddingPlan"), false);
  for (const child of PLAN_CHILDREN) assert.equal(calls.includes(child), false);
  // Account-level cleanup still ran.
  assert.ok(calls.includes("provider"));
  assert.ok(calls.includes("idempotencyKey"));
  assert.ok(calls.includes("otpCode"));
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion without a phone skips OTP cleanup", async () => {
  const { tx, calls } = recordingTx([]);
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: null } as any);

  assert.equal(calls.includes("otpCode"), false);
  assert.ok(calls.includes("idempotencyKey"));
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion retries a deadlock without changing its read-committed media snapshot", async () => {
  const { tx } = recordingTx([]);
  const transactionOptions: unknown[] = [];
  let attempts = 0;
  const prisma = {
    user: { findUnique: async () => ({ role: UserRole.USER }) },
    $transaction: async (
      operation: (value: any) => Promise<unknown>,
      options: unknown,
    ) => {
      transactionOptions.push(options);
      attempts += 1;
      if (attempts === 1) {
        throw new Prisma.PrismaClientKnownRequestError("deadlock", {
          code: "P2034",
          clientVersion: "test",
        });
      }
      return operation(tx);
    },
  };
  const service = new UsersService(
    prisma as any,
    {} as any,
    { scheduleAllOwnedMediaDeletion: async () => [] } as any,
  );

  assert.deepEqual(await service.deleteMe({ id: "u1", phone: null } as any), {
    deleted: true,
  });
  assert.equal(attempts, 2);
  assert.deepEqual(transactionOptions, [
    {
      timeout: 15_000,
      isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
    },
    {
      timeout: 15_000,
      isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted,
    },
  ]);
});
