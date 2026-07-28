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

interface RecordedGraph {
  providerIds?: string[];
  reviewedProviderIds?: string[];
  conversationIds?: string[];
  quoteRequestIds?: string[];
  attachmentIds?: string[];
}

function recordingTx(planIds: string[], graph: RecordedGraph = {}) {
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
      if (text.includes('FROM "Provider"')) {
        calls.push("lockProviders");
        return [
          ...new Set([
            ...(graph.providerIds ?? []),
            ...(graph.reviewedProviderIds ?? []),
          ]),
        ]
          .sort()
          .map((id) => ({ id }));
      }
      if (text.includes('FROM "WeddingCost"')) {
        calls.push("lockCosts");
        return planIds.map((id) => ({ id: `cost-${id}` }));
      }
      if (text.includes('FROM "Conversation"')) {
        calls.push("lockConversations");
        return [...(graph.conversationIds ?? [])].sort().map((id) => ({ id }));
      }
      if (text.includes('FROM "QuoteRequest"')) {
        calls.push("lockQuoteRequests");
        return [...(graph.quoteRequestIds ?? [])].sort().map((id) => ({ id }));
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
    provider: {
      findMany: async () =>
        [...(graph.providerIds ?? [])].sort().map((id) => ({ id })),
      updateMany: async () => {
        calls.push("refreshProviderRating");
        return { count: 1 };
      },
      ...del("provider"),
    },
    providerReview: {
      findMany: async () =>
        [...(graph.reviewedProviderIds ?? [])]
          .sort()
          .map((providerId) => ({ providerId })),
      aggregate: async () => ({
        _avg: { rating: null },
        _count: { _all: 0 },
      }),
      deleteMany: async () => {
        calls.push("providerReview");
        return { count: graph.reviewedProviderIds?.length ?? 0 };
      },
    },
    notification: {
      findMany: async () => [{ id: "notification-u1" }],
      deleteMany: async () => {
        calls.push("notification");
        return { count: 1 };
      },
    },
    chatAttachment: {
      findMany: async () => (graph.attachmentIds ?? []).map((id) => ({ id })),
    },
    mediaUploadTicket: {
      updateMany: async () => {
        calls.push("conversationAttachmentMedia");
        return { count: graph.attachmentIds?.length ?? 0 };
      },
    },
    quoteRequest: del("quoteRequest"),
    conversation: del("conversation"),
    outboxEvent: {
      ...del("outboxEvent"),
      create: async () => {
        calls.push("outboxEvent.create");
        return {};
      },
    },
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
  realtime?: { disconnectUser: (userId: string) => void },
) =>
  new UsersService(
    {
      user: { findUnique: async () => ({ role: UserRole.USER }) },
      $transaction: async (fn: any) => fn(tx),
    } as any,
    {} as any,
    mediaStorage,
    realtime as any,
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
  const { tx, calls, queries } = recordingTx(["plan-2", "plan-1"], {
    conversationIds: ["conversation-plan"],
    quoteRequestIds: ["quote-2", "quote-1"],
    attachmentIds: ["attachment-provider"],
  });
  const svc = serviceFor(tx);

  const result = await svc.deleteMe({
    id: "u1",
    phone: "+967700000000",
  } as any);
  assert.deepEqual(result, { deleted: true });

  const at = (name: string) => calls.indexOf(name);
  // Lock graph order is User -> ordered plans -> ordered costs -> payments.
  assert.ok(at("lockUser") < at("lockPlans"));
  assert.equal(at("lockProviders"), -1);
  assert.ok(at("lockPlans") < at("lockCosts"));
  assert.ok(at("lockCosts") < at("ledgerPurge"));
  assert.ok(at("lockCosts") < at("costPayment"));
  assert.ok(at("lockCosts") < at("lockConversations"));
  assert.ok(at("lockConversations") < at("lockQuoteRequests"));
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
  // The Restrict edge is cleared before the owned Conversation/Plan graph.
  assert.ok(at("quoteRequest") < at("conversation"));
  assert.ok(at("conversation") < at("weddingPlan"));
  assert.ok(
    at("conversationAttachmentMedia") < at("conversation"),
    "conversation media is scheduled before its attachment cascades",
  );
  // Every plan child is removed before the plan row itself.
  for (const child of PLAN_CHILDREN) {
    assert.ok(
      at(child) >= 0 && at(child) < at("weddingPlan"),
      `${child} before plan`,
    );
  }
  // Non-cascading rows are cleaned explicitly, and the user is deleted last.
  assert.equal(at("provider"), -1);
  assert.ok(at("outboxEvent") >= 0 && at("outboxEvent") < at("user.delete"));
  assert.ok(
    at("outboxEvent.create") >= 0 &&
      at("outboxEvent.create") < at("user.delete"),
    "the durable realtime revocation is enqueued before the user is deleted",
  );
  assert.ok(at("idempotencyKey") >= 0);
  assert.ok(at("otpCode") >= 0);
  assert.ok(at("weddingPlan") < at("user.delete"));
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion with no owned plans still erases account-level data", async () => {
  const { tx, calls } = recordingTx([], {
    conversationIds: ["account-conversation"],
    quoteRequestIds: ["account-quote"],
  });
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: "+967700000000" } as any);

  // No plan children or plan rows were touched.
  assert.equal(calls.includes("weddingPlan"), false);
  for (const child of PLAN_CHILDREN) assert.equal(calls.includes(child), false);
  // Account-level cleanup still ran.
  assert.ok(calls.includes("quoteRequest"));
  assert.ok(calls.includes("conversation"));
  assert.equal(calls.includes("provider"), false);
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

test("account deletion disconnects live realtime sessions only after commit", async () => {
  const { tx, calls } = recordingTx([]);
  const disconnected: string[] = [];
  const svc = serviceFor(
    tx,
    { scheduleAllOwnedMediaDeletion: async () => [] },
    { disconnectUser: (userId) => disconnected.push(userId) },
  );

  await svc.deleteMe({ id: "u1", phone: null } as any);

  assert.equal(calls[calls.length - 1], "user.delete");
  assert.deepEqual(disconnected, ["u1"]);
});

test("deleting a provider account purges its quote conversations without touching customer plans", async () => {
  const { tx, calls } = recordingTx([], {
    providerIds: ["provider-owned"],
    conversationIds: [
      "customer-plan-conversation-2",
      "customer-plan-conversation-1",
    ],
    quoteRequestIds: ["customer-quote-2", "customer-quote-1"],
  });
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: null } as any);

  const at = (name: string) => calls.indexOf(name);
  assert.ok(at("quoteRequest") < at("conversation"));
  assert.ok(at("conversation") < at("provider"));
  assert.equal(calls.includes("weddingPlan"), false);
  for (const child of PLAN_CHILDREN) assert.equal(calls.includes(child), false);
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("deleting a shared member removes only that member's request and preserves the owner's conversation", async () => {
  const { tx, calls, queries } = recordingTx([], {
    quoteRequestIds: ["member-authored-quote"],
  });
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: null } as any);

  assert.ok(calls.includes("quoteRequest"));
  assert.equal(calls.includes("conversation"), false);
  assert.equal(calls.includes("weddingPlan"), false);
  const conversationLock = queries.find((query) =>
    query.text.includes('FROM "Conversation"'),
  );
  assert.match(conversationLock?.text ?? "", /"accountRequesterUserId"\s*=\s*/);
  assert.doesNotMatch(conversationLock?.text ?? "", /Participant/);
});

test("account deletion refreshes every surviving provider reviewed by the user", async () => {
  const { tx, calls, queries } = recordingTx([], {
    reviewedProviderIds: ["provider-z", "provider-a"],
  });
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: null } as any);

  const providerLock = queries.find((query) =>
    query.text.includes('FROM "Provider"'),
  );
  assert.match(providerLock?.text ?? "", /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.deepEqual(providerLock?.values, ["provider-a", "provider-z"]);
  assert.ok(calls.indexOf("lockProviders") < calls.indexOf("providerReview"));
  assert.ok(
    calls.indexOf("providerReview") < calls.indexOf("refreshProviderRating"),
  );
  assert.ok(
    calls.lastIndexOf("refreshProviderRating") < calls.indexOf("user.delete"),
  );
  assert.equal(
    calls.filter((call) => call === "refreshProviderRating").length,
    2,
  );
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
