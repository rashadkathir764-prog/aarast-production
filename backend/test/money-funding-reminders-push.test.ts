import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { NotificationType, Prisma, UserStatus } from "@prisma/client";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import { OutboxEventTypes } from "../src/platform/outbox/outbox.constants";
import { notificationsService } from "./support/owner-ports";
import { expectedFundingRow } from "../src/notifications/plan-reminders";
import {
  isPushNotificationType,
  pushNotificationCopy,
} from "../src/push/push-notification.policy";
import { startOfRiyadhDay } from "../src/shared-kernel/time/business-day";
import { riyadhDay } from "../src/modules/finance/public/finance.port";

// RA-BE-187, RA-BE-188, RA-MO-321 (Q-40: the reminder is built). The app
// promises money reminders: «نذكّرك {day}» on a payment date
// (`cost_payment_screens.dart`, `due_date_sheets.dart`), «ونذكّرك فيها» on a
// loan's repayments (`funding_sheets.dart`), «ما راح يوصلك موعد دفعة» when the
// phone's notices are off (`push_off_card.dart`), «نذكّرك قبلها بيوم ويومها»
// on promised money (`funding_widgets.dart`) and «ونذكرك بموعد استلامه» on the
// bride's mahr (`mahr_screen.dart`). Each promise is held here.

const DAY_MS = 24 * 60 * 60 * 1000;

const MONEY_PUSH_TYPES = [
  NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
  NotificationType.PAYMENT_SCHEDULE_OVERDUE,
  NotificationType.LOAN_REPAYMENT_DUE_SOON,
  NotificationType.LOAN_REPAYMENT_OVERDUE,
  NotificationType.BUDGET_CATEGORY_EXCEEDED,
  NotificationType.FUNDING_EXPECTED,
];

/** A stored day (00:00 UTC, as the app saves a picked day) `offset` days from today in Sana'a. */
function storedDay(offset: number): Date {
  const today = riyadhDay(new Date());
  return new Date(Date.parse(`${today}T00:00:00.000Z`) + offset * DAY_MS);
}

test("RA-BE-187: payment, repayment and over-budget reminders reach the phone", () => {
  for (const type of MONEY_PUSH_TYPES) {
    assert.equal(isPushNotificationType(type), true, type);
  }
});

test("RA-BE-187: the lock screen tells a money reminder with no name or amount", () => {
  const copies = [
    ...MONEY_PUSH_TYPES.map((type) => [type, pushNotificationCopy(type)] as const),
    [
      NotificationType.FUNDING_EXPECTED,
      pushNotificationCopy(NotificationType.FUNDING_EXPECTED, { reminder: "ON_THE_DAY" }),
    ] as const,
  ];
  for (const [type, copy] of copies) {
    // B5: it points to the app, in neither reader's gender.
    assert.match(copy.body, /في اعّرست/u, type);
    for (const words of [copy.title, copy.body]) {
      assert.doesNotMatch(words, /\d/u, type);
      for (const name of ["القاعة", "العم", "باقي المهر", "مهر"]) {
        assert.equal(words.includes(name), false, `${type}: ${name}`);
      }
    }
  }
  assert.equal(pushNotificationCopy(NotificationType.PAYMENT_SCHEDULE_OVERDUE).title, "دفعة متأخرة");
  assert.equal(pushNotificationCopy(NotificationType.LOAN_REPAYMENT_OVERDUE).title, "سداد متأخر");
  // The day before and the day itself read apart.
  assert.notEqual(
    pushNotificationCopy(NotificationType.FUNDING_EXPECTED, { reminder: "DAY_BEFORE" }).title,
    pushNotificationCopy(NotificationType.FUNDING_EXPECTED, { reminder: "ON_THE_DAY" }).title,
  );
});

test("RA-BE-188: promised money is reminded the day before and on the day, one key per source and day", () => {
  const today = startOfRiyadhDay(new Date("2026-11-13T09:00:00.000Z"));
  const source = {
    id: "mahr-rest",
    weddingPlanId: "plan-1",
    kind: "MAHR",
    sourceName: "باقي المهر",
    amount: new Prisma.Decimal("1000000"),
    expectedAt: new Date("2026-11-15T00:00:00.000Z"),
  };
  const twoDaysBefore = expectedFundingRow("owner-1", source, today, "YER");
  const dayBefore = expectedFundingRow("owner-1", source, new Date(today.getTime() + DAY_MS), "YER");
  const onTheDay = expectedFundingRow("owner-1", source, new Date(today.getTime() + 2 * DAY_MS), "YER");
  const dayAfter = expectedFundingRow("owner-1", source, new Date(today.getTime() + 3 * DAY_MS), "YER");
  assert.equal(twoDaysBefore, null);
  assert.equal(dayAfter, null);
  assert.ok(dayBefore && onTheDay);
  assert.equal(dayBefore.type, NotificationType.FUNDING_EXPECTED);
  assert.equal(dayBefore.title, "موعد باقي المهر غدًا");
  assert.equal(onTheDay.title, "موعد باقي المهر اليوم");
  assert.equal((dayBefore.data as any).reminder, "DAY_BEFORE");
  assert.equal((onTheDay.data as any).reminder, "ON_THE_DAY");
  // The amount is for the owner's phone to write (or hide), never in the words.
  assert.equal((dayBefore.data as any).amount, "1000000");
  assert.doesNotMatch(String(dayBefore.body), /1000000|مليون/u);
  assert.equal(dayBefore.entityType, "funding_source");
  assert.equal(dayBefore.routeTarget, "/wedding-plans/plan-1/money/funding");
  assert.notEqual(dayBefore.dedupeKey, onTheDay.dedupeKey);
  // Another source on the same day has its own key.
  const other = expectedFundingRow("owner-1", { ...source, id: "gift" }, new Date(today.getTime() + DAY_MS), "YER");
  assert.notEqual(other?.dedupeKey, dayBefore.dedupeKey);
  // A moved day reminds again.
  const moved = expectedFundingRow(
    "owner-1",
    { ...source, expectedAt: new Date("2026-11-16T00:00:00.000Z") },
    new Date(today.getTime() + 2 * DAY_MS),
    "YER",
  );
  assert.ok(moved);
  assert.notEqual(moved.dedupeKey, dayBefore.dedupeKey);
});

/** The hourly scan over one plan, with the money rows it is given. */
async function scan(input: {
  paymentRemindersEnabled: boolean;
  fundingSources?: Array<Record<string, unknown>>;
}) {
  const now = new Date();
  const created: Array<Record<string, any>> = [];
  const outbox: Array<Record<string, any>> = [];
  const fundingQueries: unknown[] = [];
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: "PLANNING",
    weddingDate: null,
    currency: "YER",
    sharedMembers: [
      {
        userId: "finance-member",
        role: "HELPER",
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
    paymentSchedule: {
      // «نذكّرك {day}»: a payment due in ten days whose own reminder day is today.
      findMany: async () => [
        {
          id: "schedule-1",
          weddingCostId: "cost-1",
          amount: new Prisma.Decimal("300"),
          dueDate: new Date(now.getTime() + 10 * DAY_MS),
          remindAt: now,
          rescheduledFrom: null,
          status: "PENDING",
          weddingCost: {
            weddingPlanId: plan.id,
            title: "القاعة",
            partyName: null,
            providerId: null,
            privateToUserId: null,
            totalAmount: new Prisma.Decimal("1000"),
            paidAmount: new Prisma.Decimal("0"),
          },
        },
      ],
    },
    contributionEvent: { findMany: async () => [] },
    budgetCategory: {
      findMany: async () => [
        {
          id: "category-1",
          weddingPlanId: plan.id,
          name: "القاعة",
          allocatedAmount: new Prisma.Decimal("100"),
        },
      ],
    },
    weddingCost: {
      findMany: async () => [
        { budgetCategoryId: "category-1", totalAmount: new Prisma.Decimal("150"), estimateCover: "WHOLE", estimatePart: null },
      ],
    },
    // «ونذكّرك فيها»: a repayment of a loan that arrived.
    loanRepayment: {
      findMany: async () => [
        {
          id: "repayment-1",
          amount: new Prisma.Decimal("50"),
          dueDate: new Date(now.getTime() + 3 * DAY_MS),
          fundingSource: { weddingPlanId: plan.id, sourceName: "العم" },
        },
      ],
    },
    fundingSource: {
      findMany: async (args: unknown) => {
        fundingQueries.push(args);
        return input.fundingSources ?? [];
      },
    },
    notificationPreference: {
      findMany: async () => [
        {
          userId: "owner-1",
          taskRemindersEnabled: true,
          paymentRemindersEnabled: input.paymentRemindersEnabled,
          providerMessagesEnabled: true,
        },
      ],
    },
    notification: {
      createManyAndReturn: async ({ data }: { data: Array<Record<string, any>> }) => {
        created.push(...data);
        return data.map((item, index) => ({ ...item, id: `created-${index}` }));
      },
    },
    outboxEvent: {
      create: async ({ data }: { data: Record<string, any> }) => {
        outbox.push(data);
        return { id: `outbox-${outbox.length}` };
      },
    },
  };
  const prisma = { $transaction: async (operation: any) => operation(tx) } as any;
  const service = notificationsService(prisma, {} as any, new OutboxService());
  await service.generateDueNotifications();
  const pushed = new Set(
    outbox
      .filter((event) => event.type === OutboxEventTypes.pushNotificationRequested)
      .map((event) => event.aggregateId),
  );
  return {
    created: created.map(
      (row, index): Record<string, any> => ({ ...row, pushed: pushed.has(`created-${index}`) }),
    ),
    fundingQueries,
  };
}

const sources = () => [
  // «ونذكرك بموعد استلامه»: the bride's mahr rest, expected tomorrow.
  {
    id: "mahr-rest",
    weddingPlanId: "plan-1",
    kind: "MAHR",
    sourceName: "باقي المهر",
    amount: new Prisma.Decimal("1000000"),
    expectedAt: storedDay(1),
  },
  // A «موعود» gift expected today.
  {
    id: "gift",
    weddingPlanId: "plan-1",
    kind: "FAMILY_SUPPORT",
    sourceName: "الوالد",
    amount: new Prisma.Decimal("200000"),
    expectedAt: storedDay(0),
  },
  // Promised money whose day passed reads «متأخر» in the app; it is not reminded again.
  {
    id: "late",
    weddingPlanId: "plan-1",
    kind: "GIFT",
    sourceName: "الخال",
    amount: new Prisma.Decimal("5000"),
    expectedAt: storedDay(-1),
  },
];

test("RA-BE-187, RA-BE-188: the hourly scan reminds money and promised money, and pushes each to the owner's phone", async () => {
  const { created, fundingQueries } = await scan({
    paymentRemindersEnabled: true,
    fundingSources: sources(),
  });
  const owner = created.filter((row) => row.userId === "owner-1");
  const sent = owner.map((row) => `${row.type}:${row.entityId}:${row.pushed}`).sort();
  assert.deepEqual(sent, [
    `${NotificationType.BUDGET_CATEGORY_EXCEEDED}:category-1:true`,
    `${NotificationType.FUNDING_EXPECTED}:gift:true`,
    `${NotificationType.FUNDING_EXPECTED}:mahr-rest:true`,
    `${NotificationType.LOAN_REPAYMENT_DUE_SOON}:repayment-1:true`,
    `${NotificationType.PAYMENT_SCHEDULE_DUE_SOON}:schedule-1:true`,
  ]);
  const byId = new Map(owner.map((row) => [row.entityId, row]));
  assert.equal(byId.get("mahr-rest")?.data.reminder, "DAY_BEFORE");
  assert.equal(byId.get("gift")?.data.reminder, "ON_THE_DAY");
  // Promised money is the owner's private picture (D59): no member reads it.
  assert.equal(
    created.some((row) => row.userId !== "owner-1" && row.type === NotificationType.FUNDING_EXPECTED),
    false,
  );
  // The scan reads the promised money through finance's port, up to tomorrow's end.
  assert.equal(fundingQueries.length, 1);
  const where = (fundingQueries[0] as any).where;
  assert.equal(where.status, "PLEDGED");
  assert.deepEqual(where.weddingPlanId, { in: ["plan-1"] });
  assert.equal(
    riyadhDay(where.expectedAt.lte),
    riyadhDay(new Date(startOfRiyadhDay().getTime() + DAY_MS)),
  );
});

test("RA-BE-187: the «الدفعات» setting turns every money and promised-money reminder off", async () => {
  const { created } = await scan({
    paymentRemindersEnabled: false,
    fundingSources: sources(),
  });
  const owner = created.filter((row) => row.userId === "owner-1");
  assert.deepEqual(owner, []);
});
