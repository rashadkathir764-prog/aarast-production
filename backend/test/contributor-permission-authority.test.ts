import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ForbiddenException } from "@nestjs/common";
import { SharedMemberRole, WeddingPlanStatus } from "@prisma/client";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";
import { sharingService } from "./support/owner-ports";

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
  const permissions = new PermissionService({} as any, new PlanReadService());
  const context = contributorContext();

  assert.equal(permissions.canViewMoney(context), false);
  assert.equal(permissions.canManagePlan(context), false);
  assert.equal(permissions.canManageTasks(context), false);
  assert.equal(permissions.canManageGuests(context), false);
  assert.equal(permissions.canManageProviders(context), false);
  assert.equal(permissions.canManageMembers(context), false);
  assert.equal(permissions.canManageMoney(context), false);
});

// RA-BE-42: this test pinned how the direct add filled permissions it was
// not given. The direct add no longer grants anything: whoever joins
// accepts an invite (P5), so every request is refused before any lookup and
// no permission is ever derived on this path.
test("direct member creation grants nothing: every request is refused before any lookup", async () => {
  // An empty database: any read would throw a TypeError, not ADD_BY_INVITE.
  const service = sharingService(
    {} as any,
    {
      assertMemberManageable: async () => ({
        plan: { id: "plan-1", ownerUserId: "owner-1" },
        isOwner: true,
        sharedMember: null,
      }),
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );

  for (const dto of [
    { role: SharedMemberRole.CONTRIBUTOR, userId: "account-1" },
    { role: SharedMemberRole.VIEWER, userId: "account-2", canManageMoney: true },
    { role: SharedMemberRole.VIEWER, phone: "+967777000004" },
  ]) {
    await assert.rejects(
      () => service.create({ id: "owner-1" } as any, "plan-1", dto as any),
      (error: any) => error?.response?.code === "ADD_BY_INVITE",
    );
  }
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
    // D63: the plan's owner waits out no deletion.
    user: { findMany: async () => [] },
  } as any, new PlanReadService());

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
