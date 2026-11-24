import "reflect-metadata";

import assert from "node:assert/strict";
import { mock, test } from "node:test";
import { NotificationType, UserStatus } from "@prisma/client";
import { SCHEDULE_CRON_OPTIONS } from "@nestjs/schedule/dist/schedule.constants";
import { BookingRemindersScheduler } from "../src/marketplace/booking-reminders.scheduler";
import { QuoteRequestExpiryScheduler } from "../src/marketplace/quote-request-expiry.scheduler";
import { NotificationRemindersScheduler } from "../src/notifications/notification-reminders.scheduler";
import { OutboxEventTypes } from "../src/platform/outbox/outbox.constants";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import {
  pushNotBefore,
  isQuietHoursExempt,
} from "../src/push/push-notification.policy";
import {
  isQuietHour,
  quietHoursEnd,
} from "../src/shared-kernel/time/quiet-hours";
import { notificationsService } from "./support/owner-ports";

// RA-BE-185: a push created between 21:00 and 09:00 in Aden (UTC+3, no
// daylight saving) is held until 09:00. Chat and a booking request are
// exempt (OTP is no notification and never comes through here). The day
// scans run from 09:05, not right after midnight.

/** An instant at `hhmm` Aden time on 2026-11-24 (UTC+3). */
function aden(hhmm: string, day = "2026-11-24"): Date {
  const [hours, minutes] = hhmm.split(":").map(Number);
  return new Date(Date.parse(`${day}T00:00:00.000Z`) + ((hours! - 3) * 60 + minutes!) * 60_000);
}

test("quiet hours run from 21:00 to 09:00 Aden, ends included on the morning side only", () => {
  assert.equal(isQuietHour(aden("20:59")), false);
  assert.equal(isQuietHour(aden("21:00")), true);
  assert.equal(isQuietHour(aden("23:59")), true);
  assert.equal(isQuietHour(aden("00:15", "2026-11-25")), true);
  assert.equal(isQuietHour(aden("08:59", "2026-11-25")), true);
  assert.equal(isQuietHour(aden("09:00", "2026-11-25")), false);
  assert.equal(isQuietHour(aden("12:00")), false);
});

test("a held push waits for the next 09:00 Aden, tonight's or tomorrow's", () => {
  assert.equal(quietHoursEnd(aden("21:00")).toISOString(), aden("09:00", "2026-11-25").toISOString());
  assert.equal(quietHoursEnd(aden("23:59")).toISOString(), aden("09:00", "2026-11-25").toISOString());
  // After midnight the 09:00 is the same calendar day.
  assert.equal(quietHoursEnd(aden("00:15", "2026-11-25")).toISOString(), aden("09:00", "2026-11-25").toISOString());
  assert.equal(quietHoursEnd(aden("08:59", "2026-11-25")).toISOString(), aden("09:00", "2026-11-25").toISOString());
});

test("a push is held at night except chat and a booking request; any other type waits", () => {
  const night = aden("23:30");
  assert.equal(isQuietHoursExempt(NotificationType.CHAT_MESSAGE_RECEIVED), true);
  assert.equal(isQuietHoursExempt(NotificationType.BOOKING_REQUESTED), true);
  assert.equal(pushNotBefore(NotificationType.CHAT_MESSAGE_RECEIVED, night), null);
  assert.equal(pushNotBefore(NotificationType.BOOKING_REQUESTED, night), null);
  // The reminders, the offers, the booking steps and the money types of
  // commit 51dfa3fb are all held.
  for (const type of [
    NotificationType.TASK_DUE_SOON,
    NotificationType.TASK_OVERDUE,
    NotificationType.TASK_ASSIGNED,
    NotificationType.WEDDING_COUNTDOWN,
    NotificationType.QUOTE_OFFER_RECEIVED,
    NotificationType.BOOKING_UPDATED,
    NotificationType.QUOTE_REQUEST_EXPIRING,
    NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
    NotificationType.PAYMENT_SCHEDULE_OVERDUE,
    NotificationType.LOAN_REPAYMENT_DUE_SOON,
    NotificationType.LOAN_REPAYMENT_OVERDUE,
    NotificationType.BUDGET_CATEGORY_EXCEEDED,
    NotificationType.FUNDING_EXPECTED,
  ]) {
    assert.equal(
      pushNotBefore(type, night)?.toISOString(),
      aden("09:00", "2026-11-25").toISOString(),
      type,
    );
    assert.equal(pushNotBefore(type, aden("10:00")), null, type);
  }
});

/** One notification written through the one service path, at `at`, and the outbox rows it queued. */
async function writeAt(at: Date, type: NotificationType, data: Record<string, unknown> = {}) {
  const outbox: Array<Record<string, any>> = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      if (sql.includes('FROM "User"')) return [{ id: "user-1", status: UserStatus.ACTIVE }];
      return [];
    },
    user: { findMany: async () => [] },
    notificationPreference: { findUnique: async () => null },
    notification: {
      create: async ({ data: row }: { data: Record<string, any> }) => ({
        ...row,
        id: "notification-1",
        createdAt: at,
        readAt: null,
        archivedAt: null,
      }),
    },
    outboxEvent: {
      create: async ({ data: row }: { data: Record<string, any> }) => {
        outbox.push(row);
        return { id: `outbox-${outbox.length}` };
      },
    },
  };
  const service = notificationsService({} as any, {} as any, new OutboxService());
  mock.timers.enable({ apis: ["Date"], now: at });
  try {
    await service.createNotificationInTransaction(tx as any, {
      userId: "user-1",
      type,
      title: "عنوان",
      body: "نص",
      data,
    } as any);
  } finally {
    mock.timers.reset();
  }
  return outbox;
}

test("the service queues a night push for 09:00 and leaves the in-app row and the day push alone", async () => {
  const night = await writeAt(aden("00:20", "2026-11-25"), NotificationType.TASK_DUE_SOON);
  const created = night.find((event) => event.type === OutboxEventTypes.notificationCreated);
  const push = night.find((event) => event.type === OutboxEventTypes.pushNotificationRequested);
  assert.ok(created && push);
  // The inbox and the live badge are not held; only the phone's push is.
  assert.equal(created.nextAttemptAt, undefined);
  assert.equal(push.nextAttemptAt.toISOString(), aden("09:00", "2026-11-25").toISOString());

  const day = await writeAt(aden("13:00"), NotificationType.TASK_DUE_SOON);
  const dayPush = day.find((event) => event.type === OutboxEventTypes.pushNotificationRequested);
  assert.ok(dayPush);
  assert.equal(dayPush.nextAttemptAt, undefined);
});

test("a night chat message and a night booking request go out at once", async () => {
  for (const type of [NotificationType.CHAT_MESSAGE_RECEIVED, NotificationType.BOOKING_REQUESTED]) {
    const events = await writeAt(aden("23:45"), type);
    const push = events.find((event) => event.type === OutboxEventTypes.pushNotificationRequested);
    assert.ok(push, type);
    assert.equal(push.nextAttemptAt, undefined, type);
  }
});

test("the money push types of 51dfa3fb are held at night too", async () => {
  const events = await writeAt(aden("22:10"), NotificationType.FUNDING_EXPECTED, { reminder: "DAY_BEFORE" });
  const push = events.find((event) => event.type === OutboxEventTypes.pushNotificationRequested);
  assert.ok(push);
  assert.equal(push.nextAttemptAt.toISOString(), aden("09:00", "2026-11-25").toISOString());
});

function cronOf(scheduler: object, method: string): string {
  const options = Reflect.getMetadata(
    SCHEDULE_CRON_OPTIONS,
    (scheduler as any)[method],
  ) as { cronTime: string };
  return options.cronTime;
}

test("the day scans open at 09:05, 09:10 and 09:15 Aden, hourly, not at 00:15", () => {
  const reminders = new NotificationRemindersScheduler({} as any);
  const bookings = new BookingRemindersScheduler({} as any);
  const expiry = new QuoteRequestExpiryScheduler({} as any);
  assert.equal(cronOf(reminders, "generateDueReminders"), "5 * * * *");
  assert.equal(cronOf(bookings, "sendDueReminders"), "10 * * * *");
  assert.equal(cronOf(expiry, "expireOverdueRequests"), "15 * * * *");
});

test("the reminder scan makes no day reminder at night, and does at 09:05", async () => {
  const calls: unknown[] = [];
  const scheduler = new NotificationRemindersScheduler({
    generateDueNotifications: async (options: unknown) => {
      calls.push(options);
      return 0;
    },
  } as any);
  await scheduler.generateDueReminders(aden("00:05", "2026-11-25"));
  await scheduler.generateDueReminders(aden("20:05"));
  await scheduler.generateDueReminders(aden("21:05"));
  await scheduler.generateDueReminders(aden("09:05"));
  assert.deepEqual(calls, [
    { dayReminders: false },
    { dayReminders: true },
    { dayReminders: false },
    { dayReminders: true },
  ]);
});

test("the booking reminders wait for the morning, the overdue completions do not", async () => {
  let completions = 0;
  let reminders = 0;
  const scheduler = new BookingRemindersScheduler({
    completeOverdueBookings: async () => {
      completions += 1;
      return { completed: 0, failures: [] };
    },
    sendDueReminders: async () => {
      reminders += 1;
      return { sent: 0, failures: [] };
    },
  } as any);
  await scheduler.sendDueReminders(aden("00:10", "2026-11-25"));
  assert.deepEqual([completions, reminders], [1, 0]);
  await scheduler.sendDueReminders(aden("09:10", "2026-11-25"));
  assert.deepEqual([completions, reminders], [2, 1]);
});

test("«طلب ينتهي بكرة» goes out in the window; the expiry itself runs at any hour", async () => {
  const runs: unknown[] = [];
  const scheduler = new QuoteRequestExpiryScheduler({
    run: async (_now: Date, options: unknown) => {
      runs.push(options);
      return { expired: 0, warned: 0, skipped: 0, failures: [] };
    },
  } as any);
  await scheduler.expireOverdueRequests(aden("02:15", "2026-11-25"));
  await scheduler.expireOverdueRequests(aden("09:15", "2026-11-25"));
  assert.deepEqual(runs, [{ warn: false }, { warn: true }]);
});
