import "reflect-metadata";

import assert from "node:assert/strict";
import {
  NotificationPriority,
  NotificationType,
  PrismaClient,
  WeddingTaskStatus,
} from "@prisma/client";
import { NotificationsService } from "../../src/notifications/notifications.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { PermissionService } from "../../src/sharing/permission.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createQuoteDecisionFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
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
const notifications = new NotificationsService(
  prisma as any,
  new PermissionService(prisma as any),
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

async function holdUncommittedPreferenceDisable(
  userId: string,
): Promise<{ commit: () => Promise<void> }> {
  const disabled = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await tx.$queryRaw`
        SELECT "id"
        FROM "User"
        WHERE "id" = ${userId}
        FOR UPDATE
      `;
      await tx.notificationPreference.update({
        where: { userId },
        data: { providerMessagesEnabled: false },
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
  assert.equal(state, "blocked", `${label} must be waiting on the row lock`);
}

async function assertDisableWinsBeforeNotification(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      await prisma.notificationPreference.create({
        data: {
          userId: fixture.owner.id,
          providerMessagesEnabled: true,
        },
      });
      const disable = await holdUncommittedPreferenceDisable(fixture.owner.id);
      const create = notifications.createNotification({
        userId: fixture.owner.id,
        weddingPlanId: fixture.plan.id,
        type: NotificationType.QUOTE_OFFER_RECEIVED,
        title: "Preference race notification",
        body: "This notification must lose to the committed disable.",
        entityType: "quote_request",
        entityId: fixture.quoteRequest.id,
        dedupeKey: `${fixture.scope}:preference-race`,
      });

      try {
        await waitForBlockedMutation(
          create,
          "notification while preference disable is uncommitted",
        );
        await disable.commit();
        assert.equal(await create, null);
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              dedupeKey: `${fixture.scope}:preference-race`,
            },
          }),
          0,
          "a committed preference disable must prevent notification persistence",
        );
      } finally {
        await disable.commit();
      }
    },
  );
}

async function assertContentPreferencesControlDurableWork(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      try {
        await prisma.notificationPreference.create({
          data: {
            userId: fixture.owner.id,
            taskRemindersEnabled: false,
            paymentRemindersEnabled: true,
            providerMessagesEnabled: false,
          },
        });
        const category = await prisma.budgetCategory.create({
          data: {
            weddingPlanId: fixture.plan.id,
            name: `Notification preference ${fixture.scope}`,
            normalizedName: `notification-preference-${fixture.scope}`,
          },
        });
        const cost = await prisma.weddingCost.create({
          data: {
            weddingPlanId: fixture.plan.id,
            budgetCategoryId: category.id,
            title: `Notification preference ${fixture.scope}`,
            totalAmount: 100,
          },
        });
        const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
        const disabledTask = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Disabled task reminder ${fixture.scope}`,
            dueDate,
          },
        });
        const enabledPayment = await prisma.paymentSchedule.create({
          data: {
            weddingCostId: cost.id,
            amount: 10,
            dueDate,
          },
        });

        assert.equal(await notifications.generateDueNotifications(), 1);
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              entityType: "task",
              entityId: disabledTask.id,
            },
          }),
          0,
          "disabled task reminders must create no notification",
        );
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              entityType: "payment_schedule",
              entityId: enabledPayment.id,
            },
          }),
          1,
          "enabled payment reminders must create one notification",
        );

        const suppressedProviderNotification =
          await notifications.createNotification({
            userId: fixture.owner.id,
            weddingPlanId: fixture.plan.id,
            type: NotificationType.QUOTE_OFFER_RECEIVED,
            priority: NotificationPriority.HIGH,
            title: "Suppressed quote notification",
            body: "This notification must not be persisted.",
            entityType: "quote_request",
            entityId: fixture.quoteRequest.id,
            dedupeKey: `${fixture.scope}:suppressed-provider-notification`,
          });
        assert.equal(suppressedProviderNotification, null);
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              entityType: "quote_request",
              entityId: fixture.quoteRequest.id,
            },
          }),
          0,
          "disabled provider messages must create no notification",
        );

        const generalNotification = await notifications.createNotification({
          userId: fixture.owner.id,
          weddingPlanId: fixture.plan.id,
          type: NotificationType.GENERAL,
          title: "In-app account notification",
          body: "General in-app notifications remain available.",
          dedupeKey: `${fixture.scope}:general-notification`,
        });
        assert.ok(
          generalNotification,
          "content preferences must not disable general in-app notifications",
        );

        await prisma.weddingTask.update({
          where: { id: disabledTask.id },
          data: { status: WeddingTaskStatus.DONE },
        });
        await prisma.notificationPreference.update({
          where: { userId: fixture.owner.id },
          data: {
            taskRemindersEnabled: true,
            paymentRemindersEnabled: false,
            providerMessagesEnabled: true,
          },
        });
        const enabledTask = await prisma.weddingTask.create({
          data: {
            weddingPlanId: fixture.plan.id,
            title: `Enabled task reminder ${fixture.scope}`,
            dueDate,
          },
        });
        const disabledPayment = await prisma.paymentSchedule.create({
          data: {
            weddingCostId: cost.id,
            amount: 20,
            dueDate,
          },
        });

        assert.equal(await notifications.generateDueNotifications(), 1);
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              entityType: "task",
              entityId: enabledTask.id,
            },
          }),
          1,
          "enabled task reminders must create one notification",
        );
        assert.equal(
          await prisma.notification.count({
            where: {
              userId: fixture.owner.id,
              entityType: "payment_schedule",
              entityId: disabledPayment.id,
            },
          }),
          0,
          "disabled payment reminders must create no notification",
        );

        const notificationIds = (
          await prisma.notification.findMany({
            where: { userId: fixture.owner.id },
            select: { id: true },
          })
        ).map((notification) => notification.id);
        assert.equal(
          await prisma.outboxEvent.count({
            where: {
              aggregateType: "notification",
              aggregateId: { in: notificationIds },
            },
          }),
          notificationIds.length,
          "each persisted notification must have exactly one durable outbox event",
        );
      } finally {
        await prisma.weddingTask.deleteMany({
          where: { weddingPlanId: fixture.plan.id },
        });
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertDisableWinsBeforeNotification();
    await assertContentPreferencesControlDurableWork();
    console.log(
      "PASS - Phase 2 notification preferences control real notification and outbox writes.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
