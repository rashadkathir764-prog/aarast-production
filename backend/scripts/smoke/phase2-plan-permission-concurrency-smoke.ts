import "reflect-metadata";

import assert from "node:assert/strict";
import { NotFoundException } from "@nestjs/common";
import {
  PrismaClient,
  SharedMemberRole,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ContributionHistoryService } from "../../src/modules/collaboration/internal/contribution-history.service";
import { WeddingPlansService } from "../../src/wedding-plans/wedding-plans.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => {
    runId: string;
  };
};
const { createPermissionRevocationFixture, withFixture } =
  require("../../test/support/phase0-postgres-support.js") as {
    createPermissionRevocationFixture: (
      prisma: unknown,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<any>;
    withFixture: (
      createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
      callback: (fixture: any) => Promise<void>,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<void>;
  };

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const permissions = new PermissionService(prisma as any);
const contributionHistory = new ContributionHistoryService(prisma as any);
const weddingPlans = new WeddingPlansService(
  prisma as any,
  permissions,
  contributionHistory,
);

function authenticatedUser(user: {
  id: string;
  name: string;
  phone: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
  } as any;
}

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
} {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function holdUncommittedPlanPermissionRevocation(
  sharedMemberId: string,
): Promise<{ commit: () => Promise<void> }> {
  const revoked = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.update({
        where: { id: sharedMemberId },
        data: {
          role: SharedMemberRole.VIEWER,
          canEditPlan: false,
        },
      });
      revoked.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await revoked.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedMembershipRemoval(
  sharedMemberId: string,
): Promise<{ commit: () => Promise<void> }> {
  const removed = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.delete({
        where: { id: sharedMemberId },
      });
      removed.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await removed.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedUserDisable(
  userId: string,
): Promise<{ commit: () => Promise<void> }> {
  const disabled = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { status: UserStatus.DISABLED },
      });
      disabled.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await disabled.promise;
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function waitForBlockedMutation(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(
    state,
    "blocked",
    `${label} must wait for permission revocation`,
  );
}

async function assertRevocationWinsBeforeArchive(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const revocation = await holdUncommittedPlanPermissionRevocation(
        fixture.sharedMember.id,
      );
      const archive = weddingPlans.archive(
        authenticatedUser(fixture.member),
        fixture.plan.id,
      );

      try {
        await waitForBlockedMutation(
          archive,
          "archive while plan permission revocation is uncommitted",
        );
        await revocation.commit();

        const [result] = await Promise.allSettled([archive]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed permission revocation must reject the waiting archive",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const plan = await prisma.weddingPlan.findUniqueOrThrow({
          where: { id: fixture.plan.id },
        });
        assert.equal(
          plan.status,
          WeddingPlanStatus.PLANNING,
          "a revoked member must not archive the plan",
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([archive]);
      }
    },
  );
}

async function assertRevocationWinsBeforeUpdate(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const revocation = await holdUncommittedPlanPermissionRevocation(
        fixture.sharedMember.id,
      );
      const update = weddingPlans.update(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        { title: "Must not be written after revocation" },
      );

      try {
        await waitForBlockedMutation(
          update,
          "plan update while plan permission revocation is uncommitted",
        );
        await revocation.commit();

        const [result] = await Promise.allSettled([update]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed permission revocation must reject the waiting plan update",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const plan = await prisma.weddingPlan.findUniqueOrThrow({
          where: { id: fixture.plan.id },
        });
        assert.equal(
          plan.title,
          fixture.plan.title,
          "a revoked member must not update the plan",
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function assertMembershipRemovalWinsBeforeSetActive(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      assert.equal(fixture.member.activeWeddingPlanId, null);
      const removal = await holdUncommittedMembershipRemoval(
        fixture.sharedMember.id,
      );
      const setActive = weddingPlans.setActive(
        authenticatedUser(fixture.member),
        fixture.plan.id,
      );

      try {
        await waitForBlockedMutation(
          setActive,
          "set-active while membership removal is uncommitted",
        );
        await removal.commit();

        const [result] = await Promise.allSettled([setActive]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed membership removal must reject the waiting set-active",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const user = await prisma.user.findUniqueOrThrow({
          where: { id: fixture.member.id },
          select: { activeWeddingPlanId: true },
        });
        assert.equal(
          user.activeWeddingPlanId,
          null,
          "a removed member must not select the inaccessible plan",
        );
      } finally {
        await removal.commit();
        await Promise.allSettled([setActive]);
      }
    },
  );
}

async function assertAccountDisableWinsBeforePlanUpdate(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const disable = await holdUncommittedUserDisable(fixture.member.id);
      const update = weddingPlans.update(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        { title: "Must not be written by a disabled account" },
      );

      try {
        await waitForBlockedMutation(
          update,
          "plan update while account disable is uncommitted",
        );
        await disable.commit();

        const [result] = await Promise.allSettled([update]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed account disable must reject the waiting plan update",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const plan = await prisma.weddingPlan.findUniqueOrThrow({
          where: { id: fixture.plan.id },
        });
        assert.equal(
          plan.title,
          fixture.plan.title,
          "a disabled account must not update the plan",
        );
      } finally {
        await disable.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function assertAccountDisableWinsBeforePlanCreate(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const baseline = await prisma.weddingPlan.count({
        where: { ownerUserId: fixture.member.id },
      });
      const disable = await holdUncommittedUserDisable(fixture.member.id);
      const create = weddingPlans.create(authenticatedUser(fixture.member), {
        title: "Must not be created by a disabled account",
      });

      try {
        await waitForBlockedMutation(
          create,
          "plan create while account disable is uncommitted",
        );
        await disable.commit();

        const [result] = await Promise.allSettled([create]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed account disable must reject the waiting plan create",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        assert.equal(
          await prisma.weddingPlan.count({
            where: { ownerUserId: fixture.member.id },
          }),
          baseline,
          "a disabled account must not create a wedding plan",
        );
      } finally {
        await disable.commit();
        await Promise.allSettled([create]);
      }
    },
  );
}

async function assertAccountDisableWinsBeforeSetActive(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      assert.equal(fixture.member.activeWeddingPlanId, null);
      const disable = await holdUncommittedUserDisable(fixture.member.id);
      const setActive = weddingPlans.setActive(
        authenticatedUser(fixture.member),
        fixture.plan.id,
      );

      try {
        await waitForBlockedMutation(
          setActive,
          "set-active while account disable is uncommitted",
        );
        await disable.commit();

        const [result] = await Promise.allSettled([setActive]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed account disable must reject the waiting set-active",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const user = await prisma.user.findUniqueOrThrow({
          where: { id: fixture.member.id },
          select: { activeWeddingPlanId: true },
        });
        assert.equal(
          user.activeWeddingPlanId,
          null,
          "a disabled account must not select an active wedding plan",
        );
      } finally {
        await disable.commit();
        await Promise.allSettled([setActive]);
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertRevocationWinsBeforeArchive();
    await assertRevocationWinsBeforeUpdate();
    await assertMembershipRemovalWinsBeforeSetActive();
    await assertAccountDisableWinsBeforePlanUpdate();
    await assertAccountDisableWinsBeforePlanCreate();
    await assertAccountDisableWinsBeforeSetActive();
    console.log(
      "PASS - Phase 2 plan mutations serialize permission revocation, membership removal, and account disable.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
