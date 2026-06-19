import { Injectable, NotFoundException } from '@nestjs/common';
import {
  DebtStatus,
  ExpenseStatus,
  InstallmentStatus,
  WeddingPlan,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';

export interface MoneySummaryResponse {
  weddingPlanId: string;
  currency: string;
  budgetTotal: string | null;
  categoryTargetTotal: string | null;
  spentTotal: string | null;
  plannedExpensesTotal: string | null;
  cancelledExpensesTotal: string | null;
  remainingBudget: string | null;
  debtTotal: string | null;
  paidDebtTotal: string | null;
  unpaidDebtTotal: string | null;
  dueInstallmentsCount: number | null;
  overdueInstallmentsCount: number | null;
  categoriesCount: number | null;
  expensesCount: number | null;
  debtsCount: number | null;
  installmentsCount: number | null;
  permissions: {
    canViewBudget: boolean;
    canViewExpenses: boolean;
    canViewDebts: boolean;
    canManageFinancialRecords: boolean;
  };
}

@Injectable()
export class MoneySummaryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async getSummary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<MoneySummaryResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const canViewBudget = this.permissions.canReadFinancial(context, 'budget');
    const canViewExpenses = this.permissions.canReadFinancial(context, 'expenses');
    const canViewDebts = this.permissions.canReadFinancial(context, 'debts');
    const canManageFinancialRecords =
      context.isOwner ||
      Boolean(context.sharedMember?.canManageFinancialRecords);

    if (!canViewBudget && !canViewExpenses && !canViewDebts) {
      throw new NotFoundException('Wedding plan not found');
    }

    const today = this.startOfToday();
    const [
      categories,
      expenses,
      debts,
      installmentsCount,
      dueInstallmentsCount,
      overdueInstallmentsCount,
    ] = await Promise.all([
      canViewBudget
        ? this.prisma.budgetCategory.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewExpenses
        ? this.prisma.expense.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.debt.findMany({ where: { weddingPlanId } })
        : Promise.resolve([]),
      canViewDebts
        ? this.prisma.installment.count({ where: { debt: { weddingPlanId } } })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lte: this.endOfToday(today) },
            },
          })
        : Promise.resolve(null),
      canViewDebts
        ? this.prisma.installment.count({
            where: {
              debt: { weddingPlanId },
              status: {
                in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
              },
              dueDate: { lt: today },
            },
          })
        : Promise.resolve(null),
    ]);

    const categoryTargetTotal = canViewBudget
      ? categories.reduce(
          (sum, category) => sum + this.decimalToNumber(category.targetAmount),
          0,
        )
      : null;
    const budgetTotal = canViewBudget
      ? this.resolveBudgetTotal(context.plan, categoryTargetTotal ?? 0)
      : null;
    const expenseTotals = canViewExpenses
      ? this.expenseTotals(expenses)
      : null;
    const debtTotals = canViewDebts ? this.debtTotals(debts) : null;
    const remainingBudget =
      budgetTotal !== null && expenseTotals
        ? budgetTotal - expenseTotals.spentTotal
        : null;

    return {
      weddingPlanId,
      currency: context.plan.currency,
      budgetTotal: this.moneyOrNull(budgetTotal),
      categoryTargetTotal: this.moneyOrNull(categoryTargetTotal),
      spentTotal: this.moneyOrNull(expenseTotals?.spentTotal ?? null),
      plannedExpensesTotal: this.moneyOrNull(
        expenseTotals?.plannedExpensesTotal ?? null,
      ),
      cancelledExpensesTotal: this.moneyOrNull(
        expenseTotals?.cancelledExpensesTotal ?? null,
      ),
      remainingBudget: this.moneyOrNull(remainingBudget),
      debtTotal: this.moneyOrNull(debtTotals?.debtTotal ?? null),
      paidDebtTotal: this.moneyOrNull(debtTotals?.paidDebtTotal ?? null),
      unpaidDebtTotal: this.moneyOrNull(debtTotals?.unpaidDebtTotal ?? null),
      dueInstallmentsCount,
      overdueInstallmentsCount,
      categoriesCount: canViewBudget ? categories.length : null,
      expensesCount: canViewExpenses ? expenses.length : null,
      debtsCount: canViewDebts ? debts.length : null,
      installmentsCount,
      permissions: {
        canViewBudget,
        canViewExpenses,
        canViewDebts,
        canManageFinancialRecords,
      },
    };
  }

  private resolveBudgetTotal(plan: WeddingPlan, categoryTargetTotal: number): number {
    if (plan.estimatedBudget) return this.decimalToNumber(plan.estimatedBudget);
    return categoryTargetTotal;
  }

  private expenseTotals(expenses: { amount: { toString(): string }; status: ExpenseStatus }[]) {
    return expenses.reduce(
      (summary, expense) => {
        const amount = this.decimalToNumber(expense.amount);
        if (expense.status === ExpenseStatus.PAID) summary.spentTotal += amount;
        if (expense.status === ExpenseStatus.PLANNED) {
          summary.plannedExpensesTotal += amount;
        }
        if (expense.status === ExpenseStatus.CANCELLED) {
          summary.cancelledExpensesTotal += amount;
        }
        return summary;
      },
      {
        spentTotal: 0,
        plannedExpensesTotal: 0,
        cancelledExpensesTotal: 0,
      },
    );
  }

  private debtTotals(
    debts: {
      totalAmount: { toString(): string };
      paidAmount: { toString(): string };
      status: DebtStatus;
    }[],
  ) {
    const totals = debts.reduce(
      (summary, debt) => {
        if (debt.status === DebtStatus.CANCELLED) return summary;
        summary.debtTotal += this.decimalToNumber(debt.totalAmount);
        summary.paidDebtTotal += this.decimalToNumber(debt.paidAmount);
        return summary;
      },
      { debtTotal: 0, paidDebtTotal: 0 },
    );

    return {
      ...totals,
      unpaidDebtTotal: Math.max(totals.debtTotal - totals.paidDebtTotal, 0),
    };
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
}
