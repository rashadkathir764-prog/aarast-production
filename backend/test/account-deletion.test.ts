import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma, UserRole } from "@prisma/client";
import { usersService } from "./support/owner-ports";

const PLAN_CHILDREN = [
  "costPayment",
  "paymentSchedule",
  "weddingCost",
  "fundingSource",
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
  /** V1 checklist 4.10: the account's private costs and tasks in other plans. */
  privateCostIds?: string[];
  privateTaskIds?: string[];
}

function recordingTx(
  planIds: string[],
  graph: RecordedGraph = {},
  userRole: UserRole = UserRole.USER,
) {
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
        return [{ id: "u1", role: userRole }];
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
    // B-12: the account's claims of listings go with it.
    providerClaimRequest: del("providerClaimRequest"),
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
    contributorTenure: {
      updateMany: async ({ data }: any) => {
        calls.push(
          data.actorUserId === null
            ? "contributorTenure.detachActor"
            : `contributorTenure.${data.endReason}`,
        );
        return { count: 1 };
      },
    },
    contributorHistoryScope: {
      updateMany: async ({ where, data }: any) => {
        calls.push("contributorHistoryScope.DELETED");
        assert.deepEqual(where, {
          weddingPlanId: { in: [...planIds].sort() },
        });
        assert.equal(data.status, "DELETED");
        assert.ok(data.deletedAt instanceof Date);
        return { count: planIds.length };
      },
    },
    accountDeletionReceipt: {
      findUnique: async () => null,
      create: async ({ data }: any) => {
        calls.push("accountDeletionReceipt.create");
        assert.match(data.receiptHash, /^[0-9a-f]{64}$/);
        return data;
      },
    },
    idempotencyKey: {
      deleteMany: async ({ where }: any) => {
        calls.push(
          where.NOT?.OR?.some(
            (entry: any) =>
              entry.path === "/admin" ||
              entry.path?.startsWith === "/admin/" ||
              entry.path === "/api/v1/admin" ||
              entry.path?.startsWith === "/api/v1/admin/" ||
              entry.path === "/api/v1/auth/admin" ||
              entry.path?.startsWith === "/api/v1/auth/admin/",
          )
            ? "idempotencyKey.APPLICATION"
            : "idempotencyKey",
        );
        return { count: 1 };
      },
    },
    otpCode: {
      deleteMany: async ({ where }: any) => {
        calls.push(where.purpose?.in ? "otpCode.APPLICATION" : "otpCode");
        return { count: 1 };
      },
    },
    refreshToken: {
      deleteMany: async ({ where }: any) => {
        calls.push(`refreshToken.${where.scope}`);
        return { count: 1 };
      },
    },
    user: {
      delete: async () => {
        calls.push("user.delete");
        return {};
      },
      update: async ({ data }: any) => {
        calls.push("user.clearApplicationIdentity");
        assert.equal(data.appPasswordHash, null);
        assert.equal(data.appName, null);
        assert.equal(data.appEmail, null);
        assert.equal(data.appAvatarUrl, null);
        assert.equal(data.activeWeddingPlanId, null);
        for (const retainedField of [
          "passwordHash",
          "name",
          "email",
          "avatarUrl",
          "role",
          "adminRole",
        ]) {
          assert.equal(retainedField in data, false);
        }
        return {};
      },
    },
  };
  for (const child of PLAN_CHILDREN) tx[child] = del(child);
  // V1 checklist 4.4: the erased plans' costs are read to find their
  // receipts, which go (with their files scheduled) before the ledger.
  tx.weddingCost.findMany = async ({ where }: any = {}) =>
    // V1 checklist 4.10: the account's private costs in other plans.
    where?.privateToUserId
      ? (graph.privateCostIds ?? []).map((id) => ({ id }))
      : planIds.map((id) => ({ id: `cost-${id}` }));
  tx.weddingTask.findMany = async () =>
    (graph.privateTaskIds ?? []).map((id) => ({ id }));
  tx.costReceipt = {
    findMany: async () => [],
    deleteMany: async () => {
      calls.push("costReceipt");
      return { count: 0 };
    },
  };
  tx.weddingTask.updateMany = async () => {
    calls.push("weddingTask.unassign");
    return { count: 1 };
  };
  tx.planInvite.updateMany = async () => {
    calls.push("planInvite.detachInvitee");
    return { count: 1 };
  };
  tx.conversation.updateMany = async () => {
    calls.push("conversation.detachActor");
    return { count: 1 };
  };
  for (const model of [
    "notificationPreference",
    "pushInstallation",
    "favoriteProvider",
    "conversationParticipant",
    "chatMessage",
    "conversationReport",
  ]) {
    tx[model] = del(model);
  }
  tx.conversationEvent = {
    updateMany: async () => {
      calls.push("conversationEvent.detachActor");
      return { count: 1 };
    },
  };
  return { tx, calls, queries };
}

const serviceFor = (
  tx: any,
  mediaStorage: any = {
    lockAccountDeletionBoundary: async () => {},
    scheduleAllOwnedMediaDeletion: async () => [],
  },
  realtime?: { disconnectUser: (userId: string) => void },
) =>
  usersService(
    {
      user: { findUnique: async () => ({ role: UserRole.USER }) },
      $transaction: async (fn: any) => fn(tx),
    } as any,
    {} as any,
    {
      lockAccountDeletionBoundary: async () => {},
      scheduleAllOwnedMediaDeletion: async () => [],
      ...mediaStorage,
    },
    realtime as any,
  );

test("application account deletion erases only the administrator's application identity", async () => {
  const { tx, calls } = recordingTx([], {}, UserRole.ADMIN);
  let adminMediaDeletes = 0;
  const service = usersService(
    {
      user: { findUnique: async () => ({ role: UserRole.ADMIN }) },
      $transaction: async (operation: (value: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {} as any,
    {
      lockAccountDeletionBoundary: async () => {},
      scheduleApplicationIdentityMediaDeletion: async () => {
        adminMediaDeletes += 1;
      },
    } as any,
  );

  assert.deepEqual(
    await service.deleteMe(
      {
        id: "u1",
        phone: "+967700000000",
        sessionScope: "application",
      } as any,
      "delete-admin-app",
    ),
    { deleted: true },
  );
  assert.equal(adminMediaDeletes, 1);
  assert.equal(calls.includes("user.delete"), false);
  assert.ok(calls.includes("user.clearApplicationIdentity"));
  assert.ok(calls.includes("refreshToken.APPLICATION"));
  assert.ok(calls.includes("otpCode.APPLICATION"));
  assert.ok(calls.includes("idempotencyKey.APPLICATION"));
  assert.equal(calls.includes("refreshToken.ADMIN"), false);
  assert.equal(calls.includes("otpCode.ADMIN"), false);
});

test("account deletion rolls back when durable media scheduling fails", async () => {
  const { tx, calls } = recordingTx([]);
  const svc = serviceFor(tx, {
    scheduleAllOwnedMediaDeletion: async () => {
      throw new Error("ticket scheduling unavailable");
    },
  });

  await assert.rejects(() =>
    svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1"),
  );
  assert.deepEqual(calls, ["lockUser"]);
});

test("account deletion clears plan children before plans and deletes the user last", async () => {
  const { tx, calls, queries } = recordingTx(["plan-2", "plan-1"], {
    conversationIds: ["conversation-plan"],
    quoteRequestIds: ["quote-2", "quote-1"],
    attachmentIds: ["attachment-provider"],
  });
  const svc = serviceFor(tx);

  const result = await svc.deleteMe(
    { id: "u1", phone: "+967700000000" } as any,
    "delete-u1",
  );
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
  assert.ok(
    at("contributorTenure.PLAN_DELETED") < at("sharedMember"),
    "owned-plan contributor tenures close before memberships are deleted",
  );
  assert.ok(
    at("contributorHistoryScope.DELETED") >= 0 &&
      at("contributorHistoryScope.DELETED") < at("weddingPlan"),
    "owned-plan history scopes become DELETED before their plan links are detached",
  );
  assert.ok(
    at("contributorTenure.ACCOUNT_DELETED") < at("user.delete"),
    "the deleting contributor tenure closes before user deletion",
  );
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
  assert.ok(
    at("providerClaimRequest") >= 0 &&
      at("providerClaimRequest") < at("user.delete"),
    "the account's claims of listings are removed before the user (B-12)",
  );
  assert.ok(at("outboxEvent") >= 0 && at("outboxEvent") < at("user.delete"));
  assert.ok(
    at("outboxEvent.create") >= 0 &&
      at("outboxEvent.create") < at("user.delete"),
    "the durable realtime revocation is enqueued before the user is deleted",
  );
  assert.ok(at("idempotencyKey") >= 0);
  assert.ok(at("accountDeletionReceipt.create") < at("idempotencyKey"));
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

  await svc.deleteMe(
    { id: "u1", phone: "+967700000000" } as any,
    "delete-u1",
  );

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

test("a partner's account deletion purges its private costs and tasks in the other plan (V1 4.10)", async () => {
  const { tx, calls, queries } = recordingTx([], {
    privateCostIds: ["private-cost"],
    privateTaskIds: ["private-task"],
  });
  const svc = serviceFor(tx);

  await svc.deleteMe(
    { id: "u1", phone: "+967700000000" } as any,
    "delete-u1",
  );

  const at = (name: string) => calls.indexOf(name);
  // The private costs are locked in the money mutation order, then their
  // ledger rows go before the costs, and the private tasks go too.
  assert.ok(
    queries.some(
      (query) =>
        query.text.includes('"privateToUserId"') &&
        query.text.includes("FOR UPDATE") &&
        query.values.includes("u1"),
    ),
  );
  assert.ok(at("ledgerPurge") >= 0 && at("ledgerPurge") < at("costPayment"));
  assert.ok(at("costPayment") < at("paymentSchedule"));
  assert.ok(at("paymentSchedule") < at("weddingCost"));
  assert.ok(at("weddingTask") >= 0 && at("weddingTask") < at("user.delete"));
  // The other plan itself is untouched.
  assert.equal(calls.includes("weddingPlan"), false);
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion without a phone skips OTP cleanup", async () => {
  const { tx, calls } = recordingTx([]);
  const svc = serviceFor(tx);

  await svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1");

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

  await svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1");

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

  await svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1");

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

  await svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1");

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

  await svc.deleteMe({ id: "u1", phone: null } as any, "delete-u1");

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
  const service = usersService(
    prisma as any,
    {} as any,
    {
      lockAccountDeletionBoundary: async () => {},
      scheduleAllOwnedMediaDeletion: async () => [],
    } as any,
  );

  assert.deepEqual(await service.deleteMe({ id: "u1", phone: null } as any, "delete-u1"), {
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
