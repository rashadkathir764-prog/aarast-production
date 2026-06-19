import { Injectable } from '@nestjs/common';
import {
  DebtStatus,
  ExpenseStatus,
  GuestStatus,
  InstallmentStatus,
  SharedMemberRole,
  WeddingPlan,
  WeddingPlanStatus,
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
  currentUserRole: 'OWNER' | SharedMemberRole | null;
  permissions: DashboardPermissionSummary;
}

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
      totalTasks,
      completedTasks,
      overdueTasks,
      todayTasks,
      guestCount,
      confirmedGuests,
      quoteRequestsCount,
      unreadNotificationsCount,
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
      this.prisma.quoteRequest.count({ where: { weddingPlanId } }),
      this.prisma.notification.count({
        where: {
          userId: currentUser.id,
          weddingPlanId,
          readAt: null,
        },
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
      providerCount: 0,
      quoteRequestsCount,
      unreadNotificationsCount,
      currentUserRole: this.currentUserRole(context),
      permissions: this.permissionSummary(context),
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
        context.isOwner ||
        Boolean(context.sharedMember?.canManageFinancialRecords),
      canManagePlan:
        context.isOwner || context.sharedMember?.role === SharedMemberRole.MANAGER,
    };
  }
}
