import { Inject, Injectable } from "@nestjs/common";
import {
  GuestStatus,
  NotificationPriority,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  ProviderStatus,
  QuoteRequestStatus,
  Prisma,
  SharedMemberRole,
  WeddingCostStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import type { ContributionHistorySummaryResponse } from "../modules/collaboration/public/collaboration-history.port";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { runRetryableTransaction } from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../shared-kernel/time/business-day";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import { weddingLocationResponse } from "../modules/planning/public/wedding-location";
import {
  DashboardPermissionSummary,
  WeddingPlanDashboardSummaryResponse,
} from "./dashboard.contracts";
import {
  dashboardTaskVisibilityWhere,
  resolveDashboardContributorDataScope,
} from "./dashboard-contributor-scope";
import { loadDashboardHomeSections } from "./dashboard-home-queries";
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
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope?: ContributorScopeService,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory?: ContributionHistoryService,
  ) {}

  async getHome(currentUser: AuthenticatedUser) {
    const currentWeddingPlan = await this.prisma.weddingPlan.findFirst({
      where: {
        ownerUserId: currentUser.id,
        status: WeddingPlanStatus.PLANNING,
      },
      orderBy: [{ weddingDate: "asc" }, { createdAt: "desc" }],
    });

    const sections = await loadDashboardHomeSections(
      this.prisma,
      currentUser.id,
      currentWeddingPlan?.id ?? null,
    );

    return {
      currentWeddingPlan: currentWeddingPlan
        ? toPlanResponse(currentWeddingPlan)
        : null,
      ...sections,
    };
  }

  async getWeddingPlanDashboardSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse> {
    return runRetryableTransaction(
      this.prisma,
      (tx) =>
        this.getWeddingPlanDashboardSummaryInTransaction(
          tx,
          currentUser,
          weddingPlanId,
        ),
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  private async getWeddingPlanDashboardSummaryInTransaction(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse> {
    const context = await this.permissions.assertPlanReadableInTransaction(
      tx,
      weddingPlanId,
      currentUser,
    );
    const today = startOfRiyadhDay();
    const endOfToday = endOfRiyadhDay(today);
    const dueSoonEnd = new Date(endOfToday.getTime() + 7 * 86_400_000);
    const canViewMoney = this.permissions.canViewMoney(context);
    const contributorIds = context.isOwner
      ? null
      : await resolveDashboardContributorDataScope({
          tx,
          context,
          weddingPlanId,
          actorUserId: currentUser.id,
          canViewMoney,
          contributorScope: this.requiredContributorScope(),
        });
    const taskVisibilityWhere = dashboardTaskVisibilityWhere(
      contributorIds,
      currentUser.id,
    );
    const notificationVisibility =
      await this.notifications.visibilityWhereForUser(currentUser.id, tx);
    const notificationWhere = {
      userId: currentUser.id,
      weddingPlanId,
      archivedAt: null,
      ...(notificationVisibility ? { AND: notificationVisibility } : {}),
    };

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
        ? tx.weddingCost.findMany({
            where: {
              weddingPlanId,
              ...(contributorIds ? { id: { in: contributorIds.costIds } } : {}),
              status: { not: WeddingCostStatus.CANCELLED },
            },
            select: { id: true, totalAmount: true, paidAmount: true },
          })
        : Promise.resolve([]),
      canViewMoney
        ? tx.paymentSchedule.findMany({
            where: {
              status: PaymentScheduleStatus.PENDING,
              weddingCost: {
                weddingPlanId,
                ...(contributorIds
                  ? { id: { in: contributorIds.costIds } }
                  : {}),
                status: { not: WeddingCostStatus.CANCELLED },
              },
            },
            include: { weddingCost: { select: { title: true } } },
            orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
          })
        : Promise.resolve([]),
      tx.weddingTask.findMany({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          dueDate: { lte: endOfToday },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        take: 2,
      }),
      tx.weddingTask.findFirst({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      }),
      tx.weddingTask.count({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
        },
      }),
      tx.weddingTask.count({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          status: WeddingTaskStatus.DONE,
        },
      }),
      tx.weddingTask.count({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          status: {
            in: [WeddingTaskStatus.TODO, WeddingTaskStatus.IN_PROGRESS],
          },
        },
      }),
      tx.weddingTask.count({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          dueDate: { lt: today },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
      }),
      tx.weddingTask.count({
        where: {
          weddingPlanId,
          ...taskVisibilityWhere,
          dueDate: { gte: today, lte: endOfToday },
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
      }),
      tx.guest.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.guestIds } } : {}),
        },
      }),
      tx.guest.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.guestIds } } : {}),
          status: GuestStatus.CONFIRMED,
        },
      }),
      tx.guest.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.guestIds } } : {}),
          status: { in: [GuestStatus.PENDING, GuestStatus.INVITED] },
        },
      }),
      tx.guest.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.guestIds } } : {}),
          status: GuestStatus.DECLINED,
        },
      }),
      tx.guest.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.guestIds } } : {}),
          OR: [{ phone: null }, { phone: "" }, { name: "" }],
        },
      }),
      tx.planProviderLink.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { quoteRequestId: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
          status: PlanProviderLinkStatus.ACTIVE,
          provider: { status: ProviderStatus.ACTIVE },
        },
      }),
      tx.planProviderLink.findMany({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { quoteRequestId: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
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
      tx.quoteRequest.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { id: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
        },
      }),
      tx.quoteRequest.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { id: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
          status: {
            in: [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED],
          },
        },
      }),
      tx.quoteRequest.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { id: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
          status: QuoteRequestStatus.RESPONDED,
        },
      }),
      tx.quoteRequest.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { id: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
          status: QuoteRequestStatus.ACCEPTED,
        },
      }),
      tx.quoteRequest.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? contributorIds.providersEnabled
              ? { id: { in: contributorIds.quoteIds } }
              : { id: { in: [] as string[] } }
            : {}),
          status: {
            in: [QuoteRequestStatus.REJECTED, QuoteRequestStatus.CANCELLED],
          },
        },
      }),
      tx.sharedMember.count({
        where: {
          weddingPlanId,
          ...(contributorIds
            ? {
                OR: [
                  { userId: currentUser.id },
                  { id: { in: contributorIds.memberIds } },
                ],
              }
            : {}),
        },
      }),
      tx.planInvite.count({
        where: {
          weddingPlanId,
          ...(contributorIds ? { id: { in: contributorIds.inviteIds } } : {}),
          acceptedAt: null,
          declinedAt: null,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
      }),
      tx.notification.count({
        where: {
          ...notificationWhere,
          readAt: null,
        },
      }),
      tx.notification.count({
        where: {
          ...notificationWhere,
          priority: {
            in: [NotificationPriority.HIGH, NotificationPriority.URGENT],
          },
        },
      }),
      tx.notification.findMany({
        where: notificationWhere,
        orderBy: { createdAt: "desc" },
        take: 3,
      }),
      tx.notification.findFirst({
        where: {
          ...notificationWhere,
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

    const budgetTotalNumber =
      canViewMoney && context.isOwner ? resolveBudgetTotal(context.plan) : null;
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
      // A contributor must not learn whether the owner configured a plan-wide
      // budget, nor receive a misleading SET_BUDGET action for a value they
      // are not allowed to inspect.
      hasBudget:
        !context.isOwner ||
        (budgetTotalNumber !== null && budgetTotalNumber > 0),
      guestCount,
      quoteRequestsCount,
      acceptedProviders: providerCount,
      currency: context.plan.currency,
    });
    const currentUserRole = this.currentUserRole(context);
    const notificationPreviews = latestNotifications.map((notification) =>
      toNotificationPreview(notification),
    );
    const contributionHistory: ContributionHistorySummaryResponse | null =
      context.isOwner
        ? null
        : await this.requiredContributionHistory().summary(
            currentUser,
            weddingPlanId,
          );

    return {
      dataScope: "ACCOUNT_BACKED",
      accountBacked: true,
      planId: context.plan.id,
      membershipId: context.sharedMember?.id ?? null,
      membershipAuthorityVersion:
        context.sharedMember?.authorityVersion ?? null,
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
      contributionHistory,
    };
  }

  private requiredContributorScope(): ContributorScopeService {
    if (!this.contributorScope) {
      throw new Error(
        "ContributorScopeService is required for contributor dashboard access",
      );
    }
    return this.contributorScope;
  }

  private requiredContributionHistory(): ContributionHistoryService {
    if (!this.contributionHistory) {
      throw new Error(
        "ContributionHistoryService is required for contributor dashboard access",
      );
    }
    return this.contributionHistory;
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
