import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException } from "@nestjs/common";
import { SharedMemberRole } from "@prisma/client";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { rolePermissionDefaults } from "../src/modules/collaboration/internal/plan-permissions";
import type { PlanAccessContext } from "../src/modules/collaboration/public/collaboration-permission.port";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";

// RA-BE-40: a member refused a write in a section they may not edit was told
// «Wedding plan not found» (the phone says it found no plan) everywhere but
// in tasks, which already answer 403 TASK_PERMISSION_REVOKED. A member knows
// the plan, so the refusal says why; someone outside it still learns nothing.

const plan = { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" } as any;
const viewer: PlanAccessContext = {
  plan,
  isOwner: false,
  sharedMember: {
    id: "member-1",
    userId: "viewer-1",
    weddingPlanId: "plan-1",
    role: SharedMemberRole.VIEWER,
    ...rolePermissionDefaults(SharedMemberRole.VIEWER),
  } as any,
};
const outsider: PlanAccessContext = { plan, isOwner: false, sharedMember: null };
const user = { id: "viewer-1" } as any;

function permissionsFor(context: PlanAccessContext): PermissionService {
  const service = new PermissionService({} as any, new PlanReadService());
  const anyService = service as any;
  anyService.assertPlanReadable = async () => context;
  anyService.getLockedPlanAccessContext = async () => context;
  anyService.getPlanUpdateLockedAccessContext = async () => context;
  return service;
}

const writeChecks: Array<[string, (service: any) => Promise<unknown>]> = [
  ["guests", (s) => s.assertGuestManageable("plan-1", user)],
  ["guests in a transaction", (s) => s.assertGuestManageableInTransaction({}, "plan-1", user)],
  ["money", (s) => s.assertMoneyManageable("plan-1", user)],
  ["money in a transaction", (s) => s.assertMoneyManageableInTransaction({}, "plan-1", user)],
  ["money under the plan lock", (s) => s.assertMoneyManageableForUpdateInTransaction({}, "plan-1", user)],
  ["providers", (s) => s.assertProviderManageable("plan-1", user)],
  ["providers in a transaction", (s) => s.assertProviderManageableInTransaction({}, "plan-1", user)],
  ["providers and money", (s) => s.assertProviderAndMoneyManageableInTransaction({}, "plan-1", user)],
  ["members", (s) => s.assertMemberManageable("plan-1", user)],
  ["members in a transaction", (s) => s.assertMemberManageableInTransaction({}, "plan-1", user)],
  ["the plan", (s) => s.assertPlanManageable("plan-1", user)],
  ["the plan under its lock", (s) => s.assertPlanManageableForUpdateInTransaction({}, "plan-1", user)],
];

test("RA-BE-40: a member refused a section's write is told why, in Arabic", async () => {
  for (const [section, check] of writeChecks) {
    await assert.rejects(
      () => check(permissionsFor(viewer)),
      (error: unknown) => {
        assert.ok(error instanceof HttpException, section);
        assert.equal(error.getStatus(), 403, section);
        const response = error.getResponse() as Record<string, unknown>;
        assert.equal(response.code, "SECTION_PERMISSION_MISSING", section);
        assert.match(String(response.message), /[؀-ۿ]/u, section);
        assert.doesNotMatch(String(response.message), /[A-Za-z]/u, section);
        return true;
      },
    );
  }
});

test("RA-BE-40: someone outside the plan still learns nothing of it", async () => {
  const lockedChecks = writeChecks.filter(([section]) =>
    / in a transaction| under | and money/.test(section),
  );
  assert.ok(lockedChecks.length >= 6);
  for (const [section, check] of lockedChecks) {
    await assert.rejects(
      () => check(permissionsFor(outsider)),
      (error: unknown) => {
        assert.ok(error instanceof HttpException, section);
        assert.equal(error.getStatus(), 404, section);
        return true;
      },
    );
  }
});
