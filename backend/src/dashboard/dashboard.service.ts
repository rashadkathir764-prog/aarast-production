import { Injectable } from "@nestjs/common";
import {
  GuestStatus,
  NotificationPriority,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  ProviderStatus,
  QuoteRequestStatus,
  SharedMemberRole,
  WeddingCostStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { endOfRiyadhDay, startOfRiyadhDay } from "../common/time/business-day";
import { PrismaService } from "../prisma/prisma.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";
import { weddingLocationResponse } from "../wedding-plans/wedding-location";
import {
  applicationNameFields,
  toApplicationUserContact,
} from "../users/application-user-identity";
import {
  DashboardPermissionSummary,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import {
  buildFinancialWarnings,
  buildImportantItems,
  compareDates,
  daysRemaining,
  decimalToNumber,
  moneyOrNull,
  nextProviderAction,
  progressPercentage,
  resolveBudgetTotal,
  toPaymentScheduleDueMoneyItem,
  toNotificationPreview,
  toPlanResponse,
  toProviderPreviewResponse,
} from "./dashboard-summary.presenter";

export type {
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  DashboardNotificationPreviewResponse,
  DashboardPermissionSummary,
  DashboardProviderPreviewResponse,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";

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

    const [marketplaceSummary, moneySummary, upcomingTasks, sharedMembers] =
      await Promise.all([
        this.getMarketplaceSummary(currentUser.id),
        currentWeddingPlan
          ? this.getMoneyHomeSummary(currentWeddingPlan.id)
          : Promise.resolve(null),
        currentWeddingPlan
          ? this.getUpcomingTasks(currentWeddingPlan.id)
          : Promise.resolve([]),
        currentWeddingPlan
          ? this.getSharedMembers(currentWeddingPlan.id)
          : Promise.resolve([]),
      ]);

    return {
      currentWeddingPlan: currentWeddingPlan
        ? toPlanResponse(currentWeddingPlan)
        : null,
      moneySummary,
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
    const dueSoonEnd = new Date(endOfToday.getTime() + 7 * 86_400_000);
    const canViewMoney = this.permissions.canViewMoney(context);

    const [
      costs,
      paymentSchedules,
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
      canViewMoney
        ? this.prisma.weddingCost.findMany({
            where: {
              weddingPlanId,
              status: { not: WeddingCostStatus.CANCELLED },
            },
            select: { id: true, totalAmount: true, paidAmount: true },
          })
        : Promise.resolve([]),
      canViewMoney
        ? this.prisma.paymentSchedule.findMany({
            where: {
              status: PaymentScheduleStatus.PENDING,
              weddingCost: {
                weddingPlanId,
                status: { not: WeddingCostStatus.CANCELLED },
              },
            },
            include: { weddingCost: { select: { title: true } } },
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

    const dueSoonSchedules = paymentSchedules.filter(
      (schedule) => schedule.dueDate >= today && schedule.dueDate <= dueSoonEnd,
    );
    const overdueSchedules = paymentSchedules.filter(
      (schedule) => schedule.dueDate < today,
    );
    const actionableSchedules = paymentSchedules
      .filter((schedule) => schedule.dueDate <= dueSoonEnd)
      .map(toPaymentScheduleDueMoneyItem)
      .sort((a, b) => compareDates(a.dueDate, b.dueDate));
    const dueMoneyItems = actionableSchedules.slice(0, 2);
    const nextPaymentSchedule = paymentSchedules[0]
      ? toPaymentScheduleDueMoneyItem(paymentSchedules[0])
      : null;
    const effectiveDuePaymentSchedulesCount = canViewMoney
      ? actionableSchedules.length
      : null;

    const budgetTotalNumber = canViewMoney
      ? resolveBudgetTotal(context.plan)
      : null;
    const confirmedCostNumber = canViewMoney
      ? costs.reduce((sum, cost) => sum + decimalToNumber(cost.totalAmount), 0)
      : null;
    const paidNumber = canViewMoney
      ? costs.reduce((sum, cost) => sum + decimalToNumber(cost.paidAmount), 0)
      : null;
    const outstandingNumber =
      confirmedCostNumber !== null && paidNumber !== null
        ? confirmedCostNumber - paidNumber
        : null;
    const remainingBudgetNumber =
      budgetTotalNumber !== null && confirmedCostNumber !== null
        ? budgetTotalNumber - confirmedCostNumber
        : null;
    const location = weddingLocationResponse(
      context.plan.location,
      context.plan.city,
    );
    const nextProviderActionValue = nextProviderAction(
      pendingQuoteRequests,
      receivedQuotes,
      providerCount,
    );
    const financialWarnings = buildFinancialWarnings({
      remainingBudget: remainingBudgetNumber,
      overdueCount: canViewMoney ? overdueSchedules.length : null,
      dueSoonCount: canViewMoney ? dueSoonSchedules.length : null,
    });
    const importantItems = buildImportantItems({
      weddingPlanId,
      tasks: urgentTasks,
      paymentSchedules: dueMoneyItems,
      providers: planProviderLinks,
      today,
      receivedQuotes,
      pendingInvites,
      hasLocation: location !== null,
      hasBudget: budgetTotalNumber !== null && budgetTotalNumber > 0,
      guestCount,
      quoteRequestsCount,
      acceptedProviders: providerCount,
      currency: context.plan.currency,
    });
    const currentUserRole = this.currentUserRole(context);
    const notificationPreviews = latestNotifications.map((notification) =>
      toNotificationPreview(notification),
    );

    return {
      dataScope: "ACCOUNT_BACKED",
      accountBacked: true,
      planId: context.plan.id,
      title: context.plan.title,
      currency: context.plan.currency,
      weddingDate: context.plan.weddingDate,
      city: context.plan.city,
      location,
      status: context.plan.status,
      daysRemaining: daysRemaining(context.plan.weddingDate, today),
      progressPercentage: progressPercentage(totalTasks, completedTasks),
      budgetTotal: moneyOrNull(budgetTotalNumber),
      confirmedCostTotal: moneyOrNull(confirmedCostNumber),
      paidTotal: moneyOrNull(paidNumber),
      outstandingTotal: moneyOrNull(outstandingNumber),
      remainingBudget: moneyOrNull(remainingBudgetNumber),
      duePaymentSchedulesCount: effectiveDuePaymentSchedulesCount,
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
      nextProviderAction: nextProviderActionValue,
      participantCount: participantMembersCount + 1,
      pendingInvites,
      unreadNotificationsCount,
      highPriorityNotificationsCount,
      importantItems,
      nextBestActions: importantItems,
      planProviders: planProviderLinks.map((link) =>
        toProviderPreviewResponse(link),
      ),
      importantNotifications: notificationPreviews,
      latestImportantNotification: latestImportantNotification
        ? toNotificationPreview(latestImportantNotification)
        : null,
      nextTask: nextTask
        ? {
            id: nextTask.id,
            title: nextTask.title,
            dueAt: nextTask.dueDate,
            status: nextTask.status,
          }
        : null,
      nextPaymentScheduleDue: nextPaymentSchedule
        ? {
            id: nextPaymentSchedule.id,
            weddingCostId: nextPaymentSchedule.weddingCostId,
            title: nextPaymentSchedule.title,
            amount: nextPaymentSchedule.amount.toString(),
            dueDate: nextPaymentSchedule.dueDate,
            status: nextPaymentSchedule.status,
          }
        : null,
      moneySummary: {
        totalBudget: moneyOrNull(budgetTotalNumber),
        confirmedCost: moneyOrNull(confirmedCostNumber),
        paid: moneyOrNull(paidNumber),
        outstanding: moneyOrNull(outstandingNumber),
        remainingBudget: moneyOrNull(remainingBudgetNumber),
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
        nextAction: nextProviderActionValue,
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

  private async getMoneyHomeSummary(weddingPlanId: string) {
    const [plan, costs] = await Promise.all([
      this.prisma.weddingPlan.findUniqueOrThrow({
        where: { id: weddingPlanId },
        select: { estimatedBudget: true, currency: true },
      }),
      this.prisma.weddingCost.findMany({
        where: {
          weddingPlanId,
          status: { not: WeddingCostStatus.CANCELLED },
        },
        select: { totalAmount: true, paidAmount: true },
      }),
    ]);
    const confirmedCost = costs.reduce(
      (sum, cost) => sum + decimalToNumber(cost.totalAmount),
      0,
    );
    const paid = costs.reduce(
      (sum, cost) => sum + decimalToNumber(cost.paidAmount),
      0,
    );
    const totalBudget = plan.estimatedBudget
      ? decimalToNumber(plan.estimatedBudget)
      : null;
    return {
      currency: plan.currency,
      totalBudget: moneyOrNull(totalBudget),
      confirmedCost: moneyOrNull(confirmedCost),
      paid: moneyOrNull(paid),
      outstanding: moneyOrNull(confirmedCost - paid),
      remainingBudget:
        totalBudget === null ? null : moneyOrNull(totalBudget - confirmedCost),
      costsCount: costs.length,
    };
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
      include: {
        user: {
          select: { id: true, phone: true, ...applicationNameFields },
        },
      },
      orderBy: { createdAt: "asc" },
    });

    return members.map((member) => ({
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
      user: toApplicationUserContact(member.user),
      role: member.role,
      canViewMoney: member.canViewMoney || member.canManageMoney,
      canEditPlan: member.canEditPlan,
      canManageTasks: member.canManageTasks,
      canManageGuests: member.canManageGuests,
      canManageProviders: member.canManageProviders,
      canInviteMembers: member.canInviteMembers,
      canManageMoney: member.canManageMoney,
      receiveNotifications: member.receiveNotifications,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    }));
  }

  private startOfToday(): Date {
    return startOfRiyadhDay();
  }

  private endOfToday(today: Date): Date {
    return endOfRiyadhDay(today);
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
      canViewMoney: this.permissions.canViewMoney(context),
      canManageMoney: this.permissions.canManageMoney(context),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canManageMembers: this.permissions.canManageMembers(context),
      canManagePlan: this.permissions.canManagePlan(context),
    };
  }
}
