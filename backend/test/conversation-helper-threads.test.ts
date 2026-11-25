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
