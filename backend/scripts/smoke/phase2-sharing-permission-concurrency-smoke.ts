import "reflect-metadata";

import assert from "node:assert/strict";
import { HttpException, NotFoundException } from "@nestjs/common";
import {
  PlanInviteDeliveryStatus,
  PrismaClient,
  SharedMemberRole,
  WeddingPlanStatus,
} from "@prisma/client";
import { ContributionHistoryService } from "../../src/modules/collaboration/internal/contribution-history.service";
import { NotificationsService } from "../../src/notifications/notifications.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { SharingService } from "../../src/modules/collaboration/internal/sharing.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createPermissionRevocationFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
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
const history = new ContributionHistoryService(prisma as any);
const notifications = new NotificationsService(
  prisma as any,
  permissions,
  new OutboxService(),
);
const sharing = new SharingService(
  prisma as any,
  permissions,
  notifications,
  {
    deliver: async () => ({
      channel: "WHATSAPP",
      status: "DELIVERED",
    }),
  } as any,
  history,
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

async function holdUncommittedDelegationRevocation(
  sharedMemberId: string,
): Promise<{ commit: () => Promise<void> }> {
  const revoked = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.sharedMember.update({
        where: { id: sharedMemberId },
        data: { canInviteMembers: false },
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

async function holdUncommittedPlanArchive(
  planId: string,
): Promise<{ commit: () => Promise<void> }> {
  const archived = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.weddingPlan.update({
        where: { id: planId },
        data: { status: WeddingPlanStatus.ARCHIVED },
      });
      archived.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await archived.promise;
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
    `${label} must wait for the uncommitted authority change`,
  );
}

function assertArchivedReadOnly(result: PromiseSettledResult<unknown>): void {
  assert.equal(
    result.status,
    "rejected",
    "a committed plan archive must reject the waiting member mutation",
  );
  if (result.status === "rejected") {
    const response = (
      result.reason as { getResponse?: () => unknown }
    ).getResponse?.();
    assert.equal(
      typeof response === "object" && response !== null
        ? (response as { code?: unknown }).code
        : undefined,
      "PLAN_ARCHIVED_READ_ONLY",
    );
  }
}

async function createDelegatedMemberFixture(fixture: any) {
  const actor = await grantDelegatedMemberAuthority(fixture);
  const target = await prisma.sharedMember.create({
    data: {
      weddingPlanId: fixture.plan.id,
      userId: fixture.providerUser.id,
      role: SharedMemberRole.VIEWER,
    },
  });
  return { actor, target };
}

async function grantDelegatedMemberAuthority(fixture: any) {
  return prisma.sharedMember.update({
    where: { id: fixture.sharedMember.id },
    data: { canInviteMembers: true },
  });
}

async function assertRevocationWinsBeforeMemberUpdate(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const { actor, target } = await createDelegatedMemberFixture(fixture);
      assert.equal(target.receiveNotifications, true);
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const update = sharing.updateMemberForPlan(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        target.id,
        { receiveNotifications: false },
      );

      try {
        await waitForBlockedMutation(
          update,
          "member update while delegation revocation is uncommitted",
        );
        await revocation.commit();

        const [result] = await Promise.allSettled([update]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed delegation revocation must reject the waiting member update",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const stored = await prisma.sharedMember.findUniqueOrThrow({
          where: { id: target.id },
        });
        assert.equal(
          stored.receiveNotifications,
          true,
          "a revoked delegate must not update another member",
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function assertRevocationWinsBeforeMemberRemoval(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const { actor, target } = await createDelegatedMemberFixture(fixture);
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const removal = sharing.removeMemberFromPlan(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        target.id,
      );

      try {
        await waitForBlockedMutation(
          removal,
          "member removal while delegation revocation is uncommitted",
        );
        await revocation.commit();

        const [result] = await Promise.allSettled([removal]);
        assert.equal(
          result?.status,
          "rejected",
          "a committed delegation revocation must reject the waiting member removal",
        );
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        assert.equal(
          await prisma.sharedMember.count({
            where: { id: target.id },
          }),
          1,
          "a revoked delegate must not remove another member",
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([removal]);
      }
    },
  );
}

async function assertRevocationWinsBeforeMemberCreation(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const actor = await grantDelegatedMemberAuthority(fixture);
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const creation = sharing.create(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        {
          userId: fixture.providerUser.id,
          role: SharedMemberRole.VIEWER,
        },
      );

      try {
        await waitForBlockedMutation(
          creation,
          "member creation while delegation revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([creation]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        assert.equal(
          await prisma.sharedMember.count({
            where: {
              weddingPlanId: fixture.plan.id,
              userId: fixture.providerUser.id,
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([creation]);
      }
    },
  );
}

async function assertRevocationWinsBeforeInviteCreation(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const actor = await grantDelegatedMemberAuthority(fixture);
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const creation = sharing.createInvite(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        {
          phone: fixture.providerUser.phone,
          role: SharedMemberRole.VIEWER,
        },
      );

      try {
        await waitForBlockedMutation(
          creation,
          "invite creation while delegation revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([creation]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        assert.equal(
          await prisma.planInvite.count({
            where: {
              weddingPlanId: fixture.plan.id,
              inviterUserId: fixture.member.id,
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([creation]);
      }
    },
  );
}

async function createDelegateInvite(fixture: any) {
  const actor = await grantDelegatedMemberAuthority(fixture);
  const invite = await sharing.createInvite(
    authenticatedUser(fixture.member),
    fixture.plan.id,
    {
      phone: fixture.providerUser.phone,
      role: SharedMemberRole.VIEWER,
    },
  );
  return { actor, invite };
}

async function assertRevocationWinsBeforeInviteCancellation(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const { actor, invite } = await createDelegateInvite(fixture);
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const cancellation = sharing.cancelInvite(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        invite.id,
      );

      try {
        await waitForBlockedMutation(
          cancellation,
          "invite cancellation while delegation revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([cancellation]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const stored = await prisma.planInvite.findUniqueOrThrow({
          where: { id: invite.id },
        });
        assert.equal(stored.revokedAt, null);
      } finally {
        await revocation.commit();
        await Promise.allSettled([cancellation]);
      }
    },
  );
}

async function assertRevocationWinsBeforeInviteReissue(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const { actor, invite } = await createDelegateInvite(fixture);
      const ready = await prisma.planInvite.update({
        where: { id: invite.id },
        data: { deliveryAttemptedAt: new Date(Date.now() - 61_000) },
      });
      const revocation = await holdUncommittedDelegationRevocation(actor.id);
      const reissue = sharing.reissueInvite(
        authenticatedUser(fixture.member),
        fixture.plan.id,
        invite.id,
      );

      try {
        await waitForBlockedMutation(
          reissue,
          "invite reissue while delegation revocation is uncommitted",
        );
        await revocation.commit();
        const [result] = await Promise.allSettled([reissue]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.ok(result.reason instanceof NotFoundException);
        }
        const stored = await prisma.planInvite.findUniqueOrThrow({
          where: { id: invite.id },
        });
        assert.equal(stored.tokenHash, ready.tokenHash);
        assert.ok(stored.deliveryAttemptedAt);
        assert.ok(ready.deliveryAttemptedAt);
        assert.equal(
          stored.deliveryAttemptedAt.getTime(),
          ready.deliveryAttemptedAt.getTime(),
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([reissue]);
      }
    },
  );
}

async function assertCancellationSupersedesInFlightDelivery(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const deliveryStarted = deferred();
      const releaseDelivery = deferred();
      let deliveryCalls = 0;
      let deliveredToken: string | null = null;
      const deliverySharing = new SharingService(
        prisma as any,
        permissions,
        notifications,
        {
          deliver: async (_phone: string | null, token: string) => {
            deliveryCalls += 1;
            deliveredToken = token;
            deliveryStarted.resolve();
            await releaseDelivery.promise;
            return {
              channel: "WHATSAPP",
              status: "DELIVERED",
            };
          },
        } as any,
        history,
      );
      const creating = deliverySharing.createInvite(
        authenticatedUser(fixture.owner),
        fixture.plan.id,
        {
          phone: fixture.providerUser.phone,
          role: SharedMemberRole.VIEWER,
        },
      );

      try {
        let timeout: NodeJS.Timeout | undefined;
        let startState: "started" | "completed" | "timeout";
        try {
          startState = await Promise.race([
            deliveryStarted.promise.then(() => "started" as const),
            creating.then(
              () => "completed" as const,
              (error) => {
                throw error;
              },
            ),
            new Promise<"timeout">((resolve) => {
              timeout = setTimeout(() => resolve("timeout"), 5_000);
            }),
          ]);
        } finally {
          if (timeout) clearTimeout(timeout);
        }
        assert.equal(
          startState,
          "started",
          "invite delivery must pause at the external boundary",
        );

        const pending = await prisma.planInvite.findFirstOrThrow({
          where: {
            weddingPlanId: fixture.plan.id,
            inviterUserId: fixture.owner.id,
            revokedAt: null,
          },
          orderBy: { createdAt: "desc" },
        });
        const cancelled = await deliverySharing.cancelInvite(
          authenticatedUser(fixture.owner),
          fixture.plan.id,
          pending.id,
        );
        assert.equal(cancelled.status, "CANCELLED");
        assert.equal(cancelled.token, pending.id);

        releaseDelivery.resolve();
        const [completion] = await Promise.allSettled([creating]);
        assert.equal(
          completion?.status,
          "rejected",
          "cancellation must supersede the stale delivery finalizer",
        );
        if (completion?.status === "rejected") {
          assert.ok(completion.reason instanceof HttpException);
          assert.equal(completion.reason.getStatus(), 409);
          assert.equal(
            (
              completion.reason.getResponse() as {
                code?: unknown;
              }
            ).code,
            "INVITE_DELIVERY_ATTEMPT_SUPERSEDED",
          );
        }

        const stored = await prisma.planInvite.findUniqueOrThrow({
          where: { id: pending.id },
        });
        assert.ok(stored.revokedAt);
        assert.equal(
          stored.deliveryStatus,
          PlanInviteDeliveryStatus.PENDING,
          "a cancelled invite must not be finalized by the stale delivery attempt",
        );
        assert.equal(deliveryCalls, 1);
        assert.match(deliveredToken ?? "", /^[A-Za-z0-9_-]{43}$/);
        const terminalResponse = (deliverySharing as any).toInviteResponse(
          stored,
          deliveredToken,
        );
        assert.equal(terminalResponse.status, "CANCELLED");
        assert.equal(
          terminalResponse.token,
          stored.id,
          "a terminal invite response must not expose the raw bearer",
        );
      } finally {
        releaseDelivery.resolve();
        await Promise.allSettled([creating]);
      }
    },
  );
}

async function assertArchiveWinsBeforeMemberUpdate(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const target = await prisma.sharedMember.create({
        data: {
          weddingPlanId: fixture.plan.id,
          userId: fixture.providerUser.id,
          role: SharedMemberRole.VIEWER,
        },
      });
      const archive = await holdUncommittedPlanArchive(fixture.plan.id);
      const update = sharing.updateMemberForPlan(
        authenticatedUser(fixture.owner),
        fixture.plan.id,
        target.id,
        { receiveNotifications: false },
      );

      try {
        await waitForBlockedMutation(
          update,
          "member update while plan archive is uncommitted",
        );
        await archive.commit();
        const [result] = await Promise.allSettled([update]);
        assertArchivedReadOnly(result);
        const stored = await prisma.sharedMember.findUniqueOrThrow({
          where: { id: target.id },
        });
        assert.equal(
          stored.receiveNotifications,
          true,
          "an archived plan must remain read-only for member updates",
        );
      } finally {
        await archive.commit();
        await Promise.allSettled([update]);
      }
    },
  );
}

async function assertArchiveWinsBeforeMemberRemoval(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const target = await prisma.sharedMember.create({
        data: {
          weddingPlanId: fixture.plan.id,
          userId: fixture.providerUser.id,
          role: SharedMemberRole.VIEWER,
        },
      });
      const archive = await holdUncommittedPlanArchive(fixture.plan.id);
      const removal = sharing.removeMemberFromPlan(
        authenticatedUser(fixture.owner),
        fixture.plan.id,
        target.id,
      );

      try {
        await waitForBlockedMutation(
          removal,
          "member removal while plan archive is uncommitted",
        );
        await archive.commit();
        const [result] = await Promise.allSettled([removal]);
        assertArchivedReadOnly(result);
        assert.equal(
          await prisma.sharedMember.count({ where: { id: target.id } }),
          1,
          "an archived plan must remain read-only for member removals",
        );
      } finally {
        await archive.commit();
        await Promise.allSettled([removal]);
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertRevocationWinsBeforeMemberUpdate();
    await assertRevocationWinsBeforeMemberRemoval();
    await assertRevocationWinsBeforeMemberCreation();
    await assertRevocationWinsBeforeInviteCreation();
    await assertRevocationWinsBeforeInviteCancellation();
    await assertRevocationWinsBeforeInviteReissue();
    await assertCancellationSupersedesInFlightDelivery();
    await assertArchiveWinsBeforeMemberUpdate();
    await assertArchiveWinsBeforeMemberRemoval();
    console.log(
      "PASS - Phase 2 delegated sharing mutations serialize permission and lifecycle revocation.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
