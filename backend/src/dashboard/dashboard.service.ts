import { Injectable } from '@nestjs/common';
import {
  DebtStatus,
  ExpenseStatus,
  InstallmentStatus,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

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
}
