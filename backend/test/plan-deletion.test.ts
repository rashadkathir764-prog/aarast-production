import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException, NotFoundException } from "@nestjs/common";
import { UserRole, UserStatus, WeddingPersona, WeddingPlanStatus } from "@prisma/client";
import {
  assertWeddingPlanWritable,
  isWeddingPlanWritable,
  PLAN_DELETION_PENDING,
} from "../src/modules/collaboration/public/collaboration-permission.port";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { PlanDeletionPurgeService } from "../src/modules/identity/internal/profile/plan-deletion-purge.service";
import { PlanErasureService } from "../src/modules/planning/infrastructure/plan-erasure.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";
import {
  PLAN_DELETION_GRACE_DAYS,
  PlanDeletionService,
} from "../src/wedding-plans/plan-deletion.service";

// Q-45 (D124), RA-BE-179: a plan could only be archived, and kept its
// guests' numbers, invitations and everything else for ever. Its owner may
// now delete it, live or archived: it closes to its members and stays
// read-only to him for 30 days, when he can take it back as it was; then
// the hourly purge erases it with everything in it.

const DAY_MS = 24 * 60 * 60 * 1000;
const OWNER = { id: "owner-1" } as any;
const MEMBER = { id: "member-1" } as any;

interface PlanRow {
  id: string;
  ownerUserId: string;
  title: string;
  persona: WeddingPersona | null;
  status: WeddingPlanStatus;
  deletionRequestedAt: Date | null;
  deletionScheduledFor: Date | null;
}

/** One plan row, read and written as planning's statements do. */
function planStore(status: WeddingPlanStatus = WeddingPlanStatus.PLANNING) {
  const row: PlanRow = {
    id: "plan-1",
    ownerUserId: OWNER.id,
    title: "عرس محمد",
    persona: WeddingPersona.GROOM,
    status,
    deletionRequestedAt: null,
    deletionScheduledFor: null,
  };
  let erased = false;
  const tx: any = {
    weddingPlan: {
      update: async ({ where, data }: any) => {
        assert.equal(where.id, row.id);
        Object.assign(row, data);
        return { ...row };
      },
      findUnique: async () => (erased ? null : { ...row }),
      findMany: async ({ where, take }: any) => {
        const due = where.deletionScheduledFor.lte as Date;
        return !erased &&
          row.deletionScheduledFor !== null &&
          row.deletionScheduledFor.getTime() <= due.getTime()
          ? [{ id: row.id, ownerUserId: row.ownerUserId }].slice(0, take)
          : [];
      },
    },
    $queryRaw: async (query: { strings: readonly string[]; values: unknown[] }) => {
      const text = query.strings.join("?");
      if (text.includes('FROM "User"')) {
        return [{ id: OWNER.id, name: "محمد علي", role: UserRole.USER }];
      }
      if (text.includes('FROM "WeddingPlan"') && text.includes('"deletionScheduledFor" <=')) {
        const now = query.values[1] as Date;
        return !erased &&
          row.deletionScheduledFor !== null &&
          row.deletionScheduledFor.getTime() <= now.getTime()
          ? [{ id: row.id }]
          : [];
      }
      throw new Error(`Unexpected query: ${text}`);
    },
  };
  return { row, tx, markErased: () => (erased = true) };
}

function deletionService(store: ReturnType<typeof planStore>) {
  const notices: any[] = [];
  const revoked: string[] = [];
  const service = new PlanDeletionService(
    { $transaction: async (work: any) => work(store.tx) } as any,
    { findOne: async () => ({ ...store.row }) } as any,
    {
      assertPlanReadableForUserUpdateInTransaction: async (
        _tx: unknown,
        _planId: string,
        user: { id: string },
      ) => ({
        plan: { ...store.row },
        isOwner: user.id === store.row.ownerUserId,
        sharedMember: null,
      }),
      revokeLivePlanInvitesInTransaction: async (_tx: unknown, planId: string) => {
        revoked.push(planId);
      },
      listPlanMembers: async () => [{ userId: MEMBER.id, weddingPlanId: "plan-1" }],
    } as any,
    {
      createNotificationInTransaction: async (_tx: unknown, notice: unknown) => {
        notices.push(notice);
        return null;
      },
    } as any,
    {
      getAppIdentities: async () => [
        { id: OWNER.id, name: "محمد علي", appName: null, role: UserRole.USER },
      ],
    } as any,
  );
  return { service, notices, revoked };
}

/** The shared purge's steps, recorded with what they were asked to remove. */
function recordingGraph() {
  const calls: Array<[string, unknown[]]> = [];
  const port = (name: string) =>
    new Proxy(
      {},
      {
        get: (_target, method: string) => async (...args: unknown[]) => {
          calls.push([`${name}.${method}`, args.slice(1)]);
          if (/^(list|lock|closed)/u.test(method)) return [];
          return undefined;
        },
      },
    );
  const ports = {
    mediaStorage: port("media"),
    planErasure: port("planning"),
    marketplaceErasure: port("marketplace"),
    messagingErasure: port("messaging"),
    notificationsErasure: port("notifications"),
    collaborationErasure: port("collaboration"),
    finance: port("finance"),
    tasks: port("tasks"),
    guests: port("guests"),
  };
  return { ports, calls };
}

function purgeService(store: ReturnType<typeof planStore>) {
  const graph = recordingGraph();
  const plans = new PlanErasureService();
  // planning's own reads of the due plans; the deletion itself is recorded.
  graph.ports.planErasure = {
    listDuePlanDeletions: plans.listDuePlanDeletions.bind(plans),
    lockDuePlanForUpdateInTransaction: plans.lockDuePlanForUpdateInTransaction.bind(plans),
    deletePlansInTransaction: async (_tx: unknown, ids: readonly string[]) => {
      graph.calls.push(["planning.deletePlansInTransaction", [ids]]);
      store.markErased();
    },
  } as any;
  const service = new PlanDeletionPurgeService(
    { $transaction: async (work: any) => work(store.tx), weddingPlan: store.tx.weddingPlan } as any,
    { erasureGraphPorts: () => graph.ports } as any,
    graph.ports.mediaStorage as any,
    graph.ports.planErasure as any,
    graph.ports.finance as any,
    graph.ports.messagingErasure as any,
    graph.ports.marketplaceErasure as any,
    { createNotificationInTransaction: async () => null } as any,
  );
  return { service, calls: graph.calls };
}

test("Q-45: the owner deletes a plan; it waits 30 days, closed to its members", async () => {
  const store = planStore();
  const { service, notices, revoked } = deletionService(store);
  const before = Date.now();

  const answer = await service.request(OWNER, "plan-1");

  assert.ok(store.row.deletionRequestedAt instanceof Date);
  const waited =
    store.row.deletionScheduledFor!.getTime() - store.row.deletionRequestedAt!.getTime();
  assert.equal(PLAN_DELETION_GRACE_DAYS, 30);
  assert.equal(waited, 30 * DAY_MS);
  assert.ok(store.row.deletionRequestedAt!.getTime() >= before);
  assert.deepEqual((answer as any).deletionScheduledFor, store.row.deletionScheduledFor);
  // Closed: no invitation is accepted, and the members are told when.
  assert.deepEqual(revoked, ["plan-1"]);
  assert.equal(notices.length, 1);
  assert.equal(notices[0].userId, MEMBER.id);
  assert.equal(notices[0].weddingPlanId, null);
  assert.equal(notices[0].title, "خطة محمد بتنحذف");
  assert.match(notices[0].body, /^محمد طلب حذف الخطة\. لو ما تراجع لين .+، تنحذف الخطة كلها\.$/u);

  // Asking again answers the same request.
  const requestedAt = store.row.deletionRequestedAt;
  await service.request(OWNER, "plan-1");
  assert.equal(store.row.deletionRequestedAt, requestedAt);
  assert.equal(notices.length, 1);
});

test("Q-45: an archived plan can be deleted too, and only by its owner", async () => {
  const store = planStore(WeddingPlanStatus.ARCHIVED);
  const { service } = deletionService(store);
  await assert.rejects(
    () => service.request(MEMBER, "plan-1"),
    (error: any) => error?.response?.code === "PLAN_DELETE_OWNER_ONLY",
  );
  assert.equal(store.row.deletionRequestedAt, null);
  await service.request(OWNER, "plan-1");
  assert.ok(store.row.deletionScheduledFor instanceof Date);
});

test("Q-45: a plan waiting out its deletion is read-only and closed to its members", async () => {
  const pending = {
    status: WeddingPlanStatus.PLANNING,
    deletionRequestedAt: new Date("2026-11-25T09:00:00.000Z"),
  };
  assert.equal(isWeddingPlanWritable(pending), false);
  assert.throws(
    () => assertWeddingPlanWritable(pending),
    (error: unknown) =>
      error instanceof ConflictException &&
      (error.getResponse() as any).code === PLAN_DELETION_PENDING,
  );
  assert.equal(
    isWeddingPlanWritable({ status: WeddingPlanStatus.PLANNING, deletionRequestedAt: null }),
    true,
  );

  const plan = {
    id: "plan-1",
    ownerUserId: OWNER.id,
    status: WeddingPlanStatus.PLANNING,
    deletionRequestedAt: pending.deletionRequestedAt,
  };
  const client: any = {
    weddingPlan: { findUnique: async () => plan },
    user: {
      findMany: async () => [
        { id: OWNER.id, status: UserStatus.ACTIVE, deletionRequestedAt: null },
      ],
    },
    sharedMember: { findUnique: async () => ({ id: "m1", userId: MEMBER.id }) },
  };
  const permissions = new PermissionService(client, new PlanReadService());
  await assert.rejects(
    () => permissions.getPlanAccessContext("plan-1", MEMBER),
    NotFoundException,
  );
  const owner = await permissions.getPlanAccessContext("plan-1", OWNER);
  assert.equal(owner.isOwner, true);
});

test("Q-45: the 30 days are real: a plan taken back is as it was and never erased", async () => {
  const store = planStore();
  const { service, notices } = deletionService(store);
  await service.request(OWNER, "plan-1");
  const scheduledFor = store.row.deletionScheduledFor!;

  // Day 29: still waiting; the purge erases nothing.
  const { service: purge, calls } = purgeService(store);
  const early = await purge.purgeDuePlans(new Date(scheduledFor.getTime() - DAY_MS));
  assert.deepEqual(early, { erased: 0, failures: [] });
  assert.equal(calls.length, 0);

  await service.cancel(OWNER, "plan-1");
  assert.equal(store.row.deletionRequestedAt, null);
  assert.equal(store.row.deletionScheduledFor, null);
  assert.equal(notices[notices.length - 1].title, "رجعت خطة محمد");
  assert.equal(notices[notices.length - 1].weddingPlanId, "plan-1");

  // Day 31: nothing is due any more.
  const late = await purge.purgeDuePlans(new Date(scheduledFor.getTime() + DAY_MS));
  assert.deepEqual(late, { erased: 0, failures: [] });
  assert.equal(calls.length, 0);

  // Taking back what is not waiting says so.
  await assert.rejects(
    () => service.cancel(OWNER, "plan-1"),
    (error: any) => error?.response?.code === "PLAN_DELETION_NOT_PENDING",
  );
});

test("Q-45: after 30 days the plan is erased with everything in it, and nothing of the owner's account", async () => {
  const store = planStore();
  const { service } = deletionService(store);
  await service.request(OWNER, "plan-1");
  const { service: purge, calls } = purgeService(store);

  const result = await purge.purgeDuePlans(
    new Date(store.row.deletionScheduledFor!.getTime() + 60_000),
  );

  assert.deepEqual(result, { erased: 1, failures: [] });
  const steps = calls.map(([name]) => name);
  const at = (name: string) => steps.indexOf(name);
  // The saga's lock order: the owner's media boundary, then the plan's
  // costs, conversations and requests, then the purge, the plan last.
  assert.ok(at("media.lockAccountDeletionBoundary") === 0);
  for (const step of [
    "finance.lockPlanCostsForUpdateInTransaction",
    "messaging.lockOwnedConversationIdsForUpdateInTransaction",
    "marketplace.lockOwnedQuoteRequestIdsForUpdateInTransaction",
    "finance.deleteReceiptsInTransaction",
    "notifications.deleteNotificationsInTransaction",
    "marketplace.deleteQuoteRequestsInTransaction",
    "messaging.deleteConversationsInTransaction",
    "collaboration.markPlansDeletedInTransaction",
    "finance.purgePlanLedgerInTransaction",
    "tasks.deletePlanTasksInTransaction",
    "guests.deletePlanGuestsInTransaction",
    "marketplace.deletePlanProviderLinksInTransaction",
    "collaboration.deletePlanMembersAndInvitesInTransaction",
    "finance.deletePlanBudgetCategoriesInTransaction",
  ]) {
    assert.ok(at(step) > 0 && at(step) < at("planning.deletePlansInTransaction"), step);
  }
  // Only the plan: the scopes name no account, and nothing of the owner's
  // own (private costs, tasks, tenures elsewhere, receipts) is touched.
  const scope = (name: string) => calls.find(([step]) => step === name)?.[1][0] as any;
  assert.deepEqual(scope("messaging.lockOwnedConversationIdsForUpdateInTransaction"), {
    userId: null,
    weddingPlanIds: ["plan-1"],
  });
  assert.equal(scope("notifications.listOwnedNotificationIds").userId, null);
  for (const ownerStep of [
    "finance.purgePrivateCostsInTransaction",
    "tasks.deletePrivateTasksInTransaction",
    "collaboration.closeActorTenuresInTransaction",
    "finance.detachReceiptUploaderInTransaction",
  ]) {
    assert.equal(at(ownerStep), -1, ownerStep);
  }
  // The providers of its open requests are told the plan went, not the account.
  const notices = calls.find(([step]) => step === "marketplace.closedCustomerNoticesInTransaction");
  assert.equal(notices?.[1][3], "PLAN");

  // Erased once: the next run finds nothing.
  assert.deepEqual(
    await purge.purgeDuePlans(new Date(store.row.deletionScheduledFor!.getTime() + DAY_MS)),
    { erased: 0, failures: [] },
  );
});
