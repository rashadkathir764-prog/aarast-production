import { NotificationType } from "@prisma/client";
import { QUIET_HOURS_END_HOUR, QUIET_HOURS_START_HOUR } from "./quiet-hours";

/**
 * The one table of when the server reminds and when a push waits. The
 * reminder scan, the five-minute task scan, the booking reminders, the
 * promised-money reminders and the quiet-hours rule read their numbers from
 * here, and `GET /api/v1/notifications/schedule` returns it as it is, so the
 * phone's «متى يصلك» lines cannot say anything the server does not do
 * (`test/reminder-schedule.test.ts` holds the two together).
 *
 * Days are calendar days in Sana'a (UTC+3, no daylight saving: the business
 * day of `business-day.ts`). `daysBefore: 0` is the day itself.
 */
export const REMINDER_SCHEDULE = {
  version: 1,
  timeZone: "Asia/Aden",
  /**
   * The day reminders (a task's day, a payment, a loan, promised money, the
   * countdown) are made by the hourly scan at this minute, from the first
   * hour out of the quiet hours (09:05).
   */
  dayScan: { everyHourAtMinute: 5, firstHour: QUIET_HOURS_END_HOUR },
  tasks: {
    /** A week before, a day before and on the due day. */
    daysBefore: [7, 1, 0],
    /** A late task is told once for its due day. */
    overdue: "ONCE",
    /** The task's own «ذكّرني» time: checked every five minutes, still told up to a day late. */
    ownReminderTime: { checkEveryMinutes: 5, lateUpToHours: 24 },
  },
  payments: {
    /** Told once when it comes within this many days of its due day... */
    firstReminderDaysBefore: 7,
    /** ...or from its own reminder day, when it has one. */
    ownReminderDay: true,
    overdue: "ONCE",
  },
  loanRepayments: { firstReminderDaysBefore: 7, overdue: "ONCE" },
  /** Promised money (the mahr's rest, every «موعود» source): the day before and on the day. */
  promisedMoney: { daysBefore: [1, 0] },
  /** A confirmed booking: a week and a day before its day. */
  bookings: { daysBefore: [7, 1] },
  weddingCountdown: { daysBefore: [30, 7, 1, 0] },
  /** The guests' replies reach the phone as one digest at most this often per plan. */
  guestRepliesDigest: { atMostEveryHours: 3 },
  quietHours: {
    startHour: QUIET_HOURS_START_HOUR,
    endHour: QUIET_HOURS_END_HOUR,
    /** Someone is waiting on a reply now: these reach the phone at any hour. */
    alwaysThrough: [
      NotificationType.CHAT_MESSAGE_RECEIVED,
      NotificationType.BOOKING_REQUESTED,
    ],
    /**
     * From this many days before the wedding day up to the day itself,
     * these come through the night too: news that changes the wedding.
     */
    weddingWeek: {
      daysBefore: 7,
      through: [
        {
          type: NotificationType.BOOKING_UPDATED,
          kinds: [
            "DECLINED",
            "CANCELLED",
            "PROVIDER_SUSPENDED",
            "PROVIDER_CLOSED",
            "CHANGE_ACCEPTED",
            "CHANGE_DECLINED",
          ],
        },
        { type: NotificationType.QUOTE_REJECTED, kinds: ["REJECTED", "WITHDRAWN"] },
        { type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON, kinds: ["DUE_TODAY"] },
        { type: NotificationType.PAYMENT_SCHEDULE_OVERDUE, kinds: [] },
      ],
    },
    /** On the wedding day every notice of the plan comes through, except these. */
    weddingDay: { allPlanNoticesExcept: [NotificationType.GUEST_RESPONDED] },
  },
} as const satisfies ReminderSchedule;

export interface ReminderSchedule {
  version: number;
  timeZone: string;
  dayScan: { everyHourAtMinute: number; firstHour: number };
  tasks: {
    daysBefore: readonly number[];
    overdue: "ONCE";
    ownReminderTime: { checkEveryMinutes: number; lateUpToHours: number };
  };
  payments: { firstReminderDaysBefore: number; ownReminderDay: boolean; overdue: "ONCE" };
  loanRepayments: { firstReminderDaysBefore: number; overdue: "ONCE" };
  promisedMoney: { daysBefore: readonly number[] };
  bookings: { daysBefore: readonly number[] };
  weddingCountdown: { daysBefore: readonly number[] };
  guestRepliesDigest: { atMostEveryHours: number };
  quietHours: {
    startHour: number;
    endHour: number;
    alwaysThrough: readonly NotificationType[];
    weddingWeek: {
      daysBefore: number;
      /** `kinds` empty: every notice of the type. */
      through: ReadonlyArray<{ type: NotificationType; kinds: readonly string[] }>;
    };
    weddingDay: { allPlanNoticesExcept: readonly NotificationType[] };
  };
}

/** How far ahead the day scan reads: the farthest first reminder of a task, a payment or a loan. */
export const REMINDER_SCAN_WINDOW_DAYS = Math.max(
  ...REMINDER_SCHEDULE.tasks.daysBefore,
  REMINDER_SCHEDULE.payments.firstReminderDaysBefore,
  REMINDER_SCHEDULE.loanRepayments.firstReminderDaysBefore,
);
