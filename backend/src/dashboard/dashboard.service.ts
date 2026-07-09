import { Injectable } from "@nestjs/common";
import {
  DebtStatus,
  ExpenseStatus,
  FinancialCommitmentStatus,
  GuestStatus,
  InstallmentStatus,
  NotificationPriority,
  NotificationType,
  PlanProviderLinkStatus,
  Prisma,
  ProviderStatus,
  QuoteRequestStatus,
  SharedMemberRole,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { endOfRiyadhDay, startOfRiyadhDay } from "../common/time/business-day";
import { PrismaService } from "../prisma/prisma.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";
import {
  WeddingLocationResponse,
  weddingLocationResponse,
} from "../wedding-plans/wedding-location";
import { selectTopDashboardActions } from "./dashboard-priority";

export interface DashboardPermissionSummary {
  isOwner: boolean;
  role: "OWNER" | SharedMemberRole | null;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canManageMembers: boolean;
  canManageFinancialRecords: boolean;
  canManagePlan: boolean;
}

export interface WeddingPlanDashboardSummaryResponse {
  dataScope: "ACCOUNT_BACKED";
  accountBacked: true;
  planId: string;
  title: string;
  weddingDate: Date | null;
  city: string | null;
  location: WeddingLocationResponse | null;
  status: WeddingPlanStatus;
  daysRemaining: number | null;
  progressPercentage: number;
  budgetTotal: string | null;
  spentTotal: string | null;
  remainingBudget: string | null;
  debtTotal: string | null;
  paidDebtTotal: string | null;
  unpaidDebtTotal: string | null;
  dueInstallmentsCount: number | null;
  totalTasks: number;
  completedTasks: number;
  overdueTasks: number;
  todayTasks: number;
  guestCount: number;
  confirmedGuests: number;
  pendingGuests: number;
  declinedGuests: number;
  incompleteGuestsCount: number;
  providerCount: number;
  quoteRequestsCount: number;
  pendingQuoteRequests: number;
  receivedQuotes: number;
  acceptedProviders: number;
  acceptedProvidersCount: number;
  quoteStatusBreakdown: {
    pending: number;
    offered: number;
    accepted: number;
    rejectedClosed: number;
  };
  nextProviderAction: string;
  participantCount: number;
  pendingInvites: number;
  unreadNotificationsCount: number;
  highPriorityNotificationsCount: number;
  importantItems: DashboardImportantItemResponse[];
  nextBestActions: DashboardImportantItemResponse[];
  planProviders: DashboardProviderPreviewResponse[];
  importantNotifications: DashboardNotificationPreviewResponse[];
  latestImportantNotification: DashboardNotificationPreviewResponse | null;
  nextTask: {
    id: string;
    title: string;
    dueAt: Date | null;
    status: WeddingTaskStatus;
  } | null;
  nextInstallmentDue: {
    id: string;
    debtId: string;
    amount: string;
    dueAt: Date | null;
    status: InstallmentStatus;
  } | null;
  moneySummary: {
    totalBudget: string | null;
    totalSpent: string | null;
    remainingBudget: string | null;
    totalDebts: string | null;
    overBudget: boolean | null;
  };
  financialWarnings: {
    type: "BUDGET_EXCEEDED" | "INSTALLMENT_OVERDUE" | "INSTALLMENT_DUE_SOON";
    severity: "WARNING" | "DANGER";
    message: string;
    count: number | null;
    amount: string | null;
  }[];
  taskSummary: {
    total: number;
    completed: number;
    pendingInProgress: number;
    overdue: number;
    dueToday: number;
  };
  guestSummary: {
    total: number;
    confirmed: number;
    pending: number;
    declined: number;
    incompleteGuestsCount: number;
  };
  providerQuoteSummary: {
    pending: number;
    received: number;
    offered: number;
    accepted: number;
    rejectedClosed: number;
    nextAction: string;
  };
  participantSummary: {
    count: number;
    pendingInvites: number;
    currentUserRole: "OWNER" | SharedMemberRole | null;
  };
  notificationSummary: {
    unread: number;
    highPriority: number;
  };
  generatedAt: Date;
  currentUserRole: "OWNER" | SharedMemberRole | null;
  permissions: DashboardPermissionSummary;
}

export type DashboardImportantItemType =
  | "TASK_OVERDUE"
  | "TASK_TODAY"
  | "INSTALLMENT_DUE"
  | "PLAN_PROVIDER"
  | "QUOTE_RECEIVED"
  | "INVITE_PENDING"
  | "SET_LOCATION"
  | "SET_BUDGET"
  | "ADD_GUESTS"
  | "REQUEST_QUOTE";

export interface DashboardImportantItemResponse {
  id: string;
  type: DashboardImportantItemType;
  title: string;
  subtitle: string;
  body: string | null;
  icon: "calendar" | "wallet" | "provider";
  tone: "danger" | "warning" | "success" | "info";
  priority: "URGENT" | "HIGH" | "NORMAL" | "LOW";
  actionLabel: string;
  dueDate: Date | null;
  amount: string | null;
  route: string | null;
  routeTarget: string | null;
  entityId: string | null;
  data: Record<string, string | null>;
}

export interface DashboardProviderPreviewResponse {
  id: string;
  providerId: string;
  businessName: string;
  categoryName: string | null;
  serviceTitle: string | null;
  imageUrl: string | null;
  ratingAverage: string;
  ratingCount: number;
  status: PlanProviderLinkStatus;
}

export interface DashboardNotificationPreviewResponse {
  id: string;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
  data: Prisma.JsonValue | null;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
}

type DashboardTaskRecord = Prisma.WeddingTaskGetPayload<object>;
type DashboardNotificationRecord = Prisma.NotificationGetPayload<object>;
type DashboardInstallmentRecord = Prisma.InstallmentGetPayload<{
  include: {
    debt: {
      select: {
        id: true;
        title: true;
        creditorName: true;
      };
    };
  };
}>;
type DashboardFinancialCommitmentRecord =
  Prisma.FinancialCommitmentGetPayload<object>;
type DashboardFinancialInstallmentRecord =
  Prisma.FinancialInstallmentGetPayload<object>;
interface DashboardDueMoneyItem {
  id: string;
  source: "legacy-debt" | "financial-commitment";
  debtId: string | null;
  financialCommitmentId: string | null;
  title: string;
  amount: Prisma.Decimal;
  dueDate: Date | null;
  status: InstallmentStatus;
}
type DashboardPlanProviderLinkRecord = Prisma.PlanProviderLinkGetPayload<{
  include: {
    provider: {
      include: {
        primaryCategory: true;
        services: {
          include: {
            images: true;
          };
        };
      };
    };
  };
}>;

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async getHome(currentUser: AuthenticatedUser) {
    const currentWeddingPlan = await this.prisma.weddingPlan.findFirst({
      where: {
        ownerUserId: currentUser.id,
        status: WeddingPlanStatus.PLANNING,
      },
      orderBy: [{ weddingDate: "asc" }, { createdAt: "desc" }],
    });

    const [
      marketplaceSummary,
      budgetSummary,
      expensesSummary,
      debtsSummary,
      dueInstallments,
      upcomingTasks,
      sharedMembers,
    ] = await Promise.all([
      this.getMarketplaceSummary(currentUser.id),
      currentWeddingPlan
        ? this.getBudgetSummary(currentWeddingPlan.id)
        : Promise.resolve(null),
      currentWeddingPlan
        ? this.getExpensesSummary(currentWeddingPlan.id)
        : Promise.resolve(null),
      currentWeddingPlan
        ? this.getDebtsSummary(currentWeddingPlan.id)
        : Promise.resolve(null),
      currentWeddingPlan
        ? this.getDueInstallments(currentWeddingPlan.id)
        : Promise.resolve([]),
      currentWeddingPlan
        ? this.getUpcomingTasks(currentWeddingPlan.id)
        : Promise.resolve([]),
      currentWeddingPlan
        ? this.getSharedMembers(currentWeddingPlan.id)
        : Promise.resolve([]),
    ]);

    return {
      currentWeddingPlan: currentWeddingPlan
        ? this.toPlanResponse(currentWeddingPlan)
        : null,
      budgetSummary,
      expensesSummary,
      debtsSummary,
      dueInstallments,
      upcomingTasks,
      sharedMembers,
      marketplaceSummary,
    };
  }

  async getWeddingPlanDashboardSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const today = this.startOfToday();
    const endOfToday = this.endOfToday(today);
    const canViewBudget = this.permissions.canReadFinancial(context, "budget");
    const canViewExpenses = this.permissions.canReadFinancial(
      context,
      "expenses",
    );
    const canViewDebts = this.permissions.canReadFinancial(context, "debts");

    const [
      budgetCategories,
      expenses,
      debts,
      dueInstallmentsCount,
      dueInstallments,
      nextInstallment,
      financialCommitments,
      financialInstallments,
      urgentTasks,
      nextTask,
      totalTasks,
      completedTasks,
      openTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      pendingGuests,
      declinedGuests,
      incompleteGuestsCount,
      providerCount,
      planProviderLinks,
      quoteRequestsCount,
      pendingQuoteRequests,
      receivedQuotes,
      acceptedQuoteRequests,
      rejectedClosedQuoteRequests,
      participantMembersCount,
      pendingInvites,
      unreadNotificationsCount,
      highPriorityNotificationsCount,
      latestNotifications,
      latestImportantNotification,
    ] = await Promise.all([
      canViewBudget
        ? this.prisma.budgetCategory.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewExpenses
        ? this.prisma.expense.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.debt.findMany({
            where: {
              weddingPlanId,
              status: { not: DebtStatus.CANCELLED },
            },
          })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lte: endOfToday },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.findMany({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lte: endOfToday },
            },
            include: {
              debt: {
                select: {
                  id: true,
                  title: true,
                  creditorName: true,
                },
              },
            },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
            take: 2,
          })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.installment.findFirst({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
            },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.financialCommitment.findMany({
            where: { weddingPlanId },
          })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.financialInstallment.findMany({
            where: { weddingPlanId },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve([]),
      this.prisma.weddingTask.findMany({
        where: {
          weddingPlanId,
          dueDate: { lte: endOfToday },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        take: 2,
      }),
      this.prisma.weddingTask.findFirst({
        where: {
          weddingPlanId,
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      }),
      this.prisma.weddingTask.count({ where: { weddingPlanId } }),
      this.prisma.weddingTask.count({
        where: { weddingPlanId, status: WeddingTaskStatus.DONE },
      }),
      this.prisma.weddingTask.count({
        where: {
          weddingPlanId,
          status: {
            in: [WeddingTaskStatus.TODO, WeddingTaskStatus.IN_PROGRESS],
          },
        },
      }),
      this.prisma.weddingTask.count({
        where: {
          weddingPlanId,
          dueDate: { lt: today },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
      }),
      this.prisma.weddingTask.count({
        where: {
          weddingPlanId,
          dueDate: { gte: today, lte: endOfToday },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
      }),
      this.prisma.guest.count({ where: { weddingPlanId } }),
      this.prisma.guest.count({
        where: { weddingPlanId, status: GuestStatus.CONFIRMED },
      }),
      this.prisma.guest.count({
        where: {
          weddingPlanId,
          status: { in: [GuestStatus.PENDING, GuestStatus.INVITED] },
        },
      }),
      this.prisma.guest.count({
        where: { weddingPlanId, status: GuestStatus.DECLINED },
      }),
      this.prisma.guest.count({
        where: {
          weddingPlanId,
          OR: [{ phone: null }, { phone: "" }, { name: "" }],
        },
      }),
      this.prisma.planProviderLink.count({
        where: {
          weddingPlanId,
          status: PlanProviderLinkStatus.ACTIVE,
        },
      }),
      this.prisma.planProviderLink.findMany({
        where: {
          weddingPlanId,
          status: PlanProviderLinkStatus.ACTIVE,
          provider: { status: ProviderStatus.ACTIVE },
        },
        include: {
          provider: {
            include: {
              primaryCategory: true,
              services: {
                where: { isActive: true },
                orderBy: [{ isFeatured: "desc" }, { createdAt: "desc" }],
                take: 1,
                include: {
                  images: {
                    orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
                    take: 1,
                  },
                },
              },
            },
          },
        },
        orderBy: { createdAt: "desc" },
        take: 3,
      }),
      this.prisma.quoteRequest.count({ where: { weddingPlanId } }),
      this.prisma.quoteRequest.count({
        where: {
          weddingPlanId,
          status: {
            in: [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED],
          },
        },
      }),
      this.prisma.quoteRequest.count({
        where: { weddingPlanId, status: QuoteRequestStatus.RESPONDED },
      }),
      this.prisma.quoteRequest.count({
        where: { weddingPlanId, status: QuoteRequestStatus.ACCEPTED },
      }),
      this.prisma.quoteRequest.count({
        where: {
          weddingPlanId,
          status: {
            in: [QuoteRequestStatus.REJECTED, QuoteRequestStatus.CANCELLED],
          },
        },
      }),
      this.prisma.sharedMember.count({ where: { weddingPlanId } }),
      this.prisma.planInvite.count({
        where: {
          weddingPlanId,
          acceptedAt: null,
          declinedAt: null,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
      }),
      this.prisma.notification.count({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          readAt: null,
          archivedAt: null,
        },
      }),
      this.prisma.notification.count({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          archivedAt: null,
          priority: {
            in: [NotificationPriority.HIGH, NotificationPriority.URGENT],
          },
        },
      }),
      this.prisma.notification.findMany({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          archivedAt: null,
        },
        orderBy: { createdAt: "desc" },
        take: 3,
      }),
      this.prisma.notification.findFirst({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          archivedAt: null,
          priority: {
            in: [NotificationPriority.URGENT, NotificationPriority.HIGH],
          },
        },
        orderBy: [{ priority: "desc" }, { createdAt: "desc" }],
      }),
    ]);

    const mirroredDebtIds = new Set(
      financialCommitments
        .map((commitment) => commitment.legacyDebtId)
        .filter((id): id is string => Boolean(id)),
    );
    const mirroredInstallmentIds = new Set(
      financialInstallments
        .map((installment) => installment.legacyInstallmentId)
        .filter((id): id is string => Boolean(id)),
    );
    const legacyDebts = debts.filter((debt) => !mirroredDebtIds.has(debt.id));
    const activeFinancialCommitments = financialCommitments.filter(
      (commitment) => commitment.status !== FinancialCommitmentStatus.CANCELLED,
    );
    const commitmentById = new Map(
      financialCommitments.map((commitment) => [commitment.id, commitment]),
    );
    const openFinancialInstallments = financialInstallments.filter(
      (installment) => this.isOpenInstallment(installment.status),
    );
    const financialDueInstallmentItems = openFinancialInstallments
      .filter(
        (installment) =>
          installment.dueDate !== null && installment.dueDate <= endOfToday,
      )
      .map((installment) =>
        this.toFinancialDueMoneyItem(installment, commitmentById),
      );
    const legacyDueInstallmentItems = dueInstallments
      .filter((installment) => !mirroredInstallmentIds.has(installment.id))
      .map((installment) => this.toLegacyDueMoneyItem(installment));
    const dueMoneyItems = [
      ...financialDueInstallmentItems,
      ...legacyDueInstallmentItems,
    ]
      .sort((a, b) => this.compareNullableDates(a.dueDate, b.dueDate))
      .slice(0, 2);
    const legacyNextInstallment =
      nextInstallment && !mirroredInstallmentIds.has(nextInstallment.id)
        ? this.toLegacyDueMoneyItem({
            ...nextInstallment,
            debt: {
              title: "دين قديم",
            },
          })
        : null;
    const nextFinancialInstallment = openFinancialInstallments[0]
      ? this.toFinancialDueMoneyItem(
          openFinancialInstallments[0],
          commitmentById,
        )
      : null;
    const nextMoneyInstallment =
      [nextFinancialInstallment, legacyNextInstallment]
        .filter((item): item is DashboardDueMoneyItem => item !== null)
        .sort((a, b) => this.compareNullableDates(a.dueDate, b.dueDate))[0] ??
      null;
    const effectiveDueInstallmentsCount = canViewDebts
      ? financialDueInstallmentItems.length + legacyDueInstallmentItems.length
      : null;

    const budgetTotalNumber = canViewBudget
      ? this.resolveBudgetTotal(context.plan, budgetCategories)
      : null;
    const spentTotalNumber = canViewExpenses
      ? expenses.reduce((sum, expense) => {
          if (expense.status !== ExpenseStatus.PAID) return sum;
          return sum + this.decimalToNumber(expense.amount);
        }, 0)
      : null;
    const debtTotalNumber = canViewDebts
      ? activeFinancialCommitments.reduce(
          (sum, commitment) =>
            sum + this.decimalToNumber(commitment.totalAmount),
          0,
        ) +
        legacyDebts.reduce(
          (sum, debt) => sum + this.decimalToNumber(debt.totalAmount),
          0,
        )
      : null;
    const paidDebtTotalNumber = canViewDebts
      ? activeFinancialCommitments.reduce(
          (sum, commitment) =>
            sum + this.decimalToNumber(commitment.paidAmount),
          0,
        ) +
        legacyDebts.reduce(
          (sum, debt) => sum + this.decimalToNumber(debt.paidAmount),
          0,
        )
      : null;
    const remainingBudgetNumber =
      budgetTotalNumber !== null && spentTotalNumber !== null
        ? budgetTotalNumber - spentTotalNumber
        : null;
    const unpaidDebtTotalNumber =
      debtTotalNumber !== null && paidDebtTotalNumber !== null
        ? Math.max(debtTotalNumber - paidDebtTotalNumber, 0)
        : null;
    const location = weddingLocationResponse(
      context.plan.location,
      context.plan.city,
    );
    const nextProviderAction = this.nextProviderAction(
      pendingQuoteRequests,
      receivedQuotes,
      providerCount,
    );
    const financialWarnings = this.buildFinancialWarnings({
      remainingBudget: remainingBudgetNumber,
      dueInstallmentsCount: effectiveDueInstallmentsCount,
    });
    const importantItems = this.buildImportantItems({
      weddingPlanId,
      tasks: urgentTasks,
      installments: dueMoneyItems,
      providers: planProviderLinks,
      today,
      receivedQuotes,
      pendingInvites,
      hasLocation: location !== null,
      hasBudget: budgetTotalNumber !== null && budgetTotalNumber > 0,
      guestCount,
      quoteRequestsCount,
      acceptedProviders: providerCount,
    });
    const currentUserRole = this.currentUserRole(context);
    const notificationPreviews = latestNotifications.map((notification) =>
      this.toNotificationPreview(notification),
    );

    return {
      dataScope: "ACCOUNT_BACKED",
      accountBacked: true,
      planId: context.plan.id,
      title: context.plan.title,
      weddingDate: context.plan.weddingDate,
      city: context.plan.city,
      location,
      status: context.plan.status,
      daysRemaining: this.daysRemaining(context.plan.weddingDate, today),
      progressPercentage: this.progressPercentage(totalTasks, completedTasks),
      budgetTotal: this.moneyOrNull(budgetTotalNumber),
      spentTotal: this.moneyOrNull(spentTotalNumber),
      remainingBudget: this.moneyOrNull(remainingBudgetNumber),
      debtTotal: this.moneyOrNull(debtTotalNumber),
      paidDebtTotal: this.moneyOrNull(paidDebtTotalNumber),
      unpaidDebtTotal: this.moneyOrNull(unpaidDebtTotalNumber),
      dueInstallmentsCount: effectiveDueInstallmentsCount,
      totalTasks,
      completedTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      pendingGuests,
      declinedGuests,
      incompleteGuestsCount,
      providerCount,
      quoteRequestsCount,
      pendingQuoteRequests,
      receivedQuotes,
      acceptedProviders: providerCount,
      acceptedProvidersCount: providerCount,
      quoteStatusBreakdown: {
        pending: pendingQuoteRequests,
        offered: receivedQuotes,
        accepted: acceptedQuoteRequests,
        rejectedClosed: rejectedClosedQuoteRequests,
      },
      nextProviderAction,
      participantCount: participantMembersCount + 1,
      pendingInvites,
      unreadNotificationsCount,
      highPriorityNotificationsCount,
      importantItems,
      nextBestActions: importantItems,
      planProviders: planProviderLinks.map((link) =>
        this.toProviderPreviewResponse(link),
      ),
      importantNotifications: notificationPreviews,
      latestImportantNotification: latestImportantNotification
        ? this.toNotificationPreview(latestImportantNotification)
        : null,
      nextTask: nextTask
        ? {
            id: nextTask.id,
            title: nextTask.title,
            dueAt: nextTask.dueDate,
            status: nextTask.status,
          }
        : null,
      nextInstallmentDue: nextMoneyInstallment
        ? {
            id: nextMoneyInstallment.id,
            debtId:
              nextMoneyInstallment.debtId ??
              nextMoneyInstallment.financialCommitmentId ??
              nextMoneyInstallment.id,
            amount: nextMoneyInstallment.amount.toString(),
            dueAt: nextMoneyInstallment.dueDate,
            status: nextMoneyInstallment.status,
          }
        : null,
      moneySummary: {
        totalBudget: this.moneyOrNull(budgetTotalNumber),
        totalSpent: this.moneyOrNull(spentTotalNumber),
        remainingBudget: this.moneyOrNull(remainingBudgetNumber),
        totalDebts: this.moneyOrNull(debtTotalNumber),
        overBudget:
          remainingBudgetNumber === null ? null : remainingBudgetNumber < 0,
      },
      financialWarnings,
      taskSummary: {
        total: totalTasks,
        completed: completedTasks,
        pendingInProgress: openTasks,
        overdue: overdueTasks,
        dueToday: todayTasks,
      },
      guestSummary: {
        total: guestCount,
        confirmed: confirmedGuests,
        pending: pendingGuests,
        declined: declinedGuests,
        incompleteGuestsCount,
      },
      providerQuoteSummary: {
        pending: pendingQuoteRequests,
        received: receivedQuotes,
        offered: receivedQuotes,
        accepted: providerCount,
        rejectedClosed: rejectedClosedQuoteRequests,
        nextAction: nextProviderAction,
      },
      participantSummary: {
        count: participantMembersCount + 1,
        pendingInvites,
        currentUserRole,
      },
      notificationSummary: {
        unread: unreadNotificationsCount,
        highPriority: highPriorityNotificationsCount,
      },
      generatedAt: new Date(),
      currentUserRole,
      permissions: this.permissionSummary(context),
    };
  }

  private toLegacyDueMoneyItem(installment: {
    id: string;
    debtId: string;
    amount: Prisma.Decimal;
    dueDate: Date | null;
    status: InstallmentStatus;
    debt: { title: string };
  }): DashboardDueMoneyItem {
    return {
      id: installment.id,
      source: "legacy-debt",
      debtId: installment.debtId,
      financialCommitmentId: null,
      title: installment.debt.title,
      amount: installment.amount,
      dueDate: installment.dueDate,
      status: installment.status,
    };
  }

  private toFinancialDueMoneyItem(
    installment: DashboardFinancialInstallmentRecord,
    commitments: Map<string, DashboardFinancialCommitmentRecord>,
  ): DashboardDueMoneyItem {
    const commitment = commitments.get(installment.financialCommitmentId);
    return {
      id: installment.id,
      source: "financial-commitment",
      debtId: commitment?.legacyDebtId ?? null,
      financialCommitmentId: installment.financialCommitmentId,
      title: commitment?.title ?? "مستحق مالي",
      amount: installment.amount,
      dueDate: installment.dueDate,
      status: installment.status,
    };
  }

  private compareNullableDates(
    first: Date | null,
    second: Date | null,
  ): number {
    const firstTime = first?.getTime() ?? Number.MAX_SAFE_INTEGER;
    const secondTime = second?.getTime() ?? Number.MAX_SAFE_INTEGER;
    return firstTime - secondTime;
  }

  private isOpenInstallment(status: InstallmentStatus): boolean {
    return (
      status === InstallmentStatus.PENDING ||
      status === InstallmentStatus.OVERDUE
    );
  }

  private buildImportantItems({
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
          ? `${isOverdue ? "كان موعدها" : "موعدها"} ${this.formatDateArabic(
              task.dueDate,
            )}`
          : null,
        icon: "calendar",
        tone: isOverdue ? "danger" : this.toneForTaskPriority(task.priority),
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
      const routeTarget =
        installment.source === "financial-commitment"
          ? `/wedding-plans/${weddingPlanId}/finance`
          : `/debts/${installment.debtId}`;
      items.push({
        id: installment.id,
        type: "INSTALLMENT_DUE",
        title:
          installment.status === InstallmentStatus.OVERDUE
            ? "قسط متأخر"
            : "دفعة قادمة",
        subtitle: installment.title,
        body: [
          installment.dueDate
            ? this.formatDateArabic(installment.dueDate)
            : null,
          `${this.moneyOrNull(this.decimalToNumber(installment.amount))} ر.ي`,
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
          debtId: installment.debtId,
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
        this.setupAction(
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
        this.setupAction(
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
        this.setupAction(
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
        this.setupAction(
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

    return this.prioritizeImportantItems(items);
  }

  private toProviderPreviewResponse(
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

  private setupAction(
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

  private prioritizeImportantItems(
    items: DashboardImportantItemResponse[],
  ): DashboardImportantItemResponse[] {
    return selectTopDashboardActions(items);
  }

  private nextProviderAction(
    pending: number,
    received: number,
    accepted: number,
  ): string {
    if (received > 0) return "REVIEW_RECEIVED_QUOTES";
    if (pending > 0) return "WAIT_FOR_PROVIDER_RESPONSE";
    if (accepted > 0) return "MANAGE_ACCEPTED_PROVIDERS";
    return "REQUEST_FIRST_QUOTE";
  }

  private buildFinancialWarnings({
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
        amount: this.moneyOrNull(Math.abs(remainingBudget)),
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

  private toNotificationPreview(
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

  private async getMarketplaceSummary(userId: string) {
    const [featuredProvidersCount, favoriteProvidersCount, quoteRequestsCount] =
      await Promise.all([
        this.prisma.provider.count({
          where: { status: "ACTIVE", isFeatured: true },
        }),
        this.prisma.favoriteProvider.count({ where: { userId } }),
        this.prisma.quoteRequest.count({ where: { userId } }),
      ]);

    return {
      featuredProvidersCount,
      favoriteProvidersCount,
      quoteRequestsCount,
    };
  }

  private async getBudgetSummary(weddingPlanId: string) {
    const categories = await this.prisma.budgetCategory.findMany({
      where: { weddingPlanId },
    });
    const totalTargetAmount = categories.reduce(
      (sum, category) => sum + Number(category.targetAmount?.toString() ?? "0"),
      0,
    );

    return {
      categoriesCount: categories.length,
      totalTargetAmount: totalTargetAmount.toFixed(2),
    };
  }

  private async getExpensesSummary(weddingPlanId: string) {
    const expenses = await this.prisma.expense.findMany({
      where: { weddingPlanId },
    });
    const summary = {
      totalPlanned: 0,
      totalPaid: 0,
      totalCancelled: 0,
      countPlanned: 0,
      countPaid: 0,
      countCancelled: 0,
    };

    for (const expense of expenses) {
      const amount = Number(expense.amount.toString());
      if (expense.status === ExpenseStatus.PLANNED) {
        summary.totalPlanned += amount;
        summary.countPlanned++;
      }
      if (expense.status === ExpenseStatus.PAID) {
        summary.totalPaid += amount;
        summary.countPaid++;
      }
      if (expense.status === ExpenseStatus.CANCELLED) {
        summary.totalCancelled += amount;
        summary.countCancelled++;
      }
    }

    return {
      totalPlanned: summary.totalPlanned.toFixed(2),
      totalPaid: summary.totalPaid.toFixed(2),
      totalCancelled: summary.totalCancelled.toFixed(2),
      countPlanned: summary.countPlanned,
      countPaid: summary.countPaid,
      countCancelled: summary.countCancelled,
    };
  }

  private async getDebtsSummary(weddingPlanId: string) {
    const debts = await this.prisma.debt.findMany({ where: { weddingPlanId } });
    const summary = {
      totalDebt: 0,
      totalPaid: 0,
      countOpen: 0,
      countPartiallyPaid: 0,
      countPaid: 0,
      countCancelled: 0,
    };

    for (const debt of debts) {
      if (debt.status !== DebtStatus.CANCELLED) {
        summary.totalDebt += Number(debt.totalAmount.toString());
        summary.totalPaid += Number(debt.paidAmount.toString());
      }
      if (debt.status === DebtStatus.OPEN) summary.countOpen++;
      if (debt.status === DebtStatus.PARTIALLY_PAID)
        summary.countPartiallyPaid++;
      if (debt.status === DebtStatus.PAID) summary.countPaid++;
      if (debt.status === DebtStatus.CANCELLED) summary.countCancelled++;
    }

    return {
      totalDebt: summary.totalDebt.toFixed(2),
      totalPaid: summary.totalPaid.toFixed(2),
      remainingDebt: Math.max(summary.totalDebt - summary.totalPaid, 0).toFixed(
        2,
      ),
      countOpen: summary.countOpen,
      countPartiallyPaid: summary.countPartiallyPaid,
      countPaid: summary.countPaid,
      countCancelled: summary.countCancelled,
    };
  }

  private async getDueInstallments(weddingPlanId: string) {
    const installments = await this.prisma.installment.findMany({
      where: {
        debt: { weddingPlanId },
        status: { in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE] },
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      take: 5,
    });

    return installments.map((installment) => ({
      id: installment.id,
      debtId: installment.debtId,
      amount: installment.amount.toString(),
      dueDate: installment.dueDate,
      paidAt: installment.paidAt,
      status: installment.status,
      note: installment.note,
    }));
  }

  private async getUpcomingTasks(weddingPlanId: string) {
    const tasks = await this.prisma.weddingTask.findMany({
      where: {
        weddingPlanId,
        status: {
          notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
        },
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      take: 5,
    });

    return tasks.map((task) => ({
      id: task.id,
      weddingPlanId: task.weddingPlanId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      reminderAt: task.reminderAt,
      status: task.status,
      priority: task.priority,
    }));
  }

  private async getSharedMembers(weddingPlanId: string) {
    const members = await this.prisma.sharedMember.findMany({
      where: { weddingPlanId },
      include: { user: { select: { id: true, name: true, phone: true } } },
      orderBy: { createdAt: "asc" },
    });

    return members.map((member) => ({
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
      user: member.user,
      role: member.role,
      canViewBudget: member.canViewBudget,
      canViewExpenses: member.canViewExpenses,
      canViewDebts: member.canViewDebts,
      canEditPlan: member.canEditPlan,
      canManageTasks: member.canManageTasks,
      canManageGuests: member.canManageGuests,
      canManageProviders: member.canManageProviders,
      canInviteMembers: member.canInviteMembers,
      canManageFinancialRecords: member.canManageFinancialRecords,
      receiveNotifications: member.receiveNotifications,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    }));
  }

  private toneForTaskPriority(
    priority: WeddingTaskPriority,
  ): DashboardImportantItemResponse["tone"] {
    if (priority === WeddingTaskPriority.URGENT) return "danger";
    if (priority === WeddingTaskPriority.HIGH) return "warning";
    return "info";
  }

  private formatDateArabic(date: Date): string {
    const formatter = new Intl.DateTimeFormat("ar-YE", {
      day: "numeric",
      month: "long",
    });
    return formatter.format(date);
  }

  private toPlanResponse(plan: WeddingPlan) {
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

  private resolveBudgetTotal(
    plan: WeddingPlan,
    categories: { targetAmount: { toString(): string } | null }[],
  ): number {
    if (plan.estimatedBudget) {
      return this.decimalToNumber(plan.estimatedBudget);
    }

    return categories.reduce(
      (sum, category) => sum + this.decimalToNumber(category.targetAmount),
      0,
    );
  }

  private decimalToNumber(value: { toString(): string } | null): number {
    if (!value) return 0;
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private moneyOrNull(value: number | null): string | null {
    return value === null ? null : value.toFixed(2);
  }

  private startOfToday(): Date {
    return startOfRiyadhDay();
  }

  private endOfToday(today: Date): Date {
    return endOfRiyadhDay(today);
  }

  private daysRemaining(weddingDate: Date | null, today: Date): number | null {
    if (!weddingDate) return null;
    const weddingDay = new Date(
      weddingDate.getFullYear(),
      weddingDate.getMonth(),
      weddingDate.getDate(),
    );
    const millisecondsPerDay = 24 * 60 * 60 * 1000;
    return Math.ceil(
      (weddingDay.getTime() - today.getTime()) / millisecondsPerDay,
    );
  }

  private progressPercentage(
    totalTasks: number,
    completedTasks: number,
  ): number {
    if (totalTasks < 1) return 0;
    return Math.round((completedTasks / totalTasks) * 100);
  }

  private currentUserRole(
    context: PlanAccessContext,
  ): "OWNER" | SharedMemberRole | null {
    if (context.isOwner) return "OWNER";
    return context.sharedMember?.role ?? null;
  }

  private permissionSummary(
    context: PlanAccessContext,
  ): DashboardPermissionSummary {
    const role = this.currentUserRole(context);
    return {
      isOwner: context.isOwner,
      role,
      canViewBudget: this.permissions.canReadFinancial(context, "budget"),
      canViewExpenses: this.permissions.canReadFinancial(context, "expenses"),
      canViewDebts: this.permissions.canReadFinancial(context, "debts"),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canManageMembers: this.permissions.canManageMembers(context),
      canManageFinancialRecords:
        this.permissions.canManageFinancialRecords(context),
      canManagePlan: this.permissions.canManagePlan(context),
    };
  }
}
