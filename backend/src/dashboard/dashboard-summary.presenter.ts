import {
  PaymentScheduleStatus,
  Prisma,
  WeddingPlan,
  WeddingTaskPriority,
} from "@prisma/client";
import {
  DashboardDueMoneyItem,
  DashboardImportantItemResponse,
  DashboardNotificationPreviewResponse,
  DashboardNotificationRecord,
  DashboardPaymentScheduleRecord,
  DashboardPlanProviderLinkRecord,
  DashboardProviderPreviewResponse,
  DashboardTaskRecord,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import type {
  DashboardNextStepResponse,
  DashboardNextStepType,
} from "./dashboard-setup.contracts";
import { selectTopDashboardActions } from "./dashboard-priority";
import {
  type AddressForm,
  gendered,
  textFor,
} from "../shared-kernel/voice/address-form";
import {
  dayCountWords,
  daysBetween,
  weekdayDayMonthWords,
  whenWords,
} from "../shared-kernel/voice/day-words";

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
  canManageMoney,
  form,
  planPersona,
  mahrRecorded = null,
  weddingCostsCount = null,
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
  /** A reader who may record a payment is offered that; others only read it. */
  canManageMoney: boolean;
  /** The reader's form (B5): the next steps speak to them. */
  form: AddressForm;
  /** Whose wedding the plan is: the bride's guests are «الضيفات». */
  planPersona: string | null;
  /**
   * Whether the plan's mahr is recorded; null when the reader may not record
   * or see it (only the owner records it), so no step is invented.
   */
  mahrRecorded?: boolean | null;
  /**
   * The plan's wedding agreements, the mahr's not counted; null for a reader
   * who does not see the plan's money.
   */
  weddingCostsCount?: number | null;
}): DashboardNextStepResponse[] {
  const items: DashboardNextStepResponse[] = [];
  const say = (masculine: string, feminine: string) =>
    textFor(form, gendered(masculine, feminine));

  // A next step names the thing, says why it is first, and offers the one
  // action that moves it; the amount stays data so «أخفِ المبالغ» can hide it.
  for (const task of tasks) {
    const isOverdue = task.dueDate !== null && task.dueDate < today;
    const days = task.dueDate ? daysBetween(today, task.dueDate) : null;
    const taskRoute = `/wedding-plans/${weddingPlanId}/tasks/${task.id}`;
    items.push({
      id: task.id,
      type: isOverdue ? "TASK_OVERDUE" : "TASK_TODAY",
      title: task.title,
      subtitle:
        days === null
          ? say("حدد لها موعد عشان ما تنساها", "حددي لها موعد عشان ما تنسيها")
          : isOverdue
            ? `متأخرة ${dayCountWords(-days)}`
            : `موعدها ${whenWords(days)}`,
      body: task.dueDate ? weekdayDayMonthWords(task.dueDate) : null,
      icon: "calendar",
      tone: isOverdue ? "danger" : toneForTaskPriority(task.priority),
      priority: isOverdue ? "URGENT" : "HIGH",
      actionLabel: say("افتح المهمة", "افتحي المهمة"),
      dueDate: task.dueDate,
      amount: null,
      route: taskRoute,
      routeTarget: taskRoute,
      entityId: task.id,
      data: { weddingPlanId, taskId: task.id },
    });
  }

  for (const schedule of paymentSchedules) {
    const overdue = schedule.dueDate < today;
    const days = daysBetween(today, schedule.dueDate);
    const scheduleRoute = `/wedding-plans/${weddingPlanId}/money/costs/${schedule.weddingCostId}/schedules/${schedule.id}`;
    const routeTarget = canManageMoney ? `${scheduleRoute}/pay` : scheduleRoute;
    items.push({
      id: schedule.id,
      type: "PAYMENT_SCHEDULE_DUE",
      title: schedule.title,
      subtitle: overdue
        ? `فات موعدها من ${dayCountWords(-days)}`
        : `موعدها ${whenWords(days)}`,
      body: weekdayDayMonthWords(schedule.dueDate),
      icon: "wallet",
      tone: overdue ? "danger" : "warning",
      priority: overdue ? "URGENT" : "HIGH",
      actionLabel: canManageMoney
        ? say("سجّل الدفعة", "سجّلي الدفعة")
        : say("شوف الدفعة", "شوفي الدفعة"),
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
    const single = receivedQuotes === 1;
    const providersRoute = `/wedding-plans/${weddingPlanId}/providers`;
    items.push({
      id: `quote-received:${weddingPlanId}`,
      type: "QUOTE_RECEIVED",
      title: single
        ? "وصلك عرض سعر"
        : receivedQuotes === 2
          ? "وصلك عرضين"
          : `وصلك ${receivedQuotes} ${receivedQuotes <= 10 ? "عروض" : "عرض"}`,
      subtitle: single
        ? say("شوفه قبل ما تنتهي مدته", "شوفيه قبل ما تنتهي مدته")
        : say("قارن بينها قبل ما تنتهي مدتها", "قارني بينها قبل ما تنتهي مدتها"),
      body: null,
      icon: "provider",
      tone: "warning",
      priority: "HIGH",
      actionLabel: single
        ? say("شوف العرض", "شوفي العرض")
        : say("قارن العروض", "قارني العروض"),
      dueDate: null,
      amount: null,
      route: providersRoute,
      routeTarget: providersRoute,
      entityId: null,
      data: { weddingPlanId },
    });
  }

  if (pendingInvites > 0) {
    items.push({
      id: `pending-invites:${weddingPlanId}`,
      type: "INVITE_PENDING",
      title:
        pendingInvites === 1
          ? "دعوة مشاركة تنتظر الرد"
          : pendingInvites === 2
            ? "دعوتين تنتظر الرد"
            : `${pendingInvites} ${pendingInvites <= 10 ? "دعوات" : "دعوة"} تنتظر الرد`,
      subtitle: "ما يشوفون الخطة لين يقبلون",
      body: null,
      icon: "calendar",
      tone: "info",
      priority: "NORMAL",
      actionLabel: say("شوف الدعوات", "شوفي الدعوات"),
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
        say("أكمل موقع الزفاف", "أكملي موقع الزفاف"),
        "عشان تشوف مزودين مدينتك وتوصلهم طلباتك بوضوح",
        say("حدد الموقع", "حددي الموقع"),
        `/wedding-plans/${weddingPlanId}/plan-center`,
      ),
    );
  }
  if (!hasBudget) {
    items.push(
      setupAction(
        weddingPlanId,
        "SET_BUDGET",
        say("حدد ميزانية الخطة", "حددي ميزانية الخطة"),
        say(
          "رقم تقريبي يكفي، ومنه تعرف كم تقدر تصرف على كل بند",
          "رقم تقريبي يكفي، ومنه تعرفي كم تقدري تصرفي على كل بند",
        ),
        say("حدد الميزانية", "حددي الميزانية"),
        `/wedding-plans/${weddingPlanId}/money/budget`,
      ),
    );
  }
  // J1-04: the home's next step is the first item, so the money basics come
  // here in the one order the app follows: the mahr (a groom's or a bride's
  // plan, outside the wedding budget), then the first agreement. Each only
  // while it is missing, and only for a reader who may record it.
  const planHasMahrSide = planPersona === "GROOM" || planPersona === "BRIDE";
  if (canManageMoney && planHasMahrSide && mahrRecorded === false) {
    items.push(
      setupAction(
        weddingPlanId,
        "RECORD_MAHR",
        "اتفقتوا على المهر؟",
        "نحسبه لحاله، برا ميزانية العرس.",
        say("سجّل المهر", "سجّلي المهر"),
        `/wedding-plans/${weddingPlanId}/money/mahr`,
      ),
    );
  }
  if (canManageMoney && weddingCostsCount === 0) {
    items.push(
      setupAction(
        weddingPlanId,
        "ADD_FIRST_COST",
        say("سجّل أول اتفاق", "سجّلي أول اتفاق"),
        "القاعة أو الذهب أو الكسوة: أول رقم يخلي الباقي يبان",
        say("أضف اتفاق", "أضيفي اتفاق"),
        `/wedding-plans/${weddingPlanId}/money/costs/create`,
      ),
    );
  }
  if (guestCount === 0) {
    // D55: the verb follows the reader, the guests follow the plan: the
    // bride's are «الضيفات», so her first one is «ضيفة».
    const brideGuests = planPersona === "BRIDE";
    items.push(
      setupAction(
        weddingPlanId,
        "ADD_GUESTS",
        `${say("ابدأ", "ابدئي")} قائمة ${brideGuests ? "الضيفات" : "الضيوف"}`,
        brideGuests
          ? "العدد يحدد حجم الصالة وتكلفة الضيافة"
          : "العدد يحدد حجم القاعة وتكلفة الضيافة",
        brideGuests
          ? say("أضف أول ضيفة", "أضيفي أول ضيفة")
          : say("أضف أول ضيف", "أضيفي أول ضيف"),
        `/wedding-plans/${weddingPlanId}/guests`,
      ),
    );
  }
  if (quoteRequestsCount === 0 && acceptedProviders === 0) {
    items.push(
      setupAction(
        weddingPlanId,
        "REQUEST_QUOTE",
        say("اطلب أول عرض سعر", "اطلبي أول عرض سعر"),
        "الليالي تنحجز بدري، والعرض يعطيك سعر حقيقي بدل التخمين",
        say("شوف المزودين", "شوفي المزودين"),
        `/wedding-plans/${weddingPlanId}/providers`,
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
      message: "التكاليف المؤكدة تجاوزت الميزانية العامة.",
      count: null,
      amount: moneyOrNull(remaining.abs()),
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
    DashboardNextStepType,
    | "SET_LOCATION"
    | "SET_BUDGET"
    | "RECORD_MAHR"
    | "ADD_FIRST_COST"
    | "ADD_GUESTS"
    | "REQUEST_QUOTE"
  >,
  title: string,
  reason: string,
  actionLabel: string,
  routeTarget: string,
): DashboardNextStepResponse {
  const moneyStep =
    type === "SET_BUDGET" || type === "RECORD_MAHR" || type === "ADD_FIRST_COST";
  return {
    id: `${type.toLowerCase()}:${weddingPlanId}`,
    type,
    title,
    subtitle: reason,
    body: null,
    icon: moneyStep ? "wallet" : "calendar",
    tone: "info",
    priority: "LOW",
    actionLabel,
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
