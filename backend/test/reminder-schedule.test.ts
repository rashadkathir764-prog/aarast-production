import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { NotificationType } from "@prisma/client";
import {
  BOOKING_REMINDER_MILESTONES,
  bookingReminderMilestone,
} from "../src/marketplace/booking-notifications";
import { expectedFundingReminder } from "../src/modules/finance/domain/funding-policy";
import { NotificationsController } from "../src/notifications/notifications.controller";
import {
  DUE_REMINDER_SCAN_CRON,
  TASK_REMINDER_TIME_SCAN_CRON,
} from "../src/notifications/notification-reminders.scheduler";
import {
  isTaskDueReminderDay,
  paymentReminderDue,
  TASK_DUE_REMINDER_DAYS,
  WEDDING_COUNTDOWN_MILESTONES,
  weddingCountdownMilestone,
} from "../src/notifications/plan-reminders";
import { bypassesQuietHours, isQuietHoursExempt } from "../src/push/push-notification.policy";
import {
  QUIET_HOURS_END_HOUR,
  QUIET_HOURS_START_HOUR,
  isQuietHour,
} from "../src/shared-kernel/time/quiet-hours";
import {
  REMINDER_SCAN_WINDOW_DAYS,
  REMINDER_SCHEDULE,
} from "../src/shared-kernel/time/reminder-schedule";

// The phone's «متى يصلك» lines are drawn from `GET /api/v1/notifications/
// schedule`; these hold every number of that answer to what the reminder
// code does, so the two cannot drift apart.

const DAY = 24 * 60 * 60 * 1000;
const today = new Date("2026-12-01T00:00:00+03:00");

test("the schedule endpoint returns the reminder table itself", () => {
  const controller = new NotificationsController({} as never);
  assert.deepEqual(controller.schedule(), { reminderSchedule: REMINDER_SCHEDULE });
  // Before `:id`: «schedule» is a route, not a notice id.
  const routes = Object.getOwnPropertyNames(NotificationsController.prototype);
  assert.ok(routes.indexOf("schedule") < routes.indexOf("findOne"));
  // Plain data: it survives JSON as it is.
  assert.deepEqual(JSON.parse(JSON.stringify(REMINDER_SCHEDULE)), REMINDER_SCHEDULE);
});

// The phone draws its settings lines from this answer; its tests read the
// committed copy (`reminder_timing_lines_test.dart`). This fails when the
// copy drifts from the table; regenerate it with
// `WRITE_REMINDER_SCHEDULE_FIXTURE=1 node --test -r ts-node/register test/reminder-schedule.test.ts`.
test("the phone's copy of the schedule answer is the server's", () => {
  const fixture = path.resolve(__dirname, "../../mobile/test/fixtures/reminder_schedule.json");
  const expected = `${JSON.stringify(new NotificationsController({} as never).schedule(), null, 2)}\n`;
  if (process.env.WRITE_REMINDER_SCHEDULE_FIXTURE === "1") writeFileSync(fixture, expected);
  assert.equal(
    readFileSync(fixture, "utf8").replace(/\r\n/g, "\n"),
    expected,
    "mobile/test/fixtures/reminder_schedule.json is stale (see the comment above)",
  );
});

test("a task is reminded exactly on the table's days, once late", () => {
  assert.equal(TASK_DUE_REMINDER_DAYS, REMINDER_SCHEDULE.tasks.daysBefore);
  for (let days = -3; days <= 40; days += 1) {
    const expected =
      days < 0 || (REMINDER_SCHEDULE.tasks.daysBefore as readonly number[]).includes(days);
    assert.equal(isTaskDueReminderDay(days), expected, String(days));
  }
  assert.equal(REMINDER_SCHEDULE.tasks.overdue, "ONCE");
});

test("the countdown reminds in the table's windows", () => {
  assert.equal(WEDDING_COUNTDOWN_MILESTONES, REMINDER_SCHEDULE.weddingCountdown.daysBefore);
  const milestones = [...REMINDER_SCHEDULE.weddingCountdown.daysBefore].sort((a, b) => a - b);
  for (const milestone of milestones) {
    assert.equal(weddingCountdownMilestone(milestone), milestone);
  }
  assert.equal(weddingCountdownMilestone(Math.max(...milestones) + 1), null);
});

test("a booking is reminded on the table's days", () => {
  assert.equal(BOOKING_REMINDER_MILESTONES, REMINDER_SCHEDULE.bookings.daysBefore);
  for (const days of REMINDER_SCHEDULE.bookings.daysBefore) {
    assert.equal(bookingReminderMilestone(days), days);
  }
  assert.equal(bookingReminderMilestone(Math.max(...REMINDER_SCHEDULE.bookings.daysBefore) + 1), null);
});

test("promised money is reminded on exactly the table's days", () => {
  const reminded: number[] = [];
  for (let days = -2; days <= 10; days += 1) {
    if (expectedFundingReminder(new Date(today.getTime() + days * DAY), today)) reminded.push(days);
  }
  assert.deepEqual(
    reminded.sort((a, b) => a - b),
    [...REMINDER_SCHEDULE.promisedMoney.daysBefore].sort((a, b) => a - b),
  );
});

test("the day scan reads as far ahead as the farthest first reminder, and payments are first told within it", () => {
  assert.equal(REMINDER_SCAN_WINDOW_DAYS, 7);
  assert.equal(REMINDER_SCHEDULE.payments.firstReminderDaysBefore, REMINDER_SCAN_WINDOW_DAYS);
  assert.equal(REMINDER_SCHEDULE.loanRepayments.firstReminderDaysBefore, REMINDER_SCAN_WINDOW_DAYS);
  // A date of its own reminds from that day, not before (D106).
  const due = new Date(today.getTime() + 5 * DAY);
  assert.equal(paymentReminderDue({ dueDate: due, remindAt: new Date(today.getTime() + DAY) }, today), false);
  assert.equal(paymentReminderDue({ dueDate: due, remindAt: today }, today), true);
  assert.equal(REMINDER_SCHEDULE.payments.ownReminderDay, true);
});

test("the scans run when the table says", () => {
  assert.equal(
    DUE_REMINDER_SCAN_CRON,
    `${REMINDER_SCHEDULE.dayScan.everyHourAtMinute} * * * *`,
  );
  assert.equal(
    TASK_REMINDER_TIME_SCAN_CRON,
    `*/${REMINDER_SCHEDULE.tasks.ownReminderTime.checkEveryMinutes} * * * *`,
  );
  assert.equal(REMINDER_SCHEDULE.dayScan.firstHour, QUIET_HOURS_END_HOUR);
});

test("the quiet hours and what comes through them are the policy's own", () => {
  assert.equal(REMINDER_SCHEDULE.quietHours.startHour, QUIET_HOURS_START_HOUR);
  assert.equal(REMINDER_SCHEDULE.quietHours.endHour, QUIET_HOURS_END_HOUR);
  assert.equal(isQuietHour(new Date(`2026-12-01T${String(QUIET_HOURS_START_HOUR).padStart(2, "0")}:00:00+03:00`)), true);
  assert.equal(isQuietHour(new Date(`2026-12-01T${String(QUIET_HOURS_END_HOUR).padStart(2, "0")}:00:00+03:00`)), false);
  for (const type of Object.values(NotificationType)) {
    assert.equal(
      isQuietHoursExempt(type),
      (REMINDER_SCHEDULE.quietHours.alwaysThrough as readonly NotificationType[]).includes(type),
      type,
    );
  }
  const night = new Date("2026-12-01T23:30:00+03:00");
  const weddingIn = (days: number) => new Date(Date.UTC(2026, 11, 1 + days));
  const { daysBefore, through } = REMINDER_SCHEDULE.quietHours.weddingWeek;
  for (const rule of through) {
    const data =
      rule.type === NotificationType.PAYMENT_SCHEDULE_DUE_SOON
        ? { dueDate: "2026-12-01T00:00:00.000Z" }
        : { recipientAudience: "CUSTOMER", bookingEvent: rule.kinds[0], status: rule.kinds[0] };
    const context = (days: number) => ({ weddingPlanId: "plan-1", weddingDate: weddingIn(days), data });
    assert.equal(bypassesQuietHours(rule.type, night, context(daysBefore)), true, rule.type);
    assert.equal(bypassesQuietHours(rule.type, night, context(daysBefore + 1)), false, rule.type);
  }
  for (const type of REMINDER_SCHEDULE.quietHours.weddingDay.allPlanNoticesExcept) {
    assert.equal(
      bypassesQuietHours(type, night, { weddingPlanId: "plan-1", weddingDate: weddingIn(0), data: {} }),
      false,
      type,
    );
  }
  assert.equal(REMINDER_SCHEDULE.guestRepliesDigest.atMostEveryHours, 3);
});
