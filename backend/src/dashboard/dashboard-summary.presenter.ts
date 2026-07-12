import {
  InstallmentStatus,
  WeddingPlan,
  WeddingTaskPriority,
} from "@prisma/client";
import {
  DashboardDueMoneyItem,
  DashboardFinancialCommitmentRecord,
  DashboardFinancialInstallmentRecord,
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  DashboardNotificationPreviewResponse,
  DashboardNotificationRecord,
  DashboardPlanProviderLinkRecord,
  DashboardProviderPreviewResponse,
  DashboardTaskRecord,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import { selectTopDashboardActions } from "./dashboard-priority";

export function toFinancialDueMoneyItem(
  installment: DashboardFinancialInstallmentRecord,
  commitments: Map<string, DashboardFinancialCommitmentRecord>,
): DashboardDueMoneyItem {
  const commitment = commitments.get(installment.financialCommitmentId);
  return {
    id: installment.id,
    financialCommitmentId: installment.financialCommitmentId,
    title: commitment?.title ?? "مستحق مالي",
    amount: installment.amount,
    dueDate: installment.dueDate,
    status: installment.status,
  };
}

export function compareNullableDates(
  first: Date | null,
  second: Date | null,
): number {
  const firstTime = first?.getTime() ?? Number.MAX_SAFE_INTEGER;
  const secondTime = second?.getTime() ?? Number.MAX_SAFE_INTEGER;
  return firstTime - secondTime;
}

export function isOpenInstallment(status: InstallmentStatus): boolean {
  return (
    status === InstallmentStatus.PENDING ||
    status === InstallmentStatus.OVERDUE
  );
}

export function buildImportantItems({
  weddingPlanId,
  tasks,
  installments,
  providers,
  today,
  receivedQuotes,
  pendingInvites,
  hasLocation,
  hasBudget,
  guestCount,
  quoteRequestsCount,
  acceptedProviders,
}: {
  weddingPlanId: string;
  tasks: DashboardTaskRecord[];
  installments: DashboardDueMoneyItem[];
  providers: DashboardPlanProviderLinkRecord[];
  today: Date;
  receivedQuotes: number;
  pendingInvites: number;
  hasLocation: boolean;
  hasBudget: boolean;
  guestCount: number;
  quoteRequestsCount: number;
  acceptedProviders: number;
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
        ? `${isOverdue ? "كان موعدها" : "موعدها"} ${formatDateArabic(
            task.dueDate,
          )}`
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
      data: {
        weddingPlanId,
        taskId: task.id,
      },
    });
  }

  for (const installment of installments) {
    const routeTarget = `/wedding-plans/${weddingPlanId}/finance/commitments/${installment.financialCommitmentId}`;
    items.push({
      id: installment.id,
      type: "INSTALLMENT_DUE",
      title:
        installment.status === InstallmentStatus.OVERDUE
          ? "قسط متأخر"
          : "دفعة قادمة",
      subtitle: installment.title,
      body: [
        installment.dueDate ? formatDateArabic(installment.dueDate) : null,
        `${moneyOrNull(decimalToNumber(installment.amount))} ر.ي`,
      ]
        .filter((part): part is string => Boolean(part))
        .join(" · "),
      icon: "wallet",
      tone:
        installment.status === InstallmentStatus.OVERDUE
          ? "danger"
          : "warning",
      priority:
        installment.status === InstallmentStatus.OVERDUE ? "URGENT" : "HIGH",
      actionLabel: "عرض التفاصيل",
      dueDate: installment.dueDate,
      amount: installment.amount.toString(),
      route: routeTarget,
      routeTarget,
      entityId: installment.id,
      data: {
        weddingPlanId,
        financialCommitmentId: installment.financialCommitmentId,
        installmentId: installment.id,
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
        "أضف ميزانية حقيقية لعرض المتبقي والمصروف بدقة.",
        `/wedding-plans/${weddingPlanId}/finance`,
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
        "لم يتم إرسال طلب عرض سعر لأي مورد بعد.",
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
      title: "مزود قريب منك",
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
  dueInstallmentsCount,
}: {
  remainingBudget: number | null;
  dueInstallmentsCount: number | null;
}): WeddingPlanDashboardSummaryResponse["financialWarnings"] {
  const warnings: WeddingPlanDashboardSummaryResponse["financialWarnings"] =
    [];

  if (remainingBudget !== null && remainingBudget < 0) {
    warnings.push({
      type: "BUDGET_EXCEEDED",
      severity: "DANGER",
      message: "Spent total is above the available wedding budget.",
      count: null,
      amount: moneyOrNull(Math.abs(remainingBudget)),
    });
  }
  if (dueInstallmentsCount !== null && dueInstallmentsCount > 0) {
    warnings.push({
      type: "INSTALLMENT_DUE_SOON",
      severity: "WARNING",
      message: "There are installments due soon.",
      count: dueInstallmentsCount,
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
  const formatter = new Intl.DateTimeFormat("ar-YE", {
    day: "numeric",
    month: "long",
  });
  return formatter.format(date);
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
  categories: { targetAmount: { toString(): string } | null }[],
): number {
  if (plan.estimatedBudget) {
    return decimalToNumber(plan.estimatedBudget);
  }

  return categories.reduce(
    (sum, category) => sum + decimalToNumber(category.targetAmount),
    0,
  );
}

export function decimalToNumber(
  value: { toString(): string } | null,
): number {
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
  const millisecondsPerDay = 24 * 60 * 60 * 1000;
  return Math.ceil((weddingDay.getTime() - today.getTime()) / millisecondsPerDay);
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
