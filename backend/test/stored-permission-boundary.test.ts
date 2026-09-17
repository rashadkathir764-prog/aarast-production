import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConversationScope, SharedMemberRole } from "@prisma/client";
import { conversationsService } from "./support/owner-ports";
import { NotificationsService } from "../src/notifications/notifications.service";

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

test("finance role is not a money-notification permission fallback", () => {
  const service = new NotificationsService({} as any, {} as any, {} as any);
  const where = (service as any).moneyNotificationVisibilityWhere("user-1");
  const serialized = JSON.stringify(where);

  assert.equal(serialized.includes("FINANCE_MANAGER"), false);
  assert.match(serialized, /canViewMoney/);
  assert.match(serialized, /canManageMoney/);
});
