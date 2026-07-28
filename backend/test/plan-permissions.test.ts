import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import {
  SharedMemberRole,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { rolePermissionDefaults } from "../src/sharing/plan-permissions";
import { PermissionService } from "../src/sharing/permission.service";

const archivedPlan = {
  id: "archived-plan",
  ownerUserId: "owner-1",
  status: WeddingPlanStatus.ARCHIVED,
};

const archivedPlanPrisma = () => {
  let lockCount = 0;
  return {
    $queryRaw: async () => {
      lockCount += 1;
      return lockCount === 1
        ? [{ id: archivedPlan.ownerUserId, status: UserStatus.ACTIVE }]
        : [{ id: archivedPlan.id }];
    },
    weddingPlan: {
      findUnique: async () => archivedPlan,
    },
    sharedMember: {
      findUnique: async () => null,
    },
  };
};

const assertArchivedConflict = (error: unknown) => {
  assert.ok(error instanceof ConflictException);
  const response = error.getResponse();
  assert.equal(typeof response, "object");
  assert.equal(
    (response as { code?: unknown }).code,
    "PLAN_ARCHIVED_READ_ONLY",
  );
  return true;
};

test("groom and bride roles can operate the plan while retaining explicit money access", () => {
  for (const role of [SharedMemberRole.GROOM, SharedMemberRole.BRIDE]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canEditPlan, true);
    assert.equal(permissions.canManageTasks, true);
    assert.equal(permissions.canManageGuests, true);
    assert.equal(permissions.canManageProviders, true);
    assert.equal(permissions.canViewMoney, true);
    assert.equal(permissions.canManageMoney, true);
  }
});

test("family and helper roles keep financial data private by default", () => {
  for (const role of [SharedMemberRole.FAMILY, SharedMemberRole.HELPER]) {
    const permissions = rolePermissionDefaults(role);
    assert.equal(permissions.canViewMoney, false);
    assert.equal(permissions.canManageMoney, false);
    assert.equal(permissions.canManageTasks, true);
    assert.equal(permissions.canManageGuests, true);
  }
});

test("viewer role is read-only and owner retains every permission", () => {
  const viewer = rolePermissionDefaults(SharedMemberRole.VIEWER);
  assert.equal(viewer.canEditPlan, false);
  assert.equal(viewer.canManageTasks, false);
  assert.equal(viewer.canManageGuests, false);
  assert.equal(viewer.canManageProviders, false);
  assert.equal(viewer.canInviteMembers, false);

  const owner = rolePermissionDefaults(SharedMemberRole.OWNER);
  assert.ok(Object.values(owner).every(Boolean));
});

test("stored provider permission overrides role defaults everywhere", () => {
  const service = new PermissionService({} as any);
  const context = (role: SharedMemberRole, canManageProviders: boolean) =>
    ({
      plan: { ownerUserId: "owner-1" },
      isOwner: false,
      sharedMember: {
        role,
        canManageProviders,
      },
    }) as any;

  assert.equal(
    service.canManageProviders(context(SharedMemberRole.HELPER, false)),
    false,
  );
  assert.equal(
    service.canManageProviders(context(SharedMemberRole.GROOM, false)),
    false,
  );
  assert.equal(
    service.canManageProviders(context(SharedMemberRole.VIEWER, true)),
    true,
  );
});

test("an archived plan remains readable for an authorized owner", async () => {
  const service = new PermissionService(archivedPlanPrisma() as any);
  const currentUser = { id: archivedPlan.ownerUserId } as any;

  const planAccess = await service.assertPlanReadable(
    archivedPlan.id,
    currentUser,
  );
  const moneyAccess = await service.assertMoneyReadable(
    archivedPlan.id,
    currentUser,
  );

  assert.equal(planAccess.plan.status, WeddingPlanStatus.ARCHIVED);
  assert.equal(moneyAccess.plan.status, WeddingPlanStatus.ARCHIVED);
});

const archivedWriteAssertions = [
  {
    label: "plan changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertPlanManageable(archivedPlan.id, currentUser),
  },
  {
    label: "task changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertTaskManageable(archivedPlan.id, currentUser),
  },
  {
    label: "guest changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertGuestManageable(archivedPlan.id, currentUser),
  },
  {
    label: "money changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertMoneyManageable(archivedPlan.id, currentUser),
  },
  {
    label: "provider and quote changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertProviderManageable(archivedPlan.id, currentUser),
  },
  {
    label: "member and invitation changes",
    run: (service: PermissionService, currentUser: any) =>
      service.assertMemberManageable(archivedPlan.id, currentUser),
  },
];

for (const assertion of archivedWriteAssertions) {
  test(`an archived plan rejects ${assertion.label}`, async () => {
    const service = new PermissionService(archivedPlanPrisma() as any);
    const currentUser = { id: archivedPlan.ownerUserId } as any;

    await assert.rejects(
      () => assertion.run(service, currentUser),
      assertArchivedConflict,
    );
  });
}

const archivedTransactionalWriteAssertions = [
  {
    label: "plan changes that update the plan row inside a transaction",
    run: (service: PermissionService, tx: any, currentUser: any) =>
      service.assertPlanManageableForUpdateInTransaction(
        tx,
        archivedPlan.id,
        currentUser,
      ),
  },
  {
    label: "provider and quote changes inside a transaction",
    run: (service: PermissionService, tx: any, currentUser: any) =>
      service.assertProviderManageableInTransaction(
        tx,
        archivedPlan.id,
        currentUser,
      ),
  },
  {
    label: "provider and money changes inside a transaction",
    run: (service: PermissionService, tx: any, currentUser: any) =>
      service.assertProviderAndMoneyManageableInTransaction(
        tx,
        archivedPlan.id,
        currentUser,
      ),
  },
  {
    label: "member and invitation changes inside a transaction",
    run: (service: PermissionService, tx: any, currentUser: any) =>
      service.assertMemberManageableInTransaction(
        tx,
        archivedPlan.id,
        currentUser,
      ),
  },
];

for (const assertion of archivedTransactionalWriteAssertions) {
  test(`an archived plan rejects ${assertion.label}`, async () => {
    const tx = archivedPlanPrisma();
    const service = new PermissionService(tx as any);
    const currentUser = { id: archivedPlan.ownerUserId } as any;

    await assert.rejects(
      () => assertion.run(service, tx, currentUser),
      assertArchivedConflict,
    );
  });
}
