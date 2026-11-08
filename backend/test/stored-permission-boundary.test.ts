import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConversationScope, SharedMemberRole } from "@prisma/client";
import { conversationsService, notificationsService } from "./support/owner-ports";

test("finance role cannot restore a stored money permission in conversations", () => {
  const service = conversationsService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );
  const access = (service as any).accessFor(
    {
      scope: ConversationScope.PLAN,
      accountRequesterUserId: null,
      provider: { userId: "provider", status: "ACTIVE" },
      weddingPlan: {
        ownerUserId: "owner",
        sharedMembers: [
          {
            userId: "contributor",
            role: SharedMemberRole.FINANCE_MANAGER,
            canManageProviders: true,
            canViewMoney: false,
            canManageMoney: false,
          },
        ],
      },
    },
    "contributor",
  );

  assert.equal(access?.canViewMoney, false);
  assert.equal(access?.canManageMoney, false);
});

test("RA-BE-73: a conversation's offer carries no extra's price to a reader without money", () => {
  const service = conversationsService({} as any, {} as any, {} as any, {} as any, {} as any);
  const offer = {
    id: "offer",
    amount: "500000",
    currentVersionNo: 2,
    versionChanges: [{ field: "amount", from: "400000", to: "500000" }],
    revisionNoticeAt: null,
    lines: [
      { label: "تصوير", kind: "INCLUDED", amount: null },
      { label: "درون", kind: "EXTRA", amount: "80000" },
    ],
    deliveryDays: 30,
    revisedAt: null,
    withdrawnAt: null,
    withdrawnReason: null,
  };
  const quote = {
    id: "quote",
    user: { id: "owner", name: "عبدالله", appName: null, avatarUrl: null, appAvatarUrl: null },
    offers: [offer],
    budgetMin: null,
    budgetMax: null,
    contactName: null,
    contactPhone: null,
    contactNormalizedPhone: null,
    shareBudget: false,
    shareContact: false,
  };
  const read = (canViewMoney: boolean) =>
    (service as any).toQuoteRequestResponse(quote, {
      side: "CUSTOMER",
      canViewMoney,
      canViewContact: false,
    }).offers[0];

  const helper = read(false);
  assert.equal(helper.amount, undefined);
  assert.deepEqual(
    helper.lines.map((line: { amount: string | null }) => line.amount),
    [null, null],
  );
  assert.deepEqual(helper.changes, []);
  const owner = read(true);
  assert.equal(owner.amount, "500000");
  assert.deepEqual(
    owner.lines.map((line: { amount: string | null }) => line.amount),
    [null, "80000"],
  );
  assert.equal(owner.versionNo, 2);
});

// The money visibility used to be a join on the membership row's flags; the
// plans a reader may see money in are derived from the membership rows
// (canViewMoney or canManageMoney) when the predicate is built, never from
// the role, and applied to the notification table by plan id.
test("finance role is not a money-notification permission fallback", async () => {
  const service = notificationsService(
    {
      provider: { findUnique: async () => null },
      // The reader owns no plan; the plans he is a member of are open
      // (RA-BE-102: their owners are not leaving).
      weddingPlan: {
        findMany: async ({ where }: any) =>
          (where.id?.in ?? []).map((id: string) => ({ id, ownerUserId: "owner" })),
      },
      user: { findMany: async () => [] },
      sharedMember: {
        findMany: async () => [
          {
            weddingPlanId: "plan-money",
            userId: "user-1",
            role: SharedMemberRole.FINANCE_MANAGER,
            canManageTasks: false,
            canViewMoney: true,
            canManageMoney: false,
          },
          {
            weddingPlanId: "plan-role-only",
            userId: "user-1",
            role: SharedMemberRole.FINANCE_MANAGER,
            canManageTasks: false,
            canViewMoney: false,
            canManageMoney: false,
          },
        ],
      },
      weddingTask: { findMany: async () => [] },
      contributionEvent: { findMany: async () => [] },
      paymentSchedule: { findMany: async () => [] },
    } as any,
    {} as any,
    {} as any,
  );
  const where = await service.visibilityWhereForUser("user-1");
  const serialized = JSON.stringify(where);

  assert.equal(serialized.includes("FINANCE_MANAGER"), false);
  const money = where?.AND[1] as { OR: [unknown, { weddingPlanId: { in: string[] } }] };
  assert.deepEqual(money.OR[1], { weddingPlanId: { in: ["plan-money"] } });
});
