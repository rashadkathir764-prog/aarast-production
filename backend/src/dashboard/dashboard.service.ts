import { Injectable } from '@nestjs/common';
import {
  DebtStatus,
  ExpenseStatus,
  GuestStatus,
  InstallmentStatus,
  NotificationType,
  PlanProviderLinkStatus,
  Prisma,
  ProviderStatus,
  SharedMemberRole,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';

export interface DashboardPermissionSummary {
  isOwner: boolean;
  role: 'OWNER' | SharedMemberRole | null;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewDebts: boolean;
  canManageTasks: boolean;
  canManageFinancialRecords: boolean;
  canManagePlan: boolean;
}

export interface WeddingPlanDashboardSummaryResponse {
  planId: string;
  title: string;
  weddingDate: Date | null;
  city: string | null;
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
  providerCount: number;
  quoteRequestsCount: number;
  unreadNotificationsCount: number;
  importantItems: DashboardImportantItemResponse[];
  planProviders: DashboardProviderPreviewResponse[];
  importantNotifications: DashboardNotificationPreviewResponse[];
  generatedAt: Date;
  currentUserRole: 'OWNER' | SharedMemberRole | null;
  permissions: DashboardPermissionSummary;
}

export type DashboardImportantItemType =
  | 'TASK_OVERDUE'
  | 'TASK_TODAY'
  | 'INSTALLMENT_DUE'
  | 'PLAN_PROVIDER';

export interface DashboardImportantItemResponse {
  id: string;
  type: DashboardImportantItemType;
  title: string;
  subtitle: string;
  body: string | null;
  icon: 'calendar' | 'wallet' | 'provider';
  tone: 'danger' | 'warning' | 'success' | 'info';
  actionLabel: string;
  dueDate: Date | null;
  amount: string | null;
  route: string | null;
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
  title: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
  data: Prisma.JsonValue | null;
}

type DashboardTaskRecord = Prisma.WeddingTaskGetPayload<object>;
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
      orderBy: [{ weddingDate: 'asc' }, { createdAt: 'desc' }],
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
    const canViewBudget = this.permissions.canReadFinancial(context, 'budget');
    const canViewExpenses = this.permissions.canReadFinancial(context, 'expenses');
    const canViewDebts = this.permissions.canReadFinancial(context, 'debts');

    const [
      budgetCategories,
      expenses,
      debts,
      dueInstallmentsCount,
      dueInstallments,
      urgentTasks,
      totalTasks,
      completedTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      providerCount,
      planProviderLinks,
      quoteRequestsCount,
      unreadNotificationsCount,
      latestNotifications,
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
            orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
            take: 2,
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
      this.prisma.weddingTask.count({ where: { weddingPlanId } }),
      this.prisma.weddingTask.count({
        where: { weddingPlanId, status: WeddingTaskStatus.DONE },
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
      this.prisma.planProviderLink.count({ where: { weddingPlanId } }),
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
      this.prisma.notification.count({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          readAt: null,
        },
      }),
      this.prisma.notification.findMany({
        where: {
          userId: currentUser.id,
          weddingPlanId,
        },
        orderBy: { createdAt: 'desc' },
        take: 3,
      }),
    ]);

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
      ? debts.reduce(
          (sum, debt) => sum + this.decimalToNumber(debt.totalAmount),
          0,
        )
      : null;
    const paidDebtTotalNumber = canViewDebts
      ? debts.reduce(
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

    return {
      planId: context.plan.id,
      title: context.plan.title,
      weddingDate: context.plan.weddingDate,
      city: context.plan.city,
      status: context.plan.status,
      daysRemaining: this.daysRemaining(context.plan.weddingDate, today),
      progressPercentage: this.progressPercentage(totalTasks, completedTasks),
      budgetTotal: this.moneyOrNull(budgetTotalNumber),
      spentTotal: this.moneyOrNull(spentTotalNumber),
      remainingBudget: this.moneyOrNull(remainingBudgetNumber),
      debtTotal: this.moneyOrNull(debtTotalNumber),
      paidDebtTotal: this.moneyOrNull(paidDebtTotalNumber),
      unpaidDebtTotal: this.moneyOrNull(unpaidDebtTotalNumber),
      dueInstallmentsCount,
      totalTasks,
      completedTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      providerCount,
      quoteRequestsCount,
      unreadNotificationsCount,
      importantItems: this.buildImportantItems({
        weddingPlanId,
        tasks: urgentTasks,
        installments: dueInstallments,
        providers: planProviderLinks,
        today,
      }),
      planProviders: planProviderLinks.map((link) =>
        this.toProviderPreviewResponse(link),
      ),
      importantNotifications: latestNotifications.map((notification) => ({
        id: notification.id,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        readAt: notification.readAt,
        createdAt: notification.createdAt,
        data: notification.data,
      })),
      generatedAt: new Date(),
      currentUserRole: this.currentUserRole(context),
      permissions: this.permissionSummary(context),
    };
  }

  private buildImportantItems({
    weddingPlanId,
    tasks,
    installments,
    providers,
    today,
  }: {
    weddingPlanId: string;
    tasks: DashboardTaskRecord[];
    installments: DashboardInstallmentRecord[];
    providers: DashboardPlanProviderLinkRecord[];
    today: Date;
  }): DashboardImportantItemResponse[] {
    const items: DashboardImportantItemResponse[] = [];

    for (const task of tasks) {
      const isOverdue = task.dueDate !== null && task.dueDate < today;
      items.push({
        id: task.id,
        type: isOverdue ? 'TASK_OVERDUE' : 'TASK_TODAY',
        title: isOverdue ? 'مهمة متأخرة' : 'مهمة اليوم',
        subtitle: task.title,
        body: task.dueDate
          ? `${isOverdue ? 'كان موعدها' : 'موعدها'} ${this.formatDateArabic(
              task.dueDate,
            )}`
          : null,
        icon: 'calendar',
        tone: isOverdue ? 'danger' : this.toneForTaskPriority(task.priority),
        actionLabel: 'تنفيذ الآن',
        dueDate: task.dueDate,
        amount: null,
        route: `/wedding-plans/${weddingPlanId}/tasks`,
        data: {
          weddingPlanId,
          taskId: task.id,
        },
      });
    }

    for (const installment of installments) {
      items.push({
        id: installment.id,
        type: 'INSTALLMENT_DUE',
        title:
          installment.status === InstallmentStatus.OVERDUE
            ? 'قسط متأخر'
            : 'دفعة قادمة',
        subtitle: installment.debt.title,
        body: [
          installment.dueDate
            ? this.formatDateArabic(installment.dueDate)
            : null,
          `${this.moneyOrNull(this.decimalToNumber(installment.amount))} ر.ي`,
        ]
          .filter((part): part is string => Boolean(part))
          .join(' · '),
        icon: 'wallet',
        tone:
          installment.status === InstallmentStatus.OVERDUE
            ? 'danger'
            : 'warning',
        actionLabel: 'عرض التفاصيل',
        dueDate: installment.dueDate,
        amount: installment.amount.toString(),
        route: `/debts/${installment.debtId}`,
        data: {
          weddingPlanId,
          debtId: installment.debtId,
          installmentId: installment.id,
        },
      });
    }

    const firstProvider = providers[0];
    if (firstProvider) {
      const provider = firstProvider.provider;
      items.push({
        id: firstProvider.id,
        type: 'PLAN_PROVIDER',
        title: 'مزود قريب منك',
        subtitle: provider.businessName,
        body: [
          provider.primaryCategory?.nameAr ?? null,
          Number(provider.ratingAverage) > 0
            ? `تقييم ${provider.ratingAverage.toString()}`
            : null,
        ]
          .filter((part): part is string => Boolean(part))
          .join(' · '),
        icon: 'provider',
        tone: 'success',
        actionLabel: 'عرض الملف',
        dueDate: null,
        amount: null,
        route: `/providers/${provider.id}`,
        data: {
          weddingPlanId,
          providerId: provider.id,
          planProviderLinkId: firstProvider.id,
        },
      });
    }

    return items.slice(0, 3);
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

  private async getMarketplaceSummary(userId: string) {
    const [
      featuredProvidersCount,
      favoriteProvidersCount,
      quoteRequestsCount,
    ] = await Promise.all([
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
      (sum, category) =>
        sum + Number(category.targetAmount?.toString() ?? '0'),
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
      if (debt.status === DebtStatus.PARTIALLY_PAID) summary.countPartiallyPaid++;
      if (debt.status === DebtStatus.PAID) summary.countPaid++;
      if (debt.status === DebtStatus.CANCELLED) summary.countCancelled++;
    }

    return {
      totalDebt: summary.totalDebt.toFixed(2),
      totalPaid: summary.totalPaid.toFixed(2),
      remainingDebt: Math.max(summary.totalDebt - summary.totalPaid, 0).toFixed(2),
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
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
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
        status: { notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED] },
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
      canViewDebts: member.canViewDebts,
      canManageTasks: member.canManageTasks,
      canManageFinancialRecords: member.canManageFinancialRecords,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    }));
  }

  private toneForTaskPriority(
    priority: WeddingTaskPriority,
  ): DashboardImportantItemResponse['tone'] {
    if (priority === WeddingTaskPriority.URGENT) return 'danger';
    if (priority === WeddingTaskPriority.HIGH) return 'warning';
    return 'info';
  }

  private formatDateArabic(date: Date): string {
    const formatter = new Intl.DateTimeFormat('ar-YE', {
      day: 'numeric',
      month: 'long',
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
      (sum, category) =>
        sum + this.decimalToNumber(category.targetAmount),
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
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  private endOfToday(today: Date): Date {
    const end = new Date(today);
    end.setHours(23, 59, 59, 999);
    return end;
  }

  private daysRemaining(weddingDate: Date | null, today: Date): number | null {
    if (!weddingDate) return null;
    const weddingDay = new Date(
      weddingDate.getFullYear(),
      weddingDate.getMonth(),
      weddingDate.getDate(),
    );
    const millisecondsPerDay = 24 * 60 * 60 * 1000;
    return Math.ceil((weddingDay.getTime() - today.getTime()) / millisecondsPerDay);
  }

  private progressPercentage(totalTasks: number, completedTasks: number): number {
    if (totalTasks < 1) return 0;
    return Math.round((completedTasks / totalTasks) * 100);
  }

  private currentUserRole(
    context: PlanAccessContext,
  ): 'OWNER' | SharedMemberRole | null {
    if (context.isOwner) return 'OWNER';
    return context.sharedMember?.role ?? null;
  }

  private permissionSummary(
    context: PlanAccessContext,
  ): DashboardPermissionSummary {
    const role = this.currentUserRole(context);
    return {
      isOwner: context.isOwner,
      role,
      canViewBudget: this.permissions.canReadFinancial(context, 'budget'),
      canViewExpenses: this.permissions.canReadFinancial(context, 'expenses'),
      canViewDebts: this.permissions.canReadFinancial(context, 'debts'),
      canManageTasks: this.permissions.canManageTasks(context),
      canManageFinancialRecords:
        this.permissions.canManageFinancialRecords(context),
      canManagePlan: this.permissions.canManagePlan(context),
    };
  }
}
