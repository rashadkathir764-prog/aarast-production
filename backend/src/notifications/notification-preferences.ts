import { NotificationType, Prisma } from "@prisma/client";

/**
 * Which of the account's alert switches governs a notice: off, the notice
 * is not written at all (neither the inbox nor the phone). Null: no switch
 * governs it, it always comes (an invitation, the guests' replies digest,
 * the team's decisions on a provider).
 *
 * The one rule: the notifications service reads it before writing a
 * notice, and `GET /api/v1/notifications/schedule` returns its coverage
 * (`preferenceCoverage`), so the settings page says what each switch
 * silences from the rule itself.
 */
export type NotificationPreferenceKey =
  | "taskRemindersEnabled"
  | "paymentRemindersEnabled"
  | "providerMessagesEnabled"
  | "bookingRemindersEnabled";

export function notificationPreferenceKey(
  type: NotificationType,
  data?: Prisma.InputJsonValue,
): NotificationPreferenceKey | null {
  switch (type) {
    case NotificationType.TASK_DUE_SOON:
    case NotificationType.TASK_OVERDUE:
    case NotificationType.TASK_ASSIGNED:
    case NotificationType.WEDDING_COUNTDOWN:
      return "taskRemindersEnabled";
    case NotificationType.PAYMENT_SCHEDULE_DUE_SOON:
    case NotificationType.PAYMENT_SCHEDULE_OVERDUE:
    case NotificationType.BUDGET_CATEGORY_EXCEEDED:
    case NotificationType.LOAN_REPAYMENT_DUE_SOON:
    case NotificationType.LOAN_REPAYMENT_OVERDUE:
    case NotificationType.FUNDING_EXPECTED:
      return "paymentRemindersEnabled";
    case NotificationType.QUOTE_REQUEST_SUBMITTED:
    case NotificationType.QUOTE_REQUEST_EXPIRING:
    case NotificationType.QUOTE_OFFER_RECEIVED:
    case NotificationType.QUOTE_ACCEPTED:
    case NotificationType.QUOTE_REJECTED:
    case NotificationType.CHAT_MESSAGE_RECEIVED:
    case NotificationType.BOOKING_REQUESTED:
    case NotificationType.REVIEW_RECEIVED:
    case NotificationType.REVIEW_REPLIED:
    // Q-50 (أ): what came of a report on a conversation is the messages'.
    case NotificationType.CONVERSATION_REPORT_CLOSED:
      return "providerMessagesEnabled";
    // RA-BE-190: a customer's booking reminders are the «الحجوزات» switch;
    // every other booking notice, and the provider's own reminders (his one
    // switch says «الحجوزات» too), stay with the offers and chats.
    case NotificationType.BOOKING_UPDATED:
      return isCustomerBookingReminder(data)
        ? "bookingRemindersEnabled"
        : "providerMessagesEnabled";
    default:
      return null;
  }
}

/** A booking notice that is the customer's reminder of the booking's day. */
export function isCustomerBookingReminder(data: Prisma.InputJsonValue | undefined): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  const fields = data as Record<string, unknown>;
  return fields.reminder === true && fields.recipientAudience === "CUSTOMER";
}

/** «BOOKING_UPDATED» split by what the switch reads: its reminders, or its other news. */
export type PreferenceCoverageItem = NotificationType | "BOOKING_REMINDER" | "BOOKING_NEWS";

/**
 * Every notice type under the switch that governs it, and the ones no
 * switch governs, in the enum's order: what the settings page may say
 * each switch silences.
 */
export function preferenceCoverage(): {
  switches: Record<NotificationPreferenceKey, PreferenceCoverageItem[]>;
  always: PreferenceCoverageItem[];
} {
  const switches: Record<NotificationPreferenceKey, PreferenceCoverageItem[]> = {
    taskRemindersEnabled: [],
    paymentRemindersEnabled: [],
    providerMessagesEnabled: [],
    bookingRemindersEnabled: [],
  };
  const always: PreferenceCoverageItem[] = [];
  for (const type of Object.values(NotificationType)) {
    if (type === NotificationType.BOOKING_UPDATED) {
      const reminder = { reminder: true, recipientAudience: "CUSTOMER" };
      switches[notificationPreferenceKey(type, reminder)!].push("BOOKING_REMINDER");
      switches[notificationPreferenceKey(type)!].push("BOOKING_NEWS");
      continue;
    }
    const key = notificationPreferenceKey(type);
    if (key) switches[key].push(type);
    else always.push(type);
  }
  return { switches, always };
}
