import { Prisma, WeddingPlan } from "@prisma/client";
import {
  DashboardDueMoneyItem,
  DashboardNotificationPreviewResponse,
  DashboardNotificationRecord,
  DashboardPaymentScheduleRecord,
  DashboardPlanProviderLinkRecord,
  DashboardProviderPreviewResponse,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import { daysBetween } from "../shared-kernel/voice/day-words";
import { MONEY_WARNING_COPY } from "../shared-kernel/copy/money-warnings.ar";

// The home's next steps (REFINEMENT_SPEC 2.1) are built and ordered in
// `dashboard-next-steps.ts` and `dashboard-priority.ts`.

export function toPaymentScheduleDueMoneyItem(
  schedule: DashboardPaymentScheduleRecord,
): DashboardDueMoneyItem {
  return {
    id: schedule.id,
    weddingCostId: schedule.weddingCostId,
    title: schedule.weddingCost.title,
    amount: schedule.amount,
    dueDate: schedule.dueDate,
    status: schedule.status,
  };
}

export function compareDates(first: Date, second: Date): number {
  return first.getTime() - second.getTime();
}

export function toProviderPreviewResponse(
  link: DashboardPlanProviderLinkRecord,
): DashboardProviderPreviewResponse {
  const service = link.provider.services[0];
  return {
    id: link.id,
    providerId: link.providerId,
    businessName: link.provider.businessName,
    categoryName: link.provider.primaryCategory?.nameAr ?? null,
    serviceTitle: service?.title ?? null,
    // RA-BE-44 (D62): the provider's own cover or logo, never a service
    // photo, which nobody reviews (RA-BE-12 kept them out of public reads).
    imageUrl: link.provider.coverUrl ?? link.provider.logoUrl ?? null,
    ratingAverage: link.provider.ratingAverage.toString(),
    ratingCount: link.provider.ratingCount,
    status: link.status,
  };
}

export function nextProviderAction(
  pending: number,
  received: number,
  accepted: number,
): string {
  if (received > 0) return "REVIEW_RECEIVED_QUOTES";
  if (pending > 0) return "WAIT_FOR_PROVIDER_RESPONSE";
  if (accepted > 0) return "MANAGE_ACCEPTED_PROVIDERS";
  return "REQUEST_FIRST_QUOTE";
}

/**
 * `remainingBudget` is the budget less what the wedding items are expected
 * to cost (D105); below zero is «over the budget».
 */
export function buildFinancialWarnings({
  remainingBudget,
  overdueCount,
  dueSoonCount,
}: {
  remainingBudget: Prisma.Decimal | number | null;
  overdueCount: number | null;
  dueSoonCount: number | null;
}): WeddingPlanDashboardSummaryResponse["financialWarnings"] {
  const warnings: WeddingPlanDashboardSummaryResponse["financialWarnings"] = [];
  const remaining =
    remainingBudget === null ? null : new Prisma.Decimal(remainingBudget);
  if (remaining !== null && remaining.isNegative()) {
    warnings.push({
      type: "BUDGET_EXCEEDED",
      severity: "DANGER",
      message: MONEY_WARNING_COPY.budgetExceeded,
      count: null,
      amount: moneyOrNull(remaining.abs()),
    });
  }
  if (overdueCount !== null && overdueCount > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_OVERDUE",
      severity: "DANGER",
      message: MONEY_WARNING_COPY.paymentsOverdue(overdueCount),
      count: overdueCount,
      amount: null,
    });
  }
  if (dueSoonCount !== null && dueSoonCount > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_DUE_SOON",
      severity: "WARNING",
      message: MONEY_WARNING_COPY.paymentsDueSoon(dueSoonCount),
      count: dueSoonCount,
      amount: null,
    });
  }
  return warnings;
}

export function toNotificationPreview(
  notification: DashboardNotificationRecord,
): DashboardNotificationPreviewResponse {
  return {
    id: notification.id,
    type: notification.type,
    priority: notification.priority,
    title: notification.title,
    body: notification.body,
    readAt: notification.readAt,
    createdAt: notification.createdAt,
    data: notification.data,
    entityType: notification.entityType,
    entityId: notification.entityId,
    routeTarget: notification.routeTarget,
  };
}

// Money is numeric(14,2) in the database and Prisma.Decimal in code. The
// dashboard composes the same totals Finance reports, so it sums exactly:
// a float accumulation loses cents once amounts reach the column's
// magnitude, and the two surfaces would then disagree.
export function sumMoney(
  values: Iterable<Prisma.Decimal | number | string | null | undefined>,
): Prisma.Decimal {
  let sum = new Prisma.Decimal(0);
  for (const value of values) {
    if (value === null || value === undefined) continue;
    sum = sum.plus(new Prisma.Decimal(value));
  }
  return sum;
}

export function resolveBudgetDecimal(
  plan: Pick<WeddingPlan, "estimatedBudget">,
): Prisma.Decimal | null {
  return plan.estimatedBudget === null
    ? null
    : new Prisma.Decimal(plan.estimatedBudget);
}

export function moneyOrNull(
  value: Prisma.Decimal | number | null,
): string | null {
  return value === null ? null : value.toFixed(2);
}

/**
 * Whole days from today to the wedding, both read as days in Sana'a (D11),
 * as the countdown notice and the assistant count them. It read the wedding
 * day in the server's own zone and rounded up against Sana'a's midnight, so
 * on a server in UTC it said one day more, 1 on the wedding day and 0 the
 * day after (the member's home showed the wedding day a day late).
 */
export function daysRemaining(
  weddingDate: Date | null,
  today: Date,
): number | null {
  if (!weddingDate) return null;
  return daysBetween(today, weddingDate);
}

export function progressPercentage(
  totalTasks: number,
  completedTasks: number,
): number {
  if (totalTasks < 1) return 0;
  return Math.round((completedTasks / totalTasks) * 100);
}
