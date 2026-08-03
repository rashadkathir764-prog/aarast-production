import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ForbiddenException } from "@nestjs/common";
import { SharedMemberRole, WeddingPlanStatus } from "@prisma/client";
import { PermissionService } from "../src/sharing/permission.service";

const taskRevokedMessage = "لم تعد لديك صلاحية لتنفيذ هذه المهمة";

function contributorContext() {
  return {
    plan: { id: "plan-1", ownerUserId: "owner-1" },
    isOwner: false,
    sharedMember: {
      id: "member-contributor",
      weddingPlanId: "plan-1",
      userId: "contributor-1",
      role: SharedMemberRole.CONTRIBUTOR,
      canViewMoney: false,
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canManageMoney: false,
      receiveNotifications: true,
    },
  } as any;
}

test("stored false contributor permissions override every role default at runtime", () => {
  const permissions = new PermissionService({} as any);
  const context = contributorContext();

  assert.equal(permissions.canViewMoney(context), false);
  assert.equal(permissions.canManagePlan(context), false);
  assert.equal(permissions.canManageTasks(context), false);
  assert.equal(permissions.canManageGuests(context), false);
  assert.equal(permissions.canManageProviders(context), false);
  assert.equal(permissions.canManageMembers(context), false);
  assert.equal(permissions.canManageMoney(context), false);
});

test("a known contributor whose task permission was revoked receives the stable task denial", async () => {
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: WeddingPlanStatus.PLANNING,
  };
  const member = contributorContext().sharedMember;
  const permissions = new PermissionService({
    weddingPlan: { findUnique: async () => plan },
    sharedMember: { findUnique: async () => member },
  } as any);

  await assert.rejects(
    () =>
      permissions.assertTaskManageable("plan-1", {
        id: "contributor-1",
      } as any),
    (error: unknown) => {
      assert.ok(error instanceof ForbiddenException);
      const response = error.getResponse() as Record<string, unknown>;
      assert.equal(response.code, "TASK_PERMISSION_REVOKED");
      assert.equal(response.message, taskRevokedMessage);
      return true;
    },
  );
});
