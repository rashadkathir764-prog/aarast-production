import {
  PaymentScheduleStatus,
  WeddingPlan,
  WeddingTaskPriority,
} from "@prisma/client";
import {
  DashboardDueMoneyItem,
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  DashboardNotificationPreviewResponse,
  DashboardNotificationRecord,
  DashboardPaymentScheduleRecord,
  DashboardPlanProviderLinkRecord,
  DashboardProviderPreviewResponse,
  DashboardTaskRecord,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import { selectTopDashboardActions } from "./dashboard-priority";

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

export function buildImportantItems({
  weddingPlanId,
  tasks,
  paymentSchedules,
  providers,
  today,
  receivedQuotes,
  pendingInvites,
  hasLocation,
  hasBudget,
  guestCount,
  quoteRequestsCount,
  acceptedProviders,
  currency,
}: {
  weddingPlanId: string;
  tasks: DashboardTaskRecord[];
  paymentSchedules: DashboardDueMoneyItem[];
  providers: DashboardPlanProviderLinkRecord[];
  today: Date;
  receivedQuotes: number;
  pendingInvites: number;
  hasLocation: boolean;
  hasBudget: boolean;
  guestCount: number;
  quoteRequestsCount: number;
  acceptedProviders: number;
  currency: string;
}): DashboardImportantItemResponse[] {
  const items: DashboardImportantItemResponse[] = [];

  for (const task of tasks) {
    const isOverdue = task.dueDate !== null && task.dueDate < today;
    items.push({
      id: task.id,
      type: isOverdue ? "TASK_OVERDUE" : "TASK_TODAY",
      title: isOverdue ? "مهمة متأخرة" : "مهمة اليوم",
      subtitle: task.title,
      body: task.dueDate
        ? `${isOverdue ? "كان موعدها" : "موعدها"} ${formatDateArabic(task.dueDate)}`
        : null,
      icon: "calendar",
      tone: isOverdue ? "danger" : toneForTaskPriority(task.priority),
      priority: isOverdue ? "URGENT" : "HIGH",
      actionLabel: "تنفيذ الآن",
      dueDate: task.dueDate,
      amount: null,
      route: `/wedding-plans/${weddingPlanId}/tasks`,
      routeTarget: `/wedding-plans/${weddingPlanId}/tasks`,
      entityId: task.id,
      data: { weddingPlanId, taskId: task.id },
    });
  }

  for (const schedule of paymentSchedules) {
    const overdue = schedule.dueDate < today;
    const routeTarget = `/wedding-plans/${weddingPlanId}/money/costs/${schedule.weddingCostId}/schedules/${schedule.id}`;
    items.push({
      id: schedule.id,
      type: "PAYMENT_SCHEDULE_DUE",
      title: overdue ? "موعد دفع متأخر" : "موعد دفع قريب",
      subtitle: schedule.title,
      body: `${formatDateArabic(schedule.dueDate)} · ${schedule.amount.toString()} ${currency}`,
      icon: "wallet",
      tone: overdue ? "danger" : "warning",
      priority: overdue ? "URGENT" : "HIGH",
      actionLabel: "عرض موعد الدفع",
      dueDate: schedule.dueDate,
      amount: schedule.amount.toString(),
      route: routeTarget,
      routeTarget,
      entityId: schedule.id,
      data: {
        weddingPlanId,
        weddingCostId: schedule.weddingCostId,
        paymentScheduleId: schedule.id,
      },
    });
  }

  if (receivedQuotes > 0) {
    items.push({
      id: `quote-received:${weddingPlanId}`,
      type: "QUOTE_RECEIVED",
      title: "وصل عرض سعر",
      subtitle: `${receivedQuotes} عرض بانتظار قرارك`,
      body: "راجع العرض الحقيقي ثم اقبله أو ارفضه من مركز الخطة.",
      icon: "provider",
      tone: "warning",
      priority: "HIGH",
      actionLabel: "مراجعة العروض",
      dueDate: null,
      amount: null,
      route: `/wedding-plans/${weddingPlanId}/plan-center`,
      routeTarget: `/wedding-plans/${weddingPlanId}/plan-center`,
      entityId: null,
      data: { weddingPlanId },
    });
  }

  if (pendingInvites > 0) {
    items.push({
      id: `pending-invites:${weddingPlanId}`,
      type: "INVITE_PENDING",
      title: "دعوات مشاركة معلقة",
      subtitle: `${pendingInvites} دعوة لم تُحسم بعد`,
      body: null,
      icon: "calendar",
      tone: "info",
      priority: "NORMAL",
      actionLabel: "إدارة المشاركين",
      dueDate: null,
      amount: null,
      route: `/wedding-plans/${weddingPlanId}/sharing`,
      routeTarget: `/wedding-plans/${weddingPlanId}/sharing`,
      entityId: null,
      data: { weddingPlanId },
    });
  }

  if (!hasLocation) {
    items.push(
      setupAction(
        weddingPlanId,
        "SET_LOCATION",
        "أكمل موقع الزفاف",
        "الموقع يساعدك في تصفية الموردين وتوضيح طلبات الأسعار.",
        `/wedding-plans/${weddingPlanId}/plan-center`,
      ),
    );
  }
  if (!hasBudget) {
    items.push(
      setupAction(
        weddingPlanId,
        "SET_BUDGET",
        "حدد ميزانية الخطة",
        "حدد سقفًا ماليًا واحدًا ثم وزّعه اختياريًا على التصنيفات.",
        `/wedding-plans/${weddingPlanId}/money/budget`,
      ),
    );
  }
  if (guestCount === 0) {
    items.push(
      setupAction(
        weddingPlanId,
        "ADD_GUESTS",
        "ابدأ قائمة الضيوف",
        "لم تتم إضافة ضيوف إلى الخطة بعد.",
        `/wedding-plans/${weddingPlanId}/guests`,
      ),
    );
  }
  if (quoteRequestsCount === 0 && acceptedProviders === 0) {
    items.push(
      setupAction(
        weddingPlanId,
        "REQUEST_QUOTE",
        "اطلب أول عرض سعر",
        "لم يتم إرسال طلب عرض سعر لأي مزود بعد.",
        "/providers",
      ),
    );
  }

  const firstProvider = providers[0];
  if (firstProvider) {
    const provider = firstProvider.provider;
    items.push({
      id: firstProvider.id,
      type: "PLAN_PROVIDER",
      title: "مزود في خطتك",
      subtitle: provider.businessName,
      body: [
        provider.primaryCategory?.nameAr ?? null,
        Number(provider.ratingAverage) > 0
          ? `تقييم ${provider.ratingAverage.toString()}`
          : null,
      ]
        .filter((part): part is string => Boolean(part))
        .join(" · "),
      icon: "provider",
      tone: "success",
      priority: "LOW",
      actionLabel: "عرض الملف",
      dueDate: null,
      amount: null,
      route: `/providers/${provider.id}`,
      routeTarget: `/providers/${provider.id}`,
      entityId: provider.id,
      data: {
        weddingPlanId,
        providerId: provider.id,
        planProviderLinkId: firstProvider.id,
      },
    });
  }

  return selectTopDashboardActions(items);
}

export function toProviderPreviewResponse(
  link: DashboardPlanProviderLinkRecord,
): DashboardProviderPreviewResponse {
  const service = link.provider.services[0];
  const image = service?.images[0]?.imageUrl ?? null;
  return {
    id: link.id,
    providerId: link.providerId,
    businessName: link.provider.businessName,
    categoryName: link.provider.primaryCategory?.nameAr ?? null,
    serviceTitle: service?.title ?? null,
    imageUrl: link.provider.coverUrl ?? link.provider.logoUrl ?? image,
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

export function buildFinancialWarnings({
  remainingBudget,
  overdueCount,
  dueSoonCount,
}: {
  remainingBudget: number | null;
  overdueCount: number | null;
  dueSoonCount: number | null;
}): WeddingPlanDashboardSummaryResponse["financialWarnings"] {
  const warnings: WeddingPlanDashboardSummaryResponse["financialWarnings"] = [];
  if (remainingBudget !== null && remainingBudget < 0) {
    warnings.push({
      type: "BUDGET_EXCEEDED",
      severity: "DANGER",
      message: "التكاليف المؤكدة تجاوزت الميزانية العامة.",
      count: null,
      amount: moneyOrNull(Math.abs(remainingBudget)),
    });
  }
  if (overdueCount !== null && overdueCount > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_OVERDUE",
      severity: "DANGER",
      message: "لديك مواعيد دفع متأخرة تحتاج متابعة.",
      count: overdueCount,
      amount: null,
    });
  }
  if (dueSoonCount !== null && dueSoonCount > 0) {
    warnings.push({
      type: "PAYMENT_SCHEDULE_DUE_SOON",
      severity: "WARNING",
      message: "لديك مواعيد دفع خلال الأيام السبعة القادمة.",
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

export function formatDateArabic(date: Date): string {
  return new Intl.DateTimeFormat("ar-YE", {
    day: "numeric",
    month: "long",
  }).format(date);
}

export function toPlanResponse(plan: WeddingPlan) {
  return {
    id: plan.id,
    ownerUserId: plan.ownerUserId,
    title: plan.title,
    city: plan.city,
    weddingDate: plan.weddingDate,
    estimatedBudget: plan.estimatedBudget?.toString() ?? null,
    currency: plan.currency,
    status: plan.status,
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
  };
}

export function resolveBudgetTotal(
  plan: Pick<WeddingPlan, "estimatedBudget">,
): number | null {
  return plan.estimatedBudget === null
    ? null
    : decimalToNumber(plan.estimatedBudget);
}

export function decimalToNumber(value: { toString(): string } | null): number {
  if (!value) return 0;
  const parsed = Number(value.toString());
  return Number.isFinite(parsed) ? parsed : 0;
}

export function moneyOrNull(value: number | null): string | null {
  return value === null ? null : value.toFixed(2);
}

export function daysRemaining(
  weddingDate: Date | null,
  today: Date,
): number | null {
  if (!weddingDate) return null;
  const weddingDay = new Date(
    weddingDate.getFullYear(),
    weddingDate.getMonth(),
    weddingDate.getDate(),
  );
  return Math.ceil((weddingDay.getTime() - today.getTime()) / 86_400_000);
}

export function progressPercentage(
  totalTasks: number,
  completedTasks: number,
): number {
  if (totalTasks < 1) return 0;
  return Math.round((completedTasks / totalTasks) * 100);
}

function setupAction(
  weddingPlanId: string,
  type: Extract<
    DashboardImportantItemType,
    "SET_LOCATION" | "SET_BUDGET" | "ADD_GUESTS" | "REQUEST_QUOTE"
  >,
  title: string,
  body: string,
  routeTarget: string,
): DashboardImportantItemResponse {
  return {
    id: `${type.toLowerCase()}:${weddingPlanId}`,
    type,
    title,
    subtitle: "إعداد الخطة",
    body,
    icon: type === "SET_BUDGET" ? "wallet" : "calendar",
    tone: "info",
    priority: "LOW",
    actionLabel: "إكمال الآن",
    dueDate: null,
    amount: null,
    route: routeTarget,
    routeTarget,
    entityId: weddingPlanId,
    data: { weddingPlanId },
  };
}

function toneForTaskPriority(
  priority: WeddingTaskPriority,
): DashboardImportantItemResponse["tone"] {
  if (priority === WeddingTaskPriority.URGENT) return "danger";
  if (priority === WeddingTaskPriority.HIGH) return "warning";
  return "info";
}
