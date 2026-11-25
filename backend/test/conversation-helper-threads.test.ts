import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConversationScope, SharedMemberRole } from "@prisma/client";
import { ensureConversationContext } from "../src/conversations/conversation-lifecycle";
import { planThreadHelperUserId } from "../src/marketplace/quote-request-creation";
import { conversationsService } from "./support/owner-ports";

// RA-BE-139 (Q-33 (أ)): a plan's provider conversations are one per plan,
// provider and requester side. The owner and the partners share one thread;
// each helper who asks gets his own with that provider.

function lifecycleClient() {
  const statements: Array<{ sql: string; values: unknown[] }> = [];
  const participants: unknown[] = [];
  const tx = {
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => {
      statements.push({
        sql: query.strings.join("?").replace(/\s+/g, " ").trim(),
        values: query.values,
      });
      return [{ id: "conversation-1" }];
    },
    conversationParticipant: {
      createMany: async (args: unknown) => {
        participants.push(args);
        return { count: 2 };
      },
    },
  } as any;
  const owners = {
    plans: { getPlan: async () => ({ id: "plan-1", ownerUserId: "owner" }) },
    providers: { getProvider: async () => ({ id: "provider-1", userId: "provider-user" }) },
  } as any;
  return { tx, owners, statements, participants };
}

test("RA-BE-139: the owner's side asks into the plan's one shared thread with the provider", async () => {
  const { tx, owners, statements } = lifecycleClient();
  const at = new Date("2026-11-25T10:00:00Z");
  await ensureConversationContext(
    tx,
    { requesterUserId: "bride", providerId: "provider-1", weddingPlanId: "plan-1", helperUserId: null, activityAt: at },
    owners,
  );
  assert.equal(statements.length, 1);
  assert.match(statements[0].sql, /"helperThread"/);
  assert.match(
    statements[0].sql,
    /ON CONFLICT \("weddingPlanId", "providerId"\) WHERE "scope" = 'PLAN' AND NOT "helperThread"/,
  );
  assert.equal(statements[0].values.includes("bride"), true, "the thread's creator");
});

test("RA-BE-139: a helper asks into his own thread with the provider, the owner and the provider in it", async () => {
  const { tx, owners, statements, participants } = lifecycleClient();
  const at = new Date("2026-11-25T10:00:00Z");
  const result = await ensureConversationContext(
    tx,
    { requesterUserId: "helper", providerId: "provider-1", weddingPlanId: "plan-1", helperUserId: "helper", activityAt: at },
    owners,
  );
  assert.deepEqual(result, { id: "conversation-1", scope: ConversationScope.PLAN });
  assert.equal(statements.length, 1);
  assert.match(
    statements[0].sql,
    /ON CONFLICT \("weddingPlanId", "providerId", "helperUserId"\) WHERE "scope" = 'PLAN' AND "helperThread"/,
  );
  assert.deepEqual(
    statements[0].values.filter((value) => value === "helper"),
    ["helper", "helper"],
    "the helper keys the thread and created it",
  );
  assert.deepEqual(participants, [
    {
      data: [
        { conversationId: "conversation-1", userId: "owner", joinedAt: at },
        { conversationId: "conversation-1", userId: "provider-user", joinedAt: at },
      ],
      skipDuplicates: true,
    },
  ]);
});

test("RA-BE-139: an account's request without a plan keeps its one ACCOUNT thread", async () => {
  const { tx, owners, statements } = lifecycleClient();
  await ensureConversationContext(
    tx,
    { requesterUserId: "user-1", providerId: "provider-1", weddingPlanId: null, helperUserId: null },
    owners,
  );
  assert.match(statements[0].sql, /ON CONFLICT \("accountRequesterUserId", "providerId"\) WHERE "scope" = 'ACCOUNT'/);
  assert.doesNotMatch(statements[0].sql, /helper/);
});

test("RA-BE-139: the owner and a partner ask for the shared thread; every other member for his own", () => {
  const member = (role: SharedMemberRole) => ({ isOwner: false, sharedMember: { userId: "member", role } }) as any;
  assert.equal(planThreadHelperUserId(null, "user-1"), null, "no plan: no helper thread");
  assert.equal(planThreadHelperUserId({ isOwner: true, sharedMember: null } as any, "owner"), null);
  assert.equal(planThreadHelperUserId(member(SharedMemberRole.BRIDE), "member"), null);
  assert.equal(planThreadHelperUserId(member(SharedMemberRole.GROOM), "member"), null);
  for (const role of [
    SharedMemberRole.HELPER,
    SharedMemberRole.MANAGER,
    SharedMemberRole.FAMILY,
    SharedMemberRole.EDITOR,
    SharedMemberRole.FINANCE_MANAGER,
    SharedMemberRole.CONTRIBUTOR,
  ]) {
    assert.equal(planThreadHelperUserId(member(role), "member"), "member", role);
  }
});

test("RA-BE-139: a helper's thread is read by him, the owner and a partner, and not by another helper", () => {
  const service = conversationsService({} as any, {} as any, {} as any, {} as any, {} as any);
  const member = (userId: string, role: SharedMemberRole) => ({
    userId,
    role,
    canManageProviders: true,
    canViewMoney: false,
    canManageMoney: false,
  });
  const thread = (helperUserId: string | null, requesterUserIds: string[]) => ({
    scope: ConversationScope.PLAN,
    accountRequesterUserId: null,
    helperThread: helperUserId !== null,
    helperUserId,
    provider: { userId: "provider", status: "ACTIVE" },
    requesterUserIds,
    weddingPlan: {
      ownerUserId: "owner",
      sharedMembers: [
        member("helper", SharedMemberRole.HELPER),
        member("other", SharedMemberRole.HELPER),
        member("bride", SharedMemberRole.BRIDE),
      ],
    },
  });
  const reads = (record: unknown, userId: string) => (service as any).accessFor(record, userId) !== null;

  const helpers = thread("helper", ["helper"]);
  assert.equal(reads(helpers, "helper"), true);
  assert.equal(reads(helpers, "owner"), true);
  assert.equal(reads(helpers, "bride"), true);
  assert.equal(reads(helpers, "other"), false);

  // The owner's thread with the same provider stays closed to the helper.
  const owners = thread(null, ["owner", "bride"]);
  assert.equal(reads(owners, "helper"), false);
  assert.equal(reads(owners, "bride"), true);

  // The provider's message in the helper's thread reaches the helper, the
  // owner and the partner; in the owner's thread, not the helper.
  assert.deepEqual((service as any).messageRecipientIds(helpers, "PROVIDER", "provider").sort(), ["bride", "helper", "owner"]);
  assert.deepEqual((service as any).messageRecipientIds(owners, "PROVIDER", "provider").sort(), ["bride", "owner"]);
});

// RA-BE-139: a block is the plan's with the provider, not one thread's. The
// provider's, the owner's and a partner's reach every thread of the plan
// with that provider; a helper's own reaches his thread only.
function blockHarness(options: {
  scope?: ConversationScope;
  helperUserId?: string | null;
  customerSideBlockedById?: string | null;
}) {
  const calls: Array<[string, ...unknown[]]> = [];
  const service = conversationsService(
    { $transaction: async (fn: any) => fn({}) },
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );
  const scope = options.scope ?? ConversationScope.PLAN;
  const current = {
    id: "thread-helper",
    scope,
    weddingPlanId: scope === ConversationScope.PLAN ? "plan-1" : null,
    providerId: "provider-1",
    helperThread: Boolean(options.helperUserId),
    helperUserId: options.helperUserId ?? null,
    customerSideBlockedAt: options.customerSideBlockedById ? new Date() : null,
    customerSideBlockedById: options.customerSideBlockedById ?? null,
    providerSideBlockedAt: null,
    weddingPlan: scope === ConversationScope.PLAN
      ? {
          ownerUserId: "owner",
          sharedMembers: [
            { userId: "bride", role: SharedMemberRole.BRIDE, canManageProviders: true },
            { userId: "helper", role: SharedMemberRole.HELPER, canManageProviders: true },
          ],
        }
      : null,
  };
  (service as any).assertActiveAccessInTransaction = async (_tx: unknown, user: { id: string }) => ({
    conversation: current,
    access: { side: user.id === "provider-user" ? "PROVIDER" : "CUSTOMER" },
    activeLifecycleUserIds: new Set([user.id]),
  });
  (service as any).repository = {
    lockPlanProviderThreads: async (...args: unknown[]) => {
      calls.push(["lockPlanProviderThreads", ...args.slice(1)]);
      return ["thread-helper", "thread-owner", "thread-other-helper"];
    },
    setConversationBlocked: async (...args: unknown[]) => {
      calls.push(["setConversationBlocked", ...args.slice(1, 5)]);
      return { count: 1 };
    },
    findConversationBlockState: async () => ({
      customerSideBlockedAt: new Date(),
      customerSideBlockedById: "owner",
      providerSideBlockedAt: null,
    }),
  };
  return { service, calls };
}

const everyThread = ["thread-helper", "thread-owner", "thread-other-helper"];

test("RA-BE-139: the provider's block reaches every thread of the plan with him, in one write", async () => {
  const { service, calls } = blockHarness({ helperUserId: "helper" });
  await service.setBlocked({ id: "provider-user" } as any, "thread-helper", true);
  assert.deepEqual(calls, [
    ["lockPlanProviderThreads", "plan-1", "provider-1"],
    ["setConversationBlocked", everyThread, "provider-user", true, true],
  ]);
});

test("RA-BE-139: the owner's and a partner's block and unblock reach every thread of the plan", async () => {
  const owner = blockHarness({ helperUserId: "helper" });
  await owner.service.setBlocked({ id: "owner" } as any, "thread-helper", true);
  assert.deepEqual(owner.calls, [
    ["lockPlanProviderThreads", "plan-1", "provider-1"],
    ["setConversationBlocked", everyThread, "owner", false, true],
  ]);
  const bride = blockHarness({ customerSideBlockedById: "bride" });
  await bride.service.setBlocked({ id: "bride" } as any, "thread-helper", false);
  assert.deepEqual(bride.calls, [
    ["lockPlanProviderThreads", "plan-1", "provider-1"],
    ["setConversationBlocked", everyThread, "bride", false, false],
  ]);
});

test("RA-BE-139: the owner's block reaches the other threads even where this one is already a helper's block", async () => {
  const { service, calls } = blockHarness({ helperUserId: "helper", customerSideBlockedById: "helper" });
  await service.setBlocked({ id: "owner" } as any, "thread-helper", true);
  assert.deepEqual(calls, [
    ["lockPlanProviderThreads", "plan-1", "provider-1"],
    ["setConversationBlocked", everyThread, "owner", false, true],
  ]);
});

test("RA-BE-139: a helper's own block stays on his thread, and an account thread's on itself", async () => {
  const helper = blockHarness({ helperUserId: "helper" });
  await helper.service.setBlocked({ id: "helper" } as any, "thread-helper", true);
  assert.deepEqual(helper.calls, [["setConversationBlocked", ["thread-helper"], "helper", false, true]]);
  const account = blockHarness({ scope: ConversationScope.ACCOUNT });
  await account.service.setBlocked({ id: "provider-user" } as any, "thread-helper", true);
  assert.deepEqual(account.calls, [["setConversationBlocked", ["thread-helper"], "provider-user", true, true]]);
});

test("RA-BE-139: a block is written once per thread and only where it changes the thread", async () => {
  const { ConversationsRepository } = require("../src/modules/messaging/infrastructure/conversations.repository");
  const writes: unknown[] = [];
  const tx = { conversation: { updateMany: async (args: unknown) => { writes.push(args); return { count: 2 }; } } };
  const repository = new ConversationsRepository();
  const at = new Date("2026-11-25T10:00:00Z");
  await repository.setConversationBlocked(tx, ["a", "b"], "owner", false, true, at);
  await repository.setConversationBlocked(tx, ["a", "b"], "owner", false, false, at);
  await repository.setConversationBlocked(tx, ["a", "b"], "provider-user", true, true, at);
  await repository.setConversationBlocked(tx, ["a", "b"], "provider-user", true, false, at);
  assert.deepEqual(writes, [
    { where: { id: { in: ["a", "b"] }, customerSideBlockedAt: null }, data: { customerSideBlockedAt: at, customerSideBlockedById: "owner" } },
    // The blocker lifts his own block; a helper's own block on his thread stays.
    {
      where: { id: { in: ["a", "b"] }, customerSideBlockedAt: { not: null }, OR: [{ customerSideBlockedById: "owner" }, { customerSideBlockedById: null }] },
      data: { customerSideBlockedAt: null, customerSideBlockedById: null },
    },
    { where: { id: { in: ["a", "b"] }, providerSideBlockedAt: null }, data: { providerSideBlockedAt: at } },
    { where: { id: { in: ["a", "b"] }, providerSideBlockedAt: { not: null } }, data: { providerSideBlockedAt: null } },
  ]);
});

test("RA-BE-139: a helper's new thread starts with the plan's block with the provider", async () => {
  const { tx, owners, statements } = lifecycleClient();
  await ensureConversationContext(
    tx,
    { requesterUserId: "helper", providerId: "provider-1", weddingPlanId: "plan-1", helperUserId: "helper" },
    owners,
  );
  const sql = statements[0].sql;
  // The provider's side from any thread of the plan with him; the owner's
  // side as it stands on the shared thread.
  assert.match(sql, /max\("providerSideBlockedAt"\)/);
  assert.match(sql, /shared\."customerSideBlockedAt", shared\."customerSideBlockedById"/);
  assert.match(sql, /NOT shared\."helperThread"/);
});

test("RA-BE-139: a helper's thread says whose request it is to the plan's other readers", async () => {
  const service = conversationsService({} as any, {} as any, {} as any, {} as any, {} as any);
  const record = (helperUser: unknown, helperUserId: string | null) => ({
    id: "thread-helper",
    scope: ConversationScope.PLAN,
    weddingPlanId: "plan-1",
    accountRequesterUserId: null,
    helperThread: true,
    helperUserId,
    helperUser,
    providerId: "provider-1",
    provider: { id: "provider-1", userId: "provider-user", status: "ACTIVE", businessName: "قاعة", logoUrl: null, user: null },
    weddingPlan: {
      id: "plan-1", title: "عرس", ownerUserId: "owner", status: "ACTIVE", deletionRequestedAt: null,
      sharedMembers: [{ userId: "helper", role: SharedMemberRole.HELPER, canManageProviders: true, canViewMoney: false, canManageMoney: false }],
    },
    participants: ["owner", "helper", "provider-user"].map((userId) => ({ userId, revokedAt: null, mutedAt: null })),
    quoteRequests: [],
    requesterUserIds: ["helper"],
    messages: [],
    _count: { quoteRequests: 1 },
    closedAt: null,
    customerSideBlockedAt: null,
    customerSideBlockedById: null,
    providerSideBlockedAt: null,
  });
  const salem = { id: "helper", name: "سالم أحمد", phone: null, avatarUrl: null, appRole: "USER" };
  const view = (userId: string, row: unknown) => (service as any).toConversationResponse(userId, row, 0);
  assert.deepEqual((await view("owner", record(salem, "helper"))).throughHelper, { name: "سالم أحمد" });
  assert.equal((await view("helper", record(salem, "helper"))).throughHelper, null, "not to the helper himself");
  assert.equal((await view("provider-user", record(salem, "helper"))).throughHelper, null, "the provider reads the requester already");
  // RA-BE-178: an erased helper is a former member.
  assert.deepEqual((await view("owner", record(null, null))).throughHelper, { name: null });
  const shared = { ...record(null, null), helperThread: false };
  assert.equal((await view("owner", shared)).throughHelper, null);
});
