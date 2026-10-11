import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  NotificationPriority,
  NotificationType,
  Prisma,
  UserStatus,
} from "@prisma/client";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import { notificationsService } from "./support/owner-ports";
import {
  budgetCategoryExceededRow,
  daysUntilWedding,
  loanRepaymentRow,
  weddingCountdownMilestone,
  weddingCountdownRow,
} from "../src/notifications/plan-reminders";
import { isPushNotificationType, pushNotificationCopy } from "../src/push/push-notification.policy";
import { startOfRiyadhDay } from "../src/shared-kernel/time/business-day";

// Plan-level reminders of the hourly scan (V1 checklist 4.8, 4.17).

const today = startOfRiyadhDay(new Date("2026-10-11T09:00:00.000Z"));

test("an over-budget category alerts the owner once per allocation", () => {
  const category = {
    id: "category-1",
    weddingPlanId: "plan-1",
    name: "القاعة",
    allocatedAmount: new Prisma.Decimal("500000"),
    committedAmount: new Prisma.Decimal("650000"),
  };
  const row = budgetCategoryExceededRow("owner-1", category);

  assert.equal(row.userId, "owner-1");
  assert.equal(row.type, NotificationType.BUDGET_CATEGORY_EXCEEDED);
  assert.equal(row.priority, NotificationPriority.HIGH);
  assert.equal(row.entityType, "budget_category");
  assert.equal(row.routeTarget, "/wedding-plans/plan-1/money");
  assert.equal(row.body, "بند القاعة تجاوز المخطط (500000) بمبلغ 150000.");

  const raised = budgetCategoryExceededRow("owner-1", {
    ...category,
    allocatedAmount: new Prisma.Decimal("600000"),
  });
  assert.notEqual(raised.dedupeKey, row.dedupeKey);
  assert.equal(
    budgetCategoryExceededRow("owner-1", { ...category, committedAmount: new Prisma.Decimal("700000") }).dedupeKey,
    row.dedupeKey,
    "a further cost on the same allocation does not alert again",
  );
});

test("a loan repayment reminder says due soon or overdue", () => {
  const repayment = {
    id: "repayment-1",
    weddingPlanId: "plan-1",
    sourceName: "العم أحمد",
    amount: new Prisma.Decimal("100000"),
    dueDate: new Date("2026-10-15T00:00:00.000Z"),
  };
  const soon = loanRepaymentRow("owner-1", repayment, today);
  assert.equal(soon.type, NotificationType.LOAN_REPAYMENT_DUE_SOON);
  assert.equal(soon.title, "موعد سداد قريب");
  assert.equal(soon.body, "سداد العم أحمد بقيمة 100000 يستحق قريباً (15/10/2026).");
  assert.equal(soon.entityType, "loan_repayment");
  assert.equal(soon.routeTarget, "/wedding-plans/plan-1/money/funding");

  const late = loanRepaymentRow(
    "owner-1",
    { ...repayment, dueDate: new Date("2026-10-01T00:00:00.000Z") },
    today,
  );
  assert.equal(late.type, NotificationType.LOAN_REPAYMENT_OVERDUE);
  assert.equal(late.priority, NotificationPriority.HIGH);
  assert.notEqual(late.dedupeKey, soon.dedupeKey);
});

test("the wedding countdown reminds a month, a week and a day before", () => {
  assert.equal(weddingCountdownMilestone(45), null);
  assert.equal(weddingCountdownMilestone(30), 30);
  assert.equal(weddingCountdownMilestone(8), 30);
  assert.equal(weddingCountdownMilestone(7), 7);
  assert.equal(weddingCountdownMilestone(2), 7);
  assert.equal(weddingCountdownMilestone(1), 1);
  assert.equal(weddingCountdownMilestone(0), 1);
  assert.equal(weddingCountdownMilestone(-1), null);

  const wedding = new Date("2026-11-10T00:00:00.000Z");
  assert.equal(daysUntilWedding(wedding, today), 30);
  const row = weddingCountdownRow("member-1", { id: "plan-1", weddingDate: wedding }, today);
  assert.ok(row);
  assert.equal(row.type, NotificationType.WEDDING_COUNTDOWN);
  assert.equal(row.body, "باقي 30 يومًا على العرس. راجع المهام والدفعات القادمة.");
  assert.equal(row.routeTarget, "/wedding-plans/plan-1/dashboard");

  const tomorrow = weddingCountdownRow(
    "member-1",
    { id: "plan-1", weddingDate: new Date("2026-10-12T00:00:00.000Z") },
    today,
  );
  assert.equal(tomorrow?.body, "العرس غدًا. راجع آخر المهام والدفعات.");
  assert.equal(tomorrow?.priority, NotificationPriority.HIGH);

  assert.equal(
    weddingCountdownRow("member-1", { id: "plan-1", weddingDate: null }, today),
    null,
  );
  assert.equal(
    weddingCountdownRow("member-1", { id: "plan-1", weddingDate: new Date("2027-03-01T00:00:00.000Z") }, today),
    null,
  );
});

test("postponing the wedding restarts the countdown", () => {
  const before = weddingCountdownRow(
    "member-1",
    { id: "plan-1", weddingDate: new Date("2026-10-15T00:00:00.000Z") },
    today,
  );
  const after = weddingCountdownRow(
    "member-1",
    { id: "plan-1", weddingDate: new Date("2026-10-16T00:00:00.000Z") },
    today,
  );
  assert.ok(before && after);
  assert.notEqual(before.dedupeKey, after.dedupeKey);
});

test("only the countdown is pushed; money reminders stay in the app", () => {
  assert.equal(isPushNotificationType(NotificationType.WEDDING_COUNTDOWN), true);
  assert.equal(pushNotificationCopy(NotificationType.WEDDING_COUNTDOWN).title, "العد التنازلي للعرس");
  for (const type of [
    NotificationType.BUDGET_CATEGORY_EXCEEDED,
    NotificationType.LOAN_REPAYMENT_DUE_SOON,
    NotificationType.LOAN_REPAYMENT_OVERDUE,
  ]) {
    assert.equal(isPushNotificationType(type), false, type);
  }
});

test("the hourly scan sends money reminders to the owner only and honours preferences", async () => {
  const now = new Date();
  const soon = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const captured: Array<Record<string, any>> = [];
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: "PLANNING",
    weddingDate: soon,
    sharedMembers: [
      {
        userId: "finance-member",
        receiveNotifications: true,
        canViewMoney: true,
        canManageMoney: true,
        canManageTasks: true,
      },
    ],
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      if (sql.includes("pg_try_advisory_xact_lock")) return [{ locked: true }];
      if (sql.includes('FROM "User"')) {
        return [
          { id: "owner-1", status: UserStatus.ACTIVE },
          { id: "finance-member", status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: plan.id }];
    },
    weddingPlan: { findMany: async () => [plan] },
    weddingTask: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
    contributionEvent: { findMany: async () => [] },
    budgetCategory: {
      findMany: async () => [
        {
          id: "category-1",
          weddingPlanId: plan.id,
          name: "القاعة",
          allocatedAmount: new Prisma.Decimal("100"),
        },
        {
          id: "category-2",
          weddingPlanId: plan.id,
          name: "التصوير",
          allocatedAmount: new Prisma.Decimal("500"),
        },
      ],
    },
    weddingCost: {
      groupBy: async () => [
        { budgetCategoryId: "category-1", _sum: { totalAmount: new Prisma.Decimal("150") } },
        { budgetCategoryId: "category-2", _sum: { totalAmount: new Prisma.Decimal("200") } },
      ],
    },
    loanRepayment: {
      findMany: async () => [
        {
          id: "repayment-1",
          amount: new Prisma.Decimal("50"),
          dueDate: soon,
          fundingSource: { weddingPlanId: plan.id, sourceName: "العم" },
        },
      ],
    },
    notificationPreference: {
      findMany: async () => [
        {
          userId: "finance-member",
          taskRemindersEnabled: false,
          paymentRemindersEnabled: true,
          providerMessagesEnabled: true,
        },
      ],
    },
    notification: {
      createManyAndReturn: async ({ data }: { data: Array<Record<string, any>> }) => {
        captured.push(...data);
        return data.map((item, index) => ({ ...item, id: `created-${index}` }));
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox" }) },
  };
  const prisma = { $transaction: async (operation: any) => operation(tx) } as any;
  const service = notificationsService(prisma, {} as any, new OutboxService());

  await service.generateDueNotifications();

  const sent = captured.map((row) => `${row.userId}:${row.type}:${row.entityId}`).sort();
  assert.deepEqual(sent, [
    `owner-1:${NotificationType.BUDGET_CATEGORY_EXCEEDED}:category-1`,
    `owner-1:${NotificationType.LOAN_REPAYMENT_DUE_SOON}:repayment-1`,
    `owner-1:${NotificationType.WEDDING_COUNTDOWN}:plan-1`,
  ]);
});
