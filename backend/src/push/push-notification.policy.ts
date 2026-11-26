import { NotificationType } from "@prisma/client";
import { startOfRiyadhDay } from "../shared-kernel/time/business-day";
import { isQuietHour, quietHoursEnd } from "../shared-kernel/time/quiet-hours";
import { REMINDER_SCHEDULE } from "../shared-kernel/time/reminder-schedule";
import { reminderWhenWords } from "../shared-kernel/voice/day-words";
import { PUSH_COPY, type PushCopy } from "../shared-kernel/copy/push.ar";

/**
 * RA-MO-360: the phone's notification channel of a push, the one place a
 * person can mute a kind of alert on their own: «رسائل», «مهام وتذكيرات»,
 * «المال» (the channels are made in the app's `AarastApplication`). Every
 * type that reaches a phone is listed here with its channel, so a new push
 * type cannot go out without one.
 */
export type PushAndroidChannelId =
  | "aarast_messages"
  | "aarast_tasks"
  | "aarast_money";

const MESSAGES: PushAndroidChannelId = "aarast_messages";
const TASKS: PushAndroidChannelId = "aarast_tasks";
const MONEY: PushAndroidChannelId = "aarast_money";

const PUSH_CHANNEL_BY_TYPE: ReadonlyMap<NotificationType, PushAndroidChannelId> =
  new Map<NotificationType, PushAndroidChannelId>([
    [NotificationType.TASK_ASSIGNED, TASKS],
    [NotificationType.TASK_DUE_SOON, TASKS],
    [NotificationType.TASK_OVERDUE, TASKS],
    [NotificationType.CHAT_MESSAGE_RECEIVED, MESSAGES],
    [NotificationType.WEDDING_COUNTDOWN, TASKS],
    // A price offer for the customer and every booking step for the other
    // side: each waits on a decision (V1 checklist 4.6).
    [NotificationType.QUOTE_OFFER_RECEIVED, MESSAGES],
    [NotificationType.BOOKING_UPDATED, MESSAGES],
    // B-19: a booking request has its own type; it waits on the provider.
    [NotificationType.BOOKING_REQUESTED, MESSAGES],
    // B-04: a request the provider has not answered ends tomorrow.
    [NotificationType.QUOTE_REQUEST_EXPIRING, MESSAGES],
    // RA-BE-187, RA-BE-188 (Q-40): the money reminders the app promises
    // («نذكّرك» on a payment date, a loan's repayments and promised money).
    [NotificationType.PAYMENT_SCHEDULE_DUE_SOON, MONEY],
    [NotificationType.PAYMENT_SCHEDULE_OVERDUE, MONEY],
    [NotificationType.LOAN_REPAYMENT_DUE_SOON, MONEY],
    [NotificationType.LOAN_REPAYMENT_OVERDUE, MONEY],
    [NotificationType.BUDGET_CATEGORY_EXCEEDED, MONEY],
    [NotificationType.FUNDING_EXPECTED, MONEY],
    // RA-BE-186 (Q-48 أ), Q-60 (أ, D127): every decision the team takes on
    // the provider's account, his claim of a listing and his photos waits on
    // him to act or to know. Back in review is his own act, and reviews stay
    // in the inbox.
    [NotificationType.PROVIDER_APPROVED, MESSAGES],
    [NotificationType.PROVIDER_REJECTED, MESSAGES],
    [NotificationType.PROVIDER_NEEDS_CHANGES, MESSAGES],
    [NotificationType.PROVIDER_SUSPENDED, MESSAGES],
    [NotificationType.PROVIDER_CLAIM_DECIDED, MESSAGES],
    [NotificationType.PORTFOLIO_REVIEWED, MESSAGES],
    // Q-50 (أ), D124: the reporter hears what came of his report; it waits
    // on no one, so it is held through the quiet hours.
    [NotificationType.CONVERSATION_REPORT_CLOSED, MESSAGES],
    // Both sides of a request hear its end: the provider that his offer was
    // not taken, the plan that a provider declined, withdrew his offer or
    // let the request run out. Each changes what the plan does next.
    [NotificationType.QUOTE_REJECTED, MESSAGES],
    // An invitation to a plan waits on its invitee; the inviter hears it
    // was taken; a provider hears of a new review on his page.
    [NotificationType.SHARING_INVITATION, MESSAGES],
    [NotificationType.SHARING_INVITE_ACCEPTED, MESSAGES],
    [NotificationType.REVIEW_RECEIVED, MESSAGES],
    // The guests' replies, as one digest at most every few hours
    // (`REMINDER_SCHEDULE.guestRepliesDigest`); never through the night.
    [NotificationType.GUEST_RESPONDED, TASKS],
  ]);

/**
 * RA-BE-186: these types are written for both sides of a request, and only
 * the provider's side pushes. The customer's own request received and offer
 * accepted stay in the inbox: the customer did them.
 */
const PROVIDER_AUDIENCE_PUSH_CHANNEL_BY_TYPE: ReadonlyMap<
  NotificationType,
  PushAndroidChannelId
> = new Map<NotificationType, PushAndroidChannelId>([
  [NotificationType.QUOTE_REQUEST_SUBMITTED, MESSAGES],
  [NotificationType.QUOTE_ACCEPTED, MESSAGES],
]);

function isProviderAudience(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  return (data as Record<string, unknown>).recipientAudience === "PROVIDER";
}

/**
 * Whether a notification of this type reaches the phone. `data` is the
 * notification's own data, read only for the types written for both a
 * customer and a provider.
 */
export function isPushNotificationType(
  type: NotificationType,
  data?: unknown,
): boolean {
  if (PROVIDER_AUDIENCE_PUSH_CHANNEL_BY_TYPE.has(type)) {
    return isProviderAudience(data);
  }
  return PUSH_CHANNEL_BY_TYPE.has(type);
}

/**
 * The plan right a push of [type] still needs when it goes out (a held or
 * retried push may leave hours after its notice was written, and a member
 * may have lost the right meanwhile): `MONEY` money visibility, `TASKS` the
 * task right, `PROVIDERS` the provider right, `MEMBER` only a place in the
 * plan, `NONE` nothing of the plan (a notice of no plan, the provider's own
 * business, an invitation to someone not in it yet, a conversation, which
 * messaging guards itself).
 */
export type PushPlanRight = "NONE" | "MEMBER" | "MONEY" | "TASKS" | "PROVIDERS";

const MONEY_PUSH_TYPES = new Set<NotificationType>([
  NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
  NotificationType.PAYMENT_SCHEDULE_OVERDUE,
  NotificationType.LOAN_REPAYMENT_DUE_SOON,
  NotificationType.LOAN_REPAYMENT_OVERDUE,
  NotificationType.BUDGET_CATEGORY_EXCEEDED,
  NotificationType.FUNDING_EXPECTED,
]);
const TASK_PUSH_TYPES = new Set<NotificationType>([
  NotificationType.TASK_ASSIGNED,
  NotificationType.TASK_DUE_SOON,
  NotificationType.TASK_OVERDUE,
]);
const PROVIDER_PUSH_TYPES = new Set<NotificationType>([
  NotificationType.QUOTE_OFFER_RECEIVED,
  NotificationType.QUOTE_REJECTED,
  NotificationType.BOOKING_UPDATED,
]);

export function pushPlanRight(
  notification: { type: NotificationType; weddingPlanId: string | null; data?: unknown },
): PushPlanRight {
  const { type, weddingPlanId, data } = notification;
  if (!weddingPlanId || isProviderAudience(data)) return "NONE";
  if (
    type === NotificationType.SHARING_INVITATION ||
    type === NotificationType.CHAT_MESSAGE_RECEIVED
  ) {
    return "NONE";
  }
  if (MONEY_PUSH_TYPES.has(type)) return "MONEY";
  if (TASK_PUSH_TYPES.has(type)) return "TASKS";
  if (PROVIDER_PUSH_TYPES.has(type)) return "PROVIDERS";
  return "MEMBER";
}

/** The channel a push of [type] goes to on an Android phone. */
export function pushAndroidChannelId(type: NotificationType): PushAndroidChannelId {
  const channel =
    PUSH_CHANNEL_BY_TYPE.get(type) ??
    PROVIDER_AUDIENCE_PUSH_CHANNEL_BY_TYPE.get(type);
  if (channel === undefined) {
    throw new Error(`${type} is not a push type, so it has no phone channel`);
  }
  return channel;
}

/**
 * RA-BE-185: a chat message and a booking request wait on a person who is
 * writing now, so they reach the phone at any hour; every other push is held
 * through quiet hours (OTP is no notification and never comes through here).
 */
const QUIET_HOURS_EXEMPT_TYPES = new Set<NotificationType>(
  REMINDER_SCHEDULE.quietHours.alwaysThrough,
);

/** Whether [type] reaches the phone at any hour, whatever its plan's date. */
export function isQuietHoursExempt(type: NotificationType): boolean {
  return QUIET_HOURS_EXEMPT_TYPES.has(type);
}

/** What a quiet-hours decision reads of the notice beyond its type. */
export interface QuietHoursContext {
  /** The plan the notice is about; a notice of no plan has no wedding week. */
  weddingPlanId?: string | null;
  /** That plan's wedding day, when it has one. */
  weddingDate?: Date | null;
  /** The notice's own data (its booking step, its request's end, its due day). */
  data?: unknown;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Whole Sana'a days from `at`'s day to the wedding day, by the countdown's
 * own count (`daysUntilWedding` in `plan-reminders.ts`): 0 on the day,
 * negative once it passed.
 */
function daysToWedding(weddingDate: Date, at: Date): number {
  return Math.round(
    (startOfRiyadhDay(weddingDate).getTime() - startOfRiyadhDay(at).getTime()) /
      DAY_MS,
  );
}

/**
 * The kind a wedding-week rule matches (`REMINDER_SCHEDULE.quietHours
 * .weddingWeek.through[].kinds`): a booking's step, how a request ended for
 * the plan, a payment due today. Null when the notice has none.
 */
function quietHoursKind(type: NotificationType, data: unknown, at: Date): string | null {
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  const fields = data as Record<string, unknown>;
  switch (type) {
    case NotificationType.BOOKING_UPDATED:
      return fields.recipientAudience === "CUSTOMER" &&
        typeof fields.bookingEvent === "string"
        ? fields.bookingEvent
        : null;
    case NotificationType.QUOTE_REJECTED:
      return fields.recipientAudience === "CUSTOMER" &&
        typeof fields.status === "string"
        ? fields.status
        : null;
    case NotificationType.PAYMENT_SCHEDULE_DUE_SOON: {
      if (typeof fields.dueDate !== "string") return null;
      const due = new Date(fields.dueDate);
      if (Number.isNaN(due.getTime())) return null;
      return startOfRiyadhDay(due).getTime() === startOfRiyadhDay(at).getTime()
        ? "DUE_TODAY"
        : null;
    }
    default:
      return null;
  }
}

/**
 * The one quiet-hours rule (RA-BE-185, and the wedding week). From 21:00 to
 * 09:00 in Aden a push waits for the morning, except:
 *
 * - a chat message and a booking request, at any time: someone is writing
 *   now (`alwaysThrough`);
 * - in the 7 days before the plan's wedding day and on the day (Sana'a
 *   calendar days, as the reminders count them), news that changes the
 *   wedding: a booking declined, cancelled, its provider suspended or gone,
 *   its day change decided; a provider who declined the request or
 *   withdrew his offer; a payment due today or overdue (`weddingWeek`);
 * - on the wedding day itself, every notice of the plan except the guests'
 *   replies digest (`weddingDay`).
 *
 * Everything else, and every notice of no plan or of a plan with no date, is
 * held. Eight days before is held; the day after is held. The guests'
 * replies are never let through the night.
 */
export function bypassesQuietHours(
  type: NotificationType,
  at: Date,
  context: QuietHoursContext = {},
): boolean {
  if (isQuietHoursExempt(type)) return true;
  const rules = REMINDER_SCHEDULE.quietHours;
  if (!context.weddingPlanId || !context.weddingDate) return false;
  const days = daysToWedding(context.weddingDate, at);
  if (days < 0 || days > rules.weddingWeek.daysBefore) return false;
  if (
    days === 0 &&
    !(rules.weddingDay.allPlanNoticesExcept as readonly NotificationType[]).includes(type)
  ) {
    return true;
  }
  const rule = rules.weddingWeek.through.find((entry) => entry.type === type);
  if (!rule) return false;
  const kinds = rule.kinds as readonly string[];
  if (kinds.length === 0) return true;
  const kind = quietHoursKind(type, context.data, at);
  return kind !== null && kinds.includes(kind);
}

/** The instant a push made at `at` may go out, or null when it goes out now. */
export function pushNotBefore(
  type: NotificationType,
  at: Date,
  context: QuietHoursContext = {},
): Date | null {
  if (!isQuietHour(at) || bypassesQuietHours(type, at, context)) return null;
  return quietHoursEnd(at);
}

/**
 * A QUOTE_OFFER_RECEIVED notice about a new version (B-06) carries the
 * version number from 2 up; the first offer carries none.
 */
function isRevisedOfferNotice(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  const versionNo = (data as Record<string, unknown>).versionNo;
  return typeof versionNo === "number" && versionNo > 1;
}

/** A WEDDING_COUNTDOWN notice for the wedding day itself (`daysUntil` 0). */
function isWeddingDayNotice(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  return (data as Record<string, unknown>).daysUntil === 0;
}

/** The distance a task reminder carries (`daysUntil`, 0 or more), or null. */
function taskDueDays(data: unknown): number | null {
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  const days = (data as Record<string, unknown>).daysUntil;
  return typeof days === "number" && Number.isInteger(days) && days >= 0
    ? days
    : null;
}

/**
 * A team decision that refused (a claim's `claimStatus`, a photo's
 * `decision`); anything else reads as accepted.
 */
function isRefusalNotice(data: unknown, field: "claimStatus" | "decision"): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  return (data as Record<string, unknown>)[field] === "REJECTED";
}

/** How a request ended, as its notice's data says (`REJECTED`, `WITHDRAWN`, `EXPIRED`). */
function noticeStatus(data: unknown): string | null {
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  const status = (data as Record<string, unknown>).status;
  return typeof status === "string" ? status : null;
}

/** A FUNDING_EXPECTED notice for the expected day itself, not the day before. */
function isExpectedTodayNotice(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  return (data as Record<string, unknown>).reminder === "ON_THE_DAY";
}

/**
 * The words on the lock screen: generic, never a name or an amount. `data`
 * is the notification's own data, read only to tell a revised offer from a
 * new one. A customer's lock screen may be the groom's or the bride's, so
 * these lines tell without an imperative in either gender (B5); the
 * provider's line keeps the provider's voice.
 */
export function pushNotificationCopy(
  type: NotificationType,
  data?: unknown,
): PushCopy {
  switch (type) {
    case NotificationType.TASK_ASSIGNED:
      return PUSH_COPY.taskAssigned;
    // RA-BE-189: the phone says the real distance («اليوم», «غدًا», «بعد
    // أسبوع»); a «ذكّرني» time carries none and says only that it is near.
    case NotificationType.TASK_DUE_SOON: {
      const days = taskDueDays(data);
      return PUSH_COPY.taskDueSoon(
        days === null ? null : reminderWhenWords(days),
      );
    }
    // RA-BE-99: a task whose day passed is late, not coming.
    case NotificationType.TASK_OVERDUE:
      return PUSH_COPY.taskOverdue;
    case NotificationType.CHAT_MESSAGE_RECEIVED:
      return PUSH_COPY.chatMessage;
    // RA-BE-99: on the day itself the lock screen does not say it is near.
    case NotificationType.WEDDING_COUNTDOWN:
      return isWeddingDayNotice(data) ? PUSH_COPY.weddingDay : PUSH_COPY.weddingNear;
    case NotificationType.QUOTE_OFFER_RECEIVED:
      return isRevisedOfferNotice(data) ? PUSH_COPY.offerRevised : PUSH_COPY.offerReceived;
    case NotificationType.QUOTE_REQUEST_EXPIRING:
      return PUSH_COPY.requestExpiringForProvider;
    case NotificationType.BOOKING_REQUESTED:
      return PUSH_COPY.bookingRequested;
    // RA-BE-187: a money reminder tells there is one, never which or how much.
    case NotificationType.PAYMENT_SCHEDULE_DUE_SOON:
      return PUSH_COPY.paymentDueSoon;
    case NotificationType.PAYMENT_SCHEDULE_OVERDUE:
      return PUSH_COPY.paymentOverdue;
    case NotificationType.LOAN_REPAYMENT_DUE_SOON:
      return PUSH_COPY.loanDueSoon;
    case NotificationType.LOAN_REPAYMENT_OVERDUE:
      return PUSH_COPY.loanOverdue;
    case NotificationType.BUDGET_CATEGORY_EXCEEDED:
      return PUSH_COPY.budgetItemExceeded;
    // RA-BE-188: promised money, the day before and on the day.
    case NotificationType.FUNDING_EXPECTED:
      return isExpectedTodayNotice(data) ? PUSH_COPY.promisedToday : PUSH_COPY.promisedTomorrow;
    case NotificationType.BOOKING_UPDATED:
      return PUSH_COPY.bookingUpdated;
    // RA-BE-186: the provider's own notices, with no customer's name or
    // price on the lock screen.
    case NotificationType.QUOTE_REQUEST_SUBMITTED:
      return PUSH_COPY.requestForProvider;
    case NotificationType.QUOTE_ACCEPTED:
      return PUSH_COPY.offerAcceptedForProvider;
    // The plan's side of a request's end: which provider stays in the app.
    case NotificationType.QUOTE_REJECTED:
      if (!isProviderAudience(data)) {
        switch (noticeStatus(data)) {
          case "WITHDRAWN":
            return PUSH_COPY.offerWithdrawn;
          case "EXPIRED":
            return PUSH_COPY.requestExpired;
          default:
            return PUSH_COPY.requestDeclined;
        }
      }
      return PUSH_COPY.offerDeclinedForProvider;
    case NotificationType.SHARING_INVITATION:
      return PUSH_COPY.planInvitation;
    case NotificationType.SHARING_INVITE_ACCEPTED:
      return PUSH_COPY.invitationAccepted;
    case NotificationType.REVIEW_RECEIVED:
      return PUSH_COPY.reviewReceived;
    // How many replied stays in the app; the lock screen says only that
    // some did.
    case NotificationType.GUEST_RESPONDED:
      return PUSH_COPY.guestReplies;
    case NotificationType.PROVIDER_APPROVED:
      return PUSH_COPY.providerApproved;
    case NotificationType.PROVIDER_REJECTED:
      return PUSH_COPY.providerRejected;
    // Q-60: the team's note and reason stay in the app.
    case NotificationType.PROVIDER_NEEDS_CHANGES:
      return PUSH_COPY.providerNeedsChanges;
    case NotificationType.PROVIDER_SUSPENDED:
      return PUSH_COPY.providerSuspended;
    case NotificationType.PROVIDER_CLAIM_DECIDED:
      return isRefusalNotice(data, "claimStatus") ? PUSH_COPY.claimRefused : PUSH_COPY.claimAccepted;
    case NotificationType.PORTFOLIO_REVIEWED:
      return isRefusalNotice(data, "decision")
        ? PUSH_COPY.portfolioPhotoRefused
        : PUSH_COPY.portfolioPhotoAccepted;
    // Q-50: the team's reason stays in the app.
    case NotificationType.CONVERSATION_REPORT_CLOSED:
      return PUSH_COPY.reportClosed;
    default:
      throw new Error("UnsupportedPushNotificationType");
  }
}
