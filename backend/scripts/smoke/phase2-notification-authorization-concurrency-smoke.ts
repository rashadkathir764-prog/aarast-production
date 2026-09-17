import "reflect-metadata";

import assert from "node:assert/strict";
import {
  NotificationType,
  PaymentScheduleStatus,
  Prisma,
  PrismaClient,
  ProviderStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, notificationsService } from "./support/owner-ports";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
  createPermissionRevocationFixture: (
    prisma: unknown,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  createQuoteDecisionFixture: (
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
const notifications = notificationsService(
  prisma,
  new PermissionService(prisma as any, ownerPorts.plans),
  new OutboxService(),
);

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

async function holdMutation(
  operation: (tx: Prisma.TransactionClient) => Promise<void>,
): Promise<{ commit: () => Promise<void> }> {
  const acquired = deferred();
  const release = deferred();
  let committed = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await operation(tx);
      acquired.resolve();
      await release.promise;
    },
    { timeout: 20_000 },
  );
  await acquired.promise;
  return {
    commit: async () => {
      if (!committed) {
        committed = true;
        release.resolve();
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
  assert.equal(state, "blocked", `${label} must wait on the lifecycle lock`);
}

function errorCode(error: unknown): unknown {
  const response = (error as { getResponse?: () => unknown })?.getResponse?.();
  return typeof response === "object" && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

async function financialRevocationWinsPersonalMutation(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await prisma.sharedMember.update({
        where: { id: fixture.sharedMember.id },
        data: { canViewMoney: true, canManageMoney: false },
      });
      const stored = await prisma.notification.create({
        data: {
          userId: fixture.member.id,
          weddingPlanId: fixture.plan.id,
          type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
          title: "Financial authorization race",
          body: "This row must remain unread after access is revoked.",
          entityType: "payment_schedule",
          entityId: `${fixture.scope}:schedule`,
          dedupeKey: `${fixture.scope}:financial-personal-mutation`,
        },
      });
      const revocation = await holdMutation(async (tx) => {
        await tx.sharedMember.update({
          where: { id: fixture.sharedMember.id },
          data: { canViewMoney: false, canManageMoney: false },
        });
      });
      const markRead = notifications.markRead(
        { id: fixture.member.id } as any,
        stored.id,
      );

      try {
        await waitForBlockedMutation(
          markRead,
          "financial mark-read during permission revocation",
        );
        await revocation.commit();
        await assert.rejects(markRead, (error: unknown) => {
          assert.equal(
            (error as { getStatus?: () => unknown })?.getStatus?.(),
            404,
          );
          return true;
        });
        const after = await prisma.notification.findUniqueOrThrow({
          where: { id: stored.id },
        });
        assert.equal(after.readAt, null);
        const inbox = await notifications.list(
          { id: fixture.member.id } as any,
        );
        assert.equal(
          inbox.items.some((notification) => notification.id === stored.id),
          false,
        );
        assert.equal(
          (
            await notifications.unreadCount({
              id: fixture.member.id,
            } as any)
          ).count,
          0,
        );
        await assert.rejects(
          notifications.findOne(
            { id: fixture.member.id } as any,
            stored.id,
          ),
          (error: unknown) => {
            assert.equal(
              (error as { getStatus?: () => unknown })?.getStatus?.(),
              404,
            );
            return true;
          },
        );
        assert.deepEqual(
          await notifications.markAllRead(
            { id: fixture.member.id } as any,
            fixture.plan.id,
          ),
          { updated: 0 },
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([markRead]);
      }
    },
  );
}

async function providerSuspensionWinsPersonalMutation(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const stored = await prisma.notification.create({
        data: {
          userId: fixture.providerUser.id,
          type: NotificationType.GENERAL,
          title: "Provider lifecycle race",
          body: "This row must remain active after provider suspension.",
          data: {
            providerId: fixture.provider.id,
            recipientAudience: "PROVIDER",
          },
          dedupeKey: `${fixture.scope}:provider-personal-mutation`,
        },
      });
      const suspension = await holdMutation(async (tx) => {
        await tx.$queryRaw`
          SELECT "id"
          FROM "User"
          WHERE "id" = ${fixture.providerUser.id}
          FOR UPDATE
        `;
        await tx.provider.update({
          where: { id: fixture.provider.id },
          data: { status: ProviderStatus.SUSPENDED },
        });
      });
      const archive = notifications.archive(
        { id: fixture.providerUser.id } as any,
        stored.id,
      );

      try {
        await waitForBlockedMutation(
          archive,
          "provider archive during suspension",
        );
        await suspension.commit();
        await assert.rejects(archive, (error: unknown) => {
          assert.equal(errorCode(error), "PROVIDER_NOT_ACTIVE");
          return true;
        });
        const after = await prisma.notification.findUniqueOrThrow({
          where: { id: stored.id },
        });
        assert.equal(after.readAt, null);
        assert.equal(after.archivedAt, null);
      } finally {
        await suspension.commit();
        await Promise.allSettled([archive]);
      }
    },
  );
}

async function membershipRevocationWinsParticipantFanout(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const revocation = await holdMutation(async (tx) => {
        await tx.sharedMember.update({
          where: { id: fixture.sharedMember.id },
          data: { receiveNotifications: false },
        });
      });
      const dedupeKey = `${fixture.scope}:participant-fanout`;
      const fanout = notifications.createForPlanParticipants(
        fixture.plan.id,
        {
          type: NotificationType.GENERAL,
          title: "Participant authorization race",
          body: "Only a live participant may receive this event.",
          dedupeKey,
        },
      );

      try {
        await waitForBlockedMutation(
          fanout,
          "participant fanout during membership revocation",
        );
        await revocation.commit();
        const created = await fanout;
        assert.deepEqual(
          created.map((notification) => notification.userId),
          [fixture.owner.id],
        );
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.member.id,
              dedupeKey: `${fixture.member.id}:${dedupeKey}`,
            },
          }),
          0,
        );
      } finally {
        await revocation.commit();
        await Promise.allSettled([fanout]);
      }
    },
  );
}

async function revokedMemberLosesPlanNotificationVisibility(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const stored = await prisma.notification.create({
        data: {
          userId: fixture.member.id,
          weddingPlanId: fixture.plan.id,
          type: NotificationType.TASK_DUE_SOON,
          title: "Revoked plan notification",
          body: "A revoked participant must not retain this plan detail.",
          entityType: "task",
          entityId: `${fixture.scope}:revoked-task`,
          dedupeKey: `${fixture.scope}:revoked-plan-visibility`,
        },
      });
      await prisma.sharedMember.delete({
        where: { id: fixture.sharedMember.id },
      });

      const inbox = await notifications.list({
        id: fixture.member.id,
      } as any);
      assert.equal(
        inbox.items.some((notification) => notification.id === stored.id),
        false,
      );
      assert.equal(
        (
          await notifications.unreadCount({
            id: fixture.member.id,
          } as any)
        ).count,
        0,
      );
      await assert.rejects(
        notifications.findOne(
          { id: fixture.member.id } as any,
          stored.id,
        ),
        (error: unknown) => {
          assert.equal(
            (error as { getStatus?: () => unknown })?.getStatus?.(),
            404,
          );
          return true;
        },
      );
      await assert.rejects(
        notifications.markRead(
          { id: fixture.member.id } as any,
          stored.id,
        ),
        (error: unknown) => {
          assert.equal(
            (error as { getStatus?: () => unknown })?.getStatus?.(),
            404,
          );
          return true;
        },
      );
      const after = await prisma.notification.findUniqueOrThrow({
        where: { id: stored.id },
      });
      assert.equal(after.readAt, null);
    },
  );
}

async function membershipRevocationWinsSchedulerFanout(): Promise<void> {
  await withFixture(
    (environment) =>
      createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      try {
        const task = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Scheduler authorization ${fixture.scope}`,
            dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
          },
        });
        const revocation = await holdMutation(async (tx) => {
          await tx.sharedMember.update({
            where: { id: fixture.sharedMember.id },
            data: { receiveNotifications: false },
          });
        });
        const generation = notifications.generateDueNotifications();

        try {
          await waitForBlockedMutation(
            generation,
            "scheduler fanout during membership revocation",
          );
          await revocation.commit();
          assert.equal(await generation, 1);
          assert.equal(
            await prisma.notification.count({
              where: {
                userId: fixture.owner.id,
                entityType: "task",
                entityId: task.id,
              },
            }),
            1,
          );
          assert.equal(
            await prisma.notification.count({
              where: {
                userId: fixture.member.id,
                entityType: "task",
                entityId: task.id,
              },
            }),
            0,
          );
        } finally {
          await revocation.commit();
          await Promise.allSettled([generation]);
        }
      } finally {
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function taskCompletionWinsImmediateFanout(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      try {
        const task = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Immediate task lifecycle ${fixture.scope}`,
            dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
          },
        });
        const completion = await holdMutation(async (tx) => {
          await tx.weddingTask.update({
            where: { id: task.id },
            data: { status: WeddingTaskStatus.DONE },
          });
        });
        const fanout = notifications.notifyTaskDue(task);

        try {
          await waitForBlockedMutation(
            fanout,
            "immediate task fanout during completion",
          );
          await completion.commit();
          await fanout;
          assert.equal(
            await prisma.notification.count({
              where: {
                entityType: "task",
                entityId: task.id,
              },
            }),
            0,
          );
        } finally {
          await completion.commit();
          await Promise.allSettled([fanout]);
        }
      } finally {
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function archivedPlanStopsImmediateFanout(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      try {
        const task = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Archived plan task ${fixture.scope}`,
            dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
          },
        });
        await prisma.weddingPlan.update({
          where: { id: fixture.plan.id },
          data: { status: WeddingPlanStatus.ARCHIVED },
        });

        await notifications.notifyTaskDue(task);
        assert.equal(
          await prisma.notification.count({
            where: {
              entityType: "task",
              entityId: task.id,
            },
          }),
          0,
        );
      } finally {
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function taskCompletionWinsSchedulerScan(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      try {
        const task = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Scheduler task lifecycle ${fixture.scope}`,
            dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
          },
        });
        const completion = await holdMutation(async (tx) => {
          await tx.weddingTask.update({
            where: { id: task.id },
            data: { status: WeddingTaskStatus.DONE },
          });
        });
        const generation = notifications.generateDueNotifications();

        try {
          await waitForBlockedMutation(
            generation,
            "scheduler scan during task completion",
          );
          await completion.commit();
          assert.equal(await generation, 0);
          assert.equal(
            await prisma.notification.count({
              where: {
                entityType: "task",
                entityId: task.id,
              },
            }),
            0,
          );
        } finally {
          await completion.commit();
          await Promise.allSettled([generation]);
        }
      } finally {
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function scheduleCancellationWinsSchedulerScan(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const category = await prisma.budgetCategory.create({
        data: {
          weddingPlanId: fixture.plan.id,
          name: `Scheduler lifecycle ${fixture.scope}`,
          normalizedName: `scheduler-lifecycle-${fixture.scope}`,
        },
      });
      const cost = await prisma.weddingCost.create({
        data: {
          weddingPlanId: fixture.plan.id,
          budgetCategoryId: category.id,
          title: `Scheduler lifecycle ${fixture.scope}`,
          totalAmount: 100,
        },
      });
      const schedule = await prisma.paymentSchedule.create({
        data: {
          weddingCostId: cost.id,
          amount: 10,
          dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
        },
      });
      const cancellation = await holdMutation(async (tx) => {
        await tx.$queryRaw`
          SELECT "id"
          FROM "WeddingCost"
          WHERE "id" = ${cost.id}
          FOR UPDATE
        `;
        await tx.paymentSchedule.update({
          where: { id: schedule.id },
          data: { status: PaymentScheduleStatus.CANCELLED },
        });
      });
      const generation = notifications.generateDueNotifications();

      try {
        await waitForBlockedMutation(
          generation,
          "scheduler scan during schedule cancellation",
        );
        await cancellation.commit();
        assert.equal(await generation, 0);
        assert.equal(
          await prisma.notification.count({
            where: {
              entityType: "payment_schedule",
              entityId: schedule.id,
            },
          }),
          0,
        );
      } finally {
        await cancellation.commit();
        await Promise.allSettled([generation]);
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await financialRevocationWinsPersonalMutation();
    await providerSuspensionWinsPersonalMutation();
    await membershipRevocationWinsParticipantFanout();
    await revokedMemberLosesPlanNotificationVisibility();
    await membershipRevocationWinsSchedulerFanout();
    await taskCompletionWinsImmediateFanout();
    await archivedPlanStopsImmediateFanout();
    await taskCompletionWinsSchedulerScan();
    await scheduleCancellationWinsSchedulerScan();
    console.log(
      "PASS - Notification mutations and fanout serialize against live authorization revocation.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
