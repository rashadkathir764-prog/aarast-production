import { NotificationPriority, NotificationType } from "@prisma/client";
import {
  type DueLoanRepayment,
  type DuePaymentSchedule,
  type ExceededBudgetCategory,
  riyadhDay,
} from "../modules/finance/public/finance.port";
import type { DueNotificationRow } from "../modules/notifications/infrastructure/notifications.repository";
import { startOfRiyadhDay } from "../shared-kernel/time/business-day";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import {
  type AddressedText,
  type AddressForm,
  textFor,
} from "../shared-kernel/voice/address-form";
import {
  dayCountWords,
  daysBetween,
  weekdayDayMonthWords,
  whenWords,
} from "../shared-kernel/voice/day-words";

// The hourly reminder scan's reminders (V1 checklist 4.8, 4.17): a task or a
// payment coming due, a budget item over its allocation, a loan repayment
// coming due, and the wedding countdown. Each row's dedupe key makes the
// scan idempotent.
//
// B-38: the words are the app's: a day reads «الجمعة 30 أكتوبر», a distance
// «بكرة» or «بعد 5 أيام», and no notice text carries an amount. A money
// reminder carries its amount in `data` (`amount`, `currency`) for a reader
// with money rights; the phone writes it the app's one way and leaves it
// out under «أخفِ المبالغ» (a setting that lives on the phone only).
//
// D55: every reminder is written in its reader's form; a row's words may
// come in two forms and `addressDueNotice` picks the reader's, the same
// `textFor` every single notice goes through.

const DAY_MS = 24 * 60 * 60 * 1000;

/** A reminder before it is written for its reader: its words may have two forms. */
export type DueNotice = Omit<DueNotificationRow, "title" | "body"> & {
  title: AddressedText;
  body: AddressedText;
};

/** The reminder in its reader's form, ready to write. */
export function addressDueNotice(
  notice: DueNotice,
  form: AddressForm,
): DueNotificationRow {
  return {
    ...notice,
    title: textFor(form, notice.title),
    body: textFor(form, notice.body),
  };
}

/** The countdown reminds once inside each window: a month, a week, a day. */
export const WEDDING_COUNTDOWN_MILESTONES = [30, 7, 1] as const;

/** A task due within the window or overdue, for one reader. */
export function taskDueNotice(
  userId: string,
  task: { id: string; weddingPlanId: string; title: string; dueDate: Date },
  today: Date,
): DueNotice {
  const content = taskDueContent(task, today);
  return {
    ...content,
    userId,
    dedupeKey: `${userId}:${taskDueKey(content.type, task.id)}`,
  };
}

/**
 * G36: the task's own «ذكّرني» time came. Once per reader and reminder time:
 * moving the time reminds again at the new time.
 */
export function taskReminderNotice(
  userId: string,
  task: { id: string; weddingPlanId: string; title: string; reminderAt: Date },
): DueNotice {
  return {
    userId,
    weddingPlanId: task.weddingPlanId,
    type: NotificationType.TASK_DUE_SOON,
    priority: NotificationPriority.NORMAL,
    title: "تذكير بمهمة",
    body: task.title,
    data: {
      taskId: task.id,
      weddingPlanId: task.weddingPlanId,
      reminderAt: task.reminderAt.toISOString(),
    },
    entityType: "task",
    entityId: task.id,
    routeTarget: noticeRoutes.task(task.weddingPlanId, task.id),
    dedupeKey: `${userId}:TASK_REMINDER:task:${task.id}:${task.reminderAt.toISOString()}`,
  };
}

/** The reader-free part of a task's reminder key (each reader's key adds the reader). */
export function taskDueKey(type: NotificationType, taskId: string): string {
  return `${type}:task:${taskId}`;
}

/** What a task's reminder says and opens, whoever reads it. */
export function taskDueContent(
  task: { id: string; weddingPlanId: string; title: string; dueDate: Date },
  today: Date,
): Omit<DueNotice, "userId" | "dedupeKey"> {
  const days = daysBetween(today, task.dueDate);
  const overdue = days < 0;
  const type = overdue
    ? NotificationType.TASK_OVERDUE
    : NotificationType.TASK_DUE_SOON;
  const day = weekdayDayMonthWords(task.dueDate);
  return {
    weddingPlanId: task.weddingPlanId,
    type,
    priority: overdue ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title: overdue ? "مهمة متأخرة" : `مهمة ${whenWords(days)}`,
    body: overdue
      ? `${task.title} · كان موعدها ${day}`
      : `${task.title} · ${day}`,
    data: {
      taskId: task.id,
      weddingPlanId: task.weddingPlanId,
      dueDate: task.dueDate.toISOString(),
    },
    entityType: "task",
    entityId: task.id,
    routeTarget: noticeRoutes.task(task.weddingPlanId, task.id),
  };
}

/**
 * D106: whether a pending date is reminded today. A late date is (and when
 * late). A date with a reminder day of its own is reminded from that day,
 * not before; without one, in the week before its due day (the scan's
 * window). The due day itself never moves for a reminder.
 */
export function paymentReminderDue(
  schedule: { dueDate: Date; remindAt: Date | null },
  today: Date,
): boolean {
  if (schedule.dueDate < today) return true;
  if (schedule.remindAt) return riyadhDay(schedule.remindAt) <= riyadhDay(today);
  return true;
}

/**
 * A payment date coming due or overdue. The owner reads which agreement and
 * its amount (in `data`); another member with money rights reads only that
 * a payment is due (V1 checklist 4.10: no name or amount of a cost that is
 * not theirs to see whole).
 */
export function paymentDueNotice(
  userId: string,
  schedule: DuePaymentSchedule,
  plan: { id: string; currency: string },
  today: Date,
  owner: { partyName: string | null } | null,
): DueNotice {
  const days = daysBetween(today, schedule.dueDate);
  const overdue = days < 0;
  const type = overdue
    ? NotificationType.PAYMENT_SCHEDULE_OVERDUE
    : NotificationType.PAYMENT_SCHEDULE_DUE_SOON;
  const day = weekdayDayMonthWords(schedule.dueDate);
  const title = owner
    ? overdue
      ? `دفعة ${schedule.weddingCost.title} متأخرة`
      : `دفعة ${schedule.weddingCost.title} ${whenWords(days)}`
    : overdue
      ? "موعد دفع متأخر"
      : `موعد دفع ${whenWords(days)}`;
  const when = overdue ? `كان موعدها ${day}` : day;
  return {
    userId,
    weddingPlanId: plan.id,
    type,
    priority: overdue ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title,
    body: owner ? when : `${when} · التفاصيل في المال`,
    data: {
      paymentScheduleId: schedule.id,
      weddingCostId: schedule.weddingCostId,
      weddingPlanId: plan.id,
      dueDate: schedule.dueDate.toISOString(),
      ...(owner
        ? {
            amount: schedule.amount.toString(),
            currency: plan.currency,
            ...(owner.partyName ? { partyName: owner.partyName } : {}),
          }
        : {}),
    },
    entityType: "payment_schedule",
    entityId: schedule.id,
    routeTarget: noticeRoutes.cost(plan.id, schedule.weddingCostId),
    // D106: a moved due day is a new agreement and is reminded again, as is
    // a reminder day chosen again; a date never moved keeps its first key.
    dedupeKey:
      `${userId}:${type}:payment-schedule:${schedule.id}` +
      (schedule.rescheduledFrom ? `:due:${riyadhDay(schedule.dueDate)}` : "") +
      (!overdue && schedule.remindAt ? `:remind:${riyadhDay(schedule.remindAt)}` : ""),
  };
}

/**
 * An over-budget item, for the plan owner only: a contributor's money view
 * covers just the items they created, so a plan-wide alert would tell them
 * more than their summary does. The key carries the allocation, so raising
 * it and overspending again alerts again. `amount` is by how much it is over.
 */
export function budgetCategoryExceededRow(
  ownerUserId: string,
  category: ExceededBudgetCategory,
  currency: string,
): DueNotice {
  // D105: by what it is expected to cost, not its agreements alone.
  const over = category.expectedAmount.minus(category.allocatedAmount);
  return {
    userId: ownerUserId,
    weddingPlanId: category.weddingPlanId,
    type: NotificationType.BUDGET_CATEGORY_EXCEEDED,
    priority: NotificationPriority.HIGH,
    title: `بند ${category.name} فات المخطط له`,
    body: category.committedAmount.gt(category.allocatedAmount)
      ? "اتفاقاته صارت أكثر من المخطط."
      : "تكلفته المتوقعة صارت أكثر من المخصص له.",
    data: {
      budgetCategoryId: category.id,
      weddingPlanId: category.weddingPlanId,
      amount: over.toString(),
      currency,
      allocatedAmount: category.allocatedAmount.toString(),
      committedAmount: category.committedAmount.toString(),
      expectedAmount: category.expectedAmount.toString(),
    },
    entityType: "budget_category",
    entityId: category.id,
    routeTarget: noticeRoutes.budgetItem(category.weddingPlanId, category.id),
    dedupeKey: `${ownerUserId}:${NotificationType.BUDGET_CATEGORY_EXCEEDED}:budget-category:${category.id}:${category.allocatedAmount.toFixed()}`,
  };
}

/** A loan repayment due within the window or overdue; loans are the owner's private money. */
export function loanRepaymentRow(
  ownerUserId: string,
  repayment: DueLoanRepayment,
  today: Date,
  currency: string,
): DueNotice {
  const days = daysBetween(today, repayment.dueDate);
  const overdue = days < 0;
  const type = overdue
    ? NotificationType.LOAN_REPAYMENT_OVERDUE
    : NotificationType.LOAN_REPAYMENT_DUE_SOON;
  const day = weekdayDayMonthWords(repayment.dueDate);
  return {
    userId: ownerUserId,
    weddingPlanId: repayment.weddingPlanId,
    type,
    priority: overdue ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title: overdue
      ? `سداد ${repayment.sourceName} متأخر`
      : `سداد ${repayment.sourceName} ${whenWords(days)}`,
    body: overdue ? `كان موعده ${day}` : day,
    data: {
      loanRepaymentId: repayment.id,
      weddingPlanId: repayment.weddingPlanId,
      dueDate: repayment.dueDate.toISOString(),
      amount: repayment.amount.toString(),
      currency,
    },
    entityType: "loan_repayment",
    entityId: repayment.id,
    routeTarget: noticeRoutes.funding(repayment.weddingPlanId),
    dedupeKey: `${ownerUserId}:${type}:loan-repayment:${repayment.id}`,
  };
}

/** Whole Riyadh days from today to the wedding day (negative once it passed). */
export function daysUntilWedding(weddingDate: Date, today: Date): number {
  return Math.round(
    (startOfRiyadhDay(weddingDate).getTime() - today.getTime()) / DAY_MS,
  );
}

/** The countdown window the plan is in, or null outside every window. */
export function weddingCountdownMilestone(daysUntil: number): number | null {
  if (daysUntil < 0) return null;
  for (const milestone of [...WEDDING_COUNTDOWN_MILESTONES].reverse()) {
    if (daysUntil <= milestone) return milestone;
  }
  return null;
}

/** The countdown reminder for one recipient, or null when none is due. */
export function weddingCountdownRow(
  userId: string,
  plan: { id: string; weddingDate: Date | null },
  today: Date,
): DueNotice | null {
  if (!plan.weddingDate) return null;
  const daysUntil = daysUntilWedding(plan.weddingDate, today);
  const milestone = weddingCountdownMilestone(daysUntil);
  if (milestone === null) return null;
  return {
    userId,
    weddingPlanId: plan.id,
    type: NotificationType.WEDDING_COUNTDOWN,
    priority: daysUntil <= 1 ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title: countdownTitle(daysUntil),
    body: countdownBody(daysUntil, plan.weddingDate),
    data: {
      weddingPlanId: plan.id,
      daysUntil,
      weddingDate: plan.weddingDate.toISOString(),
    },
    entityType: "wedding_plan",
    entityId: plan.id,
    routeTarget: noticeRoutes.planHome(plan.id),
    // A new wedding date (postponed) starts the countdown again.
    dedupeKey: `${userId}:${NotificationType.WEDDING_COUNTDOWN}:plan:${plan.id}:${milestone}:${plan.weddingDate.toISOString().slice(0, 10)}`,
  };
}

function countdownTitle(daysUntil: number): string {
  if (daysUntil === 0) return "اليوم يوم العرس";
  if (daysUntil === 1) return "العرس بكرة";
  return `باقي ${dayCountWords(daysUntil)} على العرس`;
}

function countdownBody(daysUntil: number, weddingDate: Date): AddressedText {
  if (daysUntil === 0) return "ألف مبروك!";
  return `يوم ${weekdayDayMonthWords(weddingDate)}. اللي باقي قبله في الخطة.`;
}
