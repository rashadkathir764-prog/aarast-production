import { Injectable } from '@nestjs/common';
import {
  ExpenseStatus,
  FinancialCommitmentStatus,
  GuestStatus,
  NotificationPriority,
  PlanProviderLinkStatus,
  ProviderStatus,
  QuoteRequestStatus,
  SharedMemberRole,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { endOfRiyadhDay, startOfRiyadhDay } from '../common/time/business-day';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';
import { weddingLocationResponse } from '../wedding-plans/wedding-location';
import {
  DashboardPermissionSummary,
  WeddingPlanDashboardSummaryResponse,
} from './dashboard.contracts';
import {
  buildFinancialWarnings,
  buildImportantItems,
  compareNullableDates,
  daysRemaining,
  decimalToNumber,
  isOpenInstallment,
  moneyOrNull,
  nextProviderAction,
  progressPercentage,
  resolveBudgetTotal,
  toFinancialDueMoneyItem,
  toNotificationPreview,
  toPlanResponse,
  toProviderPreviewResponse,
} from './dashboard-summary.presenter';

export type {
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  DashboardNotificationPreviewResponse,
  DashboardPermissionSummary,
  DashboardProviderPreviewResponse,
  WeddingPlanDashboardSummaryResponse,
} from './dashboard.contracts';

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
      orderBy: [{ weddingDate: 'asc' }, { createdAt: 'desc' }],
    });

    const [marketplaceSummary, budgetSummary, expensesSummary, upcomingTasks, sharedMembers] =
      await Promise.all([
        this.getMarketplaceSummary(currentUser.id),
        currentWeddingPlan ? this.getBudgetSummary(currentWeddingPlan.id) : Promise.resolve(null),
        currentWeddingPlan ? this.getExpensesSummary(currentWeddingPlan.id) : Promise.resolve(null),
        currentWeddingPlan ? this.getUpcomingTasks(currentWeddingPlan.id) : Promise.resolve([]),
        currentWeddingPlan ? this.getSharedMembers(currentWeddingPlan.id) : Promise.resolve([]),
      ]);

    return {
      currentWeddingPlan: currentWeddingPlan ? toPlanResponse(currentWeddingPlan) : null,
      budgetSummary,
      expensesSummary,
      upcomingTasks,
      sharedMembers,
      marketplaceSummary,
    };
  }

  async getWeddingPlanDashboardSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanDashboardSummaryResponse> {
    const context = await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const today = this.startOfToday();
    const endOfToday = this.endOfToday(today);
    const canViewBudget = this.permissions.canReadFinancial(context, 'budget');
    const canViewExpenses = this.permissions.canReadFinancial(context, 'expenses');
    const canViewFinancialRecords = this.permissions.canReadFinancial(context, 'financialRecords');

    const [
      budgetCategories,
      expenses,
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
      canViewFinancialRecords
        ? this.prisma.financialCommitment.findMany({
            where: { weddingPlanId },
          })
        : Promise.resolve([]),
      canViewFinancialRecords
        ? this.prisma.financialInstallment.findMany({
            where: { weddingPlanId },
            orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
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
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
        take: 2,
      }),
      this.prisma.weddingTask.findFirst({
        where: {
          weddingPlanId,
          status: {
            notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
          },
        },
        orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
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
          OR: [{ phone: null }, { phone: '' }, { name: '' }],
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
                orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
                take: 1,
                include: {
                  images: {
                    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
                    take: 1,
                  },
                },
              },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
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
        orderBy: { createdAt: 'desc' },
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
        orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      }),
    ]);

    const activeFinancialCommitments = financialCommitments.filter(
      (commitment) => commitment.status !== FinancialCommitmentStatus.CANCELLED,
    );
    const commitmentById = new Map(
      financialCommitments.map((commitment) => [commitment.id, commitment]),
    );
    const openFinancialInstallments = financialInstallments.filter((installment) =>
      isOpenInstallment(installment.status),
    );
    const financialDueInstallmentItems = openFinancialInstallments
      .filter((installment) => installment.dueDate !== null && installment.dueDate <= endOfToday)
      .map((installment) => toFinancialDueMoneyItem(installment, commitmentById));
    const dueMoneyItems = [...financialDueInstallmentItems]
      .sort((a, b) => compareNullableDates(a.dueDate, b.dueDate))
      .slice(0, 2);
    const nextMoneyInstallment = openFinancialInstallments[0]
      ? toFinancialDueMoneyItem(openFinancialInstallments[0], commitmentById)
      : null;
    const effectiveDueInstallmentsCount = canViewFinancialRecords
      ? financialDueInstallmentItems.length
      : null;

    const budgetTotalNumber = canViewBudget
      ? resolveBudgetTotal(context.plan, budgetCategories)
      : null;
    const spentTotalNumber = canViewExpenses
      ? expenses.reduce((sum, expense) => {
          if (expense.status !== ExpenseStatus.PAID) return sum;
          return sum + decimalToNumber(expense.amount);
        }, 0)
      : null;
    const commitmentTotalNumber = canViewFinancialRecords
      ? activeFinancialCommitments.reduce(
          (sum, commitment) => sum + decimalToNumber(commitment.totalAmount),
          0,
        )
      : null;
    const commitmentPaidTotalNumber = canViewFinancialRecords
      ? activeFinancialCommitments.reduce(
          (sum, commitment) => sum + decimalToNumber(commitment.paidAmount),
          0,
        )
      : null;
    const confirmedCostNumber =
      spentTotalNumber !== null && commitmentTotalNumber !== null
        ? spentTotalNumber + commitmentTotalNumber
        : (spentTotalNumber ?? commitmentTotalNumber);
    const remainingBudgetNumber =
      budgetTotalNumber !== null && confirmedCostNumber !== null
        ? budgetTotalNumber - confirmedCostNumber
        : null;
    const commitmentOutstandingTotalNumber =
      commitmentTotalNumber !== null && commitmentPaidTotalNumber !== null
        ? Math.max(commitmentTotalNumber - commitmentPaidTotalNumber, 0)
        : null;
    const location = weddingLocationResponse(context.plan.location, context.plan.city);
    const nextProviderActionValue = nextProviderAction(
      pendingQuoteRequests,
      receivedQuotes,
      providerCount,
    );
    const financialWarnings = buildFinancialWarnings({
      remainingBudget: remainingBudgetNumber,
      dueInstallmentsCount: effectiveDueInstallmentsCount,
    });
    const importantItems = buildImportantItems({
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
      toNotificationPreview(notification),
    );

    return {
      dataScope: 'ACCOUNT_BACKED',
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
      spentTotal: moneyOrNull(spentTotalNumber),
      remainingBudget: moneyOrNull(remainingBudgetNumber),
      commitmentTotal: moneyOrNull(commitmentTotalNumber),
      commitmentPaidTotal: moneyOrNull(commitmentPaidTotalNumber),
      commitmentOutstandingTotal: moneyOrNull(commitmentOutstandingTotalNumber),
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
      nextProviderAction: nextProviderActionValue,
      participantCount: participantMembersCount + 1,
      pendingInvites,
      unreadNotificationsCount,
      highPriorityNotificationsCount,
      importantItems,
      nextBestActions: importantItems,
      planProviders: planProviderLinks.map((link) => toProviderPreviewResponse(link)),
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
      nextInstallmentDue: nextMoneyInstallment
        ? {
            id: nextMoneyInstallment.id,
            financialCommitmentId: nextMoneyInstallment.financialCommitmentId,
            amount: nextMoneyInstallment.amount.toString(),
            dueAt: nextMoneyInstallment.dueDate,
            status: nextMoneyInstallment.status,
          }
        : null,
      moneySummary: {
        totalBudget: moneyOrNull(budgetTotalNumber),
        totalSpent: moneyOrNull(spentTotalNumber),
        remainingBudget: moneyOrNull(remainingBudgetNumber),
        totalCommitments: moneyOrNull(commitmentTotalNumber),
        overBudget: remainingBudgetNumber === null ? null : remainingBudgetNumber < 0,
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
    const [featuredProvidersCount, favoriteProvidersCount, quoteRequestsCount] = await Promise.all([
      this.prisma.provider.count({
        where: { status: 'ACTIVE', isFeatured: true },
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
      (sum, category) => sum + Number(category.targetAmount?.toString() ?? '0'),
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

  private async getUpcomingTasks(weddingPlanId: string) {
    const tasks = await this.prisma.weddingTask.findMany({
      where: {
        weddingPlanId,
        status: {
          notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
        },
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
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
      orderBy: { createdAt: 'asc' },
    });

    return members.map((member) => ({
      id: member.id,
      weddingPlanId: member.weddingPlanId,
      userId: member.userId,
      user: member.user,
      role: member.role,
      canViewBudget: member.canViewBudget,
      canViewExpenses: member.canViewExpenses,
      canViewFinancialRecords: member.canViewFinancialRecords,
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

  private startOfToday(): Date {
    return startOfRiyadhDay();
  }

  private endOfToday(today: Date): Date {
    return endOfRiyadhDay(today);
  }

  private currentUserRole(context: PlanAccessContext): 'OWNER' | SharedMemberRole | null {
    if (context.isOwner) return 'OWNER';
    return context.sharedMember?.role ?? null;
  }

  private permissionSummary(context: PlanAccessContext): DashboardPermissionSummary {
    const role = this.currentUserRole(context);
    return {
      isOwner: context.isOwner,
      role,
      canViewBudget: this.permissions.canReadFinancial(context, 'budget'),
      canViewExpenses: this.permissions.canReadFinancial(context, 'expenses'),
      canViewFinancialRecords: this.permissions.canReadFinancial(context, 'financialRecords'),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageGuests: this.permissions.canManageGuests(context),
      canManageProviders: this.permissions.canManageProviders(context),
      canManageMembers: this.permissions.canManageMembers(context),
      canManageFinancialRecords: this.permissions.canManageFinancialRecords(context),
      canManagePlan: this.permissions.canManagePlan(context),
    };
  }
}
