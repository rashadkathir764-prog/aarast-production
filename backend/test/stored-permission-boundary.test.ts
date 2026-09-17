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

// The money visibility used to be a join on the membership row's flags; the
// plans a reader may see money in are derived from the membership rows
// (canViewMoney or canManageMoney) when the predicate is built, never from
// the role, and applied to the notification table by plan id.
test("finance role is not a money-notification permission fallback", async () => {
  const service = notificationsService(
    {
      provider: { findUnique: async () => null },
      weddingPlan: { findMany: async () => [] },
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
