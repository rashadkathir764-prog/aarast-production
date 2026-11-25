import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { Prisma, UserRole } from "@prisma/client";
import { newAccountDeletionReceiptHash } from "../src/modules/identity/internal/profile/users.service";
import { erasureNotices, usersService } from "./support/owner-ports";

// RA-BE-180: a cost's payments go through the database's eraser
// ("ledgerPurge" below), never a `costPayment.deleteMany`.
const PLAN_CHILDREN = [
  "paymentSchedule",
  "weddingCost",
  "fundingSource",
  "weddingTask",
  "guest",
  "guestGroup",
  // D83: the plan's invitation card.
  "guestInvitationCard",
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
  /** B-33: the owned provider's confirmed bookings from today on. */
  upcomingBookingIds?: string[];
  /** B-33: the open requests customers sent the owned provider. */
  openQuotes?: Array<{ id: string; userId: string; weddingPlanId: string | null }>;
  /** D63: the account's open requests whose providers are told it closed. */
  customerQuotes?: Array<{
    id: string;
    provider: { userId: string };
    booking: { status: string; eventDate: Date } | null;
  }>;
  /** D63: the members of the owned plans, told after the purge. */
  members?: Array<{ userId: string; weddingPlanId: string }>;
  /** D112 (Q-22): the account's requests inside plans it does not own. */
  memberPlanQuotes?: Array<{ id: string; weddingPlanId: string }>;
  /** D112 (Q-22): the plans the account takes part in, and their owners. */
  memberships?: Array<{ weddingPlanId: string; ownerUserId: string }>;
  /** The account's phone on its row (null skips the OTP cleanup). */
  phone?: string | null;
  /** D63: where the account's 30 days stand at the purge. */
  deletion?: "DUE" | "NOT_YET" | "TAKEN_BACK" | "GONE";
}

/** The purge's clock in these tests. */
const NOW = new Date("2026-11-27T09:00:00.000Z");
const DAY_MS = 24 * 60 * 60 * 1000;

function accountRow(graph: RecordedGraph, userRole: UserRole) {
  const deletion = graph.deletion ?? "DUE";
  if (deletion === "GONE") return [];
  const scheduledFor =
    deletion === "NOT_YET"
      ? new Date(NOW.getTime() + 60_000)
      : new Date(NOW.getTime() - 60_000);
  return [
    {
      id: "u1",
      role: userRole,
      name: "سلمان المنصور",
      phone: graph.phone === undefined ? "+967700000000" : graph.phone,
      persona: null,
      deletionRequestedAt:
        deletion === "TAKEN_BACK"
          ? null
          : new Date(scheduledFor.getTime() - 30 * DAY_MS),
      deletionScheduledFor: deletion === "TAKEN_BACK" ? null : scheduledFor,
    },
  ];
}

function recordingTx(
  planIds: string[],
  graph: RecordedGraph = {},
  userRole: UserRole = UserRole.USER,
) {
  const calls: string[] = [];
  const receipts: string[] = [];
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
        return accountRow(graph, userRole);
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
      if (text.includes('"aarast_erase_cost_ledger"')) {
        calls.push("ledgerPurge");
        return [];
      }
      if (text.includes('FROM "WeddingCost"')) {
        calls.push("lockCosts");
        return planIds.map((id) => ({ id: `cost-${id}` }));
      }
      if (text.includes('FROM "Conversation"')) {
        calls.push("lockConversations");
        return [...(graph.conversationIds ?? [])].sort().map((id) => ({ id }));
      }
      // D112 (Q-22): the account's requests inside plans it does not own,
      // locked apart from the ones that go with it.
      if (
        text.includes('FROM "QuoteRequest"') &&
        text.includes('"weddingPlanId" IS NOT NULL')
      ) {
        calls.push("lockMemberPlanQuoteRequests");
        return [...(graph.memberPlanQuotes ?? [])];
      }
      if (text.includes('FROM "QuoteRequest"')) {
        calls.push("lockQuoteRequests");
        return [...(graph.quoteRequestIds ?? [])].sort().map((id) => ({ id }));
      }
      throw new Error(`Unexpected account-deletion lock query: ${text}`);
    },
    $executeRaw: async () => {
      calls.push("executeRaw");
      return 1;
    },
    // D65: planning deletes the plans' events just before the plans.
    planEvent: {
      deleteMany: async () => {
        calls.push("planEvent");
        return { count: 0 };
      },
    },
    weddingPlan: {
      deleteMany: async () => {
        calls.push("weddingPlan");
        return { count: planIds.length };
      },
    },
    // RA-OP-32: the erased plans go on the re-deletion list.
    erasedPlan: {
      createMany: async ({ data, skipDuplicates }: any) => {
        calls.push("erasedPlan.record");
        assert.deepEqual(
          data.map((row: any) => row.weddingPlanId).sort(),
          [...planIds].sort(),
        );
        assert.ok(data.every((row: any) => row.erasedAt instanceof Date));
        assert.equal(skipDuplicates, true);
        return { count: planIds.length };
      },
    },
    provider: {
      findMany: async () =>
        [...(graph.providerIds ?? [])].sort().map((id) => ({ id })),
      updateMany: async ({ data }: any) => {
        // RA-BE-178: an erased listing is emptied, not deleted.
        calls.push(data.erasedAt ? "provider.erase" : "refreshProviderRating");
        if (data.erasedAt) tx.erasedProvider = data;
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
    // RA-ST-05: the reports the account made go with it.
    reviewReport: {
      deleteMany: async () => {
        calls.push("reviewReport");
        return { count: 0 };
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
    quoteRequest: {
      ...del("quoteRequest"),
      findMany: async ({ where }: any) =>
        // D63: the account's own open requests (by user or plan), whose
        // providers are told; else B-33: the requests to its listing.
        where?.OR
          ? (graph.customerQuotes ?? [])
          : (graph.openQuotes ?? []).map((quote) => ({
              ...quote,
              provider: { businessName: "ضيافة الأصالة" },
            })),
    },
    booking: {
      findMany: async () => {
        calls.push("readUpcomingBookings");
        return (graph.upcomingBookingIds ?? []).map((id) => ({ id }));
      },
    },
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
    // RA-OP-32: the erased account goes on the re-deletion list.
    erasedAccount: {
      createMany: async ({ data, skipDuplicates }: any) => {
        calls.push("erasedAccount.record");
        assert.deepEqual(data, [{ userId: "u1", erasedAt: NOW }]);
        assert.equal(skipDuplicates, true);
        return { count: 1 };
      },
    },
    accountDeletionReceipt: {
      findUnique: async () => null,
      create: async ({ data }: any) => {
        calls.push("accountDeletionReceipt.create");
        assert.match(data.receiptHash, /^[0-9a-f]{64}$/);
        receipts.push(data.receiptHash);
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
  tx.costPayment = del("costPayment");
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
    // RA-BE-178 (D112): his receipts on others' costs stay, with no uploader.
    updateMany: async ({ where, data }: any) => {
      calls.push("costReceipt.detachUploader");
      assert.deepEqual(where, { uploadedByUserId: "u1" });
      assert.deepEqual(data, { uploadedByUserId: null });
      return { count: 0 };
    },
  };
  // RA-BE-178: the erased plans' invitation cards, whose pictures go too.
  tx.guestInvitationCard.findMany = async () => [];
  // RA-BE-178: an erased listing's own data goes; the row stays.
  for (const model of [
    "providerService",
    "providerPackage",
    "portfolioItem",
    "providerBlockedDate",
    "providerProfileViewDay",
    "providerFeaturedPeriod",
    "providerReviewEvent",
    "providerProfileChange",
  ]) {
    tx[model] = del(model);
  }
  tx.quoteOffer = {
    updateMany: async ({ data }: any) => {
      calls.push(`quoteOffer.${data.status}`);
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
  tx.conversation.updateMany = async ({ data }: any) => {
    // RA-BE-178: an erased provider's conversations close; others detach.
    calls.push(data.closedAt ? "conversation.close" : "conversation.detachActor");
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
  // RA-BE-178: the messages stay, with no author.
  tx.chatMessage.updateMany = async ({ data }: any) => {
    assert.deepEqual(data, { senderUserId: null });
    calls.push("chatMessage.detachSender");
    return { count: 1 };
  };
  tx.conversationEvent = {
    updateMany: async () => {
      calls.push("conversationEvent.detachActor");
      return { count: 1 };
    },
  };
  // D112 (Q-22): what passes to the owners of the plans the account took
  // part in.
  const handedOver: Array<{ ids: string[]; data: Record<string, unknown> }> = [];
  tx.weddingPlan.findMany = async ({ where }: any) =>
    (graph.memberships ?? [])
      .filter((plan) => where.id.in.includes(plan.weddingPlanId))
      .map((plan) => ({ id: plan.weddingPlanId, ownerUserId: plan.ownerUserId }));
  tx.user.findMany = async ({ where }: any) =>
    where.id.in.map((id: string) => ({
      id,
      name: `صاحب ${id}`,
      appName: null,
      role: UserRole.USER,
      phone: `+9677${id.replace(/\D/gu, "").padStart(8, "0")}`,
    }));
  tx.quoteRequest.updateMany = async ({ where, data }: any) => {
    // RA-BE-178: what is open with an erased provider expires.
    if (data.status) {
      calls.push(`quoteRequest.${data.status}`);
      return { count: 0 };
    }
    calls.push("quoteRequest.handOver");
    assert.equal(where.userId, "u1");
    handedOver.push({ ids: where.id.in, data });
    return { count: where.id.in.length };
  };
  tx.booking = {
    ...(tx.booking ?? {}),
    updateMany: async ({ data }: any) => {
      if (data.status) {
        calls.push(`booking.${data.status}`);
        return { count: 0 };
      }
      calls.push("booking.handOver");
      assert.equal(typeof data.requestedByUserId, "string");
      return { count: 1 };
    },
  };
  tx.bookingChange = {
    ...(tx.bookingChange ?? {}),
    updateMany: async () => {
      calls.push("bookingChange.handOver");
      return { count: 0 };
    },
  };
  // D63: the members of the owned plans, read through collaboration's port.
  const permissions = {
    listPlanMembers: async (_client: unknown, weddingPlanIds: readonly string[]) => {
      calls.push("listPlanMembers");
      return (graph.members ?? []).filter((member) =>
        weddingPlanIds.includes(member.weddingPlanId),
      );
    },
    listMemberships: async () =>
      (graph.memberships ?? []).map((plan) => ({
        weddingPlanId: plan.weddingPlanId,
      })),
  };
  tx.handedOver = handedOver;
  return { tx, calls, queries, permissions, receipts };
}

const serviceFor = (
  tx: any,
  mediaStorage: any = {
    lockAccountDeletionBoundary: async () => {},
    scheduleAllOwnedMediaDeletion: async () => [],
  },
  realtime?: { disconnectUser: (userId: string) => void },
  permissions: unknown = { listPlanMembers: async () => [], listMemberships: async () => [] },
) =>
  usersService(
    {
      user: { findUnique: async () => ({ role: UserRole.USER }) },
      $transaction: async (fn: any) => fn(tx),
    } as any,
    permissions,
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
    { listPlanMembers: async () => [], listMemberships: async () => [] },
    {
      lockAccountDeletionBoundary: async () => {},
      scheduleApplicationIdentityMediaDeletion: async () => {
        adminMediaDeletes += 1;
      },
    } as any,
  );

  assert.equal(await service.eraseDueAccount("u1", NOW), "ERASED");
  assert.equal(adminMediaDeletes, 1);
  assert.equal(calls.includes("user.delete"), false);
  assert.ok(calls.includes("user.clearApplicationIdentity"));
  assert.ok(calls.includes("chatMessage.detachSender"));
  // RA-OP-32: an administrator keeps his row and may enrol again.
  assert.equal(calls.includes("erasedAccount.record"), false);
  assert.equal(calls.includes("chatMessage"), false, "his messages are not deleted");
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
    svc.eraseDueAccount("u1", NOW),
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

  const result = await svc.eraseDueAccount("u1", NOW);
  assert.equal(result, "ERASED");

  const at = (name: string) => calls.indexOf(name);
  // Lock graph order is User -> ordered plans -> ordered costs -> payments.
  assert.ok(at("lockUser") < at("lockPlans"));
  assert.equal(at("lockProviders"), -1);
  assert.ok(at("lockPlans") < at("lockCosts"));
  assert.ok(at("lockCosts") < at("ledgerPurge"));
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
  // RA-BE-180: the append-only ledger opens to the database's eraser only
  // (no session setting), and children are erased from ledger to category
  // in dependency order.
  assert.equal(at("costPayment"), -1);
  assert.equal(at("executeRaw"), -1);
  assert.ok(at("ledgerPurge") < at("paymentSchedule"));
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
  // RA-OP-32: the plans are listed for re-deletion once they are gone.
  assert.ok(at("weddingPlan") < at("erasedPlan.record"));
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
  assert.ok(
    at("erasedAccount.record") > at("accountDeletionReceipt.create") &&
      at("erasedAccount.record") < at("user.delete"),
    "RA-OP-32: the account is on the re-deletion list before it goes",
  );
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

  await svc.eraseDueAccount("u1", NOW);

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

  await svc.eraseDueAccount("u1", NOW);

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
  assert.ok(at("ledgerPurge") >= 0 && at("ledgerPurge") < at("paymentSchedule"));
  assert.equal(at("costPayment"), -1);
  assert.ok(at("paymentSchedule") < at("weddingCost"));
  assert.ok(at("weddingTask") >= 0 && at("weddingTask") < at("user.delete"));
  // The other plan itself is untouched.
  assert.equal(calls.includes("weddingPlan"), false);
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("account deletion without a phone skips OTP cleanup", async () => {
  const { tx, calls } = recordingTx([], { phone: null });
  const svc = serviceFor(tx);

  await svc.eraseDueAccount("u1", NOW);

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

  await svc.eraseDueAccount("u1", NOW);

  assert.equal(calls[calls.length - 1], "user.delete");
  assert.deepEqual(disconnected, ["u1"]);
});

// RA-BE-178: this test pinned the opposite («purges its quote
// conversations»): the listing was deleted, and its customers'
// conversations, requests, offers and bookings with it, leaving their
// agreements with no offer. They are the customers' records; the listing
// stays as «مزود محذوف», emptied of its own data, and they read them.
test("RA-BE-178: deleting a provider account keeps its customers' conversations, requests and offers", async () => {
  const { tx, calls, queries } = recordingTx([], {
    providerIds: ["provider-owned"],
    // His own conversation as a customer goes; his customers' are not asked for.
    conversationIds: ["own-account-conversation"],
    quoteRequestIds: ["own-quote"],
  });
  const svc = serviceFor(tx);

  await svc.eraseDueAccount("u1", NOW);

  const at = (name: string) => calls.indexOf(name);
  for (const lock of ['FROM "Conversation"', 'FROM "QuoteRequest"']) {
    for (const query of queries.filter((entry) => entry.text.includes(lock))) {
      assert.doesNotMatch(query.text, /"providerId"/u, `${lock} leaves his customers' rows`);
    }
  }
  assert.equal(calls.includes("provider"), false, "the listing row stays");
  assert.ok(at("conversation.close") >= 0, "his customers' conversations close");
  assert.ok(at("quoteRequest.EXPIRED") >= 0);
  assert.ok(at("quoteOffer.WITHDRAWN") >= 0);
  assert.ok(at("booking.EXPIRED") >= 0);
  assert.ok(at("provider.erase") >= 0 && at("provider.erase") < at("user.delete"));
  assert.equal(tx.erasedProvider.businessName, "مزود محذوف");
  assert.equal(tx.erasedProvider.phone, "");
  assert.equal(calls.includes("weddingPlan"), false);
  for (const child of PLAN_CHILDREN) assert.equal(calls.includes(child), false);
  assert.equal(calls[calls.length - 1], "user.delete");
});

test("B-33: a provider with a wedding still to do cannot delete his account, and nothing is erased", async () => {
  const { tx, calls } = recordingTx([], {
    providerIds: ["provider-owned"],
    upcomingBookingIds: ["booking-2", "booking-1"],
  });
  const svc = serviceFor(tx);

  await assert.rejects(
    svc.eraseDueAccount("u1", NOW),
    (error: any) =>
      error?.response?.code === "PROVIDER_HAS_UPCOMING_BOOKINGS" &&
      error.response.count === 2 &&
      error.response.bookingIds.join() === "booking-2,booking-1",
  );
  // Read under the provider's lock, before anything is purged.
  assert.ok(calls.indexOf("lockProviders") < calls.indexOf("readUpcomingBookings"));
  for (const purge of ["quoteRequest", "conversation", "provider", "notification", "user.delete"]) {
    assert.equal(calls.includes(purge), false, `${purge} is not erased`);
  }
});

test("B-33: customers with an open request are told «أغلق حسابه» after the purge", async () => {
  erasureNotices.written.length = 0;
  const { tx, calls } = recordingTx([], {
    providerIds: ["provider-owned"],
    quoteRequestIds: ["customer-quote-1"],
    openQuotes: [
      { id: "customer-quote-1", userId: "customer-1", weddingPlanId: "plan-9" },
      // His own request to himself is not a customer to tell.
      { id: "self-quote", userId: "u1", weddingPlanId: null },
    ],
  });
  const svc = serviceFor(tx);

  await svc.eraseDueAccount("u1", NOW);

  const notices = erasureNotices.written as any[];
  assert.equal(notices.length, 1);
  assert.equal(notices[0].userId, "customer-1");
  assert.equal(notices[0].title, "ضيافة الأصالة أغلق حسابه");
  assert.equal(notices[0].routeTarget, "/wedding-plans/plan-9/providers/requests");
  // The notice names nothing that is erased.
  assert.equal(notices[0].entityId, null);
  assert.equal(notices[0].data.quoteRequestId, undefined);
  assert.ok(calls.includes("quoteRequest"));
});

// D112 (Q-22), the owner's word: what a participant recorded in a plan
// stays in that plan. This test pinned the opposite for his requests
// («removes only that member's request»): the request went with his
// account and its confirmed booking with it, by cascade, and the plan's
// owner was told nothing (RA-BE-131). It passes to the plan's owner, with
// his contact, before the account's row goes; and he is told.
test("Q-22: a member's request in another person's plan passes to that plan's owner, who is told", async () => {
  const { tx, calls, queries, permissions } = recordingTx([], {
    memberPlanQuotes: [
      { id: "member-quote-2", weddingPlanId: "plan-of-owner-7" },
      { id: "member-quote-1", weddingPlanId: "plan-of-owner-7" },
    ],
    memberships: [
      { weddingPlanId: "plan-of-owner-7", ownerUserId: "owner-7" },
      // A plan he only took part in, with nothing requested: its owner is
      // told too, and nothing passes.
      { weddingPlanId: "plan-of-owner-9", ownerUserId: "owner-9" },
    ],
  });
  erasureNotices.written.length = 0;
  const svc = serviceFor(tx, undefined, undefined, permissions);

  await svc.eraseDueAccount("u1", NOW);
  const written = erasureNotices.written as any[];

  // The requests were handed over, not deleted, and before the row went.
  assert.deepEqual(tx.handedOver, [
    {
      ids: ["member-quote-2", "member-quote-1"],
      data: {
        userId: "owner-7",
        contactName: "صاحب owner-7",
        contactPhone: "+967700000007",
        contactNormalizedPhone: "+967700000007",
      },
    },
  ]);
  assert.ok(calls.includes("booking.handOver"));
  assert.ok(
    calls.indexOf("lockQuoteRequests") <
      calls.indexOf("lockMemberPlanQuoteRequests"),
  );
  assert.ok(calls.indexOf("quoteRequest.handOver") < calls.indexOf("user.delete"));
  const ownerNotices = written.filter(
    (notice) => notice.entityType === "plan_member_deletion",
  );
  assert.deepEqual(
    ownerNotices.map((notice) => [notice.userId, notice.weddingPlanId, notice.body]),
    [
      [
        "owner-7",
        "plan-of-owner-7",
        "انحذف حساب سلمان وما عاد في خطتك. اللي انسجّل في الخطة باقي، وطلبات العروض والحجوزات اللي انطلبت من هذا الحساب صارت باسمك.",
      ],
      [
        "owner-9",
        "plan-of-owner-9",
        "انحذف حساب سلمان وما عاد في خطتك. اللي انسجّل في الخطة باقي.",
      ],
    ],
  );
  // The lock that selects what goes with the account leaves them out.
  const deleteLock = queries.find(
    (query) =>
      query.text.includes('FROM "QuoteRequest"') &&
      !query.text.includes('"weddingPlanId" IS NOT NULL'),
  );
  assert.match(
    deleteLock?.text ?? "",
    /"userId" = \S*\s+AND \("weddingPlanId" IS NULL\s+OR "weddingPlanId" = ANY/u,
  );
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

  await svc.eraseDueAccount("u1", NOW);

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
    { listPlanMembers: async () => [], listMemberships: async () => [] },
    {
      lockAccountDeletionBoundary: async () => {},
      scheduleAllOwnedMediaDeletion: async () => [],
    } as any,
  );

  assert.equal(await service.eraseDueAccount("u1", NOW), "ERASED");
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

for (const [deletion, expected] of [
  ["NOT_YET", "NOT_DUE"],
  ["TAKEN_BACK", "NOT_DUE"],
  ["GONE", "GONE"],
] as const) {
  test(`D63: the purge erases nothing when the account is ${deletion}`, async () => {
    const { tx, calls } = recordingTx(["plan-1"], {
      deletion,
      providerIds: ["provider-owned"],
    });
    const disconnected: string[] = [];
    const svc = serviceFor(tx, undefined, {
      disconnectUser: (userId) => disconnected.push(userId),
    });

    assert.equal(await svc.eraseDueAccount("u1", NOW), expected);
    // Decided under the account's lock, before any other lock or purge.
    assert.deepEqual(calls, ["lockUser"]);
    assert.deepEqual(disconnected, []);
  });
}

test("D63: after the purge the members of its plans and the providers of its requests are told", async () => {
  erasureNotices.written.length = 0;
  const { tx, calls, permissions } = recordingTx(["plan-1"], {
    quoteRequestIds: ["quote-1", "quote-2"],
    members: [
      { userId: "member-1", weddingPlanId: "plan-1" },
      { userId: "member-2", weddingPlanId: "plan-1" },
    ],
    customerQuotes: [
      {
        id: "quote-1",
        provider: { userId: "provider-user-1" },
        booking: { status: "CONFIRMED", eventDate: new Date("2027-01-21T00:00:00.000Z") },
      },
      { id: "quote-2", provider: { userId: "provider-user-2" }, booking: null },
    ],
  });
  const svc = serviceFor(tx, undefined, undefined, permissions);

  assert.equal(await svc.eraseDueAccount("u1", NOW), "ERASED");

  const notices = erasureNotices.written as any[];
  const members = notices.filter((notice) => notice.type === "PLAN_UPDATED");
  assert.deepEqual(members.map((notice) => notice.userId).sort(), ["member-1", "member-2"]);
  for (const notice of members) {
    assert.equal(notice.title, "انحذفت خطة سلمان");
    assert.equal(notice.routeTarget, "/home");
    // The plan is gone: the notice names none.
    assert.equal(notice.weddingPlanId, null);
  }
  const providers = notices.filter((notice) => notice.type === "BOOKING_UPDATED");
  assert.deepEqual(providers.map((notice) => notice.userId).sort(), [
    "provider-user-1",
    "provider-user-2",
  ]);
  const booked = providers.find((notice) => notice.userId === "provider-user-1");
  // RA-BE-168: a provider reads the first name and the family's initial.
  assert.equal(booked.title, "سلمان م. حذف حسابه");
  assert.match(String(booked.body.masculine ?? booked.body), /انلغى/u);
  assert.equal(booked.routeTarget, "/provider/dashboard?tab=requests");
  // Built while the memberships existed; written after the purge.
  assert.ok(calls.indexOf("listPlanMembers") < calls.indexOf("sharedMember"));
});

// RA-BE-180: the receipt was the hash of the user's id and the request's day,
// so anyone who knew an id and roughly when it was asked could prove that
// account was erased. It is now a hash of a random 128-bit token made at the
// erasure and kept nowhere, so it names neither the account nor the day.
test("the deletion receipt is a hash of a random token, not of the account and its request day", async () => {
  const hashes: string[] = [];
  for (let run = 0; run < 2; run += 1) {
    const { tx, receipts } = recordingTx([]);
    await serviceFor(tx).eraseDueAccount("u1", NOW);
    assert.equal(receipts.length, 1);
    hashes.push(receipts[0]);
  }
  assert.notEqual(
    hashes[0],
    hashes[1],
    "the same account and request day gave the same receipt twice",
  );
  const requestedAt = new Date(NOW.getTime() - 60_000 - 30 * DAY_MS);
  const derivable = createHash("sha256")
    .update("u1")
    .update("\0")
    .update(`grace:${requestedAt.toISOString()}`)
    .digest("hex");
  assert.ok(!hashes.includes(derivable), "the receipt can be derived from the id and the day");
});

test("the receipt token is 128 random bits and its hash is what is stored", () => {
  const bytes = Buffer.from("00112233445566778899aabbccddeeff", "hex");
  let asked = 0;
  const hash = newAccountDeletionReceiptHash((size: number) => {
    asked = size;
    return bytes;
  });
  assert.equal(asked, 16);
  assert.equal(hash, createHash("sha256").update(bytes).digest("hex"));
  assert.notEqual(newAccountDeletionReceiptHash(), newAccountDeletionReceiptHash());
});
