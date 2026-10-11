import { NotificationPriority, NotificationType } from "@prisma/client";
import type {
  DueLoanRepayment,
  ExceededBudgetCategory,
} from "../modules/finance/public/finance.port";
import type { DueNotificationRow } from "../modules/notifications/infrastructure/notifications.repository";
import { startOfRiyadhDay } from "../shared-kernel/time/business-day";

// The hourly reminder scan's plan-level reminders (V1 checklist 4.8, 4.17):
// a budget category over its allocation, a loan repayment coming due, and
// the wedding countdown. Each row's dedupe key makes the scan idempotent.

const DAY_MS = 24 * 60 * 60 * 1000;

/** The countdown reminds once inside each window: a month, a week, a day. */
export const WEDDING_COUNTDOWN_MILESTONES = [30, 7, 1] as const;

export function formatReminderDate(date: Date): string {
  return `${date.getUTCDate()}/${date.getUTCMonth() + 1}/${date.getUTCFullYear()}`;
}

/**
 * An over-budget category, for the plan owner only: a contributor's money
 * view covers just the categories they created, so a plan-wide alert would
 * tell them more than their summary does. The key carries the allocation, so
 * raising it and overspending again alerts again.
 */
export function budgetCategoryExceededRow(
  ownerUserId: string,
  category: ExceededBudgetCategory,
): DueNotificationRow {
  const over = category.committedAmount.minus(category.allocatedAmount);
  return {
    userId: ownerUserId,
    weddingPlanId: category.weddingPlanId,
    type: NotificationType.BUDGET_CATEGORY_EXCEEDED,
    priority: NotificationPriority.HIGH,
    title: "تجاوز بند في الميزانية",
    body: `بند ${category.name} تجاوز المخطط (${category.allocatedAmount.toString()}) بمبلغ ${over.toString()}.`,
    data: {
      budgetCategoryId: category.id,
      weddingPlanId: category.weddingPlanId,
      allocatedAmount: category.allocatedAmount.toString(),
      committedAmount: category.committedAmount.toString(),
    },
    entityType: "budget_category",
    entityId: category.id,
    routeTarget: `/wedding-plans/${category.weddingPlanId}/money`,
    dedupeKey: `${ownerUserId}:${NotificationType.BUDGET_CATEGORY_EXCEEDED}:budget-category:${category.id}:${category.allocatedAmount.toFixed()}`,
  };
}

/** A loan repayment due within the window or overdue; loans are the owner's private money. */
export function loanRepaymentRow(
  ownerUserId: string,
  repayment: DueLoanRepayment,
  today: Date,
): DueNotificationRow {
  const overdue = repayment.dueDate < today;
  const type = overdue
    ? NotificationType.LOAN_REPAYMENT_OVERDUE
    : NotificationType.LOAN_REPAYMENT_DUE_SOON;
  return {
    userId: ownerUserId,
    weddingPlanId: repayment.weddingPlanId,
    type,
    priority: overdue ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title: overdue ? "موعد سداد متأخر" : "موعد سداد قريب",
    body: `سداد ${repayment.sourceName} بقيمة ${repayment.amount.toString()} ${overdue ? "متأخر" : "يستحق قريباً"} (${formatReminderDate(repayment.dueDate)}).`,
    data: {
      loanRepaymentId: repayment.id,
      weddingPlanId: repayment.weddingPlanId,
      dueDate: repayment.dueDate.toISOString(),
    },
    entityType: "loan_repayment",
    entityId: repayment.id,
    routeTarget: `/wedding-plans/${repayment.weddingPlanId}/money/funding`,
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
): DueNotificationRow | null {
  if (!plan.weddingDate) return null;
  const daysUntil = daysUntilWedding(plan.weddingDate, today);
  const milestone = weddingCountdownMilestone(daysUntil);
  if (milestone === null) return null;
  return {
    userId,
    weddingPlanId: plan.id,
    type: NotificationType.WEDDING_COUNTDOWN,
    priority: daysUntil <= 1 ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
    title: "العد التنازلي للعرس",
    body: countdownBody(daysUntil),
    data: {
      weddingPlanId: plan.id,
      daysUntil,
      weddingDate: plan.weddingDate.toISOString(),
    },
    entityType: "wedding_plan",
    entityId: plan.id,
    routeTarget: `/wedding-plans/${plan.id}/dashboard`,
    // A new wedding date (postponed) starts the countdown again.
    dedupeKey: `${userId}:${NotificationType.WEDDING_COUNTDOWN}:plan:${plan.id}:${milestone}:${plan.weddingDate.toISOString().slice(0, 10)}`,
  };
}

function countdownBody(daysUntil: number): string {
  if (daysUntil === 0) return "اليوم يوم العرس. ألف مبروك!";
  if (daysUntil === 1) return "العرس غدًا. راجع آخر المهام والدفعات.";
  return `باقي ${daysLabel(daysUntil)} على العرس. راجع المهام والدفعات القادمة.`;
}

function daysLabel(days: number): string {
  if (days === 2) return "يومان";
  if (days <= 10) return `${days} أيام`;
  return `${days} يومًا`;
}
