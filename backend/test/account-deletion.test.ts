import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { UsersService } from "../src/users/users.service";

const PLAN_CHILDREN = [
  "financialPaymentRecord",
  "financialInstallment",
  "expense",
  "financialCommitment",
  "debt",
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
  const del = (name: string) => ({
    deleteMany: async () => {
      calls.push(name);
      return { count: 1 };
    },
  });
  const tx: any = {
    weddingPlan: {
      findMany: async () => planIds.map((id) => ({ id })),
      deleteMany: async () => {
        calls.push("weddingPlan");
        return { count: planIds.length };
      },
    },
    provider: del("provider"),
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
  return { tx, calls };
}

const serviceFor = (tx: any) =>
  new UsersService({ $transaction: async (fn: any) => fn(tx) } as any);

test("account deletion clears plan children before plans and deletes the user last", async () => {
  const { tx, calls } = recordingTx(["plan-1", "plan-2"]);
  const svc = serviceFor(tx);

  const result = await svc.deleteMe({
    id: "u1",
    phone: "+967700000000",
  } as any);
  assert.deepEqual(result, { deleted: true });

  const at = (name: string) => calls.indexOf(name);
  // Restrict parents (budgetCategory, financialCommitment) come after their refs.
  assert.ok(at("financialPaymentRecord") < at("financialCommitment"));
  assert.ok(at("financialInstallment") < at("financialCommitment"));
  assert.ok(at("expense") < at("budgetCategory"));
  assert.ok(at("financialCommitment") < at("budgetCategory"));
  // Every plan child is removed before the plan row itself.
  for (const child of PLAN_CHILDREN) {
    assert.ok(at(child) >= 0 && at(child) < at("weddingPlan"), `${child} before plan`);
  }
  // Non-cascading rows are cleaned explicitly, and the user is deleted last.
  assert.ok(at("provider") >= 0);
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
