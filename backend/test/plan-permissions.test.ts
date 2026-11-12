import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import {
  SharedMemberRole,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { rolePermissionDefaults } from "../src/modules/collaboration/internal/plan-permissions";
import {
  managesMoneyNow,
  planWriteRights,
} from "../src/modules/collaboration/public/collaboration-permission.port";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";

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

// D112 (Q-21): the owner of an archived plan reads it, and changes nothing.
// The contexts said so; the three summaries a screen reads its buttons from
// (`permissions/me`, the dashboard's, the money's) still reported every
// write right, so an archived plan opened to read showed «+» and «ادفع»
// the server then refused.
test("Q-21: an archived plan reports no write right to anyone, and keeps its read rights", () => {
  const owner = new PermissionService({} as never, {} as never);
  const context = (status: WeddingPlanStatus) =>
    ({
      plan: { ...archivedPlan, status },
      isOwner: true,
      sharedMember: null,
    }) as never;

  assert.deepEqual(planWriteRights(context(WeddingPlanStatus.ARCHIVED), owner), {
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canManageMoney: false,
    canManagePlan: false,
    canManageMembers: false,
  });
  assert.equal(owner.canViewMoney(context(WeddingPlanStatus.ARCHIVED)), true);
  // A plan still being planned is unchanged.
  assert.deepEqual(planWriteRights(context(WeddingPlanStatus.PLANNING), owner), {
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canManageMoney: true,
    canManagePlan: true,
    canManageMembers: true,
  });
});

test("Q-21: the summaries a screen reads its buttons from all go through that rule", () => {
  const read = (path: string) =>
    readFileSync(join(__dirname, "..", "src", path), "utf8");
  for (const path of [
    "modules/collaboration/internal/sharing.service.ts",
    "dashboard/dashboard.service.ts",
  ]) {
    assert.match(read(path), /planWriteRights\(/u, path);
  }
  // The money's summary reports one right, through the same rule.
  assert.match(read("money/money-summary.service.ts"), /managesMoneyNow\(/u);
  assert.doesNotMatch(
    read("money/money-summary.service.ts"),
    /permissions\.canManageMoney\(/u,
  );
  const archived = {
    plan: { ...archivedPlan },
    isOwner: true,
    sharedMember: null,
  } as never;
  const owner = new PermissionService({} as never, {} as never);
  assert.equal(managesMoneyNow(archived, owner), false);
  assert.equal(
    managesMoneyNow(
      { plan: { ...archivedPlan, status: WeddingPlanStatus.PLANNING }, isOwner: true, sharedMember: null } as never,
      owner,
    ),
    true,
  );
});

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
  const service = new PermissionService({} as any, new PlanReadService());
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
  const service = new PermissionService(archivedPlanPrisma() as any, new PlanReadService());
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
    const service = new PermissionService(archivedPlanPrisma() as any, new PlanReadService());
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
    const service = new PermissionService(tx as any, new PlanReadService());
    const currentUser = { id: archivedPlan.ownerUserId } as any;

    await assert.rejects(
      () => assertion.run(service, tx, currentUser),
      assertArchivedConflict,
    );
  });
}
